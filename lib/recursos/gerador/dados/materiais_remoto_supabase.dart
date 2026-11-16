import 'package:supabase_flutter/supabase_flutter.dart';

import 'materiais_remoto.dart';

class MateriaisRemotoSupabase implements MateriaisRemoto {
  MateriaisRemotoSupabase(this._cliente);

  final SupabaseClient _cliente;

  @override
  Future<List<Map<String, dynamic>>> listar() async {
    final linhas = await _cliente
        .from('materiais')
        .select('id, codigo, nome, categoria')
        .order('id');
    return linhas.cast<Map<String, dynamic>>();
  }
}
