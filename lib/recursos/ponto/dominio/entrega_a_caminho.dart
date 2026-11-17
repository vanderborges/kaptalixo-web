/// Entrega de um catador a caminho do ponto (UC11). Só o necessário: sem
/// endereço de geradores.
class EntregaACaminho {
  const EntregaACaminho({
    required this.rotaId,
    required this.catadorNome,
    required this.sacos,
    this.eta,
    this.chegou = false,
  });

  /// Linha da visão `v_entrega_a_caminho` (ver pedido P-023).
  factory EntregaACaminho.fromJson(Map<String, dynamic> j) => EntregaACaminho(
    rotaId: j['rota_id'] as String,
    catadorNome: (j['catador_nome'] as String?) ?? 'Catador',
    sacos: (j['qtd_sacos'] as num?)?.toInt() ?? 0,
    eta: j['eta'] == null ? null : DateTime.parse(j['eta'] as String),
    chegou: j['chegou'] == true,
  );

  final String rotaId;
  final String catadorNome;
  final int sacos;

  /// Chegada prevista (parada de descarte); nulo se ainda não calculada.
  final DateTime? eta;

  /// Catador já está no ponto.
  final bool chegou;

  /// Minutos até a chegada (>= 0), ou nulo sem ETA.
  int? minutosAte(DateTime agora) {
    final e = eta;
    if (e == null) return null;
    final d = e.difference(agora).inSeconds;
    return d <= 0 ? 0 : (d / 60).ceil();
  }
}
