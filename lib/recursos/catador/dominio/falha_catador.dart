/// Motivo estável da falha (códigos levantados pelas RPCs).
enum MotivoFalhaCatador {
  cadastroNaoAprovado,
  emRota,
  indisponivel,
  semPermissao,
  ofertaIndisponivel,
  ofertaExpirada,
  semCapacidade,
  rotaInexistente,
  rotaInvalida,
  paradaInexistente,
  paradaInvalida,
  coletasPendentes,
  pontoInexistente,
  parametroInvalido,
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
    if (t.contains('rota_inexistente')) return rotaInexistente;
    if (t.contains('rota_invalida')) return rotaInvalida;
    if (t.contains('parada_inexistente')) return paradaInexistente;
    if (t.contains('parada_invalida')) return paradaInvalida;
    if (t.contains('coletas_pendentes')) return coletasPendentes;
    if (t.contains('ponto_inexistente')) return pontoInexistente;
    if (t.contains('parametro_invalido')) return parametroInvalido;
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
        MotivoFalhaCatador.rotaInexistente => 'Rota não encontrada.',
        MotivoFalhaCatador.rotaInvalida => 'Esta rota não está ativa.',
        MotivoFalhaCatador.paradaInexistente => 'Parada não encontrada.',
        MotivoFalhaCatador.paradaInvalida =>
          'Esta parada não aceita esta ação agora.',
        MotivoFalhaCatador.coletasPendentes =>
          'Ainda há coletas pendentes na rota.',
        MotivoFalhaCatador.pontoInexistente => 'Ponto não encontrado.',
        MotivoFalhaCatador.parametroInvalido => 'Dado inválido.',
        MotivoFalhaCatador.generico => 'Algo deu errado. Tente de novo.',
      };

  @override
  String toString() => 'FalhaCatador: ${motivo.name}';
}
