/// Acesso bruto às RPCs da demonstração. Lança `FalhaAdmin`.
///
/// Contrato (RPCs admin; `resetar_demo` já existe, as demais estão em
/// `backlog/PEDIDOS.md`, P-024):
/// - `demo_snapshot(p_eventos int)` -> jsonb
///   `{atores:[{id,tipo,nome,lat,lng,situacao?}], rotas:[{id,catador_id,status,
///   polyline?,paradas:[{lat,lng}]}], eventos:[{id,solicitacao_id,de_status,
///   para_status,criado_em}]}`;
/// - `demo_criar_catadores(p_n int)` -> int (criados);
/// - `demo_criar_pedido()` -> uuid;
/// - `demo_mover_catador(p_catador uuid, p_lat float8, p_lng float8)`;
/// - `resetar_demo()`.
abstract class DemoRemoto {
  Future<Map<String, dynamic>> snapshot({int eventos = 50});

  Future<int> criarCatadores(int quantidade);

  Future<String> criarPedido();

  Future<void> resetar();

  Future<void> moverCatador(String catadorId, double lat, double lng);
}
