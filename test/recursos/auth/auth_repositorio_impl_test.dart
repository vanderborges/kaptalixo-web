import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/nucleo/modelos/papel.dart';
import 'package:kaptalixo/nucleo/modelos/status_cadastro.dart';
import 'package:kaptalixo/nucleo/modelos/tipo_catador.dart';
import 'package:kaptalixo/recursos/auth/dados/auth_remoto.dart';
import 'package:kaptalixo/recursos/auth/dados/auth_repositorio_impl.dart';
import 'package:kaptalixo/recursos/auth/dominio/dados_cadastro.dart';
import 'package:kaptalixo/recursos/auth/dominio/falha_auth.dart';

/// Remoto em memória que imita Auth + tabelas.
class RemotoFake implements AuthRemoto {
  final perfis = <String, Map<String, dynamic>>{};
  final catadores = <String, Map<String, dynamic>>{};
  final geradores = <String>[];
  final pontos = <Map<String, dynamic>>[];
  final contas = <String, ({String id, String senha})>{};
  final _saiu = StreamController<void>.broadcast();
  String? _logado;
  int sairChamadas = 0;
  Object? falhaAoInserirPerfil;

  void semear(String email, String senha, String id, String papel) {
    contas[email] = (id: id, senha: senha);
    perfis[id] = {'id': id, 'papel': papel};
  }

  @override
  String? get usuarioId => _logado;

  @override
  Stream<void> get aoSair => _saiu.stream;

  void expirarSessao() {
    _logado = null;
    _saiu.add(null);
  }

  @override
  Future<String> entrar(String email, String senha) async {
    final c = contas[email];
    if (c == null || c.senha != senha) {
      throw const FalhaAuth(CodigoFalhaAuth.credenciaisInvalidas);
    }
    return _logado = c.id;
  }

  @override
  Future<String> criarConta(String email, String senha) async {
    if (contas.containsKey(email)) {
      throw const FalhaAuth(CodigoFalhaAuth.emailJaUsado);
    }
    if (senha.length < 8) throw const FalhaAuth(CodigoFalhaAuth.senhaFraca);
    final id = 'u${contas.length + 1}';
    contas[email] = (id: id, senha: senha);
    return _logado = id;
  }

  @override
  Future<Map<String, dynamic>?> buscarPerfil(String id) async => perfis[id];

  @override
  Future<Map<String, dynamic>?> buscarCatador(String id) async => catadores[id];

  @override
  Future<void> inserirPerfil(String id, Map<String, dynamic> perfil) async {
    if (falhaAoInserirPerfil != null) throw falhaAoInserirPerfil!;
    perfis[id] = {'id': id, ...perfil};
  }

  @override
  Future<void> inserirGerador(String id) async => geradores.add(id);

  @override
  Future<void> inserirCatador(String id, Map<String, dynamic> catador) async {
    // Imita o default do banco: nasce pendente.
    catadores[id] = {
      'perfil_id': id,
      'status_cadastro': 'pendente',
      ...catador,
    };
  }

  @override
  Future<void> cadastrarPonto(Map<String, dynamic> ponto) async {
    pontos.add(ponto);
    perfis[_logado!] = {'id': _logado, 'papel': 'ponto'};
  }

  @override
  Future<void> sair() async {
    sairChamadas++;
    _logado = null;
  }
}

void main() {
  late RemotoFake remoto;
  late AuthRepositorioImpl repo;

  setUp(() async {
    remoto = RemotoFake()
      ..semear('ger@x.dev', 'Kaptalixo#Dev1', 'g1', 'gerador')
      ..semear('cat@x.dev', 'Kaptalixo#Dev1', 'c1', 'catador')
      ..semear('pen@x.dev', 'Kaptalixo#Dev1', 'c2', 'catador')
      ..semear('adm@x.dev', 'Kaptalixo#Dev1', 'a1', 'admin');
    remoto.catadores['c1'] = {'status_cadastro': 'aprovado'};
    remoto.catadores['c2'] = {'status_cadastro': 'pendente'};
    repo = AuthRepositorioImpl(remoto);
  });

  tearDown(() => repo.fechar());

  group('entrar', () {
    test('papel vem de perfis', () async {
      final s = await repo.entrar(
        email: ' adm@x.dev ',
        senha: 'Kaptalixo#Dev1',
      );
      expect(s.papel, Papel.admin);
      expect(s.statusCadastro, isNull);
      expect(repo.atual, s);
    });

    test('catador traz status de catadores', () async {
      expect(
        (await repo.entrar(
          email: 'cat@x.dev',
          senha: 'Kaptalixo#Dev1',
        )).statusCadastro,
        StatusCadastro.aprovado,
      );
      expect(
        (await repo.entrar(
          email: 'pen@x.dev',
          senha: 'Kaptalixo#Dev1',
        )).catadorNaoAprovado,
        isTrue,
      );
    });

    test('senha errada lança credenciais inválidas e não loga', () async {
      await expectLater(
        repo.entrar(email: 'ger@x.dev', senha: 'errada123'),
        throwsA(
          isA<FalhaAuth>().having(
            (f) => f.codigo,
            'codigo',
            CodigoFalhaAuth.credenciaisInvalidas,
          ),
        ),
      );
      expect(repo.atual, isNull);
    });

    test('conta sem perfil: falha e encerra a sessão do Auth', () async {
      remoto.contas['orf@x.dev'] = (id: 'o1', senha: 'Kaptalixo#Dev1');
      await expectLater(
        repo.entrar(email: 'orf@x.dev', senha: 'Kaptalixo#Dev1'),
        throwsA(
          isA<FalhaAuth>().having(
            (f) => f.codigo,
            'codigo',
            CodigoFalhaAuth.perfilNaoEncontrado,
          ),
        ),
      );
      expect(remoto.sairChamadas, 1);
      expect(repo.atual, isNull);
    });

    test('emite a sessão em mudancas', () async {
      final futuro = repo.mudancas.first;
      await repo.entrar(email: 'ger@x.dev', senha: 'Kaptalixo#Dev1');
      expect((await futuro)?.papel, Papel.gerador);
    });
  });

  group('cadastrar', () {
    test('gerador cria perfil e gerador', () async {
      final s = await repo.cadastrar(
        const CadastroGerador(
          nome: 'Ana',
          email: 'ana@x.dev',
          senha: 'Senha1234',
          telefone: '11999990000',
        ),
      );
      expect(s.papel, Papel.gerador);
      expect(remoto.perfis[s.usuarioId]!['nome'], 'Ana');
      expect(remoto.perfis[s.usuarioId]!['telefone'], '11999990000');
      expect(remoto.geradores, [s.usuarioId]);
    });

    test('catador nasce pendente e grava campos do papel', () async {
      final s = await repo.cadastrar(
        const CadastroCatador(
          nome: 'Beto',
          email: 'beto@x.dev',
          senha: 'Senha1234',
          telefone: '11888880000',
          tipo: TipoCatador.empresa,
          documento: '12345678000199',
          razaoSocial: 'Beto Recicla',
          tipoVeiculo: 'utilitario',
          capacidadeSacos: 30,
        ),
      );
      expect(s.statusCadastro, StatusCadastro.pendente);
      expect(s.catadorNaoAprovado, isTrue);
      final linha = remoto.catadores[s.usuarioId]!;
      expect(linha['tipo'], 'empresa');
      expect(linha['razao_social'], 'Beto Recicla');
      expect(linha['capacidade_sacos'], 30);
      expect(linha.containsKey('status_cadastro'), isTrue);
    });

    test('catador não envia status_cadastro (só admin altera)', () {
      const c = CadastroCatador(
        nome: 'B',
        email: 'b@x.dev',
        senha: 'Senha1234',
        tipo: TipoCatador.pessoa,
        documento: '1',
        tipoVeiculo: 'bicicleta',
        capacidadeSacos: 5,
      );
      expect(c.catadorJson().containsKey('status_cadastro'), isFalse);
      expect(c.catadorJson().containsKey('razao_social'), isFalse);
    });

    test('ponto usa o RPC e carrega horário e preços', () async {
      final s = await repo.cadastrar(
        const CadastroPonto(
          nome: 'Dona Rita',
          email: 'rita@x.dev',
          senha: 'Senha1234',
          nomePonto: 'Ferro Velho Rita',
          logradouro: 'Rua A, 10',
          cidade: 'São Paulo',
          uf: 'SP',
          horarioAbertura: '08:00',
          horarioFechamento: '17:00',
          precosPorMaterial: {'pet': 2.5},
        ),
      );
      expect(s.papel, Papel.ponto);
      final p = remoto.pontos.single;
      expect(p['nome_ponto'], 'Ferro Velho Rita');
      expect(p['nome'], 'Dona Rita');
      expect(p['papel'], 'ponto');
      expect((p['precos'] as Map)['pet'], 2.5);
      expect((p['horario_funcionamento'] as Map)['seg'], [
        ['08:00', '17:00'],
      ]);
    });

    test('e-mail já usado', () async {
      await expectLater(
        repo.cadastrar(
          const CadastroGerador(
            nome: 'X',
            email: 'ger@x.dev',
            senha: 'Senha1234',
          ),
        ),
        throwsA(
          isA<FalhaAuth>().having(
            (f) => f.codigo,
            'codigo',
            CodigoFalhaAuth.emailJaUsado,
          ),
        ),
      );
      expect(repo.atual, isNull);
    });

    test('senha fraca', () async {
      await expectLater(
        repo.cadastrar(
          const CadastroGerador(nome: 'X', email: 'n@x.dev', senha: '123'),
        ),
        throwsA(
          isA<FalhaAuth>().having(
            (f) => f.codigo,
            'codigo',
            CodigoFalhaAuth.senhaFraca,
          ),
        ),
      );
    });

    test('falha ao gravar perfil desfaz a sessão do Auth', () async {
      remoto.falhaAoInserirPerfil = const FalhaAuth(
        CodigoFalhaAuth.desconhecida,
      );
      await expectLater(
        repo.cadastrar(
          const CadastroGerador(
            nome: 'X',
            email: 'n@x.dev',
            senha: 'Senha1234',
          ),
        ),
        throwsA(isA<FalhaAuth>()),
      );
      expect(remoto.sairChamadas, 1);
      expect(repo.atual, isNull);
    });
  });

  group('sessão', () {
    test('sair limpa a sessão e emite nulo', () async {
      await repo.entrar(email: 'ger@x.dev', senha: 'Kaptalixo#Dev1');
      final futuro = repo.mudancas.first;
      await repo.sair();
      expect(await futuro, isNull);
      expect(repo.atual, isNull);
    });

    test('sessão expirada no Auth derruba a sessão', () async {
      await repo.entrar(email: 'ger@x.dev', senha: 'Kaptalixo#Dev1');
      remoto.expirarSessao();
      await Future<void>.delayed(Duration.zero);
      expect(repo.atual, isNull);
    });

    test('restaurar recupera sessão existente', () async {
      remoto._logado = 'c2';
      final r = await AuthRepositorioImpl.restaurar(remoto);
      expect(r.atual?.papel, Papel.catador);
      expect(r.atual?.statusCadastro, StatusCadastro.pendente);
      await r.fechar();
    });

    test('restaurar sem perfil segue deslogado', () async {
      remoto._logado = 'sem-perfil';
      final r = await AuthRepositorioImpl.restaurar(remoto);
      expect(r.atual, isNull);
      await r.fechar();
    });
  });

  group('recarregar (P-013 item 5)', () {
    test('pendente aprovado pelo admin passa a aprovado e emite', () async {
      await repo.entrar(email: 'pen@x.dev', senha: 'Kaptalixo#Dev1');
      expect(repo.atual!.statusCadastro, StatusCadastro.pendente);
      expect(repo.atual!.podeFicarDisponivel, isFalse);
      final emitidas = <Object?>[];
      final sub = repo.mudancas.listen(emitidas.add);
      remoto.catadores['c2'] = {'status_cadastro': 'aprovado'};
      final s = await repo.recarregar();
      await Future<void>.delayed(Duration.zero);
      expect(s!.statusCadastro, StatusCadastro.aprovado);
      expect(s.podeFicarDisponivel, isTrue);
      expect(emitidas, hasLength(1));
      await sub.cancel();
    });

    test('sem mudança não emite; deslogado devolve nulo', () async {
      expect(await repo.recarregar(), isNull);
      await repo.entrar(email: 'pen@x.dev', senha: 'Kaptalixo#Dev1');
      final emitidas = <Object?>[];
      final sub = repo.mudancas.listen(emitidas.add);
      await repo.recarregar();
      await Future<void>.delayed(Duration.zero);
      expect(emitidas, isEmpty);
      await sub.cancel();
    });
  });
}
