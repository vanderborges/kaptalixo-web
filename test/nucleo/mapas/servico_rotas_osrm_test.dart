import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/nucleo/mapas/haversine.dart';
import 'package:kaptalixo/nucleo/mapas/polyline.dart';
import 'package:kaptalixo/nucleo/mapas/rota_calculada.dart';
import 'package:kaptalixo/nucleo/mapas/servico_rotas_fake.dart';
import 'package:kaptalixo/nucleo/mapas/servico_rotas_osrm.dart';
import 'package:latlong2/latlong.dart';

import 'adaptador_http_fake.dart';

void main() {
  const origem = LatLng(-23.50, -46.60);
  const p1 = LatLng(-23.51, -46.61);
  const p2 = LatLng(-23.505, -46.605);
  const destino = LatLng(-23.52, -46.62);

  ServicoRotasOsrm criar(AdaptadorHttpFake a) {
    final dio = Dio()..httpClientAdapter = a;
    return ServicoRotasOsrm(urlBase: 'http://osrm.teste/', dio: dio);
  }

  group('polyline', () {
    test('decodifica exemplo canonico', () {
      final pts = decodificarPolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');
      expect(pts.length, 3);
      expect(pts[0].latitude, closeTo(38.5, 1e-9));
      expect(pts[0].longitude, closeTo(-120.2, 1e-9));
      expect(pts[2].latitude, closeTo(43.252, 1e-9));
      expect(pts[2].longitude, closeTo(-126.453, 1e-9));
    });

    test('texto vazio e truncado', () {
      expect(decodificarPolyline(''), isEmpty);
      expect(() => decodificarPolyline('_p~iF~'), throwsFormatException);
    });
  });

  group('haversine', () {
    test('distancia conhecida (1 grau de latitude ~ 111,2 km)', () {
      final d = distanciaHaversineMetros(
        const LatLng(0, 0),
        const LatLng(1, 0),
      );
      expect(d, closeTo(111195, 100));
    });

    test('mesmo ponto e zero e simetria', () {
      expect(distanciaHaversineMetros(origem, origem), 0);
      expect(
        distanciaHaversineMetros(origem, destino),
        closeTo(distanciaHaversineMetros(destino, origem), 1e-6),
      );
    });

    test('vizinho mais proximo', () {
      const a = LatLng(0, 0.1);
      const b = LatLng(0, 0.01);
      const c = LatLng(0, 0.05);
      expect(ordemVizinhoMaisProximo(const LatLng(0, 0), [a, b, c]), [1, 2, 0]);
    });
  });

  group('ServicoRotasOsrm', () {
    test('route sem paradas usa fixture', () async {
      final a = AdaptadorHttpFake(['osrm_route.json']);
      final r = await criar(a).calcular(origem, [], destino);
      expect(r.origemCalculo, OrigemCalculo.osrm);
      expect(r.distanciaMetros, 1523.4);
      expect(r.duracaoSegundos, 212.7);
      expect(r.geometria.length, 3);
      expect(a.requisicoes.single.uri.path, contains('/route/v1/driving/'));
      expect(
        a.requisicoes.single.uri.path,
        contains('-46.6,-23.5;-46.62,-23.52'),
      );
    });

    test('trip reordena paradas e usa source/destination', () async {
      final a = AdaptadorHttpFake(['osrm_trip.json']);
      final r = await criar(a).calcular(origem, [p1, p2], destino);
      expect(r.origemCalculo, OrigemCalculo.osrm);
      expect(r.ordemParadas, [1, 0]);
      final q = a.requisicoes.single.uri.queryParameters;
      expect(q['source'], 'first');
      expect(q['destination'], 'last');
      expect(q['roundtrip'], 'false');
    });

    test('cache em memoria evita segunda requisicao', () async {
      final a = AdaptadorHttpFake(['osrm_trip.json']);
      final s = criar(a);
      await s.calcular(origem, [p1, p2], destino);
      await s.calcular(origem, [p1, p2], destino);
      expect(a.requisicoes.length, 1);
    });

    test('table devolve matriz', () async {
      final a = AdaptadorHttpFake(['osrm_table.json']);
      final m = await criar(a).matrizDuracoes([origem, p1, destino]);
      expect(m[0][1], 100.5);
      expect(m[2][0], 210);
      expect(a.requisicoes.single.uri.path, contains('/table/v1/driving/'));
    });

    test('duracaoAte usa route', () async {
      final a = AdaptadorHttpFake(['osrm_route.json']);
      expect(await criar(a).duracaoAte(origem, destino), 212.7);
    });

    test('1 retry apos timeout e depois sucesso', () async {
      final a = AdaptadorHttpFake([
        DioExceptionType.receiveTimeout,
        'osrm_route.json',
      ]);
      final r = await criar(a).calcular(origem, [], destino);
      expect(r.origemCalculo, OrigemCalculo.osrm);
      expect(a.requisicoes.length, 2);
    });

    test('falha de rede persistente cai em haversine', () async {
      final a = AdaptadorHttpFake([DioExceptionType.connectionError]);
      final r = await criar(a).calcular(origem, [p1, p2], destino);
      expect(a.requisicoes.length, 2);
      expect(r.origemCalculo, OrigemCalculo.haversine);
      // vizinho mais proximo: p2 (mais perto da origem) antes de p1.
      expect(r.ordemParadas, [1, 0]);
      expect(r.geometria, [origem, p2, p1, destino]);
      expect(
        r.distanciaMetros,
        closeTo(
          distanciaHaversineMetros(origem, p2) +
              distanciaHaversineMetros(p2, p1) +
              distanciaHaversineMetros(p1, destino),
          1e-6,
        ),
      );
      expect(r.duracaoSegundos, greaterThan(0));
    });

    test('HTTP 500 cai em haversine; duracao e matriz tambem', () async {
      final s = criar(AdaptadorHttpFake([500]));
      expect(
        (await s.calcular(origem, [], destino)).origemCalculo,
        OrigemCalculo.haversine,
      );
      expect(await s.duracaoAte(origem, destino), greaterThan(0));
      final m = await s.matrizDuracoes([origem, destino]);
      expect(m[0][0], 0);
      expect(m[0][1], greaterThan(0));
    });

    test('codigo OSRM diferente de Ok cai em fallback', () async {
      final a = AdaptadorHttpFake([404]);
      final r = await criar(a).calcular(origem, [], destino);
      expect(r.origemCalculo, OrigemCalculo.haversine);
      expect(a.requisicoes.length, 1, reason: '4xx nao repete');
    });
  });

  test('ServicoRotasFake e deterministico', () async {
    final f = ServicoRotasFake();
    final r = await f.calcular(origem, [p1], destino);
    expect(r.ordemParadas, [0]);
    expect(await f.duracaoAte(origem, destino), greaterThan(0));
    expect(f.chamadas, ['calcular', 'duracaoAte']);
  });
}
