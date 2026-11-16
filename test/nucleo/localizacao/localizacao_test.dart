import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:kaptalixo/nucleo/localizacao/falha_localizacao.dart';
import 'package:kaptalixo/nucleo/localizacao/localizacao_fake.dart';
import 'package:kaptalixo/nucleo/localizacao/localizacao_gps.dart';
import 'package:kaptalixo/nucleo/localizacao/localizacao_simulada.dart';
import 'package:kaptalixo/nucleo/mapas/haversine.dart';
import 'package:latlong2/latlong.dart';

class _PlataformaFake implements PlataformaGps {
  _PlataformaFake({this.ativo = true, this.perm = LocationPermission.always});
  bool ativo;
  LocationPermission perm;
  LocationPermission? aposSolicitar;

  @override
  Future<bool> servicoAtivo() async => ativo;
  @override
  Future<LocationPermission> permissao() async => perm;
  @override
  Future<LocationPermission> solicitarPermissao() async =>
      perm = aposSolicitar ?? perm;
  @override
  Future<Position> posicaoAtual() async => _pos(-23.5, -46.6);
  @override
  Stream<Position> fluxo(int f) =>
      Stream.fromIterable([_pos(-23.5, -46.6), _pos(-23.51, -46.6)]);

  Position _pos(double la, double ln) => Position(
    latitude: la,
    longitude: ln,
    timestamp: DateTime.utc(2026),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  // ~1,11 km por 0,01 grau de latitude; polyline de ~2,2 km com curva.
  final linha = [
    const LatLng(-23.50, -46.60),
    const LatLng(-23.51, -46.60),
    const LatLng(-23.52, -46.60),
  ];
  final t0 = DateTime.utc(2026, 1, 1);

  group('LocalizacaoSimulada', () {
    late StreamController<DateTime> ticks;
    late DateTime agora;

    setUp(() {
      ticks = StreamController<DateTime>();
      agora = t0;
    });

    LocalizacaoSimulada criar({double mult = 1}) => LocalizacaoSimulada(
      polyline: linha,
      velocidadeKmh: 36, // 10 m/s
      multiplicador: mult,
      relogio: () => agora,
      ticks: (_) => ticks.stream,
    );

    test('posicoes monotonicas e termina no ultimo ponto', () async {
      final sim = criar();
      final recebidas = <LatLng>[];
      final fim = Completer<void>();
      sim.posicoes().listen(
        (p) => recebidas.add(p.ponto),
        onDone: fim.complete,
      );
      for (var s = 30; s <= 600; s += 30) {
        ticks.add(t0.add(Duration(seconds: s)));
        await Future<void>.delayed(Duration.zero);
        if (fim.isCompleted) break;
      }
      await fim.future; // stream fechou sozinho no fim
      expect(recebidas.first, linha.first);
      expect(recebidas.last, linha.last);
      var anterior = 0.0;
      for (final p in recebidas) {
        final d = distanciaHaversineMetros(linha.first, p);
        expect(d, greaterThanOrEqualTo(anterior));
        anterior = d;
      }
    });

    test('nao passa do ultimo ponto apos o fim', () async {
      final sim = criar();
      agora = t0;
      await sim.atual();
      agora = t0.add(const Duration(hours: 5));
      expect((await sim.atual()).ponto, linha.last);
    });

    test('multiplicador 10x percorre 10x mais rapido', () async {
      final normal = criar();
      final rapido = criar(mult: 10);
      await normal.atual();
      await rapido.atual();
      agora = t0.add(const Duration(seconds: 10));
      final dn = distanciaHaversineMetros(
        linha.first,
        (await normal.atual()).ponto,
      );
      final dr = distanciaHaversineMetros(
        linha.first,
        (await rapido.atual()).ponto,
      );
      expect(dn, closeTo(100, 1));
      expect(dr, closeTo(1000, 10));
      expect(dr / dn, closeTo(10, 0.1));
    });

    test('marca posicao como simulada e interpola entre vertices', () async {
      final sim = criar();
      await sim.atual();
      agora = t0.add(const Duration(seconds: 111));
      final p = await sim.atual();
      expect(p.simulada, isTrue);
      expect(p.latitude, closeTo(-23.50999, 0.0005));
    });
  });

  group('LocalizacaoGps', () {
    test('servico desligado', () {
      final gps = LocalizacaoGps(plataforma: _PlataformaFake(ativo: false));
      expect(
        gps.atual(),
        throwsA(
          isA<FalhaLocalizacao>().having(
            (e) => e.motivo,
            'motivo',
            MotivoFalhaLocalizacao.servicoDesligado,
          ),
        ),
      );
    });

    test('permissao negada apos solicitar', () {
      final p = _PlataformaFake(perm: LocationPermission.denied)
        ..aposSolicitar = LocationPermission.denied;
      expect(
        LocalizacaoGps(plataforma: p).posicoes().first,
        throwsA(
          isA<FalhaLocalizacao>().having(
            (e) => e.motivo,
            'motivo',
            MotivoFalhaLocalizacao.permissaoNegada,
          ),
        ),
      );
    });

    test('negada para sempre', () {
      final p = _PlataformaFake(perm: LocationPermission.deniedForever);
      expect(
        LocalizacaoGps(plataforma: p).atual(),
        throwsA(
          isA<FalhaLocalizacao>().having(
            (e) => e.motivo,
            'motivo',
            MotivoFalhaLocalizacao.permissaoNegadaParaSempre,
          ),
        ),
      );
    });

    test('permissao concedida apos solicitar converte posicao', () async {
      final p = _PlataformaFake(perm: LocationPermission.denied)
        ..aposSolicitar = LocationPermission.whileInUse;
      final gps = LocalizacaoGps(plataforma: p);
      final a = await gps.atual();
      expect(a.latitude, -23.5);
      expect(a.simulada, isFalse);
      expect((await gps.posicoes().toList()).length, 2);
    });
  });

  group('LocalizacaoFake', () {
    test('emite e devolve atual; falha tipada', () async {
      final f = LocalizacaoFake();
      expect(f.atual(), throwsA(isA<FalhaLocalizacao>()));
      final futuro = f.posicoes().first;
      f.emitirPonto(const LatLng(1, 2), instante: t0);
      expect((await futuro).ponto, const LatLng(1, 2));
      expect((await f.atual()).ponto, const LatLng(1, 2));
      await f.fechar();
    });
  });
}
