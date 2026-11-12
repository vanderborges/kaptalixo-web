import 'dart:async';

import '../../../nucleo/modelos/catador_cadastro.dart';
import '../../../nucleo/modelos/status_cadastro.dart';
import '../../../nucleo/modelos/tipo_catador.dart';
import '../dominio/catadores_admin_repositorio.dart';
import '../dominio/falha_admin.dart';

/// Fake em memória. Nasce com 2 pendentes, 1 aprovado e 1 suspenso.
class CatadoresAdminRepositorioFake implements CatadoresAdminRepositorio {
  CatadoresAdminRepositorioFake({List<CatadorCadastro>? iniciais}) {
    for (final c in iniciais ?? padrao()) {
      _itens[c.id] = c;
    }
  }

  static List<CatadorCadastro> padrao() => const [
    CatadorCadastro(
      id: 'c-pendente-1',
      nome: 'Maria Souza',
      telefone: '11999990001',
      tipo: TipoCatador.pessoa,
      documento: '12345678901',
      statusCadastro: StatusCadastro.pendente,
      tipoVeiculo: 'carrinho',
      capacidadeSacos: 8,
    ),
    CatadorCadastro(
      id: 'c-pendente-2',
      nome: 'Recicla Já',
      tipo: TipoCatador.empresa,
      documento: '12345678000199',
      razaoSocial: 'Recicla Já Ltda',
      statusCadastro: StatusCadastro.pendente,
      tipoVeiculo: 'utilitario',
      capacidadeSacos: 30,
    ),
    CatadorCadastro(
      id: 'c-aprovado-1',
      nome: 'João Lima',
      tipo: TipoCatador.pessoa,
      statusCadastro: StatusCadastro.aprovado,
    ),
    CatadorCadastro(
      id: 'c-suspenso-1',
      nome: 'Pedro Alves',
      tipo: TipoCatador.pessoa,
      statusCadastro: StatusCadastro.suspenso,
    ),
  ];

  final Map<String, CatadorCadastro> _itens = {};

  /// Falha lançada na próxima chamada (uma vez).
  FalhaAdmin? falhaProxima;

  /// Bloqueia as chamadas até completar (testa "carregando").
  Completer<void>? bloqueio;

  /// Chamadas de [alterarStatus], na ordem: (id, status).
  final List<(String, StatusCadastro)> alteracoes = [];

  Future<void> _preparar() async {
    if (bloqueio != null) await bloqueio!.future;
    final falha = falhaProxima;
    if (falha != null) {
      falhaProxima = null;
      throw falha;
    }
  }

  @override
  Future<List<CatadorCadastro>> listar(StatusCadastro status) async {
    await _preparar();
    return _itens.values.where((c) => c.statusCadastro == status).toList();
  }

  @override
  Future<CatadorCadastro> buscar(String id) async {
    await _preparar();
    final c = _itens[id];
    if (c == null) throw const FalhaAdmin(CodigoFalhaAdmin.naoEncontrado);
    return c;
  }

  @override
  Future<CatadorCadastro> alterarStatus(
    String id,
    StatusCadastro status,
  ) async {
    await _preparar();
    final c = _itens[id];
    if (c == null) throw const FalhaAdmin(CodigoFalhaAdmin.semPermissao);
    alteracoes.add((id, status));
    return _itens[id] = c.comStatus(status);
  }
}
