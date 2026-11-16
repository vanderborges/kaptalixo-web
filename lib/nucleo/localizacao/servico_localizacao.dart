import 'posicao.dart';

abstract interface class ServicoLocalizacao {
  /// Fluxo de posicoes. Pode lancar [FalhaLocalizacao] (GPS).
  Stream<Posicao> posicoes();

  /// Posicao atual. Pode lancar [FalhaLocalizacao] (GPS).
  Future<Posicao> atual();
}
