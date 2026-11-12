import '../../../nucleo/modelos/catador_cadastro.dart';
import '../../../nucleo/modelos/status_cadastro.dart';

/// Gestão de cadastros de catador pelo admin (UC02). Lança `FalhaAdmin`.
abstract class CatadoresAdminRepositorio {
  /// Catadores com o [status] informado.
  Future<List<CatadorCadastro>> listar(StatusCadastro status);

  /// Cadastro de um catador.
  Future<CatadorCadastro> buscar(String id);

  /// Define `status_cadastro` (a RLS só permite ao admin) e devolve o cadastro.
  Future<CatadorCadastro> alterarStatus(String id, StatusCadastro status);
}
