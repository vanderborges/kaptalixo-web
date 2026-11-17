# kaptalixo-web

App Flutter do Kaptalixo ("Uber da reciclagem"): gerador, catador, ponto de coleta e admin. Este README leva um ambiente limpo (Windows) até a demonstração e lista, sem enfeite, o que ainda NÃO funciona. Convenções: `docs/04` da pasta de especificação.

O projeto tem dois repositórios irmãos: este (front) e `kaptalixo-api` (Supabase: banco, RPCs, seed). Este guia assume a estrutura `Kaptalixo/repositorios/{kaptalixo-web,kaptalixo-api}` e a pasta `Kaptalixo/scripts/`.

## 1. Pré-requisitos

- Git, Flutter SDK (Dart ^3.12), Docker Desktop (em execução), Supabase CLI. Para o alvo Windows: Visual Studio com "Desenvolvimento para desktop com C++".
- Opcional: Deno (testes da Edge Function), `gh` (fluxo de PR).
- Conferência automática, a partir da pasta `Kaptalixo`:

```
scripts\preparar-ambiente.ps1
flutter doctor
```

## 2. Subir a API local (Supabase)

A partir da pasta `Kaptalixo` (sem `cd`; o CLI aceita `--workdir`):

```
supabase start --workdir repositorios/kaptalixo-api
supabase db reset --workdir repositorios/kaptalixo-api
supabase status --workdir repositorios/kaptalixo-api
```

- `db reset` aplica as migrations e o `supabase/seed.sql` (usuários, pontos, preços, parâmetros; liga `modo_demo`).
- `supabase status` mostra a URL (`http://127.0.0.1:54321`) e a chave pública anon local. Dependendo da versão do CLI ela aparece como "anon key" ou "Publishable"; se não aparecer, `supabase status -o env` lista `ANON_KEY`. É uma chave local de desenvolvimento: não a commite.
- Para parar: `supabase stop --workdir repositorios/kaptalixo-api`.

### Mapas, rotas e busca de endereço (OSRM / Nominatim / tiles)

Não há instância local no repositório. Por padrão o app usa os servidores públicos (`router.project-osrm.org`, `nominatim.openstreetmap.org`, `tile.openstreetmap.org`), que são "melhor esforço", têm limites de uso e exigem internet. Para instâncias próprias, passe as URLs por `--dart-define` (seção 3). Sem OSRM o app recorre à estimativa em linha reta (haversine) onde implementado.

## 3. Rodar o app

```
cd repositorios\kaptalixo-web
flutter pub get
flutter run -d windows --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY=<chave anon local>
```

Variáveis `--dart-define` (ver `lib/app/config.dart`):

| Variável | Padrão |
|---|---|
| `SUPABASE_URL` | `http://127.0.0.1:54321` |
| `SUPABASE_ANON_KEY` | sem padrão |
| `OSRM_BASE_URL` | `https://router.project-osrm.org` |
| `NOMINATIM_BASE_URL` | `https://nominatim.openstreetmap.org` |
| `TILE_URL` | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` |
| `CIDADE_DEMO_LAT` / `CIDADE_DEMO_LNG` | `-23.5505` / `-46.6333` (São Paulo) |

Observações:

- **Sem `SUPABASE_ANON_KEY` o app sobe em modo fake**: login com `<papel>@kaptalixo.dev` (e `pendente@kaptalixo.dev`) e repositórios falsos, sem backend. Serve para ver as telas, não para a demo.
- Emulador Android não enxerga `127.0.0.1` do PC: use `--dart-define=SUPABASE_URL=http://10.0.2.2:54321` (veja as limitações de permissão de localização abaixo).
- Alvo web (`flutter run -d chrome`) existe na pasta `web/`, mas não foi validado para a demo.

## 4. Usuários de desenvolvimento (seed local)

Definidos em `repositorios/kaptalixo-api/supabase/seed.sql` (**só POC local**):

- Senha de todos: `Kaptalixo#Dev1`
- E-mails (`@kaptalixo.dev`): `admin@`, `ponto1@..ponto4@`, `gerador1@..gerador5@`, `catador1@..catador9@`.
- `catador9` está **pendente** de aprovação (cai na tela "aguardando"); `catador1..8` estão aprovados. O admin aprova/suspende pela lista de catadores.

## 5. Roteiro de demonstração (≈ 5 min)

Base: `docs/01` §9. Abaixo, o que o código realmente suporta hoje e como executar. O que o smoke automatizado cobre está descrito logo após o roteiro.

Preparação: banco recém-resetado (`db reset`), e o app aberto em 3 janelas (gerador, catador, admin). Atenção: instâncias do app na mesma máquina e no mesmo navegador/perfil compartilham a sessão salva; para três papéis simultâneos use instâncias com perfis de armazenamento distintos (por exemplo, builds/alvos diferentes: Windows + Android/emulador + Chrome em janela anônima). Esse arranjo de 3 telas não foi validado de ponta a ponta.

1. **Admin** (`admin@`): tela inicial lista catadores; o ícone "Painel de demonstração" abre `/admin/demo` (mapa, ações, eventos ao vivo, simulação 1x/10x).
2. **Catador** (`catador1@`): na home, ficar **disponível** (exige localização; ver limitações). Repita com outro catador, se quiser ver a oferta passar de um para outro.
3. **Gerador** (`gerador1@`): a home mostra o mapa; "Chamar coleta" (`/gerador/chamar`) permite escolher/confirmar o endereço (busca Nominatim ou manual), quantidade e tamanho dos sacos e materiais, e cria a solicitação; segue para `/gerador/acompanhar/:id` ("buscando catador").
4. **Catador**: recebe a oferta (home) e aceita ou recusa; ao recusar/expirar, o servidor oferece ao próximo. Aceitar leva a `/catador/rota/:id`, com o mapa da rota até o gerador e depois até o ponto de descarte (pode trocar de ponto).
5. **Gerador**: vê o catador a caminho, ETA calculado no cliente e o **PIN** de coleta (só ele o vê). Segunda solicitação encaixada na rota ativa é feita pelo servidor (matching), depende do catador ainda estar elegível.
6. **Catador**: avança as paradas; ao chegar no gerador digita o PIN que o gerador informa; coleta confirmada. Posição enviada a cada 5 s durante a rota.
7. **Ponto** (o operador cujo ponto é o destino da rota; no seed, o que enxergar a entrega no painel): painel com entregas a caminho; "Confirmar entrega" chama a RPC `confirmar_entrega` (sem pesagem) e a entrega sai da lista com a mensagem "Entrega confirmada".
8. **Avaliação mútua**: o servidor tem a RPC `avaliar`, mas **não há tela** (ver limitações); esta etapa não pode ser demonstrada pela UI.

Simulação de movimento (painel admin): as RPCs `demo_*` existem no banco (T1.6) e o `demo_snapshot` é validado pelo smoke contra o contrato do parser; a simulação pela UI não foi exercitada de ponta a ponta. O catador também pode andar "de verdade" por GPS do dispositivo.

### Smoke da demo (backend, via RPC/REST)

`scripts/smoke-demo.ps1`, a partir da pasta Kaptalixo, com `supabase start` ativo. `-Resetar` roda `db reset` antes e é necessário para repetir (o smoke consome o pedido do `gerador1`):

```
powershell -NoProfile -File repositorios/kaptalixo-web/scripts/smoke-demo.ps1 -Resetar
```

Imprime PASS/FAIL por passo e sai com código 1 se algum falhar. Validado em 2026-11-17 após a T6.3 (21 passos PASS, 0 aviso; passos 19 e 21 usam `confirmar_entrega`): login, disponibilidade, criação do pedido, PIN só para o gerador, matching/oferta, RLS (catador não lê PIN nem o pedido antes do aceite), aceite, paradas coleta+descarte, `demo_snapshot` sem PIN, iniciar rota, posição, chegada, PIN errado recusado (RN08), PIN correto, chegada ao ponto, `v_entrega_a_caminho` visível só ao operador certo, confirmação `confirmar_entrega`, estado final (entregue/concluída/disponível) e confirmação duplicada recusada. Não cobre a UI Flutter.

## 6. Limitações conhecidas (honestas)

Referências em `backlog/PEDIDOS.md`.

- **RPCs `demo_*`** existem no banco (T1.6) e o contrato de `demo_snapshot` bate com o parser (validado no smoke). "Criar catadores/pedido fictício" e "mover catador" não foram exercitados pela UI nem pelo smoke.
- **Avaliação sem tela** (T3.4/T5.4): a RPC `avaliar` existe, o app não tem UI; `aoAvaliar` não está ligado.
- **Permissões de localização**: `AndroidManifest.xml` não declara `ACCESS_FINE/COARSE_LOCATION`, e não há pasta `ios/` (P-015). No Android o GPS não funciona até declará-las; no Windows, a localização do sistema precisa estar ativada. O modo simulação do catador só existe no painel admin; não há seletor de posição manual para o catador.
- **`planejar-rota` (Edge Function) NÃO validada** (P-027): contra o banco local responde 422 `sem_paradas` (não lê o EWKB das paradas), então não há parada de descarte nem `ponto_destino_id` automáticos. O smoke contorna gravando-os com a service role local (passo 09b, com aviso). O app chama a função após o aceite (melhor esforço), mas o descarte só aparece quando P-027 for corrigido. `pontos_proximos` e `v_entrega_a_caminho` existem e foram validados no smoke; `v_atendimento_gerador` e o valor estimado em `v_oferta_resumo` não existem (P-019..P-023).
- **ETA/polyline do gerador** são calculados no cliente (OSRM público ou haversine), não oficiais do servidor.
- **Sem UI** para foto da solicitação e agendamento. O ponto só confirma a entrega: **não há pesagem nem valor pago** (a RPC `registrar_entrega` segue no banco, sem tela).
- **Serviços públicos** (OSRM, Nominatim, tiles) podem limitar ou falhar; Nominatim: 1 req/s.
- **Build/execução**: validado apenas o alvo Windows desktop no desenvolvimento; testes de integração (`integration_test/`) ainda sem cenários E2E (só `helpers/`). Android, web e iOS não foram validados.
- Auth é e-mail/senha local, sem confirmação; sem pagamento real nem push nativo (fora da POC).

## 7. Qualidade e testes

A partir da pasta `Kaptalixo`:

```
scripts\verificar.ps1
```

Roda `flutter pub get`, `dart format --set-exit-if-changed`, `flutter analyze` e `flutter test` neste repositório; e, na API, `supabase db reset`, `supabase test db` (pgTAP) e testes Deno (se houver Deno). Precisa de Docker ativo. Só o front: `cd repositorios\kaptalixo-web; flutter analyze; flutter test`.

Fluxo de git e PRs: `docs/08-repositorios-e-fluxo-git.md`. Nunca commite segredos.
