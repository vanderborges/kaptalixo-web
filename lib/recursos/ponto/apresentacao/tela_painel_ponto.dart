import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dominio/entrega_a_caminho.dart';
import '../dominio/falha_ponto.dart';
import 'providers.dart';
import 'tela_pesagem.dart';

/// Painel do ponto (UC11): entregas a caminho com ETA; toque para pesar.
class TelaPainelPonto extends ConsumerStatefulWidget {
  const TelaPainelPonto({super.key, this.acoes = const [], this.aoPesar});

  /// Ações da barra (ex.: sair), injetadas pelo roteador.
  final List<Widget> acoes;

  /// Substitui a navegação padrão para a pesagem.
  final void Function(EntregaACaminho entrega)? aoPesar;

  @override
  ConsumerState<TelaPainelPonto> createState() => _TelaPainelPontoState();
}

class _TelaPainelPontoState extends ConsumerState<TelaPainelPonto> {
  Timer? _tick;
  DateTime? _agora;

  @override
  void initState() {
    super.initState();
    _agora = ref.read(relogioPontoProvider)();
    _tick = Timer.periodic(ref.read(tickPontoProvider), (_) {
      if (mounted) setState(() => _agora = ref.read(relogioPontoProvider)());
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _pesar(EntregaACaminho e) {
    final cb = widget.aoPesar;
    if (cb != null) {
      cb(e);
      return;
    }
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => TelaPesagem(entrega: e)));
  }

  @override
  Widget build(BuildContext context) {
    final entregas = ref.watch(entregasACaminhoProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entregas a caminho'),
        actions: widget.acoes,
      ),
      body: entregas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e is FalhaPonto ? e.texto : 'Não foi possível carregar.',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (lista) => lista.isEmpty
            ? Center(
                child: Text(
                  'Nenhuma entrega a caminho',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: lista.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _CartaoEntrega(
                  entrega: lista[i],
                  agora: _agora ?? DateTime.now(),
                  aoPesar: () => _pesar(lista[i]),
                ),
              ),
      ),
    );
  }
}

class _CartaoEntrega extends StatelessWidget {
  const _CartaoEntrega({
    required this.entrega,
    required this.agora,
    required this.aoPesar,
  });

  final EntregaACaminho entrega;
  final DateTime agora;
  final VoidCallback aoPesar;

  String _quando() {
    if (entrega.chegou) return 'Chegou';
    final m = entrega.minutosAte(agora);
    if (m == null) return 'ETA indisponível';
    if (m == 0) return 'Chegando';
    return 'Chega em $m min';
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final s = entrega.sacos;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(entrega.catadorNome, style: tema.titleLarge),
            const SizedBox(height: 4),
            Text('$s ${s == 1 ? 'saco' : 'sacos'}', style: tema.titleMedium),
            const SizedBox(height: 4),
            Text(_quando(), style: tema.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: aoPesar,
                child: const Text('Pesar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
