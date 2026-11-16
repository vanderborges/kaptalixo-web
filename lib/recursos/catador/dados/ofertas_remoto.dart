/// Acesso bruto às ofertas (view, Realtime e RPCs).
abstract class OfertasRemoto {
  /// Linhas de `v_oferta_resumo` (pendentes e não vencidas do usuário).
  Future<List<Map<String, dynamic>>> buscarPendentes();

  /// Avisa quando a tabela `ofertas` do catador muda (Realtime).
  Stream<void> mudancas();

  /// RPC `aceitar_oferta(p_oferta)`; devolve o id da rota.
  Future<String> aceitar(String ofertaId);

  /// RPC `recusar_oferta(p_oferta)`.
  Future<void> recusar(String ofertaId);

  /// RPC `expirar_ofertas()`.
  Future<int> expirar();
}
