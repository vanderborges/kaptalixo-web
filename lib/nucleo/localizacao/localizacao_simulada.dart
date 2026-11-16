import 'dart:async';

import 'package:latlong2/latlong.dart';

import '../mapas/haversine.dart';
import 'posicao.dart';
import 'servico_localizacao.dart';

/// Percurso sobre uma polyline: dada a distancia percorrida, devolve o ponto.
class PercursoSimulado {
  PercursoSimulado(List<LatLng> polyline)
    : assert(polyline.isNotEmpty, 'Polyline vazia'),
      _pontos = List.unmodifiable(polyline) {
    var acc = 0.0;
    _acumulado = [0.0];
    for (var i = 1; i < _pontos.length; i++) {
      acc += distanciaHaversineMetros(_pontos[i - 1], _pontos[i]);
      _acumulado.add(acc);
    }
    comprimentoMetros = acc;
  }

  final List<LatLng> _pontos;
  late final List<double> _acumulado;
  late final double comprimentoMetros;

  LatLng get inicio => _pontos.first;
  LatLng get fim => _pontos.last;

  /// Ponto apos percorrer [metros] (limitado ao fim).
  LatLng pontoEm(double metros) {
    if (metros <= 0) return _pontos.first;
    if (metros >= comprimentoMetros) return _pontos.last;
    var i = 1;
    while (_acumulado[i] < metros) {
      i++;
    }
    final trecho = _acumulado[i] - _acumulado[i - 1];
    if (trecho == 0) return _pontos[i];
    final f = (metros - _acumulado[i - 1]) / trecho;
    final a = _pontos[i - 1];
    final b = _pontos[i];
    return LatLng(
      a.latitude + (b.latitude - a.latitude) * f,
      a.longitude + (b.longitude - a.longitude) * f,
    );
  }
}

/// Fonte de instantes (um por tick). Injetavel nos testes.
typedef FonteTicks = Stream<DateTime> Function(Duration intervalo);

Stream<DateTime> _ticksReais(Duration intervalo) =>
    Stream.periodic(intervalo, (_) => DateTime.now());

/// Simula o GPS percorrendo [polyline] a [velocidadeKmh] x [multiplicador].
/// Relogio e fonte de ticks sao injetaveis (testes sem Timer real).
class LocalizacaoSimulada implements ServicoLocalizacao {
  LocalizacaoSimulada({
    required List<LatLng> polyline,
    this.velocidadeKmh = 30,
    this.multiplicador = 1,
    this.intervalo = const Duration(seconds: 1),
    DateTime Function()? relogio,
    FonteTicks? ticks,
  }) : percurso = PercursoSimulado(polyline),
       _relogio = relogio ?? DateTime.now,
       _ticks = ticks ?? _ticksReais;

  final PercursoSimulado percurso;
  final double velocidadeKmh;
  final double multiplicador;
  final Duration intervalo;
  final DateTime Function() _relogio;
  final FonteTicks _ticks;
  DateTime? _inicio;

  double get velocidadeEfetivaMs => velocidadeKmh * multiplicador / 3.6;

  double _metros(DateTime agora) {
    final inicio = _inicio ??= agora;
    final seg = agora.difference(inicio).inMicroseconds / 1e6;
    return seg <= 0 ? 0.0 : seg * velocidadeEfetivaMs;
  }

  Posicao _em(DateTime agora) => Posicao(
    ponto: percurso.pontoEm(_metros(agora)),
    instante: agora,
    simulada: true,
  );

  bool _terminou(DateTime agora) =>
      _metros(agora) >= percurso.comprimentoMetros;

  @override
  Future<Posicao> atual() async => _em(_relogio());

  /// Emite o ponto inicial, uma posicao por tick e fecha ao chegar ao fim.
  @override
  Stream<Posicao> posicoes() async* {
    final t0 = _relogio();
    yield _em(t0);
    if (_terminou(t0)) return;
    await for (final t in _ticks(intervalo)) {
      yield _em(t);
      if (_terminou(t)) return;
    }
  }
}
