import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../dominio/falha_catador.dart';
import 'ofertas_remoto.dart';

/// [OfertasRemoto] sobre Supabase. Traduz erros de RPC em [FalhaCatador].
class OfertasRemotoSupabase implements OfertasRemoto {
  OfertasRemotoSupabase(this._cliente);

  final SupabaseClient _cliente;

  Future<T> _traduzir<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on PostgrestException catch (e) {
      throw FalhaCatador(MotivoFalhaCatador.deCodigo(e.message));
    }
  }

  @override
  Future<List<Map<String, dynamic>>> buscarPendentes() => _traduzir(() async {
    final linhas = await _cliente
        .from('v_oferta_resumo')
        .select()
        .order('expira_em');
    return List<Map<String, dynamic>>.from(linhas);
  });

  @override
  Stream<void> mudancas() {
    late final StreamController<void> ctrl;
    RealtimeChannel? canal;
    ctrl = StreamController<void>(
      onListen: () {
        final uid = _cliente.auth.currentUser?.id;
        if (uid == null) return;
        canal = _cliente
            .channel('ofertas-$uid')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'ofertas',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'catador_id',
                value: uid,
              ),
              callback: (_) {
                if (!ctrl.isClosed) ctrl.add(null);
              },
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
  Future<String> aceitar(String ofertaId) => _traduzir(
    () async => (await _cliente.rpc<dynamic>(
      'aceitar_oferta',
      params: {'p_oferta': ofertaId},
    )).toString(),
  );

  @override
  Future<void> recusar(String ofertaId) => _traduzir(
    () async => await _cliente.rpc<void>(
      'recusar_oferta',
      params: {'p_oferta': ofertaId},
    ),
  );

  @override
  Future<int> expirar() => _traduzir(
    () async =>
        ((await _cliente.rpc<dynamic>('expirar_ofertas')) as num?)?.toInt() ??
        0,
  );
}
