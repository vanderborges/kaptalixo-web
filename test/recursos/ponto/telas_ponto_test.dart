import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/recursos/ponto/apresentacao/providers.dart';
import 'package:kaptalixo/recursos/ponto/apresentacao/tela_painel_ponto.dart';
import 'package:kaptalixo/recursos/ponto/dados/ponto_repositorio_fake.dart';
import 'package:kaptalixo/recursos/ponto/dominio/entrega_a_caminho.dart';
import 'package:kaptalixo/recursos/ponto/dominio/falha_ponto.dart';

final _agora = DateTime(2026, 1, 1, 10);

EntregaACaminho _entrega(String id, String nome, int sacos, int minutos) =>
    EntregaACaminho(
      rotaId: id,
      catadorNome: nome,
      sacos: sacos,
      eta: _agora.add(Duration(minutes: minutos)),
    );

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
      );
      await _montar(t, repo, const TelaPainelPonto());
      expect(find.text('Zé'), findsOneWidget);
      expect(find.text('3 sacos'), findsOneWidget);
      expect(find.text('Chega em 5 min'), findsOneWidget);
      expect(find.text('1 saco'), findsOneWidget);
      expect(find.text('Chega em 12 min'), findsOneWidget);
    });

    testWidgets('vazio, chegou e atualização em tempo real', (t) async {
      final repo = PontoRepositorioFake();
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

    testWidgets('Confirmar entrega chama o repositório e atualiza a lista', (
      t,
    ) async {
      final repo = PontoRepositorioFake(
        entregas: [_entrega('r1', 'Zé', 3, 5), _entrega('r2', 'Ana', 1, 12)],
      );
      await _montar(t, repo, const TelaPainelPonto());
      expect(find.text('Confirmar entrega'), findsNWidgets(2));

      await t.tap(find.text('Confirmar entrega').first);
      await t.pump();
      await t.pump();
      expect(repo.confirmadas, ['r1']);
      expect(find.text('Entrega confirmada'), findsOneWidget);
      expect(find.text('Zé'), findsNothing);
      expect(find.text('Ana'), findsOneWidget);
    });

    testWidgets('mostra a falha e permite tentar de novo', (t) async {
      final repo = PontoRepositorioFake(entregas: [_entrega('r1', 'Zé', 3, 5)])
        ..proximaFalha = const FalhaPonto(MotivoFalhaPonto.coletasPendentes);
      await _montar(t, repo, const TelaPainelPonto());

      await t.tap(find.text('Confirmar entrega'));
      await t.pump();
      await t.pump();
      expect(
        find.text('O catador ainda tem coletas pendentes.'),
        findsOneWidget,
      );
      expect(repo.confirmadas, isEmpty);
      expect(find.text('Zé'), findsOneWidget);

      await t.tap(find.text('Confirmar entrega'));
      await t.pump();
      await t.pump();
      expect(find.text('Entrega confirmada'), findsOneWidget);
      expect(repo.confirmadas, ['r1']);
    });

    testWidgets('não há nenhuma referência à pesagem na tela', (t) async {
      final repo = PontoRepositorioFake(entregas: [_entrega('r1', 'Zé', 3, 5)]);
      await _montar(t, repo, const TelaPainelPonto());
      expect(find.textContaining('Pes'), findsNothing);
    });
  });
}
