import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'acompanhamento_remoto.dart';

/// [AcompanhamentoRemoto] sobre Supabase (visão do gerador + Realtime).
class AcompanhamentoRemotoSupabase implements AcompanhamentoRemoto {
  AcompanhamentoRemotoSupabase(this._cliente);

  final SupabaseClient _cliente;

  @override
  Future<Map<String, dynamic>?> buscarSolicitacao(String id) => _cliente
      .from('v_solicitacao_gerador')
      .select()
      .eq('id', id)
      .maybeSingle();

  @override
  Future<Map<String, dynamic>?> buscarPosicao(String id) => _cliente
      .from('posicoes_atendimento')
      .select('lat,lng,atualizada_em')
      .eq('solicitacao_id', id)
      .maybeSingle();

  @override
  Stream<void> mudancas(String id) {
    late final StreamController<void> ctrl;
    RealtimeChannel? canal;
    ctrl = StreamController<void>(
      onListen: () {
        void aviso(PostgresChangePayload _) {
          if (!ctrl.isClosed) ctrl.add(null);
        }

        canal = _cliente
            .channel('acompanhamento-$id')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'solicitacoes',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'id',
                value: id,
              ),
              callback: aviso,
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'posicoes_atendimento',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'solicitacao_id',
                value: id,
              ),
              callback: aviso,
            )
            .subscribe();
      },
      onCancel: () async {
        final c = canal;
        if (c != null) await _cliente.removeChannel(c);
      },
    );
    return ctrl.stream;
  }

  @override
  Future<void> cancelar(String id, String? motivo) async {
    await _cliente.rpc<dynamic>(
      'cancelar_solicitacao',
      params: {'p_solicitacao': id, 'p_motivo': motivo},
    );
  }
}
