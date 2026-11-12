import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/app/app.dart';
import 'package:kaptalixo/app/roteador.dart';
import 'package:kaptalixo/nucleo/modelos/papel.dart';
import 'package:kaptalixo/nucleo/modelos/status_cadastro.dart';
import 'package:kaptalixo/recursos/auth/apresentacao/providers.dart';
import 'package:kaptalixo/recursos/auth/dados/auth_repositorio_fake.dart';
import 'package:kaptalixo/recursos/auth/dominio/dados_cadastro.dart';

Future<void> abrir(
  WidgetTester tester,
  AuthRepositorioFake repo, {
  List<Papel>? papeis,
}) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositorioProvider.overrideWithValue(repo),
        if (papeis != null)
          papeisCadastraveisProvider.overrideWithValue(papeis),
      ],
      child: const KaptalixoApp(),
    ),
  );
  await tester.pumpAndSettle();
}

String local(WidgetTester tester) {
  final c = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
  return c.read(roteadorProvider).routerDelegate.currentConfiguration.uri.path;
}

Finder campo(String rotulo) => find.widgetWithText(TextFormField, rotulo);

Future<void> preencher(WidgetTester t, String rotulo, String texto) async {
  await t.ensureVisible(campo(rotulo));
  await t.enterText(campo(rotulo), texto);
}

Future<void> tocar(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  group('login', () {
    for (final papel in Papel.values) {
      testWidgets('${papel.name} do seed vai para a home do papel', (
        tester,
      ) async {
        final repo = AuthRepositorioFake();
        await abrir(tester, repo);
        await preencher(tester, 'E-mail', '${papel.name}@kaptalixo.dev');
        await preencher(tester, 'Senha', AuthRepositorioFake.senhaPadrao);
        await tocar(tester, find.widgetWithText(FilledButton, 'Entrar'));
        expect(local(tester), papel.rotaInicial);
      });
    }

    testWidgets('campos vazios e e-mail inválido mostram validação', (
      tester,
    ) async {
      await abrir(tester, AuthRepositorioFake());
      await tocar(tester, find.widgetWithText(FilledButton, 'Entrar'));
      expect(find.text('Informe o e-mail.'), findsOneWidget);
      expect(find.text('Informe a senha.'), findsOneWidget);
      await preencher(tester, 'E-mail', 'abc');
      await tocar(tester, find.widgetWithText(FilledButton, 'Entrar'));
      expect(find.text('E-mail inválido.'), findsOneWidget);
      expect(local(tester), '/entrar');
    });

    testWidgets('credenciais erradas mostram mensagem em pt-BR', (
      tester,
    ) async {
      await abrir(tester, AuthRepositorioFake());
      await preencher(tester, 'E-mail', 'gerador@kaptalixo.dev');
      await preencher(tester, 'Senha', 'errada');
      await tocar(tester, find.widgetWithText(FilledButton, 'Entrar'));
      expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
      expect(local(tester), '/entrar');
    });

    testWidgets('mostra carregando enquanto aguarda', (tester) async {
      final repo = AuthRepositorioFake()..bloqueio = Completer();
      await abrir(tester, repo);
      await preencher(tester, 'E-mail', 'gerador@kaptalixo.dev');
      await preencher(tester, 'Senha', AuthRepositorioFake.senhaPadrao);
      await tester.tap(find.widgetWithText(FilledButton, 'Entrar'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      repo.bloqueio!.complete();
      await tester.pumpAndSettle();
      expect(local(tester), '/gerador');
    });

    testWidgets('catador pendente vai para a tela de aguardando', (
      tester,
    ) async {
      await abrir(tester, AuthRepositorioFake());
      await preencher(tester, 'E-mail', 'pendente@kaptalixo.dev');
      await preencher(tester, 'Senha', AuthRepositorioFake.senhaPadrao);
      await tocar(tester, find.widgetWithText(FilledButton, 'Entrar'));
      expect(local(tester), rotaAguardandoAprovacao);
      expect(find.textContaining('aguardando aprovação'), findsOneWidget);
    });

    testWidgets('logout volta para /entrar', (tester) async {
      await abrir(tester, AuthRepositorioFake());
      await preencher(tester, 'E-mail', 'ponto@kaptalixo.dev');
      await preencher(tester, 'Senha', AuthRepositorioFake.senhaPadrao);
      await tocar(tester, find.widgetWithText(FilledButton, 'Entrar'));
      await tocar(tester, find.byTooltip('Sair'));
      expect(local(tester), '/entrar');
    });
  });

  group('cadastro', () {
    Future<void> irParaCadastro(WidgetTester t) async {
      await tocar(t, find.text('Criar conta'));
      expect(local(t), '/cadastrar');
    }

    Future<void> comuns(WidgetTester t, {String email = 'novo@x.dev'}) async {
      await preencher(t, 'Nome', 'Fulano');
      await preencher(t, 'E-mail', email);
      await preencher(t, 'Senha', 'Senha1234');
      await preencher(t, 'Telefone', '11999990000');
    }

    testWidgets('gerador cai na home do gerador', (tester) async {
      final repo = AuthRepositorioFake();
      await abrir(tester, repo);
      await irParaCadastro(tester);
      await tocar(tester, find.text('Gerador'));
      await comuns(tester);
      await tocar(tester, find.widgetWithText(FilledButton, 'Criar conta'));
      expect(local(tester), '/gerador');
      expect(repo.cadastros.single, isA<CadastroGerador>());
    });

    testWidgets('sem escolher papel pede a escolha', (tester) async {
      await abrir(tester, AuthRepositorioFake());
      await irParaCadastro(tester);
      await tocar(tester, find.widgetWithText(FilledButton, 'Criar conta'));
      expect(find.textContaining('Escolha como'), findsWidgets);
    });

    testWidgets('senha fraca e e-mail inválido são validados', (tester) async {
      final repo = AuthRepositorioFake();
      await abrir(tester, repo);
      await irParaCadastro(tester);
      await tocar(tester, find.text('Gerador'));
      await preencher(tester, 'Nome', 'Fulano');
      await preencher(tester, 'E-mail', 'xxx');
      await preencher(tester, 'Senha', '123');
      await preencher(tester, 'Telefone', '1');
      await tocar(tester, find.widgetWithText(FilledButton, 'Criar conta'));
      expect(find.text('E-mail inválido.'), findsOneWidget);
      expect(find.textContaining('Senha fraca'), findsOneWidget);
      expect(repo.cadastros, isEmpty);
    });

    testWidgets('e-mail já usado mostra mensagem', (tester) async {
      await abrir(tester, AuthRepositorioFake());
      await irParaCadastro(tester);
      await tocar(tester, find.text('Gerador'));
      await comuns(tester, email: 'gerador@kaptalixo.dev');
      await tocar(tester, find.widgetWithText(FilledButton, 'Criar conta'));
      expect(find.textContaining('já está cadastrado'), findsOneWidget);
      expect(local(tester), '/cadastrar');
    });

    testWidgets('catador: campos do papel, fica pendente e aguarda', (
      tester,
    ) async {
      final repo = AuthRepositorioFake();
      await abrir(tester, repo);
      await irParaCadastro(tester);
      await tocar(tester, find.text('Catador'));
      await comuns(tester);
      await preencher(tester, 'CPF', '12345678901');
      await preencher(tester, 'Veículo', 'carrinho');
      await preencher(tester, 'Capacidade (sacos)', '12');
      await tocar(tester, find.widgetWithText(FilledButton, 'Criar conta'));
      final c = repo.cadastros.single as CadastroCatador;
      expect(c.capacidadeSacos, 12);
      expect(repo.atual?.statusCadastro, StatusCadastro.pendente);
      expect(local(tester), rotaAguardandoAprovacao);
    });

    testWidgets('catador empresa pede razão social e CNPJ', (tester) async {
      await abrir(tester, AuthRepositorioFake());
      await irParaCadastro(tester);
      await tocar(tester, find.text('Catador'));
      await tocar(tester, find.text('Empresa'));
      expect(campo('Razão social'), findsOneWidget);
      expect(campo('CNPJ'), findsOneWidget);
    });

    testWidgets('ponto: formulário com endereço, horário e preços', (
      tester,
    ) async {
      final repo = AuthRepositorioFake();
      await abrir(
        tester,
        repo,
        papeis: const [Papel.gerador, Papel.catador, Papel.ponto],
      );
      await irParaCadastro(tester);
      await tocar(tester, find.text('Ponto de coleta'));
      await comuns(tester);
      await preencher(tester, 'Nome do ponto', 'Ferro Velho');
      await preencher(tester, 'Endereço', 'Rua A, 10');
      await preencher(tester, 'Cidade', 'São Paulo');
      await preencher(tester, 'UF', 'sp');
      await preencher(tester, 'Preço do PET (R\$/kg)', '2,5');
      await tocar(tester, find.widgetWithText(FilledButton, 'Criar conta'));
      final p = repo.cadastros.single as CadastroPonto;
      expect(p.uf, 'SP');
      expect(p.precosPorMaterial, {'pet': 2.5});
      expect(local(tester), '/ponto');
    });

    testWidgets('por padrão ponto não é oferecido no cadastro', (tester) async {
      await abrir(tester, AuthRepositorioFake());
      await irParaCadastro(tester);
      expect(find.text('Ponto de coleta'), findsNothing);
      expect(find.text('Gerador'), findsOneWidget);
    });
  });
}
