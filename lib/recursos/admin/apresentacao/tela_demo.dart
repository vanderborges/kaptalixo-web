import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../compartilhado/estados.dart';
import '../dominio/demo.dart';
import '../dominio/falha_admin.dart';
import 'demo_providers.dart';
import 'mapa_demo.dart';

/// Rota do painel de demonstração (filha de `/admin`).
const rotaDemo = '/admin/demo';

/// Limite de aceite do reset (UC15).
const limiteResetDemo = Duration(seconds: 10);

/// Formata a duração em segundos com vírgula (ex.: `0,8 s`).
String formatarSegundos(Duration d) =>
    '${(d.inMilliseconds / 1000).toStringAsFixed(1).replaceAll('.', ',')} s';

String _mensagem(Object e) => e is FalhaAdmin
    ? e.mensagem
    : const FalhaAdmin(CodigoFalhaAdmin.desconhecida).mensagem;

/// Painel de demonstração (UC15): mapa ao vivo, ações e feed de eventos.
class TelaDemo extends ConsumerStatefulWidget {
  const TelaDemo({super.key, this.tileProvider});

  final TileProvider? tileProvider;

  @override
  ConsumerState<TelaDemo> createState() => _EstadoTelaDemo();
}

class _EstadoTelaDemo extends ConsumerState<TelaDemo> {
  int _n = 3;
  bool _ocupado = false;
  String? _resultadoReset;
  bool _resetLento = false;
  String? _catadorSelecionado;

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _executar(Future<void> Function() acao) async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    try {
      await acao();
    } on Object catch (e) {
      _aviso(_mensagem(e));
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _criarCatadores() => _executar(() async {
    final n = await ref
        .read(demoControladorProvider.notifier)
        .criarCatadores(_n);
    _aviso(
      n == 1 ? '1 catador fictício criado.' : '$n catadores fictícios criados.',
    );
  });

  Future<void> _criarPedido() => _executar(() async {
    await ref.read(demoControladorProvider.notifier).criarPedido();
    _aviso('Pedido fictício criado.');
  });

  Future<void> _resetar() async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resetar demo?'),
        content: const Text(
          'Apaga pedidos, rotas, entregas e notificações e devolve os '
          'catadores ao estado inicial. Usuários e pontos são mantidos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text('Resetar'),
          ),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;
    ref.read(simulacaoDemoProvider.notifier).desligar();
    await _executar(() async {
      final d = await ref.read(demoControladorProvider.notifier).resetar();
      if (!mounted) return;
      setState(() {
        _resultadoReset = 'Demo resetada em ${formatarSegundos(d)}.';
        _resetLento = d >= limiteResetDemo;
      });
    });
  }

  void _alternarSimulacao(SnapshotDemo snapshot, SimulacaoDemoEstado sim) {
    final controle = ref.read(simulacaoDemoProvider.notifier);
    if (sim.ativa) {
      controle.desligar();
      return;
    }
    final catador = snapshot
        .porTipo(TipoAtorDemo.catador)
        .where((c) => c.id == _catadorSelecionado)
        .firstOrNull;
    if (catador == null) {
      _aviso('Escolha um catador para simular.');
      return;
    }
    if (!controle.ligar(catador, snapshot, multiplicador: sim.multiplicador)) {
      _aviso('${catador.nome} não tem rota ativa para percorrer.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(demoControladorProvider);
    final sim = ref.watch(simulacaoDemoProvider);
    ref.listen(simulacaoDemoProvider, (anterior, atual) {
      if (atual.erro != null && atual.erro != anterior?.erro) {
        _aviso('Simulação interrompida: ${atual.erro}');
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel de demonstração'),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar agora',
            icon: const Icon(Icons.refresh),
            onPressed: () =>
                ref.read(demoControladorProvider.notifier).atualizar(),
          ),
        ],
      ),
      body: estado.when(
        loading: () => const EstadoCarregando(mensagem: 'Carregando painel...'),
        error: (e, _) => EstadoErro(
          mensagem: _mensagem(e),
          aoTentarNovamente: () => ref.invalidate(demoControladorProvider),
        ),
        data: (snapshot) => LayoutBuilder(
          builder: (context, c) {
            final mapa = Column(
              children: [
                Expanded(
                  child: MapaDemo(
                    snapshot: snapshot,
                    catadorEmSimulacao: sim.catadorId,
                    tileProvider: widget.tileProvider,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: LegendaDemo(),
                  ),
                ),
              ],
            );
            final painel = _Painel(
              snapshot: snapshot,
              sim: sim,
              n: _n,
              ocupado: _ocupado,
              resultadoReset: _resultadoReset,
              resetLento: _resetLento,
              catadorSelecionado: _catadorSelecionado,
              aoMudarN: (v) => setState(() => _n = v),
              aoCriarCatadores: _criarCatadores,
              aoCriarPedido: _criarPedido,
              aoResetar: _resetar,
              aoEscolherCatador: (id) =>
                  setState(() => _catadorSelecionado = id),
              aoMudarMultiplicador: (m) {
                final controle = ref.read(simulacaoDemoProvider.notifier);
                if (sim.ativa) {
                  final id = sim.catadorId;
                  controle.desligar();
                  final ator = snapshot.atores
                      .where((a) => a.id == id)
                      .firstOrNull;
                  if (ator != null) {
                    controle.ligar(ator, snapshot, multiplicador: m);
                  }
                } else {
                  controle.definirMultiplicador(m);
                }
              },
              aoAlternarSimulacao: () => _alternarSimulacao(snapshot, sim),
            );
            if (c.maxWidth >= 900) {
              return Row(
                children: [
                  Expanded(child: mapa),
                  SizedBox(width: 400, child: painel),
                ],
              );
            }
            return Column(
              children: [
                Expanded(flex: 3, child: mapa),
                Expanded(flex: 4, child: painel),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Painel extends StatelessWidget {
  const _Painel({
    required this.snapshot,
    required this.sim,
    required this.n,
    required this.ocupado,
    required this.resultadoReset,
    required this.resetLento,
    required this.catadorSelecionado,
    required this.aoMudarN,
    required this.aoCriarCatadores,
    required this.aoCriarPedido,
    required this.aoResetar,
    required this.aoEscolherCatador,
    required this.aoMudarMultiplicador,
    required this.aoAlternarSimulacao,
  });

  final SnapshotDemo snapshot;
  final SimulacaoDemoEstado sim;
  final int n;
  final bool ocupado;
  final String? resultadoReset;
  final bool resetLento;
  final String? catadorSelecionado;
  final ValueChanged<int> aoMudarN;
  final VoidCallback aoCriarCatadores;
  final VoidCallback aoCriarPedido;
  final VoidCallback aoResetar;
  final ValueChanged<String?> aoEscolherCatador;
  final ValueChanged<double> aoMudarMultiplicador;
  final VoidCallback aoAlternarSimulacao;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final catadores = snapshot.porTipo(TipoAtorDemo.catador).toList();
    final estiloBotao = FilledButton.styleFrom(minimumSize: const Size(48, 48));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Ações', style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            IconButton.outlined(
              key: const Key('demo-n-menos'),
              tooltip: 'Menos catadores',
              icon: const Icon(Icons.remove),
              onPressed: ocupado || n <= 1 ? null : () => aoMudarN(n - 1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '$n',
                key: const Key('demo-n'),
                style: tema.textTheme.titleLarge,
              ),
            ),
            IconButton.outlined(
              key: const Key('demo-n-mais'),
              tooltip: 'Mais catadores',
              icon: const Icon(Icons.add),
              onPressed: ocupado || n >= 20 ? null : () => aoMudarN(n + 1),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                key: const Key('demo-criar-catadores'),
                style: estiloBotao,
                onPressed: ocupado ? null : aoCriarCatadores,
                icon: const Icon(Icons.group_add),
                label: const Text('Criar catadores fictícios'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          key: const Key('demo-criar-pedido'),
          style: estiloBotao,
          onPressed: ocupado ? null : aoCriarPedido,
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('Criar pedido fictício'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('demo-resetar'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: tema.colorScheme.error,
          ),
          onPressed: ocupado ? null : aoResetar,
          icon: const Icon(Icons.restart_alt),
          label: const Text('Resetar demo'),
        ),
        if (ocupado)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
        if (resultadoReset != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                resetLento
                    ? '$resultadoReset Acima do limite de 10 s.'
                    : resultadoReset!,
                key: const Key('demo-resultado-reset'),
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: resetLento ? tema.colorScheme.error : null,
                ),
              ),
            ),
          ),
        const Divider(height: 32),
        Text('Simulação de movimento', style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (catadores.isEmpty)
          const Text('Nenhum catador no mapa.')
        else
          DropdownButtonFormField<String>(
            key: const Key('demo-catador'),
            initialValue: catadores.any((c) => c.id == catadorSelecionado)
                ? catadorSelecionado
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Catador'),
            items: [
              for (final c in catadores)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(
                    snapshot.rotaDe(c.id) == null
                        ? c.nome
                        : '${c.nome} (com rota)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: sim.ativa ? null : aoEscolherCatador,
          ),
        const SizedBox(height: 8),
        SegmentedButton<double>(
          key: const Key('demo-velocidade'),
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(minimumSize: const Size(48, 48)),
          segments: const [
            ButtonSegment(value: 1, label: Text('1x')),
            ButtonSegment(value: 10, label: Text('10x')),
          ],
          selected: {sim.multiplicador},
          onSelectionChanged: (s) => aoMudarMultiplicador(s.first),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('demo-simulacao'),
          style: estiloBotao,
          onPressed: aoAlternarSimulacao,
          icon: Icon(sim.ativa ? Icons.stop : Icons.play_arrow),
          label: Text(sim.ativa ? 'Desligar simulação' : 'Ligar simulação'),
        ),
        const Divider(height: 32),
        Text('Eventos ao vivo', style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (snapshot.eventos.isEmpty)
          const EstadoVazio(mensagem: 'Nenhum evento ainda.')
        else
          for (final e in snapshot.eventos)
            ListTile(
              key: Key('evento-${e.id}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              minVerticalPadding: 12,
              leading: const Icon(Icons.bolt),
              title: Text(e.descricao),
              subtitle: Text(_hora(e.criadoEm)),
            ),
      ],
    );
  }

  static String _hora(DateTime d) {
    final l = d.toLocal();
    String dois(int v) => v.toString().padLeft(2, '0');
    return '${dois(l.hour)}:${dois(l.minute)}:${dois(l.second)}';
  }
}
