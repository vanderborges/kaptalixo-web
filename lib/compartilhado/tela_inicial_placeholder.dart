import 'package:flutter/material.dart';

/// Tela inicial provisória até a implementação de login e papéis.
class TelaInicialPlaceholder extends StatelessWidget {
  const TelaInicialPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.recycling,
              size: 72,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Kaptalixo',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text('Coleta de recicláveis perto de você'),
          ],
        ),
      ),
    );
  }
}
