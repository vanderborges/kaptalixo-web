import 'dart:async';

import '../../../nucleo/modelos/papel.dart';
import '../../../nucleo/modelos/sessao.dart';
import '../../../nucleo/modelos/status_cadastro.dart';
import '../dominio/auth_repositorio.dart';
import '../dominio/dados_cadastro.dart';
import '../dominio/falha_auth.dart';

/// Fake em memória para testes de widget e desenvolvimento sem backend.
///
/// Já nasce com um usuário por papel (`<papel>@kaptalixo.dev`, senha
/// `Kaptalixo#Dev1`), mais `pendente@kaptalixo.dev` (catador pendente).
class AuthRepositorioFake implements AuthRepositorio {
  AuthRepositorioFake({Sessao? sessao}) : _atual = sessao {
    for (final p in Papel.values) {
      _contas['${p.name}@kaptalixo.dev'] = _Conta(
        senhaPadrao,
        Sessao(
          usuarioId: 'fake-${p.name}',
          papel: p,
          statusCadastro: p == Papel.catador ? StatusCadastro.aprovado : null,
        ),
      );
    }
    _contas['pendente@kaptalixo.dev'] = _Conta(
      senhaPadrao,
      const Sessao(
        usuarioId: 'fake-pendente',
        papel: Papel.catador,
        statusCadastro: StatusCadastro.pendente,
      ),
    );
  }

  static const senhaPadrao = 'Kaptalixo#Dev1';

  final Map<String, _Conta> _contas = {};
  final _controle = StreamController<Sessao?>.broadcast();
  Sessao? _atual;

  /// Falha a ser lançada na próxima chamada de entrar/cadastrar (uma vez).
  FalhaAuth? falhaProxima;

  /// Cadastros recebidos, na ordem (para asserções).
  final List<DadosCadastro> cadastros = [];

  /// Atraso artificial para testar o estado "carregando".
  Completer<void>? bloqueio;

  @override
  Sessao? get atual => _atual;

  @override
  Stream<Sessao?> get mudancas => _controle.stream;

  void _definir(Sessao? s) {
    _atual = s;
    _controle.add(s);
  }

  Future<void> _preparar() async {
    if (bloqueio != null) await bloqueio!.future;
    final falha = falhaProxima;
    if (falha != null) {
      falhaProxima = null;
      throw falha;
    }
  }

  @override
  Future<Sessao> entrar({required String email, required String senha}) async {
    await _preparar();
    final conta = _contas[email.trim().toLowerCase()];
    if (conta == null || conta.senha != senha) {
      throw const FalhaAuth(CodigoFalhaAuth.credenciaisInvalidas);
    }
    _definir(conta.sessao);
    return conta.sessao;
  }

  @override
  Future<Sessao> cadastrar(DadosCadastro dados) async {
    await _preparar();
    final email = dados.email.trim().toLowerCase();
    if (_contas.containsKey(email)) {
      throw const FalhaAuth(CodigoFalhaAuth.emailJaUsado);
    }
    if (dados.senha.length < tamanhoMinimoSenha) {
      throw const FalhaAuth(CodigoFalhaAuth.senhaFraca);
    }
    cadastros.add(dados);
    final sessao = Sessao(
      usuarioId: 'fake-novo-${cadastros.length}',
      papel: dados.papel,
      statusCadastro: dados.papel == Papel.catador
          ? StatusCadastro.pendente
          : null,
    );
    _contas[email] = _Conta(dados.senha, sessao);
    _definir(sessao);
    return sessao;
  }

  /// Simula a decisão do admin sobre um catador (aplicada em [recarregar]).
  void definirStatusCatador(String usuarioId, StatusCadastro status) {
    for (final conta in _contas.values) {
      final s = conta.sessao;
      if (s.usuarioId == usuarioId) {
        conta.sessao = Sessao(
          usuarioId: s.usuarioId,
          papel: s.papel,
          statusCadastro: status,
        );
      }
    }
  }

  /// Falha lançada na próxima chamada de [recarregar] (uma vez).
  FalhaAuth? falhaRecarregar;

  @override
  Future<Sessao?> recarregar() async {
    final falha = falhaRecarregar;
    if (falha != null) {
      falhaRecarregar = null;
      throw falha;
    }
    final atual = _atual;
    if (atual == null) return null;
    final nova = _contas.values
        .map((c) => c.sessao)
        .firstWhere((s) => s.usuarioId == atual.usuarioId, orElse: () => atual);
    if (nova != atual) _definir(nova);
    return nova;
  }

  @override
  Future<void> sair() async {
    _definir(null);
  }

  /// Verdadeiro enquanto alguém escuta [mudancas].
  bool get temOuvintes => _controle.hasListener;

  Future<void> fechar() => _controle.close();
}

class _Conta {
  _Conta(this.senha, this.sessao);
  final String senha;
  Sessao sessao;
}
