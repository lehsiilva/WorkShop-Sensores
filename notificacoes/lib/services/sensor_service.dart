// SensorService (Pessoa 1): ponto central de acesso aos sensores do app.
// Ele NÃO tem lógica própria: só repassa (delega) cada chamada para o
// serviço que a Pessoa responsável escreveu. Assim a tela conhece um único
// lugar, e cada Pessoa continua dona do seu código.

import 'package:geolocator/geolocator.dart'; // tipo Position (GPS)
import 'package:sensors_plus/sensors_plus.dart'; // tipos dos eventos dos sensores

import 'gps_service.dart'; // Pessoa 3
// Nome do arquivo mantido como está hoje (com "permition"); renomear é decisão da Pessoa 2.
import 'location_permition_service.dart'; // Pessoa 2
import 'movimento_service.dart'; // Pessoa 4

class SensorService {
  // Construtor privado: impede que alguém fora desta classe crie outra instância.
  SensorService._();

  // Instância única (singleton). Uso: SensorService.instance.
  static final SensorService instance = SensorService._();

  // Um objeto de cada serviço. São públicos para que os painéis (widgets)
  // possam recebê-los pelo parâmetro "service", ex.: PainelGps(service: ...gps).
  final LocationPermissionService permissao = LocationPermissionService(); // Pessoa 2
  final GpsService gps = GpsService(); // Pessoa 3
  final MovimentoService movimento = MovimentoService(); // Pessoa 4

  // =========================================================================
  // PESSOA 2 (Thayná): Permissões
  // =========================================================================

  /// Pessoa 2: só consulta o estado atual da permissão, sem mostrar o pedido.
  Future<LocationAccess> verificarPermissao() => permissao.check();

  /// Pessoa 2: mostra o pedido de permissão ao usuário (se ainda for possível).
  Future<LocationAccess> pedirPermissao() => permissao.request();

  /// Pessoa 2: atalho que devolve true só quando a permissão foi concedida.
  Future<bool> garantirPermissao() => permissao.ensureGranted();

  /// Pessoa 2: abre as configurações do app (caso "negada para sempre").
  Future<bool> abrirConfiguracoesApp() => permissao.openAppSettings();

  /// Pessoa 2: abre as configurações de localização (caso GPS desligado).
  Future<bool> abrirConfiguracoesLocalizacao() =>
      permissao.openLocationSettings();

  // =========================================================================
  // PESSOA 3 (Lucas Reis): Geolocalização
  // =========================================================================

  /// Pessoa 3: leitura única da posição atual (lança GpsException se falhar).
  Future<Position> obterLocalizacaoAtual({
    LocationAccuracy precisao = LocationAccuracy.high,
  }) =>
      gps.obterLocalizacaoAtual(precisao: precisao);

  /// Pessoa 3: distância em metros entre dois pontos.
  double calcularDistanciaMetros(Position origem, Position destino) =>
      gps.calcularDistanciaMetros(origem, destino);

  // =========================================================================
  // PESSOA 4 (Letícia): Sensores de movimento
  // =========================================================================

  /// Pessoa 4: fluxo contínuo do acelerômetro (m/s²).
  Stream<AccelerometerEvent> acelerometro() => movimento.acelerometro();

  /// Pessoa 4: fluxo contínuo do giroscópio (rad/s).
  Stream<GyroscopeEvent> giroscopio() => movimento.giroscopio();

  /// Pessoa 4: fluxo contínuo do magnetômetro (µT).
  Stream<MagnetometerEvent> magnetometro() => movimento.magnetometro();

  // =========================================================================
  // PESSOA 5 (a definir): Bateria e ciclo de vida
  // =========================================================================
  // TODO Pessoa 5: nada implementado ainda. Nomes sugeridos (ajuste à vontade):
  //   Stream<Position> posicaoEmTempoReal({int distanceFilter})
  //       -> leitura contínua do GPS com distanceFilter (economia de bateria)
  //   void pausarLeituras()   -> chamado quando o app vai para segundo plano
  //   void retomarLeituras()  -> chamado quando o app volta para a tela
  //   Future<void> pararTudo() -> cancela todas as assinaturas (streams)
}
