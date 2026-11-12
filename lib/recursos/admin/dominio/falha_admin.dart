/// Motivos de falha nas operações do admin.
enum CodigoFalhaAdmin { naoEncontrado, semPermissao, rede, desconhecida }

/// Erro com mensagem pronta para o usuário (pt-BR).
class FalhaAdmin implements Exception {
  const FalhaAdmin(this.codigo);

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
