/// Material reciclável (tabela `materiais`).
class MaterialReciclavel {
  const MaterialReciclavel({
    required this.id,
    required this.codigo,
    required this.nome,
    this.categoria,
  });

  final int id;
  final String codigo;
  final String nome;
  final String? categoria;

  factory MaterialReciclavel.fromJson(Map<String, dynamic> json) =>
      MaterialReciclavel(
        id: (json['id'] as num).toInt(),
        codigo: json['codigo'] as String,
        nome: json['nome'] as String,
        categoria: json['categoria'] as String?,
      );
}
