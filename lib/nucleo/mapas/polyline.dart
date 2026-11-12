import 'package:latlong2/latlong.dart';

/// Decodifica polyline do Google/OSRM. [precisao] 5 (padrao) ou 6.
List<LatLng> decodificarPolyline(String codigo, {int precisao = 5}) {
  var fator = 1.0;
  for (var k = 0; k < precisao; k++) {
    fator *= 10;
  }
  final pontos = <LatLng>[];
  var i = 0;
  var lat = 0;
  var lng = 0;

  int proximo() {
    var resultado = 0;
    var deslocamento = 0;
    int b;
    do {
      if (i >= codigo.length) {
        throw const FormatException('Polyline truncada');
      }
      b = codigo.codeUnitAt(i++) - 63;
      resultado |= (b & 0x1f) << deslocamento;
      deslocamento += 5;
    } while (b >= 0x20);
    return (resultado & 1) != 0 ? ~(resultado >> 1) : (resultado >> 1);
  }

  while (i < codigo.length) {
    lat += proximo();
    lng += proximo();
    pontos.add(LatLng(lat / fator, lng / fator));
  }
  return pontos;
}
