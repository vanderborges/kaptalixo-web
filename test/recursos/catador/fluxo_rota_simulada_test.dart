import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/nucleo/localizacao/localizacao_simulada.dart';
import 'package:kaptalixo/recursos/catador/dados/rota_repositorio_fake.dart';
import 'package:kaptalixo/recursos/catador/dominio/rota_ativa.dart';
import 'package:latlong2/latlong.dart';

import 'rota_fixtures.dart';

/// Fluxo completo do UC08 com GPS simulado (T4.4) e servidor fake:
/// Iniciar rota -> chegada automática (<= 80 m) -> PIN -> próxima parada ->
/// ponto de descarte -> rota concluída. Teste "de integração leve": sem
/// dispositivo, rede nem Supabase.
void main() {
  testWidgets('rota inteira percorrida pela LocalizacaoSimulada', (t) async {
    final relogio = RelogioTeste();
    final repo = RotaRepositorioFake(
      rota: rotaDemo(),
      pins: pinsDemo,
      relogio: relogio.agora,
    );
    // Parte ~330 m ao sul da casa 1 e segue 36 km/h (10 m/s) até o ponto.
    final gps = LocalizacaoSimulada(
      polyline: const [LatLng(-23.5530, -46.6300), casa1, casa2, pontoCentral],
      velocidadeKmh: 36,
      relogio: relogio.agora,
    );
    var saiu = false;
    await montarRota(
      t,
      repo: repo,
      gps: gps,
      relogio: relogio,
      aoSair: () => saiu = true,
    );

    // 1. Iniciar rota.
    await t.tap(find.byKey(const Key('iniciar-rota')));
    await t.pump();
    await t.pump();
    expect(find.text('Coleta 1 de 2'), findsOneWidget);

    // 2. Anda até a casa 1; a 80 m o app marca "Cheguei" sozinho.
    Future<void> ateAparecer(Finder f, {int maxSegundos = 200}) async {
      for (var i = 0; i < maxSegundos && f.evaluate().isEmpty; i++) {
        await avancar(t, relogio, 1);
      }
      expect(f, findsOneWidget);
    }

    await ateAparecer(find.text('Peça o PIN ao morador'));
    expect(repo.chamadas.where((c) => c == 'avancar:cheguei').length, 1);
    expect(repo.rota!.paradas.first.status, StatusParada.noLocal);

    // 3. PIN informado pelo morador.
    await confirmarPin(t, pinsDemo['sol-1']!);
    expect(find.text('Coleta 2 de 2'), findsOneWidget);

    // 4. Segunda coleta, desta vez com um erro de digitação antes do certo.
    await ateAparecer(find.text('Peça o PIN ao morador'));
    await confirmarPin(t, '0000');
    expect(find.text('PIN incorreto. Restam 2 tentativas.'), findsOneWidget);
    await confirmarPin(t, pinsDemo['sol-2']!);
    expect(find.text('Levar ao ponto'), findsOneWidget);

    // 5. Ponto de descarte: chegada automática e espera da pesagem.
    await ateAparecer(find.byKey(const Key('aguardando-pesagem')));
    expect(repo.rota!.descarte!.status, StatusParada.noLocal);

    // 6. O ponto registra a entrega (T5.4): rota concluída.
    repo.emitir(rotaDemo(status: StatusRota.concluida));
    await t.pump();
    await t.pump();
    expect(find.text('Rota concluída'), findsOneWidget);
    await t.tap(find.byKey(const Key('voltar-inicio')));
    expect(saiu, isTrue);

    // Posição foi enviada durante todo o percurso, sempre com a rota.
    expect(repo.posicoes.length, greaterThan(10));
    expect(repo.posicoes.every((p) => p.rotaId == 'rota-1'), isTrue);
    final antes = repo.posicoes.length;
    await avancar(t, relogio, 15);
    expect(repo.posicoes.length, antes, reason: 'rota encerrada: sem envio');
  });
}
