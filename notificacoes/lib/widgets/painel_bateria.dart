import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/bateria_service.dart';
import '../services/gps_service.dart';

/// Painel de Bateria e ciclo de vida - Pessoa 5.
/// Widget autocontido para ser encaixado na tela única do app (Pessoa 6).
///
/// O que a demo mostra:
///  1. Interruptor que liga/desliga a leitura contínua (getPositionStream).
///  2. Seletores de precisão, distanceFilter e intervalo.
///  3. Contador de atualizações, para comparar as configurações.
///  4. Pausa automática quando o app vai para segundo plano.
class PainelBateria extends StatefulWidget {
  const PainelBateria({super.key, this.service});

  /// Opcional: permite usar o serviço do SensorService
  /// (ex.: PainelBateria(service: SensorService.instance.bateria)).
  final BateriaService? service;

  @override
  State<PainelBateria> createState() => _PainelBateriaState();
}

// WidgetsBindingObserver: faz o Flutter avisar este State sempre que o app
// muda de estado (em primeiro plano, em segundo plano, etc.).
class _PainelBateriaState extends State<PainelBateria>
    with WidgetsBindingObserver {
  late final BateriaService _service = widget.service ?? BateriaService();

  /// Só descartamos o serviço se fomos nós que o criamos.
  bool get _somosDonos => widget.service == null;

  /// Redesenha o "tempo ligado" a cada segundo, só enquanto estiver lendo.
  Timer? _relogio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service.addListener(_atualizarRelogio);
  }

  /// Chamado pelo Flutter quando o app muda de estado.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      // Foi para segundo plano (botão Home, outro app por cima, tela apagada).
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _service.pausar();
      // Voltou para a tela.
      case AppLifecycleState.resumed:
        _service.retomar();
      // "inactive" NÃO pausa: ele também acontece com o diálogo de permissão
      // e ao puxar a barra de notificações, e o app continua visível.
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _atualizarRelogio() {
    final lendo = _service.estado == EstadoLeitura.lendo;
    if (lendo && _relogio == null) {
      _relogio = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!lendo) {
      _relogio?.cancel();
      _relogio = null;
    }
  }

  Future<void> _alternar(bool ligar) async {
    if (!ligar) {
      await _service.parar();
      return;
    }
    try {
      await _service.iniciar();
    } on GpsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.mensagem)));
    }
  }

  @override
  void dispose() {
    // Ordem importa: primeiro paramos de ouvir o ciclo de vida e o relógio,
    // depois cancelamos o stream do GPS. Nada pode ficar ligado.
    WidgetsBinding.instance.removeObserver(this);
    _relogio?.cancel();
    _service.removeListener(_atualizarRelogio);
    if (_somosDonos) {
      _service.dispose(); // dispose() já cancela a assinatura
    } else {
      _service.parar();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ListenableBuilder(
          listenable: _service,
          builder: (context, _) {
            final s = _service;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bateria e ciclo de vida', style: tema.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'getPositionStream, distanceFilter e cancelamento do stream',
                  style: tema.bodySmall,
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Leitura contínua do GPS'),
                  subtitle: Text(_textoEstado(s.estado)),
                  value: s.ligada,
                  onChanged: _alternar,
                ),
                const Divider(height: 1),
                const SizedBox(height: 12),
                _configuracoes(s),
                const SizedBox(height: 12),
                _custo(s.config),
                const SizedBox(height: 12),
                _contadores(s),
                if (s.ultimaPosicao != null) ...[
                  const SizedBox(height: 12),
                  _ultimaPosicao(s.ultimaPosicao!),
                ],
                if (s.erro != null) ...[
                  const SizedBox(height: 12),
                  Text(s.erro!, style: const TextStyle(color: Colors.red)),
                ],
                if (s.historico.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _comparativo(s),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  String _textoEstado(EstadoLeitura e) => switch (e) {
        EstadoLeitura.desligada => 'Desligada: nenhum stream aberto',
        EstadoLeitura.lendo => 'Lendo: GPS ligado',
        EstadoLeitura.pausadaSegundoPlano => 'Pausada: app em segundo plano',
      };

  Widget _configuracoes(BateriaService s) {
    final c = s.config;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Atalhos para a demo: um clique troca tudo de uma vez.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.gps_fixed, size: 18),
              label: const Text('Alta precisão'),
              onPressed: () => s.mudarConfig(ConfigLeitura.altaPrecisao),
            ),
            ActionChip(
              avatar: const Icon(Icons.battery_saver, size: 18),
              label: const Text('Economia'),
              onPressed: () => s.mudarConfig(ConfigLeitura.economia),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Precisão'),
        const SizedBox(height: 4),
        SegmentedButton<LocationAccuracy>(
          segments: const [
            ButtonSegment(
              value: LocationAccuracy.high,
              label: Text('Alta (GPS)'),
            ),
            ButtonSegment(
              value: LocationAccuracy.low,
              label: Text('Baixa (rede)'),
            ),
          ],
          selected: {
            c.precisao == LocationAccuracy.low
                ? LocationAccuracy.low
                : LocationAccuracy.high,
          },
          onSelectionChanged: (v) => s.mudarConfig(c.copyWith(precisao: v.first)),
        ),
        const SizedBox(height: 12),
        const Text('distanceFilter (metros)'),
        const SizedBox(height: 4),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('0 m')),
            ButtonSegment(value: 10, label: Text('10 m')),
            ButtonSegment(value: 50, label: Text('50 m')),
          ],
          selected: {c.distanceFilterMetros},
          onSelectionChanged: (v) =>
              s.mudarConfig(c.copyWith(distanceFilterMetros: v.first)),
        ),
        const SizedBox(height: 12),
        const Text('Intervalo entre leituras (só Android)'),
        const SizedBox(height: 4),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('1 s')),
            ButtonSegment(value: 5, label: Text('5 s')),
            ButtonSegment(value: 10, label: Text('10 s')),
          ],
          selected: {c.intervalo.inSeconds},
          onSelectionChanged: (v) => s.mudarConfig(
            c.copyWith(intervalo: Duration(seconds: v.first)),
          ),
        ),
      ],
    );
  }

  Widget _custo(ConfigLeitura c) {
    final custo = c.custoEstimado;
    final cor = switch (custo) {
      'Alto' => Colors.red,
      'Médio' => Colors.orange,
      _ => Colors.green,
    };
    return Row(
      children: [
        Icon(Icons.battery_alert, color: cor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Custo estimado de bateria: $custo',
            style: TextStyle(color: cor, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _contadores(BateriaService s) {
    final segundos = s.tempoLigado.inSeconds;
    final porMinuto = segundos == 0 ? 0 : s.atualizacoes * 60 / segundos;
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        _numero('Atualizações', '${s.atualizacoes}'),
        _numero('Tempo ligado', _formatarDuracao(s.tempoLigado)),
        _numero('Por minuto', porMinuto.toStringAsFixed(1)),
        _numero('Pausas', '${s.pausas}'),
      ],
    );
  }

  Widget _numero(String rotulo, String valor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          valor,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
        Text(rotulo, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _ultimaPosicao(Position p) {
    final hora = p.timestamp.toLocal();
    String dois(int n) => n.toString().padLeft(2, '0');
    return Text(
      'Última: ${p.latitude.toStringAsFixed(6)}, '
      '${p.longitude.toStringAsFixed(6)}\n'
      'Precisão: ±${p.accuracy.toStringAsFixed(0)} m · '
      '${dois(hora.hour)}:${dois(hora.minute)}:${dois(hora.second)}',
      style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
    );
  }

  Widget _comparativo(BateriaService s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Comparativo das rodadas',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: s.limparHistorico,
              child: const Text('Limpar'),
            ),
          ],
        ),
        for (final r in s.historico)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              '${r.config.descricao}\n'
              '  ${r.atualizacoes} atualizações em '
              '${_formatarDuracao(r.duracao)} '
              '(${r.porMinuto.toStringAsFixed(1)}/min, '
              'custo ${r.config.custoEstimado.toLowerCase()})',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
      ],
    );
  }

  String _formatarDuracao(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
