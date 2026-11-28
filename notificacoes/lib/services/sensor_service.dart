// SensorService (Pessoa 1): ponto central de acesso aos sensores do app.
// Ele NÃO tem lógica própria: só repassa (delega) cada chamada para o
// serviço que a Pessoa responsável escreveu. Assim a tela conhece um único
// lugar, e cada Pessoa continua dona do seu código.

import 'package:geolocator/geolocator.dart'; // tipo Position (GPS)
import 'package:sensors_plus/sensors_plus.dart'; // tipos dos eventos dos sensores

import 'bateria_service.dart'; // Pessoa 5
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
  final BateriaService bateria = BateriaService(); // Pessoa 5

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
  // PESSOA 5 (Luis Felipe): Bateria e ciclo de vida
  // =========================================================================

  /// Pessoa 5: liga a leitura contínua do GPS (getPositionStream) com a
  /// precisão, o distanceFilter e o intervalo escolhidos.
  Future<void> iniciarLeituraContinua({ConfigLeitura? config}) =>
      bateria.iniciar(config: config);

  /// Pessoa 5: app foi para segundo plano. Cancela o stream do GPS, mas
  /// lembra que o usuário queria a leitura ligada.
  Future<void> pausarLeituras() => bateria.pausar();

  /// Pessoa 5: app voltou para a tela. Reabre o stream se estava pausado.
  Future<void> retomarLeituras() => bateria.retomar();

  /// Pessoa 5: cancela todas as assinaturas de GPS abertas pela Pessoa 5.
  Future<void> pararTudo() => bateria.parar();
}
