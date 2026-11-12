import 'package:latlong2/latlong.dart';

import 'rota_calculada.dart';

abstract interface class ServicoRotas {
  /// Rota origem -> paradas (ordem otimizada) -> destino.
  /// Nunca lanca por falha de rede: usa fallback haversine.
  Future<RotaCalculada> calcular(
    LatLng origem,
    List<LatLng> paradas,
    LatLng destino,
  );

  /// Duracao em segundos de [origem] ate [destino].
  Future<double> duracaoAte(LatLng origem, LatLng destino);

  /// Matriz de duracoes (segundos) entre [pontos] (OSRM `table`).
  Future<List<List<double>>> matrizDuracoes(List<LatLng> pontos);
}
