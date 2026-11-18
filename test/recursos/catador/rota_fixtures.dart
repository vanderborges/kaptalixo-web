import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/nucleo/localizacao/providers.dart';
import 'package:kaptalixo/nucleo/localizacao/servico_localizacao.dart';
import 'package:kaptalixo/nucleo/mapas/servico_rotas_fake.dart';
import 'package:kaptalixo/recursos/catador/apresentacao/ofertas_providers.dart';
import 'package:kaptalixo/recursos/catador/apresentacao/rota_providers.dart';
import 'package:kaptalixo/recursos/catador/dominio/ofertas_repositorio.dart';
import 'package:kaptalixo/recursos/catador/apresentacao/tela_rota_ativa.dart';
import 'package:kaptalixo/recursos/catador/dados/rota_repositorio_fake.dart';
import 'package:kaptalixo/recursos/catador/dominio/rota_ativa.dart';
import 'package:latlong2/latlong.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class TilesVazios extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_png);
}

const casa1 = LatLng(-23.5500, -46.6300);
const casa2 = LatLng(-23.5400, -46.6300);
const pontoCentral = LatLng(-23.5400, -46.6200);

/// PINs corretos de cada solicitação (só existem no fake do servidor).
const pinsDemo = {'sol-1': '4821', 'sol-2': '1357'};

/// Duas coletas e um ponto de descarte, com um ponto alternativo.
RotaAtiva rotaDemo({StatusRota status = StatusRota.planejada}) => RotaAtiva(
  id: 'rota-1',
  status: status,
  versao: 1,
  distanciaTotalM: 2400,
  duracaoTotalS: 900,
  pontoDestinoId: 'pt-1',
  alternativas: const [
    PontoDescarte(
      id: 'pt-2',
      nome: 'Ponto Norte',
      posicao: LatLng(-23.53, -46.6),
    ),
  ],
  paradas: const [
    ParadaRota(
      id: 'par-1',
      ordem: 1,
      tipo: TipoParada.coleta,
      status: StatusParada.pendente,
      posicao: casa1,
      solicitacaoId: 'sol-1',
      qtdSacos: 2,
      enderecoTexto: 'Rua das Flores, 10',
      geradorNome: 'Maria',
    ),
    ParadaRota(
      id: 'par-2',
      ordem: 2,
      tipo: TipoParada.coleta,
      status: StatusParada.pendente,
      posicao: casa2,
      solicitacaoId: 'sol-2',
      qtdSacos: 1,
      enderecoTexto: 'Rua do Sol, 55',
      geradorNome: 'José',
    ),
    ParadaRota(
      id: 'par-3',
      ordem: 3,
      tipo: TipoParada.descarte,
      status: StatusParada.pendente,
      posicao: pontoCentral,
      pontoId: 'pt-1',
      pontoNome: 'Ponto Central',
    ),
  ],
);

/// Relógio de teste: o "agora" de [relogioProvider] e do fake do servidor.
class RelogioTeste {
  final DateTime inicio = DateTime.utc(2026, 1, 1, 12);
  Duration decorrido = Duration.zero;
  DateTime agora() => inicio.add(decorrido);
}

Future<RelogioTeste> montarRota(
  WidgetTester t, {
  required RotaRepositorioFake repo,
  required ServicoLocalizacao gps,
  RelogioTeste? relogio,
  VoidCallback? aoSair,
  OfertasRepositorio? ofertas,
  Future<void> Function(String rotaId)? aoReplanejar,
}) async {
  final r = relogio ?? RelogioTeste();
  t.view.physicalSize = const Size(900, 2200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        rotaRepositorioProvider.overrideWithValue(repo),
        servicoLocalizacaoProvider.overrideWithValue(gps),
        servicoRotasCatadorProvider.overrideWithValue(ServicoRotasFake()),
        relogioProvider.overrideWithValue(r.agora),
        if (ofertas != null)
          ofertasRepositorioProvider.overrideWithValue(ofertas),
      ],
      child: MaterialApp(
        home: TelaRotaAtiva(
          rotaId: 'rota-1',
          aoSair: aoSair,
          aoReplanejar: aoReplanejar,
          tileProvider: TilesVazios(),
        ),
      ),
    ),
  );
  await t.pump();
  await t.pump();
  return r;
}

/// Avança [segundos] de relógio, 1 s por vez (timers e relógio injetado).
Future<void> avancar(WidgetTester t, RelogioTeste r, int segundos) async {
  for (var i = 0; i < segundos; i++) {
    r.decorrido += const Duration(seconds: 1);
    await t.pump(const Duration(seconds: 1));
  }
}

Future<void> digitar(WidgetTester t, String pin) async {
  for (final d in pin.split('')) {
    await t.tap(find.byKey(Key('tecla-$d')));
    await t.pump();
  }
}

Future<void> confirmarPin(WidgetTester t, String pin) async {
  await digitar(t, pin);
  await t.tap(find.byKey(const Key('confirmar-pin')));
  await t.pump();
  await t.pump();
}
