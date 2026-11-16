import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/recursos/catador/dados/disponibilidade_remoto.dart';
import 'package:kaptalixo/recursos/catador/dados/disponibilidade_repositorio_impl.dart';
import 'package:kaptalixo/recursos/catador/dominio/falha_catador.dart';
import 'package:kaptalixo/recursos/catador/dominio/situacao_catador.dart';

class _Remoto implements DisponibilidadeRemoto {
  Object? erro;
  String resposta = 'disponivel';
  (double, double)? ultima;

  @override
  Future<String> alternar(bool disponivel) async {
    if (erro != null) throw erro!;
    return resposta;
  }

  @override
  Future<void> atualizarLocalizacao(double lat, double lng) async {
    if (erro != null) throw erro!;
    ultima = (lat, lng);
  }

  @override
  Future<String> situacaoAtual() async => resposta;
}

void main() {
  test('converte o enum do banco', () async {
    final r = _Remoto()..resposta = 'em_rota';
    final repo = DisponibilidadeRepositorioImpl(r);
    expect(await repo.situacaoAtual(), SituacaoCatador.emRota);
    r.resposta = 'disponivel';
    expect(await repo.alternar(true), SituacaoCatador.disponivel);
  });

  test('envia lat/lng', () async {
    final r = _Remoto();
    await DisponibilidadeRepositorioImpl(r).atualizarLocalizacao(1, 2);
    expect(r.ultima, (1.0, 2.0));
  });

  test('erro desconhecido vira falha genérica; FalhaCatador passa', () async {
    final r = _Remoto()..erro = StateError('x');
    final repo = DisponibilidadeRepositorioImpl(r);
    await expectLater(
      repo.alternar(true),
      throwsA(
        isA<FalhaCatador>().having(
          (f) => f.motivo,
          'motivo',
          MotivoFalhaCatador.generico,
        ),
      ),
    );
    r.erro = const FalhaCatador(MotivoFalhaCatador.emRota);
    await expectLater(
      repo.alternar(false),
      throwsA(
        isA<FalhaCatador>().having(
          (f) => f.motivo,
          'motivo',
          MotivoFalhaCatador.emRota,
        ),
      ),
    );
  });

  test('mapeia códigos estáveis do servidor', () {
    expect(
      MotivoFalhaCatador.deCodigo('cadastro_nao_aprovado'),
      MotivoFalhaCatador.cadastroNaoAprovado,
    );
    expect(
      MotivoFalhaCatador.deCodigo('catador_em_rota'),
      MotivoFalhaCatador.emRota,
    );
    expect(
      MotivoFalhaCatador.deCodigo('catador_indisponivel'),
      MotivoFalhaCatador.indisponivel,
    );
    expect(MotivoFalhaCatador.deCodigo(null), MotivoFalhaCatador.generico);
  });
}
