import 'package:latlong2/latlong.dart';

import '../dominio/disponibilidade_repositorio.dart';
import '../dominio/falha_catador.dart';
import '../dominio/situacao_catador.dart';

/// Fake: guarda a situação em memória e registra as posições enviadas.
class DisponibilidadeRepositorioFake implements DisponibilidadeRepositorio {
  DisponibilidadeRepositorioFake({
    this.situacao = SituacaoCatador.offline,
    this.aprovado = true,
    this.falhaAlternar,
    this.falhaPosicao,
  });

  SituacaoCatador situacao;

  /// Simula RN10 no servidor.
  bool aprovado;
  FalhaCatador? falhaAlternar;
  FalhaCatador? falhaPosicao;
  int chamadasAlternar = 0;
  final List<LatLng> posicoesEnviadas = [];

  @override
  Future<SituacaoCatador> situacaoAtual() async => situacao;

  @override
  Future<SituacaoCatador> alternar(bool disponivel) async {
    chamadasAlternar++;
    if (falhaAlternar != null) throw falhaAlternar!;
    if (disponivel && !aprovado) {
      throw const FalhaCatador(MotivoFalhaCatador.cadastroNaoAprovado);
    }
    situacao = disponivel
        ? SituacaoCatador.disponivel
        : SituacaoCatador.offline;
    return situacao;
  }

  @override
  Future<void> atualizarLocalizacao(double lat, double lng) async {
    if (falhaPosicao != null) throw falhaPosicao!;
    posicoesEnviadas.add(LatLng(lat, lng));
  }
}
