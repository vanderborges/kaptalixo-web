import 'package:latlong2/latlong.dart';

import 'haversine.dart';
import 'rota_calculada.dart';
import 'servico_rotas.dart';

/// Fake deterministico para testes (linha reta, [velocidadeMs] m/s).
class ServicoRotasFake implements ServicoRotas {
  ServicoRotasFake({this.velocidadeMs = 5});

  final double velocidadeMs;
  final List<String> chamadas = [];

  @override
  Future<RotaCalculada> calcular(
    LatLng origem,
    List<LatLng> paradas,
    LatLng destino,
  ) async {
    chamadas.add('calcular');
    final ordem = List<int>.generate(paradas.length, (i) => i);
    final geo = [origem, ...paradas, destino];
    var dist = 0.0;
    for (var i = 1; i < geo.length; i++) {
      dist += distanciaHaversineMetros(geo[i - 1], geo[i]);
    }
    return RotaCalculada(
      distanciaMetros: dist,
      duracaoSegundos: dist / velocidadeMs,
      geometria: geo,
      ordemParadas: ordem,
      origemCalculo: OrigemCalculo.haversine,
    );
  }

  @override
  Future<double> duracaoAte(LatLng origem, LatLng destino) async {
    chamadas.add('duracaoAte');
    return distanciaHaversineMetros(origem, destino) / velocidadeMs;
  }

  @override
  Future<List<List<double>>> matrizDuracoes(List<LatLng> pontos) async {
    chamadas.add('matrizDuracoes');
    return [
      for (final a in pontos)
        [for (final b in pontos) distanciaHaversineMetros(a, b) / velocidadeMs],
    ];
  }
}
