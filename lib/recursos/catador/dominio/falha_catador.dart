/// Motivo estável da falha (códigos levantados pelas RPCs).
enum MotivoFalhaCatador {
  cadastroNaoAprovado,
  emRota,
  indisponivel,
  semPermissao,
  ofertaIndisponivel,
  ofertaExpirada,
  semCapacidade,
  generico;

  static MotivoFalhaCatador deCodigo(String? texto) {
    final t = texto ?? '';
    if (t.contains('cadastro_nao_aprovado')) return cadastroNaoAprovado;
    if (t.contains('catador_em_rota')) return emRota;
    if (t.contains('catador_indisponivel')) return indisponivel;
    if (t.contains('oferta_indisponivel') || t.contains('oferta_inexistente')) {
      return ofertaIndisponivel;
    }
    if (t.contains('oferta_expirada')) return ofertaExpirada;
    if (t.contains('sem_capacidade')) return semCapacidade;
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
        MotivoFalhaCatador.ofertaIndisponivel =>
          'Oferta indisponível: outro catador foi mais rápido.',
        MotivoFalhaCatador.ofertaExpirada => 'Oferta expirada.',
        MotivoFalhaCatador.semCapacidade =>
          'Sem espaço para esses sacos na sua carga.',
        MotivoFalhaCatador.generico => 'Algo deu errado. Tente de novo.',
      };

  @override
  String toString() => 'FalhaCatador: ${motivo.name}';
}
