import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dominio/rota_ativa.dart';
import 'rota_providers.dart';

String _mmss(int s) =>
    '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

/// Digitação do PIN (UC08, RN08): o morador informa os 4 dígitos e o catador
/// os digita num teclado grande. O app nunca recebe nem mostra o PIN certo.
class PainelPin extends ConsumerStatefulWidget {
  const PainelPin({super.key, required this.rotaId, required this.parada});

  final String rotaId;
  final ParadaRota parada;

  @override
  ConsumerState<PainelPin> createState() => _EstadoPainelPin();
}

class _EstadoPainelPin extends ConsumerState<PainelPin> {
  String _digitos = '';

  void _digitar(String d) {
    if (_digitos.length < 4) setState(() => _digitos += d);
  }

  void _apagar() {
    if (_digitos.isNotEmpty) {
      setState(() => _digitos = _digitos.substring(0, _digitos.length - 1));
    }
  }

  Future<void> _confirmar() async {
    final pin = _digitos;
    final r = await ref
        .read(rotaProvider(widget.rotaId).notifier)
        .concluir(pin);
    // Erro ou bloqueio: limpa para digitar de novo.
    if (mounted && r != null && !r.ok) setState(() => _digitos = '');
  }

  @override
  Widget build(BuildContext context) {
    final estado = ref.watch(rotaProvider(widget.rotaId));
    final tema = Theme.of(context);
    final bloqueio = estado.segundosBloqueio(widget.parada);
    final bloqueado = bloqueio > 0;
    final ocupado = estado.agindo;
    final tentativas = estado.tentativasRestantes;
    final podeDigitar = !bloqueado && !ocupado;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Peça o PIN ao morador',
          style: tema.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 4; i++)
              Container(
                key: Key('pin-casa-$i'),
                width: 56,
                height: 64,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: bloqueado
                        ? tema.colorScheme.error
                        : tema.colorScheme.outline,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  i < _digitos.length ? _digitos[i] : '',
                  style: tema.textTheme.headlineMedium,
                ),
              ),
          ],
        ),
        if (bloqueado)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'PIN bloqueado. Tente de novo em ${_mmss(bloqueio)}',
              key: const Key('pin-bloqueado'),
              textAlign: TextAlign.center,
              style: tema.textTheme.titleMedium?.copyWith(
                color: tema.colorScheme.error,
              ),
            ),
          )
        else if (tentativas != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              tentativas == 1
                  ? 'PIN incorreto. Resta 1 tentativa.'
                  : 'PIN incorreto. Restam $tentativas tentativas.',
              key: const Key('pin-incorreto'),
              textAlign: TextAlign.center,
              style: tema.textTheme.titleMedium?.copyWith(
                color: tema.colorScheme.error,
              ),
            ),
          ),
        const SizedBox(height: 8),
        for (final linha in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          _LinhaTeclas(
            teclas: [
              for (final d in linha)
                _Tecla(
                  chave: Key('tecla-$d'),
                  rotulo: d,
                  aoToque: podeDigitar ? () => _digitar(d) : null,
                ),
            ],
          ),
        _LinhaTeclas(
          teclas: [
            const SizedBox.shrink(),
            _Tecla(
              chave: const Key('tecla-0'),
              rotulo: '0',
              aoToque: podeDigitar ? () => _digitar('0') : null,
            ),
            _Tecla(
              chave: const Key('tecla-apagar'),
              icone: Icons.backspace_outlined,
              semantica: 'Apagar',
              aoToque: podeDigitar ? _apagar : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 72,
          child: FilledButton(
            key: const Key('confirmar-pin'),
            onPressed: podeDigitar && _digitos.length == 4 ? _confirmar : null,
            child: ocupado
                ? const CircularProgressIndicator()
                : Text(
                    'Confirmar coleta',
                    style: tema.textTheme.headlineSmall?.copyWith(
                      color: tema.colorScheme.onPrimary,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _LinhaTeclas extends StatelessWidget {
  const _LinhaTeclas({required this.teclas});

  final List<Widget> teclas;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        for (final t in teclas)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: SizedBox(height: 56, child: t),
            ),
          ),
      ],
    ),
  );
}

class _Tecla extends StatelessWidget {
  const _Tecla({
    required this.chave,
    this.rotulo,
    this.icone,
    this.semantica,
    required this.aoToque,
  });

  final Key chave;
  final String? rotulo;
  final IconData? icone;
  final String? semantica;
  final VoidCallback? aoToque;

  @override
  Widget build(BuildContext context) => FilledButton.tonal(
    key: chave,
    onPressed: aoToque,
    child: icone != null
        ? Icon(icone, semanticLabel: semantica)
        : Text(rotulo!, style: Theme.of(context).textTheme.headlineSmall),
  );
}
