import 'dart:async';

import '../../../nucleo/modelos/papel.dart';
import '../../../nucleo/modelos/sessao.dart';
import '../../../nucleo/modelos/status_cadastro.dart';
import '../dominio/auth_repositorio.dart';
import '../dominio/dados_cadastro.dart';
import '../dominio/falha_auth.dart';
import 'auth_remoto.dart';

/// Implementação de [AuthRepositorio] sobre [AuthRemoto] (Supabase em produção).
class AuthRepositorioImpl implements AuthRepositorio {
  AuthRepositorioImpl(this._remoto) {
    _sub = _remoto.aoSair.listen((_) => _definir(null));
  }

  final AuthRemoto _remoto;
  late final StreamSubscription<void> _sub;
  final _controle = StreamController<Sessao?>.broadcast();
  Sessao? _atual;

  /// Cria o repositório e restaura a sessão já existente (se houver).
  static Future<AuthRepositorioImpl> restaurar(AuthRemoto remoto) async {
    final repo = AuthRepositorioImpl(remoto);
    final id = remoto.usuarioId;
    if (id != null) {
      try {
        repo._atual = await repo._carregarSessao(id);
      } on FalhaAuth {
        // Sem perfil ou sem rede: segue deslogado na tela de entrada.
        repo._atual = null;
      }
    }
    return repo;
  }

  @override
  Sessao? get atual => _atual;

  @override
  Stream<Sessao?> get mudancas => _controle.stream;

  void _definir(Sessao? sessao) {
    if (sessao == _atual && sessao != null) return;
    _atual = sessao;
    if (!_controle.isClosed) _controle.add(sessao);
  }

  /// Papel vem de `perfis`; status de `catadores` (apenas catador).
  Future<Sessao> _carregarSessao(String id) async {
    final perfil = await _remoto.buscarPerfil(id);
    if (perfil == null) {
      throw const FalhaAuth(CodigoFalhaAuth.perfilNaoEncontrado);
    }
    final papel = Papel.deTexto(perfil['papel'] as String);
    StatusCadastro? status;
    if (papel == Papel.catador) {
      final catador = await _remoto.buscarCatador(id);
      if (catador == null) {
        throw const FalhaAuth(CodigoFalhaAuth.perfilNaoEncontrado);
      }
      status = StatusCadastro.deTexto(catador['status_cadastro'] as String);
    }
    return Sessao(usuarioId: id, papel: papel, statusCadastro: status);
  }

  @override
  Future<Sessao> entrar({required String email, required String senha}) async {
    final id = await _remoto.entrar(email.trim(), senha);
    try {
      final sessao = await _carregarSessao(id);
      _definir(sessao);
      return sessao;
    } catch (_) {
      await _remoto.sair();
      rethrow;
    }
  }

  @override
  Future<Sessao> cadastrar(DadosCadastro dados) async {
    final id = await _remoto.criarConta(dados.email.trim(), dados.senha);
    try {
      switch (dados) {
        case CadastroPonto():
          // Papel `ponto` não passa pela RLS de `perfis`: o RPC cria tudo.
          await _remoto.cadastrarPonto({
            ...dados.perfilJson(),
            ...dados.pontoJson(),
          });
        case CadastroGerador():
          await _remoto.inserirPerfil(id, dados.perfilJson());
          await _remoto.inserirGerador(id);
        case CadastroCatador():
          await _remoto.inserirPerfil(id, dados.perfilJson());
          await _remoto.inserirCatador(id, dados.catadorJson());
      }
      final sessao = await _carregarSessao(id);
      _definir(sessao);
      return sessao;
    } catch (_) {
      await _remoto.sair();
      rethrow;
    }
  }

  @override
  Future<Sessao?> recarregar() async {
    final atual = _atual;
    if (atual == null) return null;
    final sessao = await _carregarSessao(atual.usuarioId);
    _definir(sessao);
    return sessao;
  }

  @override
  Future<void> sair() async {
    await _remoto.sair();
    _definir(null);
  }

  /// Libera recursos (usado em testes).
  Future<void> fechar() async {
    await _sub.cancel();
    await _controle.close();
  }
}
