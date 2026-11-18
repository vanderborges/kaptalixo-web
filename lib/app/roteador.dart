import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../nucleo/modelos/papel.dart';
import '../nucleo/repositorios_base/sessao_repositorio.dart';
import '../recursos/auth/apresentacao/providers.dart';
import '../recursos/auth/apresentacao/tela_cadastro.dart';
import '../recursos/auth/apresentacao/tela_entrar.dart';
import '../recursos/admin/apresentacao/tela_admin.dart';
import '../recursos/admin/apresentacao/tela_catador_admin.dart';
import '../recursos/auth/apresentacao/tela_aguardando_aprovacao.dart';
import '../recursos/admin/apresentacao/tela_demo.dart';
import '../recursos/catador/apresentacao/tela_home_catador.dart';
import '../recursos/catador/apresentacao/tela_rota_ativa.dart';
import '../recursos/gerador/apresentacao/tela_acompanhamento.dart';
import '../recursos/gerador/apresentacao/tela_chamar_coleta.dart';
import '../recursos/gerador/apresentacao/tela_home_gerador.dart';
import '../recursos/ponto/apresentacao/tela_painel_ponto.dart';
import 'acoes_app.dart';

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

/// Tela inicial de cada papel (as telas reais de cada feature).
Widget _telaInicial(Papel p) => switch (p) {
  Papel.admin => const TelaAdmin(),
  Papel.gerador => Consumer(
    builder: (context, ref, _) => TelaHomeGerador(
      tileProvider: ref.watch(tileProviderAppProvider),
      acoes: const [BotaoSair()],
    ),
  ),
  Papel.catador => Consumer(
    builder: (context, ref, _) => TelaHomeCatador(
      acoes: const [BotaoSair()],
      aoAceitarOferta: (rotaId) {
        // Dispara o planejamento (ordem, ETA, ponto de descarte); a rota abre
        // já e a tela atualiza quando o servidor gravar o resultado.
        unawaited(
          ref.read(planejarRotaProvider)(rotaId).catchError((Object _) {}),
        );
        context.go('/catador/rota/$rotaId');
      },
    ),
  ),
  Papel.ponto => const TelaPainelPonto(acoes: [BotaoSair()]),
};

/// Redireciona na próxima frame para [destino] (rota que exige `extra`).
class _VoltarAoInicio extends StatefulWidget {
  const _VoltarAoInicio(this.destino);

  final String destino;

  @override
  State<_VoltarAoInicio> createState() => _VoltarAoInicioState();
}

class _VoltarAoInicioState extends State<_VoltarAoInicio> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go(widget.destino);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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
          builder: (context, state) => _telaInicial(p),
          routes: [
            if (p == Papel.gerador) ...[
              GoRoute(
                path: 'chamar',
                builder: (context, state) {
                  final posicao = state.extra;
                  if (posicao is! LatLng) {
                    // Sem posição (ex.: recarga da página): volta ao início.
                    return const _VoltarAoInicio('/gerador');
                  }
                  return Consumer(
                    builder: (context, ref, _) => TelaChamarColeta(
                      posicaoInicial: posicao,
                      tileProvider: ref.watch(tileProviderAppProvider),
                      aoCriada: (id) => context.go('/gerador/acompanhar/$id'),
                    ),
                  );
                },
              ),
              GoRoute(
                path: 'acompanhar/:id',
                builder: (context, state) => Consumer(
                  builder: (context, ref, _) => TelaAcompanhamento(
                    solicitacaoId: state.pathParameters['id']!,
                    tileProvider: ref.watch(tileProviderAppProvider),
                    aoSair: () => context.go('/gerador'),
                    aoNovaChamada: () => context.go('/gerador'),
                  ),
                ),
              ),
            ],
            if (p == Papel.catador)
              GoRoute(
                path: 'rota/:id',
                builder: (context, state) => Consumer(
                  builder: (context, ref, _) => TelaRotaAtiva(
                    rotaId: state.pathParameters['id']!,
                    acoes: const [BotaoSair()],
                    tileProvider: ref.watch(tileProviderAppProvider),
                    aoSair: () => context.go('/catador'),
                    aoReplanejar: (id) => ref.read(planejarRotaProvider)(id),
                  ),
                ),
              ),
            if (p == Papel.admin)
              GoRoute(
                path: 'demo',
                builder: (context, state) => Consumer(
                  builder: (context, ref, _) => TelaDemo(
                    tileProvider: ref.watch(tileProviderAppProvider),
                  ),
                ),
              ),
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
