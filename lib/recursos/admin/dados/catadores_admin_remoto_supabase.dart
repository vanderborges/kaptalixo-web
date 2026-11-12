import 'package:supabase_flutter/supabase_flutter.dart';

import '../dominio/falha_admin.dart';
import 'catadores_admin_remoto.dart';

/// [CatadoresAdminRemoto] sobre o `SupabaseClient`.
class CatadoresAdminRemotoSupabase implements CatadoresAdminRemoto {
  CatadoresAdminRemotoSupabase(this._cliente);

  final SupabaseClient _cliente;

  static const _colunas =
      'perfil_id, tipo, documento, razao_social, status_cadastro, '
      'tipo_veiculo, capacidade_sacos, perfis(nome, telefone)';

  Future<T> _traduzir<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on FalhaAdmin {
      rethrow;
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const FalhaAdmin(CodigoFalhaAdmin.semPermissao);
      }
      throw const FalhaAdmin(CodigoFalhaAdmin.desconhecida);
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
  Future<List<Map<String, dynamic>>> listar(String status) => _traduzir(
    () => _cliente
        .from('catadores')
        .select(_colunas)
        .eq('status_cadastro', status)
        .order('perfil_id'),
  );

  @override
  Future<Map<String, dynamic>?> buscar(String id) => _traduzir(
    () => _cliente
        .from('catadores')
        .select(_colunas)
        .eq('perfil_id', id)
        .maybeSingle(),
  );

  @override
  Future<Map<String, dynamic>?> atualizarStatus(String id, String status) =>
      _traduzir(
        () => _cliente
            .from('catadores')
            .update({'status_cadastro': status})
            .eq('perfil_id', id)
            .select(_colunas)
            .maybeSingle(),
      );
}
