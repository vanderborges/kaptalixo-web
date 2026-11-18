import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/recursos/gerador/dados/acompanhamento_remoto.dart';
import 'package:kaptalixo/recursos/gerador/dados/acompanhamento_repositorio_impl.dart';
import 'package:kaptalixo/recursos/gerador/dominio/acompanhamento_coleta.dart';
import 'package:kaptalixo/recursos/gerador/dominio/falha_acompanhamento.dart';
import 'package:kaptalixo/recursos/gerador/dominio/dados_solicitacao.dart';
import 'package:kaptalixo/recursos/gerador/dados/solicitacao_repositorio_impl.dart';
import 'package:latlong2/latlong.dart';

class _Remoto implements AcompanhamentoRemoto {
  Map<String, dynamic>? linha;
  Map<String, dynamic>? posicao;
  Object? erroBusca;
  Object? erroCancelar;
  final eventos = StreamController<void>.broadcast();
  final cancelados = <(String, String?)>[];
  int buscas = 0;

  @override
  Future<Map<String, dynamic>?> buscarSolicitacao(String id) async {
    buscas++;
    if (erroBusca != null) throw erroBusca!;
    return linha;
  }

  @override
  Future<Map<String, dynamic>?> buscarPosicao(String id) async => posicao;

  @override
  Stream<void> mudancas(String id) => eventos.stream;

  List<Map<String, dynamic>> atuais = [];
  final eventosAtuais = StreamController<void>.broadcast();

  @override
  Future<List<Map<String, dynamic>>> buscarAtuais() async {
    buscas++;
    if (erroBusca != null) throw erroBusca!;
    return atuais;
  }

  @override
  Stream<void> mudancasAtuais() => eventosAtuais.stream;

  @override
  Future<void> cancelar(String id, String? motivo) async {
    cancelados.add((id, motivo));
    if (erroCancelar != null) throw erroCancelar!;
  }
}

Map<String, dynamic> _linha(String status, {Map<String, dynamic>? extra}) => {
  'id': 's1',
  'status': status,
  'endereco_texto': 'Rua A, 1',
  'lat': -23.55,
  'lng': -46.63,
  'qtd_sacos': 2,
  'pin_coleta': '4821',
  'tentativas_oferta': 1,
  'catador_nome': 'João Silva',
  'catador_tipo_veiculo': 'bicicleta',
  'catador_avaliacao_media': '4.80',
  'catador_lat': -23.56,
  'catador_lng': -46.64,
  'atualizado_em': '2026-01-01T10:00:00Z',
  ...?extra,
};

void main() {
  test('le eta e distancia_trecho_m da visao', () {
    final c = AcompanhamentoColeta.deLinha({
      ..._linha('aceita'),
      'eta': '2030-01-01T10:06:00+00:00',
      'distancia_trecho_m': 1234,
    });
    expect(c.eta, DateTime.utc(2030, 1, 1, 10, 6));
    expect(c.distanciaTrechoM, 1234);
    expect(c.chegadaVisivel, isTrue);
    final sem = AcompanhamentoColeta.deLinha(_linha('aceita'));
    expect(sem.eta, isNull);
    expect(sem.chegadaVisivel, isFalse);
  });

  test('interpreta a visao do gerador (catador, nota, veiculo, PIN)', () {
    final c = AcompanhamentoColeta.deLinha(_linha('a_caminho'));
    expect(c.status, StatusColeta.aCaminho);
    expect(c.pin, '4821');
    expect(c.catador!.nome, 'João Silva');
    expect(c.catador!.avaliacaoMedia, 4.8);
    expect(c.catador!.veiculoRotulo, 'Bicicleta');
    expect(c.catador!.posicao, const LatLng(-23.56, -46.64));
  });

  test('posicao_atendimento prevalece sobre a da visao', () {
    final c = AcompanhamentoColeta.deLinha(
      _linha('a_caminho'),
      posicao: {'lat': -23.551, 'lng': -46.631},
    );
    expect(c.catador!.posicao, const LatLng(-23.551, -46.631));
  });

  test('buscando sem catador; status desconhecido falha', () {
    final c = AcompanhamentoColeta.deLinha(
      _linha('buscando', extra: {'catador_nome': null}),
    );
    expect(c.catador, isNull);
    expect(() => StatusColeta.doCodigo('xyz'), throwsFormatException);
  });

  test('stream emite o retrato inicial e a cada evento Realtime', () async {
    final r = _Remoto()
      ..linha = _linha('buscando', extra: {'catador_nome': null});
    final repo = AcompanhamentoRepositorioImpl(r);
    final recebidos = <StatusColeta>[];
    final sub = repo.observar('s1').listen((c) => recebidos.add(c.status));
    await pumpEventQueue();
    r.linha = _linha('aceita');
    r.posicao = {'lat': -23.5, 'lng': -46.6};
    r.eventos.add(null);
    await pumpEventQueue();
    r.linha = _linha('a_caminho');
    r.eventos.add(null);
    await pumpEventQueue();
    r.linha = _linha('no_local');
    r.eventos.add(null);
    await pumpEventQueue();
    r.linha = _linha('coletada');
    r.eventos.add(null);
    await pumpEventQueue();
    await sub.cancel();
    expect(recebidos, [
      StatusColeta.buscando,
      StatusColeta.aceita,
      StatusColeta.aCaminho,
      StatusColeta.noLocal,
      StatusColeta.coletada,
    ]);
    expect(r.eventos.hasListener, isFalse);
  });

  test('observarAtuais emite coletada + ativa e reage a eventos', () async {
    final r = _Remoto()
      ..atuais = [
        _linha('coletada', extra: {'id': 'velha'}),
        _linha('buscando', extra: {'id': 'nova', 'catador_nome': null}),
      ];
    final repo = AcompanhamentoRepositorioImpl(r);
    final recebidos = <List<String>>[];
    final sub = repo.observarAtuais().listen(
      (l) => recebidos.add([for (final c in l) '${c.id}:${c.status.codigo}']),
    );
    await pumpEventQueue();
    r.atuais = [
      _linha('aceita', extra: {'id': 'nova'}),
    ];
    r.eventosAtuais.add(null);
    await pumpEventQueue();
    await sub.cancel();
    expect(recebidos, [
      ['velha:coletada', 'nova:buscando'],
      ['nova:aceita'],
    ]);
    expect(r.eventosAtuais.hasListener, isFalse);
  });

  test('observarAtuais traduz erro em FalhaAcompanhamento', () async {
    final r = _Remoto()..erroBusca = StateError('socket');
    await expectLater(
      AcompanhamentoRepositorioImpl(r).observarAtuais(),
      emitsError(isA<FalhaAcompanhamento>()),
    );
  });

  test('solicitacao inexistente vira FalhaAcompanhamento no stream', () async {
    final repo = AcompanhamentoRepositorioImpl(_Remoto());
    await expectLater(
      repo.observar('x'),
      emitsError(
        isA<FalhaAcompanhamento>().having(
          (f) => f.motivo,
          'motivo',
          MotivoFalhaAcompanhamento.inexistente,
        ),
      ),
    );
  });

  test('erro de rede vira falha geral em linguagem simples', () async {
    final r = _Remoto()..erroBusca = StateError('socket');
    await expectLater(
      AcompanhamentoRepositorioImpl(r).observar('x'),
      emitsError(isA<FalhaAcompanhamento>()),
    );
  });

  test('cancelar envia motivo aparado (ou nulo) e traduz erros', () async {
    final r = _Remoto();
    final repo = AcompanhamentoRepositorioImpl(r);
    await repo.cancelar('s1', motivo: '  mudei de ideia ');
    await repo.cancelar('s1', motivo: '   ');
    expect(r.cancelados, [('s1', 'mudei de ideia'), ('s1', null)]);
    r.erroCancelar = Exception('solicitacao_nao_cancelavel');
    await expectLater(
      repo.cancelar('s1'),
      throwsA(
        isA<FalhaAcompanhamento>().having(
          (f) => f.motivo,
          'motivo',
          MotivoFalhaAcompanhamento.naoCancelavel,
        ),
      ),
    );
  });

  test('P-018: endereco_texto e truncado em 200 caracteres', () {
    final d = DadosSolicitacao(
      posicao: const LatLng(-23.5, -46.6),
      enderecoTexto: '  ${'a' * 300}  ',
      qtdSacos: 1,
    );
    expect(d.validar(), isNull);
    final params = SolicitacaoRepositorioImpl.parametros(d);
    expect((params['p_endereco_texto'] as String).length, 200);
  });
}
