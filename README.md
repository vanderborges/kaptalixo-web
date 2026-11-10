# kaptalixo-web

App Flutter do Kaptalixo (gerador, catador, ponto e admin). Estrutura e convenções: `docs/04` da pasta de especificação.

```
flutter pub get
flutter analyze
flutter test
flutter run -d windows --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY=<chave local>
```

Variáveis `--dart-define`: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `OSRM_BASE_URL`, `NOMINATIM_BASE_URL`, `TILE_URL`, `CIDADE_DEMO_LAT`, `CIDADE_DEMO_LNG` (ver `lib/app/config.dart`). Nunca commitar segredos.
