import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/config.dart';
import '../../../nucleo/localizacao/providers.dart';
import '../../../nucleo/mapas/haversine.dart';
import '../../../nucleo/mapas/servico_rotas.dart';
import '../../../nucleo/mapas/servico_rotas_osrm.dart';
import '../../auth/apresentacao/providers.dart';
import '../dados/rota_repositorio_fake.dart';
import '../dominio/falha_catador.dart';
import '../dominio/rota_ativa.dart';
import '../dominio/rota_repositorio.dart';
import 'ofertas_providers.dart' show relogioProvider;

/// Repositório da rota. Padrão: fake; `main.dart` troca pelo
/// `RotaRepositorioImpl(RotaRemotoSupabase(client))` (ver PEDIDOS).
final rotaRepositorioProvider = Provider<RotaRepositorio>(
  (ref) => RotaRepositorioFake(),
);

/// Serviço de rotas usado só para o ETA quando o servidor não o informa.
final servicoRotasCatadorProvider = Provider<ServicoRotas>(
  (ref) => ServicoRotasOsrm(urlBase: Config.osrmBaseUrl),
);

/// Intervalo entre envios de posição durante a rota (UC08: 5 s).
final intervaloPosicaoRotaProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 5),
);

/// Intervalo do relógio da tela (contagem do bloqueio de PIN).
final tickRotaProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 1),
);

/// Distância (m) a partir da qual o app marca "Cheguei" sozinho (UC08).
const double raioChegadaMetros = 80;

class EstadoRota {
  const EstadoRota({
    this.carregando = true,
    this.rota,
    this.naoEncontrada = false,
    this.erro,
    this.agindo = false,
    this.aviso,
    this.posicao,
    this.semPosicao = false,
    this.agora,
    this.etaEstimadoS,
    this.tentativasRestantes,
    this.bloqueioAte,
    this.bloqueioParadaId,
  });

  final bool carregando;
  final RotaAtiva? rota;

  /// A rota não existe (ou não é deste catador).
  final bool naoEncontrada;

  /// Falha ao ler a rota (a tela oferece "Tentar novamente").
  final String? erro;

  /// Ação em andamento (trava os botões).
  final bool agindo;

  /// Mensagem curta da última ação.
  final String? aviso;
  final LatLng? posicao;

  /// O último envio de posição falhou (GPS ou rede).
  final bool semPosicao;
  final DateTime? agora;

  /// ETA estimado (ServicoRotas) quando a parada não traz `eta`.
  final int? etaEstimadoS;

  /// Tentativas de PIN restantes após um erro.
  final int? tentativasRestantes;
  final DateTime? bloqueioAte;
  final String? bloqueioParadaId;

  ParadaRota? get proxima => rota?.proxima;

  /// Fim do bloqueio de PIN da parada [p] (servidor ou resposta recente).
  DateTime? bloqueioDe(ParadaRota? p) {
    if (p == null) return null;
    final doServidor = p.bloqueioPinAte;
    final local = bloqueioParadaId == p.id ? bloqueioAte : null;
    if (doServidor == null) return local;
    if (local == null) return doServidor;
    return doServidor.isAfter(local) ? doServidor : local;
  }

  /// Segundos que faltam para liberar o PIN (0 se livre).
  int segundosBloqueio(ParadaRota? p) {
    final ate = bloqueioDe(p);
    final a = agora;
    if (ate == null || a == null) return 0;
    final s = ate.difference(a).inMilliseconds;
    return s <= 0 ? 0 : (s / 1000).ceil();
  }

  /// Distância em linha reta até a próxima parada, se há posição.
  double? get distanciaProximaM {
    final p = proxima?.posicao;
    final pos = posicao;
    if (p == null || pos == null) return null;
    return distanciaHaversineMetros(pos, p);
  }

  /// ETA até a próxima parada: o do servidor menos o relógio, ou o estimado.
  int? get etaS {
    final p = proxima;
    final a = agora;
    if (p?.eta != null && a != null) {
      return math.max(0, p!.eta!.difference(a).inSeconds);
    }
    return etaEstimadoS;
  }

  EstadoRota copiar({
    bool? carregando,
    RotaAtiva? rota,
    bool? naoEncontrada,
    String? erro,
    bool limparErro = false,
    bool? agindo,
    String? aviso,
    bool limparAviso = false,
    LatLng? posicao,
    bool? semPosicao,
    DateTime? agora,
    int? etaEstimadoS,
    bool limparEta = false,
    int? tentativasRestantes,
    DateTime? bloqueioAte,
    String? bloqueioParadaId,
    bool limparPin = false,
  }) => EstadoRota(
    carregando: carregando ?? this.carregando,
    rota: rota ?? this.rota,
    naoEncontrada: naoEncontrada ?? this.naoEncontrada,
    erro: limparErro ? null : (erro ?? this.erro),
    agindo: agindo ?? this.agindo,
    aviso: limparAviso ? null : (aviso ?? this.aviso),
    posicao: posicao ?? this.posicao,
    semPosicao: semPosicao ?? this.semPosicao,
    agora: agora ?? this.agora,
    etaEstimadoS: limparEta ? null : (etaEstimadoS ?? this.etaEstimadoS),
    tentativasRestantes: limparPin
        ? null
        : (tentativasRestantes ?? this.tentativasRestantes),
    bloqueioAte: limparPin ? null : (bloqueioAte ?? this.bloqueioAte),
    bloqueioParadaId: limparPin
        ? null
        : (bloqueioParadaId ?? this.bloqueioParadaId),
  );
}

/// UC08: acompanha a rota em tempo real, envia a posição a cada 5 s, marca
/// chegada (≤ 80 m ou botão) e confirma a coleta com o PIN. AutoDispose: o
/// stream e os timers morrem ao sair da tela e no logout (muda a sessão).
class RotaNotifier extends Notifier<EstadoRota> {
  RotaNotifier(this.rotaId);

  final String rotaId;

  Timer? _timerPosicao;
  Timer? _timerRelogio;
  StreamSubscription<RotaAtiva?>? _sub;
  bool _ativo = true;

  /// Envio de posição em andamento (evita sobrepor chamadas lentas).
  bool _enviando = false;

  /// Parada para a qual o "Cheguei" automático já foi tentado.
  String? _chegadaTentada;

  /// Parada/instante do último cálculo de ETA estimado.
  String? _etaParada;
  DateTime? _etaEm;

  DateTime _agora() => ref.read(relogioProvider)();

  RotaRepositorio get _repo => ref.read(rotaRepositorioProvider);

  @override
  EstadoRota build() {
    _ativo = true;
    // Logout/troca de usuário reconstrói (e reinicia) o notifier.
    ref.listen(sessaoProvider.select((s) => s.value?.usuarioId), (
      antes,
      depois,
    ) {
      if (antes != null && antes != depois) ref.invalidateSelf();
    });
    ref.onDispose(() {
      _ativo = false;
      _timerPosicao?.cancel();
      _timerRelogio?.cancel();
      _sub?.cancel();
    });
    _assinar();
    _timerRelogio = Timer.periodic(ref.read(tickRotaProvider), (_) {
      if (_ativo) state = state.copiar(agora: _agora());
    });
    return EstadoRota(agora: _agora());
  }

  void _assinar() {
    _sub?.cancel();
    _sub = _repo
        .observar(rotaId)
        .listen(
          (r) {
            if (_ativo) _aplicar(r);
          },
          onError: (Object e) {
            if (!_ativo) return;
            state = state.copiar(
              carregando: false,
              erro: e is FalhaCatador
                  ? e.texto
                  : const FalhaCatador(MotivoFalhaCatador.generico).texto,
            );
          },
        );
  }

  /// Recomeça a leitura depois de um erro.
  void tentarNovamente() {
    state = state.copiar(carregando: true, limparErro: true);
    _assinar();
  }

  void _aplicar(RotaAtiva? r) {
    if (r == null) {
      _pararPosicao();
      state = state.copiar(
        carregando: false,
        naoEncontrada: true,
        limparErro: true,
      );
      return;
    }
    final proxima = r.proxima;
    // Mudou a parada: some o estado de PIN da anterior.
    final trocou =
        state.bloqueioParadaId != null && state.bloqueioParadaId != proxima?.id;
    state = state.copiar(
      carregando: false,
      naoEncontrada: false,
      rota: r,
      limparErro: true,
      limparPin: trocou,
    );
    if (r.status.aberta) {
      _iniciarPosicao();
    } else {
      _pararPosicao();
    }
  }

  void _iniciarPosicao() {
    if (_timerPosicao != null) return;
    _timerPosicao = Timer.periodic(
      ref.read(intervaloPosicaoRotaProvider),
      (_) => _enviarPosicao(),
    );
    _enviarPosicao();
  }

  void _pararPosicao() {
    _timerPosicao?.cancel();
    _timerPosicao = null;
  }

  Future<void> _enviarPosicao() async {
    if (_enviando || !_ativo) return;
    _enviando = true;
    try {
      final p = await ref.read(servicoLocalizacaoProvider).atual();
      if (!_ativo || _timerPosicao == null) return;
      state = state.copiar(posicao: p.ponto);
      _verificarChegada(p.ponto);
      _estimarEta(p.ponto);
      await _repo.atualizarLocalizacao(p.latitude, p.longitude, rotaId);
      if (_ativo && state.semPosicao) state = state.copiar(semPosicao: false);
    } catch (_) {
      if (_ativo) state = state.copiar(semPosicao: true);
    } finally {
      _enviando = false;
    }
  }

  void _verificarChegada(LatLng pos) {
    final r = state.rota;
    final p = r?.proxima;
    if (r == null || p == null || r.status != StatusRota.emAndamento) return;
    if (p.status != StatusParada.pendente &&
        p.status != StatusParada.aCaminho) {
      return;
    }
    final alvo = p.posicao;
    if (alvo == null || state.agindo || _chegadaTentada == p.id) return;
    if (distanciaHaversineMetros(pos, alvo) <= raioChegadaMetros) {
      _chegadaTentada = p.id; // uma tentativa; se falhar, o botão resolve
      cheguei();
    }
  }

  /// ETA via ServicoRotas quando a parada não traz `eta` (no máx. a cada 30 s).
  void _estimarEta(LatLng pos) {
    final p = state.rota?.proxima;
    final alvo = p?.posicao;
    if (p == null || alvo == null || p.eta != null) return;
    final agora = _agora();
    final ultimo = _etaEm;
    if (_etaParada == p.id &&
        ultimo != null &&
        agora.difference(ultimo) < const Duration(seconds: 30)) {
      return;
    }
    _etaParada = p.id;
    _etaEm = agora;
    ref
        .read(servicoRotasCatadorProvider)
        .duracaoAte(pos, alvo)
        .then((s) {
          if (_ativo) state = state.copiar(etaEstimadoS: s.round());
        })
        .catchError((Object _) {});
  }

  Future<void> _recarregar() async {
    try {
      final r = await _repo.carregar(rotaId);
      if (_ativo) _aplicar(r);
    } on FalhaCatador {
      // o stream/Realtime traz o próximo retrato
    }
  }

  /// Executa uma ação do catador: trava botões, traduz falhas em aviso e
  /// relê a rota ao terminar. Devolve null se falhou ou já havia ação.
  Future<T?> _agir<T>(Future<T> Function() acao) async {
    if (state.agindo) return null;
    state = state.copiar(agindo: true, limparAviso: true);
    try {
      final r = await acao();
      if (!_ativo) return r;
      await _recarregar();
      if (_ativo) state = state.copiar(agindo: false);
      return r;
    } on FalhaCatador catch (e) {
      if (!_ativo) return null;
      state = state.copiar(agindo: false, aviso: e.texto);
      await _recarregar(); // a rota pode ter mudado (ex.: parada inválida)
      return null;
    } catch (_) {
      if (_ativo) {
        state = state.copiar(
          agindo: false,
          aviso: const FalhaCatador(MotivoFalhaCatador.generico).texto,
        );
      }
      return null;
    }
  }

  /// Relê a rota agora (ex.: após aceitar uma oferta extra e replanejar).
  Future<void> atualizar() => _recarregar();

  /// **Iniciar rota** (rota `planejada` -> `em_andamento`).
  Future<bool> iniciar() async {
    final r = state.rota;
    if (r == null || r.status != StatusRota.planejada) return false;
    final ok = await _agir(() => _repo.iniciar(rotaId).then((_) => true));
    return ok ?? false;
  }

  /// **Cheguei** na próxima parada.
  Future<bool> cheguei() async {
    final p = state.proxima;
    if (p == null || state.rota?.status != StatusRota.emAndamento) {
      return false;
    }
    final r = await _agir(() => _repo.avancarParada(p.id, AcaoParada.cheguei));
    return r?.ok ?? false;
  }

  /// Confirma a coleta com o PIN que o gerador informou. Devolve o resultado
  /// (null se não enviou: parada errada, bloqueio ou falha).
  Future<ResultadoParada?> concluir(String pin) async {
    final p = state.proxima;
    if (p == null ||
        !p.ehColeta ||
        p.status != StatusParada.noLocal ||
        state.segundosBloqueio(p) > 0) {
      return null;
    }
    final r = await _agir(
      () => _repo.avancarParada(p.id, AcaoParada.concluir, pin: pin),
    );
    if (r == null || !_ativo) return r;
    switch (r.tipo) {
      case TipoResultadoParada.ok:
        state = state.copiar(limparPin: true);
      case TipoResultadoParada.pinIncorreto:
        state = state.copiar(
          tentativasRestantes: r.tentativasRestantes,
          bloqueioParadaId: p.id,
          aviso: 'PIN incorreto.',
        );
      case TipoResultadoParada.pinBloqueado:
        state = state.copiar(limparPin: true); // zera as tentativas
        state = state.copiar(
          bloqueioAte: r.bloqueioAte,
          bloqueioParadaId: p.id,
          aviso: 'Muitos erros. Tente de novo em instantes.',
        );
    }
    return r;
  }

  /// **Pular parada** (gerador ausente): a solicitação volta à fila.
  Future<bool> pular(String motivo) async {
    final p = state.proxima;
    if (p == null || !p.ehColeta) return false;
    var m = motivo.trim();
    if (m.length > 200) m = m.substring(0, 200);
    final r = await _agir(
      () => _repo.avancarParada(
        p.id,
        AcaoParada.pular,
        motivo: m.isEmpty ? null : m,
      ),
    );
    return r?.ok ?? false;
  }

  /// Troca o ponto de descarte (RN06).
  Future<bool> trocarPonto(String pontoId) async {
    final ok = await _agir(
      () => _repo.trocarPonto(rotaId, pontoId).then((_) => true),
    );
    return ok ?? false;
  }

  void limparAviso() => state = state.copiar(limparAviso: true);
}

final rotaProvider = NotifierProvider.autoDispose
    .family<RotaNotifier, EstadoRota, String>(RotaNotifier.new);
