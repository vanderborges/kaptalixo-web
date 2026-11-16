import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/config.dart';
import '../dominio/rota_ativa.dart';

/// Mapa da rota: polyline, paradas numeradas (a próxima em destaque) e a
/// posição do catador. Reenquadra ao mudar a próxima parada, até o catador
/// mexer no mapa.
class MapaRota extends StatefulWidget {
  const MapaRota({
    super.key,
    required this.rota,
    this.posicao,
    this.tileProvider,
  });

  final RotaAtiva rota;
  final LatLng? posicao;
  final TileProvider? tileProvider;

  @override
  State<MapaRota> createState() => _EstadoMapaRota();
}

class _EstadoMapaRota extends State<MapaRota> {
  final _controle = MapController();
  bool _pronto = false;
  bool _manual = false;

  List<ParadaRota> get _abertas => [
    for (final p in widget.rota.paradas)
      if (p.status.aberta && p.posicao != null) p,
  ];

  LatLng get _centro => _abertas.isNotEmpty
      ? _abertas.first.posicao!
      : (widget.posicao ?? LatLng(Config.cidadeDemoLat, Config.cidadeDemoLng));

  CameraFit? _enquadrar() {
    final pontos = [
      for (final p in _abertas) p.posicao!,
      if (widget.posicao != null) widget.posicao!,
    ];
    if (pontos.isEmpty) return null;
    return CameraFit.coordinates(
      coordinates: pontos,
      maxZoom: 17,
      padding: const EdgeInsets.all(56),
    );
  }

  @override
  void didUpdateWidget(MapaRota antigo) {
    super.didUpdateWidget(antigo);
    final mudouProxima = antigo.rota.proxima?.id != widget.rota.proxima?.id;
    final primeiraPosicao = antigo.posicao == null && widget.posicao != null;
    if (_pronto && !_manual && (mudouProxima || primeiraPosicao)) {
      final fit = _enquadrar();
      if (fit != null) _controle.fitCamera(fit);
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
    final proximaId = widget.rota.proxima?.id;
    final coletas = widget.rota.coletas.where(
      (c) => c.status != StatusParada.pulada,
    );
    final numeros = {for (final (i, c) in coletas.indexed) c.id: i + 1};

    return FlutterMap(
      mapController: _controle,
      options: MapOptions(
        initialCenter: _centro,
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
        if (widget.rota.trajeto.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: widget.rota.trajeto,
                strokeWidth: 5,
                color: cores.primary,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final p in _abertas)
              Marker(
                point: p.posicao!,
                width: 48,
                height: 48,
                child: _MarcadorParada(
                  key: Key('marcador-${p.id}'),
                  numero: numeros[p.id],
                  descarte: !p.ehColeta,
                  destaque: p.id == proximaId,
                ),
              ),
            if (widget.posicao != null)
              Marker(
                point: widget.posicao!,
                width: 48,
                height: 48,
                child: Tooltip(
                  message: 'Você',
                  child: Icon(
                    Icons.navigation,
                    key: const Key('marcador-catador'),
                    color: cores.tertiary,
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

class _MarcadorParada extends StatelessWidget {
  const _MarcadorParada({
    super.key,
    required this.numero,
    required this.descarte,
    required this.destaque,
  });

  final int? numero;
  final bool descarte;
  final bool destaque;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    final fundo = destaque ? cores.primary : cores.secondary;
    final frente = destaque ? cores.onPrimary : cores.onSecondary;
    return Tooltip(
      message: descarte ? 'Ponto de descarte' : 'Coleta $numero',
      child: Container(
        decoration: BoxDecoration(
          color: fundo,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: destaque ? 4 : 2),
        ),
        alignment: Alignment.center,
        child: descarte
            ? Icon(Icons.recycling, color: frente)
            : Text(
                '${numero ?? ''}',
                style: TextStyle(
                  color: frente,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
      ),
    );
  }
}
