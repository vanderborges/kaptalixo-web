/// Acesso bruto às visões/tabelas/RPC do acompanhamento (UC09).
abstract class AcompanhamentoRemoto {
  /// Linha de `v_solicitacao_gerador` (ou nulo se não existir).
  Future<Map<String, dynamic>?> buscarSolicitacao(String id);

  /// Linha de `posicoes_atendimento` da solicitação (ou nulo).
  Future<Map<String, dynamic>?> buscarPosicao(String id);

  /// Emite a cada mudança Realtime relevante (solicitação ou posição).
  Stream<void> mudancas(String id);

  /// Linhas de `v_solicitacao_gerador` ativas ou `coletada` (mais recentes
  /// primeiro).
  Future<List<Map<String, dynamic>>> buscarAtuais();

  /// Emite a cada mudança em qualquer solicitação do gerador (RLS filtra).
  Stream<void> mudancasAtuais();

  /// RPC `cancelar_solicitacao`.
  Future<void> cancelar(String id, String? motivo);
}
