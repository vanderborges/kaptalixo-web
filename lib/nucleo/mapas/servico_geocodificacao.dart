import 'package:latlong2/latlong.dart';

class ResultadoGeocodificacao {
  const ResultadoGeocodificacao({required this.nome, required this.posicao});

  final String nome;
  final LatLng posicao;
}

class ExcecaoGeocodificacao implements Exception {
  const ExcecaoGeocodificacao(this.mensagem);
  final String mensagem;
  @override
  String toString() => 'ExcecaoGeocodificacao: $mensagem';
}

abstract interface class ServicoGeocodificacao {
  Future<List<ResultadoGeocodificacao>> buscar(String texto);

  /// Null quando nada for encontrado.
  Future<ResultadoGeocodificacao?> reverso(double lat, double lng);
}
