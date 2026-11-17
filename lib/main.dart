import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/acoes_app.dart';
import 'app/app.dart';
import 'app/config.dart';
import 'recursos/admin/apresentacao/demo_providers.dart';
import 'recursos/admin/apresentacao/providers.dart';
import 'recursos/admin/dados/demo_remoto_supabase.dart';
import 'recursos/admin/dados/demo_repositorio_impl.dart';
import 'recursos/catador/apresentacao/ofertas_providers.dart';
import 'recursos/catador/apresentacao/providers.dart';
import 'recursos/catador/apresentacao/rota_providers.dart';
import 'recursos/catador/dados/disponibilidade_remoto_supabase.dart';
import 'recursos/catador/dados/disponibilidade_repositorio_impl.dart';
import 'recursos/catador/dados/ofertas_remoto_supabase.dart';
import 'recursos/catador/dados/ofertas_repositorio_impl.dart';
import 'recursos/catador/dados/rota_remoto_supabase.dart';
import 'recursos/catador/dados/rota_repositorio_impl.dart';
import 'recursos/gerador/apresentacao/providers.dart';
import 'recursos/gerador/dados/acompanhamento_remoto_supabase.dart';
import 'recursos/gerador/dados/acompanhamento_repositorio_impl.dart';
import 'recursos/gerador/dados/materiais_remoto_supabase.dart';
import 'recursos/gerador/dados/materiais_repositorio_impl.dart';
import 'recursos/gerador/dados/pontos_proximos_remoto_supabase.dart';
import 'recursos/gerador/dados/pontos_proximos_repositorio_impl.dart';
import 'recursos/gerador/dados/solicitacao_remoto_supabase.dart';
import 'recursos/gerador/dados/solicitacao_repositorio_impl.dart';
import 'recursos/ponto/apresentacao/providers.dart';
import 'recursos/ponto/dados/ponto_remoto_supabase.dart';
import 'recursos/ponto/dados/ponto_repositorio_impl.dart';
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
    final cliente = Supabase.instance.client;
    overrides.addAll([
      planejarRotaProvider.overrideWithValue((rotaId) async {
        await cliente.functions.invoke(
          'planejar-rota',
          body: {'rota_id': rotaId},
        );
      }),
      demoRepositorioProvider.overrideWithValue(
        DemoRepositorioImpl(DemoRemotoSupabase(cliente)),
      ),
      solicitacaoRepositorioProvider.overrideWithValue(
        SolicitacaoRepositorioImpl(SolicitacaoRemotoSupabase(cliente)),
      ),
      materiaisRepositorioProvider.overrideWithValue(
        MateriaisRepositorioImpl(MateriaisRemotoSupabase(cliente)),
      ),
      pontosProximosRepositorioProvider.overrideWithValue(
        PontosProximosRepositorioImpl(PontosProximosRemotoSupabase(cliente)),
      ),
      acompanhamentoRepositorioProvider.overrideWithValue(
        AcompanhamentoRepositorioImpl(AcompanhamentoRemotoSupabase(cliente)),
      ),
      disponibilidadeRepositorioProvider.overrideWithValue(
        DisponibilidadeRepositorioImpl(DisponibilidadeRemotoSupabase(cliente)),
      ),
      ofertasRepositorioProvider.overrideWithValue(
        OfertasRepositorioImpl(OfertasRemotoSupabase(cliente)),
      ),
      rotaRepositorioProvider.overrideWithValue(
        RotaRepositorioImpl(RotaRemotoSupabase(cliente)),
      ),
      pontoRepositorioProvider.overrideWithValue(
        PontoRepositorioImpl(PontoRemotoSupabase(cliente)),
      ),
    ]);
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
