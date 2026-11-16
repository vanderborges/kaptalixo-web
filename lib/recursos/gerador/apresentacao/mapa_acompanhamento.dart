import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/config.dart';

/// Mapa do acompanhamento: casa do gerador, catador e linha do trajeto.
/// Reenquadra quando o catador se move, até o gerador mexer no mapa.
class MapaAcompanhamento extends StatefulWidget {
  const MapaAcompanhamento({
    super.key,
    required this.local,
    this.catador,
    this.trajeto = const [],
    this.tileProvider,
  });

  final LatLng local;
  final LatLng? catador;
  final List<LatLng> trajeto;
  final TileProvider? tileProvider;

  @override
  State<MapaAcompanhamento> createState() => _EstadoMapa();
}

class _EstadoMapa extends State<MapaAcompanhamento> {
  final _controle = MapController();
  bool _pronto = false;
  bool _manual = false;

  CameraFit _enquadrar() {
    final c = widget.catador;
    return CameraFit.coordinates(
      coordinates: [widget.local, c ?? widget.local],
      maxZoom: c == null ? 16 : 17,
      padding: const EdgeInsets.all(56),
    );
  }

  @override
  void didUpdateWidget(MapaAcompanhamento antigo) {
    super.didUpdateWidget(antigo);
    if (_pronto && !_manual && antigo.catador != widget.catador) {
      _controle.fitCamera(_enquadrar());
    }
  }

  @override
  void dispose() {
    _controle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return FlutterMap(
      mapController: _controle,
      options: MapOptions(
        initialCenter: widget.local,
        initialZoom: 15,
        initialCameraFit: _enquadrar(),
        onMapReady: () => _pronto = true,
        onPositionChanged: (_, temGesto) {
          if (temGesto) _manual = true;
        },
      ),
      children: [
        TileLayer(
          urlTemplate: Config.tileUrl,
          userAgentPackageName: 'br.kaptalixo.app',
          tileProvider: widget.tileProvider,
        ),
        if (widget.trajeto.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.trajeto,
                strokeWidth: 5,
                color: cores.primary,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: widget.local,
              width: 48,
              height: 48,
              child: Tooltip(
                message: 'Seu endereço',
                child: Icon(Icons.home, color: cores.error, size: 40),
              ),
            ),
            if (widget.catador != null)
              Marker(
                point: widget.catador!,
                width: 48,
                height: 48,
                child: Tooltip(
                  message: 'Seu catador',
                  child: Icon(
                    Icons.local_shipping,
                    color: cores.primary,
                    size: 40,
                  ),
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
