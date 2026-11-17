import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../dominio/falha_ponto.dart';
import 'ponto_remoto.dart';

/// [PontoRemoto] sobre Supabase. Traduz erros de RPC em [FalhaPonto].
class PontoRemotoSupabase implements PontoRemoto {
  PontoRemotoSupabase(this._cliente);

  final SupabaseClient _cliente;

  Future<T> _traduzir<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on PostgrestException catch (e) {
      throw FalhaPonto(MotivoFalhaPonto.deCodigo(e.message));
    }
  }

  Future<String?> _pontoId() async {
    final uid = _cliente.auth.currentUser?.id;
    if (uid == null) return null;
    final linha = await _cliente
        .from('pontos_coleta')
        .select('id')
        .eq('perfil_id', uid)
        .maybeSingle();
    return linha?['id'] as String?;
  }

  @override
  Future<List<Map<String, dynamic>>> entregasACaminho() => _traduzir(() async {
    final dados = await _cliente.from('v_entrega_a_caminho').select();
    return List<Map<String, dynamic>>.from(dados);
  });

  @override
  Stream<void> mudancas() {
    late final StreamController<void> ctrl;
    RealtimeChannel? canal;
    ctrl = StreamController<void>(
      onListen: () async {
        final pontoId = await _pontoId();
        if (pontoId == null || ctrl.isClosed) return;
        void avisar(PostgresChangePayload _) {
          if (!ctrl.isClosed) ctrl.add(null);
        }

        canal = _cliente
            .channel('ponto-$pontoId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'rotas',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'ponto_destino_id',
                value: pontoId,
              ),
              callback: avisar,
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'rota_paradas',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'ponto_id',
                value: pontoId,
              ),
              callback: avisar,
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
  Future<String> confirmarEntrega(String rotaId) => _traduzir(() async {
    final id = await _cliente.rpc<dynamic>(
      'confirmar_entrega',
      params: {'p_rota': rotaId},
    );
    return id as String;
  });
}
