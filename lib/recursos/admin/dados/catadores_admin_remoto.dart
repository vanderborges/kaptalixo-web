/// Acesso bruto às tabelas `catadores`/`perfis` para o admin. Lança `FalhaAdmin`.
abstract class CatadoresAdminRemoto {
  /// Linhas de `catadores` com `perfis(nome, telefone)` filtradas por status.
  Future<List<Map<String, dynamic>>> listar(String status);

  Future<Map<String, dynamic>?> buscar(String id);

  /// Atualiza `status_cadastro`; devolve a linha atualizada ou nulo se a RLS
  /// ou o id não permitiram nenhuma alteração.
  Future<Map<String, dynamic>?> atualizarStatus(String id, String status);
}
