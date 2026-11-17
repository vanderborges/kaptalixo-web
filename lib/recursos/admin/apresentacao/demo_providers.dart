import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../nucleo/localizacao/localizacao_simulada.dart';
import '../../../nucleo/localizacao/servico_localizacao.dart';
import '../dados/demo_repositorio_fake.dart';
import '../dominio/demo.dart';
import '../dominio/demo_repositorio.dart';
import '../dominio/falha_admin.dart';

/// Repositório da demo. O padrão é o fake; `main.dart` troca pela
/// implementação Supabase quando há conexão configurada.
final demoRepositorioProvider = Provider<DemoRepositorio>(
  (ref) => DemoRepositorioFake(),
);

/// Intervalo da atualização periódica do painel (nulo desliga o polling).
final intervaloDemoProvider = Provider<Duration?>(
  (ref) => const Duration(seconds: 3),
);

Duration? _semRetentativa(int tentativas, Object erro) => null;

/// Estado vivo do painel: carrega ao abrir e atualiza por polling.
final demoControladorProvider =
    AsyncNotifierProvider.autoDispose<DemoControlador, SnapshotDemo>(
      DemoControlador.new,
      retry: _semRetentativa,
    );

class DemoControlador extends AsyncNotifier<SnapshotDemo> {
  Timer? _timer;
  bool _atualizando = false;

  DemoRepositorio get _repo => ref.read(demoRepositorioProvider);

  @override
  Future<SnapshotDemo> build() {
    final intervalo = ref.watch(intervaloDemoProvider);
    ref.onDispose(() => _timer?.cancel());
    if (intervalo != null) {
      _timer = Timer.periodic(intervalo, (_) => atualizar());
    }
    return ref.watch(demoRepositorioProvider).carregar();
  }

  /// Recarrega sem piscar: mantém os dados anteriores se a rede falhar.
  Future<void> atualizar() async {
    if (_atualizando) return;
    _atualizando = true;
    try {
      final s = await _repo.carregar();
      if (ref.mounted) state = AsyncData(s);
    } on Object catch (e, st) {
      if (ref.mounted && !state.hasValue) state = AsyncError(e, st);
    } finally {
      _atualizando = false;
    }
  }

  /// Cria catadores e mostra-os no mapa na hora (recarrega logo em seguida).
  Future<int> criarCatadores(int quantidade) async {
    final n = await _repo.criarCatadores(quantidade);
    await atualizar();
    return n;
  }

  Future<String> criarPedido() async {
    final id = await _repo.criarPedido();
    await atualizar();
    return id;
  }

  /// Reaplica o seed; devolve o tempo gasto.
  Future<Duration> resetar() async {
    final d = await _repo.resetar();
    await atualizar();
    return d;
  }
}

/// Cria o serviço de posições simuladas de um percurso (injetável nos testes).
typedef FabricaSimulacaoDemo =
    ServicoLocalizacao Function(List<LatLng> percurso, double multiplicador);

final fabricaSimulacaoDemoProvider = Provider<FabricaSimulacaoDemo>(
  (ref) =>
      (percurso, multiplicador) =>
          LocalizacaoSimulada(polyline: percurso, multiplicador: multiplicador),
);

class SimulacaoDemoEstado {
  const SimulacaoDemoEstado({
    this.catadorId,
    this.multiplicador = 1,
    this.erro,
  });

  /// Catador em simulação (nulo = desligada).
  final String? catadorId;
  final double multiplicador;
  final String? erro;

  bool get ativa => catadorId != null;
}

/// Modo simulação do admin para um catador (UC16): percorre a rota aberta e
/// envia as posições pelo repositório (`demo_mover_catador`).
final simulacaoDemoProvider =
    NotifierProvider.autoDispose<SimulacaoDemoControlador, SimulacaoDemoEstado>(
      SimulacaoDemoControlador.new,
    );

class SimulacaoDemoControlador extends Notifier<SimulacaoDemoEstado> {
  StreamSubscription<Object?>? _sub;

  @override
  SimulacaoDemoEstado build() {
    ref.onDispose(() => _sub?.cancel());
    return const SimulacaoDemoEstado();
  }

  /// Liga a simulação do [catador]. Devolve falso se ele não tem rota aberta.
  bool ligar(
    AtorDemo catador,
    SnapshotDemo snapshot, {
    double multiplicador = 1,
  }) {
    final rota = snapshot.rotaDe(catador.id);
    if (rota == null || rota.pontos.isEmpty) return false;
    desligar();
    final servico = ref.read(fabricaSimulacaoDemoProvider)([
      catador.posicao,
      ...rota.pontos,
    ], multiplicador);
    final repo = ref.read(demoRepositorioProvider);
    state = SimulacaoDemoEstado(
      catadorId: catador.id,
      multiplicador: multiplicador,
    );
    _sub = servico
        .posicoes()
        .asyncMap((p) => repo.moverCatador(catador.id, p.ponto))
        .listen(
          (_) {},
          onError: (Object e) {
            _sub?.cancel();
            _sub = null;
            state = SimulacaoDemoEstado(
              multiplicador: multiplicador,
              erro: e is FalhaAdmin
                  ? e.mensagem
                  : const FalhaAdmin(CodigoFalhaAdmin.desconhecida).mensagem,
            );
          },
          onDone: () {
            _sub = null;
            state = SimulacaoDemoEstado(multiplicador: multiplicador);
          },
        );
    return true;
  }

  /// Velocidade da próxima simulação (1x ou 10x), sem ligá-la.
  void definirMultiplicador(double m) {
    state = SimulacaoDemoEstado(
      catadorId: state.catadorId,
      multiplicador: m,
      erro: state.erro,
    );
  }

  void desligar() {
    _sub?.cancel();
    _sub = null;
    state = SimulacaoDemoEstado(multiplicador: state.multiplicador);
  }
}
