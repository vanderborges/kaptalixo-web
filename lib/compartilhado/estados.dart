import 'package:flutter/material.dart';

class _EstadoBase extends StatelessWidget {
  const _EstadoBase({required this.icone, required this.mensagem, this.acao});

  final Widget icone;
  final String mensagem;
  final Widget? acao;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            icone,
            const SizedBox(height: 16),
            Text(
              mensagem,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (acao != null) ...[const SizedBox(height: 16), acao!],
          ],
        ),
      ),
    );
  }
}

/// Estado vazio (sem dados).
class EstadoVazio extends StatelessWidget {
  const EstadoVazio({super.key, required this.mensagem, this.acao});

  final String mensagem;
  final Widget? acao;

  @override
  Widget build(BuildContext context) => _EstadoBase(
    icone: Icon(
      Icons.inbox_outlined,
      size: 56,
      color: Theme.of(context).colorScheme.outline,
    ),
    mensagem: mensagem,
    acao: acao,
  );
}

/// Estado de carregamento.
class EstadoCarregando extends StatelessWidget {
  const EstadoCarregando({super.key, this.mensagem = 'Carregando...'});

  final String mensagem;

  @override
  Widget build(BuildContext context) =>
      _EstadoBase(icone: const CircularProgressIndicator(), mensagem: mensagem);
}

/// Estado de erro, com botão opcional de nova tentativa.
class EstadoErro extends StatelessWidget {
  const EstadoErro({
    super.key,
    this.mensagem = 'Algo deu errado. Tente novamente.',
    this.aoTentarNovamente,
  });

  final String mensagem;
  final VoidCallback? aoTentarNovamente;

  @override
  Widget build(BuildContext context) => _EstadoBase(
    icone: Icon(
      Icons.error_outline,
      size: 56,
      color: Theme.of(context).colorScheme.error,
    ),
    mensagem: mensagem,
    acao: aoTentarNovamente == null
        ? null
        : OutlinedButton(
            onPressed: aoTentarNovamente,
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text('Tentar novamente'),
          ),
  );
}
