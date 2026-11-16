import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/config.dart';
import '../../../compartilhado/botao_primario.dart';
import '../../../compartilhado/campo_texto.dart';
import '../../../compartilhado/estados.dart';
import '../../../nucleo/mapas/servico_geocodificacao.dart';
import '../dominio/dados_solicitacao.dart';
import '../dominio/falha_solicitacao.dart';
import '../dominio/tamanho_saco.dart';
import 'providers.dart';

/// Formulário "Chamar coleta" (UC03): local, sacos, tamanho, materiais e
/// observação numa única tela. O pino fica no centro; o gerador move o mapa.
class TelaChamarColeta extends ConsumerStatefulWidget {
  const TelaChamarColeta({
    super.key,
    required this.posicaoInicial,
    this.tileProvider,
    this.aoCriada,
  });

  final LatLng posicaoInicial;
  final TileProvider? tileProvider;

  /// Chamado com o id da solicitação criada. Padrão: aviso e volta.
  final void Function(String id)? aoCriada;

  @override
  ConsumerState<TelaChamarColeta> createState() => _EstadoTela();
}

class _EstadoTela extends ConsumerState<TelaChamarColeta> {
  final _mapa = MapController();
  final _endereco = TextEditingController();
  final _observacao = TextEditingController();
  late LatLng _pino = widget.posicaoInicial;
  int _sacos = 1;
  TamanhoSaco _tamanho = TamanhoSaco.m;
  final _materiais = <int>{};
  bool _buscando = false;
  bool _enviando = false;
  String? _erroBusca;
  String? _erro;
  List<ResultadoGeocodificacao> _resultados = const [];
  int _seqReverso = 0;

  @override
  void initState() {
    super.initState();
    _preencherEndereco(_pino);
  }

  @override
  void dispose() {
    _mapa.dispose();
    _endereco.dispose();
    _observacao.dispose();
    super.dispose();
  }

  Future<void> _preencherEndereco(LatLng p) async {
    final seq = ++_seqReverso;
    try {
      final r = await ref
          .read(geocodificacaoProvider)
          .reverso(p.latitude, p.longitude);
      if (!mounted || seq != _seqReverso || r == null) return;
      _endereco.text = r.nome;
    } on ExcecaoGeocodificacao {
      // Mantém o texto atual; o gerador pode digitar o endereço.
    }
  }

  void _aoMoverMapa(MapEvent e) {
    if (e is MapEventMove || e is MapEventMoveEnd) {
      _pino = e.camera.center;
    }
    if (e is MapEventMoveEnd && e.source != MapEventSource.mapController) {
      _preencherEndereco(_pino);
    }
  }

  Future<void> _buscar() async {
    final texto = _endereco.text.trim();
    if (texto.length < 3) {
      setState(() => _erroBusca = 'Digite o endereço (rua e cidade).');
      return;
    }
    setState(() {
      _buscando = true;
      _erroBusca = null;
    });
    try {
      final r = await ref.read(geocodificacaoProvider).buscar(texto);
      if (!mounted) return;
      setState(() {
        _resultados = r.take(4).toList();
        if (r.isEmpty) _erroBusca = 'Nenhum endereço encontrado.';
      });
    } on ExcecaoGeocodificacao {
      if (!mounted) return;
      setState(() => _erroBusca = 'Não foi possível buscar o endereço.');
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _escolher(ResultadoGeocodificacao r) {
    _seqReverso++;
    _endereco.text = r.nome;
    _pino = r.posicao;
    _mapa.move(r.posicao, 16);
    setState(() => _resultados = const []);
  }

  DadosSolicitacao _dados() => DadosSolicitacao(
    posicao: _pino,
    enderecoTexto: _endereco.text,
    qtdSacos: _sacos,
    tamanho: _tamanho,
    materiais: _materiais.toList()..sort(),
    observacao: _observacao.text.trim().isEmpty ? null : _observacao.text,
  );

  Future<void> _enviar() async {
    final dados = _dados();
    final invalido = dados.validar();
    if (invalido != null) {
      setState(() => _erro = invalido);
      return;
    }
    setState(() {
      _enviando = true;
      _erro = null;
    });
    try {
      final id = await ref.read(solicitacaoRepositorioProvider).criar(dados);
      if (!mounted) return;
      if (widget.aoCriada != null) {
        widget.aoCriada!(id);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Coleta chamada!')));
        if (context.canPop()) context.pop();
      }
    } on FalhaSolicitacao catch (f) {
      if (!mounted) return;
      setState(() => _erro = f.mensagem);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _erro = 'Não foi possível chamar a coleta. Tente novamente.',
      );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final materiais = ref.watch(materiaisProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Chamar coleta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('1. Onde buscar?', style: tema.textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text('Mova o mapa para deixar o pino no local exato.'),
          const SizedBox(height: 8),
          SizedBox(
            height: 240,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  FlutterMap(
                    mapController: _mapa,
                    options: MapOptions(
                      initialCenter: widget.posicaoInicial,
                      initialZoom: 16,
                      onMapEvent: _aoMoverMapa,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: Config.tileUrl,
                        userAgentPackageName: 'br.kaptalixo.app',
                        tileProvider: widget.tileProvider,
                      ),
                      const RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                            '© Colaboradores do OpenStreetMap',
                          ),
                        ],
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: Tooltip(
                      message: 'Local da coleta',
                      child: Icon(
                        Icons.location_pin,
                        size: 48,
                        color: tema.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          CampoTexto(
            controlador: _endereco,
            rotulo: 'Endereço',
            acaoTeclado: TextInputAction.search,
          ),
          if (_erroBusca != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _erroBusca!,
                style: TextStyle(color: tema.colorScheme.error),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _buscando ? null : _buscar,
            style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
            icon: const Icon(Icons.search),
            label: Text(_buscando ? 'Buscando...' : 'Buscar endereço'),
          ),
          for (final r in _resultados)
            ListTile(
              leading: const Icon(Icons.place_outlined),
              title: Text(r.nome, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () => _escolher(r),
            ),
          const SizedBox(height: 24),
          Text('2. O que vai ser coletado?', style: tema.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(child: Text('Quantidade de sacos')),
              IconButton.outlined(
                tooltip: 'Menos um saco',
                onPressed: _sacos > 1 ? () => setState(() => _sacos--) : null,
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '$_sacos',
                  key: const Key('qtd-sacos'),
                  textAlign: TextAlign.center,
                  style: tema.textTheme.titleLarge,
                ),
              ),
              IconButton.outlined(
                tooltip: 'Mais um saco',
                onPressed: _sacos < DadosSolicitacao.maxSacos
                    ? () => setState(() => _sacos++)
                    : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<TamanhoSaco>(
            segments: [
              for (final t in TamanhoSaco.values)
                ButtonSegment(value: t, label: Text(t.rotulo)),
            ],
            selected: {_tamanho},
            onSelectionChanged: (s) => setState(() => _tamanho = s.first),
          ),
          const SizedBox(height: 12),
          Text('Materiais (opcional)', style: tema.textTheme.bodyMedium),
          const SizedBox(height: 4),
          materiais.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(8),
              child: LinearProgressIndicator(),
            ),
            error: (_, _) => EstadoErro(
              mensagem: 'Não foi possível carregar os materiais.',
              aoTentarNovamente: () => ref.invalidate(materiaisProvider),
            ),
            data: (lista) => Wrap(
              spacing: 8,
              children: [
                for (final m in lista)
                  FilterChip(
                    label: Text(m.nome),
                    selected: _materiais.contains(m.id),
                    onSelected: (v) => setState(
                      () => v ? _materiais.add(m.id) : _materiais.remove(m.id),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CampoTexto(
            controlador: _observacao,
            rotulo: 'Observação (opcional)',
            ajuda: 'Ex.: portão azul, deixar com o porteiro',
            acaoTeclado: TextInputAction.done,
          ),
          if (_erro != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _erro!,
                key: const Key('erro-envio'),
                style: TextStyle(color: tema.colorScheme.error),
              ),
            ),
          BotaoPrimario(
            rotulo: 'Chamar coleta',
            icone: Icons.recycling,
            carregando: _enviando,
            onPressed: _enviar,
          ),
        ],
      ),
    );
  }
}
