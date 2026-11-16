import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/nucleo/mapas/servico_geocodificacao.dart';
import 'package:kaptalixo/nucleo/mapas/servico_geocodificacao_fake.dart';
import 'package:kaptalixo/recursos/gerador/apresentacao/providers.dart';
import 'package:kaptalixo/recursos/gerador/apresentacao/tela_chamar_coleta.dart';
import 'package:kaptalixo/recursos/gerador/dados/materiais_repositorio_fake.dart';
import 'package:kaptalixo/recursos/gerador/dados/solicitacao_repositorio_fake.dart';
import 'package:kaptalixo/recursos/gerador/dominio/falha_gerador.dart';
import 'package:kaptalixo/recursos/gerador/dominio/dados_solicitacao.dart';
import 'package:kaptalixo/recursos/gerador/dominio/falha_solicitacao.dart';
import 'package:kaptalixo/recursos/gerador/dominio/tamanho_saco.dart';
import 'package:latlong2/latlong.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class _TilesVazios extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_png);
}

const _centro = LatLng(-23.55, -46.63);

Future<void> abrir(
  WidgetTester tester, {
  SolicitacaoRepositorioFake? solicitacoes,
  MateriaisRepositorioFake? materiais,
  ServicoGeocodificacao? geo,
  void Function(String)? aoCriada,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        solicitacaoRepositorioProvider.overrideWithValue(
          solicitacoes ?? SolicitacaoRepositorioFake(),
        ),
        materiaisRepositorioProvider.overrideWithValue(
          materiais ?? MateriaisRepositorioFake(),
        ),
        geocodificacaoProvider.overrideWithValue(
          geo ??
              ServicoGeocodificacaoFake(
                reversoPadrao: const ResultadoGeocodificacao(
                  nome: 'Rua das Flores, 10',
                  posicao: _centro,
                ),
              ),
        ),
      ],
      child: MaterialApp(
        home: TelaChamarColeta(
          posicaoInicial: _centro,
          tileProvider: _TilesVazios(),
          aoCriada: aoCriada,
        ),
      ),
    ),
  );
}

Future<void> chamar(WidgetTester tester) async {
  final botao = find.widgetWithText(FilledButton, 'Chamar coleta');
  await tester.ensureVisible(botao);
  await tester.tap(botao);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('mostra carregando materiais e depois os chips', (tester) async {
    await abrir(tester);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(FilterChip), findsNWidgets(7));
    expect(find.text('Rua das Flores, 10'), findsOneWidget);
  });

  testWidgets('erro nos materiais permite tentar de novo', (tester) async {
    final mats = MateriaisRepositorioFake(falha: const FalhaGerador());
    await abrir(tester, materiais: mats);
    await tester.pumpAndSettle();
    expect(
      find.text('Não foi possível carregar os materiais.'),
      findsOneWidget,
    );
    mats.falha = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.byType(FilterChip), findsNWidgets(7));
  });

  testWidgets('envia sacos, tamanho, materiais e observacao', (tester) async {
    final repo = SolicitacaoRepositorioFake(idCriado: 'xyz');
    String? criada;
    await abrir(tester, solicitacoes: repo, aoCriada: (id) => criada = id);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Mais um saco'));
    await tester.tap(find.byTooltip('Mais um saco'));
    await tester.tap(find.text('Grande'));
    await tester.tap(find.text('PET'));
    await tester.tap(find.text('Vidro'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Observação (opcional)'),
      'portão azul',
    );
    await tester.pump();
    await chamar(tester);

    expect(criada, 'xyz');
    final d = repo.enviadas.single;
    expect(d.qtdSacos, 3);
    expect(d.tamanho, TamanhoSaco.g);
    expect(d.materiais, [3, 5]);
    expect(d.observacao, 'portão azul');
    expect(d.enderecoTexto, 'Rua das Flores, 10');
    expect(d.posicao.latitude, closeTo(-23.55, 1e-6));
  });

  testWidgets('limita quantidade entre 1 e 20', (tester) async {
    await abrir(tester);
    await tester.pumpAndSettle();
    final menos = find.widgetWithIcon(IconButton, Icons.remove);
    expect(tester.widget<IconButton>(menos).onPressed, isNull);
    for (var i = 0; i < 25; i++) {
      await tester.tap(find.byTooltip('Mais um saco'));
      await tester.pump();
    }
    await tester.pump();
    expect(find.text('20'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add))
          .onPressed,
      isNull,
    );
  });

  testWidgets('endereco vazio bloqueia o envio (RN01)', (tester) async {
    final repo = SolicitacaoRepositorioFake();
    await abrir(tester, solicitacoes: repo);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Endereço'),
      '   ',
    );
    await chamar(tester);
    expect(find.text('Informe o endereço de coleta.'), findsOneWidget);
    expect(repo.enviadas, isEmpty);
  });

  testWidgets('solicitacao ativa mostra mensagem simples', (tester) async {
    final repo = SolicitacaoRepositorioFake(
      falha: FalhaSolicitacao.doCodigo('solicitacao_ativa_existente'),
    );
    await abrir(tester, solicitacoes: repo);
    await tester.pumpAndSettle();
    await chamar(tester);
    expect(
      find.textContaining('Você já tem uma coleta em andamento'),
      findsOneWidget,
    );
    // O gerador pode tentar de novo (botao volta a ficar ativo).
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Chamar coleta'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets('enviando mostra progresso no botao', (tester) async {
    final repo = _Lento();
    await abrir(tester, solicitacoes: repo);
    await tester.pumpAndSettle();
    final botao = find.widgetWithText(FilledButton, 'Chamar coleta');
    await tester.ensureVisible(botao);
    await tester.tap(botao);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repo.liberar();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('busca de endereco move o pino e preenche o texto', (
    tester,
  ) async {
    final geo = ServicoGeocodificacaoFake(
      resultados: const [
        ResultadoGeocodificacao(
          nome: 'Av. Paulista, 1000',
          posicao: LatLng(-23.56, -46.65),
        ),
      ],
    );
    final repo = SolicitacaoRepositorioFake();
    await abrir(tester, solicitacoes: repo, geo: geo);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Endereço'),
      'paulista',
    );
    await tester.tap(find.text('Buscar endereço'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Av. Paulista, 1000'));
    await tester.pumpAndSettle();
    await chamar(tester);
    final d = repo.enviadas.single;
    expect(d.enderecoTexto, 'Av. Paulista, 1000');
    expect(d.posicao.latitude, closeTo(-23.56, 1e-3));
    expect(d.posicao.longitude, closeTo(-46.65, 1e-3));
  });

  testWidgets('falha na busca mostra aviso', (tester) async {
    await abrir(tester, geo: ServicoGeocodificacaoFake(falhar: true));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Endereço'),
      'rua teste',
    );
    await tester.tap(find.text('Buscar endereço'));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível buscar o endereço.'), findsOneWidget);
  });
}

class _Lento extends SolicitacaoRepositorioFake {
  final _c = Completer<void>();
  void liberar() => _c.complete();

  @override
  Future<String> criar(DadosSolicitacao dados) async {
    await _c.future;
    return super.criar(dados);
  }
}
