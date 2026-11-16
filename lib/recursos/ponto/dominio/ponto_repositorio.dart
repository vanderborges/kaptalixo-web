import 'entrega_a_caminho.dart';
import 'pesagem.dart';

/// Painel do ponto de coleta (UC11).
abstract class PontoRepositorio {
  /// Emite as entregas a caminho agora e a cada mudança (Realtime), da mais
  /// próxima para a mais distante. Erros como `FalhaPonto` no stream.
  Stream<List<EntregaACaminho>> observarEntregas();

  /// Tabela de preços vigente do ponto do usuário.
  Future<List<MaterialPreco>> precos();

  /// RPC `registrar_entrega`: pesos por material. Lança `FalhaPonto`.
  Future<ResultadoEntrega> registrarEntrega(
    String rotaId,
    List<ItemPesagem> itens,
  );
}
