# ============================================================
# LIMPIEZA RESTOS MICROSOFT 365 / OFFICE
# Windows Server 2019 + Citrix
# PowerShell 5.1
#
# USO:
#   .\Limpiar-O365.ps1 -WhatIf
#   .\Limpiar-O365.ps1
#
# IMPORTANTE:
# - Ejecutar como Administrador
# - Cierra Word, Excel, Outlook, Teams y OneDrive antes
# - NO elimina perfiles de usuario
# - NO elimina licencias de Windows
# ============================================================

[CmdletBinding(SupportsShouldProcess=$true)]
param()

Clear-Host

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "   LIMPIEZA RESTOS MICROSOFT 365 / OFFICE" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# COMPROBAR ADMINISTRADOR
# ------------------------------------------------------------

$Principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent()
)

if (-not $Principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)) {
    Write-Host "ERROR: Ejecuta PowerShell como ADMINISTRADOR." -ForegroundColor Red
    exit 1
}

# ------------------------------------------------------------
# PROCESOS OFFICE
# ------------------------------------------------------------

Write-Host "[1] COMPROBANDO PROCESOS OFFICE" -ForegroundColor Yellow

$OfficeProcesses = @(
    "WINWORD",
    "EXCEL",
    "OUTLOOK",
    "POWERPNT",
    "ONENOTE",
    "MSACCESS",
    "MSPUB",
    "VISIO",
    "WINPROJ",
    "OfficeClickToRun",
    "OfficeC2RClient",
    "OneDrive"
)

$Running = Get-Process -Name $OfficeProcesses `
    -ErrorAction SilentlyContinue

if ($Running) {

    Write-Host ""
    Write-Host "ESTOS PROCESOS ESTAN ABIERTOS:" -ForegroundColor Red

    $Running |
        Select-Object Name,Id |
        Format-Table -AutoSize

    Write-Host ""
    Write-Host "Cierra las aplicaciones Office y vuelve a ejecutar el script." `
        -ForegroundColor Red

    exit 1
}

Write-Host "OK - No hay procesos Office abiertos." -ForegroundColor Green

# ------------------------------------------------------------
# SERVICIO CLICK-TO-RUN
# ------------------------------------------------------------

Write-Host ""
Write-Host "[2] SERVICIO CLICK-TO-RUN" -ForegroundColor Yellow

$Service = Get-Service ClickToRunSvc `
    -ErrorAction SilentlyContinue

if ($Service) {

    Write-Host "Estado actual: $($Service.Status)"

    if ($Service.Status -ne "Stopped") {

        if ($PSCmdlet.ShouldProcess(
            "ClickToRunSvc",
            "Detener servicio"
        )) {
            Stop-Service ClickToRunSvc -Force -ErrorAction SilentlyContinue
        }
    }

}
else {

    Write-Host "ClickToRunSvc no existe." -ForegroundColor DarkGray
}

# ------------------------------------------------------------
# SERVICIOS OFFICE RESIDUALES
# ------------------------------------------------------------

Write-Host ""
Write-Host "[3] SERVICIOS OFFICE RESIDUALES" -ForegroundColor Yellow

$OfficeServices = Get-Service -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -match "Office|ClickToRun"
    }

if ($OfficeServices) {

    $OfficeServices |
        Select-Object Name,DisplayName,Status,StartType |
        Format-Table -AutoSize
}

# ------------------------------------------------------------
# TAREAS PROGRAMADAS OFFICE
# ------------------------------------------------------------

Write-Host ""
Write-Host "[4] TAREAS PROGRAMADAS OFFICE" -ForegroundColor Yellow

$Tasks = Get-ScheduledTask -ErrorAction SilentlyContinue |
    Where-Object {
        $_.TaskName -match "Office|ClickToRun|OfficeTelemetry"
    }

if ($Tasks) {

    $Tasks |
        Select-Object TaskPath,TaskName,State |
        Format-Table -AutoSize

    foreach ($Task in $Tasks) {

        if ($PSCmdlet.ShouldProcess(
            "$($Task.TaskPath)$($Task.TaskName)",
            "Eliminar tarea"
        )) {

            Unregister-ScheduledTask `
                -TaskName $Task.TaskName `
                -TaskPath $Task.TaskPath `
                -Confirm:$false `
                -ErrorAction SilentlyContinue
        }
    }
}
else {

    Write-Host "No se han encontrado tareas Office." -ForegroundColor Green
}

# ------------------------------------------------------------
# CARPETAS CLICK-TO-RUN
# ------------------------------------------------------------

Write-Host ""
Write-Host "[5] CARPETAS CLICK-TO-RUN" -ForegroundColor Yellow

$Folders = @(
    "C:\Program Files\Common Files\Microsoft Shared\ClickToRun",
    "C:\Program Files\Common Files\Microsoft Shared\ClickToRun\Updates",
    "C:\ProgramData\Microsoft\ClickToRun",
    "C:\ProgramData\Microsoft\Office\ClickToRun",
    "C:\ProgramData\Microsoft\OfficeSoftwareProtectionPlatform",
    "C:\ProgramData\Microsoft\Office\Updates",
    "C:\ProgramData\Microsoft\Office\ClickToRun"
)

foreach ($Folder in $Folders) {

    if (Test-Path $Folder) {

        Write-Host "Encontrado: $Folder"

        if ($PSCmdlet.ShouldProcess(
            $Folder,
            "Eliminar carpeta"
        )) {

            Remove-Item $Folder `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}

# ------------------------------------------------------------
# WINDOWS TEMP OFFICE
# ------------------------------------------------------------

Write-Host ""
Write-Host "[6] TEMP / CACHE OFFICE" -ForegroundColor Yellow

$TempFolders = @(
    "C:\Windows\Temp\OfficeClickToRun",
    "C:\Windows\Temp\OfficeDeployment",
    "C:\Windows\Temp\Office",
    "C:\ProgramData\Microsoft\Office\ClickToRun"
)

foreach ($Folder in $TempFolders) {

    if (Test-Path $Folder) {

        Write-Host "Encontrado: $Folder"

        if ($PSCmdlet.ShouldProcess(
            $Folder,
            "Eliminar carpeta"
        )) {

            Remove-Item $Folder `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}

# ------------------------------------------------------------
# REGISTRO MACHINE
# ------------------------------------------------------------

Write-Host ""
Write-Host "[7] REGISTRO OFFICE MACHINE" -ForegroundColor Yellow

$RegistryMachine = @(
    "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun",
    "HKLM:\SOFTWARE\Microsoft\Office\16.0\ClickToRun",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\ClickToRun",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\16.0\ClickToRun"
)

foreach ($Key in $RegistryMachine) {

    if (Test-Path $Key) {

        Write-Host "Encontrado: $Key"

        if ($PSCmdlet.ShouldProcess(
            $Key,
            "Eliminar clave de registro"
        )) {

            Remove-Item `
                $Key `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}

# ------------------------------------------------------------
# REGISTRO UNINSTALL
# ------------------------------------------------------------

Write-Host ""
Write-Host "[8] ENTRADAS DE DESINSTALACION OFFICE" -ForegroundColor Yellow

$UninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

foreach ($Path in $UninstallPaths) {

    if (Test-Path $Path) {

        Get-ChildItem $Path -ErrorAction SilentlyContinue |
        ForEach-Object {

            $Item = Get-ItemProperty $_.PSPath `
                -ErrorAction SilentlyContinue

            if (
                $Item.DisplayName -match "Microsoft 365 Apps" -or
                $Item.DisplayName -match "Microsoft Office" -or
                $Item.DisplayName -match "Office 16" -or
                $Item.DisplayName -match "Click-to-Run"
            ) {

                Write-Host "$($Item.DisplayName)" -ForegroundColor DarkYellow
                Write-Host "  $($_.PSPath)"

                if ($PSCmdlet.ShouldProcess(
                    $_.PSPath,
                    "Eliminar entrada de desinstalacion"
                )) {

                    Remove-Item `
                        $_.PSPath `
                        -Recurse `
                        -Force `
                        -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

# ------------------------------------------------------------
# REGISTRO MACHINE OFFICE GENERAL
# ------------------------------------------------------------

Write-Host ""
Write-Host "[9] REGISTRO OFFICE RESIDUAL" -ForegroundColor Yellow

$OfficeKeys = @(
    "HKLM:\SOFTWARE\Microsoft\Office\16.0\Common",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Office\16.0\Common"
)

foreach ($Key in $OfficeKeys) {

    if (Test-Path $Key) {

        Write-Host "Existe: $Key"

        # NO SE ELIMINA Common entero.
        # Solo mostramos para detectar restos.
        Get-ChildItem $Key `
            -ErrorAction SilentlyContinue |
            Select-Object PSChildName |
            Format-Table -AutoSize
    }
}

# ------------------------------------------------------------
# ARCHIVOS PROGRAM FILES
# ------------------------------------------------------------

Write-Host ""
Write-Host "[10] RESTOS EN PROGRAM FILES" -ForegroundColor Yellow

$ProgramFolders = @(
    "C:\Program Files\Microsoft Office",
    "C:\Program Files\Microsoft Office 15",
    "C:\Program Files\Microsoft Office 16",
    "C:\Program Files (x86)\Microsoft Office",
    "C:\Program Files (x86)\Microsoft Office 15",
    "C:\Program Files (x86)\Microsoft Office 16"
)

foreach ($Folder in $ProgramFolders) {

    if (Test-Path $Folder) {

        Write-Host "Encontrado: $Folder"

        if ($PSCmdlet.ShouldProcess(
            $Folder,
            "Eliminar carpeta"
        )) {

            Remove-Item $Folder `
                -Recurse `
                -Force `
                -ErrorAction SilentlyContinue
        }
    }
}

# ------------------------------------------------------------
# COMPROBACION FINAL
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " COMPROBACION FINAL" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$RemainingService = Get-Service ClickToRunSvc `
    -ErrorAction SilentlyContinue

$RemainingClick = Test-Path `
    "C:\Program Files\Common Files\Microsoft Shared\ClickToRun"

$RemainingReg = Test-Path `
    "HKLM:\SOFTWARE\Microsoft\Office\ClickToRun"

[PSCustomObject]@{
    ClickToRunSvc       = if ($RemainingService) {
                              $RemainingService.Status
                          } else {
                              "NO EXISTE"
                          }

    ClickToRunFolder    = $RemainingClick
    ClickToRunRegistro  = $RemainingReg
} | Format-List

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan

if ($WhatIfPreference) {

    Write-Host "SIMULACION FINALIZADA - NO SE HA MODIFICADO NADA." `
        -ForegroundColor Yellow

}
else {

    Write-Host "LIMPIEZA FINALIZADA." -ForegroundColor Green
    Write-Host ""
    Write-Host "REINICIA EL SERVIDOR ANTES DE INSTALAR OFFICE 2806." `
        -ForegroundColor Yellow
}

Write-Host "============================================================"