import 'package:flutter/material.dart';
import '../services/gps_service.dart';
import 'package:geolocator/geolocator.dart';

/// Painel de Geolocalização (GPS) - Pessoa 3.
/// Widget autocontido para ser encaixado na tela única do app (Pessoa 6).
class PainelGps extends StatefulWidget {
  const PainelGps({super.key, this.service});

  final GpsService? service;

  @override
  State<PainelGps> createState() => _PainelGpsState();
}

class _PainelGpsState extends State<PainelGps> {
  late final GpsService _service = widget.service ?? GpsService();

  Position? _posicaoAtual;
  Position? _pontoReferencia;
  bool _carregando = false;
  String? _erro;

  Future<void> _buscarLocalizacao() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });

    try {
      final posicao = await _service.obterLocalizacaoAtual();
      if (!mounted) return;
      setState(() => _posicaoAtual = posicao);
    } on GpsException catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.mensagem);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = 'Erro inesperado ao ler GPS: $e');
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  void _marcarPontoReferencia() {
    if (_posicaoAtual == null) return;
    setState(() => _pontoReferencia = _posicaoAtual);
  }

  String _formatarHora(DateTime dataUtc) {
    final local = dataUtc.toLocal();
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final a = local.year;
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    final s = local.second.toString().padLeft(2, '0');
    return '$d/$m/$a às $h:$min:$s';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final posicao = _posicaoAtual;

    double? distanciaMetros;
    if (posicao != null && _pontoReferencia != null) {
      distanciaMetros = _service.calcularDistanciaMetros(
        _pontoReferencia!,
        posicao,
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Geolocalização (GPS)', style: tema.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Leitura única com Geolocator.getCurrentPosition',
              style: tema.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _carregando ? null : _buscarLocalizacao,
                icon: _carregando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                  _carregando
                      ? 'Obtendo localização...'
                      : 'Obter localização atual',
                ),
              ),
            ),
            if (_erro != null) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _erro!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
            if (posicao != null) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _LinhaDado(
                icone: Icons.north_east,
                rotulo: 'Latitude',
                valor: posicao.latitude.toStringAsFixed(6),
              ),
              _LinhaDado(
                icone: Icons.east,
                rotulo: 'Longitude',
                valor: posicao.longitude.toStringAsFixed(6),
              ),
              _LinhaDado(
                icone: Icons.radar,
                rotulo: 'Precisão',
                valor: '± ${posicao.accuracy.toStringAsFixed(1)} m',
              ),
              _LinhaDado(
                icone: Icons.schedule,
                rotulo: 'Hora',
                valor: _formatarHora(posicao.timestamp),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _marcarPontoReferencia,
                  icon: const Icon(Icons.pin_drop_outlined),
                  label: Text(
                    _pontoReferencia == null
                        ? 'Marcar ponto de referência (distância)'
                        : 'Atualizar ponto de referência',
                  ),
                ),
              ),
              if (distanciaMetros != null) ...[
                const SizedBox(height: 8),
                _LinhaDado(
                  icone: Icons.straighten,
                  rotulo: 'Distância do ponto salvo',
                  valor: _service.formatarDistancia(distanciaMetros),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _LinhaDado extends StatelessWidget {
  const _LinhaDado({
    required this.icone,
    required this.rotulo,
    required this.valor,
  });

  final IconData icone;
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icone, size: 18),
          const SizedBox(width: 8),
          Text('$rotulo: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(
              valor,
              textAlign: TextAlign.end,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}
