import '../dominio/disponibilidade_repositorio.dart';
import '../dominio/falha_catador.dart';
import '../dominio/situacao_catador.dart';
import 'disponibilidade_remoto.dart';

class DisponibilidadeRepositorioImpl implements DisponibilidadeRepositorio {
  DisponibilidadeRepositorioImpl(this._remoto);

  final DisponibilidadeRemoto _remoto;

  Future<T> _protegido<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on FalhaCatador {
      rethrow;
    } catch (_) {
      throw const FalhaCatador(MotivoFalhaCatador.generico);
    }
  }

  @override
  Future<SituacaoCatador> situacaoAtual() => _protegido(
    () async => SituacaoCatador.deTexto(await _remoto.situacaoAtual()),
  );

  @override
  Future<SituacaoCatador> alternar(bool disponivel) => _protegido(
    () async => SituacaoCatador.deTexto(await _remoto.alternar(disponivel)),
  );

  @override
  Future<void> atualizarLocalizacao(double lat, double lng) =>
      _protegido(() => _remoto.atualizarLocalizacao(lat, lng));
}
