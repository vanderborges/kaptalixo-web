import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/app/acoes_app.dart';
import 'package:kaptalixo/app/app.dart';
import 'package:kaptalixo/app/roteador.dart';
import 'package:kaptalixo/nucleo/localizacao/localizacao_fake.dart';
import 'package:kaptalixo/recursos/admin/apresentacao/demo_providers.dart';
import 'package:kaptalixo/recursos/admin/apresentacao/tela_demo.dart';
import 'package:kaptalixo/recursos/admin/dados/demo_repositorio_fake.dart';
import 'package:kaptalixo/recursos/admin/dominio/falha_admin.dart';
import 'package:kaptalixo/recursos/auth/apresentacao/providers.dart';
import 'package:kaptalixo/recursos/auth/dados/auth_repositorio_fake.dart';
import 'package:latlong2/latlong.dart';

import '../../app/overrides_teste.dart';

Future<void> abrirTela(
  WidgetTester tester,
  DemoRepositorioFake fake, {
  Duration? intervalo,
  LocalizacaoFake? simulacao,
}) async {
  tester.view.physicalSize = const Size(1200, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        demoRepositorioProvider.overrideWithValue(fake),
        intervaloDemoProvider.overrideWithValue(intervalo),
        if (simulacao != null)
          fabricaSimulacaoDemoProvider.overrideWithValue((_, _) => simulacao),
      ],
      child: MaterialApp(home: TelaDemo(tileProvider: TilesSemRede())),
    ),
  );
  await tester.pumpAndSettle();
  // Desmonta no fim para cancelar o timer de polling.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
  });
}

Future<void> tocar(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  late DemoRepositorioFake fake;

  setUp(() => fake = DemoRepositorioFake());

  group('painel', () {
    testWidgets('mostra atores no mapa, legenda e feed vazio', (tester) async {
      await abrirTela(tester, fake);
      for (final id in ['g-1', 'g-2', 'p-1', 'c-1', 'c-2']) {
        expect(find.byKey(Key('ator-$id')), findsOneWidget, reason: id);
      }
      expect(find.text('Ponto de coleta'), findsOneWidget); // legenda
      expect(find.text('Nenhum evento ainda.'), findsOneWidget);
      expect(find.text('Painel de demonstração'), findsOneWidget);
    });

    testWidgets('erro ao carregar oferece tentar novamente', (tester) async {
      fake.proximaFalha = const FalhaAdmin(CodigoFalhaAdmin.rede);
      await abrirTela(tester, fake);
      expect(find.textContaining('Sem conexão'), findsOneWidget);
      await tocar(tester, find.text('Tentar novamente'));
      expect(find.byKey(const Key('ator-g-1')), findsOneWidget);
    });

    testWidgets('criar N catadores aparece no mapa na hora', (tester) async {
      await abrirTela(tester, fake);
      await tocar(tester, find.byKey(const Key('demo-n-mais')));
      expect(find.text('4'), findsOneWidget);
      await tocar(tester, find.byKey(const Key('demo-criar-catadores')));
      for (var i = 1; i <= 4; i++) {
        expect(find.byKey(Key('ator-c-demo-$i')), findsOneWidget);
      }
      expect(find.text('4 catadores fictícios criados.'), findsOneWidget);
    });

    testWidgets('N respeita os limites 1 a 20', (tester) async {
      await abrirTela(tester, fake);
      for (var i = 0; i < 5; i++) {
        await tocar(tester, find.byKey(const Key('demo-n-menos')));
      }
      expect(find.text('1'), findsOneWidget);
      final menos = tester.widget<IconButton>(
        find.byKey(const Key('demo-n-menos')),
      );
      expect(menos.onPressed, isNull);
    });

    testWidgets('criar pedido fictício alimenta o feed', (tester) async {
      await abrirTela(tester, fake);
      await tocar(tester, find.byKey(const Key('demo-criar-pedido')));
      expect(find.text('Pedido fictício criado.'), findsOneWidget);
      expect(find.textContaining('criado: buscando catador'), findsOneWidget);
    });

    testWidgets('falha do servidor aparece em mensagem amigável', (
      tester,
    ) async {
      await abrirTela(tester, fake);
      fake.proximaFalha = const FalhaAdmin(CodigoFalhaAdmin.modoDemoDesativado);
      await tocar(tester, find.byKey(const Key('demo-criar-pedido')));
      expect(
        find.textContaining('modo demonstração está desativado'),
        findsOne,
      );
    });

    testWidgets('polling atualiza o feed com pedidos de outros atores', (
      tester,
    ) async {
      await abrirTela(tester, fake, intervalo: const Duration(seconds: 2));
      expect(find.text('Nenhum evento ainda.'), findsOneWidget);
      await fake.criarPedido();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.textContaining('criado: buscando catador'), findsOneWidget);
    });
  });

  group('resetar', () {
    testWidgets('pede confirmação; cancelar não reseta', (tester) async {
      await abrirTela(tester, fake);
      await tocar(tester, find.byKey(const Key('demo-resetar')));
      expect(find.text('Resetar demo?'), findsOneWidget);
      await tocar(tester, find.text('Cancelar'));
      expect(fake.chamadasReset, 0);
      expect(find.byKey(const Key('demo-resultado-reset')), findsNothing);
    });

    testWidgets('confirmar reseta, volta ao seed e mostra o tempo', (
      tester,
    ) async {
      await abrirTela(tester, fake);
      await tocar(tester, find.byKey(const Key('demo-criar-catadores')));
      expect(find.byKey(const Key('ator-c-demo-1')), findsOneWidget);
      await tocar(tester, find.byKey(const Key('demo-resetar')));
      await tocar(tester, find.text('Resetar'));
      expect(fake.chamadasReset, 1);
      expect(find.byKey(const Key('ator-c-demo-1')), findsNothing);
      expect(find.text('Demo resetada em 0,8 s.'), findsOneWidget);
    });

    testWidgets('avisa quando o reset passa de 10 s', (tester) async {
      fake.duracaoReset = const Duration(milliseconds: 12400);
      await abrirTela(tester, fake);
      await tocar(tester, find.byKey(const Key('demo-resetar')));
      await tocar(tester, find.text('Resetar'));
      expect(
        find.text('Demo resetada em 12,4 s. Acima do limite de 10 s.'),
        findsOneWidget,
      );
    });

    test('formatarSegundos usa vírgula', () {
      expect(formatarSegundos(const Duration(milliseconds: 9960)), '10,0 s');
      expect(formatarSegundos(const Duration(milliseconds: 1500)), '1,5 s');
    });
  });

  group('simulação', () {
    Future<void> escolher(WidgetTester tester, String nome) async {
      await tocar(tester, find.byKey(const Key('demo-catador')));
      await tocar(tester, find.text(nome).last);
    }

    testWidgets('sem catador escolhido avisa', (tester) async {
      await abrirTela(tester, fake);
      await tocar(tester, find.byKey(const Key('demo-simulacao')));
      expect(find.text('Escolha um catador para simular.'), findsOneWidget);
    });

    testWidgets('catador sem rota não liga', (tester) async {
      await abrirTela(tester, fake);
      await escolher(tester, 'Dora Catadora');
      await tocar(tester, find.byKey(const Key('demo-simulacao')));
      expect(find.textContaining('não tem rota ativa'), findsOneWidget);
      expect(find.text('Ligar simulação'), findsOneWidget);
    });

    testWidgets('liga, envia posições do catador e desliga', (tester) async {
      final servico = LocalizacaoFake();
      await abrirTela(tester, fake, simulacao: servico);
      await escolher(tester, 'Carlos Catador (com rota)');
      await tocar(tester, find.byKey(const Key('demo-simulacao')));
      expect(find.text('Desligar simulação'), findsOneWidget);

      servico.emitirPonto(const LatLng(-23.5510, -46.6340));
      await tester.pumpAndSettle();
      servico.emitirPonto(const LatLng(-23.5500, -46.6330));
      await tester.pumpAndSettle();
      expect(fake.movimentos.map((m) => m.$1), everyElement('c-1'));
      expect(fake.movimentos.last.$2, const LatLng(-23.5500, -46.6330));

      await tocar(tester, find.byKey(const Key('demo-simulacao')));
      expect(find.text('Ligar simulação'), findsOneWidget);
      final qtd = fake.movimentos.length;
      servico.emitirPonto(const LatLng(-23.54, -46.63));
      await tester.pumpAndSettle();
      expect(fake.movimentos, hasLength(qtd));
    });

    testWidgets('usa o multiplicador escolhido (1x/10x)', (tester) async {
      double? usado;
      final servico = LocalizacaoFake();
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            demoRepositorioProvider.overrideWithValue(fake),
            intervaloDemoProvider.overrideWithValue(null),
            fabricaSimulacaoDemoProvider.overrideWithValue((percurso, m) {
              usado = m;
              expect(percurso.first, DemoRepositorioFake.catador1.posicao);
              return servico;
            }),
          ],
          child: MaterialApp(home: TelaDemo(tileProvider: TilesSemRede())),
        ),
      );
      await tester.pumpAndSettle();
      await escolher(tester, 'Carlos Catador (com rota)');
      await tocar(tester, find.text('10x'));
      await tocar(tester, find.byKey(const Key('demo-simulacao')));
      expect(usado, 10);
      await tocar(tester, find.byKey(const Key('demo-simulacao')));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('erro ao enviar posição interrompe e avisa', (tester) async {
      final servico = LocalizacaoFake();
      await abrirTela(tester, fake, simulacao: servico);
      await escolher(tester, 'Carlos Catador (com rota)');
      await tocar(tester, find.byKey(const Key('demo-simulacao')));
      fake.proximaFalha = const FalhaAdmin(CodigoFalhaAdmin.semPermissao);
      servico.emitirPonto(const LatLng(-23.551, -46.634));
      await tester.pumpAndSettle();
      expect(find.textContaining('Simulação interrompida'), findsOneWidget);
      expect(find.text('Ligar simulação'), findsOneWidget);
    });

    testWidgets('simulação termina sozinha ao fim do percurso', (tester) async {
      final servico = LocalizacaoFake();
      await abrirTela(tester, fake, simulacao: servico);
      await escolher(tester, 'Carlos Catador (com rota)');
      await tocar(tester, find.byKey(const Key('demo-simulacao')));
      expect(find.text('Desligar simulação'), findsOneWidget);
      await servico.fechar();
      await tester.pumpAndSettle();
      expect(find.text('Ligar simulação'), findsOneWidget);
    });
  });

  group('navegação', () {
    testWidgets('admin abre o painel pela barra e volta', (tester) async {
      final auth = AuthRepositorioFake();
      await auth.entrar(
        email: 'admin@kaptalixo.dev',
        senha: AuthRepositorioFake.senhaPadrao,
      );
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositorioProvider.overrideWithValue(auth),
            demoRepositorioProvider.overrideWithValue(fake),
            intervaloDemoProvider.overrideWithValue(null),
            tileProviderAppProvider.overrideWithValue(TilesSemRede()),
          ],
          child: const KaptalixoApp(),
        ),
      );
      await tester.pumpAndSettle();
      String local() => ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      ).read(roteadorProvider).routerDelegate.currentConfiguration.uri.path;

      await tester.tap(find.byTooltip('Painel de demonstração'));
      await tester.pumpAndSettle();
      expect(local(), '/admin/demo');
      expect(find.byKey(const Key('ator-g-1')), findsOneWidget);

      await tester.tap(find.byTooltip('Voltar'));
      await tester.pumpAndSettle();
      expect(local(), '/admin');
    });

    testWidgets('não-admin não acessa /admin/demo', (tester) async {
      final auth = AuthRepositorioFake();
      await auth.entrar(
        email: 'gerador@kaptalixo.dev',
        senha: AuthRepositorioFake.senhaPadrao,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositorioProvider.overrideWithValue(auth),
            ...overridesTelasReais(),
          ],
          child: const KaptalixoApp(),
        ),
      );
      await tester.pumpAndSettle();
      ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      ).read(roteadorProvider).go('/admin/demo');
      await tester.pumpAndSettle();
      final local = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      ).read(roteadorProvider).routerDelegate.currentConfiguration.uri.path;
      expect(local, '/gerador');
    });
  });
}
