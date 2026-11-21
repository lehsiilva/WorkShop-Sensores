import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../services/movimento_service.dart';


class PainelMovimento extends StatefulWidget {
  const PainelMovimento({super.key, this.service});

  final MovimentoService? service;

  @override
  State<PainelMovimento> createState() => _PainelMovimentoState();
}

class _PainelMovimentoState extends State<PainelMovimento> {
  late final MovimentoService _service = widget.service ?? MovimentoService();
  final DetectorChacoalhar _detector = DetectorChacoalhar();

  
  final List<StreamSubscription<dynamic>> _assinaturas = [];
  Timer? _timerSemDados;
  Timer? _timerChacoalhar;

  bool _ativo = false;

  
  AccelerometerEvent? _acel;
  GyroscopeEvent? _giro;
  MagnetometerEvent? _mag;

 
  double _bolhaX = 0;
  double _bolhaY = 0;

  int _chacoalhoes = 0;
  bool _chacoalhouAgora = false;

  final Set<String> _indisponiveis = {};

  void _iniciar() {
    setState(() {
      _ativo = true;
      _indisponiveis.clear();
    });

    _assinaturas.add(
      _service.acelerometro().listen(
        _aoReceberAcelerometro,
        onError: (_) => _marcarIndisponivel('Acelerômetro'),
      ),
    );
    _assinaturas.add(
      _service.giroscopio().listen(
        (e) {
          if (mounted) setState(() => _giro = e);
        },
        onError: (_) => _marcarIndisponivel('Giroscópio'),
      ),
    );
    _assinaturas.add(
      _service.magnetometro().listen(
        (e) {
          if (mounted) setState(() => _mag = e);
        },
        onError: (_) => _marcarIndisponivel('Magnetômetro'),
      ),
    );

    
    _timerSemDados = Timer(const Duration(seconds: 2), () {
      if (!mounted || !_ativo) return;
      setState(() {
        if (_acel == null) _indisponiveis.add('Acelerômetro');
        if (_giro == null) _indisponiveis.add('Giroscópio');
        if (_mag == null) _indisponiveis.add('Magnetômetro');
      });
    });
  }

  void _aoReceberAcelerometro(AccelerometerEvent e) {
    if (!mounted) return;
    final alvoX = (-e.x / (MovimentoService.gravidade * 0.5)).clamp(-1.0, 1.0).toDouble();
    final alvoY = (e.y / (MovimentoService.gravidade * 0.5)).clamp(-1.0, 1.0).toDouble();

    final chacoalhou = _detector.processar(e);

    setState(() {
      _acel = e;
      _bolhaX += (alvoX - _bolhaX) * 0.25;
      _bolhaY += (alvoY - _bolhaY) * 0.25;
      if (chacoalhou) {
        _chacoalhoes++;
        _chacoalhouAgora = true;
      }
    });

    if (chacoalhou) {
      _timerChacoalhar?.cancel();
      _timerChacoalhar = Timer(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _chacoalhouAgora = false);
      });
    }
  }

  void _marcarIndisponivel(String nome) {
    if (mounted) setState(() => _indisponiveis.add(nome));
  }

  /// Cancela TODAS as assinaturas. Sem isso o sensor continuaria ligado
  /// gastando bateria mesmo com a tela já fechada.
  Future<void> _parar({bool atualizarTela = true}) async {
    _timerSemDados?.cancel();
    _timerChacoalhar?.cancel();
    for (final a in _assinaturas) {
      await a.cancel();
    }
    _assinaturas.clear();

    if (atualizarTela && mounted) {
      setState(() {
        _ativo = false;
        _acel = null;
        _giro = null;
        _mag = null;
        _bolhaX = 0;
        _bolhaY = 0;
        _chacoalhouAgora = false;
      });
    }
  }

  @override
  void dispose() {
    _parar(atualizarTela: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sensores de movimento', style: tema.titleMedium),
            const SizedBox(height: 4),
            Text(
              'sensors_plus: acelerômetro, giroscópio e magnetômetro',
              style: tema.bodySmall,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ler sensores em tempo real'),
              value: _ativo,
              onChanged: (ligar) => ligar ? _iniciar() : _parar(),
            ),
            if (_ativo) ...[
              const Divider(height: 1),
              const SizedBox(height: 12),
              if (_indisponiveis.isNotEmpty) _avisoIndisponiveis(),
              Row(
                children: [
                  Expanded(child: _nivelBolha()),
                  const SizedBox(width: 12),
                  Expanded(child: _bussola()),
                ],
              ),
              const SizedBox(height: 12),
              _chipChacoalhar(),
              const SizedBox(height: 12),
              _BlocoSensor(
                icone: Icons.speed,
                titulo: 'Acelerômetro',
                unidade: 'm/s²',
                x: _acel?.x,
                y: _acel?.y,
                z: _acel?.z,
                rodape: _acel == null
                    ? null
                    : 'Força total: ${MovimentoService.forcaG(_acel!.x, _acel!.y, _acel!.z).toStringAsFixed(2)} g (parado = 1,00 g)',
              ),
              _BlocoSensor(
                icone: Icons.threed_rotation,
                titulo: 'Giroscópio',
                unidade: 'rad/s',
                x: _giro?.x,
                y: _giro?.y,
                z: _giro?.z,
              ),
              _BlocoSensor(
                icone: Icons.explore,
                titulo: 'Magnetômetro',
                unidade: 'µT',
                x: _mag?.x,
                y: _mag?.y,
                z: _mag?.z,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _avisoIndisponiveis() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Colors.orange, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sem dados de: ${_indisponiveis.join(', ')}. '
              'O aparelho ou emulador pode não ter esse sensor '
              '(no emulador use Extended controls > Virtual sensors).',
              style: const TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }


  Widget _nivelBolha() {
    final cor = Theme.of(context).colorScheme;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cor.surfaceContainerHighest,
              border: Border.all(color: cor.outline),
            ),
           
            child: Align(
              alignment: Alignment(_bolhaX, _bolhaY),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cor.primary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text('Inclinação', style: TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _bussola() {
    final cor = Theme.of(context).colorScheme;
    final mag = _mag;
    final graus = mag == null ? null : MovimentoService.direcaoGraus(mag.x, mag.y);

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cor.surfaceContainerHighest,
              border: Border.all(color: cor.outline),
            ),
            child: Transform.rotate(
              angle: graus == null ? 0 : -graus * math.pi / 180,
              child: const Icon(Icons.navigation, size: 56, color: Colors.red),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          graus == null
              ? 'Bússola'
              : '${graus.toStringAsFixed(0)}° ${MovimentoService.pontoCardeal(graus)}',
          style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  Widget _chipChacoalhar() {
    final cor = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _chacoalhouAgora ? cor.tertiaryContainer : cor.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.vibration),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _chacoalhouAgora ? 'Chacoalhou!' : 'Chacoalhe o celular',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text('Total: $_chacoalhoes',
              style: const TextStyle(fontFamily: 'monospace')),
        ],
      ),
    );
  }
}

/// Bloco com os 3 eixos (X, Y, Z) de um sensor.
class _BlocoSensor extends StatelessWidget {
  const _BlocoSensor({
    required this.icone,
    required this.titulo,
    required this.unidade,
    required this.x,
    required this.y,
    required this.z,
    this.rodape,
  });

  final IconData icone;
  final String titulo;
  final String unidade;
  final double? x;
  final double? y;
  final double? z;
  final String? rodape;

  String _fmt(double? v) => v == null ? '--' : v.toStringAsFixed(2).padLeft(7);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 18),
              const SizedBox(width: 8),
              Text('$titulo ($unidade)',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _eixo('X', x),
              _eixo('Y', y),
              _eixo('Z', z),
            ],
          ),
          if (rodape != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(rodape!, style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  Widget _eixo(String nome, double? valor) => Text(
        '$nome: ${_fmt(valor)}',
        style: const TextStyle(fontFamily: 'monospace'),
      );
}