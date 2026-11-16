import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/recursos/ponto/dados/ponto_remoto.dart';
import 'package:kaptalixo/recursos/ponto/dados/ponto_repositorio_impl.dart';
import 'package:kaptalixo/recursos/ponto/dominio/entrega_a_caminho.dart';
import 'package:kaptalixo/recursos/ponto/dominio/falha_ponto.dart';
import 'package:kaptalixo/recursos/ponto/dominio/pesagem.dart';

const _papel = MaterialPreco(materialId: 1, nome: 'Papel', precoKgCentavos: 50);
const _pet = MaterialPreco(materialId: 3, nome: 'PET', precoKgCentavos: 250);
final _precos = {1: _papel, 3: _pet};

void main() {
  group('calcularPesagem (RN11)', () {
    test('soma kg x preço por material com 2 casas', () {
      final r = calcularPesagem([
        const ItemPesagem(1, 1250), // 12,50 x 0,50 = 6,25
        const ItemPesagem(3, 333), // 3,33 x 2,50 = 8,325 -> 8,33
      ], _precos);
      expect(r.linhas.map((l) => l.valorCentavos), [625, 833]);
      expect(r.valorTotalCentavos, 1458);
      expect(r.pesoTotalCentesimos, 1583);
    });

    test('pesos repetidos do mesmo material somam antes de arredondar', () {
      // 0,01 + 0,01 = 0,02 x 2,50 = 0,05; separado daria 0,03 + 0,03 = 0,06
      final r = calcularPesagem([
        const ItemPesagem(3, 1),
        const ItemPesagem(3, 1),
      ], _precos);
      expect(r.linhas, hasLength(1));
      expect(r.valorTotalCentavos, 5);
    });

    test('meio centavo arredonda para cima como o banco', () {
      // 0,01 kg x 0,50 = 0,005 -> 0,01
      final r = calcularPesagem([const ItemPesagem(1, 1)], _precos);
      expect(r.valorTotalCentavos, 1);
    });

    test('material sem preço, peso inválido e lista vazia são rejeitados', () {
      void espera(List<ItemPesagem> i, MotivoFalhaPonto m) {
        expect(
          () => calcularPesagem(i, _precos),
          throwsA(isA<FalhaPonto>().having((f) => f.motivo, 'motivo', m)),
        );
      }

      espera([const ItemPesagem(9, 100)], MotivoFalhaPonto.materialSemPreco);
      espera([const ItemPesagem(1, 0)], MotivoFalhaPonto.parametroInvalido);
      espera([const ItemPesagem(1, -5)], MotivoFalhaPonto.parametroInvalido);
      espera([
        const ItemPesagem(1, maxPesoCentesimos + 1),
      ], MotivoFalhaPonto.parametroInvalido);
      espera(const [], MotivoFalhaPonto.parametroInvalido);
      espera(
        List.generate(21, (_) => const ItemPesagem(1, 100)),
        MotivoFalhaPonto.parametroInvalido,
      );
    });
  });

  group('parsePesoKg e formatação', () {
    test('aceita vírgula e ponto e arredonda a 2 casas', () {
      expect(parsePesoKg('12,5'), 1250);
      expect(parsePesoKg('2.25'), 225);
      expect(parsePesoKg('3'), 300);
      expect(parsePesoKg('0,005'), 1);
      expect(parsePesoKg('0,004'), 0);
    });

    test('texto inválido vira nulo', () {
      expect(parsePesoKg(''), isNull);
      expect(parsePesoKg('abc'), isNull);
      expect(parsePesoKg('-1'), isNull);
      expect(parsePesoKg('1,2,3'), isNull);
    });

    test('formata reais e kg', () {
      expect(formatarReais(123456), r'R$ 1.234,56');
      expect(formatarReais(5), r'R$ 0,05');
      expect(formatarKg(1250), '12,50 kg');
    });
  });

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

  group('PontoRepositorioImpl', () {
    test('traduz erro de RPC e converte numeric do banco', () async {
      final remoto = _RemotoFalso();
      final repo = PontoRepositorioImpl(remoto);
      final precos = await repo.precos();
      expect(precos.single.precoKgCentavos, 250);
      final r = await repo.registrarEntrega('r1', [const ItemPesagem(3, 333)]);
      expect(r.valorTotalCentavos, 833);
      expect(r.pesoTotalCentesimos, 333);
      expect(remoto.itensEnviados.single['peso_kg'], 3.33);

      remoto.falha = true;
      await expectLater(
        repo.registrarEntrega('r1', [const ItemPesagem(3, 100)]),
        throwsA(
          isA<FalhaPonto>().having(
            (f) => f.motivo,
            'motivo',
            MotivoFalhaPonto.coletasPendentes,
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
  bool falha = false;
  List<Map<String, dynamic>> itensEnviados = [];

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
  Future<List<Map<String, dynamic>>> precos() async => [
    {'material_id': 3, 'nome': 'PET', 'preco_kg': 2.5},
  ];

  @override
  Stream<void> mudancas() => const Stream.empty();

  @override
  Future<Map<String, dynamic>> registrarEntrega(
    String rotaId,
    List<Map<String, dynamic>> itens,
  ) async {
    if (falha) throw const FalhaPonto(MotivoFalhaPonto.coletasPendentes);
    itensEnviados = itens;
    return {'entrega_id': 'e1', 'peso_total_kg': 3.33, 'valor_total': '8.33'};
  }
}
