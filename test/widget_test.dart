import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/app/app.dart';

void main() {
  testWidgets('Fumaça: app abre na tela inicial', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KaptalixoApp()));
    await tester.pumpAndSettle();

    expect(find.text('Kaptalixo'), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
