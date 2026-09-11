# ============================================================
# DIAGNOSTICO O365 2806 - CITRIX SCA
# Windows Server 2019
# PowerShell 5.1
#
# EJECUTAR COMO ADMINISTRADOR
# PREGUNTA EL UPN DEL USUARIO CITRIX
# NO MODIFICA NADA
# ============================================================

Clear-Host

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   DIAGNOSTICO O365 2806 - CITRIX SCA" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# 1. PREGUNTAR USUARIO
# ------------------------------------------------------------

do {
    $UPN = Read-Host "Introduce el UPN del usuario (ejemplo usuario@dominio.com)"
}
while ([string]::IsNullOrWhiteSpace($UPN))

Write-Host ""
Write-Host "Usuario a comprobar: $UPN" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------
# 2. SERVIDOR
# ------------------------------------------------------------

Write-Host "[1] SERVIDOR" -ForegroundColor Yellow

$OS = Get-CimInstance Win32_OperatingSystem

[PSCustomObject]@{
    Servidor = $env:COMPUTERNAME
    Sistema  = $OS.Caption
    Version  = $OS.Version
} | Format-List

# ------------------------------------------------------------
# 3. OFFICE
# ------------------------------------------------------------

Write-Host "[2] OFFICE / CLICK-TO-RUN" -ForegroundColor Yellow

$RegPath = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"

if (-not (Test-Path $RegPath)) {
    Write-Host "ERROR: No existe la configuración Click-To-Run." -ForegroundColor Red
    exit
}

$Cfg = Get-ItemProperty $RegPath

[PSCustomObject]@{
    Version           = $Cfg.VersionToReport
    ClientVersion     = $Cfg.ClientVersionToReport
    Producto          = $Cfg.ProductReleaseIds
    Plataforma        = $Cfg.Platform
    Canal             = $Cfg.UpdateChannel
    SharedComputer    = $Cfg.SharedComputerLicensing
    SCLCacheOverride  = $Cfg.SCLCacheOverride
    SCLCacheDirectory = $Cfg.SCLCacheOverrideDirectory
} | Format-List

# ------------------------------------------------------------
# 4. COMPROBAR SCA
# ------------------------------------------------------------

Write-Host "[3] SHARED COMPUTER ACTIVATION" -ForegroundColor Yellow

if ($Cfg.SharedComputerLicensing -eq 1) {
    Write-Host "SCA = ACTIVADO" -ForegroundColor Green
}
else {
    Write-Host "SCA = NO ACTIVADO" -ForegroundColor Red
}

Write-Host ""

# ------------------------------------------------------------
# 5. BUSCAR EL PERFIL DEL USUARIO
#
# Se busca el UPN dentro de:
# - OneAuth
# - IdentityCache
# - Office Identity
# - Licensing
#
# El script se ejecuta como ADMINISTRADOR, por eso no utiliza
# el perfil del usuario que ejecuta PowerShell.
# ------------------------------------------------------------

Write-Host "[4] BUSCANDO PERFIL DEL USUARIO" -ForegroundColor Yellow

$Profiles = Get-ChildItem "C:\Users" -Directory -Force `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -notin @(
            "Public",
            "Default",
            "Default User",
            "All Users"
        )
    }

$UserProfiles = @()

foreach ($Profile in $Profiles) {

    $Base = $Profile.FullName

    $Paths = @(
        "$Base\AppData\Local\Microsoft\Office\16.0\Licensing",
        "$Base\AppData\Local\Microsoft\Office\16.0\Identity",
        "$Base\AppData\Local\Microsoft\OneAuth",
        "$Base\AppData\Local\Microsoft\IdentityCache"
    )

    $UPNFound = $false

    foreach ($Path in $Paths) {

        if (Test-Path $Path) {

            try {

                $Match = Get-ChildItem $Path -Recurse -Force -File `
                    -ErrorAction SilentlyContinue |
                    Select-String -Pattern $UPN `
                    -SimpleMatch `
                    -ErrorAction SilentlyContinue |
                    Select-Object -First 1

                if ($Match) {
                    $UPNFound = $true
                    break
                }

            }
            catch {}
        }
    }

    if ($UPNFound) {

        $UserProfiles += $Base
    }
}

if ($UserProfiles.Count -eq 0) {

    Write-Host ""
    Write-Host "NO SE HA ENCONTRADO EL UPN EN LOS PERFILES LOCALES." `
        -ForegroundColor Red

    Write-Host ""
    Write-Host "Perfiles existentes en el servidor:" `
        -ForegroundColor Yellow

    $Profiles |
        Select-Object Name,FullName |
        Format-Table -AutoSize

}
else {

    Write-Host ""
    Write-Host "PERFIL ENCONTRADO:" -ForegroundColor Green

    $UserProfiles |
        ForEach-Object {
            Write-Host $_ -ForegroundColor Green
        }
}

# ------------------------------------------------------------
# 6. COMPROBAR LICENSING DEL PERFIL
# ------------------------------------------------------------

Write-Host ""
Write-Host "[5] TOKEN DE LICENCIA" -ForegroundColor Yellow

$TotalTokens = 0

foreach ($ProfilePath in $UserProfiles) {

    $LicensingPath = `
        "$ProfilePath\AppData\Local\Microsoft\Office\16.0\Licensing"

    Write-Host ""
    Write-Host "Perfil: $ProfilePath"
    Write-Host "Licensing: $LicensingPath"

    if (Test-Path $LicensingPath) {

        $Files = Get-ChildItem $LicensingPath -Force `
            -ErrorAction SilentlyContinue

        if ($Files) {

            Write-Host "ARCHIVOS ENCONTRADOS:" -ForegroundColor Green

            $Files |
                Select-Object Name,Length,CreationTime,LastWriteTime |
                Format-Table -AutoSize

            $TotalTokens += $Files.Count

        }
        else {

            Write-Host "CARPETA EXISTE PERO ESTA VACIA." `
                -ForegroundColor Red
        }

    }
    else {

        Write-Host "LA CARPETA LICENSING NO EXISTE." `
            -ForegroundColor Red
    }
}

# ------------------------------------------------------------
# 7. IDENTITY / ONEAUTH
# ------------------------------------------------------------

Write-Host ""
Write-Host "[6] IDENTITY / ONEAUTH" -ForegroundColor Yellow

foreach ($ProfilePath in $UserProfiles) {

    Write-Host ""
    Write-Host "Perfil: $ProfilePath" -ForegroundColor Cyan

    $IdentityPaths = @(
        "$ProfilePath\AppData\Local\Microsoft\Office\16.0\Identity",
        "$ProfilePath\AppData\Local\Microsoft\OneAuth",
        "$ProfilePath\AppData\Local\Microsoft\IdentityCache"
    )

    foreach ($Path in $IdentityPaths) {

        if (Test-Path $Path) {

            $Count = @(Get-ChildItem $Path -Recurse -Force -File `
                -ErrorAction SilentlyContinue).Count

            [PSCustomObject]@{
                Ruta     = $Path
                Existe   = "SI"
                Archivos = $Count
            }

        }
        else {

            [PSCustomObject]@{
                Ruta     = $Path
                Existe   = "NO"
                Archivos = 0
            }
        }
    }
} | Format-Table -AutoSize

# ------------------------------------------------------------
# 8. SERVICIO CLICK-TO-RUN
# ------------------------------------------------------------

Write-Host ""
Write-Host "[7] CLICK-TO-RUN" -ForegroundColor Yellow

$Service = Get-Service ClickToRunSvc `
    -ErrorAction SilentlyContinue

if ($Service) {

    $Service |
        Select-Object Name,Status,StartType |
        Format-Table -AutoSize

}
else {

    Write-Host "ClickToRunSvc NO ENCONTRADO." -ForegroundColor Red
}

# ------------------------------------------------------------
# 9. REGISTRO SCA
# ------------------------------------------------------------

Write-Host ""
Write-Host "[8] REGISTRO SCA" -ForegroundColor Yellow

$SCAKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun\Configuration"
)

foreach ($Key in $SCAKeys) {

    if (Test-Path $Key) {

        Write-Host ""
        Write-Host $Key -ForegroundColor Cyan

        Get-ItemProperty $Key `
            -ErrorAction SilentlyContinue |
            Select-Object `
                SharedComputerLicensing,
                SCLCacheOverride,
                SCLCacheOverrideDirectory,
                DeviceBasedLicensing |
            Format-List
    }
}

# ------------------------------------------------------------
# 10. RESULTADO
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================================" `
    -ForegroundColor Cyan
Write-Host " RESULTADO" -ForegroundColor Cyan
Write-Host "============================================================" `
    -ForegroundColor Cyan

$SCA = if ($Cfg.SharedComputerLicensing -eq 1) {
    "OK"
}
else {
    "ERROR"
}

$Perfil = if ($UserProfiles.Count -gt 0) {
    "ENCONTRADO"
}
else {
    "NO ENCONTRADO"
}

$Token = if ($TotalTokens -gt 0) {
    "ENCONTRADO"
}
else {
    "NO ENCONTRADO"
}

[PSCustomObject]@{
    Servidor       = $env:COMPUTERNAME
    Usuario        = $UPN
    Office         = $Cfg.VersionToReport
    SCA            = $SCA
    Perfil         = $Perfil
    Tokens         = $TotalTokens
    EstadoToken    = $Token
    ClickToRun     = if ($Service) {
                         $Service.Status
                     }
                     else {
                         "NO ENCONTRADO"
                     }
} | Format-List

Write-Host ""
Write-Host "============================================================" `
    -ForegroundColor Cyan