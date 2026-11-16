import 'package:flutter/material.dart';

import '../../../compartilhado/cartao_kapta.dart';
import '../dominio/acompanhamento_coleta.dart';

/// Identificação do catador: foto, nome, nota e veículo (segurança visível).
class CartaoCatador extends StatelessWidget {
  const CartaoCatador({super.key, required this.catador});

  final CatadorAtendimento catador;

  @override
  Widget build(BuildContext context) {
    final url = catador.avatarUrl;
    final temFoto = url != null && url.isNotEmpty;
    final nota = catador.avaliacaoMedia;
    final veiculo = catador.veiculoRotulo;
    return CartaoKapta(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            foregroundImage: temFoto ? NetworkImage(url) : null,
            onForegroundImageError: temFoto ? (_, _) {} : null,
            child: Text(
              catador.nome.isEmpty ? '?' : catador.nome[0].toUpperCase(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  catador.nome,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 18, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text(
                          nota == null
                              ? 'Novo'
                              : nota.toStringAsFixed(1).replaceAll('.', ','),
                        ),
                      ],
                    ),
                    if (veiculo != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_shipping_outlined, size: 18),
                          const SizedBox(width: 4),
                          Text(veiculo),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
