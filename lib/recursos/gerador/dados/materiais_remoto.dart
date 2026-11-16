/// Acesso bruto à tabela `materiais` (leitura liberada a autenticados).
abstract class MateriaisRemoto {
  Future<List<Map<String, dynamic>>> listar();
}
