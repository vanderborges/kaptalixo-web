import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'falha_localizacao.dart';
import 'posicao.dart';
import 'servico_localizacao.dart';

/// Porta fina sobre o plugin geolocator (permite testar sem plataforma).
abstract interface class PlataformaGps {
  Future<bool> servicoAtivo();
  Future<LocationPermission> permissao();
  Future<LocationPermission> solicitarPermissao();
  Future<Position> posicaoAtual();
  Stream<Position> fluxo(int filtroDistanciaMetros);
}

class PlataformaGpsGeolocator implements PlataformaGps {
  const PlataformaGpsGeolocator();

  @override
  Future<bool> servicoAtivo() => Geolocator.isLocationServiceEnabled();
  @override
  Future<LocationPermission> permissao() => Geolocator.checkPermission();
  @override
  Future<LocationPermission> solicitarPermissao() =>
      Geolocator.requestPermission();
  @override
  Future<Position> posicaoAtual() => Geolocator.getCurrentPosition();
  @override
  Stream<Position> fluxo(int filtroDistanciaMetros) =>
      Geolocator.getPositionStream(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: filtroDistanciaMetros,
        ),
      );
}

class LocalizacaoGps implements ServicoLocalizacao {
  LocalizacaoGps({
    PlataformaGps plataforma = const PlataformaGpsGeolocator(),
    this.filtroDistanciaMetros = 5,
  }) : _gps = plataforma;

  final PlataformaGps _gps;
  final int filtroDistanciaMetros;

  Future<void> _garantirAcesso() async {
    if (!await _gps.servicoAtivo()) {
      throw const FalhaLocalizacao(MotivoFalhaLocalizacao.servicoDesligado);
    }
    var p = await _gps.permissao();
    if (p == LocationPermission.denied) {
      p = await _gps.solicitarPermissao();
    }
    if (p == LocationPermission.deniedForever) {
      throw const FalhaLocalizacao(
        MotivoFalhaLocalizacao.permissaoNegadaParaSempre,
      );
    }
    if (p == LocationPermission.denied ||
        p == LocationPermission.unableToDetermine) {
      throw const FalhaLocalizacao(MotivoFalhaLocalizacao.permissaoNegada);
    }
  }

  Posicao _converter(Position p) => Posicao(
    ponto: LatLng(p.latitude, p.longitude),
    instante: p.timestamp,
    precisaoMetros: p.accuracy,
  );

  @override
  Future<Posicao> atual() async {
    await _garantirAcesso();
    return _converter(await _gps.posicaoAtual());
  }

  @override
  Stream<Posicao> posicoes() async* {
    await _garantirAcesso();
    yield* _gps.fluxo(filtroDistanciaMetros).map(_converter);
  }
}
