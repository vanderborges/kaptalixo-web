import 'dart:async';

import '../dominio/falha_catador.dart';
import '../dominio/rota_ativa.dart';
import '../dominio/rota_repositorio.dart';
import 'rota_remoto.dart';

class RotaRepositorioImpl implements RotaRepositorio {
  RotaRepositorioImpl(this._remoto);

  final RotaRemoto _remoto;

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
  Future<String?> rotaAbertaId() => _protegido(_remoto.rotaAbertaId);

  @override
  Future<RotaAtiva?> carregar(String rotaId) => _protegido(() async {
    final snap = await _remoto.buscarRota(rotaId);
    return snap == null ? null : RotaAtiva.deSnapshot(snap);
  });

  @override
  Stream<RotaAtiva?> observar(String rotaId) {
    late final StreamController<RotaAtiva?> ctrl;
    StreamSubscription<void>? sub;
    var carregando = false;
    var pendente = false;
    Timer? agendado;

    Future<void> atualizar() async {
      if (carregando) {
        pendente = true; // coalesce rajadas de eventos Realtime
        return;
      }
      carregando = true;
      try {
        do {
          pendente = false;
          final r = await carregar(rotaId);
          if (!ctrl.isClosed) ctrl.add(r);
        } while (pendente && !ctrl.isClosed);
      } catch (e, st) {
        if (!ctrl.isClosed) ctrl.addError(e, st);
      } finally {
        carregando = false;
      }
    }

    ctrl = StreamController<RotaAtiva?>(
      onListen: () {
        sub = _remoto.mudancas(rotaId).listen((_) {
          // Rajada de eventos vira uma única recarga.
          if (agendado?.isActive ?? false) return;
          agendado = Timer(Duration.zero, atualizar);
        });
        atualizar();
      },
      onCancel: () {
        agendado?.cancel();
        return sub?.cancel();
      },
    );
    return ctrl.stream;
  }

  @override
  Future<void> iniciar(String rotaId) =>
      _protegido(() => _remoto.iniciarRota(rotaId));

  @override
  Future<ResultadoParada> avancarParada(
    String paradaId,
    AcaoParada acao, {
    String? pin,
    String? motivo,
  }) => _protegido(() async {
    final json = await _remoto.avancarParada(
      paradaId,
      acao.codigo,
      pin: pin,
      motivo: motivo,
    );
    return ResultadoParada.deJson(json);
  });

  @override
  Future<void> trocarPonto(String rotaId, String pontoId) =>
      _protegido(() => _remoto.trocarPonto(rotaId, pontoId));

  @override
  Future<void> atualizarLocalizacao(double lat, double lng, String rotaId) =>
      _protegido(() => _remoto.atualizarLocalizacao(lat, lng, rotaId));
}
