/// Tipo de catador (`catadores.tipo`).
enum TipoCatador {
  pessoa,
  empresa;

  static TipoCatador deTexto(String valor) => TipoCatador.values.firstWhere(
    (t) => t.name == valor,
    orElse: () => throw ArgumentError.value(valor, 'tipo', 'Tipo inválido'),
  );

  String paraTexto() => name;

  String get rotulo => switch (this) {
    TipoCatador.pessoa => 'Pessoa',
    TipoCatador.empresa => 'Empresa',
  };
}
