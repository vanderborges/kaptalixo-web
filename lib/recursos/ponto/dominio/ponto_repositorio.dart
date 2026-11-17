import 'entrega_a_caminho.dart';

/// Painel do ponto de coleta (UC11).
abstract class PontoRepositorio {
  /// Emite as entregas a caminho agora e a cada mudança (Realtime), da mais
  /// próxima para a mais distante. Erros como `FalhaPonto` no stream.
  Stream<List<EntregaACaminho>> observarEntregas();

  /// RPC `confirmar_entrega`: confirma a entrega da rota e devolve o id da
  /// entrega criada. Lança `FalhaPonto`.
  Future<String> confirmarEntrega(String rotaId);
}
