import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dominio/oferta_resumo.dart';
import 'ofertas_providers.dart';

/// Cartão da oferta atual (UC05): só o necessário para decidir. Sem endereço
/// exato (só após o aceite) e sem PIN.
class PainelOfertas extends ConsumerWidget {
  const PainelOfertas({super.key, this.aoAceitar});

  /// Chamado com o id da rota criada no aceite (a tela da rota é da T5.3).
  final FutureOr<void> Function(String rotaId)? aoAceitar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(ofertasProvider);
    final tema = Theme.of(context);
    final oferta = estado.atual;
    final aviso = estado.aviso;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (aviso != null)
          Card(
            color: tema.colorScheme.errorContainer,
            child: ListTile(
              title: Text(aviso, style: tema.textTheme.titleMedium),
              trailing: IconButton(
                tooltip: 'Fechar aviso',
                icon: const Icon(Icons.close),
                onPressed: () =>
                    ref.read(ofertasProvider.notifier).limparAviso(),
              ),
            ),
          ),
        if (oferta != null)
          _CartaoOferta(
            oferta: oferta,
            segundos: estado.segundosRestantes,
            respondendo: estado.respondendo,
            aoAceitar: () async {
              final ok = await ref.read(ofertasProvider.notifier).aceitar();
              final rota = ref.read(ofertasProvider).rotaId;
              if (ok && rota != null) aoAceitar?.call(rota);
            },
            aoRecusar: () => ref.read(ofertasProvider.notifier).recusar(),
          ),
      ],
    );
  }
}

String _distancia(int m) =>
    m >= 1000 ? '${(m / 1000).toStringAsFixed(1)} km' : '$m m';

String _eta(int s) => '${(s / 60).round()} min';

class _CartaoOferta extends StatelessWidget {
  const _CartaoOferta({
    required this.oferta,
    required this.segundos,
    required this.respondendo,
    required this.aoAceitar,
    required this.aoRecusar,
  });

  final OfertaResumo oferta;
  final int segundos;
  final bool respondendo;
  final VoidCallback aoAceitar;
  final VoidCallback aoRecusar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final total = oferta.janela.inSeconds;
    final progresso = total == 0 ? 0.0 : (segundos / total).clamp(0.0, 1.0);
    final sacos = oferta.qtdSacos == 1 ? '1 saco' : '${oferta.qtdSacos} sacos';

    return Card(
      key: const Key('cartao-oferta'),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              oferta.naRota ? 'Coleta extra' : 'Nova coleta',
              style: tema.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              sacos,
              style: tema.textTheme.displaySmall,
              textAlign: TextAlign.center,
            ),
            Text(
              '${_distancia(oferta.distanciaM)} · ${_eta(oferta.etaS)}',
              style: tema.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            if (oferta.bairro != null)
              Text(
                oferta.bairro!,
                style: tema.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            if (oferta.naRota)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Center(
                  child: Chip(
                    key: const Key('tag-na-rota'),
                    avatar: const Icon(Icons.route),
                    label: Text(
                      'Na sua rota',
                      style: tema.textTheme.titleMedium,
                    ),
                    backgroundColor: tema.colorScheme.tertiaryContainer,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Semantics(
              label: '$segundos segundos para responder',
              child: LinearProgressIndicator(value: progresso, minHeight: 10),
            ),
            const SizedBox(height: 4),
            Text(
              '${segundos}s',
              key: const Key('contagem-oferta'),
              style: tema.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
              child: FilledButton(
                onPressed: respondendo ? null : aoAceitar,
                child: Text('Aceitar', style: tema.textTheme.headlineSmall),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: respondendo ? null : aoRecusar,
                child: Text('Recusar', style: tema.textTheme.titleLarge),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
