import 'acompanhamento_coleta.dart';

abstract interface class AcompanhamentoRepositorio {
  /// Acompanha a solicitação em tempo real: emite o retrato atual ao assinar
  /// e a cada mudança (status, posição do catador). Erros chegam como
  /// `FalhaAcompanhamento` no stream.
  Stream<AcompanhamentoColeta> observar(String solicitacaoId);

  /// Cancela a coleta (UC12/RN09). Lança `FalhaAcompanhamento`.
  Future<void> cancelar(String solicitacaoId, {String? motivo});
}
