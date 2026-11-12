import 'falha_auth.dart';

final _regexEmail = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// Retorna a mensagem de erro, ou nulo se válido.
String? validarEmail(String? valor) {
  final v = valor?.trim() ?? '';
  if (v.isEmpty) return 'Informe o e-mail.';
  if (!_regexEmail.hasMatch(v)) return 'E-mail inválido.';
  return null;
}

String? validarSenha(String? valor) {
  final v = valor ?? '';
  if (v.isEmpty) return 'Informe a senha.';
  if (v.length < tamanhoMinimoSenha) {
    return 'Senha fraca: use ao menos $tamanhoMinimoSenha caracteres.';
  }
  return null;
}

String? validarObrigatorio(String? valor, String campo) =>
    (valor == null || valor.trim().isEmpty) ? 'Informe $campo.' : null;

String? validarCapacidade(String? valor) {
  final n = int.tryParse((valor ?? '').trim());
  if (n == null || n <= 0) return 'Informe um número de sacos maior que zero.';
  return null;
}

String? validarHorario(String? valor) {
  final v = (valor ?? '').trim();
  if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(v)) {
    return 'Use o formato HH:mm.';
  }
  return null;
}

/// Preço é opcional; vazio é válido.
String? validarPreco(String? valor) {
  final v = (valor ?? '').trim();
  if (v.isEmpty) return null;
  final n = double.tryParse(v.replaceAll(',', '.'));
  if (n == null || n < 0) return 'Preço inválido.';
  return null;
}
