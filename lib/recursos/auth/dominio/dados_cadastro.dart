import '../../../nucleo/modelos/papel.dart';
import '../../../nucleo/modelos/tipo_catador.dart';

/// Dados de cadastro (UC01). Subclasses acrescentam os campos do papel.
sealed class DadosCadastro {
  const DadosCadastro({
    required this.nome,
    required this.email,
    required this.senha,
    this.telefone,
  });

  final String nome;
  final String email;
  final String senha;
  final String? telefone;

  Papel get papel;

  /// Linha para `perfis` (sem o id, definido pelo Auth).
  Map<String, dynamic> perfilJson() => {
    'papel': papel.paraTexto(),
    'nome': nome,
    if (telefone != null && telefone!.isNotEmpty) 'telefone': telefone,
  };
}

class CadastroGerador extends DadosCadastro {
  const CadastroGerador({
    required super.nome,
    required super.email,
    required super.senha,
    super.telefone,
  });

  @override
  Papel get papel => Papel.gerador;
}

class CadastroCatador extends DadosCadastro {
  const CadastroCatador({
    required super.nome,
    required super.email,
    required super.senha,
    super.telefone,
    required this.tipo,
    required this.documento,
    required this.tipoVeiculo,
    required this.capacidadeSacos,
    this.razaoSocial,
  });

  final TipoCatador tipo;
  final String documento;
  final String? razaoSocial;
  final String tipoVeiculo;
  final int capacidadeSacos;

  @override
  Papel get papel => Papel.catador;

  /// Linha para `catadores` (sem `perfil_id`). `status_cadastro` nasce pendente.
  Map<String, dynamic> catadorJson() => {
    'tipo': tipo.paraTexto(),
    'documento': documento,
    if (razaoSocial != null && razaoSocial!.isNotEmpty)
      'razao_social': razaoSocial,
    'tipo_veiculo': tipoVeiculo,
    'capacidade_sacos': capacidadeSacos,
  };
}

class CadastroPonto extends DadosCadastro {
  const CadastroPonto({
    required super.nome,
    required super.email,
    required super.senha,
    super.telefone,
    required this.nomePonto,
    required this.logradouro,
    required this.cidade,
    required this.uf,
    required this.horarioAbertura,
    required this.horarioFechamento,
    this.precosPorMaterial = const {},
  });

  final String nomePonto;
  final String logradouro;
  final String cidade;
  final String uf;

  /// Formato `HH:mm`; vale de segunda a sexta (simplificação da POC).
  final String horarioAbertura;
  final String horarioFechamento;

  /// Preço por kg indexado por `materiais.codigo` (ex.: `pet`).
  final Map<String, double> precosPorMaterial;

  @override
  Papel get papel => Papel.ponto;

  /// Formato de `pontos_coleta.horario_funcionamento`.
  Map<String, dynamic> horarioJson() => {
    for (final dia in const ['seg', 'ter', 'qua', 'qui', 'sex'])
      dia: [
        [horarioAbertura, horarioFechamento],
      ],
  };

  /// Parâmetros do RPC `cadastrar_ponto` (ver `backlog/PEDIDOS.md`).
  Map<String, dynamic> pontoJson() => {
    'nome_ponto': nomePonto,
    'logradouro': logradouro,
    'cidade': cidade,
    'uf': uf,
    'horario_funcionamento': horarioJson(),
    'precos': precosPorMaterial,
  };
}
