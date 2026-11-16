import 'dart:async';

import '../dominio/acompanhamento_coleta.dart';
import '../dominio/acompanhamento_repositorio.dart';
import '../dominio/falha_acompanhamento.dart';
import 'acompanhamento_remoto.dart';

class AcompanhamentoRepositorioImpl implements AcompanhamentoRepositorio {
  AcompanhamentoRepositorioImpl(this._remoto);

  final AcompanhamentoRemoto _remoto;

  Future<AcompanhamentoColeta> _carregar(String id) async {
    try {
      final linha = await _remoto.buscarSolicitacao(id);
      if (linha == null) {
        throw const FalhaAcompanhamento(
          MotivoFalhaAcompanhamento.inexistente,
          'Não encontramos esta coleta.',
        );
      }
      final status = StatusColeta.doCodigo(linha['status'] as String);
      final posicao = status.comCatador
          ? await _remoto.buscarPosicao(id)
          : null;
      return AcompanhamentoColeta.deLinha(linha, posicao: posicao);
    } on FalhaAcompanhamento {
      rethrow;
    } catch (e) {
      throw FalhaAcompanhamento.doCodigo(e.toString());
    }
  }

  @override
  Stream<AcompanhamentoColeta> observar(String solicitacaoId) {
    late final StreamController<AcompanhamentoColeta> ctrl;
    StreamSubscription<void>? sub;
    var carregando = false;
    var pendente = false;

    Future<void> atualizar() async {
      if (carregando) {
        pendente = true; // coalesce rajadas de eventos Realtime
        return;
      }
      carregando = true;
      try {
        do {
          pendente = false;
          final r = await _carregar(solicitacaoId);
          if (!ctrl.isClosed) ctrl.add(r);
        } while (pendente && !ctrl.isClosed);
      } catch (e, st) {
        if (!ctrl.isClosed) ctrl.addError(e, st);
      } finally {
        carregando = false;
      }
    }

    ctrl = StreamController<AcompanhamentoColeta>(
      onListen: () {
        sub = _remoto.mudancas(solicitacaoId).listen((_) => atualizar());
        atualizar();
      },
      onCancel: () => sub?.cancel(),
    );
    return ctrl.stream;
  }

  @override
  Future<void> cancelar(String solicitacaoId, {String? motivo}) async {
    final m = motivo?.trim();
    try {
      await _remoto.cancelar(
        solicitacaoId,
        (m == null || m.isEmpty) ? null : m,
      );
    } catch (e) {
      throw FalhaAcompanhamento.doCodigo(e.toString());
    }
  }
}
