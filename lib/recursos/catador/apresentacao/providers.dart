import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../nucleo/localizacao/providers.dart';
import '../../auth/apresentacao/providers.dart';
import '../dados/disponibilidade_repositorio_fake.dart';
import '../dominio/disponibilidade_repositorio.dart';
import '../dominio/falha_catador.dart';
import '../dominio/situacao_catador.dart';

/// Repositório de disponibilidade. Padrão: fake; `main.dart` troca pelo
/// `DisponibilidadeRepositorioImpl(DisponibilidadeRemotoSupabase(client))`.
final disponibilidadeRepositorioProvider = Provider<DisponibilidadeRepositorio>(
  (ref) => DisponibilidadeRepositorioFake(),
);

/// Intervalo entre envios de posição (30 s). Testes podem sobrescrever.
final intervaloPosicaoProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 30),
);

class EstadoDisponibilidade {
  const EstadoDisponibilidade({
    this.situacao = SituacaoCatador.offline,
    this.carregando = true,
    this.alternando = false,
    this.erro,
    this.semPosicao = false,
  });

  final SituacaoCatador situacao;

  /// Lendo a situação inicial.
  final bool carregando;

  /// RPC de alternar em andamento.
  final bool alternando;
  final String? erro;

  /// Último envio de posição falhou (GPS indisponível ou rede).
  final bool semPosicao;

  bool get disponivel => situacao == SituacaoCatador.disponivel;

  EstadoDisponibilidade copiar({
    SituacaoCatador? situacao,
    bool? carregando,
    bool? alternando,
    String? erro,
    bool limparErro = false,
    bool? semPosicao,
  }) => EstadoDisponibilidade(
    situacao: situacao ?? this.situacao,
    carregando: carregando ?? this.carregando,
    alternando: alternando ?? this.alternando,
    erro: limparErro ? null : (erro ?? this.erro),
    semPosicao: semPosicao ?? this.semPosicao,
  );
}

/// Controla disponível/offline (UC14) e envia a posição a cada 30 s apenas
/// enquanto disponível. RN10: só catador aprovado pode ficar disponível.
class DisponibilidadeNotifier extends Notifier<EstadoDisponibilidade> {
  Timer? _timer;
  bool _ativo = true;

  @override
  EstadoDisponibilidade build() {
    _ativo = true;
    ref.onDispose(() {
      _ativo = false;
      _parar();
    });
    _carregar();
    return const EstadoDisponibilidade();
  }

  Future<void> _carregar() async {
    try {
      final s = await ref
          .read(disponibilidadeRepositorioProvider)
          .situacaoAtual();
      if (!_ativo) return;
      state = state.copiar(situacao: s, carregando: false);
      if (s == SituacaoCatador.disponivel) _iniciar();
    } on FalhaCatador catch (e) {
      if (_ativo) state = state.copiar(carregando: false, erro: e.texto);
    }
  }

  /// Liga/desliga a disponibilidade. Bloqueado se não aprovado (RN10).
  Future<void> alternar() async {
    if (state.alternando || state.carregando) return;
    final quer = !state.disponivel;
    if (quer && !ref.read(podeFicarDisponivelProvider)) {
      state = state.copiar(
        erro: const FalhaCatador(MotivoFalhaCatador.cadastroNaoAprovado).texto,
      );
      return;
    }
    state = state.copiar(alternando: true, limparErro: true);
    try {
      final nova = await ref
          .read(disponibilidadeRepositorioProvider)
          .alternar(quer);
      if (!_ativo) return;
      state = state.copiar(
        situacao: nova,
        alternando: false,
        semPosicao: false,
      );
      if (nova == SituacaoCatador.disponivel) {
        _iniciar();
      } else {
        _parar();
      }
    } on FalhaCatador catch (e) {
      if (_ativo) state = state.copiar(alternando: false, erro: e.texto);
    }
  }

  void _iniciar() {
    _parar();
    _timer = Timer.periodic(
      ref.read(intervaloPosicaoProvider),
      (_) => _enviar(),
    );
    _enviar();
  }

  void _parar() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _enviar() async {
    try {
      final p = await ref.read(servicoLocalizacaoProvider).atual();
      if (!_ativo || _timer == null) return;
      await ref
          .read(disponibilidadeRepositorioProvider)
          .atualizarLocalizacao(p.latitude, p.longitude);
      if (_ativo && state.semPosicao) state = state.copiar(semPosicao: false);
    } on FalhaCatador catch (e) {
      if (!_ativo) return;
      if (e.motivo == MotivoFalhaCatador.indisponivel) {
        _parar();
        state = state.copiar(situacao: SituacaoCatador.offline);
      } else {
        state = state.copiar(semPosicao: true);
      }
    } catch (_) {
      if (_ativo) state = state.copiar(semPosicao: true);
    }
  }
}

final disponibilidadeProvider =
    NotifierProvider<DisponibilidadeNotifier, EstadoDisponibilidade>(
      DisponibilidadeNotifier.new,
    );
