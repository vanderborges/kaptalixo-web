import 'package:latlong2/latlong.dart';

import '../dominio/falha_gerador.dart';
import '../dominio/ponto_proximo.dart';
import '../dominio/pontos_proximos_repositorio.dart';

/// Fake: devolve [pontos] (ou lança [falha]) sem tocar a rede.
class PontosProximosRepositorioFake implements PontosProximosRepositorio {
  PontosProximosRepositorioFake({this.pontos = const [], this.falha});

  List<PontoProximo> pontos;
  FalhaGerador? falha;
  int chamadas = 0;

  @override
  Future<List<PontoProximo>> proximos(
    LatLng centro, {
    double raioMetros = 5000,
  }) async {
    chamadas++;
    if (falha != null) throw falha!;
    return pontos;
  }
}
