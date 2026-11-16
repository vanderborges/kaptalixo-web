import 'material_reciclavel.dart';

abstract interface class MateriaisRepositorio {
  /// Materiais aceitos, em ordem de id. Lança `FalhaGerador`.
  Future<List<MaterialReciclavel>> listar();
}
