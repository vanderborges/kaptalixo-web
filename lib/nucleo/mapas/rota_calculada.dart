import 'package:latlong2/latlong.dart';

/// Como a rota foi calculada (coluna `origem_calculo`).
enum OrigemCalculo {
  osrm('osrm'),
  haversine('haversine');

  const OrigemCalculo(this.valor);
  final String valor;
}

class RotaCalculada {
  const RotaCalculada({
    required this.distanciaMetros,
    required this.duracaoSegundos,
    required this.geometria,
    required this.ordemParadas,
    required this.origemCalculo,
  });

  final double distanciaMetros;
  final double duracaoSegundos;
  final List<LatLng> geometria;

  /// Indices da lista `paradas` informada, na ordem de visita.
  final List<int> ordemParadas;
  final OrigemCalculo origemCalculo;
}
