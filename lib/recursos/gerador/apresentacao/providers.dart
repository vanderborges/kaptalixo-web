import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/config.dart';
import '../../../nucleo/localizacao/providers.dart';
import '../../../nucleo/mapas/servico_geocodificacao.dart';
import '../../../nucleo/mapas/servico_geocodificacao_nominatim.dart';
import '../dados/materiais_repositorio_fake.dart';
import '../dados/pontos_proximos_repositorio_fake.dart';
import '../dados/solicitacao_repositorio_fake.dart';
import '../../../nucleo/mapas/rota_calculada.dart';
import '../../../nucleo/mapas/servico_rotas.dart';
import '../../../nucleo/mapas/servico_rotas_osrm.dart';
import '../dados/acompanhamento_repositorio_fake.dart';
import '../dominio/acompanhamento_coleta.dart';
import '../dominio/acompanhamento_repositorio.dart';
import '../dominio/material_reciclavel.dart';
import '../dominio/materiais_repositorio.dart';
import '../dominio/ponto_proximo.dart';
import '../dominio/pontos_proximos_repositorio.dart';
import '../dominio/solicitacao_repositorio.dart';

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

/// Repositório de solicitações. Padrão: fake; `main.dart` troca pelo Supabase
/// (ver PEDIDOS.md).
final solicitacaoRepositorioProvider = Provider<SolicitacaoRepositorio>(
  (ref) => SolicitacaoRepositorioFake(),
);

/// Repositório de materiais. Padrão: fake.
final materiaisRepositorioProvider = Provider<MateriaisRepositorio>(
  (ref) => MateriaisRepositorioFake(),
);

/// Materiais disponíveis no formulário.
final materiaisProvider = FutureProvider.autoDispose<List<MaterialReciclavel>>(
  retry: _semRetentativa,
  (ref) => ref.watch(materiaisRepositorioProvider).listar(),
);

/// Repositório do acompanhamento (UC09). Padrão: fake; `main.dart` troca pelo
/// `AcompanhamentoRepositorioImpl(AcompanhamentoRemotoSupabase(client))`.
final acompanhamentoRepositorioProvider = Provider<AcompanhamentoRepositorio>(
  (ref) => AcompanhamentoRepositorioFake(),
);

/// Retrato da solicitação em tempo real (Realtime via repositório).
final acompanhamentoProvider = StreamProvider.autoDispose
    .family<AcompanhamentoColeta, String>(
      retry: _semRetentativa,
      (ref, id) => ref.watch(acompanhamentoRepositorioProvider).observar(id),
    );

/// Solicitações ativas e coletadas do gerador (Realtime via repositório), para
/// a home decidir entre acompanhar, avaliar e chamar nova coleta (T6.4).
final solicitacoesAtuaisProvider =
    StreamProvider.autoDispose<List<AcompanhamentoColeta>>(
      retry: _semRetentativa,
      (ref) => ref.watch(acompanhamentoRepositorioProvider).observarAtuais(),
    );

/// Relógio do gerador (contagem regressiva do ETA). Testes injetam um falso.
final relogioGeradorProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Serviço de rotas usado para ETA e linha no mapa. Testes usam o fake.
final servicoRotasGeradorProvider = Provider<ServicoRotas>(
  (ref) => ServicoRotasOsrm(urlBase: Config.osrmBaseUrl),
);

/// Origem (catador) e destino (casa do gerador) de uma rota de atendimento.
typedef TrechoAtendimento = ({LatLng de, LatLng para});

double _arredondar(double v) => (v * 1000).roundToDouble() / 1000;

/// Normaliza o trecho (~100 m) para que pequenos movimentos do catador não
/// disparem uma nova consulta de rota a cada atualização de posição.
TrechoAtendimento trechoAtendimento(LatLng catador, LatLng destino) => (
  de: LatLng(_arredondar(catador.latitude), _arredondar(catador.longitude)),
  para: destino,
);

/// Rota catador -> gerador (polyline + ETA). Não falha: o serviço cai em
/// haversine; qualquer erro vira nulo (a tela só omite ETA e linha).
final rotaAtendimentoProvider = FutureProvider.autoDispose
    .family<RotaCalculada?, TrechoAtendimento>((ref, trecho) async {
      try {
        return await ref
            .watch(servicoRotasGeradorProvider)
            .calcular(trecho.de, const [], trecho.para);
      } catch (_) {
        return null;
      }
    });
