import 'package:latlong2/latlong.dart';

import '../dominio/falha_gerador.dart';
import '../dominio/ponto_proximo.dart';
import '../dominio/pontos_proximos_repositorio.dart';
import 'pontos_proximos_remoto.dart';

class PontosProximosRepositorioImpl implements PontosProximosRepositorio {
  PontosProximosRepositorioImpl(this._remoto);

  final PontosProximosRemoto _remoto;

  @override
  Future<List<PontoProximo>> proximos(
    LatLng centro, {
    double raioMetros = 5000,
  }) async {
    try {
      final linhas = await _remoto.proximos(
        centro.latitude,
        centro.longitude,
        raioMetros,
      );
      return linhas.map(PontoProximo.fromJson).toList();
    } on FalhaGerador {
      rethrow;
    } catch (_) {
      throw const FalhaGerador('Não foi possível carregar os pontos próximos.');
    }
  }
}
