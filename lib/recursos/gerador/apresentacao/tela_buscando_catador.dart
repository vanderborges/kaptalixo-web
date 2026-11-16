import 'package:flutter/material.dart';

import '../../../compartilhado/botao_primario.dart';
import '../dominio/acompanhamento_coleta.dart';
import 'texto_status.dart';

/// Tela "Buscando catador" (UC09/UC04): mostra a tentativa atual e permite
/// cancelar. Quando um catador aceita, [TelaAcompanhamento] troca de tela.
class TelaBuscandoCatador extends StatelessWidget {
  const TelaBuscandoCatador({
    super.key,
    required this.coleta,
    required this.aoCancelar,
    this.cancelando = false,
  });

  final AcompanhamentoColeta coleta;
  final VoidCallback aoCancelar;
  final bool cancelando;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final subtitulo = subtituloStatus(coleta);
    return Scaffold(
      appBar: AppBar(title: const Text('Chamando coleta')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const SizedBox.square(
                dimension: 72,
                child: CircularProgressIndicator(strokeWidth: 6),
              ),
              const SizedBox(height: 32),
              Text(
                tituloStatus(coleta),
                textAlign: TextAlign.center,
                style: tema.textTheme.headlineSmall,
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitulo,
                  key: const Key('subtitulo_busca'),
                  textAlign: TextAlign.center,
                  style: tema.textTheme.bodyLarge,
                ),
              ],
              const SizedBox(height: 24),
              Text(
                '${coleta.qtdSacos} ${coleta.qtdSacos == 1 ? 'saco' : 'sacos'} em ${coleta.enderecoTexto}',
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyMedium,
              ),
              const Spacer(),
              BotaoPrimario(
                rotulo: 'Cancelar pedido',
                icone: Icons.close,
                carregando: cancelando,
                onPressed: aoCancelar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
