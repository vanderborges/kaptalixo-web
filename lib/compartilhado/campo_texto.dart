import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de texto de formulário com rótulo fixo, validação e alvo >= 48 dp.
class CampoTexto extends StatelessWidget {
  const CampoTexto({
    super.key,
    required this.controlador,
    required this.rotulo,
    this.validador,
    this.tipoTeclado,
    this.obscuro = false,
    this.autofillHints,
    this.formatadores,
    this.acaoTeclado,
    this.ajuda,
  });

  final TextEditingController controlador;
  final String rotulo;
  final String? Function(String?)? validador;
  final TextInputType? tipoTeclado;
  final bool obscuro;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? formatadores;
  final TextInputAction? acaoTeclado;
  final String? ajuda;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controlador,
        validator: validador,
        keyboardType: tipoTeclado,
        obscureText: obscuro,
        autofillHints: autofillHints,
        inputFormatters: formatadores,
        textInputAction: acaoTeclado ?? TextInputAction.next,
        decoration: InputDecoration(
          labelText: rotulo,
          helperText: ajuda,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
