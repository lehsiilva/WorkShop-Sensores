// BateriaService (Pessoa 5): leitura CONTÍNUA do GPS com controle de custo.
//
// Por que existe: a leitura única (Pessoa 3) liga o GPS, pega um ponto e
// desliga. A leitura contínua (getPositionStream) mantém o GPS ligado o
// tempo todo, e é isso que gasta bateria. Este serviço deixa a tela:
//   - ligar e desligar a leitura contínua;
//   - escolher a precisão (alta = GPS, baixa = rede/Wi-Fi);
//   - escolher o distanceFilter (só avisa depois de andar X metros);
//   - escolher o intervalo entre leituras (Android);
//   - pausar quando o app vai para segundo plano e retomar ao voltar;
//   - contar quantas atualizações chegaram, para comparar as configurações.
//
// Regra mais importante: toda assinatura (StreamSubscription) aberta aqui é
// CANCELADA em parar() ou pausar(). Stream esquecido = GPS ligado à toa.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'gps_service.dart'; // reaproveita a GpsException da Pessoa 3

/// Estados possíveis da leitura contínua.
enum EstadoLeitura {
  /// Nenhuma assinatura aberta. GPS desligado por este serviço.
  desligada,

  /// Assinatura aberta e recebendo posições.
  lendo,

  /// O usuário ligou, mas o app foi para segundo plano: a assinatura foi
  /// cancelada e será reaberta quando o app voltar.
  pausadaSegundoPlano,
}

/// Configuração da leitura contínua. Cada campo muda o custo de bateria.
@immutable
class ConfigLeitura {
  const ConfigLeitura({
    this.precisao = LocationAccuracy.high,
    this.distanceFilterMetros = 0,
    this.intervalo = const Duration(seconds: 1),
  });

  /// high/best = chip de GPS ligado (mais preciso, mais caro).
  /// low = usa rede e Wi-Fi (menos preciso, bem mais barato).
  final LocationAccuracy precisao;

  /// Distância mínima (em metros) entre duas atualizações.
  /// 0 = avisa toda vez que o sistema calcular uma posição nova.
  final int distanceFilterMetros;

  /// Intervalo desejado entre leituras. Só o Android respeita este valor;
  /// no iOS quem decide é o sistema (o distanceFilter continua valendo).
  final Duration intervalo;

  /// Configuração "cara": melhor para navegação curva a curva.
  static const altaPrecisao = ConfigLeitura();

  /// Configuração "barata": suficiente para, por exemplo, mostrar a cidade.
  static const economia = ConfigLeitura(
    precisao: LocationAccuracy.low,
    distanceFilterMetros: 50,
    intervalo: Duration(seconds: 10),
  );

  ConfigLeitura copyWith({
    LocationAccuracy? precisao,
    int? distanceFilterMetros,
    Duration? intervalo,
  }) {
    return ConfigLeitura(
      precisao: precisao ?? this.precisao,
      distanceFilterMetros: distanceFilterMetros ?? this.distanceFilterMetros,
      intervalo: intervalo ?? this.intervalo,
    );
  }

  /// Texto curto para a tela e para o comparativo.
  String get descricao {
    final p = precisao == LocationAccuracy.low ? 'baixa' : 'alta';
    return 'precisão $p · filtro $distanceFilterMetros m · '
        'intervalo ${intervalo.inSeconds} s';
  }

  /// Estimativa QUALITATIVA do custo (não é medição real de mAh).
  /// Serve para explicar na apresentação quais escolhas pesam mais.
  String get custoEstimado {
    var pontos = 0;
    if (precisao != LocationAccuracy.low) pontos += 2; // GPS ligado é o maior custo
    if (distanceFilterMetros == 0) pontos += 1; // acorda o app a cada leitura
    if (intervalo.inSeconds <= 1) pontos += 1; // leituras muito frequentes
    if (pontos >= 3) return 'Alto';
    if (pontos >= 2) return 'Médio';
    return 'Baixo';
  }
}

/// Resumo de uma "rodada" de leitura, usado no comparativo da demo.
@immutable
class RodadaLeitura {
  const RodadaLeitura({
    required this.config,
    required this.atualizacoes,
    required this.duracao,
  });

  final ConfigLeitura config;
  final int atualizacoes;
  final Duration duracao;

  /// Atualizações por minuto: o número que comparamos entre as rodadas.
  double get porMinuto {
    final segundos = duracao.inMilliseconds / 1000;
    if (segundos <= 0) return 0;
    return atualizacoes * 60 / segundos;
  }
}

/// Serviço da Pessoa 5. É um ChangeNotifier: a tela se redesenha sozinha
/// quando o estado, o contador ou a última posição mudam.
class BateriaService extends ChangeNotifier {
  StreamSubscription<Position>? _assinatura;

  EstadoLeitura _estado = EstadoLeitura.desligada;
  ConfigLeitura _config = ConfigLeitura.altaPrecisao;

  int _atualizacoes = 0;
  int _pausas = 0;
  Position? _ultimaPosicao;
  String? _erro;

  // Mede só o tempo em que a leitura esteve de fato ligada (sem as pausas),
  // para a taxa "atualizações por minuto" ser justa.
  final Stopwatch _cronometro = Stopwatch();

  final List<RodadaLeitura> _historico = [];

  EstadoLeitura get estado => _estado;
  ConfigLeitura get config => _config;
  int get atualizacoes => _atualizacoes;
  int get pausas => _pausas;
  Position? get ultimaPosicao => _ultimaPosicao;
  String? get erro => _erro;
  Duration get tempoLigado => _cronometro.elapsed;
  List<RodadaLeitura> get historico => List.unmodifiable(_historico);

  /// true quando o usuário quer a leitura ligada (lendo ou só pausada).
  bool get ligada => _estado != EstadoLeitura.desligada;

  /// Monta o LocationSettings certo para cada plataforma.
  /// - Android: AndroidSettings aceita intervalDuration.
  /// - iOS: AppleSettings permite ao sistema pausar sozinho quando o
  ///   aparelho fica parado (pauseLocationUpdatesAutomatically).
  LocationSettings _settings(ConfigLeitura c) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: c.precisao,
        distanceFilter: c.distanceFilterMetros,
        intervalDuration: c.intervalo,
      );
    }
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return AppleSettings(
        accuracy: c.precisao,
        distanceFilter: c.distanceFilterMetros,
        pauseLocationUpdatesAutomatically: true,
      );
    }
    return LocationSettings(
      accuracy: c.precisao,
      distanceFilter: c.distanceFilterMetros,
    );
  }

  /// Mesmas verificações da leitura única: GPS ligado e permissão concedida.
  /// O fluxo completo (com telas e botões) é da Pessoa 2.
  Future<void> _verificarAcesso() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const GpsException(
        'Serviço de localização (GPS) está desligado no aparelho.',
      );
    }
    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    if (permissao == LocationPermission.denied) {
      throw const GpsException('Permissão de localização negada.');
    }
    if (permissao == LocationPermission.deniedForever) {
      throw const GpsException(
        'Permissão negada definitivamente. Ative nas configurações do app.',
      );
    }
  }

  /// Abre a assinatura do stream com a configuração atual.
  void _assinar() {
    _assinatura = Geolocator.getPositionStream(
      locationSettings: _settings(_config),
    ).listen(
      (posicao) {
        _atualizacoes++;
        _ultimaPosicao = posicao;
        _erro = null;
        notifyListeners();
      },
      onError: (Object e) {
        // Ex.: usuário desligou o GPS com a leitura ligada.
        _erro = 'Erro na leitura contínua: $e';
        parar();
      },
    );
    _cronometro.start();
  }

  /// Cancela a assinatura atual (se houver). É ESTE cancel() que desliga o
  /// GPS: sem ninguém escutando, o geolocator para de pedir posições.
  Future<void> _cancelarAssinatura() async {
    _cronometro.stop();
    await _assinatura?.cancel();
    _assinatura = null;
  }

  /// Liga a leitura contínua. Lança GpsException se não houver acesso.
  Future<void> iniciar({ConfigLeitura? config}) async {
    if (config != null) _config = config;
    if (_estado == EstadoLeitura.lendo) return;

    _erro = null;
    try {
      await _verificarAcesso();
    } on GpsException catch (e) {
      _erro = e.mensagem;
      notifyListeners();
      rethrow;
    }

    _atualizacoes = 0;
    _pausas = 0;
    _ultimaPosicao = null;
    _cronometro.reset();
    _assinar();
    _estado = EstadoLeitura.lendo;
    notifyListeners();
  }

  /// Desliga a leitura e guarda o resumo da rodada no comparativo.
  Future<void> parar() async {
    if (_estado == EstadoLeitura.desligada) return;
    await _cancelarAssinatura();
    _guardarRodada();
    _estado = EstadoLeitura.desligada;
    notifyListeners();
  }

  /// Troca a configuração. Se estiver lendo, fecha a rodada atual e abre
  /// uma nova (cancelar + assinar de novo), pois o stream do geolocator não
  /// muda de configuração depois de criado.
  Future<void> mudarConfig(ConfigLeitura nova) async {
    if (_estado == EstadoLeitura.desligada) {
      _config = nova;
      notifyListeners();
      return;
    }
    await parar();
    await iniciar(config: nova);
  }

  /// App foi para segundo plano: cancela a assinatura, mas lembra que o
  /// usuário queria a leitura ligada.
  ///
  /// Por que cancelar e não usar subscription.pause()? Porque pause() só
  /// segura os eventos num buffer: o GPS continuaria ligado lá embaixo.
  Future<void> pausar() async {
    if (_estado != EstadoLeitura.lendo) return;
    await _cancelarAssinatura();
    _pausas++;
    _estado = EstadoLeitura.pausadaSegundoPlano;
    notifyListeners();
  }

  /// App voltou para a tela: reabre a assinatura se ela estava pausada.
  /// Se o usuário tinha desligado, continua desligada.
  Future<void> retomar() async {
    if (_estado != EstadoLeitura.pausadaSegundoPlano) return;
    _assinar();
    _estado = EstadoLeitura.lendo;
    notifyListeners();
  }

  void limparHistorico() {
    _historico.clear();
    notifyListeners();
  }

  void _guardarRodada() {
    if (_cronometro.elapsed == Duration.zero) return;
    _historico.insert(
      0,
      RodadaLeitura(
        config: _config,
        atualizacoes: _atualizacoes,
        duracao: _cronometro.elapsed,
      ),
    );
  }

  /// Garante que nada fica ligado se o serviço for descartado.
  @override
  void dispose() {
    _cronometro.stop();
    _assinatura?.cancel();
    _assinatura = null;
    super.dispose();
  }
}
