import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../nucleo/modelos/papel.dart';
import '../nucleo/repositorios_base/sessao_repositorio.dart';
import '../recursos/auth/apresentacao/providers.dart';
import '../recursos/auth/apresentacao/tela_entrar.dart';
import 'placeholders.dart';

/// Decide o redirecionamento conforme a sessão. Retorna nulo para permitir.
String? redirecionar(SessaoRepositorio sessoes, String local) {
  final sessao = sessoes.atual;
  if (sessao == null) {
    return local == '/entrar' ? null : '/entrar';
  }
  final home = sessao.papel.rotaInicial;
  final ehRotaDoPapel = local == home || local.startsWith('$home/');
  return ehRotaDoPapel ? null : home;
}

/// Notifica o roteador quando a sessão muda. Deve ser descartado por quem o cria.
class AtualizadorSessao extends ChangeNotifier {
  AtualizadorSessao(Stream<Object?> fonte) {
    _sub = fonte.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Cria o roteador do app com guarda por papel.
GoRouter criarRoteador(
  SessaoRepositorio sessoes,
  AtualizadorSessao atualizador,
) {
  return GoRouter(
    initialLocation: '/entrar',
    refreshListenable: atualizador,
    redirect: (context, state) => redirecionar(sessoes, state.uri.path),
    routes: [
      GoRoute(path: '/entrar', builder: (context, state) => const TelaEntrar()),
      for (final p in Papel.values)
        GoRoute(
          path: p.rotaInicial,
          builder: (context, state) => TelaPlaceholderPapel(papel: p),
        ),
    ],
  );
}

final roteadorProvider = Provider<GoRouter>((ref) {
  final sessoes = ref.watch(sessaoRepositorioProvider);
  final atualizador = AtualizadorSessao(sessoes.mudancas);
  final roteador = criarRoteador(sessoes, atualizador);
  // Ordem importa: o roteador remove seu listener antes do atualizador morrer.
  ref.onDispose(() {
    roteador.dispose();
    atualizador.dispose();
  });
  return roteador;
});
