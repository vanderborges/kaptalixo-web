import 'dart:async';

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

import 'servico_geocodificacao.dart';

/// Nominatim: User-Agent proprio, max 1 req/s, cache em memoria.
class ServicoGeocodificacaoNominatim implements ServicoGeocodificacao {
  ServicoGeocodificacaoNominatim({
    required String urlBase,
    this.userAgent = 'KaptalixoPOC/1.0',
    Dio? dio,
    this.timeout = const Duration(seconds: 4),
    this.intervaloMinimo = const Duration(seconds: 1),
    DateTime Function()? agora,
    Future<void> Function(Duration)? esperar,
  }) : _dio = dio ?? Dio(),
       _urlBase = urlBase.endsWith('/')
           ? urlBase.substring(0, urlBase.length - 1)
           : urlBase,
       _agora = agora ?? DateTime.now,
       _esperar = esperar ?? ((d) => Future<void>.delayed(d));

  final Dio _dio;
  final String _urlBase;
  final String userAgent;
  final Duration timeout;
  final Duration intervaloMinimo;
  final DateTime Function() _agora;
  final Future<void> Function(Duration) _esperar;

  final Map<String, Object?> _cache = {};
  DateTime? _ultimaRequisicao;
  Future<void> _fila = Future<void>.value();

  /// Serializa as requisicoes respeitando o intervalo minimo.
  Future<T> _limitado<T>(Future<T> Function() acao) {
    final c = Completer<T>();
    _fila = _fila.then((_) async {
      final ultima = _ultimaRequisicao;
      if (ultima != null) {
        final falta = intervaloMinimo - _agora().difference(ultima);
        if (falta > Duration.zero) await _esperar(falta);
      }
      _ultimaRequisicao = _agora();
      try {
        c.complete(await acao());
      } catch (e, s) {
        c.completeError(e, s);
      }
    });
    return c.future;
  }

  Future<dynamic> _obter(String caminho, Map<String, String> query) async {
    Object? erro;
    for (var tentativa = 0; tentativa < 2; tentativa++) {
      try {
        final r = await _limitado(
          () => _dio.get<dynamic>(
            '$_urlBase/$caminho',
            queryParameters: {...query, 'format': 'jsonv2'},
            options: Options(
              headers: {'User-Agent': userAgent},
              sendTimeout: timeout,
              receiveTimeout: timeout,
              responseType: ResponseType.json,
            ),
          ),
        );
        return r.data;
      } on DioException catch (e) {
        erro = e;
        final s = e.response?.statusCode;
        if (s != null && s >= 400 && s < 500) break;
      }
    }
    throw ExcecaoGeocodificacao('Falha ao consultar Nominatim: $erro');
  }

  ResultadoGeocodificacao _item(Map<String, dynamic> m) =>
      ResultadoGeocodificacao(
        nome: (m['display_name'] as String?) ?? '',
        posicao: LatLng(
          double.parse('${m['lat']}'),
          double.parse('${m['lon']}'),
        ),
      );

  @override
  Future<List<ResultadoGeocodificacao>> buscar(String texto) async {
    final q = texto.trim();
    if (q.isEmpty) return const [];
    final chave = 'b:${q.toLowerCase()}';
    final c = _cache[chave];
    if (c != null) return c as List<ResultadoGeocodificacao>;
    final dados = await _obter('search', {'q': q, 'limit': '5'});
    if (dados is! List) {
      throw const ExcecaoGeocodificacao('Resposta invalida');
    }
    final r = [for (final m in dados) _item(m as Map<String, dynamic>)];
    _cache[chave] = r;
    return r;
  }

  @override
  Future<ResultadoGeocodificacao?> reverso(double lat, double lng) async {
    final chave = 'r:${lat.toStringAsFixed(5)},${lng.toStringAsFixed(5)}';
    if (_cache.containsKey(chave)) {
      return _cache[chave] as ResultadoGeocodificacao?;
    }
    final dados = await _obter('reverse', {'lat': '$lat', 'lon': '$lng'});
    if (dados is! Map<String, dynamic>) {
      throw const ExcecaoGeocodificacao('Resposta invalida');
    }
    final r = dados.containsKey('error') ? null : _item(dados);
    _cache[chave] = r;
    return r;
  }
}
