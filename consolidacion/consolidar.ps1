<#
.SYNOPSIS
  Pasada diaria de consolidación de la base de conocimiento (ver consolidacion/README.md).
.DESCRIPTION
  Prepara el inventario de fuentes (notas, sesiones de Claude Code, repos con cambios de docs), extrae las sesiones
  a texto y, si hay algo, asegura la rama `consolidacion` y su worktree, fusiona main en ella y lanza Claude Code sin
  interfaz con consolidacion\prompt-consolidador.md. El script (no Claude) gestiona estado.json.
  Códigos de salida: 0 bien (con o sin propuesta), 1 error o pasada incompleta.
.PARAMETER UltimaPasada
  Solo pruebas: fuerza el valor de ultima_pasada (ISO 8601). Con esto el script nunca escribe estado.json.
.PARAMETER SoloInventario
  Solo pruebas: genera inventario y sesiones y termina, sin Claude ni estado.json.
.PARAMETER SimularSalida
  Solo pruebas: en lugar de lanzar Claude usa este texto como salida. No escribe estado.json.
.PARAMETER ForzarGlobo
  Solo pruebas: las notificaciones usan el globo de la bandeja como si BurntToast fallara.
#>
param(
    [string]$UltimaPasada,
    [switch]$SoloInventario,
    [string]$SimularSalida,
    [switch]$ForzarGlobo
)
$ErrorActionPreference = 'Stop'

$Main     = 'C:\SENYUM\base-conocimiento'
$Worktree = 'C:\SENYUM\base-conocimiento-consolidacion'
$Branch   = 'consolidacion'
$Prompt   = Join-Path $Main 'consolidacion\prompt-consolidador.md'
$LogDir   = Join-Path $Main 'consolidacion\logs'
$Trabajo  = Join-Path $Main 'consolidacion\trabajo'
$Estado   = Join-Path $Main 'consolidacion\estado.json'
$Extractor= Join-Path $Main 'consolidacion\extraer_sesiones.py'
$Inventario = Join-Path $Trabajo 'inventario.json'
$LockFile = Join-Path $LogDir '.lock'
$KeepLogs = 30
$Historico = Join-Path $Main 'consolidacion\trabajo-historico'
$KeepHistoricoDias = 30

# Raíces donde buscar repos git (recursivo, hasta $ProfundidadRepos niveles)
$RaicesRepos = @(
    'C:\SENYUM',
    'C:\Users\Toni.Salvado\OneDrive - SENYUM\Escritorio\Senyum\Clientes'
)
$ProfundidadRepos = 5
$ExcluirDirs = @('node_modules', 'bin', 'obj', '.vs', 'packages', '.git')   # además de base-conocimiento*
$RutasDocs   = @('CLAUDE.md', 'README.md', 'CHANGELOG*', 'docs', 'doc', 'tasks')

# Con parámetros de prueba nunca se toca estado.json
$SinEstado = [bool]($UltimaPasada -or $SoloInventario -or $SimularSalida)

[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding           = New-Object System.Text.UTF8Encoding($false)

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Log = Join-Path $LogDir ((Get-Date).ToString('yyyy-MM-dd_HHmm') + '.log')

function Write-Log([string]$Msg) {
    $line = '[{0}] {1}' -f (Get-Date).ToString('HH:mm:ss'), $Msg
    Add-Content -Path $Log -Value $line -Encoding UTF8
    Write-Host $line
}

function Send-Notice([string]$Title, [string]$Text) {
    if (-not $ForzarGlobo) {
        try {
            Import-Module BurntToast -ErrorAction Stop
            New-BurntToastNotification -Text $Title, $Text | Out-Null
            return
        } catch { }
    }
    try {   # alternativa sin dependencias: globo de la bandeja del sistema
        Add-Type -AssemblyName System.Windows.Forms, System.Drawing
        $n = New-Object System.Windows.Forms.NotifyIcon
        $n.Icon = [System.Drawing.SystemIcons]::Information
        $n.Visible = $true
        $n.ShowBalloonTip(10000, $Title, $Text, [System.Windows.Forms.ToolTipIcon]::Info)
        Start-Sleep -Seconds 10
        $n.Dispose()
    } catch { Write-Log "No se pudo mostrar la notificacion: $($_.Exception.Message)" }
}

function Invoke-Git([string]$Dir, [string[]]$GitArgs) {
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & git -C $Dir @GitArgs 2>&1 | ForEach-Object { $_.ToString() }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    [pscustomobject]@{ Code = $code; Out = ($out -join "`n") }
}

function Get-Iso([datetimeoffset]$d) { $d.ToString("yyyy-MM-dd'T'HH:mm:sszzz") }

function Find-Repos([string]$Dir, [int]$Nivel) {
    $subs = Get-ChildItem -LiteralPath $Dir -Directory -Force -ErrorAction SilentlyContinue
    foreach ($s in $subs) {
        if ($s.Name -like 'base-conocimiento*' -or $ExcluirDirs -contains $s.Name) { continue }
        if (Test-Path -LiteralPath (Join-Path $s.FullName '.git')) { $s.FullName; continue }   # repo: no se baja más
        if ($Nivel -lt $ProfundidadRepos) { Find-Repos $s.FullName ($Nivel + 1) }
    }
}

function Write-Estado($Inicio, $Propuesta) {
    $json = [ordered]@{ ultima_pasada = $Inicio; ultima_propuesta = $Propuesta } | ConvertTo-Json
    [IO.File]::WriteAllText($Estado, $json, (New-Object System.Text.UTF8Encoding($false)))
}

# --- Bloqueo: una sola ejecución a la vez -------------------------------------------------------------
try {
    $lock = [System.IO.File]::Open($LockFile, 'OpenOrCreate', 'ReadWrite', 'None')
} catch {
    Write-Log 'Ya hay una consolidacion en curso (bloqueo ocupado). Salgo.'
    exit 0
}

$exit = 0
try {
    $inicioDto = [datetimeoffset](Get-Date)
    $inicio = Get-Iso $inicioDto
    Write-Log "Inicio de la consolidacion ($inicio)"
    # Token de larga duracion: si el proceso no lo heredo (sesion abierta antes de crearlo), leerlo del entorno de usuario
    if (-not $env:CLAUDE_CODE_OAUTH_TOKEN) {
        $tok = [Environment]::GetEnvironmentVariable('CLAUDE_CODE_OAUTH_TOKEN', 'User')
        if ($tok) { $env:CLAUDE_CODE_OAUTH_TOKEN = $tok }
    }
    Write-Log ('token: ' + $(if ($env:CLAUDE_CODE_OAUTH_TOKEN) { 'si' } else { 'no' }))

    # --- ultima_pasada --------------------------------------------------------------------------------
    if ($UltimaPasada) { $ultima = [datetimeoffset]::Parse($UltimaPasada) }
    elseif (Test-Path $Estado) { $ultima = [datetimeoffset]::Parse((Get-Content -Raw -Encoding UTF8 $Estado | ConvertFrom-Json).ultima_pasada) }
    else { $ultima = $inicioDto.AddHours(-72) }
    $ultimaIso = Get-Iso $ultima
    Write-Log "ultima_pasada = $ultimaIso"

    # --- Carpeta de trabajo limpia --------------------------------------------------------------------
    if (Test-Path $Trabajo) { Remove-Item -LiteralPath $Trabajo -Recurse -Force }
    New-Item -ItemType Directory -Force -Path (Join-Path $Trabajo 'sesiones') | Out-Null

    # --- Inventario -----------------------------------------------------------------------------------
    # a) notas pendientes del inbox (todas, sin filtrar por fecha)
    $inbox = @(Get-ChildItem -Path (Join-Path $Main '_inbox') -Filter '*.md' -File -ErrorAction SilentlyContinue |
               Where-Object { $_.Name -ne 'README.md' } | ForEach-Object { $_.FullName })

    # b) sesiones de Claude Code modificadas tras ultima_pasada (sin las de la propia base)
    $sesiones = @(Get-ChildItem -Path (Join-Path $env:USERPROFILE '.claude\projects') -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notlike '*base-conocimiento*' } |
        ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Filter '*.jsonl' -File } |
        Where-Object { [datetimeoffset]$_.LastWriteTime -gt $ultima } |
        ForEach-Object { [ordered]@{ jsonl = $_.FullName; proyecto = $_.Directory.Name; modificado = (Get-Iso $_.LastWriteTime) } })

    # c) repos git con cambios de documentación
    $repos = @()
    foreach ($raiz in $RaicesRepos) {
        if (-not (Test-Path -LiteralPath $raiz)) { Write-Log "AVISO: raiz de repos inexistente: $raiz"; continue }
        foreach ($repo in @(Find-Repos $raiz 1)) {
            $r = Invoke-Git $repo (@('log', "--since=$ultimaIso", '--name-only', '--pretty=format:', '--') + $RutasDocs)
            if ($r.Code -ne 0) { Write-Log "AVISO: git log fallo en $repo"; continue }
            $ficheros = @($r.Out -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
            if ($ficheros.Count -gt 0) { $repos += [ordered]@{ raiz = $raiz; ruta = $repo; ficheros = $ficheros } }
        }
    }

    $inv = [ordered]@{
        inicio = $inicio; ultima_pasada = $ultimaIso
        inbox = $inbox; sesiones = $sesiones; repos = $repos
    }
    [IO.File]::WriteAllText($Inventario, ($inv | ConvertTo-Json -Depth 6), (New-Object System.Text.UTF8Encoding($false)))
    $resumen = "{0} notas de inbox, {1} sesiones de Claude Code, {2} repos con cambios de documentacion" -f $inbox.Count, $sesiones.Count, $repos.Count
    Write-Log "Inventario: $resumen"
    foreach ($raiz in $RaicesRepos) {
        $n = @($repos | Where-Object { $_.raiz -eq $raiz }).Count
        Write-Log ("  repos con cambios en {0}: {1}" -f $raiz, $n)
    }

    # --- Sin fuentes: terminar sin Claude --------------------------------------------------------------
    if ($inbox.Count + $sesiones.Count + $repos.Count -eq 0) {
        if (-not $SinEstado) { Write-Estado $inicio $null }
        Write-Log 'SIN NOVEDADES (sin fuentes)'
        return
    }

    # --- Sesiones a texto -----------------------------------------------------------------------------
    if ($sesiones.Count -gt 0) {
        $py = (Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1).Source
        if (-not $py) { $py = (Get-Command py -ErrorAction SilentlyContinue | Select-Object -First 1).Source }
        if (-not $py) { throw 'No se encuentra python para extraer las sesiones.' }
        $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        $pyOut = & $py -I $Extractor $Inventario (Join-Path $Trabajo 'sesiones') 2>&1 | ForEach-Object { $_.ToString() }
        $pyCode = $LASTEXITCODE
        $ErrorActionPreference = $prev
        Write-Log ("extraer_sesiones.py: " + ($pyOut -join ' '))
        if ($pyCode -ne 0) { throw "extraer_sesiones.py fallo (codigo $pyCode)" }
    }

    if ($SoloInventario) { Write-Log 'Modo SoloInventario: termino aqui.'; return }

    if ($SimularSalida) {
        $out = @($SimularSalida -split "`n")
        Write-Log 'Modo SimularSalida: no se lanza Claude.'
    }
    else {
        # --- Rama y worktree --------------------------------------------------------------------------
        $null = Invoke-Git $Main @('worktree', 'prune')
        $branchExists = (Invoke-Git $Main @('rev-parse', '--verify', '--quiet', "refs/heads/$Branch")).Code -eq 0
        if (-not (Test-Path (Join-Path $Worktree '.git'))) {
            $gitArgs = if ($branchExists) { @('worktree', 'add', $Worktree, $Branch) }
                       else               { @('worktree', 'add', '-b', $Branch, $Worktree, 'main') }
            $r = Invoke-Git $Main $gitArgs
            if ($r.Code -ne 0) { throw "No se pudo crear el worktree: $($r.Out)" }
            Write-Log "Worktree creado en $Worktree"
        }

        # --- Recoger lo aprobado/cambiado en main -----------------------------------------------------
        $r = Invoke-Git $Worktree @('merge', 'main', '--no-edit')
        Write-Log ("git merge main: " + $r.Out)
        if ($r.Code -ne 0) {
            $null = Invoke-Git $Worktree @('merge', '--abort')
            throw 'Conflicto al fusionar main en consolidacion; merge abortado. Claude no se ha ejecutado. Resolverlo a mano.'
        }

        # --- Claude Code sin interfaz -----------------------------------------------------------------
        $claude = (Get-Command claude -ErrorAction SilentlyContinue | Select-Object -First 1).Source
        if (-not $claude) { $claude = Join-Path $env:USERPROFILE '.local\bin\claude.exe' }
        if (-not (Test-Path $claude)) { throw 'No se encuentra claude en el PATH.' }

        $allowed = @(
            'Read', 'Glob', 'Grep', 'Edit', 'Write',
            'Bash(git *)', 'Bash(python *)', 'Bash(python3 *)', 'Bash(py *)',
            'Bash(cat *)', 'Bash(head *)', 'Bash(tail *)', 'Bash(ls *)', 'Bash(find *)', 'Bash(wc *)', 'Bash(grep *)'
        )
        $addDirs = @((Join-Path $env:USERPROFILE '.claude\projects'), 'C:\SENYUM', $Main) + $RaicesRepos
        $claudeArgs = @('-p', '--permission-mode', 'acceptEdits', '--no-session-persistence',
                        '--add-dir') + @($addDirs | Select-Object -Unique) + @('--allowedTools') + $allowed

        $cabecera = @"
## Datos de esta pasada

- Inicio de la pasada: $inicio
- ultima_pasada: $ultimaIso
- Inventario: $Inventario
- Sesiones ya extraidas a texto en: $(Join-Path $Trabajo 'sesiones')
- Resumen: $resumen
- El script gestiona estado.json: NO lo escribas ni calcules horas.

"@
        $promptText = $cabecera + (Get-Content -Raw -Encoding UTF8 $Prompt)
        Write-Log 'Lanzando Claude Code...'
        Push-Location $Worktree
        $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        try {
            $out = @($promptText | & $claude @claudeArgs 2>&1 | ForEach-Object { $_.ToString() })
            $claudeCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $prev
            Pop-Location
        }
        Add-Content -Path $Log -Value ($out -join "`r`n") -Encoding UTF8
        Write-Log "Claude termino con codigo $claudeCode"
        # Error de autenticacion (login caducado / token invalido): mensaje especifico
        if ($claudeCode -ne 0 -or -not ($out | Where-Object { $_ -match '^\s*(PROPUESTA:|SIN NOVEDADES|INCOMPLETA:)' })) {
            if (($out -join "`n") -match '(?i)(\b401\b|authentication[_ ]error|not logged in|please run /login|invalid (api key|bearer|token)|oauth token.{0,40}(expired|invalid|revoked)|token.{0,20}expired|invalid_grant)') {
                throw 'Claude Code: hay que renovar el login (ejecutar claude setup-token y actualizar CLAUDE_CODE_OAUTH_TOKEN).'
            }
        }
        if ($claudeCode -ne 0) { throw "Claude Code fallo (codigo $claudeCode). Ver el log." }

        # Salvaguarda: main no debe haber cambiado
        $dirty = Invoke-Git $Main @('status', '--porcelain', '--untracked-files=no')
        if ($dirty.Out.Trim()) { Write-Log ("AVISO: cambios en la carpeta principal (main):`n" + $dirty.Out) }
    }

    # --- Resultado: ULTIMA línea PROPUESTA: / SIN NOVEDADES / INCOMPLETA: ------------------------------
    $last = ($out | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^(PROPUESTA:|SIN NOVEDADES|INCOMPLETA:)' } | Select-Object -Last 1)
    if (-not $last) { throw 'La salida de Claude no termina con PROPUESTA:, SIN NOVEDADES ni INCOMPLETA:. Ver el log.' }
    Write-Log $last
    if ($last.StartsWith('INCOMPLETA:')) {
        throw ("Pasada incompleta: " + $last.Substring(11).Trim())
    }
    $propuesta = $null
    if ($last.StartsWith('PROPUESTA:')) {
        if ($last -match '^PROPUESTA:\s*(\S+)') { $propuesta = $Matches[1] }
        Send-Notice 'Base de conocimiento: propuesta pendiente' ($last -replace '^PROPUESTA:\s*', '')
        # Conservar las fuentes extraidas de esta pasada para que la revision pueda comprobarlas (se purgan a los 30 dias)
        try {
            $dest = Join-Path $Historico ((Get-Item -LiteralPath $Log).BaseName)   # yyyy-MM-dd_HHmm
            New-Item -ItemType Directory -Force -Path $dest | Out-Null
            Copy-Item -LiteralPath (Join-Path $Trabajo 'sesiones') -Destination $dest -Recurse -Force
            Copy-Item -LiteralPath $Inventario -Destination $dest -Force
            Write-Log "Fuentes conservadas en $dest"
        } catch { Write-Log "AVISO: no se pudo conservar el historico de fuentes: $($_.Exception.Message)" }
    }
    if (-not $SinEstado) { Write-Estado $inicio $propuesta; Write-Log "estado.json actualizado (ultima_pasada = $inicio)" }
}
catch {
    $exit = 1
    Write-Log "ERROR: $($_.Exception.Message)"
    Send-Notice 'Base de conocimiento: error en la consolidacion' $_.Exception.Message
}
finally {
    # Conservar solo los 30 ultimos logs
    Get-ChildItem $LogDir -Filter '*.log' | Sort-Object Name -Descending | Select-Object -Skip $KeepLogs |
        Remove-Item -Force -ErrorAction SilentlyContinue
    # Historico de fuentes: borrar solo carpetas con formato yyyy-MM-dd_HHmm de mas de 30 dias
    if (Test-Path -LiteralPath $Historico) {
        $limite = (Get-Date).Date.AddDays(-$KeepHistoricoDias)
        Get-ChildItem -LiteralPath $Historico -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}_\d{4}$' -and
                           [datetime]::ParseExact($_.Name.Substring(0, 10), 'yyyy-MM-dd', $null) -lt $limite } |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    $lock.Close(); $lock.Dispose()
}
exit $exit
