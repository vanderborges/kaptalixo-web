import 'package:flutter/material.dart';

/// Botão primário (largura total, alvo de toque >= 48 dp).
class BotaoPrimario extends StatelessWidget {
  const BotaoPrimario({
    super.key,
    required this.rotulo,
    required this.onPressed,
    this.icone,
    this.carregando = false,
  });

  final String rotulo;
  final VoidCallback? onPressed;
  final IconData? icone;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    final aoPressionar = carregando ? null : onPressed;
    final filho = carregando
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(rotulo);
    final estilo = FilledButton.styleFrom(minimumSize: const Size(48, 48));
    return SizedBox(
      width: double.infinity,
      child: icone == null || carregando
          ? FilledButton(onPressed: aoPressionar, style: estilo, child: filho)
          : FilledButton.icon(
              onPressed: aoPressionar,
              style: estilo,
              icon: Icon(icone),
              label: filho,
            ),
    );
  }
}
