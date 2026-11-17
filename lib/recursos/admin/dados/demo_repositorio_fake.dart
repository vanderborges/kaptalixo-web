import 'package:latlong2/latlong.dart';

import '../dominio/demo.dart';
import '../dominio/demo_repositorio.dart';
import '../dominio/falha_admin.dart';

/// Fake em memória do painel de demonstração.
///
/// Nasce com 2 geradores, 1 ponto e 2 catadores (um com rota aberta).
/// `resetar` restaura esse estado inicial.
class DemoRepositorioFake implements DemoRepositorio {
  DemoRepositorioFake({this.duracaoReset = const Duration(milliseconds: 800)}) {
    _restaurar();
  }

  /// Duração devolvida por [resetar].
  Duration duracaoReset;

  /// Quando não nulo, é lançada (uma vez) pela próxima operação.
  FalhaAdmin? proximaFalha;

  /// Posições recebidas por [moverCatador], em ordem.
  final List<(String, LatLng)> movimentos = [];

  int chamadasCarregar = 0;
  int chamadasReset = 0;

  static const gerador1 = AtorDemo(
    id: 'g-1',
    tipo: TipoAtorDemo.gerador,
    nome: 'Ana Gerador',
    posicao: LatLng(-23.5505, -46.6333),
  );
  static const gerador2 = AtorDemo(
    id: 'g-2',
    tipo: TipoAtorDemo.gerador,
    nome: 'Bruno Gerador',
    posicao: LatLng(-23.5560, -46.6400),
  );
  static const ponto1 = AtorDemo(
    id: 'p-1',
    tipo: TipoAtorDemo.ponto,
    nome: 'Ecoponto Centro',
    posicao: LatLng(-23.5600, -46.6500),
  );
  static const catador1 = AtorDemo(
    id: 'c-1',
    tipo: TipoAtorDemo.catador,
    nome: 'Carlos Catador',
    posicao: LatLng(-23.5520, -46.6350),
    situacao: 'em_rota',
  );
  static const catador2 = AtorDemo(
    id: 'c-2',
    tipo: TipoAtorDemo.catador,
    nome: 'Dora Catadora',
    posicao: LatLng(-23.5580, -46.6450),
    situacao: 'disponivel',
  );

  late List<AtorDemo> _atores;
  late List<RotaDemo> _rotas;
  late List<EventoDemo> _eventos;
  int _proximoEvento = 1;
  int _seq = 0;

  void _restaurar() {
    _atores = [gerador1, gerador2, ponto1, catador1, catador2];
    _rotas = [
      RotaDemo(
        id: 'r-1',
        catadorId: catador1.id,
        status: 'em_andamento',
        pontos: [catador1.posicao, gerador1.posicao, ponto1.posicao],
      ),
    ];
    _eventos = [];
    _proximoEvento = 1;
  }

  void _verificarFalha() {
    final f = proximaFalha;
    if (f != null) {
      proximaFalha = null;
      throw f;
    }
  }

  @override
  Future<SnapshotDemo> carregar() async {
    chamadasCarregar++;
    _verificarFalha();
    return SnapshotDemo(
      atores: List.of(_atores),
      rotas: List.of(_rotas),
      eventos: List.of(_eventos.reversed),
    );
  }

  @override
  Future<int> criarCatadores(int quantidade) async {
    _verificarFalha();
    if (quantidade < 1 || quantidade > 20) {
      throw const FalhaAdmin(CodigoFalhaAdmin.parametroInvalido);
    }
    for (var i = 0; i < quantidade; i++) {
      _seq++;
      _atores.add(
        AtorDemo(
          id: 'c-demo-$_seq',
          tipo: TipoAtorDemo.catador,
          nome: 'Catador fictício $_seq',
          posicao: LatLng(-23.55 - 0.002 * _seq, -46.63 - 0.002 * _seq),
          situacao: 'disponivel',
        ),
      );
    }
    return quantidade;
  }

  @override
  Future<String> criarPedido() async {
    _verificarFalha();
    _seq++;
    final id = 'pedido-demo-$_seq';
    _eventos.add(
      EventoDemo(
        id: _proximoEvento++,
        solicitacaoId: id,
        paraStatus: 'buscando',
        criadoEm: DateTime.now(),
      ),
    );
    return id;
  }

  @override
  Future<Duration> resetar() async {
    _verificarFalha();
    chamadasReset++;
    _restaurar();
    return duracaoReset;
  }

  @override
  Future<void> moverCatador(String catadorId, LatLng posicao) async {
    _verificarFalha();
    movimentos.add((catadorId, posicao));
    _atores = [
      for (final a in _atores)
        if (a.id == catadorId)
          AtorDemo(
            id: a.id,
            tipo: a.tipo,
            nome: a.nome,
            posicao: posicao,
            situacao: a.situacao,
          )
        else
          a,
    ];
  }
}
