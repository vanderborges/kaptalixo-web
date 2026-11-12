/// Tamanho mínimo da senha (igual a `minimum_password_length` do Supabase).
const int tamanhoMinimoSenha = 8;

/// Motivos de falha de autenticação/cadastro.
enum CodigoFalhaAuth {
  credenciaisInvalidas,
  emailJaUsado,
  senhaFraca,
  perfilNaoEncontrado,
  rede,
  desconhecida,
}

/// Erro de autenticação com mensagem pronta para o usuário (pt-BR).
class FalhaAuth implements Exception {
  const FalhaAuth(this.codigo);

  final CodigoFalhaAuth codigo;

  String get mensagem => switch (codigo) {
    CodigoFalhaAuth.credenciaisInvalidas => 'E-mail ou senha incorretos.',
    CodigoFalhaAuth.emailJaUsado =>
      'Este e-mail já está cadastrado. Entre ou use outro e-mail.',
    CodigoFalhaAuth.senhaFraca =>
      'Senha fraca. Use ao menos $tamanhoMinimoSenha caracteres.',
    CodigoFalhaAuth.perfilNaoEncontrado =>
      'Não encontramos o perfil desta conta. Fale com o suporte.',
    CodigoFalhaAuth.rede =>
      'Sem conexão com o servidor. Verifique a rede e tente de novo.',
    CodigoFalhaAuth.desconhecida =>
      'Não foi possível concluir. Tente novamente.',
  };

  @override
  String toString() => 'FalhaAuth(${codigo.name})';
}
