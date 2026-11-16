import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/nucleo/localizacao/falha_localizacao.dart';
import 'package:kaptalixo/nucleo/localizacao/localizacao_fake.dart';
import 'package:kaptalixo/recursos/catador/dados/rota_repositorio_fake.dart';
import 'package:kaptalixo/recursos/catador/dominio/falha_catador.dart';
import 'package:kaptalixo/recursos/catador/dominio/rota_ativa.dart';
import 'package:latlong2/latlong.dart';

import 'rota_fixtures.dart';

/// GPS longe de qualquer parada.
LocalizacaoFake _longe() =>
    LocalizacaoFake()..emitirPonto(const LatLng(-23.60, -46.70));

RotaRepositorioFake _repo(RelogioTeste r, {RotaAtiva? rota}) =>
    RotaRepositorioFake(
      rota: rota ?? rotaDemo(),
      pins: pinsDemo,
      relogio: r.agora,
    );

/// Monta a tela com a rota já em andamento (primeira parada a caminho).
Future<(RotaRepositorioFake, RelogioTeste)> _emAndamento(
  WidgetTester t, {
  LocalizacaoFake? gps,
}) async {
  final relogio = RelogioTeste();
  final repo = _repo(relogio);
  await repo.iniciar('rota-1');
  await montarRota(t, repo: repo, gps: gps ?? _longe(), relogio: relogio);
  return (repo, relogio);
}

void main() {
  _testesDeErro();
  testWidgets('rota planejada: resumo e Iniciar rota leva à primeira parada', (
    t,
  ) async {
    final relogio = RelogioTeste();
    final repo = _repo(relogio);
    await montarRota(t, repo: repo, gps: _longe(), relogio: relogio);

    expect(find.text('2 coletas'), findsOneWidget);
    expect(find.text('2,4 km · 15 min'), findsOneWidget);
    expect(find.text('Iniciar rota'), findsOneWidget);
    expect(find.text('Cheguei'), findsNothing);

    await t.tap(find.byKey(const Key('iniciar-rota')));
    await t.pump();
    await t.pump();

    expect(repo.chamadas, contains('iniciar'));
    expect(find.text('Coleta 1 de 2'), findsOneWidget);
    expect(find.text('Rua das Flores, 10'), findsOneWidget);
    expect(find.text('Maria · 2 sacos'), findsOneWidget);
    expect(find.text('Cheguei'), findsOneWidget);
    expect(find.text('Pular parada'), findsOneWidget);
    // marcadores das paradas e do catador no mapa
    expect(find.byKey(const Key('marcador-par-1')), findsOneWidget);
    expect(find.byKey(const Key('marcador-par-3')), findsOneWidget);
    expect(find.byKey(const Key('marcador-catador')), findsOneWidget);
  });

  testWidgets('mostra distância e ETA da próxima parada', (t) async {
    await _emAndamento(t);
    // (-23.60,-46.70) até casa1: ~12,7 km a 5 m/s do ServicoRotasFake.
    expect(find.textContaining(' km · '), findsOneWidget);
    expect(find.textContaining(' min'), findsWidgets);
  });

  testWidgets('envia a posição a cada 5 s com o id da rota e para ao sair', (
    t,
  ) async {
    final relogio = RelogioTeste();
    final repo = _repo(relogio);
    await montarRota(t, repo: repo, gps: _longe(), relogio: relogio);
    expect(repo.posicoes.length, 1); // envio imediato

    await avancar(t, relogio, 5);
    expect(repo.posicoes.length, 2);
    await avancar(t, relogio, 10);
    expect(repo.posicoes.length, 4);
    expect(repo.posicoes.first.rotaId, 'rota-1');
    expect(repo.posicoes.first.lat, -23.60);

    // Sair da tela (autoDispose): o timer morre e o stream é cancelado.
    await t.pumpWidget(const SizedBox());
    final antes = repo.posicoes.length;
    await avancar(t, relogio, 20);
    expect(repo.posicoes.length, antes);
    expect(repo.cancelamentos, 1);
  });

  testWidgets('não sobrepõe envios quando o anterior ainda não terminou', (
    t,
  ) async {
    final relogio = RelogioTeste();
    final repo = _repo(relogio);
    final trava = Completer<void>();
    repo.travaPosicao = trava.future;
    await montarRota(t, repo: repo, gps: _longe(), relogio: relogio);

    await avancar(t, relogio, 20);
    expect(repo.posicoes.length, 1);

    trava.complete();
    await t.pump();
    await avancar(t, relogio, 5);
    expect(repo.posicoes.length, 2);
  });

  testWidgets('sem GPS avisa que a posição não está sendo enviada', (t) async {
    final gps = LocalizacaoFake(
      falha: const FalhaLocalizacao(MotivoFalhaLocalizacao.indisponivel),
    );
    final relogio = RelogioTeste();
    await montarRota(t, repo: _repo(relogio), gps: gps, relogio: relogio);
    expect(find.byKey(const Key('sem-posicao')), findsOneWidget);
  });

  testWidgets('Cheguei abre o teclado de PIN e nunca mostra o PIN certo', (
    t,
  ) async {
    final (repo, _) = await _emAndamento(t);
    await t.tap(find.byKey(const Key('cheguei')));
    await t.pump();
    await t.pump();

    expect(repo.chamadas, contains('avancar:cheguei'));
    expect(find.text('Peça o PIN ao morador'), findsOneWidget);
    expect(find.byKey(const Key('confirmar-pin')), findsOneWidget);
    expect(find.textContaining('4821'), findsNothing);
    expect(find.textContaining('1357'), findsNothing);
  });

  testWidgets('PIN correto conclui a coleta e segue para a próxima parada', (
    t,
  ) async {
    final (repo, _) = await _emAndamento(t);
    await t.tap(find.byKey(const Key('cheguei')));
    await t.pump();
    await t.pump();

    // confirmar fica desabilitado até os 4 dígitos
    await digitar(t, '482');
    expect(
      t.widget<FilledButton>(find.byKey(const Key('confirmar-pin'))).onPressed,
      isNull,
    );
    await digitar(t, '1');
    await t.tap(find.byKey(const Key('confirmar-pin')));
    await t.pump();
    await t.pump();

    expect(repo.chamadas, contains('avancar:concluir'));
    expect(find.text('Coleta 2 de 2'), findsOneWidget);
    expect(find.text('Rua do Sol, 55'), findsOneWidget);
    expect(find.text('Peça o PIN ao morador'), findsNothing);
  });

  testWidgets('apagar remove o último dígito', (t) async {
    await _emAndamento(t);
    await t.tap(find.byKey(const Key('cheguei')));
    await t.pump();
    await t.pump();
    await digitar(t, '12');
    await t.tap(find.byKey(const Key('tecla-apagar')));
    await t.pump();
    final casas = [
      for (var i = 0; i < 4; i++)
        t
            .widget<Text>(
              find.descendant(
                of: find.byKey(Key('pin-casa-$i')),
                matching: find.byType(Text),
              ),
            )
            .data,
    ];
    expect(casas, ['1', '', '', '']);
  });

  testWidgets('PIN errado mostra tentativas restantes e limpa os dígitos', (
    t,
  ) async {
    final (repo, _) = await _emAndamento(t);
    await t.tap(find.byKey(const Key('cheguei')));
    await t.pump();
    await t.pump();

    await confirmarPin(t, '0000');
    expect(find.text('PIN incorreto. Restam 2 tentativas.'), findsOneWidget);
    expect(find.text('Coleta 1 de 2'), findsOneWidget);
    expect(
      t.widget<FilledButton>(find.byKey(const Key('confirmar-pin'))).onPressed,
      isNull, // dígitos limpos
    );

    await confirmarPin(t, '1111');
    expect(find.text('PIN incorreto. Resta 1 tentativa.'), findsOneWidget);
    expect(
      repo.rota!.paradas.first.status,
      StatusParada.noLocal,
      reason: 'coleta nunca confirmada com PIN errado',
    );
  });

  testWidgets('3 erros bloqueiam por 2 min e liberam depois', (t) async {
    final (repo, relogio) = await _emAndamento(t);
    await t.tap(find.byKey(const Key('cheguei')));
    await t.pump();
    await t.pump();

    await confirmarPin(t, '0000');
    await confirmarPin(t, '1111');
    await confirmarPin(t, '2222');

    expect(find.byKey(const Key('pin-bloqueado')), findsOneWidget);
    expect(find.textContaining('02:00'), findsOneWidget);
    expect(find.byKey(const Key('pin-incorreto')), findsNothing);
    // teclado e confirmação travados; nem o PIN certo passa
    expect(
      t.widget<FilledButton>(find.byKey(const Key('tecla-4'))).onPressed,
      isNull,
    );
    expect(
      t.widget<FilledButton>(find.byKey(const Key('confirmar-pin'))).onPressed,
      isNull,
    );
    final concluirAntes = repo.chamadas
        .where((c) => c == 'avancar:concluir')
        .length;
    expect(concluirAntes, 3);

    await avancar(t, relogio, 60);
    expect(find.textContaining('01:00'), findsOneWidget);
    await avancar(t, relogio, 61);
    expect(find.byKey(const Key('pin-bloqueado')), findsNothing);

    await confirmarPin(t, '4821');
    expect(find.text('Coleta 2 de 2'), findsOneWidget);
  });

  testWidgets('Pular parada pede o motivo e devolve a coleta à fila', (
    t,
  ) async {
    final (repo, _) = await _emAndamento(t);
    await t.tap(find.byKey(const Key('pular-parada')));
    await t.pumpAndSettle();
    expect(find.text('Pular esta parada?'), findsOneWidget);

    await t.tap(find.byKey(const Key('motivo-Não atendeu')));
    await t.pump();
    await t.tap(find.byKey(const Key('confirmar-pular')));
    await t.pumpAndSettle();

    expect(repo.motivos, ['Não atendeu']);
    expect(repo.rota!.paradas.first.status, StatusParada.pulada);
    expect(find.text('Coleta 1 de 1'), findsOneWidget);
    expect(find.text('Rua do Sol, 55'), findsOneWidget);
  });

  testWidgets('Pular parada: voltar no diálogo não faz nada', (t) async {
    final (repo, _) = await _emAndamento(t);
    await t.tap(find.byKey(const Key('pular-parada')));
    await t.pumpAndSettle();
    await t.tap(find.text('Voltar'));
    await t.pumpAndSettle();
    expect(repo.chamadas.where((c) => c == 'avancar:pular'), isEmpty);
  });

  testWidgets('depois das coletas a rota segue ao ponto de descarte', (
    t,
  ) async {
    final (repo, _) = await _emAndamento(t);
    for (final (pin) in ['4821', '1357']) {
      await t.tap(find.byKey(const Key('cheguei')));
      await t.pump();
      await t.pump();
      await confirmarPin(t, pin);
    }
    expect(find.text('Levar ao ponto'), findsOneWidget);
    expect(find.text('Ponto Central'), findsWidgets);

    await t.tap(find.byKey(const Key('cheguei')));
    await t.pump();
    await t.pump();
    expect(find.text('Cheguei ao ponto'), findsNothing);
    expect(find.byKey(const Key('aguardando-pesagem')), findsOneWidget);
    expect(find.byKey(const Key('trocar-ponto')), findsNothing);
    expect(repo.rota!.descarte!.status, StatusParada.noLocal);
  });

  testWidgets('trocar ponto de descarte escolhe entre as alternativas', (
    t,
  ) async {
    final (repo, _) = await _emAndamento(t);
    expect(find.textContaining('Ponto: Ponto Central'), findsOneWidget);

    await t.tap(find.byKey(const Key('trocar-ponto')));
    await t.pumpAndSettle();
    expect(find.text('Ponto Norte'), findsOneWidget);
    await t.tap(find.byKey(const Key('ponto-pt-2')));
    await t.pumpAndSettle();

    expect(repo.chamadas, contains('trocarPonto:pt-2'));
    expect(find.textContaining('Ponto: Ponto Norte'), findsOneWidget);
    expect(repo.rota!.versao, 2);
  });

  testWidgets('trocar ponto sem alternativas avisa', (t) async {
    final relogio = RelogioTeste();
    final repo = _repo(
      relogio,
      rota: rotaDemo().copiar(alternativas: const []),
    );
    await montarRota(t, repo: repo, gps: _longe(), relogio: relogio);
    await t.tap(find.byKey(const Key('trocar-ponto')));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('sem-alternativas')), findsOneWidget);
  });

  testWidgets('falha do servidor vira aviso curto e some ao fechar', (t) async {
    final (repo, _) = await _emAndamento(t);
    repo.proximaFalha = const FalhaCatador(MotivoFalhaCatador.paradaInvalida);
    await t.tap(find.byKey(const Key('cheguei')));
    await t.pump();
    await t.pump();
    expect(
      find.text('Esta parada não aceita esta ação agora.'),
      findsOneWidget,
    );
    await t.tap(find.byTooltip('Fechar aviso'));
    await t.pump();
    expect(find.byKey(const Key('aviso-rota')), findsNothing);
  });

  testWidgets('rota concluída mostra o fim e volta ao início', (t) async {
    final relogio = RelogioTeste();
    final repo = _repo(relogio, rota: rotaDemo(status: StatusRota.concluida));
    var saiu = false;
    await montarRota(
      t,
      repo: repo,
      gps: _longe(),
      relogio: relogio,
      aoSair: () => saiu = true,
    );
    expect(find.text('Rota concluída'), findsOneWidget);
    await t.tap(find.byKey(const Key('voltar-inicio')));
    expect(saiu, isTrue);
    // rota encerrada não envia posição
    expect(repo.posicoes, isEmpty);
  });

  testWidgets('rota concluída pelo ponto chega pelo Realtime', (t) async {
    final (repo, _) = await _emAndamento(t);
    repo.emitir(rotaDemo(status: StatusRota.concluida));
    await t.pump();
    expect(find.text('Rota concluída'), findsOneWidget);
  });

  testWidgets('rota inexistente', (t) async {
    final relogio = RelogioTeste();
    await montarRota(
      t,
      repo: RotaRepositorioFake(relogio: relogio.agora),
      gps: _longe(),
      relogio: relogio,
    );
    expect(find.text('Rota não encontrada.'), findsOneWidget);
  });

  testWidgets('erro de stream com a rota na tela mantém o painel', (t) async {
    final relogio = RelogioTeste();
    final repo = _repo(relogio);
    await montarRota(t, repo: repo, gps: _longe(), relogio: relogio);
    repo.emitirErro(const FalhaCatador(MotivoFalhaCatador.generico));
    await t.pump();
    // com a rota já na tela o erro de stream não derruba o painel
    expect(find.text('Iniciar rota'), findsOneWidget);
  });

  testWidgets('Cheguei automático a até 80 m da parada', (t) async {
    final gps = LocalizacaoFake()
      ..emitirPonto(const LatLng(-23.5500 - 0.001, -46.63)); // ~111 m
    final (repo, relogio) = await _emAndamento(t, gps: gps);
    await avancar(t, relogio, 6);
    expect(repo.chamadas, isNot(contains('avancar:cheguei')));

    gps.emitirPonto(const LatLng(-23.5500 - 0.0005, -46.63)); // ~55 m
    await avancar(t, relogio, 6);
    expect(repo.chamadas.where((c) => c == 'avancar:cheguei').length, 1);
    expect(find.text('Peça o PIN ao morador'), findsOneWidget);
  });
}

/// Falha a primeira leitura e funciona na segunda.
class _RepoQueFalhaUmaVez extends RotaRepositorioFake {
  _RepoQueFalhaUmaVez({super.rota, super.relogio});

  int leituras = 0;

  @override
  Stream<RotaAtiva?> observar(String rotaId) {
    leituras++;
    if (leituras == 1) {
      return Stream.error(const FalhaCatador(MotivoFalhaCatador.generico));
    }
    return super.observar(rotaId);
  }
}

void _testesDeErro() {
  testWidgets('erro na primeira leitura oferece tentar novamente', (t) async {
    final relogio = RelogioTeste();
    final repo = _RepoQueFalhaUmaVez(rota: rotaDemo(), relogio: relogio.agora);
    await montarRota(t, repo: repo, gps: _longe(), relogio: relogio);
    expect(find.text('Algo deu errado. Tente de novo.'), findsOneWidget);

    await t.tap(find.text('Tentar novamente'));
    await t.pump();
    await t.pump();
    expect(find.text('Iniciar rota'), findsOneWidget);
    expect(repo.leituras, 2);
  });
}
