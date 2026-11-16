import 'package:latlong2/latlong.dart';

import 'tamanho_saco.dart';

/// Dados do formulário de solicitação de coleta (UC03).
class DadosSolicitacao {
  const DadosSolicitacao({
    required this.posicao,
    required this.enderecoTexto,
    required this.qtdSacos,
    this.tamanho = TamanhoSaco.m,
    this.materiais = const [],
    this.observacao,
    this.fotoUrl,
    this.agendadaPara,
  });

  final LatLng posicao;
  final String enderecoTexto;
  final int qtdSacos;
  final TamanhoSaco tamanho;

  /// Ids de `materiais`.
  final List<int> materiais;
  final String? observacao;

  /// Preparado para o upload de foto (ainda não há upload na POC).
  final String? fotoUrl;
  final DateTime? agendadaPara;

  static const maxSacos = 20;
  static const maxObservacao = 280;

  /// Limite do RPC `criar_solicitacao` para `endereco_texto`.
  static const maxEndereco = 200;

  /// Endereço sem espaços nas pontas e limitado a [maxEndereco] caracteres
  /// (endereços do Nominatim costumam ser longos; o RPC rejeita > 200).
  String get enderecoNormalizado {
    final t = enderecoTexto.trim();
    if (t.length <= maxEndereco) return t;
    return t.substring(0, maxEndereco).trimRight();
  }

  /// Valida conforme RN01 (espelha o RPC). Devolve a mensagem ou nulo.
  String? validar({DateTime? agora}) {
    final lat = posicao.latitude;
    final lng = posicao.longitude;
    if (lat.isNaN ||
        lng.isNaN ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      return 'Local inválido. Ajuste o pino no mapa.';
    }
    if (enderecoTexto.trim().isEmpty) {
      return 'Informe o endereço de coleta.';
    }
    if (qtdSacos < 1 || qtdSacos > maxSacos) {
      return 'Informe de 1 a $maxSacos sacos.';
    }
    if ((observacao?.length ?? 0) > maxObservacao) {
      return 'A observação pode ter até $maxObservacao caracteres.';
    }
    final a = agendadaPara;
    if (a != null &&
        a.isBefore(
          (agora ?? DateTime.now()).subtract(const Duration(minutes: 5)),
        )) {
      return 'O horário agendado já passou.';
    }
    return null;
  }
}
