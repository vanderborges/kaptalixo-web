import 'package:flutter/material.dart';

const _semente = Color(0xFF1B7F4B);

ThemeData _tema(Brightness brilho) {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: _semente, brightness: brilho),
    useMaterial3: true,
    materialTapTargetSize: MaterialTapTargetSize.padded,
  );
}

/// Tema claro (verde reciclagem).
ThemeData criarTema() => _tema(Brightness.light);

/// Tema escuro.
ThemeData criarTemaEscuro() => _tema(Brightness.dark);
