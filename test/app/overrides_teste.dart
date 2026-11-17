import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:kaptalixo/app/acoes_app.dart';
import 'package:kaptalixo/nucleo/localizacao/localizacao_fake.dart';
import 'package:kaptalixo/nucleo/localizacao/providers.dart';
import 'package:latlong2/latlong.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

/// Tiles sem rede para testes de mapa.
class TilesSemRede extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_png);
}

/// Overrides para abrir as telas reais de cada papel sem GPS nem rede.
List<Override> overridesTelasReais() => [
  servicoLocalizacaoProvider.overrideWithValue(
    LocalizacaoFake()..emitirPonto(const LatLng(-23.55, -46.63)),
  ),
  tileProviderAppProvider.overrideWithValue(TilesSemRede()),
];
