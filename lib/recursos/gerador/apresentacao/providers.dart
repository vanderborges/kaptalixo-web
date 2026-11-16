import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/config.dart';
import '../../../nucleo/localizacao/providers.dart';
import '../../../nucleo/mapas/servico_geocodificacao.dart';
import '../../../nucleo/mapas/servico_geocodificacao_nominatim.dart';
import '../dados/pontos_proximos_repositorio_fake.dart';
import '../dominio/ponto_proximo.dart';
import '../dominio/pontos_proximos_repositorio.dart';

/// Repositório de pontos próximos. Padrão: fake; `main.dart` troca pela
/// implementação Supabase quando houver conexão (ver PEDIDOS.md).
final pontosProximosRepositorioProvider = Provider<PontosProximosRepositorio>(
  (ref) => PontosProximosRepositorioFake(),
);

/// Geocodificação (endereço manual). Testes sobrescrevem com o fake.
final geocodificacaoProvider = Provider<ServicoGeocodificacao>(
  (ref) => ServicoGeocodificacaoNominatim(urlBase: Config.nominatimBaseUrl),
);

/// Onde o gerador está (GPS ou endereço digitado).
class LocalGerador {
  const LocalGerador({required this.ponto, this.rotulo, this.manual = false});

  final LatLng ponto;

  /// Endereço legível, quando conhecido.
  final String? rotulo;
  final bool manual;
}

/// Posição do gerador. Erro `FalhaLocalizacao` => a tela pede endereço manual.
class LocalGeradorNotifier extends AsyncNotifier<LocalGerador> {
  @override
  Future<LocalGerador> build() async {
    final posicao = await ref.read(servicoLocalizacaoProvider).atual();
    return LocalGerador(ponto: posicao.ponto);
  }

  /// Tenta o GPS de novo.
  Future<void> usarGps() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  /// Usa um endereço escolhido pelo gerador.
  void definirManual(ResultadoGeocodificacao r) {
    state = AsyncData(
      LocalGerador(ponto: r.posicao, rotulo: r.nome, manual: true),
    );
  }
}

Duration? _semRetentativa(int tentativas, Object erro) => null;

final localGeradorProvider =
    AsyncNotifierProvider<LocalGeradorNotifier, LocalGerador>(
      LocalGeradorNotifier.new,
      retry: _semRetentativa,
    );

/// Pontos de coleta perto de [centro].
final pontosProximosProvider = FutureProvider.autoDispose
    .family<List<PontoProximo>, LatLng>(
      retry: _semRetentativa,
      (ref, centro) =>
          ref.watch(pontosProximosRepositorioProvider).proximos(centro),
    );
