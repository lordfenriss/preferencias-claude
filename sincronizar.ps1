# sincronizar.ps1 - v1.1 - 24/11/2026
# Mudancas: 1.1 - instala e atualiza as skills do claude-mods (vinculos em ~/.claude/skills para um
#   clone proprio), sem apagar edicao local. Clone e fetch com limite de tempo (-LimiteRede, 180 s);
#   o teste do curl roda antes das skills.
#
# Traz o CLAUDE.md deste repositorio para ~/.claude/CLAUDE.md sem apagar edicao local (mesclagem em
# tres vias), mantem as skills do repositorio privado claude-mods e confere se o curl precisa de ajuste
# em rede que inspeciona HTTPS.
#
# Uso (PowerShell):
#   powershell -NoProfile -ExecutionPolicy Bypass -File sincronizar.ps1                  preferencias, skills e curl
#   powershell -NoProfile -ExecutionPolicy Bypass -File sincronizar.ps1 -Registrar       idem e agenda a execucao diaria
#   powershell -NoProfile -ExecutionPolicy Bypass -File sincronizar.ps1 -SoPreferencias  so o CLAUDE.md (usado por publicar.sh)
# Saida: 0 = ok; 1 = erro (nada alterado); 2 = precisa de decisao (nada alterado); 3 = outra execucao em andamento.
# Registro: %LOCALAPPDATA%\preferencias-claude\sincronizar.log
#
# Skills: cada skill do claude-mods vira, em ~/.claude/skills, um vinculo (junction) para a pasta dela
# num clone proprio em %LOCALAPPDATA%\preferencias-claude\claude-mods, atualizado com git pull --ff-only
# (o Git recusa a atualizacao se ela tocar arquivo editado aqui). Copia solta so vira vinculo se for
# identica a uma versao publicada; a anterior fica em skills-anteriores\. Nomes que esta maquina nao
# recebe: skills-fora.txt, um por linha. Maquina com o clone de trabalho em ~/.claudecode/mods (a
# principal, vinculos do checar-skills) fica de fora.

param([switch]$Registrar, [switch]$SoPreferencias, [int]$LimiteRede = 180)

$ErrorActionPreference = 'Continue'
$repo   = $PSScriptRoot
$estado = Join-Path $env:LOCALAPPDATA 'preferencias-claude'
$logf   = Join-Path $estado 'sincronizar.log'
$basef  = Join-Path $estado 'base-CLAUDE.md'
$local  = Join-Path $env:USERPROFILE '.claude\CLAUDE.md'
$remoto = Join-Path $repo 'CLAUDE.md'
$tarefa = 'Claude - sincronizar preferencias'
$utf8   = New-Object System.Text.UTF8Encoding($false)
$modsUrl    = 'https://github.com/lordfenriss/claude-mods.git'
$padraoFora = @('acesso-remoto-casa', 'ideia', 'migrar-codex', 'orquestrar')   # dependem do PC de casa, do ai-memory ou dos scripts codex-casa/agy-casa
$clone      = Join-Path $estado 'claude-mods'
$origem     = Join-Path $clone 'skills'
$foraf      = Join-Path $estado 'skills-fora.txt'
$destSkills = Join-Path $env:USERPROFILE '.claude\skills'
$trabalho   = Join-Path $env:USERPROFILE '.claudecode\mods'
New-Item -ItemType Directory -Force -Path $estado | Out-Null

function Write-Registro([string]$m) {
    $linha = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"
    for ($i = 0; $i -lt 3; $i++) {   # o arquivo pode ficar preso por instantes (antivirus)
        try { Add-Content -Path $logf -Value $linha -Encoding UTF8 -ErrorAction Stop; break } catch { Start-Sleep -Milliseconds 300 }
    }
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

# ---------- Skills do claude-mods ----------

function Get-Entrada($p) {
    $i = Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
    if (-not $i) { return $null }
    $link = [bool]($i.Attributes -band [IO.FileAttributes]::ReparsePoint)
    $alvo = $null
    if ($link) { $alvo = @($i.Target)[0] }
    return [pscustomobject]@{ Item = $i; Link = $link; Alvo = $alvo }
}
function Test-MesmoCaminho($a, $b) {
    if (-not $a -or -not $b) { return $false }
    $a = $a -replace '^\\\\\?\\', ''
    return ([IO.Path]::GetFullPath($a).TrimEnd('\') -ieq [IO.Path]::GetFullPath($b).TrimEnd('\'))
}
# git com limite de tempo (a tarefa agendada morre em 10 min e o curl vem depois); mata a arvore de processos ao estourar.
function Invoke-GitLimitado([string[]]$argumentos, [int]$segundos) {
    $of = New-Temporario 'git-out.txt'; $ef = New-Temporario 'git-err.txt'
    try {
        $texto = ($argumentos | ForEach-Object { '"' + ($_ -replace '"', '\"') + '"' }) -join ' '
        $p = Start-Process -FilePath 'git' -ArgumentList $texto -NoNewWindow -PassThru -RedirectStandardOutput $of -RedirectStandardError $ef -ErrorAction Stop
        $null = $p.Handle   # sem isto, no PowerShell 5.1, ExitCode volta nulo depois de WaitForExit com tempo
        if (-not $p.WaitForExit($segundos * 1000)) {
            & taskkill.exe /T /F /PID $p.Id 2>&1 | Out-Null
            return [pscustomobject]@{ Codigo = -1; Saida = "tempo esgotado ($segundos s)" }
        }
        $p.WaitForExit()
        return [pscustomobject]@{ Codigo = $p.ExitCode; Saida = ((Get-Content $of, $ef -Raw -ErrorAction SilentlyContinue) -join ' ').Trim() }
    } finally { Remove-Item $of, $ef -Force -ErrorAction SilentlyContinue }
}
function Remove-Vinculo($p) {
    # So o vinculo; a pasta de destino fica intacta.
    $e = Get-Entrada $p
    if (-not $e -or -not $e.Link) { throw "$p nao e vinculo; nada removido" }
    [IO.Directory]::Delete($p, $false)
}
function Get-SkillsFora {
    if (-not (Test-Path $foraf)) {
        Write-Texto $foraf ("# Skills do claude-mods que esta maquina nao recebe: um nome por linha (# comeca comentario).`n" +
            "# Por um nome aqui tira o vinculo na proxima sincronizacao; tirar o nome instala a skill.`n" +
            (($padraoFora -join "`n") + "`n"))
    }
    return @((Read-Texto $foraf) -split "`n" | ForEach-Object { ($_ -replace '#.*$', '').Trim() } | Where-Object { $_ })
}
function Format-Assinatura($linhas) {
    $a = [string[]]@($linhas)
    [Array]::Sort($a, [StringComparer]::Ordinal)
    return ($a -join "`n")
}
# A pasta solta em ~/.claude/skills e identica a alguma versao publicada da skill (mesmos arquivos, mesmo conteudo)?
function Test-SkillPublicada($pasta, $nome) {
    $base = $pasta.TrimEnd('\')
    $locais = New-Object System.Collections.Generic.List[string]
    foreach ($a in @(Get-ChildItem -LiteralPath $base -Recurse -File -Force -ErrorAction Stop)) {
        $rel = $a.FullName.Substring($base.Length + 1) -replace '\\', '/'
        if ($rel -match '(^|/)__pycache__/') { continue }   # regeneravel; estado.json local NAO e ignorado (e dado do usuario)
        $h = & git -C $clone hash-object "--path=skills/$nome/$rel" -- $a.FullName
        if ($LASTEXITCODE -ne 0 -or -not $h) { return $false }
        $locais.Add("$rel $("$h".Trim())")
    }
    $assinatura = Format-Assinatura $locais.ToArray()
    $prefixo = "skills/$nome/"
    # So o historico remoto (origin) comprova publicacao; branch local do clone nao conta.
    foreach ($c in @(& git -C $clone rev-list --remotes=origin -- "skills/$nome")) {
        $versao = foreach ($x in @(& git -c core.quotepath=off -C $clone ls-tree -r $c -- $prefixo)) {
            $meta, $caminho = $x -split "`t", 2
            "$($caminho.Substring($prefixo.Length)) $(($meta -split ' ')[2])"
        }
        if ((Format-Assinatura $versao) -ceq $assinatura) { return $true }
    }
    return $false
}

function Sync-Skills {
    if ((Test-Path (Join-Path $trabalho 'skills')) -and (Test-Path (Join-Path $trabalho '.git'))) {
        Write-Registro 'skills: esta maquina usa o clone de trabalho em ~/.claudecode/mods (vinculos do checar-skills); nada a fazer.'
        return 0
    }
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Registro 'ERRO: git nao encontrado; skills nao sincronizadas.'; return 1 }
    # Na execucao agendada o Git nao pode abrir janela de login (ficaria esperando); com -Registrar pode.
    if (-not $Registrar) { $env:GCM_INTERACTIVE = 'never'; $env:GIT_TERMINAL_PROMPT = '0' }
    try { [Console]::OutputEncoding = $utf8 } catch { }

    if (-not (Test-Path (Join-Path $clone '.git'))) {
        $g = Invoke-GitLimitado @('clone', '-q', $modsUrl, $clone) $LimiteRede
        if ($g.Codigo -ne 0) {
            Write-Registro "ERRO: clone do claude-mods falhou (repositorio privado: falta o login do GitHub nesta maquina?); skills nao sincronizadas. $($g.Saida)"
            return 1
        }
    } else {
        $g = Invoke-GitLimitado @('-C', $clone, 'fetch', '-q') $LimiteRede
        if ($g.Codigo -ne 0) { Write-Registro "ERRO: git fetch do claude-mods falhou; skills nao alteradas. $($g.Saida)"; return 1 }
        # --no-autostash e --no-overwrite-ignore: nem configuracao herdada nem arquivo ignorado localmente furam a recusa.
        $g = Invoke-GitLimitado @('-C', $clone, 'merge', '-q', '--ff-only', '--no-autostash', '--no-overwrite-ignore', '@{u}') 60
        if ($g.Codigo -ne 0) {
            $editados = @(& git -C $clone status --porcelain) -join '; '
            $detalhe = ($g.Saida -replace '\s+', ' ').Trim()
            if ($detalhe.Length -gt 400) { $detalhe = $detalhe.Substring(0, 400) + '...' }
            Write-Registro ("DECISAO: a atualizacao do claude-mods toca skill editada aqui (ou o clone tem commit que nao esta no GitHub); " +
                "skills nao alteradas. Editados: $editados. Git: $detalhe Publique a edicao no claude-mods (ou peca ao Claude) e rode de novo. Clone: $clone")
            return 2
        }
    }
    $versao = "$(& git -C $clone rev-parse --short HEAD)".Trim()
    if (-not (Test-Path $origem)) { Write-Registro "ERRO: pasta skills nao encontrada em $clone."; return 1 }
    New-Item -ItemType Directory -Force -Path $destSkills | Out-Null

    $fora = Get-SkillsFora
    $nomes = @(Get-ChildItem -LiteralPath $origem -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') } |
               ForEach-Object { $_.Name })
    $novas = @(); $trocadas = @(); $removidas = @(); $mantidas = @(); $outras = @(); $ativas = 0
    $guarda = Join-Path $estado ('skills-anteriores\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $codigo = 0

    foreach ($n in $nomes) {
        $dest = Join-Path $destSkills $n
        $alvo = Join-Path $origem $n
        try {
            $e = Get-Entrada $dest
            if ($fora -contains $n) {
                if ($e -and $e.Link -and (Test-MesmoCaminho $e.Alvo $alvo)) { Remove-Vinculo $dest; $removidas += "$n (em skills-fora.txt)" }
                continue
            }
            if (-not $e) {
                New-Item -ItemType Junction -Path $dest -Target $alvo -ErrorAction Stop | Out-Null
                $novas += $n; $ativas++; continue
            }
            if ($e.Link) {
                if (Test-MesmoCaminho $e.Alvo $alvo) { $ativas++ } else { $outras += $n }
                continue
            }
            if ($e.Item.PSIsContainer -and (Test-SkillPublicada $dest $n)) {
                New-Item -ItemType Directory -Force -Path $guarda -ErrorAction Stop | Out-Null
                Move-Item -LiteralPath $dest -Destination (Join-Path $guarda $n) -ErrorAction Stop
                try { New-Item -ItemType Junction -Path $dest -Target $alvo -ErrorAction Stop | Out-Null }
                catch { Move-Item -LiteralPath (Join-Path $guarda $n) -Destination $dest -ErrorAction SilentlyContinue; throw }
                $trocadas += $n; $ativas++; continue
            }
            $mantidas += $n
        } catch { Write-Registro "ERRO: skill $n nao sincronizada: $($_.Exception.Message)"; $codigo = 1 }
    }

    # Vinculo para skill que saiu do repositorio: aponta para pasta que nao existe mais.
    foreach ($i in @(Get-ChildItem -LiteralPath $destSkills -Force -ErrorAction SilentlyContinue)) {
        $e = Get-Entrada $i.FullName
        if (-not $e -or -not $e.Link -or $nomes -contains $i.Name) { continue }
        if ((Test-MesmoCaminho $e.Alvo (Join-Path $origem $i.Name)) -and -not (Test-Path -LiteralPath $e.Alvo)) {
            try { Remove-Vinculo $i.FullName; $removidas += "$($i.Name) (saiu do claude-mods)" }
            catch { Write-Registro "ERRO: vinculo $($i.Name) nao removido: $($_.Exception.Message)"; $codigo = 1 }
        }
    }

    $msg = "skills: claude-mods em $versao; $ativas vinculadas"
    if ($novas)     { $msg += "; novas: $($novas -join ', ')" }
    if ($trocadas)  { $msg += "; copias soltas trocadas por vinculo (anteriores em $guarda): $($trocadas -join ', ')" }
    if ($removidas) { $msg += "; removidas: $($removidas -join ', ')" }
    if ($outras)    { $msg += "; vinculadas a outra pasta, mantidas: $($outras -join ', ')" }
    Write-Registro "$msg."
    $editados = @(& git -C $clone status --porcelain -- skills)
    if ($editados) { Write-Registro "skills: edicao local ainda nao publicada no claude-mods: $($editados -join '; ')" }
    if ($mantidas) {
        Write-Registro ("DECISAO: skill(s) com edicao local que nao veio do claude-mods, mantidas sem atualizacao: $($mantidas -join ', '). " +
            "Para receber o repositorio, publique a edicao no claude-mods ou mova a pasta; para nao receber, ponha o nome em $foraf.")
        if ($codigo -eq 0) { $codigo = 2 }
    }
    return $codigo
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
                -Description 'Traz o CLAUDE.md do repositorio preferencias-claude e as skills do claude-mods e confere o curl.' -Force -ErrorAction Stop | Out-Null
            Get-ScheduledTask -TaskName $tarefa -ErrorAction Stop | Out-Null
            Write-Registro 'Tarefa agendada registrada: diaria as 09:00 (roda depois, se o computador estava desligado).'
        } catch { Write-Registro "ERRO: tarefa agendada nao registrada: $($_.Exception.Message)"; $codigo = 1 }
    }
    try { $s = Sync-Preferencias } catch { Write-Registro "ERRO: $($_.Exception.Message)"; $s = 1 }
    if ($s -gt $codigo) { $codigo = $s }
    if (-not $SoPreferencias) {
        Test-Curl
        try { $s = Sync-Skills } catch { Write-Registro "ERRO: skills: $($_.Exception.Message)"; $s = 1 }
        if ($s -gt $codigo) { $codigo = $s }
    }
} finally {
    $trava.Close()
}

# Mantem o registro curto (ultimas 500 linhas).
$todas = @(Get-Content $logf -Encoding UTF8)
if ($todas.Count -gt 500) { $todas | Select-Object -Last 500 | Set-Content $logf -Encoding UTF8 }
exit $codigo
