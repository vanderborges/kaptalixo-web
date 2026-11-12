import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/app/app.dart';
import 'package:kaptalixo/app/roteador.dart';
import 'package:kaptalixo/nucleo/modelos/status_cadastro.dart';
import 'package:kaptalixo/recursos/admin/apresentacao/providers.dart';
import 'package:kaptalixo/recursos/admin/dados/catadores_admin_repositorio_fake.dart';
import 'package:kaptalixo/recursos/admin/dominio/falha_admin.dart';
import 'package:kaptalixo/recursos/auth/apresentacao/providers.dart';
import 'package:kaptalixo/recursos/auth/dados/auth_repositorio_fake.dart';
import 'package:kaptalixo/recursos/auth/dominio/falha_auth.dart';

Future<void> abrir(
  WidgetTester tester, {
  required AuthRepositorioFake auth,
  CatadoresAdminRepositorioFake? admin,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositorioProvider.overrideWithValue(auth),
        if (admin != null)
          catadoresAdminRepositorioProvider.overrideWithValue(admin),
      ],
      child: const KaptalixoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

String local(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(MaterialApp)),
).read(roteadorProvider).routerDelegate.currentConfiguration.uri.path;

void main() {
  late CatadoresAdminRepositorioFake admin;

  Future<AuthRepositorioFake> logarAdmin(WidgetTester tester) async {
    final auth = AuthRepositorioFake();
    await auth.entrar(
      email: 'admin@kaptalixo.dev',
      senha: AuthRepositorioFake.senhaPadrao,
    );
    return auth;
  }

  setUp(() => admin = CatadoresAdminRepositorioFake());

  group('admin', () {
    testWidgets('lista pendentes por padrão', (tester) async {
      await abrir(tester, auth: await logarAdmin(tester), admin: admin);
      expect(find.text('Maria Souza'), findsOneWidget);
      expect(find.text('Recicla Já'), findsOneWidget);
      expect(find.text('João Lima'), findsNothing);
    });

    testWidgets('filtro mostra suspensos e vazio', (tester) async {
      await abrir(tester, auth: await logarAdmin(tester), admin: admin);
      await tester.tap(find.text('Suspensos'));
      await tester.pumpAndSettle();
      expect(find.text('Pedro Alves'), findsOneWidget);
      await admin.alterarStatus('c-suspenso-1', StatusCadastro.aprovado);
      await tester.tap(find.byTooltip('Atualizar lista'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhum catador suspensos.'), findsOneWidget);
    });

    testWidgets('estado de carregamento', (tester) async {
      admin.bloqueio = Completer<void>();
      final auth = await logarAdmin(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositorioProvider.overrideWithValue(auth),
            catadoresAdminRepositorioProvider.overrideWithValue(admin),
          ],
          child: const KaptalixoApp(),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Carregando catadores...'), findsOneWidget);
      admin.bloqueio!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Maria Souza'), findsOneWidget);
    });

    testWidgets('erro com nova tentativa', (tester) async {
      admin.falhaProxima = const FalhaAdmin(CodigoFalhaAdmin.rede);
      await abrir(tester, auth: await logarAdmin(tester), admin: admin);
      expect(find.textContaining('Sem conexão'), findsOneWidget);
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      expect(find.text('Maria Souza'), findsOneWidget);
    });

    testWidgets('detalhe: aprovar atualiza e volta à lista', (tester) async {
      await abrir(tester, auth: await logarAdmin(tester), admin: admin);
      await tester.tap(find.text('Maria Souza'));
      await tester.pumpAndSettle();
      expect(local(tester), '/admin/catador/c-pendente-1');
      expect(find.text('carrinho'), findsOneWidget);
      await tester.tap(find.text('Aprovar'));
      await tester.pumpAndSettle();
      expect(admin.alteracoes, [('c-pendente-1', StatusCadastro.aprovado)]);
      expect(local(tester), '/admin');
      expect(find.text('Maria Souza'), findsNothing);
      expect(find.text('Maria Souza aprovado.'), findsOneWidget);
    });

    testWidgets('detalhe: suspender pede confirmação', (tester) async {
      await abrir(tester, auth: await logarAdmin(tester), admin: admin);
      await tester.tap(find.text('Maria Souza'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Suspender'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(admin.alteracoes, isEmpty);

      await tester.tap(find.text('Suspender'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Suspender'));
      await tester.pumpAndSettle();
      expect(admin.alteracoes, [('c-pendente-1', StatusCadastro.suspenso)]);
    });

    testWidgets('detalhe: falha ao salvar mostra erro e permanece', (
      tester,
    ) async {
      await abrir(tester, auth: await logarAdmin(tester), admin: admin);
      await tester.tap(find.text('Maria Souza'));
      await tester.pumpAndSettle();
      admin.falhaProxima = const FalhaAdmin(CodigoFalhaAdmin.semPermissao);
      await tester.tap(find.text('Aprovar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('permissão'), findsOneWidget);
      expect(local(tester), '/admin/catador/c-pendente-1');
    });

    testWidgets('suspenso pode ser reativado', (tester) async {
      await abrir(tester, auth: await logarAdmin(tester), admin: admin);
      await tester.tap(find.text('Suspensos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pedro Alves'));
      await tester.pumpAndSettle();
      expect(find.text('Suspender'), findsNothing);
      await tester.tap(find.text('Reativar (aprovar)'));
      await tester.pumpAndSettle();
      expect(find.text('Reativar catador?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Reativar'));
      await tester.pumpAndSettle();
      expect(admin.alteracoes, [('c-suspenso-1', StatusCadastro.aprovado)]);
    });
  });

  group('aguardando aprovação (catador)', () {
    Future<AuthRepositorioFake> logarPendente() async {
      final auth = AuthRepositorioFake();
      await auth.entrar(
        email: 'pendente@kaptalixo.dev',
        senha: AuthRepositorioFake.senhaPadrao,
      );
      return auth;
    }

    testWidgets('pendente vê espera; sem aprovação segue na tela', (
      tester,
    ) async {
      await abrir(tester, auth: await logarPendente());
      expect(find.text('Cadastro aguardando aprovação'), findsOneWidget);
      await tester.tap(find.text('Atualizar status'));
      await tester.pumpAndSettle();
      expect(local(tester), rotaAguardandoAprovacao);
    });

    testWidgets('após aprovação, atualizar leva à área do catador', (
      tester,
    ) async {
      final auth = await logarPendente();
      await abrir(tester, auth: auth);
      auth.definirStatusCatador('fake-pendente', StatusCadastro.aprovado);
      await tester.tap(find.text('Atualizar status'));
      await tester.pumpAndSettle();
      expect(local(tester), '/catador');
    });

    testWidgets('suspenso vê mensagem própria', (tester) async {
      final auth = await logarPendente();
      await abrir(tester, auth: auth);
      auth.definirStatusCatador('fake-pendente', StatusCadastro.suspenso);
      await tester.tap(find.text('Atualizar status'));
      await tester.pumpAndSettle();
      expect(find.text('Cadastro suspenso'), findsOneWidget);
      expect(local(tester), rotaAguardandoAprovacao);
    });

    testWidgets('falha ao recarregar mostra erro', (tester) async {
      final auth = await logarPendente();
      await abrir(tester, auth: auth);
      auth.falhaRecarregar = const FalhaAuth(CodigoFalhaAuth.rede);
      await tester.tap(find.text('Atualizar status'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sem conexão'), findsOneWidget);
    });

    testWidgets('RN10: pendente não pode ficar disponível; aprovado pode', (
      tester,
    ) async {
      final auth = await logarPendente();
      await abrir(tester, auth: auth);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      expect(container.read(podeFicarDisponivelProvider), isFalse);
      auth.definirStatusCatador('fake-pendente', StatusCadastro.aprovado);
      await auth.recarregar();
      await tester.pumpAndSettle();
      expect(container.read(podeFicarDisponivelProvider), isTrue);
    });
  });
}
