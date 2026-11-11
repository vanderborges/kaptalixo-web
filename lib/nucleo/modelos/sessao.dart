import 'papel.dart';

/// Sessão do usuário autenticado. Sessão nula = deslogado.
class Sessao {
  const Sessao({required this.usuarioId, required this.papel});

  factory Sessao.fromJson(Map<String, dynamic> json) => Sessao(
    usuarioId: json['usuario_id'] as String,
    papel: Papel.deTexto(json['papel'] as String),
  );

  final String usuarioId;
  final Papel papel;

  Map<String, dynamic> toJson() => {
    'usuario_id': usuarioId,
    'papel': papel.paraTexto(),
  };

  @override
  bool operator ==(Object other) =>
      other is Sessao && other.usuarioId == usuarioId && other.papel == papel;

  @override
  int get hashCode => Object.hash(usuarioId, papel);
}
