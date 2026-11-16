import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dados/ponto_repositorio_fake.dart';
import '../dominio/entrega_a_caminho.dart';
import '../dominio/pesagem.dart';
import '../dominio/ponto_repositorio.dart';

/// Repositório do painel do ponto. Padrão: fake; `main.dart` troca pelo
/// `PontoRepositorioImpl(PontoRemotoSupabase(client))` (ver PEDIDOS P-023).
final pontoRepositorioProvider = Provider<PontoRepositorio>(
  (ref) => PontoRepositorioFake(),
);

/// Entregas a caminho (Realtime), da mais próxima para a mais distante.
final entregasACaminhoProvider =
    StreamProvider.autoDispose<List<EntregaACaminho>>(
      (ref) => ref.watch(pontoRepositorioProvider).observarEntregas(),
    );

/// Tabela de preços vigente do ponto.
final precosPontoProvider = FutureProvider.autoDispose<List<MaterialPreco>>(
  (ref) => ref.watch(pontoRepositorioProvider).precos(),
);

/// Intervalo de atualização dos ETAs na tela (testes podem sobrescrever).
final tickPontoProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 15),
);

/// Relógio injetável do painel do ponto.
final relogioPontoProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
