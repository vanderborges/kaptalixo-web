import 'package:latlong2/latlong.dart';

import '../../../nucleo/mapas/polyline.dart';

/// Tipo de ator exibido no mapa da demonstração.
enum TipoAtorDemo {
  gerador,
  catador,
  ponto;

  static TipoAtorDemo deTexto(String valor) => TipoAtorDemo.values.firstWhere(
    (t) => t.name == valor,
    orElse: () => throw FormatException('Tipo de ator inválido: $valor'),
  );

  String get rotulo => switch (this) {
    TipoAtorDemo.gerador => 'Gerador',
    TipoAtorDemo.catador => 'Catador',
    TipoAtorDemo.ponto => 'Ponto de coleta',
  };
}

/// Gerador, catador ou ponto com posição (visão do admin).
class AtorDemo {
  const AtorDemo({
    required this.id,
    required this.tipo,
    required this.nome,
    required this.posicao,
    this.situacao,
  });

  factory AtorDemo.fromJson(Map<String, dynamic> json) => AtorDemo(
    id: json['id'] as String,
    tipo: TipoAtorDemo.deTexto(json['tipo'] as String),
    nome: (json['nome'] as String?) ?? 'Sem nome',
    posicao: LatLng(
      (json['lat'] as num).toDouble(),
      (json['lng'] as num).toDouble(),
    ),
    situacao: json['situacao'] as String?,
  );

  final String id;
  final TipoAtorDemo tipo;
  final String nome;
  final LatLng posicao;

  /// Situação do catador (`disponivel`, `em_rota`, `offline`).
  final String? situacao;

  Map<String, dynamic> toJson() => {
    'id': id,
    'tipo': tipo.name,
    'nome': nome,
    'lat': posicao.latitude,
    'lng': posicao.longitude,
    if (situacao != null) 'situacao': situacao,
  };

  @override
  bool operator ==(Object other) =>
      other is AtorDemo &&
      other.id == id &&
      other.tipo == tipo &&
      other.nome == nome &&
      other.posicao == posicao &&
      other.situacao == situacao;

  @override
  int get hashCode => Object.hash(id, tipo, nome, posicao, situacao);
}

/// Rota aberta de um catador, com o traçado a desenhar no mapa.
class RotaDemo {
  const RotaDemo({
    required this.id,
    required this.catadorId,
    required this.status,
    required this.pontos,
  });

  /// Aceita `polyline` codificada (preferida) ou a lista `paradas` em ordem.
  factory RotaDemo.fromJson(Map<String, dynamic> json) {
    final codificada = json['polyline'] as String?;
    var pontos = <LatLng>[];
    if (codificada != null && codificada.isNotEmpty) {
      try {
        pontos = decodificarPolyline(codificada);
      } on FormatException {
        pontos = [];
      }
    }
    if (pontos.isEmpty) {
      pontos = [
        for (final p in (json['paradas'] as List<dynamic>? ?? const []))
          LatLng(
            ((p as Map<String, dynamic>)['lat'] as num).toDouble(),
            (p['lng'] as num).toDouble(),
          ),
      ];
    }
    return RotaDemo(
      id: json['id'] as String,
      catadorId: json['catador_id'] as String,
      status: (json['status'] as String?) ?? 'planejada',
      pontos: pontos,
    );
  }

  final String id;
  final String catadorId;
  final String status;
  final List<LatLng> pontos;
}

/// Linha do feed (`eventos_solicitacao`).
class EventoDemo {
  const EventoDemo({
    required this.id,
    required this.solicitacaoId,
    required this.paraStatus,
    required this.criadoEm,
    this.deStatus,
  });

  factory EventoDemo.fromJson(Map<String, dynamic> json) => EventoDemo(
    id: (json['id'] as num).toInt(),
    solicitacaoId: json['solicitacao_id'] as String,
    deStatus: json['de_status'] as String?,
    paraStatus: json['para_status'] as String,
    criadoEm: DateTime.parse(json['criado_em'] as String),
  );

  final int id;
  final String solicitacaoId;
  final String? deStatus;
  final String paraStatus;
  final DateTime criadoEm;

  static const _rotulos = {
    'buscando': 'buscando catador',
    'sem_catador': 'sem catador disponível',
    'aceita': 'aceita',
    'a_caminho': 'catador a caminho',
    'no_local': 'catador no local',
    'coletada': 'coletada',
    'entregue': 'entregue no ponto',
    'cancelada': 'cancelada',
  };

  String get descricao {
    final curto = solicitacaoId.length > 6
        ? solicitacaoId.substring(0, 6)
        : solicitacaoId;
    final para = _rotulos[paraStatus] ?? paraStatus;
    return deStatus == null
        ? 'Pedido $curto criado: $para'
        : 'Pedido $curto: ${_rotulos[deStatus] ?? deStatus} → $para';
  }
}

/// Foto do estado do sistema para o painel.
class SnapshotDemo {
  const SnapshotDemo({
    this.atores = const [],
    this.rotas = const [],
    this.eventos = const [],
  });

  factory SnapshotDemo.fromJson(Map<String, dynamic> json) => SnapshotDemo(
    atores: [
      for (final a in (json['atores'] as List<dynamic>? ?? const []))
        AtorDemo.fromJson(a as Map<String, dynamic>),
    ],
    rotas: [
      for (final r in (json['rotas'] as List<dynamic>? ?? const []))
        RotaDemo.fromJson(r as Map<String, dynamic>),
    ],
    // Mais recentes primeiro.
    eventos: [
      for (final e in (json['eventos'] as List<dynamic>? ?? const []))
        EventoDemo.fromJson(e as Map<String, dynamic>),
    ]..sort((a, b) => b.criadoEm.compareTo(a.criadoEm)),
  );

  final List<AtorDemo> atores;
  final List<RotaDemo> rotas;
  final List<EventoDemo> eventos;

  Iterable<AtorDemo> porTipo(TipoAtorDemo tipo) =>
      atores.where((a) => a.tipo == tipo);

  RotaDemo? rotaDe(String catadorId) {
    for (final r in rotas) {
      if (r.catadorId == catadorId) return r;
    }
    return null;
  }
}
