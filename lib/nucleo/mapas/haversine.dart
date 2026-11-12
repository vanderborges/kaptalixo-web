import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

const double raioTerraMetros = 6371008.8;

/// Distancia em metros entre dois pontos (formula de haversine).
double distanciaHaversineMetros(LatLng a, LatLng b) {
  double rad(double g) => g * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) *
          math.cos(rad(b.latitude)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * raioTerraMetros * math.asin(math.min(1.0, math.sqrt(h)));
}

/// Ordem (indices de [pontos]) pelo vizinho mais proximo a partir de [origem].
List<int> ordemVizinhoMaisProximo(LatLng origem, List<LatLng> pontos) {
  final restantes = List<int>.generate(pontos.length, (i) => i);
  final ordem = <int>[];
  var atual = origem;
  while (restantes.isNotEmpty) {
    var melhor = restantes.first;
    var menor = double.infinity;
    for (final i in restantes) {
      final d = distanciaHaversineMetros(atual, pontos[i]);
      if (d < menor) {
        menor = d;
        melhor = i;
      }
    }
    restantes.remove(melhor);
    ordem.add(melhor);
    atual = pontos[melhor];
  }
  return ordem;
}
