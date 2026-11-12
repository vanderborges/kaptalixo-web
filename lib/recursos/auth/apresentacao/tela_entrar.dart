import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../compartilhado/botao_primario.dart';
import '../../../compartilhado/campo_texto.dart';
import '../dominio/falha_auth.dart';
import '../dominio/validadores.dart';
import 'providers.dart';

/// Tela de login por e-mail e senha.
class TelaEntrar extends ConsumerStatefulWidget {
  const TelaEntrar({super.key});

  @override
  ConsumerState<TelaEntrar> createState() => _TelaEntrarState();
}

class _TelaEntrarState extends ConsumerState<TelaEntrar> {
  final _formulario = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  bool _carregando = false;
  String? _erro;

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await ref
          .read(authRepositorioProvider)
          .entrar(email: _email.text, senha: _senha.text);
      // O roteador redireciona sozinho quando a sessão muda.
    } on FalhaAuth catch (e) {
      if (mounted) setState(() => _erro = e.mensagem);
    } catch (_) {
      if (mounted) {
        setState(
          () => _erro = const FalhaAuth(CodigoFalhaAuth.desconhecida).mensagem,
        );
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Entrar')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formulario,
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                Icon(
                  Icons.recycling,
                  size: 72,
                  color: tema.colorScheme.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  'Kaptalixo',
                  textAlign: TextAlign.center,
                  style: tema.textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Coleta de recicláveis perto de você',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                CampoTexto(
                  controlador: _email,
                  rotulo: 'E-mail',
                  tipoTeclado: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validador: validarEmail,
                ),
                CampoTexto(
                  controlador: _senha,
                  rotulo: 'Senha',
                  obscuro: true,
                  autofillHints: const [AutofillHints.password],
                  acaoTeclado: TextInputAction.done,
                  validador: (v) =>
                      (v == null || v.isEmpty) ? 'Informe a senha.' : null,
                ),
                if (_erro != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _erro!,
                      key: const Key('erro_auth'),
                      style: TextStyle(color: tema.colorScheme.error),
                    ),
                  ),
                BotaoPrimario(
                  rotulo: 'Entrar',
                  carregando: _carregando,
                  onPressed: _entrar,
                ),
                const SizedBox(height: 12),
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: _carregando
                      ? null
                      : () => context.go('/cadastrar'),
                  child: const Text('Criar conta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
