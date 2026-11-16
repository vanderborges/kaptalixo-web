import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/nucleo/localizacao/localizacao_fake.dart';
import 'package:kaptalixo/nucleo/localizacao/providers.dart';
import 'package:kaptalixo/nucleo/modelos/papel.dart';
import 'package:kaptalixo/nucleo/modelos/sessao.dart';
import 'package:kaptalixo/nucleo/modelos/status_cadastro.dart';
import 'package:kaptalixo/recursos/auth/apresentacao/providers.dart';
import 'package:kaptalixo/recursos/auth/dados/auth_repositorio_fake.dart';
import 'package:kaptalixo/recursos/catador/apresentacao/providers.dart';
import 'package:kaptalixo/recursos/catador/apresentacao/tela_home_catador.dart';
import 'package:kaptalixo/recursos/catador/dados/disponibilidade_repositorio_fake.dart';
import 'package:kaptalixo/recursos/catador/dominio/falha_catador.dart';
import 'package:kaptalixo/recursos/catador/dominio/situacao_catador.dart';
import 'package:latlong2/latlong.dart';

const _aprovado = Sessao(
  usuarioId: 'c1',
  papel: Papel.catador,
  statusCadastro: StatusCadastro.aprovado,
);
const _pendente = Sessao(
  usuarioId: 'c1',
  papel: Papel.catador,
  statusCadastro: StatusCadastro.pendente,
);

Future<void> _montar(
  WidgetTester t, {
  required DisponibilidadeRepositorioFake repo,
  Sessao sessao = _aprovado,
  LocalizacaoFake? gps,
}) async {
  final loc =
      gps ?? (LocalizacaoFake()..emitirPonto(const LatLng(-23.5, -46.6)));
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        disponibilidadeRepositorioProvider.overrideWithValue(repo),
        authRepositorioProvider.overrideWithValue(
          AuthRepositorioFake(sessao: sessao),
        ),
        servicoLocalizacaoProvider.overrideWithValue(loc),
      ],
      child: const MaterialApp(home: TelaHomeCatador()),
    ),
  );
  await t.pump();
  await t.pump();
}

void main() {
  testWidgets('começa offline e alterna para disponível e de volta', (t) async {
    final repo = DisponibilidadeRepositorioFake();
    await _montar(t, repo: repo);
    expect(find.text('Offline'), findsOneWidget);

    await t.tap(find.text('Ficar disponível'));
    await t.pump();
    await t.pump();
    expect(find.text('Disponível'), findsOneWidget);
    expect(repo.situacao, SituacaoCatador.disponivel);

    await t.tap(find.text('Ficar offline'));
    await t.pump();
    await t.pump();
    expect(find.text('Offline'), findsOneWidget);
    expect(repo.situacao, SituacaoCatador.offline);
  });

  testWidgets('catador pendente fica bloqueado com aviso (RN10)', (t) async {
    final repo = DisponibilidadeRepositorioFake(aprovado: false);
    await _montar(t, repo: repo, sessao: _pendente);
    expect(find.text('Aguardando aprovação do cadastro.'), findsOneWidget);
    final botao = t.widget<FilledButton>(find.byType(FilledButton));
    expect(botao.onPressed, isNull);
    await t.tap(find.text('Ficar disponível'), warnIfMissed: false);
    await t.pump();
    expect(repo.chamadasAlternar, 0);
  });

  testWidgets('suspenso mostra aviso próprio', (t) async {
    await _montar(
      t,
      repo: DisponibilidadeRepositorioFake(aprovado: false),
      sessao: const Sessao(
        usuarioId: 'c1',
        papel: Papel.catador,
        statusCadastro: StatusCadastro.suspenso,
      ),
    );
    expect(find.textContaining('suspenso'), findsOneWidget);
  });

  testWidgets('servidor recusa (cadastro_nao_aprovado): mostra erro', (
    t,
  ) async {
    final repo = DisponibilidadeRepositorioFake(aprovado: false);
    await _montar(t, repo: repo); // sessão local aprovada, servidor discorda
    await t.tap(find.text('Ficar disponível'));
    await t.pump();
    await t.pump();
    expect(find.text('Aguardando aprovação.'), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget);
  });

  testWidgets('em rota: botão desabilitado', (t) async {
    await _montar(
      t,
      repo: DisponibilidadeRepositorioFake(situacao: SituacaoCatador.emRota),
    );
    expect(find.text('Em rota'), findsOneWidget);
    expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });

  testWidgets('envia posição ao ficar disponível e a cada 30 s', (t) async {
    final repo = DisponibilidadeRepositorioFake();
    await _montar(t, repo: repo);
    await t.tap(find.text('Ficar disponível'));
    await t.pump();
    await t.pump();
    expect(repo.posicoesEnviadas, hasLength(1));

    await t.pump(const Duration(seconds: 29));
    expect(repo.posicoesEnviadas, hasLength(1));
    await t.pump(const Duration(seconds: 1));
    expect(repo.posicoesEnviadas, hasLength(2));
    await t.pump(const Duration(seconds: 30));
    expect(repo.posicoesEnviadas, hasLength(3));
  });

  testWidgets('para de enviar ao ficar offline', (t) async {
    final repo = DisponibilidadeRepositorioFake();
    await _montar(t, repo: repo);
    await t.tap(find.text('Ficar disponível'));
    await t.pump();
    await t.pump();
    await t.pump(const Duration(seconds: 30));
    final antes = repo.posicoesEnviadas.length;

    await t.tap(find.text('Ficar offline'));
    await t.pump();
    await t.pump();
    await t.pump(const Duration(seconds: 120));
    expect(repo.posicoesEnviadas, hasLength(antes));
  });

  testWidgets('offline nunca envia posição', (t) async {
    final repo = DisponibilidadeRepositorioFake();
    await _montar(t, repo: repo);
    await t.pump(const Duration(seconds: 90));
    expect(repo.posicoesEnviadas, isEmpty);
  });

  testWidgets('já disponível ao abrir: retoma o envio', (t) async {
    final repo = DisponibilidadeRepositorioFake(
      situacao: SituacaoCatador.disponivel,
    );
    await _montar(t, repo: repo);
    expect(find.text('Disponível'), findsOneWidget);
    expect(repo.posicoesEnviadas, hasLength(1));
  });

  testWidgets('descartar a tela cancela o timer', (t) async {
    final repo = DisponibilidadeRepositorioFake(
      situacao: SituacaoCatador.disponivel,
    );
    await _montar(t, repo: repo);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 120));
    expect(repo.posicoesEnviadas, hasLength(1));
  });

  testWidgets('GPS indisponível: avisa e segue disponível', (t) async {
    final repo = DisponibilidadeRepositorioFake(
      situacao: SituacaoCatador.disponivel,
    );
    await _montar(t, repo: repo, gps: LocalizacaoFake());
    expect(find.textContaining('Sem sinal de GPS'), findsOneWidget);
    expect(find.text('Disponível'), findsOneWidget);
  });

  testWidgets('erro ao enviar posição (offline no servidor) volta a offline', (
    t,
  ) async {
    final repo = DisponibilidadeRepositorioFake(
      situacao: SituacaoCatador.disponivel,
      falhaPosicao: const FalhaCatador(MotivoFalhaCatador.indisponivel),
    );
    await _montar(t, repo: repo);
    expect(find.text('Offline'), findsOneWidget);
  });
}
