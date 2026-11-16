import 'oferta_resumo.dart';

/// Ofertas de coleta do catador (UC05).
abstract class OfertasRepositorio {
  /// Ofertas pendentes e não vencidas; emite a lista atual e a cada mudança
  /// (Realtime). Lança `FalhaCatador` como erro do stream.
  Stream<List<OfertaResumo>> observar();

  /// RPC `aceitar_oferta`; devolve o id da rota. Lança `FalhaCatador`
  /// (`ofertaIndisponivel`, `ofertaExpirada`, `indisponivel`, `semCapacidade`).
  Future<String> aceitar(String ofertaId);

  /// RPC `recusar_oferta`. Lança `FalhaCatador`.
  Future<void> recusar(String ofertaId);

  /// RPC `expirar_ofertas` (idempotente); devolve quantas expirou.
  Future<int> expirar();
}
