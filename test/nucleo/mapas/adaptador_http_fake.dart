import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Adaptador que nunca toca a rede: responde com fixtures ou falha.
class AdaptadorHttpFake implements HttpClientAdapter {
  AdaptadorHttpFake(this.respostas);

  /// Cada item: fixture (String com nome do arquivo), `int` (status de erro)
  /// ou [DioExceptionType] (falha de rede). Consumidos em ordem; o ultimo se
  /// repete.
  final List<Object> respostas;
  final List<RequestOptions> requisicoes = [];

  static String fixture(String nome) =>
      File('test/fixtures/$nome').readAsStringSync();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final i = requisicoes.length;
    requisicoes.add(options);
    final r = respostas[i < respostas.length ? i : respostas.length - 1];
    if (r is DioExceptionType) {
      throw DioException(requestOptions: options, type: r);
    }
    final headers = {
      Headers.contentTypeHeader: ['application/json'],
    };
    if (r is int) {
      return ResponseBody.fromString('{}', r, headers: headers);
    }
    return ResponseBody.fromString(
      jsonEncode(jsonDecode(fixture(r as String))),
      200,
      headers: headers,
    );
  }

  @override
  void close({bool force = false}) {}
}
