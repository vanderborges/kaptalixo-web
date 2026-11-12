/// Acesso remoto bruto (Auth + tabelas). Implementado sobre o Supabase em
/// `AuthRemotoSupabase`; testes usam fakes. Falhas são lançadas como `FalhaAuth`.
abstract class AuthRemoto {
  /// Id do usuário com sessão ativa no Auth, ou nulo.
  String? get usuarioId;

  /// Emite quando a sessão do Auth termina (logout ou expiração).
  Stream<void> get aoSair;

  /// Autentica e devolve o id do usuário.
  Future<String> entrar(String email, String senha);

  /// Cria a conta no Auth (já autenticada) e devolve o id.
  Future<String> criarConta(String email, String senha);

  /// Linha de `perfis` (`papel`, ...) ou nulo.
  Future<Map<String, dynamic>?> buscarPerfil(String id);

  /// Linha de `catadores` (`status_cadastro`, ...) ou nulo.
  Future<Map<String, dynamic>?> buscarCatador(String id);

  Future<void> inserirPerfil(String id, Map<String, dynamic> perfil);

  Future<void> inserirGerador(String id);

  Future<void> inserirCatador(String id, Map<String, dynamic> catador);

  /// Cria ponto, preços e vínculo com o operador (RPC `cadastrar_ponto`).
  Future<void> cadastrarPonto(Map<String, dynamic> ponto);

  Future<void> sair();
}
