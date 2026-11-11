import 'package:flutter/material.dart';

/// Cartão base; clicável quando [onTap] é informado.
class CartaoKapta extends StatelessWidget {
  const CartaoKapta({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}
