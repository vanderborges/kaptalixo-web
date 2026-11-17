import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/recursos/ponto/dados/ponto_remoto.dart';
import 'package:kaptalixo/recursos/ponto/dados/ponto_repositorio_impl.dart';
import 'package:kaptalixo/recursos/ponto/dominio/entrega_a_caminho.dart';
import 'package:kaptalixo/recursos/ponto/dominio/falha_ponto.dart';

void main() {
  group('EntregaACaminho', () {
    test('minutos até a chegada arredonda para cima e não fica negativo', () {
      final agora = DateTime(2026, 1, 1, 10);
      final e = EntregaACaminho(
        rotaId: 'r',
        catadorNome: 'Zé',
        sacos: 2,
        eta: agora.add(const Duration(seconds: 61)),
      );
      expect(e.minutosAte(agora), 2);
      expect(e.minutosAte(agora.add(const Duration(minutes: 5))), 0);
      expect(
        const EntregaACaminho(
          rotaId: 'r',
          catadorNome: 'Zé',
          sacos: 1,
        ).minutosAte(agora),
        isNull,
      );
    });
  });

  group('FalhaPonto', () {
    test('traduz os códigos das RPCs', () {
      expect(
        MotivoFalhaPonto.deCodigo('sem_coletas'),
        MotivoFalhaPonto.semColetas,
      );
      expect(
        MotivoFalhaPonto.deCodigo('coletas_pendentes'),
        MotivoFalhaPonto.coletasPendentes,
      );
      expect(MotivoFalhaPonto.deCodigo('xyz'), MotivoFalhaPonto.generico);
    });
  });

  group('PontoRepositorioImpl', () {
    test('confirma a entrega pela RPC e devolve o id', () async {
      final remoto = _RemotoFalso();
      final repo = PontoRepositorioImpl(remoto);
      expect(await repo.confirmarEntrega('r1'), 'e1');
      expect(remoto.confirmadas, ['r1']);
    });

    test('preserva FalhaPonto e converte erro desconhecido', () async {
      final remoto = _RemotoFalso();
      final repo = PontoRepositorioImpl(remoto);
      remoto.falha = const FalhaPonto(MotivoFalhaPonto.coletasPendentes);
      await expectLater(
        repo.confirmarEntrega('r1'),
        throwsA(
          isA<FalhaPonto>().having(
            (f) => f.motivo,
            'motivo',
            MotivoFalhaPonto.coletasPendentes,
          ),
        ),
      );
      remoto.falha = StateError('boom');
      await expectLater(
        repo.confirmarEntrega('r1'),
        throwsA(
          isA<FalhaPonto>().having(
            (f) => f.motivo,
            'motivo',
            MotivoFalhaPonto.generico,
          ),
        ),
      );
    });

    test('lista ordena por ETA (sem ETA por último)', () async {
      final repo = PontoRepositorioImpl(_RemotoFalso());
      final l = await repo.observarEntregas().first;
      expect(l.map((e) => e.rotaId), ['perto', 'longe', 'sem']);
    });
  });
}

class _RemotoFalso implements PontoRemoto {
  Object? falha;
  final List<String> confirmadas = [];

  @override
  Future<List<Map<String, dynamic>>> entregasACaminho() async => [
    {'rota_id': 'sem', 'catador_nome': 'C', 'qtd_sacos': 1},
    {
      'rota_id': 'longe',
      'catador_nome': 'B',
      'qtd_sacos': 2,
      'eta': '2026-01-01T10:30:00Z',
    },
    {
      'rota_id': 'perto',
      'catador_nome': 'A',
      'qtd_sacos': 3,
      'eta': '2026-01-01T10:05:00Z',
    },
  ];

  @override
  Stream<void> mudancas() => const Stream.empty();

  @override
  Future<String> confirmarEntrega(String rotaId) async {
    final f = falha;
    if (f != null) throw f;
    confirmadas.add(rotaId);
    return 'e1';
  }
}
