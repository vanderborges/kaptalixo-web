import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/recursos/catador/apresentacao/ofertas_providers.dart';
import 'package:kaptalixo/recursos/catador/apresentacao/painel_ofertas.dart';
import 'package:kaptalixo/recursos/catador/dados/ofertas_remoto.dart';
import 'package:kaptalixo/recursos/catador/dados/ofertas_repositorio_fake.dart';
import 'package:kaptalixo/recursos/catador/dados/ofertas_repositorio_impl.dart';
import 'package:kaptalixo/recursos/catador/dominio/falha_catador.dart';
import 'package:kaptalixo/recursos/catador/dominio/oferta_resumo.dart';

final _t0 = DateTime.utc(2026, 1, 1, 12);

OfertaResumo _oferta(String id, {int segundos = 45, String? bairro}) =>
    OfertaResumo(
      ofertaId: id,
      solicitacaoId: 's-$id',
      distanciaM: 800,
      etaS: 300,
      qtdSacos: 3,
      enviadaEm: _t0,
      expiraEm: _t0.add(Duration(seconds: segundos)),
      bairro: bairro ?? 'Centro',
    );

class _Cena {
  _Cena(this.repo);
  final OfertasRepositorioFake repo;
  Duration decorrido = Duration.zero;
  DateTime agora() => _t0.add(decorrido);
}

Future<_Cena> _montar(
  WidgetTester t,
  OfertasRepositorioFake repo, {
  void Function(String)? aoAceitar,
}) async {
  final c = _Cena(repo);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        ofertasRepositorioProvider.overrideWithValue(repo),
        relogioProvider.overrideWithValue(c.agora),
      ],
      child: MaterialApp(
        home: Scaffold(body: PainelOfertas(aoAceitar: aoAceitar)),
      ),
    ),
  );
  await t.pump();
  await t.pump();
  return c;
}

Future<void> _avancar(WidgetTester t, _Cena c, int s) async {
  for (var i = 0; i < s; i++) {
    c.decorrido += const Duration(seconds: 1);
    await t.pump(const Duration(seconds: 1));
  }
}

void main() {
  testWidgets('mostra resumo sem endereço e conta regressivamente', (t) async {
    final repo = OfertasRepositorioFake(inicial: [_oferta('o1')]);
    final c = await _montar(t, repo);

    expect(find.text('3 sacos'), findsOneWidget);
    expect(find.text('800 m · 5 min'), findsOneWidget);
    expect(find.text('Centro'), findsOneWidget);
    expect(find.text('45s'), findsOneWidget);

    await _avancar(t, c, 10);
    expect(find.text('35s'), findsOneWidget);
  });

  testWidgets('ao expirar localmente chama expirar e esconde o cartão', (
    t,
  ) async {
    final repo = OfertasRepositorioFake(inicial: [_oferta('o1', segundos: 3)]);
    final c = await _montar(t, repo);
    expect(find.byKey(const Key('cartao-oferta')), findsOneWidget);
    expect(repo.chamadasExpirar, 0);

    await _avancar(t, c, 3);
    expect(find.byKey(const Key('cartao-oferta')), findsNothing);
    expect(repo.chamadasExpirar, 1);

    await _avancar(t, c, 5);
    expect(repo.chamadasExpirar, 1);
  });

  testWidgets('nova oferta chega pelo Realtime', (t) async {
    final repo = OfertasRepositorioFake();
    await _montar(t, repo);
    expect(find.byKey(const Key('cartao-oferta')), findsNothing);

    repo.emitir([_oferta('o2')]);
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('cartao-oferta')), findsOneWidget);
  });

  testWidgets('aceitar chama RPC e devolve a rota', (t) async {
    String? rota;
    final repo = OfertasRepositorioFake(inicial: [_oferta('o1')]);
    await _montar(t, repo, aoAceitar: (r) => rota = r);

    await t.tap(find.text('Aceitar'));
    await t.pump();
    await t.pump();
    await t.pump();
    await t.pump();

    expect(repo.aceitas, ['o1']);
    expect(rota, 'rota-1');
    expect(find.byKey(const Key('cartao-oferta')), findsNothing);
  });

  testWidgets('oferta indisponível: avisa e esconde o cartão', (t) async {
    final repo = OfertasRepositorioFake(
      inicial: [_oferta('o1')],
      falhaAceitar: const FalhaCatador(MotivoFalhaCatador.ofertaIndisponivel),
    );
    await _montar(t, repo);

    await t.tap(find.text('Aceitar'));
    await t.pump();
    await t.pump();
    await t.pump();
    await t.pump();

    expect(find.textContaining('Oferta indisponível'), findsOneWidget);
    expect(find.byKey(const Key('cartao-oferta')), findsNothing);
  });

  testWidgets('recusar chama RPC e esconde o cartão', (t) async {
    final repo = OfertasRepositorioFake(inicial: [_oferta('o1')]);
    await _montar(t, repo);

    await t.tap(find.text('Recusar'));
    await t.pump();
    await t.pump();
    await t.pump();
    await t.pump();

    expect(repo.recusadas, ['o1']);
    expect(find.byKey(const Key('cartao-oferta')), findsNothing);
  });

  testWidgets('ao sair da tela cancela a assinatura e o timer', (t) async {
    final repo = OfertasRepositorioFake(inicial: [_oferta('o1')]);
    await _montar(t, repo);
    expect(repo.assinaturas, 1);

    await t.pumpWidget(const SizedBox());
    await t.pump();
    await t.pump();
    expect(repo.cancelamentos, 1);
  });

  group('FalhaCatador.deCodigo', () {
    test('mapeia códigos das RPCs de oferta', () {
      expect(
        MotivoFalhaCatador.deCodigo('oferta_indisponivel'),
        MotivoFalhaCatador.ofertaIndisponivel,
      );
      expect(
        MotivoFalhaCatador.deCodigo('oferta_expirada'),
        MotivoFalhaCatador.ofertaExpirada,
      );
      expect(
        MotivoFalhaCatador.deCodigo('sem_capacidade'),
        MotivoFalhaCatador.semCapacidade,
      );
      expect(
        MotivoFalhaCatador.deCodigo('catador_indisponivel'),
        MotivoFalhaCatador.indisponivel,
      );
    });
  });

  group('OfertasRepositorioImpl', () {
    test('converte linhas da view e recarrega nas mudanças', () async {
      final remoto = _RemotoFake();
      final repo = OfertasRepositorioImpl(remoto);
      final it = <List<OfertaResumo>>[];
      final sub = repo.observar().listen(it.add);
      await Future<void>.delayed(Duration.zero);
      expect(it.single.single.ofertaId, 'o1');
      expect(it.single.single.distanciaM, 800);

      remoto.linhas = [];
      remoto.ctrl.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(it.last, isEmpty);
      await sub.cancel();
    });
  });
}

class _RemotoFake implements OfertasRemoto {
  List<Map<String, dynamic>> linhas = [
    {
      'oferta_id': 'o1',
      'solicitacao_id': 's1',
      'distancia_m': 800,
      'eta_s': 300,
      'qtd_sacos': 2,
      'expira_em': '2026-01-01T12:00:45Z',
      'enviada_em': '2026-01-01T12:00:00Z',
      'materiais': [1, 2],
    },
  ];
  final ctrl = StreamController<void>.broadcast();

  @override
  Future<List<Map<String, dynamic>>> buscarPendentes() async => linhas;
  @override
  Stream<void> mudancas() => ctrl.stream;
  @override
  Future<String> aceitar(String ofertaId) async => 'r';
  @override
  Future<void> recusar(String ofertaId) async {}
  @override
  Future<int> expirar() async => 0;
}
