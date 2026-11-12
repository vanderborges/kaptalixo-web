import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'roteador.dart';
import 'tema.dart';

/// Widget raiz do Kaptalixo.
class KaptalixoApp extends StatefulWidget {
  const KaptalixoApp({super.key});

  @override
  State<KaptalixoApp> createState() => _KaptalixoAppState();
}

class _KaptalixoAppState extends State<KaptalixoApp> {
  late final GoRouter _roteador = criarRoteador();

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Kaptalixo',
      theme: criarTema(),
      routerConfig: _roteador,
    );
  }
}
