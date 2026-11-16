import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/apresentacao/providers.dart';
import '../dados/ofertas_repositorio_fake.dart';
import '../dominio/falha_catador.dart';
import '../dominio/oferta_resumo.dart';
import '../dominio/ofertas_repositorio.dart';

/// Repositório de ofertas. Padrão: fake; `main.dart` troca pelo
/// `OfertasRepositorioImpl(OfertasRemotoSupabase(client))` (ver PEDIDOS).
final ofertasRepositorioProvider = Provider<OfertasRepositorio>(
  (ref) => OfertasRepositorioFake(),
);

/// Relógio injetável (testes controlam o "agora" da contagem regressiva).
final relogioProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Intervalo de atualização da contagem (1 s). Testes podem sobrescrever.
final tickOfertaProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 1),
);

class EstadoOfertas {
  const EstadoOfertas({
    this.ofertas = const [],
    this.agora,
    this.respondendo = false,
    this.aviso,
    this.rotaId,
  });

  /// Pendentes, da que vence primeiro para a última, sem as já vencidas.
  final List<OfertaResumo> ofertas;
  final DateTime? agora;

  /// Aceite/recusa em andamento (trava os botões).
  final bool respondendo;

  /// Mensagem curta (ex.: "Oferta indisponível").
  final String? aviso;

  /// Rota criada pelo último aceite.
  final String? rotaId;

  OfertaResumo? get atual => ofertas.isEmpty ? null : ofertas.first;

  int get segundosRestantes =>
      atual == null || agora == null ? 0 : atual!.segundosRestantes(agora!);

  EstadoOfertas copiar({
    List<OfertaResumo>? ofertas,
    DateTime? agora,
    bool? respondendo,
    String? aviso,
    bool limparAviso = false,
    String? rotaId,
  }) => EstadoOfertas(
    ofertas: ofertas ?? this.ofertas,
    agora: agora ?? this.agora,
    respondendo: respondendo ?? this.respondendo,
    aviso: limparAviso ? null : (aviso ?? this.aviso),
    rotaId: rotaId ?? this.rotaId,
  );
}

/// UC05: assina as ofertas pendentes e conduz a contagem de 45 s. Ao vencer
/// localmente, chama `expirar_ofertas` e esconde o cartão. AutoDispose: o
/// stream e o timer morrem ao sair da tela ou no logout (muda a sessão).
class OfertasNotifier extends Notifier<EstadoOfertas> {
  Timer? _timer;
  StreamSubscription<List<OfertaResumo>>? _sub;
  bool _ativo = true;
  bool _expirando = false;

  /// Última lista recebida do servidor.
  List<OfertaResumo> _todas = const [];

  /// Ofertas escondidas (vencidas ou respondidas) até o servidor confirmar.
  final Set<String> _ocultas = {};

  DateTime _agora() => ref.read(relogioProvider)();

  @override
  EstadoOfertas build() {
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
      _timer?.cancel();
      _sub?.cancel();
    });
    _sub = ref
        .read(ofertasRepositorioProvider)
        .observar()
        .listen(
          (todas) {
            if (!_ativo) return;
            _todas = todas;
            final ids = todas.map((o) => o.ofertaId).toSet();
            _ocultas.removeWhere((id) => !ids.contains(id));
            _recalcular();
          },
          onError: (Object e) {
            if (!_ativo) return;
            state = state.copiar(
              aviso: e is FalhaCatador
                  ? e.texto
                  : const FalhaCatador(MotivoFalhaCatador.generico).texto,
            );
          },
        );
    _timer = Timer.periodic(ref.read(tickOfertaProvider), (_) {
      if (_ativo) _recalcular();
    });
    return EstadoOfertas(agora: _agora());
  }

  void _recalcular() {
    final agora = _agora();
    final candidatas = _todas.where((o) => !_ocultas.contains(o.ofertaId));
    final vencidas = candidatas.where((o) => o.expirada(agora)).toList();
    if (vencidas.isNotEmpty) {
      _ocultas.addAll(vencidas.map((o) => o.ofertaId));
      _expirarNoServidor();
    }
    final visiveis =
        _todas
            .where((o) => !_ocultas.contains(o.ofertaId) && !o.expirada(agora))
            .toList()
          ..sort((a, b) => a.expiraEm.compareTo(b.expiraEm));
    state = state.copiar(ofertas: visiveis, agora: agora);
  }

  Future<void> _expirarNoServidor() async {
    if (_expirando) return;
    _expirando = true;
    try {
      await ref.read(ofertasRepositorioProvider).expirar();
    } catch (_) {
      // idempotente: o próximo vencimento tenta de novo
    } finally {
      _expirando = false;
    }
  }

  /// Aceita a oferta atual. Devolve true se criou rota.
  Future<bool> aceitar() async {
    final o = state.atual;
    if (o == null || state.respondendo) return false;
    state = state.copiar(respondendo: true, limparAviso: true);
    try {
      final rota = await ref
          .read(ofertasRepositorioProvider)
          .aceitar(o.ofertaId);
      if (!_ativo) return true;
      _ocultas.add(o.ofertaId);
      state = state.copiar(respondendo: false, rotaId: rota);
      _recalcular();
      return true;
    } on FalhaCatador catch (e) {
      if (!_ativo) return false;
      // Indisponível/expirada: a oferta saiu do ar; esconde o cartão.
      if (e.motivo != MotivoFalhaCatador.generico) _ocultas.add(o.ofertaId);
      state = state.copiar(respondendo: false, aviso: e.texto);
      _recalcular();
      return false;
    }
  }

  Future<void> recusar() async {
    final o = state.atual;
    if (o == null || state.respondendo) return;
    state = state.copiar(respondendo: true, limparAviso: true);
    try {
      await ref.read(ofertasRepositorioProvider).recusar(o.ofertaId);
      if (!_ativo) return;
      _ocultas.add(o.ofertaId);
    } on FalhaCatador catch (e) {
      if (!_ativo) return;
      if (e.motivo == MotivoFalhaCatador.ofertaIndisponivel) {
        _ocultas.add(o.ofertaId);
      }
      state = state.copiar(aviso: e.texto);
    }
    state = state.copiar(respondendo: false);
    _recalcular();
  }

  void limparAviso() => state = state.copiar(limparAviso: true);
}

final ofertasProvider =
    NotifierProvider.autoDispose<OfertasNotifier, EstadoOfertas>(
      OfertasNotifier.new,
    );
