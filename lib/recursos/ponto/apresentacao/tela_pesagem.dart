import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dominio/entrega_a_caminho.dart';
import '../dominio/falha_ponto.dart';
import '../dominio/pesagem.dart';
import 'providers.dart';

/// Pesagem (UC11): kg por material, valor calculado na hora (RN11), confirma.
class TelaPesagem extends ConsumerStatefulWidget {
  const TelaPesagem({super.key, required this.entrega, this.aoConcluir});

  final EntregaACaminho entrega;

  /// Chamado ao tocar em "Concluir" no resumo; padrão: fecha a tela.
  final VoidCallback? aoConcluir;

  @override
  ConsumerState<TelaPesagem> createState() => _TelaPesagemState();
}

class _TelaPesagemState extends ConsumerState<TelaPesagem> {
  final Map<int, TextEditingController> _campos = {};
  bool _enviando = false;
  String? _erro;
  ResultadoEntrega? _resultado;

  @override
  void dispose() {
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _campo(int id) =>
      _campos.putIfAbsent(id, TextEditingController.new);

  /// Itens preenchidos (>0). Campo inválido devolve nulo em `invalido`.
  ({List<ItemPesagem> itens, bool invalido}) _itens() {
    final itens = <ItemPesagem>[];
    var invalido = false;
    _campos.forEach((id, c) {
      final t = c.text.trim();
      if (t.isEmpty) return;
      final p = parsePesoKg(t);
      if (p == null || p > maxPesoCentesimos) {
        invalido = true;
      } else if (p > 0) {
        itens.add(ItemPesagem(id, p));
      }
    });
    return (itens: itens, invalido: invalido);
  }

  Future<void> _confirmar() async {
    final lido = _itens();
    if (lido.invalido || lido.itens.isEmpty) return;
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final r = await ref
          .read(pontoRepositorioProvider)
          .registrarEntrega(widget.entrega.rotaId, lido.itens);
      if (mounted) setState(() => _resultado = r);
    } on FalhaPonto catch (e) {
      if (mounted) setState(() => _erro = e.texto);
    } catch (_) {
      if (mounted) {
        setState(
          () => _erro = const FalhaPonto(MotivoFalhaPonto.generico).texto,
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _concluir() {
    final cb = widget.aoConcluir;
    if (cb != null) {
      cb();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final r = _resultado;
    return Scaffold(
      appBar: AppBar(title: Text('Pesagem · ${widget.entrega.catadorNome}')),
      body: r != null ? _resumo(context, r) : _formulario(context),
    );
  }

  Widget _resumo(BuildContext context, ResultadoEntrega r) {
    final tema = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Entrega registrada',
            style: tema.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            formatarReais(r.valorTotalCentavos),
            style: tema.displaySmall,
            textAlign: TextAlign.center,
          ),
          Text(
            formatarKg(r.pesoTotalCentesimos),
            style: tema.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 56,
            child: FilledButton(
              onPressed: _concluir,
              child: const Text('Concluir'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _formulario(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final precosAsync = ref.watch(precosPontoProvider);
    return precosAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text(
          e is FalhaPonto ? e.texto : 'Não foi possível carregar os preços.',
          style: tema.titleLarge,
        ),
      ),
      data: (precos) {
        if (precos.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Cadastre os preços do ponto para pesar.',
                style: tema.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        final mapa = {for (final p in precos) p.materialId: p};
        final lido = _itens();
        ResumoPesagem? resumo;
        if (!lido.invalido && lido.itens.isNotEmpty) {
          resumo = calcularPesagem(lido.itens, mapa);
        }
        final podeConfirmar = resumo != null && !_enviando;
        return Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final p in precos) ...[
                    _linha(p, resumo),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            Material(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (lido.invalido)
                      Text(
                        'Peso inválido. Use números, ex.: 12,5',
                        style: tema.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    if (_erro != null)
                      Text(
                        _erro!,
                        style: tema.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    Text(
                      'Total: ${formatarReais(resumo?.valorTotalCentavos ?? 0)}',
                      style: tema.headlineSmall,
                      key: const Key('valor_total'),
                    ),
                    Text(
                      formatarKg(resumo?.pesoTotalCentesimos ?? 0),
                      style: tema.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: podeConfirmar ? _confirmar : null,
                        child: _enviando
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                ),
                              )
                            : const Text('Confirmar entrega'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _linha(MaterialPreco p, ResumoPesagem? resumo) {
    final linha = resumo?.linhas
        .where((l) => l.materialId == p.materialId)
        .firstOrNull;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.nome, style: Theme.of(context).textTheme.titleMedium),
              Text('${formatarReais(p.precoKgCentavos)}/kg'),
            ],
          ),
        ),
        Expanded(
          flex: 2,
          child: TextField(
            key: Key('peso_${p.materialId}'),
            controller: _campo(p.materialId),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: Theme.of(context).textTheme.titleLarge,
            decoration: const InputDecoration(
              suffixText: 'kg',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _erro = null),
          ),
        ),
        SizedBox(
          width: 96,
          child: Text(
            linha == null ? '' : formatarReais(linha.valorCentavos),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
