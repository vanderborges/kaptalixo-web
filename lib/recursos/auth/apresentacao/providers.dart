import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../nucleo/modelos/papel.dart';
import '../../../nucleo/modelos/sessao.dart';
import '../../../nucleo/repositorios_base/sessao_repositorio.dart';
import '../dados/auth_repositorio_fake.dart';
import '../dominio/auth_repositorio.dart';

/// Repositório de autenticação. O padrão é o fake (sem backend); `main.dart`
/// substitui pela implementação Supabase quando há `--dart-define` de conexão.
final authRepositorioProvider = Provider<AuthRepositorio>(
  (ref) => AuthRepositorioFake(),
);

/// Sessão do usuário (mesmo objeto do repositório de autenticação).
final sessaoRepositorioProvider = Provider<SessaoRepositorio>(
  (ref) => ref.watch(authRepositorioProvider),
);

/// Sessão atual como estado reativo (valor inicial + mudanças).
final sessaoProvider = StreamProvider<Sessao?>((ref) async* {
  final repo = ref.watch(sessaoRepositorioProvider);
  yield repo.atual;
  yield* repo.mudancas;
});

/// RN10: verdadeiro só para catador aprovado. A tela de disponibilidade (T5.1)
/// deve condicionar o botão "Ficar disponível" a este provider.
final podeFicarDisponivelProvider = Provider<bool>(
  (ref) => ref.watch(sessaoProvider).value?.podeFicarDisponivel ?? false,
);

/// Papéis que podem se cadastrar pelo app.
///
/// `ponto` fica de fora até o banco oferecer o RPC `cadastrar_ponto`
/// (a RLS de `perfis` só aceita gerador/catador; ver `backlog/PEDIDOS.md`).
final papeisCadastraveisProvider = Provider<List<Papel>>(
  (ref) => const [Papel.gerador, Papel.catador],
);
