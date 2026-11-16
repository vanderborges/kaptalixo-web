import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

import '../../../nucleo/mapas/polyline.dart';

/// Status da rota (enum `status_rota`).
enum StatusRota {
  planejada,
  emAndamento,
  concluida,
  cancelada;

  static StatusRota deTexto(String? v) => switch (v) {
    'em_andamento' => emAndamento,
    'concluida' => concluida,
    'cancelada' => cancelada,
    _ => planejada,
  };

  bool get aberta => this == planejada || this == emAndamento;
}

/// Tipo da parada (enum `tipo_parada`).
enum TipoParada {
  coleta,
  descarte;

  static TipoParada deTexto(String? v) => v == 'descarte' ? descarte : coleta;
}

/// Status da parada (enum `status_parada`).
enum StatusParada {
  pendente,
  aCaminho,
  noLocal,
  concluida,
  pulada;

  static StatusParada deTexto(String? v) => switch (v) {
    'a_caminho' => aCaminho,
    'no_local' => noLocal,
    'concluida' => concluida,
    'pulada' => pulada,
    _ => pendente,
  };

  /// Parada ainda por fazer (nem concluída nem pulada).
  bool get aberta => this != concluida && this != pulada;
}

/// Lê um ponto geográfico vindo do PostgREST: GeoJSON (`{"coordinates":
/// [lng, lat]}`) ou EWKB em hexadecimal. Devolve null se não reconhecer.
LatLng? lerPontoGeografico(Object? valor) {
  try {
    if (valor is Map) {
      final c = valor['coordinates'];
      if (c is List && c.length >= 2) {
        return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
      }
      return null;
    }
    if (valor is String && valor.length >= 42 && valor.length.isEven) {
      final bytes = Uint8List(valor.length ~/ 2);
      for (var i = 0; i < bytes.length; i++) {
        bytes[i] = int.parse(valor.substring(i * 2, i * 2 + 2), radix: 16);
      }
      final dados = ByteData.sublistView(bytes);
      final endian = bytes[0] == 1 ? Endian.little : Endian.big;
      final tipo = dados.getUint32(1, endian);
      if ((tipo & 0xff) != 1) return null; // só Point
      var pos = 5;
      if (tipo & 0x20000000 != 0) pos += 4; // SRID
      final lng = dados.getFloat64(pos, endian);
      final lat = dados.getFloat64(pos + 8, endian);
      return LatLng(lat, lng);
    }
  } catch (_) {
    return null;
  }
  return null;
}

DateTime? _data(Object? v) => v is String ? DateTime.tryParse(v) : null;

double? _num(Object? v) => v is num ? v.toDouble() : null;

/// Ponto de descarte (destino final da rota).
class PontoDescarte {
  const PontoDescarte({required this.id, required this.nome, this.posicao});

  final String id;
  final String nome;
  final LatLng? posicao;
}

/// Parada da rota: coleta na casa de um gerador ou descarte em um ponto.
/// Endereço e nome do gerador só existem após o aceite; o PIN nunca vem.
class ParadaRota {
  const ParadaRota({
    required this.id,
    required this.ordem,
    required this.tipo,
    required this.status,
    this.posicao,
    this.eta,
    this.distanciaTrechoM,
    this.duracaoTrechoS,
    this.solicitacaoId,
    this.qtdSacos,
    this.enderecoTexto,
    this.geradorNome,
    this.observacao,
    this.bloqueioPinAte,
    this.pontoId,
    this.pontoNome,
  });

  final String id;
  final int ordem;
  final TipoParada tipo;
  final StatusParada status;
  final LatLng? posicao;
  final DateTime? eta;
  final int? distanciaTrechoM;
  final int? duracaoTrechoS;
  final String? solicitacaoId;
  final int? qtdSacos;
  final String? enderecoTexto;
  final String? geradorNome;
  final String? observacao;

  /// Fim do bloqueio por PIN errado (RN08), se houver.
  final DateTime? bloqueioPinAte;
  final String? pontoId;
  final String? pontoNome;

  bool get ehColeta => tipo == TipoParada.coleta;

  ParadaRota copiar({
    StatusParada? status,
    DateTime? bloqueioPinAte,
    bool limparBloqueio = false,
    String? pontoId,
    String? pontoNome,
    LatLng? posicao,
  }) => ParadaRota(
    id: id,
    ordem: ordem,
    tipo: tipo,
    status: status ?? this.status,
    posicao: posicao ?? this.posicao,
    eta: eta,
    distanciaTrechoM: distanciaTrechoM,
    duracaoTrechoS: duracaoTrechoS,
    solicitacaoId: solicitacaoId,
    qtdSacos: qtdSacos,
    enderecoTexto: enderecoTexto,
    geradorNome: geradorNome,
    observacao: observacao,
    bloqueioPinAte: limparBloqueio
        ? null
        : (bloqueioPinAte ?? this.bloqueioPinAte),
    pontoId: pontoId ?? this.pontoId,
    pontoNome: pontoNome ?? this.pontoNome,
  );

  /// Linha de `rota_paradas` + (coleta) `v_solicitacao_catador` e
  /// (descarte) `pontos_coleta`.
  factory ParadaRota.deLinhas(
    Map<String, dynamic> parada, {
    Map<String, dynamic>? solicitacao,
    Map<String, dynamic>? ponto,
  }) {
    final tipo = TipoParada.deTexto(parada['tipo'] as String?);
    LatLng? pos = lerPontoGeografico(parada['localizacao']);
    if (solicitacao != null) {
      final lat = _num(solicitacao['lat']);
      final lng = _num(solicitacao['lng']);
      if (lat != null && lng != null) pos = LatLng(lat, lng);
    }
    if (tipo == TipoParada.descarte && ponto != null) {
      pos = lerPontoGeografico(ponto['localizacao']) ?? pos;
    }
    return ParadaRota(
      id: parada['id'] as String,
      ordem: (parada['ordem'] as num).toInt(),
      tipo: tipo,
      status: StatusParada.deTexto(parada['status'] as String?),
      posicao: pos,
      eta: _data(parada['eta']),
      distanciaTrechoM: (parada['distancia_trecho_m'] as num?)?.toInt(),
      duracaoTrechoS: (parada['duracao_trecho_s'] as num?)?.toInt(),
      solicitacaoId: parada['solicitacao_id'] as String?,
      qtdSacos: (solicitacao?['qtd_sacos'] as num?)?.toInt(),
      enderecoTexto: solicitacao?['endereco_texto'] as String?,
      geradorNome: solicitacao?['gerador_nome'] as String?,
      observacao: solicitacao?['observacao'] as String?,
      bloqueioPinAte: _data(solicitacao?['bloqueio_pin_ate']),
      pontoId: parada['ponto_id'] as String?,
      pontoNome: ponto?['nome'] as String?,
    );
  }
}

/// Rota do catador com paradas (UC08). Montada por [RotaAtiva.deSnapshot].
class RotaAtiva {
  const RotaAtiva({
    required this.id,
    required this.status,
    required this.versao,
    required this.paradas,
    this.trajeto = const [],
    this.distanciaTotalM,
    this.duracaoTotalS,
    this.pontoDestinoId,
    this.alternativas = const [],
  });

  final String id;
  final StatusRota status;

  /// Incrementa quando a rota é replanejada (troca de ponto, pulo).
  final int versao;

  /// Paradas ordenadas por `ordem`.
  final List<ParadaRota> paradas;

  /// Polyline decodificada (vazia se a rota está encerrada ou sem cálculo).
  final List<LatLng> trajeto;
  final int? distanciaTotalM;
  final int? duracaoTotalS;
  final String? pontoDestinoId;

  /// Outros pontos de descarte possíveis (RN06: o catador pode trocar).
  final List<PontoDescarte> alternativas;

  List<ParadaRota> get coletas => [
    for (final p in paradas)
      if (p.ehColeta) p,
  ];

  ParadaRota? get descarte {
    for (final p in paradas) {
      if (!p.ehColeta) return p;
    }
    return null;
  }

  /// Próxima parada: coleta em curso, depois coleta pendente, por fim o
  /// descarte. Nula se não restou nada.
  ParadaRota? get proxima {
    final abertas = [
      for (final p in paradas)
        if (p.status.aberta) p,
    ];
    for (final alvo in const [
      StatusParada.noLocal,
      StatusParada.aCaminho,
      StatusParada.pendente,
    ]) {
      for (final p in abertas) {
        if (p.ehColeta && p.status == alvo) return p;
      }
    }
    for (final p in abertas) {
      if (!p.ehColeta) return p;
    }
    return null;
  }

  /// Coletas ainda por fazer (inclui a atual).
  int get coletasRestantes => coletas.where((p) => p.status.aberta).length;

  int get totalColetas => coletas.length;

  /// Posição (1-based) da coleta [p] entre as coletas não puladas.
  int numeroColeta(ParadaRota p) {
    var n = 0;
    for (final c in coletas) {
      if (c.status == StatusParada.pulada && c.id != p.id) continue;
      n++;
      if (c.id == p.id) return n;
    }
    return n;
  }

  RotaAtiva copiar({
    StatusRota? status,
    int? versao,
    List<ParadaRota>? paradas,
    String? pontoDestinoId,
    List<PontoDescarte>? alternativas,
  }) => RotaAtiva(
    id: id,
    status: status ?? this.status,
    versao: versao ?? this.versao,
    paradas: paradas ?? this.paradas,
    trajeto: trajeto,
    distanciaTotalM: distanciaTotalM,
    duracaoTotalS: duracaoTotalS,
    pontoDestinoId: pontoDestinoId ?? this.pontoDestinoId,
    alternativas: alternativas ?? this.alternativas,
  );

  /// Monta a rota de um retrato com as chaves `rota`, `paradas`,
  /// `solicitacoes` e `pontos` (linhas cruas do remoto).
  factory RotaAtiva.deSnapshot(Map<String, dynamic> snap) {
    final rota = Map<String, dynamic>.from(snap['rota'] as Map);
    List<Map<String, dynamic>> lista(String k) => [
      for (final e in (snap[k] as List? ?? const []))
        Map<String, dynamic>.from(e as Map),
    ];
    final solicitacoes = {
      for (final s in lista('solicitacoes')) s['id'] as String: s,
    };
    final pontos = {for (final p in lista('pontos')) p['id'] as String: p};

    final paradas = [
      for (final p in lista('paradas'))
        ParadaRota.deLinhas(
          p,
          solicitacao: solicitacoes[p['solicitacao_id']],
          ponto: pontos[p['ponto_id']],
        ),
    ]..sort((a, b) => a.ordem.compareTo(b.ordem));

    final destino = rota['ponto_destino_id'] as String?;
    final alternativas = <PontoDescarte>[];
    final brutas = rota['alternativas_ponto'];
    if (brutas is List) {
      for (final a in brutas) {
        if (a is! Map) continue;
        final id = a['ponto_id'] as String?;
        final p = id == null ? null : pontos[id];
        if (id == null || id == destino || p == null) continue;
        alternativas.add(
          PontoDescarte(
            id: id,
            nome: (p['nome'] as String?) ?? 'Ponto',
            posicao: lerPontoGeografico(p['localizacao']),
          ),
        );
      }
    }

    final codigo = rota['polyline'];
    var trajeto = const <LatLng>[];
    if (codigo is String && codigo.isNotEmpty) {
      try {
        trajeto = decodificarPolyline(codigo);
      } on FormatException {
        trajeto = const [];
      }
    }

    return RotaAtiva(
      id: rota['id'] as String,
      status: StatusRota.deTexto(rota['status'] as String?),
      versao: (rota['versao'] as num?)?.toInt() ?? 1,
      paradas: paradas,
      trajeto: trajeto,
      distanciaTotalM: (rota['distancia_total_m'] as num?)?.toInt(),
      duracaoTotalS: (rota['duracao_total_s'] as num?)?.toInt(),
      pontoDestinoId: destino,
      alternativas: alternativas,
    );
  }
}

/// Tipo de resposta de `avancar_parada` (o PIN errado não é exceção).
enum TipoResultadoParada { ok, pinIncorreto, pinBloqueado }

/// Resultado de `avancar_parada`.
class ResultadoParada {
  const ResultadoParada(
    this.tipo, {
    this.tentativasRestantes,
    this.bloqueioAte,
  });

  final TipoResultadoParada tipo;
  final int? tentativasRestantes;
  final DateTime? bloqueioAte;

  bool get ok => tipo == TipoResultadoParada.ok;

  /// Converte o jsonb `{"resultado": ..., ...}` da RPC.
  factory ResultadoParada.deJson(Map<String, dynamic> json) {
    switch (json['resultado']) {
      case 'ok':
        return const ResultadoParada(TipoResultadoParada.ok);
      case 'pin_incorreto':
        return ResultadoParada(
          TipoResultadoParada.pinIncorreto,
          tentativasRestantes: (json['tentativas_restantes'] as num?)?.toInt(),
        );
      case 'pin_bloqueado':
        return ResultadoParada(
          TipoResultadoParada.pinBloqueado,
          bloqueioAte: _data(json['bloqueio_ate']),
        );
    }
    throw const FormatException('Resultado de parada desconhecido');
  }
}

/// Ação de `avancar_parada`.
enum AcaoParada {
  cheguei('cheguei'),
  concluir('concluir'),
  pular('pular');

  const AcaoParada(this.codigo);
  final String codigo;
}
