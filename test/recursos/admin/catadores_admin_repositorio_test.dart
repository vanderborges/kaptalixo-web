import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/nucleo/modelos/catador_cadastro.dart';
import 'package:kaptalixo/nucleo/modelos/papel.dart';
import 'package:kaptalixo/nucleo/modelos/sessao.dart';
import 'package:kaptalixo/nucleo/modelos/status_cadastro.dart';
import 'package:kaptalixo/nucleo/modelos/tipo_catador.dart';
import 'package:kaptalixo/recursos/admin/dados/catadores_admin_remoto.dart';
import 'package:kaptalixo/recursos/admin/dados/catadores_admin_repositorio_fake.dart';
import 'package:kaptalixo/recursos/admin/dados/catadores_admin_repositorio_impl.dart';
import 'package:kaptalixo/recursos/admin/dominio/falha_admin.dart';

class RemotoAdminFake implements CatadoresAdminRemoto {
  final linhas = <String, Map<String, dynamic>>{
    'c1': {
      'perfil_id': 'c1',
      'tipo': 'pessoa',
      'documento': '123',
      'razao_social': null,
      'status_cadastro': 'pendente',
      'tipo_veiculo': 'carrinho',
      'capacidade_sacos': 8,
      'perfis': {'nome': 'Maria', 'telefone': '119'},
    },
    'c2': {
      'perfil_id': 'c2',
      'tipo': 'empresa',
      'status_cadastro': 'aprovado',
      'perfis': {'nome': 'Recicla', 'telefone': null},
    },
  };

  /// Imita a RLS: só admin atualiza; senão nenhuma linha é afetada.
  bool admin = true;

  @override
  Future<List<Map<String, dynamic>>> listar(String status) async =>
      linhas.values.where((l) => l['status_cadastro'] == status).toList();

  @override
  Future<Map<String, dynamic>?> buscar(String id) async => linhas[id];

  @override
  Future<Map<String, dynamic>?> atualizarStatus(
    String id,
    String status,
  ) async {
    if (!admin || !linhas.containsKey(id)) return null;
    return linhas[id] = {...linhas[id]!, 'status_cadastro': status};
  }
}

void main() {
  group('CatadorCadastro', () {
    test('fromJson/toJson fazem ida e volta', () {
      final json = RemotoAdminFake().linhas['c1']!;
      final c = CatadorCadastro.fromJson(json);
      expect(c.nome, 'Maria');
      expect(c.tipo, TipoCatador.pessoa);
      expect(c.statusCadastro, StatusCadastro.pendente);
      expect(CatadorCadastro.fromJson(c.toJson()), c);
    });
  });

  group('CatadoresAdminRepositorioImpl', () {
    late RemotoAdminFake remoto;
    late CatadoresAdminRepositorioImpl repo;

    setUp(() {
      remoto = RemotoAdminFake();
      repo = CatadoresAdminRepositorioImpl(remoto);
    });

    test('lista só os do status pedido', () async {
      final pendentes = await repo.listar(StatusCadastro.pendente);
      expect(pendentes.map((c) => c.id), ['c1']);
      expect(await repo.listar(StatusCadastro.suspenso), isEmpty);
    });

    test('aprovar muda status_cadastro', () async {
      final c = await repo.alterarStatus('c1', StatusCadastro.aprovado);
      expect(c.statusCadastro, StatusCadastro.aprovado);
      expect(remoto.linhas['c1']!['status_cadastro'], 'aprovado');
    });

    test('suspender muda status_cadastro', () async {
      await repo.alterarStatus('c2', StatusCadastro.suspenso);
      expect(remoto.linhas['c2']!['status_cadastro'], 'suspenso');
    });

    test('não-admin (RLS sem linhas) recebe semPermissao', () async {
      remoto.admin = false;
      await expectLater(
        repo.alterarStatus('c1', StatusCadastro.aprovado),
        throwsA(
          isA<FalhaAdmin>().having(
            (f) => f.codigo,
            'codigo',
            CodigoFalhaAdmin.semPermissao,
          ),
        ),
      );
      expect(remoto.linhas['c1']!['status_cadastro'], 'pendente');
    });

    test('buscar inexistente lança naoEncontrado', () async {
      await expectLater(
        repo.buscar('x'),
        throwsA(
          isA<FalhaAdmin>().having(
            (f) => f.codigo,
            'codigo',
            CodigoFalhaAdmin.naoEncontrado,
          ),
        ),
      );
    });
  });

  group('CatadoresAdminRepositorioFake', () {
    test('aprova e registra a alteração', () async {
      final repo = CatadoresAdminRepositorioFake();
      await repo.alterarStatus('c-pendente-1', StatusCadastro.aprovado);
      expect(repo.alteracoes, [('c-pendente-1', StatusCadastro.aprovado)]);
      expect(await repo.listar(StatusCadastro.pendente), hasLength(1));
    });
  });

  group('RN10 - Sessao.podeFicarDisponivel', () {
    Sessao s(Papel p, [StatusCadastro? st]) =>
        Sessao(usuarioId: 'u', papel: p, statusCadastro: st);

    test('só catador aprovado pode ficar disponível', () {
      expect(
        s(Papel.catador, StatusCadastro.aprovado).podeFicarDisponivel,
        true,
      );
      expect(
        s(Papel.catador, StatusCadastro.pendente).podeFicarDisponivel,
        false,
      );
      expect(
        s(Papel.catador, StatusCadastro.suspenso).podeFicarDisponivel,
        false,
      );
      expect(s(Papel.catador).podeFicarDisponivel, false);
      expect(s(Papel.gerador).podeFicarDisponivel, false);
    });
  });

  group('FalhaAdmin.dePostgres', () {
    test('42501 e P0001 viram semPermissao', () {
      expect(
        FalhaAdmin.dePostgres('42501').codigo,
        CodigoFalhaAdmin.semPermissao,
      );
      expect(
        FalhaAdmin.dePostgres('P0001').codigo,
        CodigoFalhaAdmin.semPermissao,
      );
      expect(
        FalhaAdmin.dePostgres('XX000').codigo,
        CodigoFalhaAdmin.desconhecida,
      );
      expect(FalhaAdmin.dePostgres(null).codigo, CodigoFalhaAdmin.desconhecida);
    });
  });

  test('lista ordenada por nome (sem diferenciar maiúsculas)', () async {
    final remoto = RemotoAdminFake();
    remoto.linhas['c3'] = {
      'perfil_id': 'c3',
      'tipo': 'pessoa',
      'status_cadastro': 'pendente',
      'perfis': {'nome': 'ana'},
    };
    final r = await CatadoresAdminRepositorioImpl(
      remoto,
    ).listar(StatusCadastro.pendente);
    expect(r.map((c) => c.nome), ['ana', 'Maria']);
  });
}
