import 'package:supabase_flutter/supabase_flutter.dart';

import 'pontos_proximos_remoto.dart';

/// [PontosProximosRemoto] sobre o RPC `pontos_proximos(p_lat, p_lng, p_raio_m)`.
class PontosProximosRemotoSupabase implements PontosProximosRemoto {
  PontosProximosRemotoSupabase(this._cliente);

  final SupabaseClient _cliente;

  @override
  Future<List<Map<String, dynamic>>> proximos(
    double lat,
    double lng,
    double raioMetros,
  ) async {
    final linhas = await _cliente.rpc<List<dynamic>>(
      'pontos_proximos',
      params: {'p_lat': lat, 'p_lng': lng, 'p_raio_m': raioMetros},
    );
    return linhas.cast<Map<String, dynamic>>();
  }
}
