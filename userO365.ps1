# ============================================================
# DIAGNOSTICO OFFICE 365 - SCA / WAM
# PowerShell 5.1
# Ejecutar como Administrador
# ============================================================

Clear-Host

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "       DIAGNOSTICO OFFICE 365 - SCA / WAM" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# ------------------------------------------------------------
# USUARIO AFECTADO
# ------------------------------------------------------------

$Cuenta = Read-Host "`nIntroduce el usuario afectado (DOM\usuario)"

if ([string]::IsNullOrWhiteSpace($Cuenta)) {
    Write-Host "No se ha indicado usuario." -ForegroundColor Red
    exit
}

$Cuenta = $Cuenta.Trim()

if ($Cuenta -notmatch "\\") {
    Write-Host "Formato incorrecto. Debe ser DOM\usuario" -ForegroundColor Red
    exit
}

$Usuario = ($Cuenta -split "\\",2)[1]

Write-Host "Cuenta analizada : $Cuenta" -ForegroundColor Cyan
Write-Host "Usuario          : $Usuario" -ForegroundColor Cyan

# ------------------------------------------------------------
# PERFIL
# ------------------------------------------------------------

Write-Host "`n[1] PERFIL DEL USUARIO" -ForegroundColor Yellow

$Perfil = Get-CimInstance Win32_UserProfile |
    Where-Object {
        $_.LocalPath -ieq "C:\Users\$Usuario"
    }

if ($Perfil) {
    $UserProfilePath = $Perfil.LocalPath

    Write-Host "Perfil encontrado : $UserProfilePath" -ForegroundColor Green
    Write-Host "Perfil cargado    : $($Perfil.Loaded)"
    Write-Host "SID               : $($Perfil.SID)"
}
else {
    Write-Host "ERROR: No existe el perfil C:\Users\$Usuario" -ForegroundColor Red
    exit
}

# ------------------------------------------------------------
# OFFICE - SCA
# ------------------------------------------------------------

Write-Host "`n[2] CONFIGURACION OFFICE / SCA" -ForegroundColor Yellow

$OfficeReg = Get-ItemProperty `
    "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration" `
    -ErrorAction SilentlyContinue

if ($OfficeReg) {

    [PSCustomObject]@{
        SharedComputerLicensing   = $OfficeReg.SharedComputerLicensing
        SCLCacheOverride          = $OfficeReg.SCLCacheOverride
        SCLCacheOverrideDirectory = $OfficeReg.SCLCacheOverrideDirectory
        VersionToReport           = $OfficeReg.VersionToReport
        UpdateChannel              = $OfficeReg.UpdateChannel
    }

}
else {
    Write-Host "ERROR: No existe configuración ClickToRun" -ForegroundColor Red
}

# ------------------------------------------------------------
# WAM EQUIPO
# ------------------------------------------------------------

Write-Host "`n[3] WAM - Microsoft.AAD.BrokerPlugin" -ForegroundColor Yellow

$Wam = Get-AppxPackage -AllUsers Microsoft.AAD.BrokerPlugin `
    -ErrorAction SilentlyContinue

if ($Wam) {

    $Wam |
        Select-Object Name,Version,PackageFullName,InstallLocation,Status

}
else {
    Write-Host "ERROR: Microsoft.AAD.BrokerPlugin NO encontrado" -ForegroundColor Red
}

# ------------------------------------------------------------
# SERVICIOS
# ------------------------------------------------------------

Write-Host "`n[4] SERVICIOS" -ForegroundColor Yellow

Get-Service TokenBroker,wlidsvc -ErrorAction SilentlyContinue |
    Select-Object Name,Status,StartType

# ------------------------------------------------------------
# WAM DEL USUARIO AFECTADO
# ------------------------------------------------------------

Write-Host "`n[5] WAM DEL USUARIO AFECTADO" -ForegroundColor Yellow

$WamUserPath = "$UserProfilePath\AppData\Local\Packages\Microsoft.AAD.BrokerPlugin_cw5n1h2txyewy"

if (Test-Path $WamUserPath) {

    Write-Host "PERFIL WAM EXISTE" -ForegroundColor Green

    Get-ChildItem $WamUserPath -Force -ErrorAction SilentlyContinue |
        Select-Object Name,LastWriteTime

}
else {
    Write-Host "PERFIL WAM NO EXISTE" -ForegroundColor Red
}

# ------------------------------------------------------------
# LICENSING OFFICE
# ------------------------------------------------------------

Write-Host "`n[6] LICENSING OFFICE DEL USUARIO" -ForegroundColor Yellow

$LocalLicensing = "$UserProfilePath\AppData\Local\Microsoft\Office\16.0\Licensing"

Write-Host "Ruta: $LocalLicensing"

if (Test-Path $LocalLicensing) {

    $LicFiles = Get-ChildItem $LocalLicensing -Force `
        -ErrorAction SilentlyContinue

    if ($LicFiles) {

        Write-Host "CONTENIDO:" -ForegroundColor Green

        $LicFiles |
            Select-Object Name,Length,LastWriteTime

    }
    else {
        Write-Host "CARPETA EXISTE PERO ESTA VACIA" -ForegroundColor Red
    }

}
else {
    Write-Host "CARPETA NO EXISTE" -ForegroundColor Red
}

# ------------------------------------------------------------
# CACHE SCA EN RED
# ------------------------------------------------------------

Write-Host "`n[7] CACHE SCA EN RED" -ForegroundColor Yellow

$SCLDirectory = $OfficeReg.SCLCacheOverrideDirectory

if ($SCLDirectory) {

    $SCLUserPath = $SCLDirectory -replace "%username%",$Usuario

    Write-Host "Ruta configurada:"
    Write-Host $SCLUserPath

    if (Test-Path $SCLUserPath) {

        Write-Host "RUTA ACCESIBLE" -ForegroundColor Green

        $NetworkFiles = Get-ChildItem $SCLUserPath -Force `
            -ErrorAction SilentlyContinue

        if ($NetworkFiles) {

            $NetworkFiles |
                Select-Object Name,Length,LastWriteTime

        }
        else {
            Write-Host "CARPETA VACIA" -ForegroundColor Red
        }

    }
    else {
        Write-Host "RUTA NO ACCESIBLE" -ForegroundColor Red
    }

}
else {
    Write-Host "SCLCacheOverrideDirectory NO CONFIGURADO" -ForegroundColor Red
}

# ------------------------------------------------------------
# EVENTOS AAD
# ------------------------------------------------------------

Write-Host "`n[8] ULTIMOS EVENTOS AAD / WAM" -ForegroundColor Yellow

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

if ($OfficeReg.SharedComputerLicensing -eq 1) {
    Write-Host "SCA                  : OK" -ForegroundColor Green
}
else {
    Write-Host "SCA                  : ERROR" -ForegroundColor Red
}

if ($Wam -and $Wam.Status -eq "Ok") {
    Write-Host "WAM EQUIPO           : OK" -ForegroundColor Green
}
else {
    Write-Host "WAM EQUIPO           : ERROR" -ForegroundColor Red
}

if (Test-Path $WamUserPath) {
    Write-Host "WAM USUARIO          : EXISTE" -ForegroundColor Green
}
else {
    Write-Host "WAM USUARIO          : NO EXISTE" -ForegroundColor Red
}

if (Test-Path $LocalLicensing) {

    if (Get-ChildItem $LocalLicensing -Force -ErrorAction SilentlyContinue) {
        Write-Host "LICENSING LOCAL      : CON CONTENIDO" -ForegroundColor Green
    }
    else {
        Write-Host "LICENSING LOCAL      : VACIO" -ForegroundColor Red
    }

}
else {
    Write-Host "LICENSING LOCAL      : NO EXISTE" -ForegroundColor Red
}

if ($SCLUserPath -and (Test-Path $SCLUserPath)) {
    Write-Host "CACHE SCA RED        : ACCESIBLE" -ForegroundColor Green
}
else {
    Write-Host "CACHE SCA RED        : NO ACCESIBLE" -ForegroundColor Red
}

Write-Host "============================================================"
Write-Host "FIN"
Write-Host "============================================================"