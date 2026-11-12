import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/app/app.dart';
import 'package:kaptalixo/app/roteador.dart';
import 'package:kaptalixo/nucleo/modelos/papel.dart';
import 'package:kaptalixo/nucleo/repositorios_base/sessao_repositorio.dart';
import 'package:kaptalixo/recursos/auth/apresentacao/providers.dart';

Future<void> abrir(WidgetTester tester, SessaoRepositorioFake repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessaoRepositorioProvider.overrideWithValue(repo)],
      child: const KaptalixoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

String localAtual(WidgetTester tester) {
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MaterialApp)),
  );
  return container
      .read(roteadorProvider)
      .routerDelegate
      .currentConfiguration
      .uri
      .path;
}

void main() {
  testWidgets('deslogado vai para /entrar', (tester) async {
    await abrir(tester, SessaoRepositorioFake());
    expect(localAtual(tester), '/entrar');
    expect(find.text('Coleta de recicláveis perto de você'), findsOneWidget);
  });

  for (final papel in Papel.values) {
    testWidgets('papel ${papel.name} vai para a própria home', (tester) async {
      await abrir(tester, SessaoRepositorioFake(papel: papel));
      expect(localAtual(tester), papel.rotaInicial);
      if (papel == Papel.admin) {
        expect(find.text('Administrador'), findsOneWidget);
      } else {
        expect(find.text('Área: ${papel.rotulo} (em construção)'), findsOne);
      }
    });

    testWidgets('papel ${papel.name} não acessa rota de outro papel', (
      tester,
    ) async {
      await abrir(tester, SessaoRepositorioFake(papel: papel));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      final outro = Papel.values.firstWhere((p) => p != papel);
      container.read(roteadorProvider).go(outro.rotaInicial);
      await tester.pumpAndSettle();
      expect(localAtual(tester), papel.rotaInicial);

      container.read(roteadorProvider).go('/entrar');
      await tester.pumpAndSettle();
      expect(localAtual(tester), papel.rotaInicial);
    });
  }

  testWidgets('mudança de sessão e logout redirecionam', (tester) async {
    final repo = SessaoRepositorioFake();
    await abrir(tester, repo);

    repo.entrarComo(Papel.catador);
    await tester.pumpAndSettle();
    expect(localAtual(tester), '/catador');

    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();
    expect(localAtual(tester), '/entrar');
  });

  group('redirecionar', () {
    for (final papel in Papel.values) {
      final repo = SessaoRepositorioFake(papel: papel);
      for (final outro in Papel.values.where((p) => p != papel)) {
        test('${papel.name} em ${outro.rotaInicial} volta à própria home', () {
          expect(redirecionar(repo, outro.rotaInicial), papel.rotaInicial);
        });
      }
      test('${papel.name} acessa a própria home e subrota', () {
        expect(redirecionar(repo, papel.rotaInicial), isNull);
        expect(redirecionar(repo, '${papel.rotaInicial}/pedido'), isNull);
      });
      test('${papel.name} não passa por falso prefixo', () {
        expect(redirecionar(repo, '${papel.rotaInicial}x'), papel.rotaInicial);
      });
      test('${papel.name} em rota desconhecida ou /entrar vai à home', () {
        for (final rota in ['/', '/xyz', '/entrar']) {
          expect(redirecionar(repo, rota), papel.rotaInicial);
        }
      });
    }

    test('deslogado vai para /entrar, exceto nela', () {
      final repo = SessaoRepositorioFake();
      for (final rota in ['/gerador', '/admin', '/', '/xyz']) {
        expect(redirecionar(repo, rota), '/entrar');
      }
      expect(redirecionar(repo, '/entrar'), isNull);
    });
  });

  testWidgets('descartar o container solta a assinatura da sessão', (
    tester,
  ) async {
    final repo = SessaoRepositorioFake();
    final container = ProviderContainer(
      overrides: [sessaoRepositorioProvider.overrideWithValue(repo)],
    );
    container.read(roteadorProvider);
    expect(repo.temOuvintes, isTrue);
    container.dispose();
    expect(repo.temOuvintes, isFalse);
    await repo.fechar();
  });

  testWidgets('usa tema escuro quando o sistema é escuro', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await abrir(tester, SessaoRepositorioFake());
    final contexto = tester.element(find.byType(Scaffold));
    expect(Theme.of(contexto).brightness, Brightness.dark);
  });
}
