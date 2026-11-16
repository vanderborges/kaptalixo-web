/// Oferta pendente como o catador a vê (`v_oferta_resumo`): sem endereço
/// exato, sem PIN. Distância e ETA já vêm arredondados pelo servidor.
class OfertaResumo {
  const OfertaResumo({
    required this.ofertaId,
    required this.solicitacaoId,
    required this.distanciaM,
    required this.etaS,
    required this.qtdSacos,
    required this.expiraEm,
    required this.enviadaEm,
    this.tamanho,
    this.pesoEstimadoKg,
    this.bairro,
    this.naRota = false,
    this.ordem = 1,
    this.materiais = const [],
  });

  final String ofertaId;
  final String solicitacaoId;
  final int distanciaM;
  final int etaS;
  final int qtdSacos;
  final DateTime expiraEm;
  final DateTime enviadaEm;
  final String? tamanho;
  final double? pesoEstimadoKg;
  final String? bairro;

  /// A coleta fica no caminho da rota atual.
  final bool naRota;
  final int ordem;
  final List<int> materiais;

  /// Janela total da oferta (RN03: 45 s); base da barra de progresso.
  Duration get janela {
    final d = expiraEm.difference(enviadaEm);
    return d.inSeconds > 0 ? d : const Duration(seconds: 45);
  }

  /// Segundos que faltam (arredondado para cima, nunca negativo).
  int segundosRestantes(DateTime agora) {
    final ms = expiraEm.difference(agora).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  bool expirada(DateTime agora) => !expiraEm.isAfter(agora);

  factory OfertaResumo.deLinha(Map<String, dynamic> l) => OfertaResumo(
    ofertaId: l['oferta_id'] as String,
    solicitacaoId: l['solicitacao_id'] as String,
    distanciaM: (l['distancia_m'] as num?)?.toInt() ?? 0,
    etaS: (l['eta_s'] as num?)?.toInt() ?? 0,
    qtdSacos: (l['qtd_sacos'] as num?)?.toInt() ?? 0,
    expiraEm: DateTime.parse(l['expira_em'] as String),
    enviadaEm: DateTime.parse(l['enviada_em'] as String),
    tamanho: l['tamanho'] as String?,
    pesoEstimadoKg: (l['peso_estimado_kg'] as num?)?.toDouble(),
    bairro: l['bairro'] as String?,
    naRota: l['na_rota'] as bool? ?? false,
    ordem: (l['ordem'] as num?)?.toInt() ?? 1,
    materiais: [
      for (final m in (l['materiais'] as List?) ?? const []) (m as num).toInt(),
    ],
  );
}
