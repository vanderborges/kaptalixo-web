import '../dominio/dados_solicitacao.dart';
import '../dominio/falha_solicitacao.dart';
import '../dominio/solicitacao_repositorio.dart';
import 'solicitacao_remoto.dart';

class SolicitacaoRepositorioImpl implements SolicitacaoRepositorio {
  SolicitacaoRepositorioImpl(this._remoto);

  final SolicitacaoRemoto _remoto;

  /// Parâmetros do RPC `criar_solicitacao`.
  static Map<String, dynamic> parametros(DadosSolicitacao d) => {
    'p_lat': d.posicao.latitude,
    'p_lng': d.posicao.longitude,
    'p_endereco_texto': d.enderecoNormalizado,
    'p_qtd_sacos': d.qtdSacos,
    'p_tamanho': d.tamanho.codigo,
    'p_materiais': d.materiais,
    'p_observacao': (d.observacao?.trim().isEmpty ?? true)
        ? null
        : d.observacao!.trim(),
    'p_foto_url': d.fotoUrl,
    'p_agendada_para': d.agendadaPara?.toUtc().toIso8601String(),
  };

  @override
  Future<String> criar(DadosSolicitacao dados) async {
    final erro = dados.validar();
    if (erro != null) {
      throw FalhaSolicitacao(MotivoFalhaSolicitacao.invalida, erro);
    }
    try {
      return await _remoto.criar(parametros(dados));
    } on FalhaSolicitacao {
      rethrow;
    } catch (e) {
      throw FalhaSolicitacao.doCodigo(e.toString());
    }
  }
}
