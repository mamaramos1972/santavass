# ============================================================
# O365 2806 - DIAGNOSTICO LICENCIA SCA
# Windows Server 2019 / Citrix
# PowerShell 5.1
#
# EJECUTAR COMO ADMINISTRADOR
# PREGUNTA EL UPN DEL USUARIO
# NO MODIFICA NADA
# ============================================================

Clear-Host

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " O365 2806 - COMPROBACION LICENCIA USUARIO CITRIX" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# PEDIR UPN
# ------------------------------------------------------------

do {
    $UPN = Read-Host "Introduce el UPN del usuario"
}
while ([string]::IsNullOrWhiteSpace($UPN))

$UPN = $UPN.Trim()

Write-Host ""
Write-Host "Usuario: $UPN" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------
# OBTENER DOMINIO Y USUARIO DESDE EL UPN
# ------------------------------------------------------------

$Parts = $UPN.Split("@")

if ($Parts.Count -ne 2) {
    Write-Host "ERROR: El UPN debe tener formato usuario@dominio.com" -ForegroundColor Red
    exit
}

$UserName = $Parts[0]
$Domain   = $Parts[1]

# ------------------------------------------------------------
# OBTENER SID DEL USUARIO
# ------------------------------------------------------------

Write-Host "[1] OBTENIENDO SID DEL USUARIO" -ForegroundColor Yellow

try {

    $Account = New-Object System.Security.Principal.NTAccount(
        $Domain,
        $UserName
    )

    $SID = $Account.Translate(
        [System.Security.Principal.SecurityIdentifier]
    ).Value

    Write-Host "SID: $SID" -ForegroundColor Green
}
catch {

    Write-Host "ERROR: No se puede resolver $UPN a un SID." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit
}

# ------------------------------------------------------------
# BUSCAR PERFIL MEDIANTE SID
# ------------------------------------------------------------

Write-Host ""
Write-Host "[2] BUSCANDO PERFIL WINDOWS DEL USUARIO" -ForegroundColor Yellow

$ProfileKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID"

if (-not (Test-Path $ProfileKey)) {

    Write-Host "NO EXISTE PERFIL LOCAL PARA ESTE USUARIO." -ForegroundColor Red
    Write-Host ""
    Write-Host "El usuario debe haber iniciado sesión previamente en este servidor." -ForegroundColor Yellow
    exit
}

$Profile = Get-ItemProperty $ProfileKey

$ProfilePath = $Profile.ProfileImagePath

Write-Host "Perfil: $ProfilePath" -ForegroundColor Green

# ------------------------------------------------------------
# RUTAS OFFICE DEL USUARIO
# ------------------------------------------------------------

$LicensingPath = Join-Path `
    $ProfilePath `
    "AppData\Local\Microsoft\Office\16.0\Licensing"

$IdentityPath = Join-Path `
    $ProfilePath `
    "AppData\Local\Microsoft\Office\16.0\Identity"

$OneAuthPath = Join-Path `
    $ProfilePath `
    "AppData\Local\Microsoft\OneAuth"

$IdentityCachePath = Join-Path `
    $ProfilePath `
    "AppData\Local\Microsoft\IdentityCache"

# ------------------------------------------------------------
# OFFICE INSTALADO
# ------------------------------------------------------------

Write-Host ""
Write-Host "[3] OFFICE INSTALADO" -ForegroundColor Yellow

$OfficeReg = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"

if (Test-Path $OfficeReg) {

    $Office = Get-ItemProperty $OfficeReg

    [PSCustomObject]@{
        Version            = $Office.VersionToReport
        ClientVersion      = $Office.ClientVersionToReport
        Producto           = $Office.ProductReleaseIds
        Canal              = $Office.UpdateChannel
        Plataforma         = $Office.Platform
        SharedComputer     = $Office.SharedComputerLicensing
        SCLCacheOverride   = $Office.SCLCacheOverride
        SCLCacheDirectory  = $Office.SCLCacheOverrideDirectory
    } | Format-List

}
else {

    Write-Host "NO SE ENCUENTRA OFFICE CLICK-TO-RUN." -ForegroundColor Red
    exit
}

# ------------------------------------------------------------
# SCA
# ------------------------------------------------------------

Write-Host "[4] SHARED COMPUTER ACTIVATION" -ForegroundColor Yellow

if ($Office.SharedComputerLicensing -eq 1) {

    Write-Host "SCA = ACTIVADO" -ForegroundColor Green

}
else {

    Write-Host "SCA = NO ACTIVADO" -ForegroundColor Red
}

# ------------------------------------------------------------
# LICENSING
# ------------------------------------------------------------

Write-Host ""
Write-Host "[5] LICENSING DEL USUARIO" -ForegroundColor Yellow
Write-Host $LicensingPath
Write-Host ""

if (Test-Path $LicensingPath) {

    $LicenseFiles = Get-ChildItem `
        $LicensingPath `
        -Force `
        -File `
        -ErrorAction SilentlyContinue

    if ($LicenseFiles.Count -gt 0) {

        Write-Host "ARCHIVOS ENCONTRADOS:" -ForegroundColor Green

        $LicenseFiles |
            Select-Object `
                Name,
                Length,
                CreationTime,
                LastWriteTime |
            Format-Table -AutoSize

    }
    else {

        Write-Host "LA CARPETA EXISTE PERO ESTA VACIA." -ForegroundColor Red
    }

}
else {

    Write-Host "NO EXISTE LA CARPETA LICENSING." -ForegroundColor Red
}

# ------------------------------------------------------------
# IDENTITY
# ------------------------------------------------------------

Write-Host ""
Write-Host "[6] OFFICE IDENTITY" -ForegroundColor Yellow

if (Test-Path $IdentityPath) {

    $IdentityFiles = Get-ChildItem `
        $IdentityPath `
        -Recurse `
        -Force `
        -File `
        -ErrorAction SilentlyContinue

    Write-Host "Carpeta existente: SI" -ForegroundColor Green
    Write-Host "Archivos: $($IdentityFiles.Count)"

}
else {

    Write-Host "NO EXISTE IDENTITY." -ForegroundColor Red
}

# ------------------------------------------------------------
# ONEAUTH
# ------------------------------------------------------------

Write-Host ""
Write-Host "[7] ONEAUTH" -ForegroundColor Yellow

if (Test-Path $OneAuthPath) {

    $OneAuthFiles = Get-ChildItem `
        $OneAuthPath `
        -Recurse `
        -Force `
        -File `
        -ErrorAction SilentlyContinue

    Write-Host "Carpeta existente: SI" -ForegroundColor Green
    Write-Host "Archivos: $($OneAuthFiles.Count)"

}
else {

    Write-Host "NO EXISTE ONEAUTH." -ForegroundColor Red
}

# ------------------------------------------------------------
# IDENTITY CACHE
# ------------------------------------------------------------

Write-Host ""
Write-Host "[8] IDENTITY CACHE" -ForegroundColor Yellow

if (Test-Path $IdentityCachePath) {

    $CacheFiles = Get-ChildItem `
        $IdentityCachePath `
        -Recurse `
        -Force `
        -File `
        -ErrorAction SilentlyContinue

    Write-Host "Carpeta existente: SI" -ForegroundColor Green
    Write-Host "Archivos: $($CacheFiles.Count)"

}
else {

    Write-Host "NO EXISTE IDENTITY CACHE." -ForegroundColor Red
}

# ------------------------------------------------------------
# REGISTRO DEL USUARIO
#
# Si el usuario tiene sesión activa, su HKU está cargado.
# ------------------------------------------------------------

Write-Host ""
Write-Host "[9] REGISTRO DEL USUARIO" -ForegroundColor Yellow

$HKU = "Registry::HKEY_USERS\$SID"

if (Test-Path $HKU) {

    Write-Host "HIVE DEL USUARIO CARGADO: SI" -ForegroundColor Green

    $IdentityReg = "$HKU\Software\Microsoft\Office\16.0\Common\Identity"

    if (Test-Path $IdentityReg) {

        Write-Host "OFFICE IDENTITY REGISTRO: SI" -ForegroundColor Green

        Get-ItemProperty `
            $IdentityReg `
            -ErrorAction SilentlyContinue |
            Format-List

    }
    else {

        Write-Host "OFFICE IDENTITY REGISTRO: NO" -ForegroundColor Yellow
    }

}
else {

    Write-Host "HIVE DEL USUARIO NO ESTA CARGADO." -ForegroundColor Yellow
    Write-Host "Esto es normal si el usuario no tiene sesión abierta." -ForegroundColor DarkGray
}

# ------------------------------------------------------------
# CLICK-TO-RUN
# ------------------------------------------------------------

Write-Host ""
Write-Host "[10] SERVICIO CLICK-TO-RUN" -ForegroundColor Yellow

$Svc = Get-Service ClickToRunSvc `
    -ErrorAction SilentlyContinue

if ($Svc) {

    [PSCustomObject]@{
        Servicio = $Svc.Name
        Estado   = $Svc.Status
        Inicio   = $Svc.StartType
    } | Format-List

}
else {

    Write-Host "SERVICIO NO ENCONTRADO." -ForegroundColor Red
}

# ------------------------------------------------------------
# COMPROBAR PROCESOS DEL USUARIO
# ------------------------------------------------------------

Write-Host ""
Write-Host "[11] PROCESOS OFFICE DEL USUARIO" -ForegroundColor Yellow

$OfficeProcesses = Get-Process `
    WINWORD,
    EXCEL,
    OUTLOOK,
    POWERPNT,
    ONENOTE `
    -IncludeUserName `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.UserName -match [regex]::Escape($UserName)
    }

if ($OfficeProcesses) {

    $OfficeProcesses |
        Select-Object Name,Id,UserName |
        Format-Table -AutoSize

}
else {

    Write-Host "No hay procesos Office del usuario actualmente." `
        -ForegroundColor DarkGray
}

# ------------------------------------------------------------
# RESULTADO
# ------------------------------------------------------------

$TokenCount = 0

if (Test-Path $LicensingPath) {

    $TokenCount = @(
        Get-ChildItem `
            $LicensingPath `
            -Force `
            -File `
            -ErrorAction SilentlyContinue
    ).Count
}

$SCAStatus = if ($Office.SharedComputerLicensing -eq 1) {
    "OK"
}
else {
    "ERROR"
}

$TokenStatus = if ($TokenCount -gt 0) {
    "TOKEN ENCONTRADO"
}
else {
    "SIN TOKEN"
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " RESULTADO FINAL" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

[PSCustomObject]@{
    Servidor        = $env:COMPUTERNAME
    UPN             = $UPN
    SID             = $SID
    Perfil          = $ProfilePath
    Office          = $Office.VersionToReport
    SCA             = $SCAStatus
    Tokens          = $TokenCount
    EstadoLicencia  = $TokenStatus
    ClickToRun      = if ($Svc) { $Svc.Status } else { "NO ENCONTRADO" }
} | Format-List

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
