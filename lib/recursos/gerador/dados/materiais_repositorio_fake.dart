import '../dominio/falha_gerador.dart';
import '../dominio/material_reciclavel.dart';
import '../dominio/materiais_repositorio.dart';

/// Fake com os materiais do seed por padrão.
class MateriaisRepositorioFake implements MateriaisRepositorio {
  MateriaisRepositorioFake({this.materiais = padrao, this.falha});

  static const padrao = [
    MaterialReciclavel(id: 1, codigo: 'papel', nome: 'Papel'),
    MaterialReciclavel(id: 2, codigo: 'papelao', nome: 'Papelão'),
    MaterialReciclavel(id: 3, codigo: 'pet', nome: 'PET'),
    MaterialReciclavel(id: 4, codigo: 'plastico_duro', nome: 'Plástico duro'),
    MaterialReciclavel(id: 5, codigo: 'vidro', nome: 'Vidro'),
    MaterialReciclavel(id: 6, codigo: 'aluminio', nome: 'Alumínio'),
    MaterialReciclavel(id: 7, codigo: 'ferro', nome: 'Ferro'),
  ];

  List<MaterialReciclavel> materiais;
  FalhaGerador? falha;

  @override
  Future<List<MaterialReciclavel>> listar() async {
    if (falha != null) throw falha!;
    return materiais;
  }
}
