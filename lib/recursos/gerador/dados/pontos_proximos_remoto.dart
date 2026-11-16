/// Acesso bruto aos pontos próximos (RPC `pontos_proximos`, ver PEDIDOS.md).
abstract class PontosProximosRemoto {
  Future<List<Map<String, dynamic>>> proximos(
    double lat,
    double lng,
    double raioMetros,
  );
}
