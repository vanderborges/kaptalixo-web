import 'dart:typed_data';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/recursos/catador/dados/rota_remoto.dart';
import 'package:kaptalixo/recursos/catador/dados/rota_repositorio_impl.dart';
import 'package:kaptalixo/recursos/catador/dominio/falha_catador.dart';
import 'package:kaptalixo/recursos/catador/dominio/rota_ativa.dart';
import 'package:latlong2/latlong.dart';

/// EWKB hex de POINT(-46.63 -23.55) com SRID 4326 (little endian).
String _ewkb(double lng, double lat) {
  String d(double v) {
    final b = ByteData(8)..setFloat64(0, v, Endian.little);
    return [
      for (var i = 0; i < 8; i++)
        b.getUint8(i).toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  return '0101000020E6100000${d(lng)}${d(lat)}';
}

class _RemotoFake implements RotaRemoto {
  Map<String, dynamic>? snapshot;
  Object? erro;
  Map<String, dynamic> respostaAvancar = {'resultado': 'ok'};
  final chamadas = <String>[];
  final mud = StreamController<void>.broadcast();
  int buscas = 0;

  @override
  Future<String?> rotaAbertaId() async => 'rota-1';

  @override
  Future<Map<String, dynamic>?> buscarRota(String rotaId) async {
    buscas++;
    if (erro != null) throw erro!;
    return snapshot;
  }

  @override
  Stream<void> mudancas(String rotaId) => mud.stream;

  @override
  Future<void> iniciarRota(String rotaId) async => chamadas.add('iniciar');

  @override
  Future<Map<String, dynamic>> avancarParada(
    String paradaId,
    String acao, {
    String? pin,
    String? motivo,
  }) async {
    chamadas.add('avancar:$paradaId:$acao:$pin:$motivo');
    if (erro != null) throw erro!;
    return respostaAvancar;
  }

  @override
  Future<void> trocarPonto(String rotaId, String pontoId) async =>
      chamadas.add('trocar:$pontoId');

  @override
  Future<void> atualizarLocalizacao(
    double lat,
    double lng,
    String rotaId,
  ) async => chamadas.add('pos:$lat,$lng,$rotaId');
}

Map<String, dynamic> _snapshot() => {
  'rota': {
    'id': 'rota-1',
    'status': 'em_andamento',
    'ponto_destino_id': 'pt-1',
    'alternativas_ponto': [
      {'ponto_id': 'pt-1', 'score': 9.0},
      {'ponto_id': 'pt-2', 'score': 7.5},
    ],
    'distancia_total_m': 3000,
    'duracao_total_s': 900,
    'polyline': encodarPolylineTeste([
      const LatLng(-23.55, -46.63),
      const LatLng(-23.54, -46.63),
    ]),
    'versao': 3,
  },
  'paradas': [
    {
      'id': 'par-2',
      'ordem': 2,
      'tipo': 'descarte',
      'solicitacao_id': null,
      'ponto_id': 'pt-1',
      'localizacao': {
        'type': 'Point',
        'coordinates': [-46.62, -23.54],
      },
      'status': 'pendente',
      'eta': null,
    },
    {
      'id': 'par-1',
      'ordem': 1,
      'tipo': 'coleta',
      'solicitacao_id': 'sol-1',
      'ponto_id': null,
      'localizacao': _ewkb(-46.63, -23.55),
      'status': 'a_caminho',
      'eta': '2026-01-01T12:10:00+00:00',
      'distancia_trecho_m': 800,
      'duracao_trecho_s': 240,
    },
  ],
  'solicitacoes': [
    {
      'id': 'sol-1',
      'qtd_sacos': 3,
      'endereco_texto': 'Rua das Flores, 10',
      'observacao': 'Portão azul',
      'lat': -23.5501,
      'lng': -46.6301,
      'gerador_nome': 'Maria',
      'bloqueio_pin_ate': '2026-01-01T12:02:00+00:00',
    },
  ],
  'pontos': [
    {
      'id': 'pt-1',
      'nome': 'Ponto Central',
      'localizacao': {
        'type': 'Point',
        'coordinates': [-46.62, -23.54],
      },
    },
    {'id': 'pt-2', 'nome': 'Ponto Norte', 'localizacao': null},
  ],
};

/// Codifica polyline (precisão 5) só para montar a fixture.
String encodarPolylineTeste(List<LatLng> pontos) {
  final sb = StringBuffer();
  var plat = 0;
  var plng = 0;
  void cod(int v) {
    var n = v < 0 ? ~(v << 1) : v << 1;
    while (n >= 0x20) {
      sb.writeCharCode((0x20 | (n & 0x1f)) + 63);
      n >>= 5;
    }
    sb.writeCharCode(n + 63);
  }

  for (final p in pontos) {
    final lat = (p.latitude * 1e5).round();
    final lng = (p.longitude * 1e5).round();
    cod(lat - plat);
    cod(lng - plng);
    plat = lat;
    plng = lng;
  }
  return sb.toString();
}

void main() {
  group('lerPontoGeografico', () {
    test('GeoJSON (lng, lat)', () {
      final p = lerPontoGeografico({
        'type': 'Point',
        'coordinates': [-46.63, -23.55],
      });
      expect(p, const LatLng(-23.55, -46.63));
    });

    test('EWKB hexadecimal com SRID', () {
      final p = lerPontoGeografico(_ewkb(-46.63, -23.55));
      expect(p!.latitude, closeTo(-23.55, 1e-9));
      expect(p.longitude, closeTo(-46.63, 1e-9));
    });

    test('valores desconhecidos viram null', () {
      expect(lerPontoGeografico(null), isNull);
      expect(lerPontoGeografico('xyz'), isNull);
      expect(lerPontoGeografico({'coordinates': 'x'}), isNull);
    });
  });

  group('RotaAtiva.deSnapshot', () {
    final rota = RotaAtiva.deSnapshot(_snapshot());

    test('ordena as paradas e lê status, trajeto e totais', () {
      expect(rota.status, StatusRota.emAndamento);
      expect(rota.versao, 3);
      expect(rota.paradas.map((p) => p.id), ['par-1', 'par-2']);
      expect(rota.trajeto.length, 2);
      expect(rota.distanciaTotalM, 3000);
    });

    test('coleta usa lat/lng da solicitação e dados após o aceite', () {
      final p = rota.paradas.first;
      expect(p.status, StatusParada.aCaminho);
      expect(p.posicao, const LatLng(-23.5501, -46.6301));
      expect(p.qtdSacos, 3);
      expect(p.enderecoTexto, 'Rua das Flores, 10');
      expect(p.geradorNome, 'Maria');
      expect(p.eta, DateTime.utc(2026, 1, 1, 12, 10));
      expect(p.bloqueioPinAte, DateTime.utc(2026, 1, 1, 12, 2));
    });

    test('descarte usa o ponto e as alternativas excluem o destino', () {
      final d = rota.descarte!;
      expect(d.pontoNome, 'Ponto Central');
      expect(d.posicao, const LatLng(-23.54, -46.62));
      expect(rota.alternativas.map((a) => a.id), ['pt-2']);
      expect(rota.alternativas.first.posicao, isNull);
    });

    test('próxima: coleta em curso antes do descarte', () {
      expect(rota.proxima!.id, 'par-1');
      expect(rota.coletasRestantes, 1);
    });

    test('polyline inválida não derruba a leitura', () {
      final s = _snapshot();
      (s['rota'] as Map)['polyline'] = '_';
      expect(RotaAtiva.deSnapshot(s).trajeto, isEmpty);
    });
  });

  group('ResultadoParada.deJson', () {
    test('ok, pin_incorreto e pin_bloqueado', () {
      expect(ResultadoParada.deJson({'resultado': 'ok'}).ok, isTrue);
      final e = ResultadoParada.deJson({
        'resultado': 'pin_incorreto',
        'tentativas_restantes': 2,
      });
      expect(e.tipo, TipoResultadoParada.pinIncorreto);
      expect(e.tentativasRestantes, 2);
      final b = ResultadoParada.deJson({
        'resultado': 'pin_bloqueado',
        'bloqueio_ate': '2026-01-01T12:02:00Z',
      });
      expect(b.tipo, TipoResultadoParada.pinBloqueado);
      expect(b.bloqueioAte, DateTime.utc(2026, 1, 1, 12, 2));
    });

    test('resposta desconhecida é erro de formato', () {
      expect(
        () => ResultadoParada.deJson({'resultado': '???'}),
        throwsFormatException,
      );
    });
  });

  group('RotaRepositorioImpl', () {
    late _RemotoFake remoto;
    late RotaRepositorioImpl repo;

    setUp(() {
      remoto = _RemotoFake()..snapshot = _snapshot();
      repo = RotaRepositorioImpl(remoto);
    });

    test('carregar converte o retrato; rota inexistente vira null', () async {
      expect((await repo.carregar('rota-1'))!.id, 'rota-1');
      remoto.snapshot = null;
      expect(await repo.carregar('rota-1'), isNull);
    });

    test('ações enviam os parâmetros certos', () async {
      await repo.iniciar('rota-1');
      await repo.trocarPonto('rota-1', 'pt-2');
      await repo.atualizarLocalizacao(-23.5, -46.6, 'rota-1');
      final r = await repo.avancarParada(
        'par-1',
        AcaoParada.concluir,
        pin: '4821',
      );
      expect(r.ok, isTrue);
      await repo.avancarParada(
        'par-1',
        AcaoParada.pular,
        motivo: 'Gerador ausente',
      );
      expect(remoto.chamadas, [
        'iniciar',
        'trocar:pt-2',
        'pos:-23.5,-46.6,rota-1',
        'avancar:par-1:concluir:4821:null',
        'avancar:par-1:pular:null:Gerador ausente',
      ]);
    });

    test('PIN errado e bloqueado voltam como resultado, não exceção', () async {
      remoto.respostaAvancar = {
        'resultado': 'pin_incorreto',
        'tentativas_restantes': 1,
      };
      final r = await repo.avancarParada(
        'par-1',
        AcaoParada.concluir,
        pin: '0000',
      );
      expect(r.tipo, TipoResultadoParada.pinIncorreto);
      expect(r.tentativasRestantes, 1);
    });

    test('erros inesperados viram FalhaCatador genérica', () async {
      remoto.erro = StateError('boom');
      await expectLater(
        repo.carregar('rota-1'),
        throwsA(
          isA<FalhaCatador>().having(
            (f) => f.motivo,
            'motivo',
            MotivoFalhaCatador.generico,
          ),
        ),
      );
    });

    test('FalhaCatador do remoto passa intacta', () async {
      remoto.erro = const FalhaCatador(MotivoFalhaCatador.paradaInvalida);
      await expectLater(
        repo.avancarParada('par-1', AcaoParada.cheguei),
        throwsA(
          isA<FalhaCatador>().having(
            (f) => f.motivo,
            'motivo',
            MotivoFalhaCatador.paradaInvalida,
          ),
        ),
      );
    });

    test(
      'observar emite agora e a cada mudança, coalescendo rajadas',
      () async {
        final recebidos = <RotaAtiva?>[];
        final sub = repo.observar('rota-1').listen(recebidos.add);
        await Future<void>.delayed(Duration.zero);
        expect(recebidos.length, 1);
        remoto.mud.add(null);
        remoto.mud.add(null);
        remoto.mud.add(null);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(remoto.buscas, 2); // 1 inicial + 1 (3 eventos coalescidos)
        await sub.cancel();
        expect(remoto.mud.hasListener, isFalse);
      },
    );

    test('observar repassa falhas como erro do stream', () async {
      remoto.erro = const FalhaCatador(MotivoFalhaCatador.generico);
      await expectLater(
        repo.observar('rota-1'),
        emitsError(isA<FalhaCatador>()),
      );
    });
  });

  group('MotivoFalhaCatador.deCodigo (rota)', () {
    test('códigos das RPCs de rota', () {
      expect(
        MotivoFalhaCatador.deCodigo('parada_invalida'),
        MotivoFalhaCatador.paradaInvalida,
      );
      expect(
        MotivoFalhaCatador.deCodigo('coletas_pendentes'),
        MotivoFalhaCatador.coletasPendentes,
      );
      expect(
        MotivoFalhaCatador.deCodigo('rota_invalida'),
        MotivoFalhaCatador.rotaInvalida,
      );
      expect(
        MotivoFalhaCatador.deCodigo('ponto_inexistente'),
        MotivoFalhaCatador.pontoInexistente,
      );
    });
  });
}
