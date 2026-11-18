import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/nucleo/localizacao/localizacao_fake.dart';
import 'package:kaptalixo/recursos/catador/dados/ofertas_repositorio_fake.dart';
import 'package:kaptalixo/recursos/catador/dados/rota_repositorio_fake.dart';
import 'package:kaptalixo/recursos/catador/dominio/oferta_resumo.dart';
import 'package:kaptalixo/recursos/catador/dominio/rota_ativa.dart';
import 'package:latlong2/latlong.dart';

import 'rota_fixtures.dart';

OfertaResumo _extra(RelogioTeste r, {bool naRota = true}) => OfertaResumo(
  ofertaId: 'of-extra',
  solicitacaoId: 'sol-3',
  distanciaM: 600,
  etaS: 240,
  qtdSacos: 2,
  enviadaEm: r.inicio,
  expiraEm: r.inicio.add(const Duration(seconds: 45)),
  bairro: 'Vila Nova',
  naRota: naRota,
);

LocalizacaoFake _longe() =>
    LocalizacaoFake()..emitirPonto(const LatLng(-23.60, -46.70));

/// Rota com a coleta extra encaixada antes do descarte (como o servidor).
RotaAtiva _comExtra(RotaAtiva base) => base.copiar(
  versao: base.versao + 1,
  paradas: [
    ...base.paradas.where((p) => p.tipo == TipoParada.coleta),
    const ParadaRota(
      id: 'par-4',
      ordem: 3,
      tipo: TipoParada.coleta,
      status: StatusParada.pendente,
      posicao: LatLng(-23.545, -46.63),
      solicitacaoId: 'sol-3',
      qtdSacos: 2,
      enderecoTexto: 'Rua Nova, 3',
      geradorNome: 'Ana',
    ),
    base.paradas.last,
  ],
);

void main() {
  testWidgets('oferta extra na rota em andamento mostra a tag e a contagem', (
    t,
  ) async {
    final relogio = RelogioTeste();
    final rotas = RotaRepositorioFake(
      rota: rotaDemo(),
      pins: pinsDemo,
      relogio: relogio.agora,
    );
    await rotas.iniciar('rota-1');
    final ofertas = OfertasRepositorioFake(inicial: [_extra(relogio)]);
    await montarRota(
      t,
      repo: rotas,
      gps: _longe(),
      relogio: relogio,
      ofertas: ofertas,
    );

    expect(find.byKey(const Key('cartao-oferta')), findsOneWidget);
    expect(find.byKey(const Key('tag-na-rota')), findsOneWidget);
    expect(find.text('Na sua rota'), findsOneWidget);
    expect(find.text('45s'), findsOneWidget);
    expect(find.text('Vila Nova'), findsOneWidget);
    // endereço exato só depois do aceite
    expect(find.text('Rua Nova, 3'), findsNothing);
    await avancar(t, relogio, 5);
    expect(find.text('40s'), findsOneWidget);
  });

  testWidgets('sem rota ativa (planejada) não mostra o painel de ofertas', (
    t,
  ) async {
    final relogio = RelogioTeste();
    final rotas = RotaRepositorioFake(
      rota: rotaDemo(),
      pins: pinsDemo,
      relogio: relogio.agora,
    );
    final ofertas = OfertasRepositorioFake(inicial: [_extra(relogio)]);
    await montarRota(
      t,
      repo: rotas,
      gps: _longe(),
      relogio: relogio,
      ofertas: ofertas,
    );
    expect(find.byKey(const Key('cartao-oferta')), findsNothing);
    expect(ofertas.assinaturas, 0);
  });

  testWidgets('aceitar replaneja, atualiza as paradas e esconde o cartão', (
    t,
  ) async {
    final relogio = RelogioTeste();
    final rotas = RotaRepositorioFake(
      rota: rotaDemo(),
      pins: pinsDemo,
      relogio: relogio.agora,
    );
    await rotas.iniciar('rota-1');
    final ofertas = OfertasRepositorioFake(
      inicial: [_extra(relogio)],
      rotaId: 'rota-1',
    );
    final replanejadas = <String>[];
    await montarRota(
      t,
      repo: rotas,
      gps: _longe(),
      relogio: relogio,
      ofertas: ofertas,
      aoReplanejar: (id) async {
        replanejadas.add(id);
        rotas.emitir(_comExtra(rotas.rota!));
      },
    );
    expect(find.text('Coleta 1 de 2'), findsOneWidget);

    await t.tap(find.text('Aceitar'));
    await t.pump();
    await t.pump();
    await t.pump();

    expect(ofertas.aceitas, ['of-extra']);
    expect(replanejadas, ['rota-1']);
    expect(find.text('Coleta 1 de 3'), findsOneWidget);
    expect(find.byKey(const Key('marcador-par-4')), findsOneWidget);
    expect(find.byKey(const Key('cartao-oferta')), findsNothing);
    expect(find.text('Cheguei'), findsOneWidget);
  });

  testWidgets('recusar esconde o cartão sem mexer na rota', (t) async {
    final relogio = RelogioTeste();
    final rotas = RotaRepositorioFake(
      rota: rotaDemo(),
      pins: pinsDemo,
      relogio: relogio.agora,
    );
    await rotas.iniciar('rota-1');
    final ofertas = OfertasRepositorioFake(inicial: [_extra(relogio)]);
    var replanejou = false;
    await montarRota(
      t,
      repo: rotas,
      gps: _longe(),
      relogio: relogio,
      ofertas: ofertas,
      aoReplanejar: (_) async => replanejou = true,
    );
    await t.tap(find.text('Recusar'));
    await t.pump();
    await t.pump();
    expect(ofertas.recusadas, ['of-extra']);
    expect(replanejou, isFalse);
    expect(find.byKey(const Key('cartao-oferta')), findsNothing);
    expect(find.text('Coleta 1 de 2'), findsOneWidget);
  });

  testWidgets('falha ao replanejar não impede atualizar a tela', (t) async {
    final relogio = RelogioTeste();
    final rotas = RotaRepositorioFake(
      rota: rotaDemo(),
      pins: pinsDemo,
      relogio: relogio.agora,
    );
    await rotas.iniciar('rota-1');
    final ofertas = OfertasRepositorioFake(inicial: [_extra(relogio)]);
    await montarRota(
      t,
      repo: rotas,
      gps: _longe(),
      relogio: relogio,
      ofertas: ofertas,
      aoReplanejar: (_) async => throw Exception('offline'),
    );
    await t.tap(find.text('Aceitar'));
    await t.pump();
    await t.pump();
    await t.pump();
    expect(ofertas.aceitas, ['of-extra']);
    expect(find.byKey(const Key('cartao-oferta')), findsNothing);
  });
}
