import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartilhado/botao_primario.dart';
import '../../../nucleo/modelos/papel.dart';
import '../../../nucleo/repositorios_base/sessao_repositorio.dart';
import 'providers.dart';

/// Tela de entrada. Provisória: com o repositório falso, permite escolher o
/// papel para navegar; o login real vem em outra tarefa.
class TelaEntrar extends ConsumerWidget {
  const TelaEntrar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(sessaoRepositorioProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Entrar')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              Icon(
                Icons.recycling,
                size: 72,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                'Kaptalixo',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Coleta de recicláveis perto de você',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (repo is SessaoRepositorioFake)
                for (final papel in Papel.values) ...[
                  BotaoPrimario(
                    rotulo: 'Entrar como ${papel.rotulo}',
                    onPressed: () => repo.entrarComo(papel),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        ),
      ),
    );
  }
}
