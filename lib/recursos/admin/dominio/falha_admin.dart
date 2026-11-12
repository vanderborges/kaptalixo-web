/// Motivos de falha nas operações do admin.
enum CodigoFalhaAdmin { naoEncontrado, semPermissao, rede, desconhecida }

/// Erro com mensagem pronta para o usuário (pt-BR).
class FalhaAdmin implements Exception {
  const FalhaAdmin(this.codigo);

  /// Traduz o código SQLSTATE de um erro do Postgres: 42501 (privilégio/RLS) e
  /// P0001 (trigger 'status_cadastro: somente admin') viram semPermissao.
  factory FalhaAdmin.dePostgres(String? sqlState) =>
      sqlState == '42501' || sqlState == 'P0001'
      ? const FalhaAdmin(CodigoFalhaAdmin.semPermissao)
      : const FalhaAdmin(CodigoFalhaAdmin.desconhecida);

  final CodigoFalhaAdmin codigo;

  String get mensagem => switch (codigo) {
    CodigoFalhaAdmin.naoEncontrado => 'Catador não encontrado.',
    CodigoFalhaAdmin.semPermissao =>
      'Você não tem permissão para esta ação (ou o cadastro mudou).',
    CodigoFalhaAdmin.rede =>
      'Sem conexão com o servidor. Verifique a rede e tente de novo.',
    CodigoFalhaAdmin.desconhecida =>
      'Não foi possível concluir. Tente novamente.',
  };

  @override
  String toString() => 'FalhaAdmin(${codigo.name})';
}
