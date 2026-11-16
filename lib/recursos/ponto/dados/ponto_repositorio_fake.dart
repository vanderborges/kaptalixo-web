import 'dart:async';

import '../dominio/entrega_a_caminho.dart';
import '../dominio/falha_ponto.dart';
import '../dominio/pesagem.dart';
import '../dominio/ponto_repositorio.dart';

/// Fake em memória que imita `registrar_entrega`: valida pesos, exige preço
/// do material, calcula o valor com [calcularPesagem] e conclui a entrega
/// (some da lista a caminho).
class PontoRepositorioFake implements PontoRepositorio {
  PontoRepositorioFake({
    List<EntregaACaminho> entregas = const [],
    List<MaterialPreco> precos = const [],
  }) : _entregas = List.of(entregas),
       _precos = List.of(precos);

  final List<EntregaACaminho> _entregas;
  final List<MaterialPreco> _precos;
  final _ctrl = StreamController<List<EntregaACaminho>>.broadcast();

  /// Falha lançada (uma vez) na próxima chamada de registro.
  FalhaPonto? proximaFalha;

  /// Entregas registradas: rotaId -> itens enviados.
  final Map<String, List<ItemPesagem>> registradas = {};
  int assinaturas = 0;

  /// Publica nova lista (simula o Realtime).
  void publicar(List<EntregaACaminho> entregas) {
    _entregas
      ..clear()
      ..addAll(entregas);
    _ctrl.add(List.unmodifiable(_entregas));
  }

  @override
  Stream<List<EntregaACaminho>> observarEntregas() {
    assinaturas++;
    late final StreamController<List<EntregaACaminho>> saida;
    StreamSubscription<List<EntregaACaminho>>? sub;
    saida = StreamController<List<EntregaACaminho>>(
      onListen: () {
        saida.add(List.unmodifiable(_entregas));
        sub = _ctrl.stream.listen(saida.add);
      },
      onCancel: () => sub?.cancel(),
    );
    return saida.stream;
  }

  @override
  Future<List<MaterialPreco>> precos() async => List.unmodifiable(_precos);

  @override
  Future<ResultadoEntrega> registrarEntrega(
    String rotaId,
    List<ItemPesagem> itens,
  ) async {
    final falha = proximaFalha;
    if (falha != null) {
      proximaFalha = null;
      throw falha;
    }
    if (!_entregas.any((e) => e.rotaId == rotaId)) {
      throw const FalhaPonto(MotivoFalhaPonto.rotaInexistente);
    }
    final resumo = calcularPesagem(itens, {
      for (final p in _precos) p.materialId: p,
    });
    registradas[rotaId] = itens;
    _entregas.removeWhere((e) => e.rotaId == rotaId);
    _ctrl.add(List.unmodifiable(_entregas));
    return ResultadoEntrega(
      entregaId: 'entrega-$rotaId',
      pesoTotalCentesimos: resumo.pesoTotalCentesimos,
      valorTotalCentavos: resumo.valorTotalCentavos,
    );
  }
}
