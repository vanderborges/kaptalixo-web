import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../compartilhado/cartao_kapta.dart';
import '../../../compartilhado/estados.dart';
import '../../../nucleo/modelos/catador_cadastro.dart';
import '../../../nucleo/modelos/status_cadastro.dart';
import '../../auth/apresentacao/providers.dart' show sessaoRepositorioProvider;
import '../dominio/falha_admin.dart';
import 'providers.dart';

String mensagemDeErro(Object erro) => erro is FalhaAdmin
    ? erro.mensagem
    : const FalhaAdmin(CodigoFalhaAdmin.desconhecida).mensagem;

/// Painel do admin: cadastros de catador por situação (UC02).
class TelaAdmin extends ConsumerWidget {
  const TelaAdmin({super.key});

  static const _rotulosFiltro = {
    StatusCadastro.pendente: 'Pendentes',
    StatusCadastro.aprovado: 'Aprovados',
    StatusCadastro.suspenso: 'Suspensos',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtro = ref.watch(filtroStatusAdminProvider);
    final lista = ref.watch(catadoresListaProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrador'),
        actions: [
          IconButton(
            tooltip: 'Atualizar lista',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(catadoresListaProvider),
          ),
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessaoRepositorioProvider).sair(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<StatusCadastro>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(minimumSize: const Size(48, 48)),
              segments: [
                for (final e in _rotulosFiltro.entries)
                  ButtonSegment(value: e.key, label: Text(e.value)),
              ],
              selected: {filtro},
              onSelectionChanged: (s) =>
                  ref.read(filtroStatusAdminProvider.notifier).definir(s.first),
            ),
          ),
          Expanded(
            child: lista.when(
              loading: () =>
                  const EstadoCarregando(mensagem: 'Carregando catadores...'),
              error: (e, _) => EstadoErro(
                mensagem: mensagemDeErro(e),
                aoTentarNovamente: () => ref.invalidate(catadoresListaProvider),
              ),
              data: (itens) => itens.isEmpty
                  ? EstadoVazio(
                      mensagem:
                          'Nenhum catador ${_rotulosFiltro[filtro]!.toLowerCase()}.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: itens.length,
                      itemBuilder: (context, i) => _ItemCatador(itens[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCatador extends StatelessWidget {
  const _ItemCatador(this.catador);

  final CatadorCadastro catador;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return CartaoKapta(
      onTap: () => context.go('/admin/catador/${catador.id}'),
      child: Row(
        children: [
          Icon(
            catador.tipo.name == 'empresa' ? Icons.business : Icons.person,
            semanticLabel: catador.tipo.rotulo,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(catador.nome, style: tema.textTheme.titleMedium),
                Text(
                  '${catador.tipo.rotulo} · ${catador.statusCadastro.rotulo}',
                  style: tema.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
