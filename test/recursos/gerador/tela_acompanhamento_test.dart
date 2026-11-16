import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/nucleo/mapas/servico_rotas_fake.dart';
import 'package:kaptalixo/recursos/gerador/apresentacao/providers.dart';
import 'package:kaptalixo/recursos/gerador/apresentacao/tela_acompanhamento.dart';
import 'package:kaptalixo/recursos/gerador/dados/acompanhamento_repositorio_fake.dart';
import 'package:kaptalixo/recursos/gerador/dominio/acompanhamento_coleta.dart';
import 'package:kaptalixo/recursos/gerador/dominio/acompanhamento_repositorio.dart';
import 'package:kaptalixo/recursos/gerador/dominio/falha_acompanhamento.dart';
import 'package:latlong2/latlong.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class _TilesVazios extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_png);
}

const _casa = LatLng(-23.55, -46.63);

AcompanhamentoColeta _c(
  StatusColeta status, {
  LatLng? catadorEm,
  int tentativas = 0,
  String? pin = '4821',
}) => AcompanhamentoColeta(
  id: 'sol-1',
  status: status,
  enderecoTexto: 'Rua das Flores, 10',
  local: _casa,
  qtdSacos: 2,
  pin: pin,
  tentativasOferta: tentativas,
  catador: status.comCatador || status.concluida
      ? CatadorAtendimento(
          nome: 'João Silva',
          tipoVeiculo: 'bicicleta',
          avaliacaoMedia: 4.8,
          posicao: catadorEm,
        )
      : null,
);

Future<void> abrir(
  WidgetTester tester,
  AcompanhamentoRepositorio repo, {
  void Function(String)? aoAvaliar,
  VoidCallback? aoSair,
  VoidCallback? aoNovaChamada,
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        acompanhamentoRepositorioProvider.overrideWithValue(repo),
        // 5 m/s: 1 km = 200 s.
        servicoRotasGeradorProvider.overrideWithValue(ServicoRotasFake()),
      ],
      child: MaterialApp(
        home: TelaAcompanhamento(
          solicitacaoId: 'sol-1',
          tileProvider: _TilesVazios(),
          aoAvaliar: aoAvaliar,
          aoSair: aoSair,
          aoNovaChamada: aoNovaChamada,
        ),
      ),
    ),
  );
}

/// Avança o relógio sem exigir "settle" (o indicador de busca anima sempre).
Future<void> assentar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _RepoCom implements AcompanhamentoRepositorio {
  _RepoCom(this.stream);
  final Stream<AcompanhamentoColeta> stream;
  @override
  Stream<AcompanhamentoColeta> observar(String id) => stream;
  @override
  Future<void> cancelar(String id, {String? motivo}) async {}
}

void main() {
  testWidgets('mostra carregando e depois a busca com a tentativa', (
    tester,
  ) async {
    final ctrl = StreamController<AcompanhamentoColeta>();
    addTearDown(ctrl.close);
    await abrir(tester, _RepoCom(ctrl.stream));
    expect(find.text('Carregando sua coleta...'), findsOneWidget);
    ctrl.add(_c(StatusColeta.buscando, tentativas: 2));
    await tester.pump();
    expect(find.text('Buscando um catador perto de você'), findsOneWidget);
    expect(find.textContaining('Tentativa 2'), findsOneWidget);
    expect(find.text('Cancelar pedido'), findsOneWidget);
    expect(find.byKey(const Key('pin_coleta')), findsNothing);
  });

  testWidgets('erro mostra mensagem e tenta de novo', (tester) async {
    final repo = AcompanhamentoRepositorioFake();
    await abrir(tester, repo);
    await assentar(tester);
    repo.emitirErro(const FalhaAcompanhamento(MotivoFalhaAcompanhamento.geral));
    await assentar(tester);
    expect(find.textContaining('Não foi possível atualizar'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    repo.emitir(_c(StatusColeta.buscando));
    await tester.tap(find.text('Tentar novamente'));
    await assentar(tester);
    expect(find.text('Buscando um catador perto de você'), findsOneWidget);
  });

  testWidgets(
    'transicoes buscando > aceita > a_caminho > no_local > coletada',
    (tester) async {
      final repo = AcompanhamentoRepositorioFake(
        inicial: _c(StatusColeta.buscando),
      );
      String? avaliada;
      await abrir(tester, repo, aoAvaliar: (id) => avaliada = id);
      await assentar(tester);
      expect(find.text('Buscando um catador perto de você'), findsOneWidget);

      // aceita: catador, PIN em destaque, mapa; ainda sem posicao.
      repo.emitir(_c(StatusColeta.aceita));
      await assentar(tester);
      expect(find.text('João aceitou sua coleta'), findsOneWidget);
      expect(find.text('João Silva'), findsOneWidget);
      expect(find.text('4,8'), findsOneWidget);
      expect(find.text('Bicicleta'), findsOneWidget);
      expect(find.text('4 8 2 1'), findsOneWidget);
      expect(find.byType(FlutterMap), findsOneWidget);
      expect(find.byType(PolylineLayer), findsNothing);

      // a_caminho a ~1,1 km (5 m/s => ~4 min): ETA e polyline.
      repo.emitir(
        _c(StatusColeta.aCaminho, catadorEm: const LatLng(-23.5600, -46.63)),
      );
      await assentar(tester);
      expect(find.text('Seu catador está a 4 min'), findsOneWidget);
      expect(find.byType(PolylineLayer), findsOneWidget);
      expect(find.byTooltip('Seu catador'), findsOneWidget);

      // posicao atualiza: ETA diminui (~560 m => 2 min).
      repo.emitir(
        _c(StatusColeta.aCaminho, catadorEm: const LatLng(-23.5550, -46.63)),
      );
      await assentar(tester);
      expect(find.text('Seu catador está a 2 min'), findsOneWidget);

      repo.emitir(
        _c(StatusColeta.noLocal, catadorEm: const LatLng(-23.5500, -46.63)),
      );
      await assentar(tester);
      expect(find.text('Seu catador chegou!'), findsOneWidget);
      expect(find.text('4 8 2 1'), findsOneWidget);

      repo.emitir(_c(StatusColeta.coletada, pin: null));
      await assentar(tester);
      expect(find.text('Coleta concluída. Obrigado!'), findsOneWidget);
      expect(find.text('4 8 2 1'), findsNothing);
      await tester.tap(find.text('Avaliar o catador'));
      expect(avaliada, 'sol-1');
    },
  );

  testWidgets('coletada sem aoAvaliar nao mostra botao de avaliar', (
    tester,
  ) async {
    final repo = AcompanhamentoRepositorioFake(
      inicial: _c(StatusColeta.coletada),
    );
    await abrir(tester, repo);
    await assentar(tester);
    expect(find.text('Avaliar o catador'), findsNothing);
    expect(find.text('Voltar ao início'), findsOneWidget);
  });

  testWidgets('cancelar na busca: confirma e mostra cancelada', (tester) async {
    final repo = AcompanhamentoRepositorioFake(
      inicial: _c(StatusColeta.buscando),
    );
    var saiu = false;
    await abrir(tester, repo, aoSair: () => saiu = true);
    await assentar(tester);
    await tester.tap(find.text('Cancelar pedido'));
    await assentar(tester);
    expect(find.text('Cancelar a coleta?'), findsOneWidget);
    expect(find.text('Motivo (opcional)'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar coleta'));
    await assentar(tester);
    expect(repo.cancelamentos.single.id, 'sol-1');
    expect(find.text('Coleta cancelada'), findsOneWidget);
    await tester.tap(find.text('Voltar ao início'));
    expect(saiu, isTrue);
  });

  testWidgets('cancelar apos aceite envia o motivo', (tester) async {
    final repo = AcompanhamentoRepositorioFake(
      inicial: _c(StatusColeta.aceita),
    );
    await abrir(tester, repo);
    await assentar(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar coleta'));
    await assentar(tester);
    expect(find.textContaining('catador será avisado'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Não estou em casa');
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar coleta'));
    await assentar(tester);
    expect(repo.cancelamentos.single.motivo, 'Não estou em casa');
    expect(find.text('Coleta cancelada'), findsOneWidget);
    expect(find.textContaining('Não estou em casa'), findsOneWidget);
  });

  testWidgets('desistir do cancelamento nao chama o repositorio', (
    tester,
  ) async {
    final repo = AcompanhamentoRepositorioFake(
      inicial: _c(StatusColeta.aceita),
    );
    await abrir(tester, repo);
    await assentar(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar coleta'));
    await assentar(tester);
    await tester.tap(find.text('Voltar'));
    await assentar(tester);
    expect(repo.cancelamentos, isEmpty);
    expect(find.text('João aceitou sua coleta'), findsOneWidget);
  });

  testWidgets('falha ao cancelar mostra aviso e mantem a tela', (tester) async {
    final repo = AcompanhamentoRepositorioFake(
      inicial: _c(StatusColeta.aCaminho, catadorEm: _casa),
      falhaAoCancelar: const FalhaAcompanhamento(
        MotivoFalhaAcompanhamento.naoCancelavel,
        'Esta coleta não pode mais ser cancelada.',
      ),
    );
    await abrir(tester, repo);
    await assentar(tester);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Cancelar coleta'));
    await assentar(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar coleta'));
    await assentar(tester);
    expect(
      find.text('Esta coleta não pode mais ser cancelada.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('titulo_status')), findsOneWidget);
  });

  testWidgets('sem_catador oferece chamar de novo', (tester) async {
    final repo = AcompanhamentoRepositorioFake(
      inicial: _c(StatusColeta.semCatador),
    );
    var novo = false;
    await abrir(tester, repo, aoNovaChamada: () => novo = true);
    await assentar(tester);
    expect(find.text('Nenhum catador disponível agora'), findsOneWidget);
    await tester.tap(find.text('Chamar de novo'));
    expect(novo, isTrue);
  });

  testWidgets('erro depois de um retrato mantem o retrato', (tester) async {
    final repo = AcompanhamentoRepositorioFake(
      inicial: _c(StatusColeta.aceita),
    );
    await abrir(tester, repo);
    await assentar(tester);
    repo.emitirErro(const FalhaAcompanhamento(MotivoFalhaAcompanhamento.geral));
    await assentar(tester);
    expect(find.text('João aceitou sua coleta'), findsOneWidget);
  });

  testWidgets('sair da tela cancela a assinatura do stream', (tester) async {
    final repo = AcompanhamentoRepositorioFake(
      inicial: _c(StatusColeta.aceita),
    );
    await abrir(tester, repo);
    await assentar(tester);
    expect(repo.temOuvinte, isTrue);
    await tester.pumpWidget(const SizedBox());
    await assentar(tester);
    expect(repo.temOuvinte, isFalse);
  });
}
