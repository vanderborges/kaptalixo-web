import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartilhado/botao_primario.dart';
import '../../../nucleo/modelos/status_cadastro.dart';
import '../dominio/falha_auth.dart';
import 'providers.dart';

/// Catador com cadastro pendente ou suspenso (RN10). Permite recarregar o
/// status; quando o admin aprova, o roteador leva o catador à sua área.
class TelaAguardandoAprovacao extends ConsumerStatefulWidget {
  const TelaAguardandoAprovacao({super.key});

  @override
  ConsumerState<TelaAguardandoAprovacao> createState() =>
      _TelaAguardandoAprovacaoState();
}

class _TelaAguardandoAprovacaoState
    extends ConsumerState<TelaAguardandoAprovacao> {
  bool _carregando = false;
  String? _erro;

  Future<void> _recarregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await ref.read(sessaoRepositorioProvider).recarregar();
    } on FalhaAuth catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (_) {
      if (mounted) {
        setState(
          () => _erro = const FalhaAuth(CodigoFalhaAuth.desconhecida).mensagem,
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final status = ref.watch(sessaoProvider).value?.statusCadastro;
    final suspenso = status == StatusCadastro.suspenso;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catador'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessaoRepositorioProvider).sair(),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Icon(
                suspenso ? Icons.block : Icons.hourglass_top,
                size: 72,
                color: suspenso
                    ? tema.colorScheme.error
                    : tema.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                suspenso
                    ? 'Cadastro suspenso'
                    : 'Cadastro aguardando aprovação',
                textAlign: TextAlign.center,
                style: tema.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                suspenso
                    ? 'Seu cadastro foi suspenso pela equipe e você não pode '
                          'receber coletas. Entre em contato com o suporte.'
                    : 'Nossa equipe está analisando seus dados. Você poderá '
                          'ficar disponível e receber coletas assim que for '
                          'aprovado.',
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              if (_erro != null) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _erro!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tema.colorScheme.error),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              BotaoPrimario(
                rotulo: 'Atualizar status',
                icone: Icons.refresh,
                carregando: _carregando,
                onPressed: _recarregar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
