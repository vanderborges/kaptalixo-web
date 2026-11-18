import 'dart:async';

import '../dominio/acompanhamento_coleta.dart';
import '../dominio/acompanhamento_repositorio.dart';
import '../dominio/falha_acompanhamento.dart';

/// Fake com stream controlável: testes chamam [emitir] para simular o Realtime.
class AcompanhamentoRepositorioFake implements AcompanhamentoRepositorio {
  AcompanhamentoRepositorioFake({this.inicial, this.falhaAoCancelar});

  AcompanhamentoColeta? inicial;
  FalhaAcompanhamento? falhaAoCancelar;
  final List<({String id, String? motivo})> cancelamentos = [];
  final _ctrl = StreamController<AcompanhamentoColeta>.broadcast();
  AcompanhamentoColeta? _ultimo;

  /// Número de assinantes ativos (para checar que a tela cancela a assinatura).
  bool get temOuvinte => _ctrl.hasListener;

  void emitir(AcompanhamentoColeta c) {
    _ultimo = c;
    _ctrl.add(c);
  }

  void emitirErro(Object erro) => _ctrl.addError(erro);

  @override
  Stream<AcompanhamentoColeta> observar(String solicitacaoId) async* {
    final atual = _ultimo ?? inicial;
    if (atual != null) yield atual;
    yield* _ctrl.stream;
  }

  /// Lista inicial de [observarAtuais] (vazia por padrão).
  List<AcompanhamentoColeta> atuaisIniciais = const [];
  final _ctrlAtuais = StreamController<List<AcompanhamentoColeta>>.broadcast();
  List<AcompanhamentoColeta>? _ultimosAtuais;

  void emitirAtuais(List<AcompanhamentoColeta> lista) {
    _ultimosAtuais = lista;
    _ctrlAtuais.add(lista);
  }

  void emitirErroAtuais(Object erro) => _ctrlAtuais.addError(erro);

  @override
  Stream<List<AcompanhamentoColeta>> observarAtuais() async* {
    yield _ultimosAtuais ?? atuaisIniciais;
    yield* _ctrlAtuais.stream;
  }

  @override
  Future<void> cancelar(String solicitacaoId, {String? motivo}) async {
    cancelamentos.add((id: solicitacaoId, motivo: motivo));
    if (falhaAoCancelar != null) throw falhaAoCancelar!;
    final base = _ultimo ?? inicial;
    if (base != null) {
      emitir(
        AcompanhamentoColeta(
          id: base.id,
          status: StatusColeta.cancelada,
          enderecoTexto: base.enderecoTexto,
          local: base.local,
          qtdSacos: base.qtdSacos,
          motivoCancelamento: motivo ?? 'sem_motivo_informado',
        ),
      );
    }
  }
}
