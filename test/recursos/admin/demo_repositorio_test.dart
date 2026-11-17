import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/nucleo/mapas/polyline.dart' show decodificarPolyline;
import 'package:kaptalixo/recursos/admin/dados/demo_remoto.dart';
import 'package:kaptalixo/recursos/admin/dados/demo_repositorio_fake.dart';
import 'package:kaptalixo/recursos/admin/dados/demo_repositorio_impl.dart';
import 'package:kaptalixo/recursos/admin/dominio/demo.dart';
import 'package:kaptalixo/recursos/admin/dominio/falha_admin.dart';
import 'package:latlong2/latlong.dart';

class _RemotoFalso implements DemoRemoto {
  Map<String, dynamic> json = {};
  final chamadas = <String>[];
  Duration demora = Duration.zero;
  DateTime agora = DateTime(2026, 1, 1, 12);

  @override
  Future<Map<String, dynamic>> snapshot({int eventos = 50}) async {
    chamadas.add('snapshot');
    return json;
  }

  @override
  Future<int> criarCatadores(int quantidade) async {
    chamadas.add('criarCatadores:$quantidade');
    return quantidade;
  }

  @override
  Future<String> criarPedido() async {
    chamadas.add('criarPedido');
    return 'id-1';
  }

  @override
  Future<void> resetar() async {
    chamadas.add('resetar');
    agora = agora.add(demora);
  }

  @override
  Future<void> moverCatador(String catadorId, double lat, double lng) async {
    chamadas.add('mover:$catadorId:$lat:$lng');
  }
}

void main() {
  late _RemotoFalso remoto;
  late DemoRepositorioImpl repo;

  setUp(() {
    remoto = _RemotoFalso();
    repo = DemoRepositorioImpl(remoto, relogio: () => remoto.agora);
  });

  group('carregar', () {
    test('converte atores, rotas e eventos (mais recente primeiro)', () async {
      remoto.json = {
        'atores': [
          {
            'id': 'g1',
            'tipo': 'gerador',
            'nome': 'Ana',
            'lat': -23.5,
            'lng': -46.6,
          },
          {
            'id': 'c1',
            'tipo': 'catador',
            'nome': 'Carlos',
            'lat': -23.51,
            'lng': -46.61,
            'situacao': 'em_rota',
          },
          {'id': 'p1', 'tipo': 'ponto', 'lat': -23.52, 'lng': -46.62},
        ],
        'rotas': [
          {
            'id': 'r1',
            'catador_id': 'c1',
            'status': 'em_andamento',
            'paradas': [
              {'lat': -23.5, 'lng': -46.6},
              {'lat': -23.52, 'lng': -46.62},
            ],
          },
        ],
        'eventos': [
          {
            'id': 1,
            'solicitacao_id': 'abcdef123',
            'de_status': null,
            'para_status': 'buscando',
            'criado_em': '2026-01-01T12:00:00Z',
          },
          {
            'id': 2,
            'solicitacao_id': 'abcdef123',
            'de_status': 'buscando',
            'para_status': 'aceita',
            'criado_em': '2026-01-01T12:00:05Z',
          },
        ],
      };
      final s = await repo.carregar();
      expect(s.atores, hasLength(3));
      expect(s.porTipo(TipoAtorDemo.catador).single.situacao, 'em_rota');
      expect(s.atores.last.nome, 'Sem nome');
      expect(s.rotaDe('c1')!.pontos, hasLength(2));
      expect(s.rotaDe('outro'), isNull);
      expect(s.eventos.map((e) => e.id), [2, 1]);
      expect(
        s.eventos.first.descricao,
        'Pedido abcdef: buscando catador → aceita',
      );
      expect(
        s.eventos.last.descricao,
        'Pedido abcdef criado: buscando catador',
      );
    });

    test('prefere a polyline codificada às paradas', () async {
      remoto.json = {
        'rotas': [
          {
            'id': 'r1',
            'catador_id': 'c1',
            'polyline': '_p~iF~ps|U_ulLnnqC_mqNvxq`@',
            'paradas': [
              {'lat': 1, 'lng': 1},
            ],
          },
        ],
      };
      final s = await repo.carregar();
      expect(
        s.rotas.single.pontos,
        decodificarPolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@'),
      );
      expect(s.rotas.single.status, 'planejada');
    });

    test('resposta malformada vira falha desconhecida', () async {
      remoto.json = {
        'atores': [
          {'id': 'x', 'tipo': 'alienigena', 'lat': 0, 'lng': 0},
        ],
      };
      await expectLater(
        repo.carregar(),
        throwsA(
          isA<FalhaAdmin>().having(
            (f) => f.codigo,
            'codigo',
            CodigoFalhaAdmin.desconhecida,
          ),
        ),
      );
      remoto.json = {
        'atores': [
          {'id': 1, 'tipo': 'gerador', 'lat': 0, 'lng': 0},
        ],
      };
      await expectLater(repo.carregar(), throwsA(isA<FalhaAdmin>()));
    });
  });

  group('criarCatadores', () {
    test('repassa a quantidade válida', () async {
      expect(await repo.criarCatadores(5), 5);
      expect(remoto.chamadas, ['criarCatadores:5']);
    });

    for (final n in [0, -1, 21]) {
      test('rejeita $n sem chamar o servidor', () async {
        await expectLater(
          Future.sync(() => repo.criarCatadores(n)),
          throwsA(
            isA<FalhaAdmin>().having(
              (f) => f.codigo,
              'codigo',
              CodigoFalhaAdmin.parametroInvalido,
            ),
          ),
        );
        expect(remoto.chamadas, isEmpty);
      });
    }
  });

  test('criarPedido e moverCatador repassam ao remoto', () async {
    expect(await repo.criarPedido(), 'id-1');
    await repo.moverCatador('c1', const LatLng(-23.5, -46.6));
    expect(remoto.chamadas, ['criarPedido', 'mover:c1:-23.5:-46.6']);
  });

  test('resetar devolve o tempo gasto', () async {
    remoto.demora = const Duration(milliseconds: 2300);
    expect(await repo.resetar(), const Duration(milliseconds: 2300));
    expect(remoto.chamadas, ['resetar']);
  });

  group('FalhaAdmin.deRpc', () {
    test('traduz os erros estáveis das RPCs', () {
      expect(
        FalhaAdmin.deRpc('P0001', 'modo_demo_desativado').codigo,
        CodigoFalhaAdmin.modoDemoDesativado,
      );
      expect(
        FalhaAdmin.deRpc('P0001', 'parametro_invalido').codigo,
        CodigoFalhaAdmin.parametroInvalido,
      );
      expect(
        FalhaAdmin.deRpc('P0001', 'sem_permissao').codigo,
        CodigoFalhaAdmin.semPermissao,
      );
      expect(
        FalhaAdmin.deRpc('42501', null).codigo,
        CodigoFalhaAdmin.semPermissao,
      );
      expect(
        FalhaAdmin.deRpc('XX000', 'outra').codigo,
        CodigoFalhaAdmin.desconhecida,
      );
    });

    test('todas as falhas têm mensagem em pt-BR', () {
      for (final c in CodigoFalhaAdmin.values) {
        expect(FalhaAdmin(c).mensagem, isNotEmpty);
      }
    });
  });

  group('DemoRepositorioFake', () {
    test(
      'criar catadores aparece no snapshot e reset restaura o seed',
      () async {
        final fake = DemoRepositorioFake();
        final inicial = (await fake.carregar()).atores.length;
        expect(await fake.criarCatadores(4), 4);
        expect((await fake.carregar()).atores.length, inicial + 4);
        await fake.criarPedido();
        expect((await fake.carregar()).eventos, hasLength(1));
        await fake.resetar();
        final s = await fake.carregar();
        expect(s.atores.length, inicial);
        expect(s.eventos, isEmpty);
      },
    );

    test('falha programada é lançada uma única vez', () async {
      final fake = DemoRepositorioFake()
        ..proximaFalha = const FalhaAdmin(CodigoFalhaAdmin.rede);
      await expectLater(fake.carregar(), throwsA(isA<FalhaAdmin>()));
      expect(await fake.carregar(), isA<SnapshotDemo>());
    });
  });
}
