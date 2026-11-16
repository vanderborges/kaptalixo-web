import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:kaptalixo/nucleo/localizacao/falha_localizacao.dart';
import 'package:kaptalixo/nucleo/localizacao/localizacao_fake.dart';
import 'package:kaptalixo/nucleo/localizacao/posicao.dart';
import 'package:kaptalixo/nucleo/localizacao/providers.dart';
import 'package:kaptalixo/nucleo/localizacao/servico_localizacao.dart';
import 'package:kaptalixo/nucleo/mapas/servico_geocodificacao.dart';
import 'package:kaptalixo/nucleo/mapas/servico_geocodificacao_fake.dart';
import 'package:kaptalixo/recursos/gerador/apresentacao/providers.dart';
import 'package:kaptalixo/recursos/gerador/apresentacao/tela_home_gerador.dart';
import 'package:kaptalixo/recursos/gerador/dados/pontos_proximos_repositorio_fake.dart';
import 'package:kaptalixo/recursos/gerador/dominio/falha_gerador.dart';
import 'package:kaptalixo/recursos/gerador/dominio/ponto_proximo.dart';
import 'package:latlong2/latlong.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class _TilesVazios extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_png);
}

class _LocalizacaoQuebrada implements ServicoLocalizacao {
  @override
  Future<Posicao> atual() async => throw StateError('boom');
  @override
  Stream<Posicao> posicoes() => const Stream.empty();
}

const _centro = LatLng(-23.55, -46.63);

const _ponto = PontoProximo(
  id: 'p1',
  nome: 'Ecoponto Centro',
  posicao: LatLng(-23.551, -46.632),
);

Posicao _posicao() => Posicao(ponto: _centro, instante: DateTime(2026));

Future<void> abrir(
  WidgetTester tester, {
  ServicoLocalizacao? localizacao,
  PontosProximosRepositorioFake? pontos,
  ServicoGeocodificacao? geo,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final roteador = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => TelaHomeGerador(tileProvider: _TilesVazios()),
      ),
      GoRoute(
        path: rotaChamarColeta,
        builder: (_, state) => Scaffold(body: Text('chamar ${state.extra}')),
      ),
    ],
  );
  addTearDown(roteador.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        servicoLocalizacaoProvider.overrideWithValue(
          localizacao ?? LocalizacaoFake(inicial: _posicao()),
        ),
        pontosProximosRepositorioProvider.overrideWithValue(
          pontos ?? PontosProximosRepositorioFake(),
        ),
        geocodificacaoProvider.overrideWithValue(
          geo ?? ServicoGeocodificacaoFake(),
        ),
      ],
      child: MaterialApp.router(routerConfig: roteador),
    ),
  );
}

LocalizacaoFake _semGps(MotivoFalhaLocalizacao motivo) =>
    LocalizacaoFake(falha: FalhaLocalizacao(motivo));

void main() {
  testWidgets('mostra carregando e depois mapa com atribuicao e botao', (
    tester,
  ) async {
    await abrir(
      tester,
      pontos: PontosProximosRepositorioFake(pontos: [_ponto]),
    );
    expect(find.text('Buscando sua localização...'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(RichAttributionWidget), findsOneWidget);
    expect(find.text('Sua localização atual'), findsOneWidget);
    expect(find.text('1 ponto de coleta por perto'), findsOneWidget);
    expect(find.text('Chamar coleta'), findsOneWidget);
  });

  testWidgets('erro nos pontos mostra aviso e mantem o botao', (tester) async {
    await abrir(
      tester,
      pontos: PontosProximosRepositorioFake(falha: const FalhaGerador()),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível mostrar os pontos de coleta.'),
      findsOneWidget,
    );
    expect(find.text('Chamar coleta'), findsOneWidget);
  });

  testWidgets('lista vazia informa que nao ha pontos', (tester) async {
    await abrir(tester);
    await tester.pumpAndSettle();
    expect(find.text('Nenhum ponto de coleta por perto.'), findsOneWidget);
  });

  testWidgets('Chamar coleta navega levando a posicao', (tester) async {
    await abrir(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chamar coleta'));
    await tester.pumpAndSettle();
    expect(find.textContaining('chamar LatLng'), findsOneWidget);
  });

  testWidgets('sem permissao pede endereco manual e usa o escolhido', (
    tester,
  ) async {
    final geo = ServicoGeocodificacaoFake(
      resultados: const [
        ResultadoGeocodificacao(
          nome: 'Rua A, 10, Centro',
          posicao: LatLng(-23.5, -46.6),
        ),
      ],
    );
    await abrir(
      tester,
      localizacao: _semGps(MotivoFalhaLocalizacao.permissaoNegada),
      geo: geo,
    );
    await tester.pumpAndSettle();
    expect(find.text('Não conseguimos pegar sua localização'), findsOneWidget);
    expect(find.text('Chamar coleta'), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'Rua A 10');
    await tester.tap(find.text('Buscar endereço'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rua A, 10, Centro'));
    await tester.pumpAndSettle();

    expect(find.text('Rua A, 10, Centro'), findsOneWidget);
    expect(find.text('Usar GPS'), findsOneWidget);
    expect(find.text('Chamar coleta'), findsOneWidget);
  });

  testWidgets('endereco manual: validacao e resultado vazio', (tester) async {
    await abrir(
      tester,
      localizacao: _semGps(MotivoFalhaLocalizacao.servicoDesligado),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buscar endereço'));
    await tester.pump();
    expect(find.text('Digite o endereço (rua e cidade).'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Rua inexistente');
    await tester.tap(find.text('Buscar endereço'));
    await tester.pumpAndSettle();
    expect(
      find.text('Nenhum endereço encontrado. Confira o texto.'),
      findsOneWidget,
    );
  });

  testWidgets('falha na busca de endereco mostra erro', (tester) async {
    await abrir(
      tester,
      localizacao: _semGps(MotivoFalhaLocalizacao.indisponivel),
      geo: ServicoGeocodificacaoFake(falhar: true),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Rua B 20');
    await tester.tap(find.text('Buscar endereço'));
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível buscar o endereço. Tente de novo.'),
      findsOneWidget,
    );
  });

  testWidgets('tentar GPS de novo funciona quando a permissao e liberada', (
    tester,
  ) async {
    final loc = _semGps(MotivoFalhaLocalizacao.permissaoNegada);
    await abrir(tester, localizacao: loc);
    await tester.pumpAndSettle();
    loc.falha = null;
    loc.emitir(_posicao());
    await tester.tap(find.text('Tentar usar minha localização'));
    await tester.pumpAndSettle();
    expect(find.text('Sua localização atual'), findsOneWidget);
  });

  testWidgets('erro inesperado mostra erro com nova tentativa', (tester) async {
    await abrir(tester, localizacao: _LocalizacaoQuebrada());
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível abrir o mapa.'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
}
