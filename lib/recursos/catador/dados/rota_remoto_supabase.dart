import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../dominio/falha_catador.dart';
import 'rota_remoto.dart';

/// [RotaRemoto] sobre Supabase. Traduz erros de RPC em [FalhaCatador].
class RotaRemotoSupabase implements RotaRemoto {
  RotaRemotoSupabase(this._cliente);

  final SupabaseClient _cliente;

  Future<T> _traduzir<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on PostgrestException catch (e) {
      throw FalhaCatador(MotivoFalhaCatador.deCodigo(e.message));
    }
  }

  @override
  Future<String?> rotaAbertaId() => _traduzir(() async {
    final linha = await _cliente
        .from('v_rota_catador')
        .select('id')
        .inFilter('status', ['planejada', 'em_andamento'])
        .limit(1)
        .maybeSingle();
    return linha?['id'] as String?;
  });

  @override
  Future<Map<String, dynamic>?> buscarRota(String rotaId) =>
      _traduzir(() async {
        final rota = await _cliente
            .from('v_rota_catador')
            .select()
            .eq('id', rotaId)
            .maybeSingle();
        if (rota == null) return null;

        final paradas = List<Map<String, dynamic>>.from(
          await _cliente
              .from('rota_paradas')
              .select(
                'id, ordem, tipo, solicitacao_id, ponto_id, localizacao, '
                'status, eta, distancia_trecho_m, duracao_trecho_s',
              )
              .eq('rota_id', rotaId)
              .order('ordem'),
        );

        final solicitacaoIds = [
          for (final p in paradas)
            if (p['solicitacao_id'] != null) p['solicitacao_id'] as String,
        ];
        final solicitacoes = solicitacaoIds.isEmpty
            ? <Map<String, dynamic>>[]
            : List<Map<String, dynamic>>.from(
                await _cliente
                    .from('v_solicitacao_catador')
                    .select(
                      'id, qtd_sacos, endereco_texto, observacao, lat, lng, '
                      'gerador_nome, bloqueio_pin_ate',
                    )
                    .inFilter('id', solicitacaoIds),
              );

        final pontoIds = <String>{
          for (final p in paradas)
            if (p['ponto_id'] != null) p['ponto_id'] as String,
          if (rota['ponto_destino_id'] != null)
            rota['ponto_destino_id'] as String,
          if (rota['alternativas_ponto'] is List)
            for (final a in rota['alternativas_ponto'] as List)
              if (a is Map && a['ponto_id'] is String) a['ponto_id'] as String,
        };
        final pontos = pontoIds.isEmpty
            ? <Map<String, dynamic>>[]
            : List<Map<String, dynamic>>.from(
                await _cliente
                    .from('pontos_coleta')
                    .select('id, nome, localizacao')
                    .inFilter('id', pontoIds.toList()),
              );

        return {
          'rota': rota,
          'paradas': paradas,
          'solicitacoes': solicitacoes,
          'pontos': pontos,
        };
      });

  @override
  Stream<void> mudancas(String rotaId) {
    late final StreamController<void> ctrl;
    RealtimeChannel? canal;
    ctrl = StreamController<void>(
      onListen: () {
        final uid = _cliente.auth.currentUser?.id;
        if (uid == null) return;
        void avisar(PostgresChangePayload _) {
          if (!ctrl.isClosed) ctrl.add(null);
        }

        PostgresChangeFilter eq(String coluna, String valor) =>
            PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: coluna,
              value: valor,
            );

        canal = _cliente
            .channel('rota-$rotaId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'rotas',
              filter: eq('id', rotaId),
              callback: avisar,
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'rota_paradas',
              filter: eq('rota_id', rotaId),
              callback: avisar,
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'solicitacoes',
              filter: eq('catador_id', uid),
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
  Future<void> iniciarRota(String rotaId) => _traduzir(
    () async =>
        await _cliente.rpc<void>('iniciar_rota', params: {'p_rota': rotaId}),
  );

  @override
  Future<Map<String, dynamic>> avancarParada(
    String paradaId,
    String acao, {
    String? pin,
    String? motivo,
  }) => _traduzir(() async {
    final r = await _cliente.rpc<dynamic>(
      'avancar_parada',
      params: {
        'p_parada': paradaId,
        'p_acao': acao,
        'p_pin': pin,
        'p_motivo': motivo,
      },
    );
    return Map<String, dynamic>.from(r as Map);
  });

  @override
  Future<void> trocarPonto(String rotaId, String pontoId) => _traduzir(
    () async => await _cliente.rpc<void>(
      'trocar_ponto_destino',
      params: {'p_rota': rotaId, 'p_ponto': pontoId},
    ),
  );

  @override
  Future<void> atualizarLocalizacao(double lat, double lng, String rotaId) =>
      _traduzir(
        () async => await _cliente.rpc<void>(
          'atualizar_localizacao',
          params: {'p_lat': lat, 'p_lng': lng, 'p_rota': rotaId},
        ),
      );
}
