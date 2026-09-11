# ============================================================
# DIAGNOSTICO OFFICE 365 - SCA / WAM
# PowerShell 5.1
# Ejecutar como Administrador
#
# IMPORTANTE:
# - Pide DOM\usuario
# - TODAS las comprobaciones del usuario usan esa cuenta
# - NO utiliza el usuario administrador/logado
# - NO modifica nada
# ============================================================

Clear-Host

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "       DIAGNOSTICO OFFICE 365 - SCA / WAM" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ------------------------------------------------------------
# USUARIO AFECTADO
# ------------------------------------------------------------

$Cuenta = Read-Host "`nIntroduce el usuario afectado (DOM\usuario)"

if ([string]::IsNullOrWhiteSpace($Cuenta) -or $Cuenta -notmatch "\\") {
    Write-Host "Formato incorrecto. Debe ser DOM\usuario" -ForegroundColor Red
    exit
}

$Dominio  = ($Cuenta -split "\\",2)[0]
$Usuario  = ($Cuenta -split "\\",2)[1]

Write-Host "`nCuenta analizada : $Cuenta" -ForegroundColor Cyan
Write-Host "Usuario          : $Usuario" -ForegroundColor Cyan

# ------------------------------------------------------------
# OBTENER SID DE LA CUENTA INTRODUCIDA
# ------------------------------------------------------------

Write-Host "`n[1] IDENTIDAD DEL USUARIO" -ForegroundColor Yellow

try {
    $NTAccount = New-Object System.Security.Principal.NTAccount($Dominio,$Usuario)
    $SID = $NTAccount.Translate(
        [System.Security.Principal.SecurityIdentifier]
    ).Value

    Write-Host "SID: $SID" -ForegroundColor Green
}
catch {
    Write-Host "ERROR obteniendo SID de $Cuenta" -ForegroundColor Red
    Write-Host $_.Exception.Message
    exit
}

# ------------------------------------------------------------
# PERFIL DEL USUARIO INTRODUCIDO
# ------------------------------------------------------------

Write-Host "`n[2] PERFIL DEL USUARIO" -ForegroundColor Yellow

$Perfil = Get-CimInstance Win32_UserProfile -ErrorAction SilentlyContinue |
    Where-Object {
        $_.SID -eq $SID
    }

if (!$Perfil) {
    Write-Host "NO EXISTE PERFIL LOCAL PARA $Cuenta" -ForegroundColor Red
    exit
}

$PerfilPath = $Perfil.LocalPath

Write-Host "Perfil : $PerfilPath" -ForegroundColor Green
Write-Host "SID    : $($Perfil.SID)"
Write-Host "Loaded : $($Perfil.Loaded)"

# ------------------------------------------------------------
# CONFIGURACION OFFICE SCA - EQUIPO
# ------------------------------------------------------------

Write-Host "`n[3] CONFIGURACION OFFICE / SCA" -ForegroundColor Yellow

$Office = Get-ItemProperty `
    "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" `
    -ErrorAction SilentlyContinue

if (!$Office) {
    Write-Host "ERROR: no existe configuracion ClickToRun" -ForegroundColor Red
}
else {

    Write-Host "SharedComputerLicensing   : $($Office.SharedComputerLicensing)"
    Write-Host "SCLCacheOverride          : $($Office.SCLCacheOverride)"
    Write-Host "SCLCacheOverrideDirectory : $($Office.SCLCacheOverrideDirectory)"
    Write-Host "VersionToReport           : $($Office.VersionToReport)"
    Write-Host "UpdateChannel             : $($Office.UpdateChannel)"
}

# ------------------------------------------------------------
# WAM - EQUIPO
# ------------------------------------------------------------

Write-Host "`n[4] WAM - EQUIPO" -ForegroundColor Yellow

$Wam = Get-AppxPackage -AllUsers Microsoft.AAD.BrokerPlugin `
    -ErrorAction SilentlyContinue

if ($Wam) {

    $Wam |
        Select-Object Name,Version,PackageFullName,InstallLocation,Status

}
else {
    Write-Host "ERROR: Microsoft.AAD.BrokerPlugin no encontrado" `
        -ForegroundColor Red
}

# ------------------------------------------------------------
# WAM - USUARIO INTRODUCIDO
# ------------------------------------------------------------

Write-Host "`n[5] WAM - $Cuenta" -ForegroundColor Yellow

$WamUserPath = Join-Path `
    $PerfilPath `
    "AppData\Local\Packages\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy"

Write-Host "Ruta:"
Write-Host $WamUserPath

if (Test-Path $WamUserPath) {

    Write-Host "WAM DEL USUARIO: EXISTE" -ForegroundColor Green

    Get-ChildItem $WamUserPath -Force `
        -ErrorAction SilentlyContinue |
        Select-Object Name,LastWriteTime

}
else {

    Write-Host "WAM DEL USUARIO: NO EXISTE" -ForegroundColor Red

}

# ------------------------------------------------------------
# LICENSING OFFICE - USUARIO INTRODUCIDO
# ------------------------------------------------------------

Write-Host "`n[6] LICENSING OFFICE - $Cuenta" -ForegroundColor Yellow

$LicensingPath = Join-Path `
    $PerfilPath `
    "AppData\Local\Microsoft\Office\16.0\Licensing"

Write-Host "Ruta:"
Write-Host $LicensingPath

if (Test-Path $LicensingPath) {

    $LicensingFiles = Get-ChildItem $LicensingPath -Force `
        -ErrorAction SilentlyContinue

    if ($LicensingFiles) {

        Write-Host "LICENSING: EXISTE Y TIENE CONTENIDO" `
            -ForegroundColor Green

        $LicensingFiles |
            Select-Object Name,Length,LastWriteTime

    }
    else {

        Write-Host "LICENSING: EXISTE PERO ESTA VACIO" `
            -ForegroundColor Red

    }

}
else {

    Write-Host "LICENSING: NO EXISTE" -ForegroundColor Red

}

# ------------------------------------------------------------
# CACHE SCA - USUARIO INTRODUCIDO
# ------------------------------------------------------------

Write-Host "`n[7] CACHE SCA - $Cuenta" -ForegroundColor Yellow

$SCLBase = $Office.SCLCacheOverrideDirectory

if ([string]::IsNullOrWhiteSpace($SCLBase)) {

    Write-Host "SCLCacheOverrideDirectory NO CONFIGURADO" `
        -ForegroundColor Red

}
else {

    # SOLO se utiliza el usuario introducido arriba
    $SCLUserPath = $SCLBase -replace "%username%",$Usuario

    Write-Host "Ruta configurada:"
    Write-Host $SCLUserPath

    if (Test-Path $SCLUserPath) {

        Write-Host "CARPETA EXISTE / ACCESIBLE" `
            -ForegroundColor Green

        $NetworkFiles = Get-ChildItem $SCLUserPath -Force `
            -ErrorAction SilentlyContinue

        if ($NetworkFiles) {

            $NetworkFiles |
                Select-Object Name,Length,LastWriteTime

        }
        else {

            Write-Host "CARPETA VACIA"

        }

    }
    else {

        Write-Host "CARPETA NO EXISTE / NO ACCESIBLE" `
            -ForegroundColor Red

    }
}

# ------------------------------------------------------------
# TOKENBROKER / WLIDSVC
# ------------------------------------------------------------

Write-Host "`n[8] SERVICIOS" -ForegroundColor Yellow

Get-Service TokenBroker,wlidsvc `
    -ErrorAction SilentlyContinue |
    Select-Object Name,Status,StartType

# ------------------------------------------------------------
# EVENTOS AAD
# ------------------------------------------------------------

Write-Host "`n[9] EVENTOS AAD / WAM" -ForegroundColor Yellow

$Events = Get-WinEvent `
    -LogName "Microsoft-Windows-AAD/Operational" `
    -MaxEvents 30 `
    -ErrorAction SilentlyContinue

if ($Events) {

    $Events |
        Select-Object TimeCreated,Id,LevelDisplayName,Message |
        Format-List

}
else {

    Write-Host "No hay eventos disponibles."

}

# ------------------------------------------------------------
# RESUMEN
# ------------------------------------------------------------

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host "                         RESUMEN" -ForegroundColor Cyan
Write-Host "============================================================"

Write-Host "Cuenta analizada : $Cuenta"
Write-Host "Perfil           : $PerfilPath"
Write-Host "SID              : $SID"

if ($Office.SharedComputerLicensing -eq 1) {
    Write-Host "SCA              : OK" -ForegroundColor Green
}
else {
    Write-Host "SCA              : ERROR" -ForegroundColor Red
}

if ($Wam -and $Wam.Status -eq "Ok") {
    Write-Host "WAM equipo       : OK" -ForegroundColor Green
}
else {
    Write-Host "WAM equipo       : ERROR" -ForegroundColor Red
}

if (Test-Path $WamUserPath) {
    Write-Host "WAM usuario      : EXISTE" -ForegroundColor Green
}
else {
    Write-Host "WAM usuario      : NO EXISTE" -ForegroundColor Red
}

if (Test-Path $LicensingPath) {
    Write-Host "Licensing        : EXISTE" -ForegroundColor Green
}
else {
    Write-Host "Licensing        : NO EXISTE" -ForegroundColor Red
}

if ($SCLUserPath -and (Test-Path $SCLUserPath)) {
    Write-Host "Cache SCA         : EXISTE / ACCESIBLE" `
        -ForegroundColor Green
}
else {
    Write-Host "Cache SCA         : NO EXISTE / NO ACCESIBLE" `
        -ForegroundColor Red
}

Write-Host "============================================================"
Write-Host "FIN"
Write-Host "============================================================"