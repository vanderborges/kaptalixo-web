import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/config.dart';
import '../../../compartilhado/botao_primario.dart';
import '../../../compartilhado/estados.dart';
import '../../../nucleo/localizacao/falha_localizacao.dart';
import '../dominio/ponto_proximo.dart';
import 'mapa_gerador.dart';
import 'painel_endereco_manual.dart';
import 'providers.dart';

/// Rota do fluxo "Chamar coleta" (T3.2). A posição segue em `extra` (LatLng).
const rotaChamarColeta = '/gerador/chamar';

/// Home do gerador: mapa, pontos próximos e o botão "Chamar coleta".
class TelaHomeGerador extends ConsumerWidget {
  const TelaHomeGerador({super.key, this.tileProvider, this.acoes = const []});

  final TileProvider? tileProvider;

  /// Ações extras da barra (ex.: sair), fornecidas por quem monta a rota.
  final List<Widget> acoes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = ref.watch(localGeradorProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kaptalixo'), actions: acoes),
      body: local.when(
        loading: () =>
            const EstadoCarregando(mensagem: 'Buscando sua localização...'),
        error: (erro, _) => erro is FalhaLocalizacao
            ? _SemLocalizacao(tileProvider: tileProvider)
            : EstadoErro(
                mensagem: 'Não foi possível abrir o mapa.',
                aoTentarNovamente: () =>
                    ref.read(localGeradorProvider.notifier).usarGps(),
              ),
        data: (l) => _ComLocalizacao(local: l, tileProvider: tileProvider),
      ),
    );
  }
}

class _SemLocalizacao extends ConsumerWidget {
  const _SemLocalizacao({this.tileProvider});

  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificador = ref.read(localGeradorProvider.notifier);
    return Column(
      children: [
        Expanded(
          child: MapaGerador(
            centro: LatLng(Config.cidadeDemoLat, Config.cidadeDemoLng),
            tileProvider: tileProvider,
          ),
        ),
        Flexible(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: PainelEnderecoManual(
              aoEscolher: notificador.definirManual,
              aoTentarGps: notificador.usarGps,
            ),
          ),
        ),
      ],
    );
  }
}

class _ComLocalizacao extends ConsumerWidget {
  const _ComLocalizacao({required this.local, this.tileProvider});

  final LocalGerador local;
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pontos = ref.watch(pontosProximosProvider(local.ponto));
    final lista = pontos.asData?.value ?? const <PontoProximo>[];
    return Column(
      children: [
        Expanded(
          child: MapaGerador(
            centro: local.ponto,
            minhaPosicao: local.ponto,
            pontos: lista,
            tileProvider: tileProvider,
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.place_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        local.manual
                            ? (local.rotulo ?? 'Endereço informado')
                            : 'Sua localização atual',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (local.manual)
                      TextButton(
                        onPressed: () =>
                            ref.read(localGeradorProvider.notifier).usarGps(),
                        child: const Text('Usar GPS'),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                _ResumoPontos(pontos: pontos),
                const SizedBox(height: 12),
                BotaoPrimario(
                  rotulo: 'Chamar coleta',
                  icone: Icons.recycling,
                  onPressed: () =>
                      context.push(rotaChamarColeta, extra: local.ponto),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResumoPontos extends StatelessWidget {
  const _ResumoPontos({required this.pontos});

  final AsyncValue<List<PontoProximo>> pontos;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.bodySmall;
    final texto = pontos.when(
      loading: () => 'Procurando pontos de coleta por perto...',
      error: (_, _) => 'Não foi possível mostrar os pontos de coleta.',
      data: (l) => l.isEmpty
          ? 'Nenhum ponto de coleta por perto.'
          : l.length == 1
          ? '1 ponto de coleta por perto'
          : '${l.length} pontos de coleta por perto',
    );
    return Text(texto, style: estilo);
  }
}
