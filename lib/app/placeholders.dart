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
