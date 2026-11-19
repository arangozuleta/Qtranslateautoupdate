# ============================================================================
#  Instalador del parche de QTranslate (endpoints de Google actualizados)
#  Se ejecuta con permisos de administrador desde INSTALAR.bat
# ============================================================================
$ErrorActionPreference = 'Stop'

function Escribir($texto, $color = 'Gray') { Write-Host $texto -ForegroundColor $color }

Escribir ""
Escribir "===============================================================" 'Cyan'
Escribir "  PARCHE QTRANSLATE - Reactivar el traductor de Google" 'Cyan'
Escribir "===============================================================" 'Cyan'
Escribir ""

# --- 1. Localizar el Service.js nuevo ---------------------------------------
$origen = Join-Path $PSScriptRoot 'Service.js'
if (-not (Test-Path $origen)) {
    Escribir "ERROR: no encuentro Service.js junto a este instalador." 'Red'
    Escribir "Copia la carpeta completa, no solo el .bat." 'Yellow'
    exit 1
}

# --- 2. Localizar la instalacion de QTranslate -------------------------------
$candidatas = New-Object System.Collections.Generic.List[string]
$candidatas.Add((Join-Path ${env:ProgramFiles(x86)} 'QTranslate'))
$candidatas.Add((Join-Path $env:ProgramFiles 'QTranslate'))
$candidatas.Add((Join-Path $env:LOCALAPPDATA 'QTranslate'))

$clavesDesinstalar = @(
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
    'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall'
)
foreach ($raiz in $clavesDesinstalar) {
    if (-not (Test-Path $raiz)) { continue }
    foreach ($item in (Get-ChildItem $raiz -ErrorAction SilentlyContinue)) {
        try { $p = Get-ItemProperty $item.PSPath -ErrorAction Stop } catch { continue }
        if ($p.DisplayName -like 'QTranslate*') {
            if ($p.InstallLocation) { $candidatas.Add($p.InstallLocation.TrimEnd('\')) }
            elseif ($p.UninstallString) {
                try { $candidatas.Add((Split-Path $p.UninstallString.Trim('"'))) } catch {}
            }
        }
    }
}

$instalacion = $null
foreach ($c in $candidatas) {
    if ([string]::IsNullOrWhiteSpace($c)) { continue }
    if (Test-Path (Join-Path $c 'Services\Google Translate\Service.js')) { $instalacion = $c; break }
}

if (-not $instalacion) {
    Escribir "ERROR: no encuentro QTranslate instalado en este equipo." 'Red'
    Escribir "Instala QTranslate primero y vuelve a ejecutar este parche." 'Yellow'
    exit 1
}
Escribir "QTranslate encontrado en:" 'Gray'
Escribir "  $instalacion" 'White'

$destino = Join-Path $instalacion 'Services\Google Translate\Service.js'

# --- 3. Cerrar QTranslate (carga los servicios solo al arrancar) -------------
$estabaAbierto = $false
$procesos = Get-Process -Name 'QTranslate' -ErrorAction SilentlyContinue
if ($procesos) {
    $estabaAbierto = $true
    Escribir ""
    Escribir "Cerrando QTranslate..." 'Gray'
    $procesos | Stop-Process -Force
    Start-Sleep -Milliseconds 1200
}

# --- 4. Copia de seguridad del archivo original ------------------------------
$respaldo = "$destino.original"
if (-not (Test-Path $respaldo)) {
    Copy-Item $destino $respaldo -Force
    Escribir ""
    Escribir "Copia de seguridad creada:" 'Gray'
    Escribir "  $respaldo" 'White'
} else {
    Escribir ""
    Escribir "La copia de seguridad ya existia (no se sobrescribe)." 'Gray'
}

# --- 5. Instalar el servicio nuevo (UTF-8 sin BOM para compatibilidad JScript)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$contenidoService = [System.IO.File]::ReadAllText($origen, $utf8NoBom)
[System.IO.File]::WriteAllText($destino, $contenidoService, $utf8NoBom)
Escribir ""
Escribir "Servicio de Google actualizado." 'Green'

# --- 6. Activar Google como servicio en uso ----------------------------------
$opciones = Join-Path $env:APPDATA 'QTranslate\Options.json'
if (Test-Path $opciones) {
    try {
        $texto = [System.IO.File]::ReadAllText($opciones)
        $nuevo = [System.Text.RegularExpressions.Regex]::Replace(
            $texto, '"ActiveServices"\s*:\s*\[[^\]]*\]', '"ActiveServices": [1]')
        if ($nuevo -ne $texto) {
            Copy-Item $opciones "$opciones.original" -Force -ErrorAction SilentlyContinue
            [System.IO.File]::WriteAllText($opciones, $nuevo, (New-Object System.Text.UTF8Encoding $true))
            Escribir "Servicio activo cambiado a Google." 'Green'
        } else {
            Escribir "Google ya estaba como servicio activo." 'Gray'
        }
    } catch {
        Escribir "Aviso: no pude ajustar el servicio activo automaticamente." 'Yellow'
        Escribir "Hazlo a mano: clic derecho en el icono de la bandeja > Google." 'Yellow'
    }
}

# --- 7. Volver a abrir QTranslate --------------------------------------------
$exe = Join-Path $instalacion 'QTranslate.exe'
if ((Test-Path $exe) -and $estabaAbierto) {
    Escribir ""
    Escribir "Reiniciando QTranslate..." 'Gray'
    Start-Process $exe
}

Escribir ""
Escribir "===============================================================" 'Green'
Escribir "  LISTO. El traductor deberia funcionar de nuevo." 'Green'
Escribir "===============================================================" 'Green'
Escribir ""
Escribir "Pruebalo: selecciona un texto en cualquier sitio y pulsa Ctrl+Q." 'White'
Escribir ""
Escribir "Para deshacer el cambio, renombra este archivo:" 'Gray'
Escribir "  $respaldo" 'Gray'
Escribir "quitandole el .original" 'Gray'
Escribir ""
