/// Falha ao carregar dados do gerador.
class FalhaGerador implements Exception {
  const FalhaGerador([this.mensagem = 'Não foi possível carregar os dados.']);

  final String mensagem;

  @override
  String toString() => 'FalhaGerador: $mensagem';
}
