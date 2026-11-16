import 'dart:async';

import '../dominio/falha_catador.dart';
import '../dominio/oferta_resumo.dart';
import '../dominio/ofertas_repositorio.dart';
import 'ofertas_remoto.dart';

class OfertasRepositorioImpl implements OfertasRepositorio {
  OfertasRepositorioImpl(this._remoto);

  final OfertasRemoto _remoto;

  Future<T> _protegido<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on FalhaCatador {
      rethrow;
    } catch (_) {
      throw const FalhaCatador(MotivoFalhaCatador.generico);
    }
  }

  Future<List<OfertaResumo>> _carregar() => _protegido(() async {
    final linhas = await _remoto.buscarPendentes();
    return [for (final l in linhas) OfertaResumo.deLinha(l)];
  });

  @override
  Stream<List<OfertaResumo>> observar() {
    late final StreamController<List<OfertaResumo>> ctrl;
    StreamSubscription<void>? sub;
    var carregando = false;
    var pendente = false;

    Future<void> atualizar() async {
      if (carregando) {
        pendente = true; // coalesce rajadas de eventos Realtime
        return;
      }
      carregando = true;
      try {
        do {
          pendente = false;
          final r = await _carregar();
          if (!ctrl.isClosed) ctrl.add(r);
        } while (pendente && !ctrl.isClosed);
      } catch (e, st) {
        if (!ctrl.isClosed) ctrl.addError(e, st);
      } finally {
        carregando = false;
      }
    }

    ctrl = StreamController<List<OfertaResumo>>(
      onListen: () {
        sub = _remoto.mudancas().listen((_) => atualizar());
        atualizar();
      },
      onCancel: () => sub?.cancel(),
    );
    return ctrl.stream;
  }

  @override
  Future<String> aceitar(String ofertaId) =>
      _protegido(() => _remoto.aceitar(ofertaId));

  @override
  Future<void> recusar(String ofertaId) =>
      _protegido(() => _remoto.recusar(ofertaId));

  @override
  Future<int> expirar() => _protegido(() => _remoto.expirar());
}
