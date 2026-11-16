/// Acesso bruto ao RPC `criar_solicitacao`.
abstract class SolicitacaoRemoto {
  /// Devolve o id (uuid) da solicitação criada.
  Future<String> criar(Map<String, dynamic> params);
}
