import 'package:flutter/material.dart';

/// PIN de coleta em destaque (RN08): o gerador informa ao catador na chegada.
class CartaoPin extends StatelessWidget {
  const CartaoPin({super.key, required this.pin});

  final String pin;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Código de coleta ${pin.split('').join(' ')}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: cores.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ExcludeSemantics(
          child: Column(
            children: [
              Text(
                'Seu código de coleta',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: cores.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                pin.split('').join(' '),
                key: const Key('pin_coleta'),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: cores.onPrimaryContainer,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Só mostre ao catador quando ele chegar.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cores.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
