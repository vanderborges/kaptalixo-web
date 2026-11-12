import '../../../nucleo/modelos/sessao.dart';
import '../../../nucleo/repositorios_base/sessao_repositorio.dart';
import 'dados_cadastro.dart';

/// Autenticação por e-mail/senha. Lança `FalhaAuth` em caso de erro.
abstract class AuthRepositorio implements SessaoRepositorio {
  /// Entra e devolve a sessão (papel lido de `perfis`).
  Future<Sessao> entrar({required String email, required String senha});

  /// Cria a conta, o perfil e a linha do papel, e já deixa o usuário logado.
  Future<Sessao> cadastrar(DadosCadastro dados);
}
