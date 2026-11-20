<#
.SYNOPSIS
  Pasada diaria de consolidación de la base de conocimiento (ver consolidacion/README.md).
.DESCRIPTION
  Asegura la rama `consolidacion` y su worktree, fusiona main en ella, lanza Claude Code sin interfaz con
  consolidacion\prompt-consolidador.md, guarda el log y avisa si hay propuesta o error.
  Códigos de salida: 0 bien (con o sin propuesta), 1 error.
#>
$ErrorActionPreference = 'Stop'

$Main     = 'C:\SENYUM\base-conocimiento'
$Worktree = 'C:\SENYUM\base-conocimiento-consolidacion'
$Branch   = 'consolidacion'
$Prompt   = Join-Path $Main 'consolidacion\prompt-consolidador.md'
$LogDir   = Join-Path $Main 'consolidacion\logs'
$LockFile = Join-Path $LogDir '.lock'
$KeepLogs = 30

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
    try {
        Import-Module BurntToast -ErrorAction Stop
        New-BurntToastNotification -Text $Title, $Text | Out-Null
        return
    } catch { }
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

# --- Bloqueo: una sola ejecución a la vez -------------------------------------------------------------
try {
    $lock = [System.IO.File]::Open($LockFile, 'OpenOrCreate', 'ReadWrite', 'None')
} catch {
    Write-Log 'Ya hay una consolidacion en curso (bloqueo ocupado). Salgo.'
    exit 0
}

$exit = 0
try {
    Write-Log 'Inicio de la consolidacion'

    # --- Rama y worktree ------------------------------------------------------------------------------
    $null = Invoke-Git $Main @('worktree', 'prune')
    $branchExists = (Invoke-Git $Main @('rev-parse', '--verify', '--quiet', "refs/heads/$Branch")).Code -eq 0
    if (-not (Test-Path (Join-Path $Worktree '.git'))) {
        $gitArgs = if ($branchExists) { @('worktree', 'add', $Worktree, $Branch) }
                   else               { @('worktree', 'add', '-b', $Branch, $Worktree, 'main') }
        $r = Invoke-Git $Main $gitArgs
        if ($r.Code -ne 0) { throw "No se pudo crear el worktree: $($r.Out)" }
        Write-Log "Worktree creado en $Worktree"
    }

    # --- Recoger lo aprobado/cambiado en main ---------------------------------------------------------
    $r = Invoke-Git $Worktree @('merge', 'main', '--no-edit')
    Write-Log ("git merge main: " + $r.Out)
    if ($r.Code -ne 0) {
        $null = Invoke-Git $Worktree @('merge', '--abort')
        throw 'Conflicto al fusionar main en consolidacion; merge abortado. Claude no se ha ejecutado. Resolverlo a mano.'
    }

    # --- Claude Code sin interfaz ---------------------------------------------------------------------
    $claude = (Get-Command claude -ErrorAction SilentlyContinue | Select-Object -First 1).Source
    if (-not $claude) { $claude = Join-Path $env:USERPROFILE '.local\bin\claude.exe' }
    if (-not (Test-Path $claude)) { throw 'No se encuentra claude en el PATH.' }

    $allowed = @(
        'Read', 'Glob', 'Grep', 'Edit', 'Write',
        'Bash(git *)', 'Bash(python *)', 'Bash(python3 *)', 'Bash(py *)',
        'Bash(cat *)', 'Bash(head *)', 'Bash(tail *)', 'Bash(ls *)', 'Bash(find *)', 'Bash(wc *)', 'Bash(grep *)'
    )
    $claudeArgs = @(
        '-p',
        '--permission-mode', 'acceptEdits',
        '--no-session-persistence',
        '--add-dir', (Join-Path $env:USERPROFILE '.claude\projects'), 'C:\SENYUM', $Main, $env:TEMP,
        '--allowedTools') + $allowed

    $promptText = Get-Content -Raw -Encoding UTF8 $Prompt
    Write-Log 'Lanzando Claude Code...'
    Push-Location $Worktree
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    try {
        $out = $promptText | & $claude @claudeArgs 2>&1 | ForEach-Object { $_.ToString() }
        $claudeCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prev
        Pop-Location
    }
    Add-Content -Path $Log -Value ($out -join "`r`n") -Encoding UTF8
    Write-Log "Claude termino con codigo $claudeCode"
    if ($claudeCode -ne 0) { throw "Claude Code fallo (codigo $claudeCode). Ver el log." }

    # --- Salvaguarda: main no debe haber cambiado -----------------------------------------------------
    $dirty = Invoke-Git $Main @('status', '--porcelain', '--untracked-files=no')
    if ($dirty.Out.Trim()) { Write-Log ("AVISO: cambios en la carpeta principal (main):`n" + $dirty.Out) }

    # --- Resultado ------------------------------------------------------------------------------------
    # Claude a veces añade un resumen tras la línea de resultado: vale la última línea PROPUESTA:/SIN NOVEDADES
    $last = ($out | Where-Object { $_.Trim() -match '^(PROPUESTA:|SIN NOVEDADES)' } | Select-Object -Last 1)
    if ($last -and $last.Trim().StartsWith('PROPUESTA:')) {
        Write-Log $last.Trim()
        Send-Notice 'Base de conocimiento: propuesta pendiente' ($last.Trim() -replace '^PROPUESTA:\s*', '')
    } else {
        Write-Log 'SIN NOVEDADES (o sin linea PROPUESTA)'
    }
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
    $lock.Close(); $lock.Dispose()
}
exit $exit
