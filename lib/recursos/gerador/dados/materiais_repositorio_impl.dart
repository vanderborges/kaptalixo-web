import '../dominio/falha_gerador.dart';
import '../dominio/material_reciclavel.dart';
import '../dominio/materiais_repositorio.dart';
import 'materiais_remoto.dart';

class MateriaisRepositorioImpl implements MateriaisRepositorio {
  MateriaisRepositorioImpl(this._remoto);

  final MateriaisRemoto _remoto;

  @override
  Future<List<MaterialReciclavel>> listar() async {
    try {
      final linhas = await _remoto.listar();
      return linhas.map(MaterialReciclavel.fromJson).toList();
    } catch (_) {
      throw const FalhaGerador('Não foi possível carregar os materiais.');
    }
  }
}
