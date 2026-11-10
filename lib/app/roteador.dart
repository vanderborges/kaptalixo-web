import 'package:go_router/go_router.dart';

import '../compartilhado/tela_inicial_placeholder.dart';

/// Cria o roteador do app. As rotas por papel serão adicionadas nas próximas tarefas.
GoRouter criarRoteador() {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const TelaInicialPlaceholder(),
      ),
    ],
  );
}
