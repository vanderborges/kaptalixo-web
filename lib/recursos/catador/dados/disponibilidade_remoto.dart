/// Acesso bruto às RPCs de disponibilidade/posição.
abstract class DisponibilidadeRemoto {
  /// `catadores.situacao` do usuário logado (texto do enum).
  Future<String> situacaoAtual();

  /// RPC `alternar_disponibilidade(p_disponivel)`; devolve o enum em texto.
  Future<String> alternar(bool disponivel);

  /// RPC `atualizar_localizacao(p_lat, p_lng)`.
  Future<void> atualizarLocalizacao(double lat, double lng);
}
