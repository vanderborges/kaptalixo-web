import 'dados_solicitacao.dart';

abstract interface class SolicitacaoRepositorio {
  /// Cria a solicitação e devolve o id. Lança `FalhaSolicitacao`.
  Future<String> criar(DadosSolicitacao dados);
}
