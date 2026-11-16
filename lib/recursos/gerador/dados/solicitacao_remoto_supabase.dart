import 'package:supabase_flutter/supabase_flutter.dart';

import 'solicitacao_remoto.dart';

class SolicitacaoRemotoSupabase implements SolicitacaoRemoto {
  SolicitacaoRemotoSupabase(this._cliente);

  final SupabaseClient _cliente;

  @override
  Future<String> criar(Map<String, dynamic> params) async {
    final id = await _cliente.rpc<dynamic>('criar_solicitacao', params: params);
    return id as String;
  }
}
