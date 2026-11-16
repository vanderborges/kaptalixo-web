import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/recursos/ponto/apresentacao/providers.dart';
import 'package:kaptalixo/recursos/ponto/apresentacao/tela_painel_ponto.dart';
import 'package:kaptalixo/recursos/ponto/apresentacao/tela_pesagem.dart';
import 'package:kaptalixo/recursos/ponto/dados/ponto_repositorio_fake.dart';
import 'package:kaptalixo/recursos/ponto/dominio/entrega_a_caminho.dart';
import 'package:kaptalixo/recursos/ponto/dominio/falha_ponto.dart';
import 'package:kaptalixo/recursos/ponto/dominio/pesagem.dart';

final _agora = DateTime(2026, 1, 1, 10);

EntregaACaminho _entrega(String id, String nome, int sacos, int minutos) =>
    EntregaACaminho(
      rotaId: id,
      catadorNome: nome,
      sacos: sacos,
      eta: _agora.add(Duration(minutes: minutos)),
    );

const _precos = [
  MaterialPreco(materialId: 1, nome: 'Papel', precoKgCentavos: 50),
  MaterialPreco(materialId: 3, nome: 'PET', precoKgCentavos: 250),
];

Future<void> _montar(
  WidgetTester t,
  PontoRepositorioFake repo,
  Widget home,
) async {
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        pontoRepositorioProvider.overrideWithValue(repo),
        relogioPontoProvider.overrideWithValue(() => _agora),
        tickPontoProvider.overrideWithValue(const Duration(hours: 1)),
      ],
      child: MaterialApp(home: home),
    ),
  );
  await t.pump();
  await t.pump();
}

void main() {
  group('Painel do ponto', () {
    testWidgets('lista entregas com catador, sacos e ETA', (t) async {
      final repo = PontoRepositorioFake(
        entregas: [_entrega('r1', 'Zé', 3, 5), _entrega('r2', 'Ana', 1, 12)],
        precos: _precos,
      );
      await _montar(t, repo, const TelaPainelPonto());
      expect(find.text('Zé'), findsOneWidget);
      expect(find.text('3 sacos'), findsOneWidget);
      expect(find.text('Chega em 5 min'), findsOneWidget);
      expect(find.text('1 saco'), findsOneWidget);
      expect(find.text('Chega em 12 min'), findsOneWidget);
    });

    testWidgets('vazio, chegou e atualização em tempo real', (t) async {
      final repo = PontoRepositorioFake(precos: _precos);
      await _montar(t, repo, const TelaPainelPonto());
      expect(find.text('Nenhuma entrega a caminho'), findsOneWidget);

      repo.publicar([
        const EntregaACaminho(
          rotaId: 'r1',
          catadorNome: 'Zé',
          sacos: 2,
          chegou: true,
        ),
      ]);
      await t.pump();
      await t.pump();
      expect(find.text('Chegou'), findsOneWidget);
      expect(find.text('Nenhuma entrega a caminho'), findsNothing);
    });

    testWidgets('Pesar chama o callback com a entrega', (t) async {
      EntregaACaminho? escolhida;
      final repo = PontoRepositorioFake(
        entregas: [_entrega('r1', 'Zé', 3, 5)],
        precos: _precos,
      );
      await _montar(t, repo, TelaPainelPonto(aoPesar: (e) => escolhida = e));
      await t.tap(find.text('Pesar'));
      expect(escolhida?.rotaId, 'r1');
    });
  });

  group('Pesagem', () {
    final entrega = _entrega('r1', 'Zé', 3, 5);

    testWidgets('calcula o valor na hora e confirma', (t) async {
      final repo = PontoRepositorioFake(entregas: [entrega], precos: _precos);
      await _montar(t, repo, TelaPesagem(entrega: entrega));

      FilledButton botao() => t.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirmar entrega'),
      );
      expect(botao().onPressed, isNull);

      await t.enterText(find.byKey(const Key('peso_1')), '12,5');
      await t.enterText(find.byKey(const Key('peso_3')), '3,33');
      await t.pump();
      // 6,25 + 8,33 (8,325 arredonda para cima)
      expect(find.text(r'Total: R$ 14,58'), findsOneWidget);
      expect(botao().onPressed, isNotNull);

      await t.tap(find.text('Confirmar entrega'));
      await t.pump();
      await t.pump();
      expect(find.text('Entrega registrada'), findsOneWidget);
      expect(find.text(r'R$ 14,58'), findsOneWidget);
      expect(find.text('15,83 kg'), findsOneWidget);
      expect(repo.registradas['r1'], hasLength(2));
    });

    testWidgets('peso inválido avisa e bloqueia a confirmação', (t) async {
      final repo = PontoRepositorioFake(entregas: [entrega], precos: _precos);
      await _montar(t, repo, TelaPesagem(entrega: entrega));
      await t.enterText(find.byKey(const Key('peso_1')), 'abc');
      await t.pump();
      expect(find.textContaining('Peso inválido'), findsOneWidget);
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirmar entrega'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('mostra a falha do servidor e permite tentar de novo', (
      t,
    ) async {
      final repo = PontoRepositorioFake(entregas: [entrega], precos: _precos)
        ..proximaFalha = const FalhaPonto(MotivoFalhaPonto.coletasPendentes);
      await _montar(t, repo, TelaPesagem(entrega: entrega));
      await t.enterText(find.byKey(const Key('peso_1')), '2');
      await t.pump();
      await t.tap(find.text('Confirmar entrega'));
      await t.pump();
      await t.pump();
      expect(
        find.text('O catador ainda tem coletas pendentes.'),
        findsOneWidget,
      );

      await t.tap(find.text('Confirmar entrega'));
      await t.pump();
      await t.pump();
      expect(find.text('Entrega registrada'), findsOneWidget);
    });

    testWidgets('sem preços cadastrados não deixa pesar', (t) async {
      final repo = PontoRepositorioFake(entregas: [entrega]);
      await _montar(t, repo, TelaPesagem(entrega: entrega));
      expect(
        find.text('Cadastre os preços do ponto para pesar.'),
        findsOneWidget,
      );
    });

    testWidgets('Concluir chama aoConcluir', (t) async {
      var fechou = false;
      final repo = PontoRepositorioFake(entregas: [entrega], precos: _precos);
      await _montar(
        t,
        repo,
        TelaPesagem(entrega: entrega, aoConcluir: () => fechou = true),
      );
      await t.enterText(find.byKey(const Key('peso_1')), '1');
      await t.pump();
      await t.tap(find.text('Confirmar entrega'));
      await t.pump();
      await t.pump();
      await t.tap(find.text('Concluir'));
      expect(fechou, isTrue);
    });
  });
}
