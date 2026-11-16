/// Motivo estável da falha (códigos levantados pelas RPCs).
enum MotivoFalhaCatador {
  cadastroNaoAprovado,
  emRota,
  indisponivel,
  semPermissao,
  generico;

  static MotivoFalhaCatador deCodigo(String? texto) {
    final t = texto ?? '';
    if (t.contains('cadastro_nao_aprovado')) return cadastroNaoAprovado;
    if (t.contains('catador_em_rota')) return emRota;
    if (t.contains('catador_indisponivel')) return indisponivel;
    if (t.contains('sem_permissao')) return semPermissao;
    return generico;
  }
}

/// Falha em operações do catador (disponibilidade, posição).
class FalhaCatador implements Exception {
  const FalhaCatador(this.motivo, [this.mensagem]);

  final MotivoFalhaCatador motivo;
  final String? mensagem;

  /// Texto curto para a UI.
  String get texto =>
      mensagem ??
      switch (motivo) {
        MotivoFalhaCatador.cadastroNaoAprovado => 'Aguardando aprovação.',
        MotivoFalhaCatador.emRota => 'Você está em rota. Termine a rota antes.',
        MotivoFalhaCatador.indisponivel => 'Você está offline.',
        MotivoFalhaCatador.semPermissao => 'Sem permissão para esta ação.',
        MotivoFalhaCatador.generico => 'Algo deu errado. Tente de novo.',
      };

  @override
  String toString() => 'FalhaCatador: ${motivo.name}';
}
