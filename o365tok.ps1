# ============================================================
# O365 2806 - COMPROBACION LICENCIA SCA
# Windows Server 2019 + Citrix
# PowerShell 5.1
#
# EJECUTAR COMO ADMINISTRADOR
# PREGUNTA EL NOMBRE DEL USUARIO
# NO UTILIZA AD
# NO UTILIZA UPN
# NO UTILIZA CORREO
# NO MODIFICA NADA
# ============================================================

Clear-Host

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " O365 2806 - COMPROBACION LICENCIA CITRIX" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# USUARIO
# ------------------------------------------------------------

do {
    $Usuario = Read-Host "Introduce el nombre del usuario"
}
while ([string]::IsNullOrWhiteSpace($Usuario))

$Usuario = $Usuario.Trim()

Write-Host ""
Write-Host "Usuario seleccionado: $Usuario" -ForegroundColor Green
Write-Host ""

# ------------------------------------------------------------
# OFFICE
# ------------------------------------------------------------

Write-Host "[1] OFFICE INSTALADO" -ForegroundColor Yellow

$OfficeKey = "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun\Configuration"

if (-not (Test-Path $OfficeKey)) {
    Write-Host "ERROR: Office Click-To-Run no encontrado." -ForegroundColor Red
    exit
}

$Office = Get-ItemProperty $OfficeKey

[PSCustomObject]@{
    Version    = $Office.VersionToReport
    Producto   = $Office.ProductReleaseIds
    Canal      = $Office.UpdateChannel
    Plataforma = $Office.Platform
    SCA        = $Office.SharedComputerLicensing
} | Format-List

# ------------------------------------------------------------
# SCA
# ------------------------------------------------------------

Write-Host "[2] SHARED COMPUTER ACTIVATION" -ForegroundColor Yellow

if ("$($Office.SharedComputerLicensing)" -eq "1") {
    Write-Host "SCA ACTIVADO" -ForegroundColor Green
}
else {
    Write-Host "SCA NO ACTIVADO" -ForegroundColor Red
}

# ------------------------------------------------------------
# PERFIL DEL USUARIO
# ------------------------------------------------------------

Write-Host ""
Write-Host "[3] PERFIL DEL USUARIO" -ForegroundColor Yellow

$Profiles = Get-CimInstance Win32_UserProfile `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.LocalPath -like "C:\Users\*" -and
        $_.Special -eq $false
    }

$Perfil = $Profiles |
    Where-Object {
        (Split-Path $_.LocalPath -Leaf) -ieq $Usuario
    } |
    Select-Object -First 1

if (-not $Perfil) {

    $Perfil = $Profiles |
        Where-Object {
            (Split-Path $_.LocalPath -Leaf) -like "*$Usuario*"
        } |
        Select-Object -First 1
}

if (-not $Perfil) {

    Write-Host "NO SE HA ENCONTRADO EL PERFIL." -ForegroundColor Red

    Write-Host ""
    Write-Host "Perfiles disponibles:" -ForegroundColor Yellow

    $Profiles |
        Select-Object @{
            Name = "Usuario"
            Expression = {
                Split-Path $_.LocalPath -Leaf
            }
        },LocalPath,Loaded |
        Format-Table -AutoSize

    exit
}

$ProfilePath = $Perfil.LocalPath

Write-Host "Perfil: $ProfilePath" -ForegroundColor Green
Write-Host "Cargado: $($Perfil.Loaded)"

# ------------------------------------------------------------
# LICENSING
# ------------------------------------------------------------

Write-Host ""
Write-Host "[4] LICENCIA SCA" -ForegroundColor Yellow

$LicensingPath = Join-Path `
    $ProfilePath `
    "AppData\Local\Microsoft\Office\16.0\Licensing"

Write-Host "Ruta: $LicensingPath"
Write-Host ""

if (Test-Path $LicensingPath) {

    $Files = Get-ChildItem `
        $LicensingPath `
        -Force `
        -File `
        -ErrorAction SilentlyContinue

    if ($Files.Count -gt 0) {

        Write-Host "ARCHIVOS DE LICENCIA ENCONTRADOS:" -ForegroundColor Green

        $Files |
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

    Write-Host "NO EXISTE LA CARPETA DE LICENCIA." -ForegroundColor Red
}

# ------------------------------------------------------------
# IDENTITY
# ------------------------------------------------------------

Write-Host ""
Write-Host "[5] OFFICE IDENTITY" -ForegroundColor Yellow

$IdentityPath = Join-Path `
    $ProfilePath `
    "AppData\Local\Microsoft\Office\16.0\Identity"

if (Test-Path $IdentityPath) {

    $IdentityFiles = @(
        Get-ChildItem `
            $IdentityPath `
            -Recurse `
            -Force `
            -File `
            -ErrorAction SilentlyContinue
    )

    Write-Host "IDENTITY: SI" -ForegroundColor Green
    Write-Host "Archivos: $($IdentityFiles.Count)"

}
else {

    Write-Host "IDENTITY: NO" -ForegroundColor Red
}

# ------------------------------------------------------------
# ONEAUTH
# ------------------------------------------------------------

Write-Host ""
Write-Host "[6] ONEAUTH" -ForegroundColor Yellow

$OneAuthPath = Join-Path `
    $ProfilePath `
    "AppData\Local\Microsoft\OneAuth"

if (Test-Path $OneAuthPath) {

    $OneAuthFiles = @(
        Get-ChildItem `
            $OneAuthPath `
            -Recurse `
            -Force `
            -File `
            -ErrorAction SilentlyContinue
    )

    Write-Host "ONEAUTH: SI" -ForegroundColor Green
    Write-Host "Archivos: $($OneAuthFiles.Count)"

}
else {

    Write-Host "ONEAUTH: NO" -ForegroundColor Red
}

# ------------------------------------------------------------
# IDENTITY CACHE
# ------------------------------------------------------------

Write-Host ""
Write-Host "[7] IDENTITY CACHE" -ForegroundColor Yellow

$CachePath = Join-Path `
    $ProfilePath `
    "AppData\Local\Microsoft\IdentityCache"

if (Test-Path $CachePath) {

    $CacheFiles = @(
        Get-ChildItem `
            $CachePath `
            -Recurse `
            -Force `
            -File `
            -ErrorAction SilentlyContinue
    )

    Write-Host "IDENTITY CACHE: SI" -ForegroundColor Green
    Write-Host "Archivos: $($CacheFiles.Count)"

}
else {

    Write-Host "IDENTITY CACHE: NO" -ForegroundColor Red
}

# ------------------------------------------------------------
# CLICK-TO-RUN
# ------------------------------------------------------------

Write-Host ""
Write-Host "[8] CLICK-TO-RUN" -ForegroundColor Yellow

$Service = Get-Service ClickToRunSvc `
    -ErrorAction SilentlyContinue

if ($Service) {

    [PSCustomObject]@{
        Servicio = $Service.Name
        Estado   = $Service.Status
        Inicio   = $Service.StartType
    } | Format-List

}
else {

    Write-Host "SERVICIO NO ENCONTRADO." -ForegroundColor Red
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

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " RESULTADO FINAL" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

[PSCustomObject]@{
    Servidor        = $env:COMPUTERNAME
    Usuario         = $Usuario
    Perfil          = $ProfilePath
    Office          = $Office.VersionToReport
    SCA             = if ($Office.SharedComputerLicensing -eq 1) {"OK"} else {"ERROR"}
    Tokens          = $TokenCount
    EstadoLicencia  = if ($TokenCount -gt 0) {"ENCONTRADO"} else {"NO ENCONTRADO"}
    ClickToRun      = if ($Service) {$Service.Status} else {"NO ENCONTRADO"}
} | Format-List

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
