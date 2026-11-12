import '../../../nucleo/modelos/catador_cadastro.dart';
import '../../../nucleo/modelos/status_cadastro.dart';
import '../dominio/catadores_admin_repositorio.dart';
import '../dominio/falha_admin.dart';
import 'catadores_admin_remoto.dart';

class CatadoresAdminRepositorioImpl implements CatadoresAdminRepositorio {
  CatadoresAdminRepositorioImpl(this._remoto);

  final CatadoresAdminRemoto _remoto;

  @override
  Future<List<CatadorCadastro>> listar(StatusCadastro status) async {
    final linhas = await _remoto.listar(status.paraTexto());
    return linhas.map(CatadorCadastro.fromJson).toList();
  }

  @override
  Future<CatadorCadastro> buscar(String id) async {
    final linha = await _remoto.buscar(id);
    if (linha == null) {
      throw const FalhaAdmin(CodigoFalhaAdmin.naoEncontrado);
    }
    return CatadorCadastro.fromJson(linha);
  }

  @override
  Future<CatadorCadastro> alterarStatus(
    String id,
    StatusCadastro status,
  ) async {
    final linha = await _remoto.atualizarStatus(id, status.paraTexto());
    // Nenhuma linha afetada: RLS negou (não é admin) ou o id não existe.
    if (linha == null) {
      throw const FalhaAdmin(CodigoFalhaAdmin.semPermissao);
    }
    return CatadorCadastro.fromJson(linha);
  }
}
