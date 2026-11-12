import 'package:latlong2/latlong.dart';

import 'servico_geocodificacao.dart';

class ServicoGeocodificacaoFake implements ServicoGeocodificacao {
  ServicoGeocodificacaoFake({
    this.resultados = const [],
    this.reversoPadrao,
    this.falhar = false,
  });

  final List<ResultadoGeocodificacao> resultados;
  final ResultadoGeocodificacao? reversoPadrao;
  final bool falhar;

  @override
  Future<List<ResultadoGeocodificacao>> buscar(String texto) async {
    if (falhar) throw const ExcecaoGeocodificacao('falha simulada');
    return resultados;
  }

  @override
  Future<ResultadoGeocodificacao?> reverso(double lat, double lng) async {
    if (falhar) throw const ExcecaoGeocodificacao('falha simulada');
    return reversoPadrao ??
        ResultadoGeocodificacao(
          nome: 'Ponto $lat,$lng',
          posicao: LatLng(lat, lng),
        );
  }
}
