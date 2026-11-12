import 'papel.dart';
import 'status_cadastro.dart';

/// Sessão do usuário autenticado. Sessão nula = deslogado.
class Sessao {
  const Sessao({
    required this.usuarioId,
    required this.papel,
    this.statusCadastro,
  });

  /// JSON interno do app (não é o formato da tabela `perfis`; lá o id é `id`).
  factory Sessao.fromJson(Map<String, dynamic> json) => Sessao(
    usuarioId: json['usuario_id'] as String,
    papel: Papel.deTexto(json['papel'] as String),
    statusCadastro: json['status_cadastro'] == null
        ? null
        : StatusCadastro.deTexto(json['status_cadastro'] as String),
  );

  final String usuarioId;
  final Papel papel;

  /// Só preenchido para catador (`catadores.status_cadastro`).
  final StatusCadastro? statusCadastro;

  /// Catador cujo cadastro ainda não foi aprovado (pendente ou suspenso).
  bool get catadorNaoAprovado =>
      papel == Papel.catador &&
      statusCadastro != null &&
      statusCadastro != StatusCadastro.aprovado;

  /// RN10: só catador `aprovado` pode ficar disponível / receber ofertas.
  bool get podeFicarDisponivel =>
      papel == Papel.catador && statusCadastro == StatusCadastro.aprovado;

  Map<String, dynamic> toJson() => {
    'usuario_id': usuarioId,
    'papel': papel.paraTexto(),
    if (statusCadastro != null) 'status_cadastro': statusCadastro!.paraTexto(),
  };

  @override
  bool operator ==(Object other) =>
      other is Sessao &&
      other.usuarioId == usuarioId &&
      other.papel == papel &&
      other.statusCadastro == statusCadastro;

  @override
  int get hashCode => Object.hash(usuarioId, papel, statusCadastro);
}
