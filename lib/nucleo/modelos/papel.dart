/// Papel do usuário em `perfis.papel`.
enum Papel {
  gerador,
  catador,
  ponto,
  admin;

  /// Converte o valor vindo do banco (ex.: `'gerador'`).
  static Papel deTexto(String valor) => Papel.values.firstWhere(
    (p) => p.name == valor,
    orElse: () => throw ArgumentError.value(valor, 'papel', 'Papel inválido'),
  );

  /// Valor gravado no banco.
  String paraTexto() => name;

  /// Rota inicial do papel.
  String get rotaInicial => '/$name';

  String get rotulo => switch (this) {
    Papel.gerador => 'Gerador',
    Papel.catador => 'Catador',
    Papel.ponto => 'Ponto de coleta',
    Papel.admin => 'Administrador',
  };
}
