import 'package:flutter/material.dart';

/// Tema do Kaptalixo (verde reciclagem).
ThemeData criarTema() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B7F4B)),
    useMaterial3: true,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}
