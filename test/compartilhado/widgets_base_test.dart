import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/compartilhado/botao_primario.dart';
import 'package:kaptalixo/compartilhado/cartao_kapta.dart';
import 'package:kaptalixo/compartilhado/estados.dart';

Widget envolver(Widget filho) => MaterialApp(home: Scaffold(body: filho));

void main() {
  testWidgets('BotaoPrimario dispara onPressed e tem alvo >= 48 dp', (
    tester,
  ) async {
    var toques = 0;
    await tester.pumpWidget(
      envolver(BotaoPrimario(rotulo: 'Pedir', onPressed: () => toques++)),
    );
    expect(tester.getSize(find.byType(FilledButton)).height, greaterThan(47));
    await tester.tap(find.text('Pedir'));
    expect(toques, 1);
  });

  testWidgets('BotaoPrimario carregando desabilita o toque', (tester) async {
    var toques = 0;
    await tester.pumpWidget(
      envolver(
        BotaoPrimario(
          rotulo: 'Pedir',
          carregando: true,
          onPressed: () => toques++,
        ),
      ),
    );
    await tester.tap(find.byType(FilledButton));
    expect(toques, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('CartaoKapta mostra conteúdo e responde ao toque', (
    tester,
  ) async {
    var toques = 0;
    await tester.pumpWidget(
      envolver(CartaoKapta(onTap: () => toques++, child: const Text('Oi'))),
    );
    await tester.tap(find.text('Oi'));
    expect(toques, 1);
  });

  testWidgets('EstadoVazio mostra a mensagem', (tester) async {
    await tester.pumpWidget(envolver(const EstadoVazio(mensagem: 'Nada aqui')));
    expect(find.text('Nada aqui'), findsOneWidget);
  });

  testWidgets('EstadoCarregando mostra indicador', (tester) async {
    await tester.pumpWidget(envolver(const EstadoCarregando()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Carregando...'), findsOneWidget);
  });

  testWidgets('EstadoErro permite tentar novamente', (tester) async {
    var tentativas = 0;
    await tester.pumpWidget(
      envolver(
        EstadoErro(mensagem: 'Falhou', aoTentarNovamente: () => tentativas++),
      ),
    );
    expect(find.text('Falhou'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    expect(tentativas, 1);
  });
}
