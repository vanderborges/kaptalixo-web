import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../nucleo/modelos/papel.dart';
import '../nucleo/repositorios_base/sessao_repositorio.dart';
import '../recursos/auth/apresentacao/providers.dart';
import '../recursos/auth/apresentacao/tela_cadastro.dart';
import '../recursos/auth/apresentacao/tela_entrar.dart';
import '../recursos/admin/apresentacao/tela_admin.dart';
import '../recursos/admin/apresentacao/tela_catador_admin.dart';
import '../recursos/auth/apresentacao/tela_aguardando_aprovacao.dart';
import 'placeholders.dart';

/// Rotas acessíveis sem login.
const rotasPublicas = {'/entrar', '/cadastrar'};

/// Destino do catador com cadastro pendente/suspenso.
const rotaAguardandoAprovacao = '/catador/aguardando';

/// Decide o redirecionamento conforme a sessão. Retorna nulo para permitir.
String? redirecionar(SessaoRepositorio sessoes, String local) {
  final sessao = sessoes.atual;
  if (sessao == null) {
    return rotasPublicas.contains(local) ? null : '/entrar';
  }
  // Catador ainda não aprovado só vê a tela de espera.
  if (sessao.catadorNaoAprovado) {
    return local == rotaAguardandoAprovacao ? null : rotaAguardandoAprovacao;
  }
  if (local == rotaAguardandoAprovacao) return sessao.papel.rotaInicial;
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
      GoRoute(
        path: '/cadastrar',
        builder: (context, state) => const TelaCadastro(),
      ),
      for (final p in Papel.values)
        GoRoute(
          path: p.rotaInicial,
          builder: (context, state) => p == Papel.admin
              ? const TelaAdmin()
              : TelaPlaceholderPapel(papel: p),
          routes: [
            if (p == Papel.admin)
              GoRoute(
                path: 'catador/:id',
                builder: (context, state) =>
                    TelaCatadorAdmin(catadorId: state.pathParameters['id']!),
              ),
            if (p == Papel.catador)
              GoRoute(
                path: 'aguardando',
                builder: (context, state) => const TelaAguardandoAprovacao(),
              ),
          ],
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
