import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../recursos/auth/apresentacao/providers.dart';

/// Provedor de tiles repassado às telas com mapa. Nulo = padrão da rede;
/// testes sobrescrevem com um provedor sem rede.
final tileProviderAppProvider = Provider<TileProvider?>((ref) => null);

/// Botão "Sair" da barra de qualquer papel.
class BotaoSair extends ConsumerWidget {
  const BotaoSair({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => IconButton(
    tooltip: 'Sair',
    icon: const Icon(Icons.logout),
    onPressed: () => ref.read(sessaoRepositorioProvider).sair(),
  );
}
