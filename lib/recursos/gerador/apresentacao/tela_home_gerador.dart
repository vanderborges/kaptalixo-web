import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/config.dart';
import '../../../compartilhado/botao_primario.dart';
import '../../../compartilhado/estados.dart';
import '../../../nucleo/localizacao/falha_localizacao.dart';
import '../dominio/acompanhamento_coleta.dart';
import '../dominio/ponto_proximo.dart';
import 'mapa_gerador.dart';
import 'painel_endereco_manual.dart';
import 'providers.dart';
import 'texto_status.dart';

/// Rota do fluxo "Chamar coleta" (T3.2). A posição segue em `extra` (LatLng).
const rotaChamarColeta = '/gerador/chamar';

/// Base da rota de acompanhamento; o id da solicitação vai depois da barra.
const rotaAcompanharColeta = '/gerador/acompanhar';

/// Home do gerador: mapa, pontos próximos e o botão "Chamar coleta".
class TelaHomeGerador extends ConsumerWidget {
  const TelaHomeGerador({
    super.key,
    this.tileProvider,
    this.acoes = const [],
    this.aoAvaliar,
  });

  final TileProvider? tileProvider;

  /// Abre a avaliação de uma coleta feita (UC13). Sem ele, o cartão de coleta
  /// feita aparece sem a ação.
  final void Function(String solicitacaoId)? aoAvaliar;

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
        data: (l) => _ComLocalizacao(
          local: l,
          tileProvider: tileProvider,
          aoAvaliar: aoAvaliar,
        ),
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
  const _ComLocalizacao({
    required this.local,
    this.tileProvider,
    this.aoAvaliar,
  });

  final LocalGerador local;
  final TileProvider? tileProvider;
  final void Function(String solicitacaoId)? aoAvaliar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pontos = ref.watch(pontosProximosProvider(local.ponto));
    final lista = pontos.asData?.value ?? const <PontoProximo>[];
    // Erro/carregando não bloqueia o botão: o servidor recusa se houver ativa.
    final atuais =
        ref.watch(solicitacoesAtuaisProvider).asData?.value ??
        const <AcompanhamentoColeta>[];
    final ativa = atuais.where((c) => c.status.ativa).firstOrNull;
    final coletadas = atuais
        .where((c) => c.status == StatusColeta.coletada)
        .toList();
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
                for (final c in coletadas)
                  _CartaoColetaFeita(
                    coleta: c,
                    aoAvaliar: aoAvaliar == null
                        ? null
                        : () => aoAvaliar!(c.id),
                  ),
                if (ativa != null)
                  _CartaoEmAndamento(
                    coleta: ativa,
                    aoAcompanhar: () =>
                        context.push('$rotaAcompanharColeta/${ativa.id}'),
                  ),
                BotaoPrimario(
                  rotulo: 'Chamar coleta',
                  icone: Icons.recycling,
                  // Só a coleta ativa bloqueia (RN T1.8); coletada libera.
                  onPressed: ativa != null
                      ? null
                      : () =>
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

/// Coleta já feita: o catador segue para o ponto; o gerador pode avaliar e
/// pedir outra coleta.
class _CartaoColetaFeita extends StatelessWidget {
  const _CartaoColetaFeita({required this.coleta, this.aoAvaliar});

  final AcompanhamentoColeta coleta;
  final VoidCallback? aoAvaliar;

  @override
  Widget build(BuildContext context) {
    final nome = coleta.catador?.nome;
    return Card(
      key: Key('coleta-feita-${coleta.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.check_circle),
        title: const Text('Coleta feita, o catador está levando ao ponto'),
        subtitle: Text(
          nome == null
              ? 'Obrigado por reciclar!'
              : 'Obrigado por reciclar! $nome já está com seus sacos.',
        ),
        trailing: aoAvaliar == null
            ? null
            : TextButton(
                onPressed: aoAvaliar,
                child: const Text('Avaliar o catador'),
              ),
      ),
    );
  }
}

/// Pedido ativo: o gerador volta ao acompanhamento em vez de pedir outro.
class _CartaoEmAndamento extends StatelessWidget {
  const _CartaoEmAndamento({required this.coleta, required this.aoAcompanhar});

  final AcompanhamentoColeta coleta;
  final VoidCallback aoAcompanhar;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: Key('coleta-ativa-${coleta.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.local_shipping_outlined),
        title: Text(tituloStatus(coleta)),
        subtitle: const Text('Você já tem uma coleta em andamento.'),
        trailing: TextButton(
          onPressed: aoAcompanhar,
          child: const Text('Acompanhar'),
        ),
      ),
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
