/// Acesso bruto do painel do ponto (views, tabelas, Realtime e RPC).
abstract class PontoRemoto {
  /// Linhas de `v_entrega_a_caminho` (ver P-023): `rota_id`, `catador_nome`,
  /// `qtd_sacos`, `eta`, `chegou`.
  Future<List<Map<String, dynamic>>> entregasACaminho();

  /// Linhas de `ponto_precos` do ponto do usuário: `material_id`, `nome`,
  /// `preco_kg` (numeric).
  Future<List<Map<String, dynamic>>> precos();

  /// Avisa quando rotas/paradas/entregas do ponto mudam (Realtime).
  Stream<void> mudancas();

  /// RPC `registrar_entrega`; devolve `entrega_id`, `peso_total_kg` e
  /// `valor_total` (lidos de `entregas`).
  Future<Map<String, dynamic>> registrarEntrega(
    String rotaId,
    List<Map<String, dynamic>> itens,
  );
}
