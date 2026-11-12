import 'dart:async';

import '../modelos/papel.dart';
import '../modelos/sessao.dart';

/// Acesso à sessão do usuário (papel lido de `perfis.papel`).
abstract class SessaoRepositorio {
  /// Sessão atual; nula quando deslogado.
  Sessao? get atual;

  /// Emite a cada mudança de sessão.
  Stream<Sessao?> get mudancas;

  Future<void> sair();

  /// Relê papel/status do servidor (ex.: catador aprovado pelo admin) e emite
  /// em [mudancas] se algo mudou. Devolve a sessão atualizada (nula = deslogado).
  Future<Sessao?> recarregar();
}

/// Implementação falsa para testes e desenvolvimento.
class SessaoRepositorioFake implements SessaoRepositorio {
  SessaoRepositorioFake({Papel? papel})
    : _atual = papel == null
          ? null
          : Sessao(usuarioId: 'fake-id', papel: papel);

  Sessao? _atual;
  final _controle = StreamController<Sessao?>.broadcast();

  @override
  Sessao? get atual => _atual;

  @override
  Stream<Sessao?> get mudancas => _controle.stream;

  /// Simula login com o papel informado.
  void entrarComo(Papel papel) {
    _atual = Sessao(usuarioId: 'fake-id', papel: papel);
    _controle.add(_atual);
  }

  /// Sessão que [recarregar] passará a devolver/emitir (simula o servidor).
  void definirSessao(Sessao sessao) => _proxima = sessao;

  Sessao? _proxima;

  @override
  Future<Sessao?> recarregar() async {
    final nova = _proxima;
    if (nova != null && nova != _atual) {
      _atual = nova;
      _controle.add(nova);
    }
    return _atual;
  }

  @override
  Future<void> sair() async {
    _atual = null;
    _controle.add(null);
  }

  /// Verdadeiro enquanto alguém escuta [mudancas] (útil em testes).
  bool get temOuvintes => _controle.hasListener;

  /// Libera o controlador de eventos.
  Future<void> fechar() => _controle.close();
}
