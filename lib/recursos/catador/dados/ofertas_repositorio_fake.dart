import 'dart:async';

import '../dominio/falha_catador.dart';
import '../dominio/oferta_resumo.dart';
import '../dominio/ofertas_repositorio.dart';

/// Fake em memória: [emitir] simula o Realtime; registra as chamadas.
class OfertasRepositorioFake implements OfertasRepositorio {
  OfertasRepositorioFake({
    List<OfertaResumo> inicial = const [],
    this.falhaAceitar,
    this.falhaRecusar,
    this.rotaId = 'rota-1',
  }) : _atual = List.of(inicial);

  List<OfertaResumo> _atual;
  FalhaCatador? falhaAceitar;
  FalhaCatador? falhaRecusar;
  final String rotaId;

  final List<String> aceitas = [];
  final List<String> recusadas = [];
  int chamadasExpirar = 0;
  int assinaturas = 0;
  int cancelamentos = 0;

  final _ctrl = StreamController<List<OfertaResumo>>.broadcast();

  /// Publica nova lista de ofertas pendentes.
  void emitir(List<OfertaResumo> ofertas) {
    _atual = List.of(ofertas);
    _ctrl.add(List.of(_atual));
  }

  void emitirErro(FalhaCatador f) => _ctrl.addError(f);

  @override
  Stream<List<OfertaResumo>> observar() {
    late final StreamController<List<OfertaResumo>> c;
    StreamSubscription<List<OfertaResumo>>? sub;
    c = StreamController<List<OfertaResumo>>(
      onListen: () {
        assinaturas++;
        c.add(List.of(_atual));
        sub = _ctrl.stream.listen(c.add, onError: c.addError);
      },
      onCancel: () {
        cancelamentos++;
        return sub?.cancel();
      },
    );
    return c.stream;
  }

  @override
  Future<String> aceitar(String ofertaId) async {
    aceitas.add(ofertaId);
    if (falhaAceitar != null) throw falhaAceitar!;
    _atual = _atual.where((o) => o.ofertaId != ofertaId).toList();
    return rotaId;
  }

  @override
  Future<void> recusar(String ofertaId) async {
    recusadas.add(ofertaId);
    if (falhaRecusar != null) throw falhaRecusar!;
    _atual = _atual.where((o) => o.ofertaId != ofertaId).toList();
  }

  @override
  Future<int> expirar() async {
    chamadasExpirar++;
    return 0;
  }
}
