import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/nucleo/mapas/servico_geocodificacao.dart';
import 'package:kaptalixo/nucleo/mapas/servico_geocodificacao_fake.dart';
import 'package:kaptalixo/nucleo/mapas/servico_geocodificacao_nominatim.dart';

import 'adaptador_http_fake.dart';

void main() {
  late List<Duration> esperas;
  late DateTime relogio;

  ServicoGeocodificacaoNominatim criar(AdaptadorHttpFake a) {
    esperas = [];
    relogio = DateTime(2026, 1, 1);
    return ServicoGeocodificacaoNominatim(
      urlBase: 'http://nominatim.teste',
      dio: Dio()..httpClientAdapter = a,
      agora: () => relogio,
      esperar: (d) async {
        esperas.add(d);
        relogio = relogio.add(d);
      },
    );
  }

  test('buscar le fixture e envia User-Agent', () async {
    final a = AdaptadorHttpFake(['nominatim_busca.json']);
    final r = await criar(a).buscar('Praca da Se');
    expect(r.length, 2);
    expect(r.first.posicao.latitude, closeTo(-23.5505199, 1e-9));
    expect(r.first.nome, contains('Praca da Se'));
    final req = a.requisicoes.single;
    expect(req.headers['User-Agent'], 'KaptalixoPOC/1.0');
    expect(req.uri.queryParameters['q'], 'Praca da Se');
  });

  test('cache evita nova requisicao', () async {
    final a = AdaptadorHttpFake(['nominatim_busca.json']);
    final s = criar(a);
    await s.buscar('Praca da Se');
    await s.buscar('  praca da se ');
    expect(a.requisicoes.length, 1);
  });

  test('texto vazio nao consulta', () async {
    final a = AdaptadorHttpFake(['nominatim_busca.json']);
    expect(await criar(a).buscar('  '), isEmpty);
    expect(a.requisicoes, isEmpty);
  });

  test('reverso com resultado e sem resultado', () async {
    final s = criar(AdaptadorHttpFake(['nominatim_reverso.json']));
    final r = await s.reverso(-23.55, -46.63);
    expect(r!.nome, contains('Se'));
    final v = criar(AdaptadorHttpFake(['nominatim_reverso_vazio.json']));
    expect(await v.reverso(0, 0), isNull);
  });

  test('throttling: segunda requisicao espera ~1s', () async {
    final a = AdaptadorHttpFake(['nominatim_busca.json']);
    final s = criar(a);
    await Future.wait([s.buscar('a'), s.buscar('b'), s.buscar('c')]);
    expect(a.requisicoes.length, 3);
    expect(esperas.length, 2);
    for (final e in esperas) {
      expect(e, const Duration(seconds: 1));
    }
  });

  test('falha de rede: 1 retry e depois ExcecaoGeocodificacao', () async {
    final a = AdaptadorHttpFake([DioExceptionType.connectionTimeout]);
    await expectLater(
      criar(a).buscar('x'),
      throwsA(isA<ExcecaoGeocodificacao>()),
    );
    expect(a.requisicoes.length, 2);
  });

  test('retry recupera apos falha', () async {
    final a = AdaptadorHttpFake([
      DioExceptionType.connectionError,
      'nominatim_busca.json',
    ]);
    expect((await criar(a).buscar('x')).length, 2);
  });

  test('fake', () async {
    final f = ServicoGeocodificacaoFake();
    expect(await f.buscar('x'), isEmpty);
    expect((await f.reverso(1, 2))!.posicao.longitude, 2);
    await expectLater(
      ServicoGeocodificacaoFake(falhar: true).buscar('x'),
      throwsA(isA<ExcecaoGeocodificacao>()),
    );
  });
}
