import 'package:latlong2/latlong.dart';

import '../dominio/demo.dart';
import '../dominio/demo_repositorio.dart';
import '../dominio/falha_admin.dart';
import 'demo_remoto.dart';

class DemoRepositorioImpl implements DemoRepositorio {
  DemoRepositorioImpl(this._remoto, {DateTime Function()? relogio})
    : _relogio = relogio ?? DateTime.now;

  final DemoRemoto _remoto;
  final DateTime Function() _relogio;

  static const maxCatadores = 20;

  @override
  Future<SnapshotDemo> carregar() async {
    final json = await _remoto.snapshot();
    try {
      return SnapshotDemo.fromJson(json);
    } on FormatException {
      throw const FalhaAdmin(CodigoFalhaAdmin.desconhecida);
    } on TypeError {
      throw const FalhaAdmin(CodigoFalhaAdmin.desconhecida);
    }
  }

  @override
  Future<int> criarCatadores(int quantidade) {
    if (quantidade < 1 || quantidade > maxCatadores) {
      throw const FalhaAdmin(CodigoFalhaAdmin.parametroInvalido);
    }
    return _remoto.criarCatadores(quantidade);
  }

  @override
  Future<String> criarPedido() => _remoto.criarPedido();

  @override
  Future<Duration> resetar() async {
    final inicio = _relogio();
    await _remoto.resetar();
    return _relogio().difference(inicio);
  }

  @override
  Future<void> moverCatador(String catadorId, LatLng posicao) =>
      _remoto.moverCatador(catadorId, posicao.latitude, posicao.longitude);
}
