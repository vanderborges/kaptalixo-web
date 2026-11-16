import 'situacao_catador.dart';

/// Disponibilidade do catador (UC14) e envio da posição.
abstract class DisponibilidadeRepositorio {
  /// Situação atual gravada no servidor.
  Future<SituacaoCatador> situacaoAtual();

  /// RPC `alternar_disponibilidade`. Lança `FalhaCatador`.
  Future<SituacaoCatador> alternar(bool disponivel);

  /// RPC `atualizar_localizacao`. Lança `FalhaCatador`.
  Future<void> atualizarLocalizacao(double lat, double lng);
}
