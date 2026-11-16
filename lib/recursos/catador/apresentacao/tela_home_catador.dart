import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartilhado/estados.dart';
import '../../../nucleo/modelos/status_cadastro.dart';
import '../../auth/apresentacao/providers.dart';
import '../dominio/situacao_catador.dart';
import 'providers.dart';

/// Home do catador (UC14): alternar disponível/offline, com botão grande.
class TelaHomeCatador extends ConsumerWidget {
  const TelaHomeCatador({super.key, this.acoes = const []});

  /// Ações extras da barra (ex.: sair), fornecidas por quem monta a rota.
  final List<Widget> acoes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(disponibilidadeProvider);
    final pode = ref.watch(podeFicarDisponivelProvider);
    final status = ref.watch(sessaoProvider).value?.statusCadastro;
    final emRota = estado.situacao == SituacaoCatador.emRota;
    final tema = Theme.of(context);
    final bloqueado = (!pode && !estado.disponivel) || emRota;

    return Scaffold(
      appBar: AppBar(title: const Text('Kaptalixo'), actions: acoes),
      body: estado.carregando
          ? const EstadoCarregando()
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    emRota
                        ? 'Em rota'
                        : estado.disponivel
                        ? 'Disponível'
                        : 'Offline',
                    textAlign: TextAlign.center,
                    style: tema.textTheme.displaySmall,
                  ),
                  const SizedBox(height: 24),
                  if (!pode)
                    Card(
                      color: tema.colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          status == StatusCadastro.suspenso
                              ? 'Cadastro suspenso. Fale com o suporte.'
                              : 'Aguardando aprovação do cadastro.',
                          textAlign: TextAlign.center,
                          style: tema.textTheme.titleMedium,
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 96,
                    child: FilledButton(
                      onPressed: bloqueado || estado.alternando
                          ? null
                          : () => ref
                                .read(disponibilidadeProvider.notifier)
                                .alternar(),
                      child: estado.alternando
                          ? const CircularProgressIndicator()
                          : Text(
                              estado.disponivel
                                  ? 'Ficar offline'
                                  : 'Ficar disponível',
                              style: tema.textTheme.headlineSmall,
                            ),
                    ),
                  ),
                  if (estado.erro != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      estado.erro!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tema.colorScheme.error),
                    ),
                  ],
                  if (estado.disponivel && estado.semPosicao) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Sem sinal de GPS: sua posição não está sendo enviada.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
