import 'package:latlong2/latlong.dart';

/// Posicao geografica com instante de leitura.
class Posicao {
  const Posicao({
    required this.ponto,
    required this.instante,
    this.simulada = false,
    this.precisaoMetros,
  });

  final LatLng ponto;
  final DateTime instante;
  final bool simulada;
  final double? precisaoMetros;

  double get latitude => ponto.latitude;
  double get longitude => ponto.longitude;

  @override
  bool operator ==(Object other) =>
      other is Posicao &&
      other.ponto == ponto &&
      other.instante == instante &&
      other.simulada == simulada &&
      other.precisaoMetros == precisaoMetros;

  @override
  int get hashCode => Object.hash(ponto, instante, simulada, precisaoMetros);

  @override
  String toString() => 'Posicao($latitude, $longitude, $instante)';
}
