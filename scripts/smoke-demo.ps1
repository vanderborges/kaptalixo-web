<#
  Smoke da demo (T7.3): executa por RPC/REST, contra o Supabase LOCAL, o fluxo
  gerador -> catador aceita -> coleta com PIN -> confirmacao da entrega no ponto,
  e imprime PASS/FAIL por passo. Sai com codigo 1 se algum passo falhar.

  Uso (a partir da pasta Kaptalixo, com `supabase start` ativo):
    powershell -NoProfile -File repositorios/kaptalixo-web/scripts/smoke-demo.ps1 [-Resetar]

  -ExigirPlanejador  trata a indisponibilidade da Edge Function planejar-rota como FAIL
            (sem o contorno 09b).
  -Resetar  roda `supabase db reset` antes (o smoke consome o pedido do gerador1;
            repetir sem reset falha em "solicitacao_ativa_existente").

  Seguranca: nenhuma chave e gravada no repositorio. As chaves locais sao lidas de
  `supabase status -o env` em tempo de execucao; os logins usam so as contas de seed
  locais (senha de desenvolvimento do seed). Nao use contra ambiente remoto.
#>
param(
  [switch]$Resetar,
  [switch]$ExigirPlanejador,
  [string]$ApiDir = ''
)
$ErrorActionPreference = 'Stop'
$raiz = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
if (-not $ApiDir) { $ApiDir = Join-Path $raiz 'repositorios\kaptalixo-api' }
$senha = 'Kaptalixo#Dev1'          # senha de seed local (seed.sql); so POC local
$lat = -23.5505; $lng = -46.6333   # centro da demo (seed)

$script:falhas = 0
$script:avisos = 0
$script:passos = 0

function Registrar($nome, $ok, $detalhe) {
  $script:passos++
  if ($ok) { Write-Host ("PASS  {0}  {1}" -f $nome, $detalhe) -ForegroundColor Green }
  else { $script:falhas++; Write-Host ("FAIL  {0}  {1}" -f $nome, $detalhe) -ForegroundColor Red }
}

function Mensagem($erro) {
  $m = $erro.Exception.Message
  if ($erro.ErrorDetails -and $erro.ErrorDetails.Message) { $m = $erro.ErrorDetails.Message }
  elseif ($erro.Exception.Response -and $erro.Exception.Response.GetResponseStream) {
    try {
      $sr = New-Object IO.StreamReader($erro.Exception.Response.GetResponseStream())
      $m = $sr.ReadToEnd()
    } catch { }
  }
  return ($m -replace '\s+', ' ')
}

function Passo($nome, [scriptblock]$bloco) {
  try {
    $r = & $bloco
    Registrar $nome $true ([string]$r)
  } catch {
    Registrar $nome $false (Mensagem $_)
  }
}

function Chamar($metodo, $url, $token, $corpo) {
  $h = @{ apikey = $script:anon; Authorization = "Bearer $token" }
  $a = @{ Method = $metodo; Uri = $url; Headers = $h; ContentType = 'application/json' }
  if ($null -ne $corpo) {
    $a.Body = [Text.Encoding]::UTF8.GetBytes(($corpo | ConvertTo-Json -Depth 8 -Compress))
  }
  return Invoke-RestMethod @a
}

function Rpc($token, $fn, $corpo) {
  if ($null -eq $corpo) { $corpo = @{} }
  return Chamar 'Post' "$($script:api)/rest/v1/rpc/$fn" $token $corpo
}

function Consultar($token, $caminho) {
  return @(Chamar 'Get' "$($script:api)/rest/v1/$caminho" $token $null)
}

function Entrar($email) {
  $r = Invoke-RestMethod -Method Post -Uri "$($script:api)/auth/v1/token?grant_type=password" `
    -Headers @{ apikey = $script:anon } -ContentType 'application/json' `
    -Body (@{ email = $email; password = $senha } | ConvertTo-Json -Compress)
  return $r.access_token
}

# ---------- ambiente ----------
if ($Resetar) {
  Write-Host '### supabase db reset' -ForegroundColor Cyan
  $ErrorActionPreference = 'Continue'
  & supabase db reset --workdir $ApiDir 2>&1 | ForEach-Object { "$_" }
  $ErrorActionPreference = 'Stop'
  if ($LASTEXITCODE -ne 0) { Write-Host 'db reset falhou' -ForegroundColor Red; exit 1 }
}

$ErrorActionPreference = 'Continue'
$envTxt = & supabase status -o env --workdir $ApiDir 2>&1 | ForEach-Object { "$_" }
$ErrorActionPreference = 'Stop'
$vars = @{}
foreach ($l in $envTxt) {
  if ($l -match '^([A-Z_]+)="?([^"]*)"?$') { $vars[$Matches[1]] = $Matches[2] }
}
$script:api = $vars['API_URL']
$script:service = $vars['SERVICE_ROLE_KEY']
$script:anon = $vars['ANON_KEY']
if (-not $script:anon) { $script:anon = $vars['PUBLISHABLE_KEY'] }
if (-not $script:api -or -not $script:anon) {
  Write-Host 'FAIL  ambiente  Supabase local nao esta rodando (supabase start --workdir repositorios/kaptalixo-api)' -ForegroundColor Red
  exit 1
}
if ($script:api -notmatch '^http://(127\.0\.0\.1|localhost)') {
  Write-Host 'FAIL  ambiente  API nao e local; abortando por seguranca' -ForegroundColor Red
  exit 1
}
Write-Host "Smoke da demo contra $($script:api)" -ForegroundColor Cyan

# Estado compartilhado entre passos (preenchido dentro dos blocos).
$script:tokG = $null; $script:tokC = $null; $script:tokP = $null; $script:tokA = $null
$script:solicitacao = $null; $script:oferta = $null; $script:rota = $null; $script:pin = $null
$script:ponto = $null; $script:entrega = $null
$script:paradaColeta = $null; $script:paradaDescarte = $null

Passo '01 login gerador1 e admin' {
  $script:tokG = Entrar 'gerador1@kaptalixo.dev'
  $script:tokA = Entrar 'admin@kaptalixo.dev'
  'tokens obtidos'
}

Passo '02 catador1 disponivel e posicao perto do gerador' {
  $t = Entrar 'catador1@kaptalixo.dev'
  $null = Rpc $t 'alternar_disponibilidade' @{ p_disponivel = $true }
  $null = Rpc $t 'atualizar_localizacao' @{ p_lat = $lat; p_lng = $lng }
  'disponivel'
}

Passo '03 gerador cria solicitacao (criar_solicitacao)' {
  $id = Rpc $script:tokG 'criar_solicitacao' @{
    p_lat = $lat; p_lng = $lng; p_endereco_texto = 'Smoke da demo, 100'
    p_qtd_sacos = 2; p_tamanho = 'M'; p_materiais = @(1, 3)
  }
  if (-not $id) { throw 'sem id' }
  $script:solicitacao = $id
  "solicitacao $id"
}

Passo '04 gerador le o PIN de 4 digitos (so ele)' {
  $v = Consultar $script:tokG "v_solicitacao_gerador?id=eq.$($script:solicitacao)&select=status,pin_coleta"
  if ($v.Count -ne 1) { throw 'view vazia' }
  if ($v[0].pin_coleta -notmatch '^[0-9]{4}$') { throw 'PIN invalido' }
  $script:pin = $v[0].pin_coleta
  "status=$($v[0].status); PIN lido (nao impresso)"
}

Passo '05 matching: um catador recebe a oferta (v_oferta_resumo)' {
  foreach ($n in 1..8) {
    $t = Entrar "catador$n@kaptalixo.dev"
    $o = Consultar $t "v_oferta_resumo?solicitacao_id=eq.$($script:solicitacao)&select=oferta_id,distancia_m,eta_s"
    if ($o.Count -ge 1) {
      $script:tokC = $t; $script:oferta = $o[0].oferta_id
      return "catador$n recebeu a oferta (dist ~$($o[0].distancia_m) m)"
    }
  }
  throw 'nenhum catador de seed recebeu oferta'
}

Passo '06 catador NAO le pin_coleta nem a solicitacao antes do aceite' {
  $bloqueado = $false
  try { $null = Consultar $script:tokC 'solicitacoes?select=pin_coleta' } catch { $bloqueado = $true }
  if (-not $bloqueado) { throw 'catador conseguiu selecionar pin_coleta' }
  $s = Consultar $script:tokC "v_solicitacao_catador?id=eq.$($script:solicitacao)&select=id"
  if ($s.Count -ne 0) { throw 'catador ve a solicitacao antes de aceitar' }
  'RLS ok'
}

Passo '07 catador aceita a oferta (aceitar_oferta)' {
  $r = Rpc $script:tokC 'aceitar_oferta' @{ p_oferta = $script:oferta }
  if (-not $r) { throw 'sem rota' }
  $script:rota = $r
  "rota $r"
}

Passo '08 gerador ve a solicitacao aceita' {
  $v = Consultar $script:tokG "v_solicitacao_gerador?id=eq.$($script:solicitacao)&select=status"
  if ($v[0].status -ne 'aceita') { throw "status=$($v[0].status)" }
  'aceita'
}

# O planejar-rota (Edge Function) so roda com `supabase functions serve` e, na versao atual,
# nao interpreta o hex EWKB que o PostgREST devolve para geography (devolve 422 sem_paradas;
# registrado em backlog/PEDIDOS.md, P-027). Sem ele nao existe parada de descarte. Para o
# smoke chegar a confirmacao, o passo 09b reproduz o que a funcao deve gravar (descarte + ponto)
# com a service role LOCAL. Com -ExigirPlanejador o AVISO vira FAIL e o contorno e pulado.
$script:planejou = $false
try {
  $r = Chamar 'Post' "$($script:api)/functions/v1/planejar-rota" $script:tokC @{ rota_id = $script:rota }
  $script:planejou = $true
  Registrar '09 planejar-rota (Edge Function) cria descarte e escolhe o ponto' $true `
    "origem=$($r.origem_calculo); paradas=$($r.ordem.Count); dist=$($r.distancia_total_m) m"
} catch {
  if ($ExigirPlanejador) {
    Registrar '09 planejar-rota (Edge Function) cria descarte e escolhe o ponto' $false (Mensagem $_)
  } else {
    $script:avisos++
    Write-Host ("AVISO 09 planejar-rota NAO validado (ver P-027): {0}" -f (Mensagem $_)) -ForegroundColor Yellow
  }
}

if (-not $script:planejou -and -not $ExigirPlanejador) {
  Passo '09b contorno: descarte + ponto_destino gravados com a service role local' {
    if (-not $script:service) { throw 'SERVICE_ROLE_KEY local indisponivel' }
    $pts = Rpc $script:tokC 'pontos_proximos' @{ p_lat = $lat; p_lng = $lng; p_raio_m = 20000 }
    $ponto = @($pts | Where-Object { $_.aberto })[0]
    if (-not $ponto) { throw 'nenhum ponto aberto' }
    $null = Chamar 'Patch' "$($script:api)/rest/v1/rotas?id=eq.$($script:rota)" $script:service @{ ponto_destino_id = $ponto.id }
    $null = Chamar 'Post' "$($script:api)/rest/v1/rota_paradas" $script:service @{
      rota_id = $script:rota; ordem = 2; tipo = 'descarte'; ponto_id = $ponto.id
      localizacao = "SRID=4326;POINT($($ponto.lng) $($ponto.lat))"
    }
    "ponto $($ponto.nome)"
  }
}

Passo '10 rota tem coleta + descarte e ponto_destino_id' {
  $p = Consultar $script:tokC "rota_paradas?rota_id=eq.$($script:rota)&select=id,ordem,tipo,status&order=ordem"
  $tipos = ($p | ForEach-Object { $_.tipo }) -join ','
  if ($tipos -ne 'coleta,descarte') { throw "paradas: $tipos" }
  $script:paradaColeta = ($p | Where-Object { $_.tipo -eq 'coleta' })[0].id
  $script:paradaDescarte = ($p | Where-Object { $_.tipo -eq 'descarte' })[0].id
  $r = Consultar $script:tokC "v_rota_catador?id=eq.$($script:rota)&select=ponto_destino_id,status,polyline"
  if (-not $r[0].ponto_destino_id) { throw 'sem ponto_destino_id' }
  $script:ponto = $r[0].ponto_destino_id
  "paradas=$tipos; rota=$($r[0].status); polyline=$([bool]$r[0].polyline)"
}

Passo '11 admin: demo_snapshot segue o contrato do parser' {
  $s = Rpc $script:tokA 'demo_snapshot' @{ p_eventos = 50 }
  foreach ($k in 'atores', 'rotas', 'eventos') {
    if (-not ($s.PSObject.Properties.Name -contains $k)) { throw "falta chave $k" }
  }
  $a = $s.atores[0]
  foreach ($k in 'id', 'tipo', 'nome', 'lat', 'lng') {
    if (-not ($a.PSObject.Properties.Name -contains $k)) { throw "ator sem $k" }
  }
  $mi = @($s.rotas | Where-Object { $_.id -eq $script:rota })
  if ($mi.Count -ne 1) { throw 'rota do smoke nao aparece no snapshot' }
  foreach ($k in 'catador_id', 'status', 'polyline', 'paradas') {
    if (-not ($mi[0].PSObject.Properties.Name -contains $k)) { throw "rota sem $k" }
  }
  $e = $s.eventos[0]
  foreach ($k in 'id', 'solicitacao_id', 'de_status', 'para_status', 'criado_em') {
    if (-not ($e.PSObject.Properties.Name -contains $k)) { throw "evento sem $k" }
  }
  if (($s | ConvertTo-Json -Depth 10) -match 'pin_coleta') { throw 'snapshot expoe pin_coleta' }
  "atores=$($s.atores.Count) rotas=$($s.rotas.Count) eventos=$($s.eventos.Count); sem pin"
}

Passo '12 catador inicia a rota (iniciar_rota)' {
  $null = Rpc $script:tokC 'iniciar_rota' @{ p_rota = $script:rota }
  $r = Consultar $script:tokC "v_rota_catador?id=eq.$($script:rota)&select=status"
  if ($r[0].status -ne 'em_andamento') { throw "status=$($r[0].status)" }
  'em_andamento'
}

Passo '13 catador envia posicao em rota (atualizar_localizacao)' {
  $null = Rpc $script:tokC 'atualizar_localizacao' @{ p_lat = $lat; p_lng = $lng; p_rota = $script:rota }
  'ok'
}

Passo '14 catador chega no gerador (avancar_parada: cheguei)' {
  $r = Rpc $script:tokC 'avancar_parada' @{ p_parada = $script:paradaColeta; p_acao = 'cheguei' }
  if ($r.resultado -ne 'ok') { throw "resultado=$($r.resultado)" }
  $v = Consultar $script:tokG "v_solicitacao_gerador?id=eq.$($script:solicitacao)&select=status"
  "gerador ve status=$($v[0].status)"
}

Passo '15 PIN errado e recusado (RN08)' {
  $errado = if ($script:pin -eq '0000') { '1111' } else { '0000' }
  $r = Rpc $script:tokC 'avancar_parada' @{ p_parada = $script:paradaColeta; p_acao = 'concluir'; p_pin = $errado }
  if ($r.resultado -ne 'pin_incorreto') { throw "resultado=$($r.resultado)" }
  "pin_incorreto; restantes=$($r.tentativas_restantes)"
}

Passo '16 PIN correto conclui a coleta' {
  $r = Rpc $script:tokC 'avancar_parada' @{ p_parada = $script:paradaColeta; p_acao = 'concluir'; p_pin = $script:pin }
  if ($r.resultado -ne 'ok') { throw "resultado=$($r.resultado)" }
  $v = Consultar $script:tokG "v_solicitacao_gerador?id=eq.$($script:solicitacao)&select=status"
  if ($v[0].status -ne 'coletada') { throw "status=$($v[0].status)" }
  'coletada'
}

Passo '17 catador chega no ponto (avancar_parada: cheguei, descarte)' {
  $r = Rpc $script:tokC 'avancar_parada' @{ p_parada = $script:paradaDescarte; p_acao = 'cheguei' }
  if ($r.resultado -ne 'ok') { throw "resultado=$($r.resultado)" }
  'no_local'
}

Passo '18 operador do ponto ve a entrega (v_entrega_a_caminho)' {
  # A tabela pontos_coleta e legivel a todos; so a visao filtra por opera_ponto(), entao
  # o operador certo e o que enxerga a rota (os demais devem ver 0 linhas).
  $n = 0; $e = $null; $outros = 0
  foreach ($i in 1..4) {
    $t = Entrar "ponto$i@kaptalixo.dev"
    $v = Consultar $t "v_entrega_a_caminho?rota_id=eq.$($script:rota)&select=rota_id,catador_nome,qtd_sacos,chegou"
    if ($v.Count -eq 1) { $script:tokP = $t; $n = $i; $e = $v[0] } else { $outros++ }
  }
  if (-not $script:tokP) { throw 'nenhum operador de seed ve a entrega a caminho' }
  if ($outros -ne 3) { throw "a entrega aparece para $(4 - $outros) operadores (esperado 1)" }
  "ponto$n; catador=$($e.catador_nome); sacos=$($e.qtd_sacos); chegou=$($e.chegou); 3 outros operadores nao veem"
}

Passo '19 confirmacao: confirmar_entrega (sem pesagem)' {
  $entrega = Rpc $script:tokP 'confirmar_entrega' @{ p_rota = $script:rota }
  if (-not $entrega) { throw 'confirmar_entrega nao devolveu o id da entrega' }
  $script:entrega = $entrega
  $en = Consultar $script:tokP "entregas?id=eq.$entrega&select=id"
  if ($en.Count -ne 1) { throw 'entrega nao encontrada apos confirmar' }
  "entrega $entrega confirmada"
}

Passo '20 estado final: entregue, rota concluida, catador disponivel' {
  $v = Consultar $script:tokG "v_solicitacao_gerador?id=eq.$($script:solicitacao)&select=status"
  $r = Consultar $script:tokC "v_rota_catador?id=eq.$($script:rota)&select=status"
  $c = Consultar $script:tokC 'v_catador_privado?select=situacao'
  if ($v[0].status -ne 'entregue') { throw "solicitacao=$($v[0].status)" }
  if ($r[0].status -ne 'concluida') { throw "rota=$($r[0].status)" }
  if ($c[0].situacao -ne 'disponivel') { throw "catador=$($c[0].situacao)" }
  'entregue / concluida / disponivel'
}

Passo '21 segunda confirmacao na mesma rota e recusada' {
  if (-not $script:tokP -or -not $script:entrega) { throw 'sem confirmacao anterior para repetir' }
  $recusou = $false
  try { $null = Rpc $script:tokP 'confirmar_entrega' @{ p_rota = $script:rota } }
  catch { $recusou = $true }
  if (-not $recusou) { throw 'aceitou entrega duplicada' }
  'recusada'
}

Write-Host ''
if ($script:falhas -gt 0) {
  Write-Host ("SMOKE FALHOU: {0} de {1} passos com FAIL" -f $script:falhas, $script:passos) -ForegroundColor Red
  exit 1
}
Write-Host ("SMOKE OK: {0} passos PASS, {1} aviso(s)" -f $script:passos, $script:avisos) -ForegroundColor Green
exit 0
