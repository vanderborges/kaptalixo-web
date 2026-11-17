/// Motivo estável da falha (códigos levantados pelas RPCs do ponto).
enum MotivoFalhaPonto {
  semPermissao,
  rotaInexistente,
  rotaInvalida,
  coletasPendentes,
  semColetas,
  generico;

  static MotivoFalhaPonto deCodigo(String? texto) {
    final t = texto ?? '';
    if (t.contains('sem_permissao')) return semPermissao;
    if (t.contains('rota_inexistente')) return rotaInexistente;
    if (t.contains('rota_invalida')) return rotaInvalida;
    if (t.contains('coletas_pendentes')) return coletasPendentes;
    if (t.contains('sem_coletas')) return semColetas;
    return generico;
  }
}

/// Falha em operações do painel do ponto.
class FalhaPonto implements Exception {
  const FalhaPonto(this.motivo, [this.mensagem]);

  final MotivoFalhaPonto motivo;
  final String? mensagem;

  /// Texto curto para a UI.
  String get texto =>
      mensagem ??
      switch (motivo) {
        MotivoFalhaPonto.semPermissao => 'Sem permissão para esta ação.',
        MotivoFalhaPonto.rotaInexistente => 'Entrega não encontrada.',
        MotivoFalhaPonto.rotaInvalida => 'Esta entrega não está em andamento.',
        MotivoFalhaPonto.coletasPendentes =>
          'O catador ainda tem coletas pendentes.',
        MotivoFalhaPonto.semColetas => 'Esta entrega não tem coletas.',
        MotivoFalhaPonto.generico => 'Algo deu errado. Tente de novo.',
      };

  @override
  String toString() => 'FalhaPonto: ${motivo.name}';
}
