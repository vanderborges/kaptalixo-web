import 'falha_gerador.dart';

enum MotivoFalhaAcompanhamento { naoCancelavel, inexistente, geral }

/// Falha ao acompanhar ou cancelar a coleta.
class FalhaAcompanhamento extends FalhaGerador {
  const FalhaAcompanhamento(this.motivo, [String? mensagem])
    : super(
        mensagem ?? 'Não foi possível atualizar sua coleta. Tente de novo.',
      );

  final MotivoFalhaAcompanhamento motivo;

  /// Falha em linguagem simples a partir do código de erro do RPC.
  factory FalhaAcompanhamento.doCodigo(String texto) {
    if (texto.contains('solicitacao_nao_cancelavel')) {
      return const FalhaAcompanhamento(
        MotivoFalhaAcompanhamento.naoCancelavel,
        'Esta coleta não pode mais ser cancelada.',
      );
    }
    if (texto.contains('solicitacao_inexistente')) {
      return const FalhaAcompanhamento(
        MotivoFalhaAcompanhamento.inexistente,
        'Não encontramos esta coleta.',
      );
    }
    return const FalhaAcompanhamento(MotivoFalhaAcompanhamento.geral);
  }
}
