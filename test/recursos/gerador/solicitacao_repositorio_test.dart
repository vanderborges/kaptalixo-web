import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/recursos/gerador/dados/materiais_remoto.dart';
import 'package:kaptalixo/recursos/gerador/dados/materiais_repositorio_fake.dart';
import 'package:kaptalixo/recursos/gerador/dados/materiais_repositorio_impl.dart';
import 'package:kaptalixo/recursos/gerador/dados/solicitacao_remoto.dart';
import 'package:kaptalixo/recursos/gerador/dados/solicitacao_repositorio_fake.dart';
import 'package:kaptalixo/recursos/gerador/dados/solicitacao_repositorio_impl.dart';
import 'package:kaptalixo/recursos/gerador/dominio/dados_solicitacao.dart';
import 'package:kaptalixo/recursos/gerador/dominio/falha_gerador.dart';
import 'package:kaptalixo/recursos/gerador/dominio/falha_solicitacao.dart';
import 'package:kaptalixo/recursos/gerador/dominio/tamanho_saco.dart';
import 'package:latlong2/latlong.dart';

class _Remoto implements SolicitacaoRemoto {
  _Remoto({this.erro});
  final Object? erro;
  Map<String, dynamic>? recebido;

  @override
  Future<String> criar(Map<String, dynamic> params) async {
    recebido = params;
    if (erro != null) throw erro!;
    return 'abc';
  }
}

class _MatRemoto implements MateriaisRemoto {
  _MatRemoto({this.falha = false});
  final bool falha;
  @override
  Future<List<Map<String, dynamic>>> listar() async {
    if (falha) throw StateError('x');
    return [
      {'id': 3, 'codigo': 'pet', 'nome': 'PET', 'categoria': 'plastico'},
    ];
  }
}

DadosSolicitacao _dados({
  LatLng posicao = const LatLng(-23.5, -46.6),
  String endereco = 'Rua A, 10',
  int sacos = 2,
  String? obs,
  DateTime? agendada,
}) => DadosSolicitacao(
  posicao: posicao,
  enderecoTexto: endereco,
  qtdSacos: sacos,
  tamanho: TamanhoSaco.g,
  materiais: const [3, 1],
  observacao: obs,
  agendadaPara: agendada,
);

void main() {
  group('validacao RN01', () {
    test('dados validos passam', () => expect(_dados().validar(), isNull));
    test('sacos fora de 1..20', () {
      expect(_dados(sacos: 0).validar(), isNotNull);
      expect(_dados(sacos: 21).validar(), isNotNull);
      expect(_dados(sacos: 20).validar(), isNull);
    });
    test('coordenadas fora do intervalo', () {
      expect(_dados(posicao: const LatLng(0, 181)).validar(), isNotNull);
      expect(_dados(posicao: const LatLng(-90, 180)).validar(), isNull);
    });
    test('endereco obrigatorio', () {
      expect(_dados(endereco: '  ').validar(), isNotNull);
    });
    test('observacao longa e agendamento no passado', () {
      expect(_dados(obs: 'a' * 281).validar(), isNotNull);
      final agora = DateTime(2026, 1, 1, 12);
      expect(
        _dados(agendada: DateTime(2026, 1, 1, 11)).validar(agora: agora),
        isNotNull,
      );
      expect(
        _dados(agendada: DateTime(2026, 1, 1, 11, 58)).validar(agora: agora),
        isNull,
      );
    });
  });

  group('SolicitacaoRepositorioImpl', () {
    test('envia os parametros do RPC e devolve o id', () async {
      final remoto = _Remoto();
      final id = await SolicitacaoRepositorioImpl(
        remoto,
      ).criar(_dados(obs: '  portao azul '));
      expect(id, 'abc');
      expect(remoto.recebido, {
        'p_lat': -23.5,
        'p_lng': -46.6,
        'p_endereco_texto': 'Rua A, 10',
        'p_qtd_sacos': 2,
        'p_tamanho': 'G',
        'p_materiais': [3, 1],
        'p_observacao': 'portao azul',
        'p_foto_url': null,
        'p_agendada_para': null,
      });
    });

    test('dados invalidos nao chegam ao remoto', () async {
      final remoto = _Remoto();
      await expectLater(
        SolicitacaoRepositorioImpl(remoto).criar(_dados(sacos: 0)),
        throwsA(
          isA<FalhaSolicitacao>().having(
            (f) => f.motivo,
            'motivo',
            MotivoFalhaSolicitacao.invalida,
          ),
        ),
      );
      expect(remoto.recebido, isNull);
    });

    test(
      'solicitacao_ativa_existente vira FalhaSolicitacao.solicitacaoAtiva',
      () async {
        final repo = SolicitacaoRepositorioImpl(
          _Remoto(erro: Exception('P0001 solicitacao_ativa_existente')),
        );
        await expectLater(
          repo.criar(_dados()),
          throwsA(
            isA<FalhaSolicitacao>()
                .having(
                  (f) => f.motivo,
                  'motivo',
                  MotivoFalhaSolicitacao.solicitacaoAtiva,
                )
                .having(
                  (f) => f.mensagem,
                  'mensagem',
                  contains('em andamento'),
                ),
          ),
        );
      },
    );

    test('erro desconhecido vira falha geral', () async {
      final repo = SolicitacaoRepositorioImpl(
        _Remoto(erro: StateError('rede')),
      );
      await expectLater(
        repo.criar(_dados()),
        throwsA(
          isA<FalhaSolicitacao>().having(
            (f) => f.motivo,
            'motivo',
            MotivoFalhaSolicitacao.geral,
          ),
        ),
      );
    });
  });

  test('fake registra envios e lanca a falha configurada', () async {
    final fake = SolicitacaoRepositorioFake();
    expect(await fake.criar(_dados()), 'sol-1');
    expect(fake.enviadas, hasLength(1));
    fake.falha = const FalhaSolicitacao(MotivoFalhaSolicitacao.geral);
    await expectLater(fake.criar(_dados()), throwsA(isA<FalhaSolicitacao>()));
  });

  group('MateriaisRepositorioImpl', () {
    test('converte linhas em materiais', () async {
      final lista = await MateriaisRepositorioImpl(_MatRemoto()).listar();
      expect(lista.single.nome, 'PET');
      expect(lista.single.id, 3);
    });
    test('falha vira FalhaGerador', () async {
      await expectLater(
        MateriaisRepositorioImpl(_MatRemoto(falha: true)).listar(),
        throwsA(isA<FalhaGerador>()),
      );
    });
    test('fake devolve padrao', () async {
      expect(await MateriaisRepositorioFake().listar(), hasLength(7));
    });
  });
}
