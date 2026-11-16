import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/config.dart';
import '../dominio/ponto_proximo.dart';

/// Mapa OSM com a posição do gerador e os pontos de coleta próximos.
class MapaGerador extends StatelessWidget {
  const MapaGerador({
    super.key,
    required this.centro,
    this.minhaPosicao,
    this.pontos = const [],
    this.tileProvider,
  });

  final LatLng centro;
  final LatLng? minhaPosicao;
  final List<PontoProximo> pontos;

  /// Permite trocar a fonte de tiles (testes).
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return FlutterMap(
      key: ValueKey(centro),
      options: MapOptions(initialCenter: centro, initialZoom: 15),
      children: [
        TileLayer(
          urlTemplate: Config.tileUrl,
          userAgentPackageName: 'br.kaptalixo.app',
          tileProvider: tileProvider,
        ),
        MarkerLayer(
          markers: [
            for (final p in pontos)
              Marker(
                point: p.posicao,
                width: 44,
                height: 44,
                child: Tooltip(
                  message: p.nome,
                  child: Icon(Icons.recycling, color: cores.tertiary, size: 32),
                ),
              ),
            if (minhaPosicao != null)
              Marker(
                point: minhaPosicao!,
                width: 48,
                height: 48,
                child: Tooltip(
                  message: 'Você está aqui',
                  child: Icon(Icons.location_pin, color: cores.error, size: 44),
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
