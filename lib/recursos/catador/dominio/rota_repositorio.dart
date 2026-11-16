import 'rota_ativa.dart';

/// Rota ativa do catador (UC08): leitura em tempo real e ações da rota.
abstract class RotaRepositorio {
  /// Id da rota aberta (planejada/em andamento) do catador, se houver.
  Future<String?> rotaAbertaId();

  /// Retrato atual da rota; nulo se não existe. Lança `FalhaCatador`.
  Future<RotaAtiva?> carregar(String rotaId);

  /// Emite o retrato agora e a cada mudança (Realtime). Erros como
  /// `FalhaCatador` no stream.
  Stream<RotaAtiva?> observar(String rotaId);

  /// RPC `iniciar_rota`.
  Future<void> iniciar(String rotaId);

  /// RPC `avancar_parada`. PIN errado/bloqueado volta como resultado, não
  /// como exceção. O PIN é o informado pelo gerador (o catador nunca o lê).
  Future<ResultadoParada> avancarParada(
    String paradaId,
    AcaoParada acao, {
    String? pin,
    String? motivo,
  });

  /// RPC `trocar_ponto_destino`.
  Future<void> trocarPonto(String rotaId, String pontoId);

  /// RPC `atualizar_localizacao` informando a rota.
  Future<void> atualizarLocalizacao(double lat, double lng, String rotaId);
}
