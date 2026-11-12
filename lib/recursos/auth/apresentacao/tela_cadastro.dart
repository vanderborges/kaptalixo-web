import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../compartilhado/botao_primario.dart';
import '../../../compartilhado/campo_texto.dart';
import '../../../nucleo/modelos/papel.dart';
import '../../../nucleo/modelos/tipo_catador.dart';
import '../dominio/dados_cadastro.dart';
import '../dominio/falha_auth.dart';
import '../dominio/validadores.dart';
import 'providers.dart';

/// Materiais com preço informável no cadastro do ponto (`materiais.codigo`).
const materiaisDoPonto = <String, String>{
  'papel': 'Papel',
  'papelao': 'Papelão',
  'pet': 'PET',
  'plastico_duro': 'Plástico duro',
  'vidro': 'Vidro',
  'aluminio': 'Alumínio',
  'ferro': 'Ferro',
};

/// Cadastro por papel (UC01).
class TelaCadastro extends ConsumerStatefulWidget {
  const TelaCadastro({super.key});

  @override
  ConsumerState<TelaCadastro> createState() => _TelaCadastroState();
}

class _TelaCadastroState extends ConsumerState<TelaCadastro> {
  final _formulario = GlobalKey<FormState>();
  Papel? _papel;
  TipoCatador _tipo = TipoCatador.pessoa;
  bool _carregando = false;
  String? _erro;

  final _nome = TextEditingController();
  final _email = TextEditingController();
  final _senha = TextEditingController();
  final _telefone = TextEditingController();
  // catador
  final _documento = TextEditingController();
  final _razaoSocial = TextEditingController();
  final _veiculo = TextEditingController();
  final _capacidade = TextEditingController();
  // ponto
  final _nomePonto = TextEditingController();
  final _logradouro = TextEditingController();
  final _cidade = TextEditingController();
  final _uf = TextEditingController();
  final _abre = TextEditingController(text: '08:00');
  final _fecha = TextEditingController(text: '17:00');
  final _precos = {
    for (final c in materiaisDoPonto.keys) c: TextEditingController(),
  };

  @override
  void dispose() {
    for (final c in [
      _nome,
      _email,
      _senha,
      _telefone,
      _documento,
      _razaoSocial,
      _veiculo,
      _capacidade,
      _nomePonto,
      _logradouro,
      _cidade,
      _uf,
      _abre,
      _fecha,
      ..._precos.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  DadosCadastro _montar(Papel papel) {
    final telefone = _telefone.text.trim();
    switch (papel) {
      case Papel.catador:
        return CadastroCatador(
          nome: _nome.text.trim(),
          email: _email.text.trim(),
          senha: _senha.text,
          telefone: telefone,
          tipo: _tipo,
          documento: _documento.text.trim(),
          razaoSocial: _tipo == TipoCatador.empresa
              ? _razaoSocial.text.trim()
              : null,
          tipoVeiculo: _veiculo.text.trim(),
          capacidadeSacos: int.parse(_capacidade.text.trim()),
        );
      case Papel.ponto:
        return CadastroPonto(
          nome: _nome.text.trim(),
          email: _email.text.trim(),
          senha: _senha.text,
          telefone: telefone,
          nomePonto: _nomePonto.text.trim(),
          logradouro: _logradouro.text.trim(),
          cidade: _cidade.text.trim(),
          uf: _uf.text.trim().toUpperCase(),
          horarioAbertura: _abre.text.trim(),
          horarioFechamento: _fecha.text.trim(),
          precosPorMaterial: {
            for (final e in _precos.entries)
              if (e.value.text.trim().isNotEmpty)
                e.key: double.parse(e.value.text.trim().replaceAll(',', '.')),
          },
        );
      case Papel.gerador || Papel.admin:
        return CadastroGerador(
          nome: _nome.text.trim(),
          email: _email.text.trim(),
          senha: _senha.text,
          telefone: telefone,
        );
    }
  }

  Future<void> _cadastrar() async {
    final papel = _papel;
    if (papel == null) {
      setState(() => _erro = 'Escolha como você vai usar o Kaptalixo.');
      return;
    }
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      await ref.read(authRepositorioProvider).cadastrar(_montar(papel));
      // O roteador leva à home do papel (ou à espera de aprovação do catador).
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

  List<Widget> _camposCatador() => [
    SegmentedButton<TipoCatador>(
      segments: [
        for (final t in TipoCatador.values)
          ButtonSegment(value: t, label: Text(t.rotulo)),
      ],
      selected: {_tipo},
      onSelectionChanged: (s) => setState(() => _tipo = s.first),
    ),
    const SizedBox(height: 12),
    if (_tipo == TipoCatador.empresa)
      CampoTexto(
        controlador: _razaoSocial,
        rotulo: 'Razão social',
        validador: (v) => validarObrigatorio(v, 'a razão social'),
      ),
    CampoTexto(
      controlador: _documento,
      rotulo: _tipo == TipoCatador.empresa ? 'CNPJ' : 'CPF',
      tipoTeclado: TextInputType.number,
      validador: (v) => validarObrigatorio(v, 'o documento'),
    ),
    CampoTexto(
      controlador: _veiculo,
      rotulo: 'Veículo',
      ajuda: 'Ex.: carrinho, bicicleta, moto, utilitário',
      validador: (v) => validarObrigatorio(v, 'o veículo'),
    ),
    CampoTexto(
      controlador: _capacidade,
      rotulo: 'Capacidade (sacos)',
      tipoTeclado: TextInputType.number,
      validador: validarCapacidade,
    ),
  ];

  List<Widget> _camposPonto() => [
    CampoTexto(
      controlador: _nomePonto,
      rotulo: 'Nome do ponto',
      validador: (v) => validarObrigatorio(v, 'o nome do ponto'),
    ),
    CampoTexto(
      controlador: _logradouro,
      rotulo: 'Endereço',
      validador: (v) => validarObrigatorio(v, 'o endereço'),
    ),
    CampoTexto(
      controlador: _cidade,
      rotulo: 'Cidade',
      validador: (v) => validarObrigatorio(v, 'a cidade'),
    ),
    CampoTexto(
      controlador: _uf,
      rotulo: 'UF',
      validador: (v) => (v ?? '').trim().length == 2 ? null : 'Informe a UF.',
    ),
    CampoTexto(
      controlador: _abre,
      rotulo: 'Abre às (seg a sex)',
      validador: validarHorario,
    ),
    CampoTexto(
      controlador: _fecha,
      rotulo: 'Fecha às',
      validador: validarHorario,
    ),
    for (final e in materiaisDoPonto.entries)
      CampoTexto(
        controlador: _precos[e.key]!,
        rotulo: 'Preço do ${e.value} (R\$/kg)',
        tipoTeclado: const TextInputType.numberWithOptions(decimal: true),
        validador: validarPreco,
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final papeis = ref.watch(papeisCadastraveisProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar conta'),
        leading: IconButton(
          tooltip: 'Voltar',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/entrar'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: _formulario,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Como você vai usar o Kaptalixo?',
                  style: tema.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final p in papeis)
                      ChoiceChip(
                        label: Text(p.rotulo),
                        selected: _papel == p,
                        onSelected: (_) => setState(() {
                          _papel = p;
                          _erro = null;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_papel != null) ...[
                  CampoTexto(
                    controlador: _nome,
                    rotulo: 'Nome',
                    validador: (v) => validarObrigatorio(v, 'o nome'),
                  ),
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
                    ajuda: 'Mínimo de $tamanhoMinimoSenha caracteres',
                    validador: validarSenha,
                  ),
                  CampoTexto(
                    controlador: _telefone,
                    rotulo: 'Telefone',
                    tipoTeclado: TextInputType.phone,
                    validador: (v) => validarObrigatorio(v, 'o telefone'),
                  ),
                  if (_papel == Papel.catador) ..._camposCatador(),
                  if (_papel == Papel.ponto) ..._camposPonto(),
                ],
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
                  rotulo: 'Criar conta',
                  carregando: _carregando,
                  onPressed: _cadastrar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
