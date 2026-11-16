import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'localizacao_gps.dart';
import 'servico_localizacao.dart';

/// Servico de localizacao em uso. Padrao: GPS. O modo simulacao (UC16) liga-se
/// sobrescrevendo este provider com `LocalizacaoSimulada` (polyline da rota
/// ativa); testes usam `LocalizacaoFake`.
final servicoLocalizacaoProvider = Provider<ServicoLocalizacao>(
  (ref) => LocalizacaoGps(),
);
