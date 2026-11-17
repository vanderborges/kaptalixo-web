import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/config.dart';
import '../dominio/demo.dart';

/// Aparência de cada tipo de ator no mapa (ícone + cor + rótulo).
({IconData icone, Color cor}) estiloAtor(TipoAtorDemo tipo) => switch (tipo) {
  TipoAtorDemo.gerador => (icone: Icons.home, cor: const Color(0xFF1565C0)),
  TipoAtorDemo.catador => (
    icone: Icons.directions_walk,
    cor: const Color(0xFFE65100),
  ),
  TipoAtorDemo.ponto => (icone: Icons.recycling, cor: const Color(0xFF2E7D32)),
};

/// Mapa do painel: geradores, catadores, pontos e rotas abertas.
class MapaDemo extends StatelessWidget {
  const MapaDemo({
    super.key,
    required this.snapshot,
    this.catadorEmSimulacao,
    this.tileProvider,
  });

  final SnapshotDemo snapshot;
  final String? catadorEmSimulacao;
  final TileProvider? tileProvider;

  static const _coresRotas = [
    Color(0xFF6A1B9A),
    Color(0xFF00838F),
    Color(0xFFAD1457),
    Color(0xFF4E342E),
  ];

  CameraFit? _enquadrar() {
    final pontos = [for (final a in snapshot.atores) a.posicao];
    if (pontos.length < 2) return null;
    return CameraFit.coordinates(
      coordinates: pontos,
      maxZoom: 16,
      padding: const EdgeInsets.all(48),
    );
  }

  @override
  Widget build(BuildContext context) {
    final centro = snapshot.atores.isEmpty
        ? LatLng(Config.cidadeDemoLat, Config.cidadeDemoLng)
        : snapshot.atores.first.posicao;
    return FlutterMap(
      options: MapOptions(
        initialCenter: centro,
        initialZoom: 14,
        initialCameraFit: _enquadrar(),
      ),
      children: [
        TileLayer(
          urlTemplate: Config.tileUrl,
          userAgentPackageName: 'br.kaptalixo.app',
          tileProvider: tileProvider,
        ),
        PolylineLayer(
          polylines: [
            for (final (i, r) in snapshot.rotas.indexed)
              if (r.pontos.length > 1)
                Polyline(
                  points: r.pontos,
                  strokeWidth: 4,
                  color: _coresRotas[i % _coresRotas.length],
                ),
          ],
        ),
        MarkerLayer(
          markers: [
            for (final a in snapshot.atores)
              Marker(
                key: Key('ator-${a.id}'),
                point: a.posicao,
                width: 44,
                height: 44,
                child: _MarcadorAtor(
                  ator: a,
                  simulando: a.id == catadorEmSimulacao,
                ),
              ),
          ],
        ),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('© Colaboradores do OpenStreetMap'),
          ],
        ),
      ],
    );
  }
}

class _MarcadorAtor extends StatelessWidget {
  const _MarcadorAtor({required this.ator, required this.simulando});

  final AtorDemo ator;
  final bool simulando;

  @override
  Widget build(BuildContext context) {
    final e = estiloAtor(ator.tipo);
    return Tooltip(
      message: '${ator.tipo.rotulo}: ${ator.nome}',
      child: Container(
        decoration: BoxDecoration(
          color: e.cor,
          shape: BoxShape.circle,
          border: Border.all(
            color: simulando ? Colors.yellow : Colors.white,
            width: simulando ? 4 : 2,
          ),
        ),
        child: Icon(e.icone, color: Colors.white, size: 24),
      ),
    );
  }
}

/// Legenda dos marcadores.
class LegendaDemo extends StatelessWidget {
  const LegendaDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        for (final t in TipoAtorDemo.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(estiloAtor(t).icone, color: estiloAtor(t).cor, size: 20),
              const SizedBox(width: 4),
              Text(t.rotulo, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timeline, size: 20),
            const SizedBox(width: 4),
            Text('Rota', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ],
    );
  }
}
