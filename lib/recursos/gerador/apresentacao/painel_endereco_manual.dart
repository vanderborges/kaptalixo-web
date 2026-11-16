import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../compartilhado/botao_primario.dart';
import '../../../compartilhado/campo_texto.dart';
import '../../../nucleo/mapas/servico_geocodificacao.dart';
import 'providers.dart';

/// Pede o endereço quando não há GPS (sem permissão, desligado ou indisponível).
class PainelEnderecoManual extends ConsumerStatefulWidget {
  const PainelEnderecoManual({
    super.key,
    required this.aoEscolher,
    required this.aoTentarGps,
  });

  final void Function(ResultadoGeocodificacao) aoEscolher;
  final VoidCallback aoTentarGps;

  @override
  ConsumerState<PainelEnderecoManual> createState() => _EstadoPainel();
}

class _EstadoPainel extends ConsumerState<PainelEnderecoManual> {
  final _controlador = TextEditingController();
  List<ResultadoGeocodificacao> _resultados = const [];
  bool _buscando = false;
  bool _buscou = false;
  String? _erro;

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final texto = _controlador.text.trim();
    if (texto.length < 3) {
      setState(() => _erro = 'Digite o endereço (rua e cidade).');
      return;
    }
    setState(() {
      _buscando = true;
      _erro = null;
    });
    try {
      final r = await ref.read(geocodificacaoProvider).buscar(texto);
      if (!mounted) return;
      setState(() {
        _resultados = r;
        _buscou = true;
      });
    } on ExcecaoGeocodificacao {
      if (!mounted) return;
      setState(
        () => _erro = 'Não foi possível buscar o endereço. Tente de novo.',
      );
    } finally {
      if (mounted) setState(() => _buscando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Não conseguimos pegar sua localização',
          style: tema.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        const Text('Digite o endereço onde o catador deve buscar os sacos.'),
        const SizedBox(height: 12),
        CampoTexto(
          controlador: _controlador,
          rotulo: 'Endereço',
          acaoTeclado: TextInputAction.search,
        ),
        if (_erro != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _erro!,
              style: TextStyle(color: tema.colorScheme.error),
            ),
          ),
        BotaoPrimario(
          rotulo: 'Buscar endereço',
          icone: Icons.search,
          carregando: _buscando,
          onPressed: _buscar,
        ),
        if (_buscou && _resultados.isEmpty && !_buscando)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Nenhum endereço encontrado. Confira o texto.'),
          ),
        for (final r in _resultados.take(4))
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: Text(r.nome, maxLines: 2, overflow: TextOverflow.ellipsis),
            onTap: () => widget.aoEscolher(r),
          ),
        TextButton(
          onPressed: widget.aoTentarGps,
          child: const Text('Tentar usar minha localização'),
        ),
      ],
    );
  }
}
