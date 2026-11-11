import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'roteador.dart';
import 'tema.dart';

/// Widget raiz do Kaptalixo.
class KaptalixoApp extends ConsumerWidget {
  const KaptalixoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Kaptalixo',
      theme: criarTema(),
      darkTheme: criarTemaEscuro(),
      routerConfig: ref.watch(roteadorProvider),
    );
  }
}
