# kaptalixo-web

App Flutter do Kaptalixo (gerador, catador, ponto e admin). Estrutura e convenções: `docs/04` da pasta de especificação.

```
flutter pub get
flutter analyze
flutter test
flutter run -d windows --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY=<chave local>
```

Variáveis `--dart-define`: `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `OSRM_BASE_URL`, `NOMINATIM_BASE_URL`, `TILE_URL`, `CIDADE_DEMO_LAT`, `CIDADE_DEMO_LNG` (ver `lib/app/config.dart`). Nunca commitar segredos.

## Login em desenvolvimento (seed local)

Sem `SUPABASE_ANON_KEY` o app usa um repositório de auth falso (`<papel>@kaptalixo.dev`, `pendente@kaptalixo.dev`). Com a chave do `supabase start`, entra de verdade com os usuários do seed (**só POC local**):

- Senha de todos: `Kaptalixo#Dev1`
- E-mails: `admin@`, `ponto1..4@`, `gerador1..5@`, `catador1..9@` + `kaptalixo.dev` (`catador9` está pendente).
