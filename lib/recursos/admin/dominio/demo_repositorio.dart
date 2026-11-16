import 'package:latlong2/latlong.dart';

import 'demo.dart';

/// Operações do painel de demonstração (UC15). Só o admin tem permissão.
abstract class DemoRepositorio {
  /// Atores, rotas abertas e últimos eventos.
  Future<SnapshotDemo> carregar();

  /// Cria [quantidade] catadores fictícios (1 a 20) e devolve quantos foram criados.
  Future<int> criarCatadores(int quantidade);

  /// Cria um pedido fictício para um gerador do seed e devolve o id.
  Future<String> criarPedido();

  /// Reaplica o estado do seed. Devolve o tempo gasto (aceite: < 10 s).
  Future<Duration> resetar();

  /// Move um catador (usado pela simulação do admin, UC16).
  Future<void> moverCatador(String catadorId, LatLng posicao);
}
