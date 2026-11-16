import 'package:supabase_flutter/supabase_flutter.dart';

import '../dominio/falha_catador.dart';
import 'disponibilidade_remoto.dart';

/// [DisponibilidadeRemoto] sobre Supabase. Traduz erros de RPC em [FalhaCatador].
class DisponibilidadeRemotoSupabase implements DisponibilidadeRemoto {
  DisponibilidadeRemotoSupabase(this._cliente);

  final SupabaseClient _cliente;

  Future<T> _traduzir<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on PostgrestException catch (e) {
      throw FalhaCatador(MotivoFalhaCatador.deCodigo(e.message));
    }
  }

  @override
  Future<String> situacaoAtual() => _traduzir(() async {
    final uid = _cliente.auth.currentUser?.id;
    if (uid == null) throw const FalhaCatador(MotivoFalhaCatador.semPermissao);
    final linha = await _cliente
        .from('catadores')
        .select('situacao')
        .eq('perfil_id', uid)
        .single();
    return linha['situacao'] as String;
  });

  @override
  Future<String> alternar(bool disponivel) => _traduzir(
    () async => await _cliente.rpc<String>(
      'alternar_disponibilidade',
      params: {'p_disponivel': disponivel},
    ),
  );

  @override
  Future<void> atualizarLocalizacao(double lat, double lng) => _traduzir(
    () async => await _cliente.rpc<void>(
      'atualizar_localizacao',
      params: {'p_lat': lat, 'p_lng': lng},
    ),
  );
}
