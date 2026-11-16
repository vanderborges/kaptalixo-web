import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartilhado/botao_primario.dart';
import '../../../compartilhado/estados.dart';
import '../dominio/acompanhamento_coleta.dart';
import '../dominio/falha_gerador.dart';
import 'cartao_catador.dart';
import 'cartao_pin.dart';
import 'dialogo_cancelar.dart';
import 'mapa_acompanhamento.dart';
import 'providers.dart';
import 'texto_status.dart';
import 'tela_buscando_catador.dart';

/// Acompanhamento em tempo real (UC09). Uma única rota que, conforme o status
/// (Realtime), mostra: buscando -> mapa com catador/PIN -> concluída.
class TelaAcompanhamento extends ConsumerStatefulWidget {
  const TelaAcompanhamento({
    super.key,
    required this.solicitacaoId,
    this.aoSair,
    this.aoAvaliar,
    this.aoNovaChamada,
    this.tileProvider,
  });

  final String solicitacaoId;

  /// Volta ao início (padrão: fecha a tela).
  final VoidCallback? aoSair;

  /// Ponto de extensão da T3.4: abre a avaliação da coleta concluída.
  final void Function(String solicitacaoId)? aoAvaliar;

  /// Chamar de novo após `sem_catador` (padrão: [aoSair]).
  final VoidCallback? aoNovaChamada;
  final TileProvider? tileProvider;

  @override
  ConsumerState<TelaAcompanhamento> createState() => _EstadoTela();
}

class _EstadoTela extends ConsumerState<TelaAcompanhamento> {
  bool _cancelando = false;

  void _sair() {
    if (widget.aoSair != null) {
      widget.aoSair!();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _cancelar(AcompanhamentoColeta c) async {
    final motivo = await confirmarCancelamento(
      context,
      comCatador: c.status.comCatador,
    );
    if (motivo == null || !mounted) return;
    setState(() => _cancelando = true);
    try {
      await ref
          .read(acompanhamentoRepositorioProvider)
          .cancelar(widget.solicitacaoId, motivo: motivo);
    } on FalhaGerador catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.mensagem)));
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(acompanhamentoProvider(widget.solicitacaoId));
    return estado.when(
      skipError: true,
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Sua coleta')),
        body: const EstadoCarregando(mensagem: 'Carregando sua coleta...'),
      ),
      // skipError: um erro de rede depois de um retrato mantém o retrato.
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Sua coleta')),
        body: EstadoErro(
          mensagem: e is FalhaGerador
              ? e.mensagem
              : 'Não foi possível acompanhar sua coleta.',
          aoTentarNovamente: () =>
              ref.invalidate(acompanhamentoProvider(widget.solicitacaoId)),
        ),
      ),
      data: (c) => switch (c.status) {
        StatusColeta.buscando => TelaBuscandoCatador(
          coleta: c,
          cancelando: _cancelando,
          aoCancelar: () => _cancelar(c),
        ),
        StatusColeta.aceita ||
        StatusColeta.aCaminho ||
        StatusColeta.noLocal => _CorpoAtendimento(
          coleta: c,
          cancelando: _cancelando,
          aoCancelar: () => _cancelar(c),
          tileProvider: widget.tileProvider,
        ),
        StatusColeta.coletada || StatusColeta.entregue => _Encerrada(
          coleta: c,
          icone: Icons.check_circle,
          acaoRotulo: widget.aoAvaliar == null ? null : 'Avaliar o catador',
          aoAcao: () => widget.aoAvaliar?.call(c.id),
          aoSair: _sair,
        ),
        StatusColeta.cancelada => _Encerrada(
          coleta: c,
          icone: Icons.cancel_outlined,
          aoSair: _sair,
        ),
        StatusColeta.semCatador => _Encerrada(
          coleta: c,
          icone: Icons.search_off,
          acaoRotulo: 'Chamar de novo',
          aoAcao: widget.aoNovaChamada ?? _sair,
          aoSair: _sair,
        ),
      },
    );
  }
}

class _CorpoAtendimento extends ConsumerWidget {
  const _CorpoAtendimento({
    required this.coleta,
    required this.aoCancelar,
    required this.cancelando,
    this.tileProvider,
  });

  final AcompanhamentoColeta coleta;
  final VoidCallback aoCancelar;
  final bool cancelando;
  final TileProvider? tileProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catador = coleta.catador;
    final posicao = catador?.posicao;
    final rota = posicao == null
        ? null
        : ref
              .watch(
                rotaAtendimentoProvider(
                  trechoAtendimento(posicao, coleta.local),
                ),
              )
              .value;
    final eta = coleta.status == StatusColeta.noLocal
        ? null
        : rota?.duracaoSegundos;
    final tema = Theme.of(context);
    final subtitulo = subtituloStatus(coleta, etaSegundos: eta);
    return Scaffold(
      appBar: AppBar(title: const Text('Sua coleta')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: MapaAcompanhamento(
                local: coleta.local,
                catador: posicao,
                trajeto: rota?.geometria ?? const [],
                tileProvider: tileProvider,
              ),
            ),
            Expanded(
              flex: 3,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    tituloStatus(coleta, etaSegundos: eta),
                    key: const Key('titulo_status'),
                    style: tema.textTheme.headlineSmall,
                  ),
                  if (subtitulo != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitulo, style: tema.textTheme.bodyLarge),
                  ],
                  const SizedBox(height: 12),
                  if (catador != null) CartaoCatador(catador: catador),
                  if (coleta.pin != null) ...[
                    const SizedBox(height: 12),
                    CartaoPin(pin: coleta.pin!),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    '${coleta.qtdSacos} ${coleta.qtdSacos == 1 ? 'saco' : 'sacos'} em ${coleta.enderecoTexto}',
                    style: tema.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: cancelando ? null : aoCancelar,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancelar coleta'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Encerrada extends StatelessWidget {
  const _Encerrada({
    required this.coleta,
    required this.icone,
    required this.aoSair,
    this.acaoRotulo,
    this.aoAcao,
  });

  final AcompanhamentoColeta coleta;
  final IconData icone;
  final VoidCallback aoSair;
  final String? acaoRotulo;
  final VoidCallback? aoAcao;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final subtitulo = subtituloStatus(coleta);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sua coleta'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(icone, size: 72, color: tema.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                tituloStatus(coleta),
                key: const Key('titulo_status'),
                textAlign: TextAlign.center,
                style: tema.textTheme.headlineSmall,
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitulo,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyLarge,
                ),
              ],
              const Spacer(),
              if (acaoRotulo != null && aoAcao != null) ...[
                BotaoPrimario(rotulo: acaoRotulo!, onPressed: aoAcao),
                const SizedBox(height: 8),
              ],
              OutlinedButton(
                onPressed: aoSair,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 48),
                ),
                child: const Text('Voltar ao início'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
