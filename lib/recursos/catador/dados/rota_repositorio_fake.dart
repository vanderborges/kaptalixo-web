import 'dart:async';

import '../dominio/falha_catador.dart';
import '../dominio/rota_ativa.dart';
import '../dominio/rota_repositorio.dart';

/// Posição enviada ao servidor (registrada pelo fake).
typedef PosicaoEnviada = ({double lat, double lng, String rotaId});

/// Fake em memória que imita as regras do servidor (iniciar_rota,
/// avancar_parada com PIN/bloqueio, trocar_ponto_destino). [pins] mapeia
/// `solicitacaoId` -> PIN correto (só para o teste; o app nunca o vê).
class RotaRepositorioFake implements RotaRepositorio {
  RotaRepositorioFake({
    RotaAtiva? rota,
    this.pins = const {},
    this.maxErros = 3,
    this.duracaoBloqueio = const Duration(minutes: 2),
    DateTime Function()? relogio,
    // ignore: prefer_initializing_formals
  }) : _rota = rota,
       _relogio = relogio ?? DateTime.now;

  RotaAtiva? _rota;
  final Map<String, String> pins;
  final int maxErros;
  final Duration duracaoBloqueio;
  final DateTime Function() _relogio;
  final Map<String, int> _erros = {};

  /// Falha lançada (uma vez) na próxima chamada de ação ou carga.
  FalhaCatador? proximaFalha;

  /// Quando definido, `atualizarLocalizacao` espera por ele (testa a guarda
  /// de envio em andamento).
  Future<void>? travaPosicao;

  final List<PosicaoEnviada> posicoes = [];
  final List<String> chamadas = [];

  /// Motivos informados ao pular paradas.
  final List<String?> motivos = [];
  int assinaturas = 0;
  int cancelamentos = 0;

  final _ctrl = StreamController<RotaAtiva?>.broadcast();

  RotaAtiva? get rota => _rota;

  /// Publica um novo retrato (simula o Realtime).
  void emitir(RotaAtiva? rota) {
    _rota = rota;
    _ctrl.add(rota);
  }

  void emitirErro(FalhaCatador f) => _ctrl.addError(f);

  void _falharSeProgramado() {
    final f = proximaFalha;
    if (f != null) {
      proximaFalha = null;
      throw f;
    }
  }

  void _publicar(RotaAtiva nova) {
    _rota = nova;
    _ctrl.add(nova);
  }

  @override
  Future<String?> rotaAbertaId() async {
    final r = _rota;
    return r != null && r.status.aberta ? r.id : null;
  }

  @override
  Future<RotaAtiva?> carregar(String rotaId) async {
    chamadas.add('carregar');
    _falharSeProgramado();
    return _rota;
  }

  @override
  Stream<RotaAtiva?> observar(String rotaId) {
    late final StreamController<RotaAtiva?> c;
    StreamSubscription<RotaAtiva?>? sub;
    c = StreamController<RotaAtiva?>(
      onListen: () {
        assinaturas++;
        c.add(_rota);
        sub = _ctrl.stream.listen(c.add, onError: c.addError);
      },
      onCancel: () {
        cancelamentos++;
        return sub?.cancel();
      },
    );
    return c.stream;
  }

  /// Promove a próxima coleta pendente a "a caminho" se nenhuma está em curso.
  List<ParadaRota> _promover(List<ParadaRota> paradas) {
    final emCurso = paradas.any(
      (p) =>
          p.ehColeta &&
          (p.status == StatusParada.aCaminho ||
              p.status == StatusParada.noLocal),
    );
    if (emCurso) return paradas;
    final i = paradas.indexWhere(
      (p) => p.ehColeta && p.status == StatusParada.pendente,
    );
    if (i < 0) return paradas;
    final nova = List.of(paradas);
    nova[i] = nova[i].copiar(status: StatusParada.aCaminho);
    return nova;
  }

  @override
  Future<void> iniciar(String rotaId) async {
    chamadas.add('iniciar');
    _falharSeProgramado();
    final r = _rota;
    if (r == null) throw const FalhaCatador(MotivoFalhaCatador.rotaInexistente);
    if (r.status != StatusRota.planejada) {
      throw const FalhaCatador(MotivoFalhaCatador.rotaInvalida);
    }
    _publicar(
      r.copiar(status: StatusRota.emAndamento, paradas: _promover(r.paradas)),
    );
  }

  @override
  Future<ResultadoParada> avancarParada(
    String paradaId,
    AcaoParada acao, {
    String? pin,
    String? motivo,
  }) async {
    chamadas.add('avancar:${acao.codigo}');
    _falharSeProgramado();
    final r = _rota;
    if (r == null) throw const FalhaCatador(MotivoFalhaCatador.rotaInexistente);
    final i = r.paradas.indexWhere((p) => p.id == paradaId);
    if (i < 0) throw const FalhaCatador(MotivoFalhaCatador.paradaInexistente);
    if (r.status != StatusRota.emAndamento) {
      throw const FalhaCatador(MotivoFalhaCatador.rotaInvalida);
    }
    final p = r.paradas[i];
    final nova = List.of(r.paradas);
    const invalida = FalhaCatador(MotivoFalhaCatador.paradaInvalida);

    switch (acao) {
      case AcaoParada.cheguei:
        if (!p.status.aberta || p.status == StatusParada.noLocal) {
          throw invalida;
        }
        if (!p.ehColeta &&
            r.paradas.any((c) => c.ehColeta && c.status.aberta)) {
          throw const FalhaCatador(MotivoFalhaCatador.coletasPendentes);
        }
        nova[i] = p.copiar(status: StatusParada.noLocal);
        _publicar(r.copiar(paradas: nova));
        return const ResultadoParada(TipoResultadoParada.ok);

      case AcaoParada.concluir:
        if (!p.ehColeta || p.status != StatusParada.noLocal) throw invalida;
        if (pin == null || !RegExp(r'^[0-9]{4}$').hasMatch(pin)) {
          throw const FalhaCatador(MotivoFalhaCatador.parametroInvalido);
        }
        final agora = _relogio();
        final bloq = p.bloqueioPinAte;
        if (bloq != null && bloq.isAfter(agora)) {
          return ResultadoParada(
            TipoResultadoParada.pinBloqueado,
            bloqueioAte: bloq,
          );
        }
        if (pins[p.solicitacaoId] != pin) {
          final erros = (_erros[p.id] ?? 0) + 1;
          if (erros >= maxErros) {
            _erros[p.id] = 0;
            final ate = agora.add(duracaoBloqueio);
            nova[i] = p.copiar(bloqueioPinAte: ate);
            _publicar(r.copiar(paradas: nova));
            return ResultadoParada(
              TipoResultadoParada.pinBloqueado,
              bloqueioAte: ate,
            );
          }
          _erros[p.id] = erros;
          return ResultadoParada(
            TipoResultadoParada.pinIncorreto,
            tentativasRestantes: maxErros - erros,
          );
        }
        _erros[p.id] = 0;
        nova[i] = p.copiar(
          status: StatusParada.concluida,
          limparBloqueio: true,
        );
        _publicar(r.copiar(paradas: _promover(nova)));
        return const ResultadoParada(TipoResultadoParada.ok);

      case AcaoParada.pular:
        if (!p.ehColeta || !p.status.aberta) throw invalida;
        motivos.add(motivo);
        nova[i] = p.copiar(status: StatusParada.pulada);
        final restam = nova.any((c) => c.ehColeta && c.status.aberta);
        _publicar(
          restam
              ? r.copiar(paradas: _promover(nova), versao: r.versao + 1)
              : r.copiar(status: StatusRota.cancelada, paradas: nova),
        );
        return const ResultadoParada(TipoResultadoParada.ok);
    }
  }

  @override
  Future<void> trocarPonto(String rotaId, String pontoId) async {
    chamadas.add('trocarPonto:$pontoId');
    _falharSeProgramado();
    final r = _rota;
    if (r == null) throw const FalhaCatador(MotivoFalhaCatador.rotaInexistente);
    final alvo = r.alternativas.where((a) => a.id == pontoId).toList();
    if (alvo.isEmpty) {
      throw const FalhaCatador(MotivoFalhaCatador.pontoInexistente);
    }
    final atual = r.descarte;
    if (atual == null || atual.status == StatusParada.noLocal) {
      throw const FalhaCatador(MotivoFalhaCatador.rotaInvalida);
    }
    final novas = [
      for (final p in r.paradas)
        if (p.id == atual.id)
          p.copiar(
            pontoId: alvo.first.id,
            pontoNome: alvo.first.nome,
            posicao: alvo.first.posicao,
          )
        else
          p,
    ];
    final trocadas = [
      for (final a in r.alternativas)
        if (a.id != pontoId) a,
      if (atual.pontoId != null)
        PontoDescarte(
          id: atual.pontoId!,
          nome: atual.pontoNome ?? 'Ponto',
          posicao: atual.posicao,
        ),
    ];
    _publicar(
      r.copiar(
        paradas: novas,
        pontoDestinoId: pontoId,
        alternativas: trocadas,
        versao: r.versao + 1,
      ),
    );
  }

  @override
  Future<void> atualizarLocalizacao(
    double lat,
    double lng,
    String rotaId,
  ) async {
    posicoes.add((lat: lat, lng: lng, rotaId: rotaId));
    final trava = travaPosicao;
    if (trava != null) await trava;
    _falharSeProgramado();
  }
}
