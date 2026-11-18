import 'package:latlong2/latlong.dart';

/// Situação da solicitação (enum `status_solicitacao`).
enum StatusColeta {
  buscando('buscando'),
  aceita('aceita'),
  aCaminho('a_caminho'),
  noLocal('no_local'),
  coletada('coletada'),
  entregue('entregue'),
  cancelada('cancelada'),
  semCatador('sem_catador');

  const StatusColeta(this.codigo);

  final String codigo;

  static StatusColeta doCodigo(String codigo) => StatusColeta.values.firstWhere(
    (s) => s.codigo == codigo,
    orElse: () => throw FormatException('Status desconhecido: $codigo'),
  );

  /// Há um catador atendendo (mapa, PIN e dados do catador visíveis).
  bool get comCatador => this == aceita || this == aCaminho || this == noLocal;

  /// Ativa (T1.8): bloqueia novo pedido. `coletada` não conta.
  bool get ativa => this == buscando || comCatador;

  /// Coleta feita (leva à avaliação, UC13).
  bool get concluida => this == coletada || this == entregue;

  /// Pode ser cancelada pelo gerador (UC12: enquanto não `coletada`).
  bool get cancelavel => this == buscando || comCatador;
}

/// Catador que atende a coleta, só com o que o gerador pode ver.
class CatadorAtendimento {
  const CatadorAtendimento({
    required this.nome,
    this.avatarUrl,
    this.tipoVeiculo,
    this.avaliacaoMedia,
    this.posicao,
  });

  final String nome;
  final String? avatarUrl;
  final String? tipoVeiculo;
  final double? avaliacaoMedia;

  /// Última posição conhecida (nula se ainda não informada).
  final LatLng? posicao;

  /// Veículo em linguagem simples ("Bicicleta").
  String? get veiculoRotulo {
    final v = tipoVeiculo?.trim();
    if (v == null || v.isEmpty) return null;
    return v[0].toUpperCase() + v.substring(1);
  }

  CatadorAtendimento comPosicao(LatLng? nova) => CatadorAtendimento(
    nome: nome,
    avatarUrl: avatarUrl,
    tipoVeiculo: tipoVeiculo,
    avaliacaoMedia: avaliacaoMedia,
    posicao: nova,
  );
}

/// Retrato da solicitação do gerador (visão `v_solicitacao_gerador`).
class AcompanhamentoColeta {
  const AcompanhamentoColeta({
    required this.id,
    required this.status,
    required this.enderecoTexto,
    required this.local,
    required this.qtdSacos,
    this.pin,
    this.tentativasOferta = 0,
    this.motivoCancelamento,
    this.catador,
    this.atualizadoEm,
  });

  final String id;
  final StatusColeta status;
  final String enderecoTexto;
  final LatLng local;
  final int qtdSacos;

  /// PIN de coleta: só o gerador dono vê (RN08). Nunca logar/compartilhar.
  final String? pin;
  final int tentativasOferta;
  final String? motivoCancelamento;
  final CatadorAtendimento? catador;
  final DateTime? atualizadoEm;

  /// Lê uma linha de `v_solicitacao_gerador`. [posicao] é a linha de
  /// `posicoes_atendimento` (mais recente que a da visão), se houver.
  factory AcompanhamentoColeta.deLinha(
    Map<String, dynamic> m, {
    Map<String, dynamic>? posicao,
  }) {
    double? numero(Object? v) => v == null ? null : double.tryParse('$v');
    LatLng? ponto(double? lat, double? lng) =>
        lat == null || lng == null ? null : LatLng(lat, lng);

    final status = StatusColeta.doCodigo(m['status'] as String);
    final nome = m['catador_nome'] as String?;
    CatadorAtendimento? catador;
    if ((status.comCatador || status.concluida) && nome != null) {
      final daPosicao = posicao == null
          ? null
          : ponto(numero(posicao['lat']), numero(posicao['lng']));
      catador = CatadorAtendimento(
        nome: nome,
        avatarUrl: m['catador_avatar_url'] as String?,
        tipoVeiculo: m['catador_tipo_veiculo'] as String?,
        avaliacaoMedia: numero(m['catador_avaliacao_media']),
        posicao:
            daPosicao ??
            ponto(numero(m['catador_lat']), numero(m['catador_lng'])),
      );
    }
    return AcompanhamentoColeta(
      id: m['id'] as String,
      status: status,
      enderecoTexto: (m['endereco_texto'] as String?) ?? '',
      local: LatLng(numero(m['lat']) ?? 0, numero(m['lng']) ?? 0),
      qtdSacos: (m['qtd_sacos'] as num?)?.toInt() ?? 1,
      pin: m['pin_coleta'] as String?,
      tentativasOferta: (m['tentativas_oferta'] as num?)?.toInt() ?? 0,
      motivoCancelamento: m['motivo_cancelamento'] as String?,
      catador: catador,
      atualizadoEm: DateTime.tryParse('${m['atualizado_em']}'),
    );
  }
}
