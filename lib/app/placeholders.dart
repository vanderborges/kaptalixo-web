import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../nucleo/modelos/papel.dart';
import '../recursos/auth/apresentacao/providers.dart';

/// Tela provisória de cada papel, até as telas reais serem entregues.
class TelaPlaceholderPapel extends ConsumerWidget {
  const TelaPlaceholderPapel({super.key, required this.papel});

  final Papel papel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(papel.rotulo),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(sessaoRepositorioProvider).sair(),
          ),
        ],
      ),
      body: Center(child: Text('Área: ${papel.rotulo} (em construção)')),
    );
  }
}

/// Provisória (a T2.2 entrega a tela definitiva): catador sem aprovação.
class TelaAguardandoAprovacao extends ConsumerWidget {
  const TelaAguardandoAprovacao({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Cadastro aguardando aprovação.\n'
            'Você poderá ficar disponível depois que a equipe aprovar.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
