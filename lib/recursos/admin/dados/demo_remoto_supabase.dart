import 'package:supabase_flutter/supabase_flutter.dart';

import '../dominio/falha_admin.dart';
import 'demo_remoto.dart';

/// [DemoRemoto] sobre o `SupabaseClient` (somente RPCs; a RLS e as guardas
/// `e_admin()`/`modo_demo` vivem no banco).
class DemoRemotoSupabase implements DemoRemoto {
  DemoRemotoSupabase(this._cliente);

  final SupabaseClient _cliente;

  Future<T> _traduzir<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on FalhaAdmin {
      rethrow;
    } on PostgrestException catch (e) {
      throw FalhaAdmin.deRpc(e.code, e.message);
    } on Exception catch (e) {
      final texto = e.toString();
      if (texto.contains('SocketException') ||
          texto.contains('ClientException')) {
        throw const FalhaAdmin(CodigoFalhaAdmin.rede);
      }
      throw const FalhaAdmin(CodigoFalhaAdmin.desconhecida);
    }
  }

  @override
  Future<Map<String, dynamic>> snapshot({int eventos = 50}) =>
      _traduzir(() async {
        final r = await _cliente.rpc(
          'demo_snapshot',
          params: {'p_eventos': eventos},
        );
        return Map<String, dynamic>.from(r as Map);
      });

  @override
  Future<int> criarCatadores(int quantidade) => _traduzir(() async {
    final r = await _cliente.rpc(
      'demo_criar_catadores',
      params: {'p_n': quantidade},
    );
    return (r as num).toInt();
  });

  @override
  Future<String> criarPedido() => _traduzir(() async {
    final r = await _cliente.rpc('demo_criar_pedido');
    return r as String;
  });

  @override
  Future<void> resetar() => _traduzir(() => _cliente.rpc('resetar_demo'));

  @override
  Future<void> moverCatador(String catadorId, double lat, double lng) =>
      _traduzir(
        () => _cliente.rpc(
          'demo_mover_catador',
          params: {'p_catador': catadorId, 'p_lat': lat, 'p_lng': lng},
        ),
      );
}
