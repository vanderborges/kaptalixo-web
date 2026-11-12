import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../dominio/falha_auth.dart';
import 'auth_remoto.dart';

/// [AuthRemoto] sobre o `SupabaseClient`. Único lugar que fala com o Supabase
/// no fluxo de autenticação.
class AuthRemotoSupabase implements AuthRemoto {
  AuthRemotoSupabase(this._cliente);

  final SupabaseClient _cliente;

  GoTrueClient get _auth => _cliente.auth;

  @override
  String? get usuarioId => _auth.currentUser?.id;

  @override
  Stream<void> get aoSair => _auth.onAuthStateChange
      .where((e) => e.event == AuthChangeEvent.signedOut)
      .map((_) {});

  Future<T> _traduzir<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on FalhaAuth {
      rethrow;
    } on AuthException catch (e) {
      throw FalhaAuth(_codigoDe(e));
    } on PostgrestException {
      throw const FalhaAuth(CodigoFalhaAuth.desconhecida);
    } on Exception catch (e) {
      // SocketException/ClientException etc.: tratadas como falha de rede.
      final texto = e.toString();
      if (texto.contains('SocketException') ||
          texto.contains('ClientException')) {
        throw const FalhaAuth(CodigoFalhaAuth.rede);
      }
      throw const FalhaAuth(CodigoFalhaAuth.desconhecida);
    }
  }

  CodigoFalhaAuth _codigoDe(AuthException e) {
    final codigo = e.code ?? '';
    final msg = e.message.toLowerCase();
    if (codigo == 'invalid_credentials' ||
        msg.contains('invalid login credentials')) {
      return CodigoFalhaAuth.credenciaisInvalidas;
    }
    if (codigo == 'user_already_exists' ||
        codigo == 'email_exists' ||
        msg.contains('already registered')) {
      return CodigoFalhaAuth.emailJaUsado;
    }
    if (codigo == 'weak_password' || e is AuthWeakPasswordException) {
      return CodigoFalhaAuth.senhaFraca;
    }
    return CodigoFalhaAuth.desconhecida;
  }

  @override
  Future<String> entrar(String email, String senha) => _traduzir(() async {
    final r = await _auth.signInWithPassword(email: email, password: senha);
    final id = r.user?.id;
    if (id == null) throw const FalhaAuth(CodigoFalhaAuth.desconhecida);
    return id;
  });

  @override
  Future<String> criarConta(String email, String senha) => _traduzir(() async {
    final r = await _auth.signUp(email: email, password: senha);
    final id = r.user?.id;
    // Sem sessão = confirmação de e-mail exigida (desligada no Supabase local).
    if (id == null || r.session == null) {
      throw const FalhaAuth(CodigoFalhaAuth.desconhecida);
    }
    return id;
  });

  @override
  Future<Map<String, dynamic>?> buscarPerfil(String id) => _traduzir(
    () =>
        _cliente.from('perfis').select('id, papel').eq('id', id).maybeSingle(),
  );

  @override
  Future<Map<String, dynamic>?> buscarCatador(String id) => _traduzir(
    () => _cliente
        .from('catadores')
        .select('perfil_id, status_cadastro')
        .eq('perfil_id', id)
        .maybeSingle(),
  );

  @override
  Future<void> inserirPerfil(String id, Map<String, dynamic> perfil) =>
      _traduzir(() => _cliente.from('perfis').insert({'id': id, ...perfil}));

  @override
  Future<void> inserirGerador(String id) =>
      _traduzir(() => _cliente.from('geradores').insert({'perfil_id': id}));

  @override
  Future<void> inserirCatador(String id, Map<String, dynamic> catador) =>
      _traduzir(
        () => _cliente.from('catadores').insert({'perfil_id': id, ...catador}),
      );

  @override
  Future<void> cadastrarPonto(Map<String, dynamic> ponto) =>
      _traduzir(() => _cliente.rpc('cadastrar_ponto', params: ponto));

  @override
  Future<void> sair() => _traduzir(() => _auth.signOut());
}
