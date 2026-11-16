import '../dominio/dados_solicitacao.dart';
import '../dominio/falha_solicitacao.dart';
import '../dominio/solicitacao_repositorio.dart';

/// Fake: registra o que foi enviado e devolve [idCriado] (ou lança [falha]).
class SolicitacaoRepositorioFake implements SolicitacaoRepositorio {
  SolicitacaoRepositorioFake({this.falha, this.idCriado = 'sol-1'});

  FalhaSolicitacao? falha;
  String idCriado;
  final List<DadosSolicitacao> enviadas = [];

  @override
  Future<String> criar(DadosSolicitacao dados) async {
    enviadas.add(dados);
    if (falha != null) throw falha!;
    return idCriado;
  }
}
