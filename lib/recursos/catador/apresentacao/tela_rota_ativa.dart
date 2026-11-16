import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartilhado/estados.dart';
import '../dominio/rota_ativa.dart';
import 'mapa_rota.dart';
import 'painel_pin.dart';
import 'rota_providers.dart';

String _distancia(double m) => m >= 1000
    ? '${(m / 1000).toStringAsFixed(1).replaceAll('.', ',')} km'
    : '${m.round()} m';

String _tempo(int s) => s < 60 ? 'menos de 1 min' : '${(s / 60).round()} min';

/// Motivos oferecidos ao pular uma parada (UC08, máx. 200 caracteres).
const motivosPular = [
  'Gerador ausente',
  'Não atendeu',
  'Endereço não encontrado',
];

/// Rota ativa do catador (UC08): mapa, próxima parada com ETA, Iniciar rota,
/// Cheguei, PIN, Pular parada e troca do ponto de descarte. Uma ação óbvia
/// por vez, botões grandes e pouco texto.
class TelaRotaAtiva extends ConsumerWidget {
  const TelaRotaAtiva({
    super.key,
    required this.rotaId,
    this.aoSair,
    this.acoes = const [],
    this.tileProvider,
  });

  final String rotaId;

  /// Volta ao início (rota concluída/cancelada ou não encontrada).
  final VoidCallback? aoSair;
  final List<Widget> acoes;
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estado = ref.watch(rotaProvider(rotaId));
    final rota = estado.rota;

    Widget corpo;
    if (estado.carregando) {
      corpo = const EstadoCarregando(mensagem: 'Carregando sua rota...');
    } else if (rota == null && estado.erro != null) {
      corpo = EstadoErro(
        mensagem: estado.erro!,
        aoTentarNovamente: () =>
            ref.read(rotaProvider(rotaId).notifier).tentarNovamente(),
      );
    } else if (rota == null) {
      corpo = EstadoVazio(
        mensagem: 'Rota não encontrada.',
        acao: aoSair == null
            ? null
            : OutlinedButton(
                onPressed: aoSair,
                child: const Text('Voltar ao início'),
              ),
      );
    } else {
      corpo = Column(
        children: [
          Expanded(
            flex: 2,
            child: MapaRota(
              rota: rota,
              posicao: estado.posicao,
              tileProvider: tileProvider,
            ),
          ),
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _Painel(
                rotaId: rotaId,
                rota: rota,
                estado: estado,
                aoSair: aoSair,
              ),
            ),
          ),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sua rota'), actions: acoes),
      body: corpo,
    );
  }
}

class _Painel extends ConsumerWidget {
  const _Painel({
    required this.rotaId,
    required this.rota,
    required this.estado,
    required this.aoSair,
  });

  final String rotaId;
  final RotaAtiva rota;
  final EstadoRota estado;
  final VoidCallback? aoSair;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final notifier = ref.read(rotaProvider(rotaId).notifier);
    final proxima = rota.proxima;
    final ocupado = estado.agindo;

    final filhos = <Widget>[
      if (estado.aviso != null)
        Card(
          color: tema.colorScheme.errorContainer,
          child: ListTile(
            key: const Key('aviso-rota'),
            title: Text(estado.aviso!, style: tema.textTheme.titleMedium),
            trailing: IconButton(
              tooltip: 'Fechar aviso',
              icon: const Icon(Icons.close),
              onPressed: notifier.limparAviso,
            ),
          ),
        ),
    ];

    switch (rota.status) {
      case StatusRota.concluida:
        filhos.addAll(
          _final(context, Icons.check_circle, 'Rota concluída', aoSair),
        );
      case StatusRota.cancelada:
        filhos.addAll(
          _final(context, Icons.info_outline, 'Rota encerrada', aoSair),
        );
      case StatusRota.planejada:
        final km = (rota.distanciaTotalM ?? 0) / 1000;
        filhos.addAll([
          Text(
            rota.coletasRestantes == 1
                ? '1 coleta'
                : '${rota.coletasRestantes} coletas',
            style: tema.textTheme.displaySmall,
            textAlign: TextAlign.center,
          ),
          if (rota.distanciaTotalM != null)
            Text(
              '${km.toStringAsFixed(1).replaceAll('.', ',')} km'
              '${rota.duracaoTotalS != null ? ' · ${_tempo(rota.duracaoTotalS!)}' : ''}',
              style: tema.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 16),
          _BotaoGrande(
            chave: const Key('iniciar-rota'),
            rotulo: 'Iniciar rota',
            altura: 96,
            carregando: ocupado,
            aoToque: ocupado ? null : notifier.iniciar,
          ),
          ..._trocarPonto(context, ref),
        ]);
      case StatusRota.emAndamento:
        if (proxima == null) {
          filhos.add(
            Text(
              'Sem paradas pendentes.',
              style: tema.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          );
        } else if (proxima.ehColeta) {
          filhos.addAll(_coleta(context, ref, proxima));
        } else {
          filhos.addAll(_descarte(context, ref, proxima));
        }
    }

    if (rota.status.aberta && estado.semPosicao) {
      filhos.addAll([
        const SizedBox(height: 12),
        Text(
          'Sem sinal de GPS: sua posição não está sendo enviada.',
          key: const Key('sem-posicao'),
          textAlign: TextAlign.center,
          style: tema.textTheme.bodyMedium,
        ),
      ]);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: filhos,
    );
  }

  List<Widget> _final(
    BuildContext context,
    IconData icone,
    String texto,
    VoidCallback? aoSair,
  ) {
    final tema = Theme.of(context);
    return [
      Icon(icone, size: 64, color: tema.colorScheme.primary),
      Text(
        texto,
        key: const Key('rota-final'),
        style: tema.textTheme.headlineMedium,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      if (aoSair != null)
        _BotaoGrande(
          chave: const Key('voltar-inicio'),
          rotulo: 'Voltar ao início',
          altura: 72,
          aoToque: aoSair,
        ),
    ];
  }

  Widget _resumo(BuildContext context, String titulo, List<String> linhas) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          titulo,
          key: const Key('titulo-parada'),
          style: tema.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        for (final l in linhas)
          Text(
            l,
            style: tema.textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  /// Distância e ETA até a próxima parada.
  String? _deslocamento() {
    final partes = <String>[
      if (estado.distanciaProximaM != null)
        _distancia(estado.distanciaProximaM!),
      if (estado.etaS != null) _tempo(estado.etaS!),
    ];
    return partes.isEmpty ? null : partes.join(' · ');
  }

  List<Widget> _coleta(BuildContext context, WidgetRef ref, ParadaRota p) {
    final notifier = ref.read(rotaProvider(rotaId).notifier);
    final ativas = rota.coletas
        .where((c) => c.status != StatusParada.pulada)
        .length;
    final sacos = p.qtdSacos == null
        ? null
        : (p.qtdSacos == 1 ? '1 saco' : '${p.qtdSacos} sacos');
    final desloc = p.status == StatusParada.noLocal ? null : _deslocamento();
    final ocupado = estado.agindo;

    return [
      _resumo(context, 'Coleta ${rota.numeroColeta(p)} de $ativas', [
        ?p.enderecoTexto,
        ?(p.geradorNome == null && sacos == null
            ? null
            : [?p.geradorNome, ?sacos].join(' · ')),
        ?desloc,
      ]),
      if (p.observacao != null && p.observacao!.isNotEmpty)
        Text(
          p.observacao!,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      const SizedBox(height: 16),
      if (p.status == StatusParada.noLocal)
        PainelPin(rotaId: rotaId, parada: p)
      else
        _BotaoGrande(
          chave: const Key('cheguei'),
          rotulo: 'Cheguei',
          altura: 96,
          carregando: ocupado,
          aoToque: ocupado ? null : notifier.cheguei,
        ),
      const SizedBox(height: 12),
      SizedBox(
        height: 56,
        child: OutlinedButton(
          key: const Key('pular-parada'),
          onPressed: ocupado ? null : () => _pular(context, ref),
          child: const Text('Pular parada'),
        ),
      ),
      ..._trocarPonto(context, ref),
    ];
  }

  List<Widget> _descarte(BuildContext context, WidgetRef ref, ParadaRota p) {
    final notifier = ref.read(rotaProvider(rotaId).notifier);
    final ocupado = estado.agindo;
    if (p.status == StatusParada.noLocal) {
      return [
        _resumo(context, 'No ponto', [p.pontoNome ?? 'Ponto de descarte']),
        const SizedBox(height: 8),
        Text(
          'Aguarde a pesagem do ponto.',
          key: const Key('aguardando-pesagem'),
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
      ];
    }
    final desloc = _deslocamento();
    return [
      _resumo(context, 'Levar ao ponto', [
        p.pontoNome ?? 'Ponto de descarte',
        ?desloc,
      ]),
      const SizedBox(height: 16),
      _BotaoGrande(
        chave: const Key('cheguei'),
        rotulo: 'Cheguei ao ponto',
        altura: 96,
        carregando: ocupado,
        aoToque: ocupado ? null : notifier.cheguei,
      ),
      ..._trocarPonto(context, ref),
    ];
  }

  List<Widget> _trocarPonto(BuildContext context, WidgetRef ref) {
    final d = rota.descarte;
    if (d == null || d.status == StatusParada.noLocal) return const [];
    return [
      const SizedBox(height: 12),
      SizedBox(
        height: 56,
        child: OutlinedButton.icon(
          key: const Key('trocar-ponto'),
          onPressed: estado.agindo ? null : () => _escolherPonto(context, ref),
          icon: const Icon(Icons.swap_horiz),
          label: Text('Ponto: ${d.pontoNome ?? 'descarte'} · Trocar'),
        ),
      ),
    ];
  }

  Future<void> _escolherPonto(BuildContext context, WidgetRef ref) async {
    final id = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: rota.alternativas.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Não há outros pontos disponíveis agora.',
                  key: Key('sem-alternativas'),
                ),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  const ListTile(title: Text('Trocar ponto de descarte')),
                  for (final a in rota.alternativas)
                    ListTile(
                      key: Key('ponto-${a.id}'),
                      minVerticalPadding: 16,
                      leading: const Icon(Icons.recycling),
                      title: Text(a.nome),
                      onTap: () => Navigator.of(ctx).pop(a.id),
                    ),
                ],
              ),
      ),
    );
    if (id != null) {
      await ref.read(rotaProvider(rotaId).notifier).trocarPonto(id);
    }
  }

  Future<void> _pular(BuildContext context, WidgetRef ref) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoPular(),
    );
    if (motivo != null) {
      await ref.read(rotaProvider(rotaId).notifier).pular(motivo);
    }
  }
}

class _DialogoPular extends StatefulWidget {
  const _DialogoPular();

  @override
  State<_DialogoPular> createState() => _EstadoDialogoPular();
}

class _EstadoDialogoPular extends State<_DialogoPular> {
  String _motivo = motivosPular.first;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Pular esta parada?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('A coleta volta para a fila de outro catador.'),
          const SizedBox(height: 8),
          for (final m in motivosPular)
            ListTile(
              key: Key('motivo-$m'),
              minVerticalPadding: 12,
              leading: Icon(
                m == _motivo
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(m),
              onTap: () => setState(() => _motivo = m),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Voltar'),
        ),
        FilledButton(
          key: const Key('confirmar-pular'),
          onPressed: () => Navigator.of(context).pop(_motivo),
          child: const Text('Pular'),
        ),
      ],
    );
  }
}

class _BotaoGrande extends StatelessWidget {
  const _BotaoGrande({
    required this.chave,
    required this.rotulo,
    required this.altura,
    required this.aoToque,
    this.carregando = false,
  });

  final Key chave;
  final String rotulo;
  final double altura;
  final VoidCallback? aoToque;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SizedBox(
      height: math.max(altura, 48),
      child: FilledButton(
        key: chave,
        onPressed: aoToque,
        child: carregando
            ? const CircularProgressIndicator()
            : Text(
                rotulo,
                style: tema.textTheme.headlineSmall?.copyWith(
                  color: tema.colorScheme.onPrimary,
                ),
              ),
      ),
    );
  }
}
