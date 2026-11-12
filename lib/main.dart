import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/config.dart';
import 'recursos/admin/apresentacao/providers.dart';
import 'recursos/admin/dados/catadores_admin_remoto_supabase.dart';
import 'recursos/admin/dados/catadores_admin_repositorio_impl.dart';
import 'recursos/auth/apresentacao/providers.dart';
import 'recursos/auth/dados/auth_remoto_supabase.dart';
import 'recursos/auth/dados/auth_repositorio_impl.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final overrides = <Override>[];
  if (Config.supabaseConfigurado) {
    await Supabase.initialize(
      url: Config.supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: Config.supabaseAnonKey,
    );
    final auth = await AuthRepositorioImpl.restaurar(
      AuthRemotoSupabase(Supabase.instance.client),
    );
    overrides.add(authRepositorioProvider.overrideWithValue(auth));
    overrides.add(
      catadoresAdminRepositorioProvider.overrideWithValue(
        CatadoresAdminRepositorioImpl(
          CatadoresAdminRemotoSupabase(Supabase.instance.client),
        ),
      ),
    );
  }
  // Sem SUPABASE_ANON_KEY o app usa o repositório fake (modo desenvolvimento).
  runApp(ProviderScope(overrides: overrides, child: const KaptalixoApp()));
}
