import 'dart:async';

import '../dominio/entrega_a_caminho.dart';
import '../dominio/falha_ponto.dart';
import '../dominio/ponto_repositorio.dart';
import 'ponto_remoto.dart';

class PontoRepositorioImpl implements PontoRepositorio {
  PontoRepositorioImpl(this._remoto);

  final PontoRemoto _remoto;

  Future<T> _protegido<T>(Future<T> Function() acao) async {
    try {
      return await acao();
    } on FalhaPonto {
      rethrow;
    } catch (_) {
      throw const FalhaPonto(MotivoFalhaPonto.generico);
    }
  }

  Future<List<EntregaACaminho>> _carregar() => _protegido(() async {
    final linhas = await _remoto.entregasACaminho();
    final lista = linhas.map(EntregaACaminho.fromJson).toList();
    lista.sort((a, b) {
      if (a.eta == null && b.eta == null) return 0;
      if (a.eta == null) return 1;
      if (b.eta == null) return -1;
      return a.eta!.compareTo(b.eta!);
    });
    return lista;
  });

  @override
  Stream<List<EntregaACaminho>> observarEntregas() {
    late final StreamController<List<EntregaACaminho>> ctrl;
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
          final l = await _carregar();
          if (!ctrl.isClosed) ctrl.add(l);
        } while (pendente && !ctrl.isClosed);
      } catch (e, st) {
        if (!ctrl.isClosed) ctrl.addError(e, st);
      } finally {
        carregando = false;
      }
    }

    ctrl = StreamController<List<EntregaACaminho>>(
      onListen: () {
        sub = _remoto.mudancas().listen((_) => atualizar());
        atualizar();
      },
      onCancel: () async {
        await sub?.cancel();
      },
    );
    return ctrl.stream;
  }

  @override
  Future<String> confirmarEntrega(String rotaId) =>
      _protegido(() => _remoto.confirmarEntrega(rotaId));
}
