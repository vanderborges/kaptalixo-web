import 'package:latlong2/latlong.dart';

/// Ponto de coleta/venda mostrado no mapa do gerador (informativo).
class PontoProximo {
  const PontoProximo({
    required this.id,
    required this.nome,
    required this.posicao,
    this.distanciaMetros,
    this.aberto,
  });

  final String id;
  final String nome;
  final LatLng posicao;
  final double? distanciaMetros;

  /// Nulo quando o horário é desconhecido.
  final bool? aberto;

  /// Linha do RPC `pontos_proximos` (id, nome, lat, lng, distancia_m, aberto).
  factory PontoProximo.fromJson(Map<String, dynamic> json) => PontoProximo(
    id: json['id'] as String,
    nome: json['nome'] as String,
    posicao: LatLng(
      (json['lat'] as num).toDouble(),
      (json['lng'] as num).toDouble(),
    ),
    distanciaMetros: (json['distancia_m'] as num?)?.toDouble(),
    aberto: json['aberto'] as bool?,
  );
}
