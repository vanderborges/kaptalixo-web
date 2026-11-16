enum MotivoFalhaLocalizacao {
  servicoDesligado,
  permissaoNegada,
  permissaoNegadaParaSempre,
  indisponivel,
}

/// Falha tipada de localizacao. O gerador deve pedir endereco manual.
class FalhaLocalizacao implements Exception {
  const FalhaLocalizacao(this.motivo, [this.mensagem]);

  final MotivoFalhaLocalizacao motivo;
  final String? mensagem;

  /// A UI deve oferecer digitar o endereco manualmente.
  bool get pedirEnderecoManual => true;

  @override
  String toString() =>
      'FalhaLocalizacao($motivo${mensagem == null ? '' : ': $mensagem'})';
}
