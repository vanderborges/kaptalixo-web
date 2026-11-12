/// Situação do cadastro do catador (`catadores.status_cadastro`).
enum StatusCadastro {
  pendente,
  aprovado,
  suspenso;

  static StatusCadastro deTexto(String valor) =>
      StatusCadastro.values.firstWhere(
        (s) => s.name == valor,
        orElse: () => throw ArgumentError.value(
          valor,
          'status_cadastro',
          'Status de cadastro inválido',
        ),
      );

  String paraTexto() => name;

  String get rotulo => switch (this) {
    StatusCadastro.pendente => 'Aguardando aprovação',
    StatusCadastro.aprovado => 'Aprovado',
    StatusCadastro.suspenso => 'Suspenso',
  };
}
