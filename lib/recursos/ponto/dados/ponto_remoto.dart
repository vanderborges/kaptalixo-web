/// Acesso bruto do painel do ponto (views, Realtime e RPC).
abstract class PontoRemoto {
  /// Linhas de `v_entrega_a_caminho` (ver P-023): `rota_id`, `catador_nome`,
  /// `qtd_sacos`, `eta`, `chegou`.
  Future<List<Map<String, dynamic>>> entregasACaminho();

  /// Avisa quando rotas/paradas/entregas do ponto mudam (Realtime).
  Stream<void> mudancas();

  /// RPC `confirmar_entrega(p_rota)`; devolve o `entrega_id` (uuid).
  Future<String> confirmarEntrega(String rotaId);
}
