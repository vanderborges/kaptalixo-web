import 'dart:async';

import 'package:latlong2/latlong.dart';

import 'falha_localizacao.dart';
import 'posicao.dart';
import 'servico_localizacao.dart';

/// Fake para testes: emite o que for passado a [emitir].
class LocalizacaoFake implements ServicoLocalizacao {
  LocalizacaoFake({Posicao? inicial, this.falha}) : _atual = inicial;

  Posicao? _atual;
  FalhaLocalizacao? falha;
  final _controle = StreamController<Posicao>.broadcast();

  void emitir(Posicao posicao) {
    _atual = posicao;
    _controle.add(posicao);
  }

  void emitirPonto(LatLng ponto, {DateTime? instante}) =>
      emitir(Posicao(ponto: ponto, instante: instante ?? DateTime.now()));

  @override
  Future<Posicao> atual() async {
    if (falha != null) throw falha!;
    final p = _atual;
    if (p == null) {
      throw const FalhaLocalizacao(MotivoFalhaLocalizacao.indisponivel);
    }
    return p;
  }

  @override
  Stream<Posicao> posicoes() {
    if (falha != null) return Stream.error(falha!);
    return _controle.stream;
  }

  Future<void> fechar() => _controle.close();
}
