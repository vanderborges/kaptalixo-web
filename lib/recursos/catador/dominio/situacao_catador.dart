/// Situação operacional do catador (enum `disponibilidade` do banco).
enum SituacaoCatador {
  offline,
  disponivel,
  emRota;

  static SituacaoCatador deTexto(String valor) => switch (valor) {
    'disponivel' => SituacaoCatador.disponivel,
    'em_rota' => SituacaoCatador.emRota,
    _ => SituacaoCatador.offline,
  };
}
