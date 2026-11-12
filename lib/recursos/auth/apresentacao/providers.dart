import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../nucleo/repositorios_base/sessao_repositorio.dart';

/// Repositório de sessão. Por enquanto falso e deslogado; será trocado pela
/// implementação Supabase.
final sessaoRepositorioProvider = Provider<SessaoRepositorio>(
  (ref) => SessaoRepositorioFake(),
);
