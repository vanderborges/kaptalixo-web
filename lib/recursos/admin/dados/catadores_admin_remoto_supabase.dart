import 'package:supabase_flutter/supabase_flutter.dart';

import '../dominio/falha_admin.dart';
import 'catadores_admin_remoto.dart';

/// [CatadoresAdminRemoto] sobre o `SupabaseClient`.
///
/// Dados completos (documento e razão social, LGPD) são lidos da view
/// `v_catador_privado`, pois a tabela `catadores` não dá SELECT nessas colunas.
/// Nome e telefone vêm de `perfis` em consulta separada (view não tem FK).
class CatadoresAdminRemotoSupabase implements CatadoresAdminRemoto {
  CatadoresAdminRemotoSupabase(this._cliente);

  final SupabaseClient _cliente;

  static const _colunas =
      'perfil_id, tipo, documento, razao_social, status_cadastro, '
      'tipo_veiculo, capacidade_sacos';

  Future<T> _traduzir<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on FalhaAdmin {
      rethrow;
    } on PostgrestException catch (e) {
      throw FalhaAdmin.dePostgres(e.code);
    } on Exception catch (e) {
      final texto = e.toString();
      if (texto.contains('SocketException') ||
          texto.contains('ClientException')) {
        throw const FalhaAdmin(CodigoFalhaAdmin.rede);
      }
      throw const FalhaAdmin(CodigoFalhaAdmin.desconhecida);
    }
  }

  /// Junta `perfis(nome, telefone)` às linhas, no formato de `fromJson`.
  Future<List<Map<String, dynamic>>> _comPerfis(
    List<Map<String, dynamic>> linhas,
  ) async {
    if (linhas.isEmpty) return [];
    final ids = linhas.map((l) => l['perfil_id'] as String).toList();
    final perfis = await _cliente
        .from('perfis')
        .select('id, nome, telefone')
        .inFilter('id', ids);
    final porId = {for (final p in perfis) p['id'] as String: p};
    return [
      for (final l in linhas)
        {
          ...l,
          'perfis': {
            'nome': porId[l['perfil_id']]?['nome'],
            'telefone': porId[l['perfil_id']]?['telefone'],
          },
        },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> listar(String status) =>
      _traduzir(() async {
        final linhas = await _cliente
            .from('v_catador_privado')
            .select(_colunas)
            .eq('status_cadastro', status);
        final r = await _comPerfis(linhas);
        r.sort(
          (a, b) =>
              ((a['perfis']['nome'] as String?) ?? '').toLowerCase().compareTo(
                ((b['perfis']['nome'] as String?) ?? '').toLowerCase(),
              ),
        );
        return r;
      });

  @override
  Future<Map<String, dynamic>?> buscar(String id) => _traduzir(() async {
    final linha = await _cliente
        .from('v_catador_privado')
        .select(_colunas)
        .eq('perfil_id', id)
        .maybeSingle();
    if (linha == null) return null;
    return (await _comPerfis([linha])).first;
  });

  @override
  Future<Map<String, dynamic>?> atualizarStatus(String id, String status) =>
      _traduzir(() async {
        // RETURNING só com colunas liberadas pelo GRANT de SELECT.
        final alterada = await _cliente
            .from('catadores')
            .update({'status_cadastro': status})
            .eq('perfil_id', id)
            .select('perfil_id, status_cadastro')
            .maybeSingle();
        if (alterada == null) return null;
        return buscar(id);
      });
}
