import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/nucleo/modelos/papel.dart';
import 'package:kaptalixo/nucleo/modelos/sessao.dart';
import 'package:kaptalixo/nucleo/modelos/status_cadastro.dart';
import 'package:kaptalixo/recursos/auth/dominio/validadores.dart';

void main() {
  test('validarEmail', () {
    expect(validarEmail(''), isNotNull);
    expect(validarEmail('sem-arroba'), 'E-mail inválido.');
    expect(validarEmail('a@b'), isNotNull);
    expect(validarEmail('a@b.com'), isNull);
    expect(validarEmail(' a@b.com '), isNull);
  });

  test('validarSenha exige 8 caracteres', () {
    expect(validarSenha(''), isNotNull);
    expect(validarSenha('1234567'), contains('fraca'));
    expect(validarSenha('12345678'), isNull);
  });

  test('capacidade, horário e preço', () {
    expect(validarCapacidade('0'), isNotNull);
    expect(validarCapacidade('abc'), isNotNull);
    expect(validarCapacidade('10'), isNull);
    expect(validarHorario('8:00'), isNotNull);
    expect(validarHorario('25:00'), isNotNull);
    expect(validarHorario('08:30'), isNull);
    expect(validarPreco(''), isNull);
    expect(validarPreco('2,5'), isNull);
    expect(validarPreco('-1'), isNotNull);
    expect(validarPreco('x'), isNotNull);
  });

  test('Sessao: json e catadorNaoAprovado', () {
    const s = Sessao(
      usuarioId: 'u',
      papel: Papel.catador,
      statusCadastro: StatusCadastro.pendente,
    );
    expect(Sessao.fromJson(s.toJson()), s);
    expect(s.catadorNaoAprovado, isTrue);
    expect(
      const Sessao(usuarioId: 'u', papel: Papel.gerador).catadorNaoAprovado,
      isFalse,
    );
    expect(
      const Sessao(
        usuarioId: 'u',
        papel: Papel.catador,
        statusCadastro: StatusCadastro.aprovado,
      ).catadorNaoAprovado,
      isFalse,
    );
  });
}
