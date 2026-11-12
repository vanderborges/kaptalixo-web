import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../nucleo/modelos/catador_cadastro.dart';
import '../../../nucleo/modelos/status_cadastro.dart';
import '../dados/catadores_admin_repositorio_fake.dart';
import '../dominio/catadores_admin_repositorio.dart';

/// Repositório de cadastros de catador. O padrão é o fake; `main.dart` troca
/// pela implementação Supabase quando há conexão configurada.
final catadoresAdminRepositorioProvider = Provider<CatadoresAdminRepositorio>(
  (ref) => CatadoresAdminRepositorioFake(),
);

/// Filtro de status da lista (padrão: pendentes).
final filtroStatusAdminProvider =
    NotifierProvider<FiltroStatusAdmin, StatusCadastro>(FiltroStatusAdmin.new);

class FiltroStatusAdmin extends Notifier<StatusCadastro> {
  @override
  StatusCadastro build() => StatusCadastro.pendente;

  void definir(StatusCadastro status) => state = status;
}

/// Catadores do status escolhido no filtro.
final catadoresListaProvider =
    FutureProvider.autoDispose<List<CatadorCadastro>>(retry: _semRetentativa, (
      ref,
    ) {
      final status = ref.watch(filtroStatusAdminProvider);
      return ref.watch(catadoresAdminRepositorioProvider).listar(status);
    });

/// Detalhe de um catador.
final catadorDetalheProvider = FutureProvider.autoDispose
    .family<CatadorCadastro, String>(
      retry: _semRetentativa,
      (ref, id) => ref.watch(catadoresAdminRepositorioProvider).buscar(id),
    );

/// Erros aparecem de imediato com botão "Tentar novamente" (sem retry automático).
Duration? _semRetentativa(int tentativas, Object erro) => null;
