import 'acompanhamento_coleta.dart';

abstract interface class AcompanhamentoRepositorio {
  /// Acompanha a solicitação em tempo real: emite o retrato atual ao assinar
  /// e a cada mudança (status, posição do catador). Erros chegam como
  /// `FalhaAcompanhamento` no stream.
  Stream<AcompanhamentoColeta> observar(String solicitacaoId);

  /// Solicitações do gerador que ainda importam na home: as ativas
  /// (buscando/aceita/a_caminho/no_local) e as `coletada` (a avaliar, enquanto
  /// o catador leva ao ponto). Pode haver uma coletada e uma ativa ao mesmo
  /// tempo (T1.8). Emite ao assinar e a cada mudança.
  Stream<List<AcompanhamentoColeta>> observarAtuais();

  /// Cancela a coleta (UC12/RN09). Lança `FalhaAcompanhamento`.
  Future<void> cancelar(String solicitacaoId, {String? motivo});
}
