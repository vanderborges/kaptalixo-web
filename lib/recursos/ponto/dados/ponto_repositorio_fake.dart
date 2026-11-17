import 'dart:async';

import '../dominio/entrega_a_caminho.dart';
import '../dominio/falha_ponto.dart';
import '../dominio/ponto_repositorio.dart';

/// Fake em memória que imita `confirmar_entrega`: a rota precisa estar na
/// lista a caminho e, ao confirmar, a entrega some da lista.
class PontoRepositorioFake implements PontoRepositorio {
  PontoRepositorioFake({List<EntregaACaminho> entregas = const []})
    : _entregas = List.of(entregas);

  final List<EntregaACaminho> _entregas;
  final _ctrl = StreamController<List<EntregaACaminho>>.broadcast();

  /// Falha lançada (uma vez) na próxima confirmação.
  FalhaPonto? proximaFalha;

  /// Rotas cuja entrega foi confirmada.
  final List<String> confirmadas = [];
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
  Future<String> confirmarEntrega(String rotaId) async {
    final falha = proximaFalha;
    if (falha != null) {
      proximaFalha = null;
      throw falha;
    }
    if (!_entregas.any((e) => e.rotaId == rotaId)) {
      throw const FalhaPonto(MotivoFalhaPonto.rotaInexistente);
    }
    confirmadas.add(rotaId);
    _entregas.removeWhere((e) => e.rotaId == rotaId);
    _ctrl.add(List.unmodifiable(_entregas));
    return 'entrega-$rotaId';
  }
}
