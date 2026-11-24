# sincronizar.ps1 - v1.0 - 24/11/2026
# Traz o CLAUDE.md deste repositorio para ~/.claude/CLAUDE.md sem apagar edicao local
# (mesclagem em tres vias) e confere se o curl precisa de ajuste em rede que inspeciona HTTPS.
#
# Uso (PowerShell):
#   powershell -NoProfile -ExecutionPolicy Bypass -File sincronizar.ps1                  sincroniza e confere o curl
#   powershell -NoProfile -ExecutionPolicy Bypass -File sincronizar.ps1 -Registrar       idem e agenda a execucao diaria
#   powershell -NoProfile -ExecutionPolicy Bypass -File sincronizar.ps1 -SoPreferencias  sem o curl (usado por publicar.sh)
# Saida: 0 = ok; 1 = erro (nada alterado); 2 = precisa de decisao (nada alterado); 3 = outra execucao em andamento.
# Registro: %LOCALAPPDATA%\preferencias-claude\sincronizar.log

param([switch]$Registrar, [switch]$SoPreferencias)

$ErrorActionPreference = 'Continue'
$repo   = $PSScriptRoot
$estado = Join-Path $env:LOCALAPPDATA 'preferencias-claude'
$logf   = Join-Path $estado 'sincronizar.log'
$basef  = Join-Path $estado 'base-CLAUDE.md'
$local  = Join-Path $env:USERPROFILE '.claude\CLAUDE.md'
$remoto = Join-Path $repo 'CLAUDE.md'
$tarefa = 'Claude - sincronizar preferencias'
$utf8   = New-Object System.Text.UTF8Encoding($false)
New-Item -ItemType Directory -Force -Path $estado | Out-Null

function Write-Registro([string]$m) {
    $linha = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"
    Add-Content -Path $logf -Value $linha -Encoding UTF8
    Write-Host $linha
}
function Read-Texto($f) {
    if (-not (Test-Path $f)) { return $null }
    return ([IO.File]::ReadAllText($f, $utf8) -replace "`r", '')
}
function Write-Texto($f, $t) { [IO.File]::WriteAllText($f, $t, $utf8) }
function New-Temporario([string]$nome) { Join-Path $estado ("tmp-" + [IO.Path]::GetRandomFileName() + "-$nome") }
function Get-Versao($t) { if ($t -match 'Vers.o (\d+\.\d+)') { return $Matches[1] } else { return '?' } }

# A copia local e exatamente uma versao ja publicada (existe no historico do repositorio)?
function Test-Publicado($t) {
    $tmp = New-Temporario 'local.md'
    try {
        Write-Texto $tmp $t
        $hash = (& git -C $repo hash-object --no-filters $tmp)
        if ($LASTEXITCODE -ne 0 -or -not $hash) { return $false }
        & git -C $repo cat-file -e $hash.Trim() 2>$null
        return ($LASTEXITCODE -eq 0)
    } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
}

# Grava o CLAUDE.md local (com copia anterior) e so depois a base. Qualquer falha interrompe.
function Set-Local($lidoAntes, $novoLocal, $novaBase) {
    $agora = Read-Texto $local
    if (-not ($agora -ceq $lidoAntes)) { throw 'o CLAUDE.md local mudou durante a sincronizacao; nada alterado' }
    if (Test-Path $local) { Copy-Item $local (Join-Path $estado 'CLAUDE.md.anterior') -Force -ErrorAction Stop }
    New-Item -ItemType Directory -Force -Path (Split-Path $local) -ErrorAction Stop | Out-Null
    Write-Texto $local $novoLocal
    Write-Texto $basef $novaBase
}

function Sync-Preferencias {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Registro 'ERRO: git nao encontrado; CLAUDE.md nao sincronizado.'; return 1 }
    $saida = & git -C $repo pull -q --ff-only 2>&1
    if ($LASTEXITCODE -ne 0) { Write-Registro "ERRO: git pull falhou; nada alterado. $saida"; return 1 }

    $tRemoto = Read-Texto $remoto
    if ($null -eq $tRemoto) { Write-Registro 'ERRO: CLAUDE.md nao encontrado no repositorio.'; return 1 }
    $tLocal = Read-Texto $local
    $tBase  = Read-Texto $basef
    # Sem base registrada, so se aceita como base uma copia local identica a uma versao publicada.
    if ($null -eq $tBase -and $null -ne $tLocal -and (Test-Publicado $tLocal)) { $tBase = $tLocal }

    if ($tLocal -ceq $tRemoto) {
        Write-Texto $basef $tRemoto
        Write-Registro "CLAUDE.md: local igual ao repositorio (versao $(Get-Versao $tRemoto))."
        return 0
    }
    if ($null -eq $tLocal -or $tLocal -ceq $tBase) {
        Set-Local $tLocal $tRemoto $tRemoto
        if ($null -eq $tLocal) { Write-Registro "CLAUDE.md: criado na versao $(Get-Versao $tRemoto)." }
        else { Write-Registro "CLAUDE.md: local atualizado de $(Get-Versao $tLocal) para $(Get-Versao $tRemoto)." }
        return 0
    }
    if ($null -eq $tBase) {
        Write-Registro 'DECISAO: o CLAUDE.md local tem edicao que nao veio do repositorio e nao ha base comprovada para mesclar; nada alterado. Mescle a mao (ou peca ao Claude) e rode de novo.'
        return 2
    }
    if ($tRemoto -ceq $tBase) {
        Write-Registro 'CLAUDE.md: edicao local ainda nao publicada; nada novo no repositorio.'
        return 0
    }

    # Os dois mudaram: mesclagem em tres vias.
    $w = New-Temporario 'mescla-local.md'; $b = New-Temporario 'mescla-base.md'; $r = New-Temporario 'mescla-repositorio.md'
    try {
        Write-Texto $w $tLocal; Write-Texto $b $tBase; Write-Texto $r $tRemoto
        & git merge-file -L local -L base -L repositorio $w $b $r
        $n = $LASTEXITCODE
        if ($n -eq 0) {
            Set-Local $tLocal (Read-Texto $w) $tRemoto
            Write-Registro 'CLAUDE.md: edicao local e repositorio mesclados sem conflito; falta publicar (publicar.sh).'
            return 0
        }
        if ($n -ge 1 -and $n -le 127) {
            Copy-Item $w (Join-Path $estado 'CLAUDE.md.conflito') -Force -ErrorAction Stop
            Write-Registro "DECISAO: $n trecho(s) mudaram dos dois lados; nada alterado. Proposta com marcas em $estado\CLAUDE.md.conflito"
            return 2
        }
        Write-Registro "ERRO: git merge-file falhou (codigo $n); nada alterado."
        return 1
    } finally { Remove-Item $w, $b, $r -Force -ErrorAction SilentlyContinue }
}

# Em rede que inspeciona HTTPS com certificado sem endereco de revogacao, o curl do Windows
# (Schannel) recusa os sites; best-effort segue recusando certificado comprovadamente revogado.
function Test-Curl {
    $curlrc = Join-Path $env:USERPROFILE '.curlrc'
    if ((Test-Path $curlrc) -and (Select-String -Path $curlrc -Pattern '^\s*ssl-revoke-best-effort' -Quiet)) {
        Write-Registro 'curl: modo best-effort ja ligado.'; return
    }
    $curl = Join-Path $env:SystemRoot 'System32\curl.exe'
    $errf = New-Temporario 'curl-erro.txt'
    try {
        $p = Start-Process -FilePath $curl -ArgumentList '-sS', '-o', 'NUL', '-m', '20', 'https://api.github.com' `
            -NoNewWindow -Wait -PassThru -RedirectStandardError $errf -ErrorAction Stop
        $erro = Get-Content $errf -Raw -ErrorAction SilentlyContinue
        if ($p.ExitCode -eq 35 -and $erro -match 'REVOCATION') {
            $linhas = @('# Rede que inspeciona HTTPS com certificado sem endereco de revogacao: o curl (Schannel)',
                        '# recusava os sites (CRYPT_E_NO_REVOCATION_CHECK). best-effort segue recusando certificado revogado.',
                        'ssl-revoke-best-effort')
            if (Test-Path $curlrc) { $linhas = @('') + $linhas }
            Add-Content -Path $curlrc -Value $linhas -Encoding ASCII -ErrorAction Stop
            Write-Registro 'curl: a checagem de revogacao falhava nesta rede; .curlrc ligado em best-effort.'
        } else {
            Write-Registro "curl: ok sem ajuste (codigo $($p.ExitCode))."
        }
    } catch { Write-Registro "AVISO: checagem do curl nao concluida: $($_.Exception.Message)" }
    finally { Remove-Item $errf -Force -ErrorAction SilentlyContinue }
}

# Uma execucao por vez (a tarefa agendada e o publicar.sh usam este mesmo script).
try { $trava = [IO.File]::Open((Join-Path $estado 'sincronizar.trava'), 'OpenOrCreate', 'ReadWrite', 'None') }
catch { Write-Registro 'AVISO: outra sincronizacao em andamento; esta foi pulada.'; exit 3 }

$codigo = 0
try {
    if ($Registrar) {
        try {
            $acao    = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`""
            $gatilho = New-ScheduledTaskTrigger -Daily -At '09:00'
            $config  = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
            Register-ScheduledTask -TaskName $tarefa -Action $acao -Trigger $gatilho -Settings $config `
                -Description 'Traz o CLAUDE.md do repositorio preferencias-claude e confere o curl.' -Force -ErrorAction Stop | Out-Null
            Get-ScheduledTask -TaskName $tarefa -ErrorAction Stop | Out-Null
            Write-Registro 'Tarefa agendada registrada: diaria as 09:00 (roda depois, se o computador estava desligado).'
        } catch { Write-Registro "ERRO: tarefa agendada nao registrada: $($_.Exception.Message)"; $codigo = 1 }
    }
    try { $s = Sync-Preferencias } catch { Write-Registro "ERRO: $($_.Exception.Message)"; $s = 1 }
    if ($s -gt $codigo) { $codigo = $s }
    if (-not $SoPreferencias) { Test-Curl }
} finally {
    $trava.Close()
}

# Mantem o registro curto (ultimas 500 linhas).
$todas = @(Get-Content $logf -Encoding UTF8)
if ($todas.Count -gt 500) { $todas | Select-Object -Last 500 | Set-Content $logf -Encoding UTF8 }
exit $codigo
