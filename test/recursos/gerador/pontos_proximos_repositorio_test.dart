import 'package:flutter_test/flutter_test.dart';
import 'package:kaptalixo/recursos/gerador/dados/pontos_proximos_remoto.dart';
import 'package:kaptalixo/recursos/gerador/dados/pontos_proximos_repositorio_impl.dart';
import 'package:kaptalixo/recursos/gerador/dominio/falha_gerador.dart';
import 'package:latlong2/latlong.dart';

class _Remoto implements PontosProximosRemoto {
  _Remoto(this.linhas, {this.erro});
  final List<Map<String, dynamic>> linhas;
  final Object? erro;

  @override
  Future<List<Map<String, dynamic>>> proximos(
    double lat,
    double lng,
    double raio,
  ) async {
    if (erro != null) throw erro!;
    return linhas;
  }
}

void main() {
  const centro = LatLng(-23.55, -46.63);

  test('converte linhas do RPC em PontoProximo', () async {
    final repo = PontosProximosRepositorioImpl(
      _Remoto([
        {
          'id': 'a',
          'nome': 'Ecoponto',
          'lat': -23.5,
          'lng': -46.6,
          'distancia_m': 350,
          'aberto': true,
        },
      ]),
    );
    final r = await repo.proximos(centro);
    expect(r.single.nome, 'Ecoponto');
    expect(r.single.posicao, const LatLng(-23.5, -46.6));
    expect(r.single.distanciaMetros, 350);
    expect(r.single.aberto, true);
  });

  test('qualquer erro vira FalhaGerador', () {
    final repo = PontosProximosRepositorioImpl(_Remoto([], erro: Exception()));
    expect(repo.proximos(centro), throwsA(isA<FalhaGerador>()));
  });
}
