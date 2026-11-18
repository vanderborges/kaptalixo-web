import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Minutos inteiros (mínimo 1) até [eta], a partir de [agora].
int minutosAte(DateTime eta, DateTime agora) {
  final m = (eta.difference(agora).inSeconds / 60).ceil();
  return m < 1 ? 1 : m;
}

/// Distância em linguagem simples: "350 m" ou "1,2 km".
String distanciaLegivel(int metros) {
  if (metros < 1000) return '${(metros / 10).round() * 10} m';
  return '${(metros / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// Texto "Chega em cerca de X min (Y km)" (UC09). [agora] vem do relógio.
String textoChegada(DateTime eta, DateTime agora, int? distanciaM) {
  final base = eta.isAfter(agora)
      ? 'Chega em cerca de ${minutosAte(eta, agora)} min'
      : 'Chegando agora';
  if (distanciaM == null || !eta.isAfter(agora)) return base;
  return '$base (${distanciaLegivel(distanciaM)})';
}

/// Mostra a chegada estimada com contagem regressiva local. Sem [eta], não
/// ocupa espaço. Atualiza sozinho quando a rota é replanejada (novo [eta]).
class TextoChegada extends ConsumerStatefulWidget {
  const TextoChegada({
    super.key,
    required this.eta,
    this.distanciaM,
    this.style,
  });

  final DateTime? eta;
  final int? distanciaM;
  final TextStyle? style;

  @override
  ConsumerState<TextoChegada> createState() => _EstadoTextoChegada();
}

class _EstadoTextoChegada extends ConsumerState<TextoChegada> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eta = widget.eta;
    if (eta == null) return const SizedBox.shrink();
    final agora = ref.watch(relogioGeradorProvider)();
    return Text(
      textoChegada(eta, agora, widget.distanciaM),
      key: const Key('chegada_estimada'),
      style: widget.style,
    );
  }
}
