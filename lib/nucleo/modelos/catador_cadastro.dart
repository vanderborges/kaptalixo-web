import 'status_cadastro.dart';
import 'tipo_catador.dart';

/// Cadastro de catador como o admin enxerga (`catadores` + `perfis`).
class CatadorCadastro {
  const CatadorCadastro({
    required this.id,
    required this.nome,
    required this.tipo,
    required this.statusCadastro,
    this.telefone,
    this.documento,
    this.razaoSocial,
    this.tipoVeiculo,
    this.capacidadeSacos,
  });

  /// Formato da consulta com junção: `catadores` com `perfis(nome, telefone)`.
  factory CatadorCadastro.fromJson(Map<String, dynamic> json) {
    final perfil = (json['perfis'] as Map?)?.cast<String, dynamic>() ?? {};
    return CatadorCadastro(
      id: json['perfil_id'] as String,
      nome: (perfil['nome'] as String?) ?? '',
      telefone: perfil['telefone'] as String?,
      tipo: TipoCatador.deTexto(json['tipo'] as String),
      documento: json['documento'] as String?,
      razaoSocial: json['razao_social'] as String?,
      statusCadastro: StatusCadastro.deTexto(json['status_cadastro'] as String),
      tipoVeiculo: json['tipo_veiculo'] as String?,
      capacidadeSacos: json['capacidade_sacos'] as int?,
    );
  }

  final String id;
  final String nome;
  final String? telefone;
  final TipoCatador tipo;
  final String? documento;
  final String? razaoSocial;
  final StatusCadastro statusCadastro;
  final String? tipoVeiculo;
  final int? capacidadeSacos;

  Map<String, dynamic> toJson() => {
    'perfil_id': id,
    'perfis': {'nome': nome, 'telefone': telefone},
    'tipo': tipo.paraTexto(),
    'documento': documento,
    'razao_social': razaoSocial,
    'status_cadastro': statusCadastro.paraTexto(),
    'tipo_veiculo': tipoVeiculo,
    'capacidade_sacos': capacidadeSacos,
  };

  CatadorCadastro comStatus(StatusCadastro novo) => CatadorCadastro(
    id: id,
    nome: nome,
    telefone: telefone,
    tipo: tipo,
    documento: documento,
    razaoSocial: razaoSocial,
    statusCadastro: novo,
    tipoVeiculo: tipoVeiculo,
    capacidadeSacos: capacidadeSacos,
  );

  @override
  bool operator ==(Object other) =>
      other is CatadorCadastro &&
      other.id == id &&
      other.nome == nome &&
      other.telefone == telefone &&
      other.tipo == tipo &&
      other.documento == documento &&
      other.razaoSocial == razaoSocial &&
      other.statusCadastro == statusCadastro &&
      other.tipoVeiculo == tipoVeiculo &&
      other.capacidadeSacos == capacidadeSacos;

  @override
  int get hashCode => Object.hash(
    id,
    nome,
    telefone,
    tipo,
    documento,
    razaoSocial,
    statusCadastro,
    tipoVeiculo,
    capacidadeSacos,
  );
}
