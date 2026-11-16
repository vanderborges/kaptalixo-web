/// Tamanho do saco (enum `tamanho_saco` do banco).
enum TamanhoSaco {
  p('P', 'Pequeno'),
  m('M', 'Médio'),
  g('G', 'Grande');

  const TamanhoSaco(this.codigo, this.rotulo);

  /// Valor enviado ao RPC (`P`, `M` ou `G`).
  final String codigo;
  final String rotulo;
}
