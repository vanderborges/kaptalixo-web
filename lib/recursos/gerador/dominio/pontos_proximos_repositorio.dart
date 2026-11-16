import 'package:latlong2/latlong.dart';

import 'ponto_proximo.dart';

abstract interface class PontosProximosRepositorio {
  /// Pontos de coleta ativos ao redor de [centro], do mais perto ao mais longe.
  /// Lança `FalhaGerador`.
  Future<List<PontoProximo>> proximos(LatLng centro, {double raioMetros});
}
