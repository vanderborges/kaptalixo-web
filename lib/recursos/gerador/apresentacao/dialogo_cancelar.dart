import 'package:flutter/material.dart';

/// Pede confirmação (e motivo opcional). Devolve nulo se o gerador desistiu;
/// caso contrário o motivo (vazio = sem motivo).
Future<String?> confirmarCancelamento(
  BuildContext context, {
  required bool comCatador,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _DialogoCancelar(comCatador: comCatador),
  );
}

class _DialogoCancelar extends StatefulWidget {
  const _DialogoCancelar({required this.comCatador});

  final bool comCatador;

  @override
  State<_DialogoCancelar> createState() => _EstadoDialogo();
}

class _EstadoDialogo extends State<_DialogoCancelar> {
  final _motivo = TextEditingController();

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancelar a coleta?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.comCatador
                ? 'O catador será avisado de que você cancelou.'
                : 'Vamos parar de procurar um catador.',
          ),
          if (widget.comCatador) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _motivo,
              maxLength: 140,
              decoration: const InputDecoration(labelText: 'Motivo (opcional)'),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Voltar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_motivo.text.trim()),
          child: const Text('Cancelar coleta'),
        ),
      ],
    );
  }
}
