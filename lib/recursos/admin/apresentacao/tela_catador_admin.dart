import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../compartilhado/botao_primario.dart';
import '../../../compartilhado/estados.dart';
import '../../../nucleo/modelos/catador_cadastro.dart';
import '../../../nucleo/modelos/status_cadastro.dart';
import 'providers.dart';
import 'tela_admin.dart' show mensagemDeErro;

/// Detalhe do cadastro de um catador, com aprovar/suspender (UC02).
class TelaCatadorAdmin extends ConsumerStatefulWidget {
  const TelaCatadorAdmin({super.key, required this.catadorId});

  final String catadorId;

  @override
  ConsumerState<TelaCatadorAdmin> createState() => _TelaCatadorAdminState();
}

class _TelaCatadorAdminState extends ConsumerState<TelaCatadorAdmin> {
  bool _salvando = false;
  String? _erro;

  void _voltar() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/admin');
    }
  }

  Future<void> _alterar(CatadorCadastro c, StatusCadastro novo) async {
    if (!await _confirmar(c, novo)) {
      return;
    }
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await ref
          .read(catadoresAdminRepositorioProvider)
          .alterarStatus(c.id, novo);
      ref.invalidate(catadoresListaProvider);
      ref.invalidate(catadorDetalheProvider(c.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            novo == StatusCadastro.aprovado
                ? '${c.nome} aprovado.'
                : '${c.nome} suspenso.',
          ),
        ),
      );
      _voltar();
    } catch (e) {
      if (mounted) setState(() => _erro = mensagemDeErro(e));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<bool> _confirmar(CatadorCadastro c, StatusCadastro novo) async {
    final suspender = novo == StatusCadastro.suspenso;
    final reativar = c.statusCadastro == StatusCadastro.suspenso;
    if (!suspender && !reativar) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(suspender ? 'Suspender catador?' : 'Reativar catador?'),
        content: Text('${c.nome} não poderá receber coletas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(suspender ? 'Suspender' : 'Reativar'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final detalhe = ref.watch(catadorDetalheProvider(widget.catadorId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro do catador'),
        leading: BackButton(onPressed: _voltar),
      ),
      body: detalhe.when(
        loading: () => const EstadoCarregando(),
        error: (e, _) => EstadoErro(
          mensagem: mensagemDeErro(e),
          aoTentarNovamente: () =>
              ref.invalidate(catadorDetalheProvider(widget.catadorId)),
        ),
        data: _conteudo,
      ),
    );
  }

  Widget _conteudo(CatadorCadastro c) {
    final tema = Theme.of(context);
    final linhas = <(String, String?)>[
      ('Tipo', c.tipo.rotulo),
      ('Situação do cadastro', c.statusCadastro.rotulo),
      ('Telefone', c.telefone),
      ('Documento', c.documento),
      ('Razão social', c.razaoSocial),
      ('Veículo', c.tipoVeiculo),
      (
        'Capacidade',
        c.capacidadeSacos == null ? null : '${c.capacidadeSacos} sacos',
      ),
    ];
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(c.nome, style: tema.textTheme.headlineSmall),
            const SizedBox(height: 16),
            for (final (rotulo, valor) in linhas)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 160,
                      child: Text(rotulo, style: tema.textTheme.labelLarge),
                    ),
                    Expanded(
                      child: Text(
                        (valor == null || valor.isEmpty) ? '—' : valor,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            if (_erro != null) ...[
              Semantics(
                liveRegion: true,
                child: Text(
                  _erro!,
                  style: TextStyle(color: tema.colorScheme.error),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (c.statusCadastro != StatusCadastro.aprovado)
              BotaoPrimario(
                rotulo: c.statusCadastro == StatusCadastro.suspenso
                    ? 'Reativar (aprovar)'
                    : 'Aprovar',
                icone: Icons.check_circle_outline,
                carregando: _salvando,
                onPressed: () => _alterar(c, StatusCadastro.aprovado),
              ),
            if (c.statusCadastro != StatusCadastro.suspenso) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: _salvando
                      ? null
                      : () => _alterar(c, StatusCadastro.suspenso),
                  icon: const Icon(Icons.block),
                  label: const Text('Suspender'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
