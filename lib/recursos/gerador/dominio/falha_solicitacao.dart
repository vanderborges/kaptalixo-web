import 'falha_gerador.dart';

enum MotivoFalhaSolicitacao { solicitacaoAtiva, invalida, semPermissao, geral }

/// Falha ao criar a solicitação de coleta.
class FalhaSolicitacao extends FalhaGerador {
  const FalhaSolicitacao(this.motivo, [String? mensagem])
    : super(mensagem ?? 'Não foi possível chamar a coleta. Tente novamente.');

  final MotivoFalhaSolicitacao motivo;

  /// Falha em linguagem simples a partir do código de erro do RPC.
  factory FalhaSolicitacao.doCodigo(String texto) {
    if (texto.contains('solicitacao_ativa_existente')) {
      return const FalhaSolicitacao(
        MotivoFalhaSolicitacao.solicitacaoAtiva,
        'Você já tem uma coleta em andamento. Acompanhe-a antes de chamar outra.',
      );
    }
    if (texto.contains('parametro_invalido')) {
      return const FalhaSolicitacao(
        MotivoFalhaSolicitacao.invalida,
        'Confira os dados da coleta e tente de novo.',
      );
    }
    if (texto.contains('sem_permissao')) {
      return const FalhaSolicitacao(
        MotivoFalhaSolicitacao.semPermissao,
        'Sua conta não pode chamar coletas.',
      );
    }
    return const FalhaSolicitacao(MotivoFalhaSolicitacao.geral);
  }
}
