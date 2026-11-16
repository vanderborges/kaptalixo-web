/// Acesso bruto à rota (views, tabelas, Realtime e RPCs).
abstract class RotaRemoto {
  /// Id da rota aberta do catador (`v_rota_catador`), se houver.
  Future<String?> rotaAbertaId();

  /// Retrato com as chaves `rota` (v_rota_catador), `paradas` (rota_paradas),
  /// `solicitacoes` (v_solicitacao_catador) e `pontos` (pontos_coleta).
  /// Nulo se a rota não existe.
  Future<Map<String, dynamic>?> buscarRota(String rotaId);

  /// Avisa quando rota, paradas ou solicitações do catador mudam (Realtime).
  Stream<void> mudancas(String rotaId);

  Future<void> iniciarRota(String rotaId);

  /// Devolve o jsonb da RPC (`resultado`, ...).
  Future<Map<String, dynamic>> avancarParada(
    String paradaId,
    String acao, {
    String? pin,
    String? motivo,
  });

  Future<void> trocarPonto(String rotaId, String pontoId);

  Future<void> atualizarLocalizacao(double lat, double lng, String rotaId);
}
