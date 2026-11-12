import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import 'haversine.dart';
import 'polyline.dart';
import 'rota_calculada.dart';
import 'servico_rotas.dart';

/// Implementacao OSRM. [urlBase] vem da configuracao (nunca fixa no codigo).
class ServicoRotasOsrm implements ServicoRotas {
  ServicoRotasOsrm({
    required String urlBase,
    Dio? dio,
    this.timeout = const Duration(seconds: 4),
    this.velocidadeFallbackKmh = 20,
    this.tamanhoMaximoCache = 100,
  }) : _dio = dio ?? Dio(),
       _urlBase = urlBase.endsWith('/')
           ? urlBase.substring(0, urlBase.length - 1)
           : urlBase;

  final Dio _dio;
  final String _urlBase;
  final Duration timeout;
  final double velocidadeFallbackKmh;
  final int tamanhoMaximoCache;
  final Map<String, RotaCalculada> _cache = {};

  double get _velocidadeMs => velocidadeFallbackKmh / 3.6;

  static String _coords(List<LatLng> p) =>
      p.map((c) => '${c.longitude},${c.latitude}').join(';');

  /// GET com timeout e 1 retry (2 tentativas); 4xx nao repete.
  Future<Map<String, dynamic>> _obter(
    String caminho,
    Map<String, String> query,
  ) async {
    Object? ultimoErro;
    for (var tentativa = 0; tentativa < 2; tentativa++) {
      try {
        final r = await _dio.get<dynamic>(
          '$_urlBase/$caminho',
          queryParameters: query,
          options: Options(
            sendTimeout: timeout,
            receiveTimeout: timeout,
            responseType: ResponseType.json,
          ),
        );
        final dados = r.data;
        if (dados is Map<String, dynamic> && dados['code'] == 'Ok') {
          return dados;
        }
        throw const FormatException('Resposta OSRM invalida');
      } on DioException catch (e) {
        ultimoErro = e;
        final s = e.response?.statusCode;
        if (s != null && s >= 400 && s < 500) break;
      } on FormatException catch (e) {
        ultimoErro = e;
        break;
      }
    }
    throw ultimoErro!;
  }

  @override
  Future<RotaCalculada> calcular(
    LatLng origem,
    List<LatLng> paradas,
    LatLng destino,
  ) async {
    final chave = _coords([origem, ...paradas, destino]);
    final emCache = _cache[chave];
    if (emCache != null) return emCache;
    try {
      final rota = paradas.isEmpty
          ? await _route(origem, destino)
          : await _trip(origem, paradas, destino);
      if (_cache.length >= tamanhoMaximoCache) {
        _cache.remove(_cache.keys.first);
      }
      _cache[chave] = rota;
      return rota;
    } catch (_) {
      return _fallback(origem, paradas, destino);
    }
  }

  Future<RotaCalculada> _route(LatLng origem, LatLng destino) async {
    final d = await _obter('route/v1/driving/${_coords([origem, destino])}', {
      'overview': 'full',
      'geometries': 'polyline',
    });
    final r = (d['routes'] as List).first as Map<String, dynamic>;
    return RotaCalculada(
      distanciaMetros: (r['distance'] as num).toDouble(),
      duracaoSegundos: (r['duration'] as num).toDouble(),
      geometria: decodificarPolyline(r['geometry'] as String),
      ordemParadas: const [],
      origemCalculo: OrigemCalculo.osrm,
    );
  }

  Future<RotaCalculada> _trip(
    LatLng origem,
    List<LatLng> paradas,
    LatLng destino,
  ) async {
    final pontos = [origem, ...paradas, destino];
    final d = await _obter('trip/v1/driving/${_coords(pontos)}', {
      'source': 'first',
      'destination': 'last',
      'roundtrip': 'false',
      'overview': 'full',
      'geometries': 'polyline',
    });
    final t = (d['trips'] as List).first as Map<String, dynamic>;
    final wps = d['waypoints'] as List;
    if (wps.length != pontos.length) {
      throw const FormatException('waypoints inconsistentes');
    }
    // waypoint_index = posicao do ponto de entrada i dentro da viagem.
    final indices = List<int>.generate(paradas.length, (i) => i + 1);
    indices.sort(
      (a, b) => ((wps[a] as Map)['waypoint_index'] as int).compareTo(
        (wps[b] as Map)['waypoint_index'] as int,
      ),
    );
    return RotaCalculada(
      distanciaMetros: (t['distance'] as num).toDouble(),
      duracaoSegundos: (t['duration'] as num).toDouble(),
      geometria: decodificarPolyline(t['geometry'] as String),
      ordemParadas: [for (final i in indices) i - 1],
      origemCalculo: OrigemCalculo.osrm,
    );
  }

  RotaCalculada _fallback(LatLng origem, List<LatLng> paradas, LatLng destino) {
    final ordem = ordemVizinhoMaisProximo(origem, paradas);
    final geo = [origem, for (final i in ordem) paradas[i], destino];
    var dist = 0.0;
    for (var i = 1; i < geo.length; i++) {
      dist += distanciaHaversineMetros(geo[i - 1], geo[i]);
    }
    return RotaCalculada(
      distanciaMetros: dist,
      duracaoSegundos: dist / _velocidadeMs,
      geometria: geo,
      ordemParadas: ordem,
      origemCalculo: OrigemCalculo.haversine,
    );
  }

  @override
  Future<double> duracaoAte(LatLng origem, LatLng destino) async {
    try {
      return (await _route(origem, destino)).duracaoSegundos;
    } catch (_) {
      return distanciaHaversineMetros(origem, destino) / _velocidadeMs;
    }
  }

  @override
  Future<List<List<double>>> matrizDuracoes(List<LatLng> pontos) async {
    try {
      final d = await _obter('table/v1/driving/${_coords(pontos)}', {
        'annotations': 'duration',
      });
      return [
        for (final linha in d['durations'] as List)
          [
            for (final v in linha as List)
              ((v as num?) ?? double.infinity).toDouble(),
          ],
      ];
    } catch (_) {
      return [
        for (final a in pontos)
          [
            for (final b in pontos)
              distanciaHaversineMetros(a, b) / _velocidadeMs,
          ],
      ];
    }
  }
}
