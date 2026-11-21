import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';

class MovimentoService {

  static const Duration intervalo = SensorInterval.uiInterval;

  Stream<AccelerometerEvent> acelerometro() =>
      accelerometerEventStream(samplingPeriod: intervalo);

  Stream<GyroscopeEvent> giroscopio() =>
      gyroscopeEventStream(samplingPeriod: intervalo);

  Stream<MagnetometerEvent> magnetometro() =>
      magnetometerEventStream(samplingPeriod: intervalo);

  static const double gravidade = 9.80665;

  static double forcaG(double x, double y, double z) =>
      math.sqrt(x * x + y * y + z * z) / gravidade;

  static double direcaoGraus(double mx, double my) {
    final graus = math.atan2(-mx, my) * 180 / math.pi;
    return (graus + 360) % 360;
  }

  static String pontoCardeal(double graus) {
    const nomes = ['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];
    return nomes[((graus + 22.5) % 360 ~/ 45)];
  }
}

class DetectorChacoalhar {
  DetectorChacoalhar({
    this.limiteG = 2.5,
    this.picosNecessarios = 3,
    this.janela = const Duration(milliseconds: 600),
    this.pausaAposDeteccao = const Duration(seconds: 1),
  });

 
  final double limiteG;

  final int picosNecessarios;

  final Duration janela;

  final Duration pausaAposDeteccao;

  final List<DateTime> _picos = [];
  DateTime? _ultimaDeteccao;

  bool processar(AccelerometerEvent e, {DateTime? agora}) {
    final t = agora ?? DateTime.now();

    final ultima = _ultimaDeteccao;
    if (ultima != null && t.difference(ultima) < pausaAposDeteccao) {
      return false;
    }

    if (MovimentoService.forcaG(e.x, e.y, e.z) < limiteG) return false;

    _picos.add(t);
    
    _picos.removeWhere((p) => t.difference(p) > janela);

    if (_picos.length >= picosNecessarios) {
      _picos.clear();
      _ultimaDeteccao = t;
      return true;
    }
    return false;
  }
} 