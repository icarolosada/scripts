# Asegurarse de que PowerShell esté usando UTF-8 para la salida
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Cambiar la codificación de salida
$OutputEncoding = New-Object -TypeName System.Text.UTF8Encoding

# Función para eliminar archivos y contar los eliminados
function Remove-FileAndCount {
    param (
        [string]$path
    )
    $files = Get-ChildItem -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    $filesCount = $files.Count
    if ($filesCount -gt 0) {
        $files | Remove-Item -Force -Recurse -Confirm:$false -ErrorAction SilentlyContinue
    }
    return $filesCount
}

# Función para medir el tiempo de ejecución de cada paso
function Measure-StepTime {
    param (
        [string]$stepName,
        [scriptblock]$stepAction
    )
    $startTime = Get-Date
    Write-Host "$stepName en progreso..." -NoNewline
    & $stepAction
    $endTime = Get-Date
    $duration = $endTime - $startTime

    # Obtener los minutos y segundos
    $minutes = [math]::Floor($duration.TotalMinutes)
    $seconds = [math]::Floor($duration.TotalSeconds) % 60

    # Mostrar el tiempo en formato adecuado
    if ($minutes -gt 0) {
        Write-Host -NoNewline "`r$stepName completado en $minutes minutos y $seconds segundos."
    } else {
        Write-Host -NoNewline "`r$stepName completado en $seconds segundos."
    }
    Write-Host -ForegroundColor Green " Hecho"
}

# Comprobación de privilegios de administrador
$admin = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $admin.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "Este script requiere privilegios de administrador."
    Exit
}

Write-Output "Iniciando la limpieza del sistema..."

# Obtener el espacio en disco antes de la limpieza (para calcular el espacio liberado)
$before = Get-PSDrive C

# Inicializar contador de archivos eliminados
$deletedCount = 0

# Limpiar archivos temporales
Measure-StepTime "Limpiando archivos temporales" {
    $deletedCount += Remove-FileAndCount "$env:TEMP\*"
    $deletedCount += Remove-FileAndCount "$env:TMP\*"
    $deletedCount += Remove-FileAndCount "$env:SystemDrive\*.tmp"
    $deletedCount += Remove-FileAndCount "$env:SystemDrive\*._mp"
    $deletedCount += Remove-FileAndCount "$env:windir\temp\*"
    $deletedCount += Remove-FileAndCount "$env:AppData\temp\*"
    $deletedCount += Remove-FileAndCount "$env:HomePath\AppData\LocalLow\Temp\*"
}

# Eliminar archivos de logs, trazas y archivos antiguos
Measure-StepTime "Eliminando logs, trazas y archivos antiguos" {
    $deletedCount += Remove-FileAndCount "$env:SystemDrive\*.log"
    $deletedCount += Remove-FileAndCount "$env:SystemDrive\*.old"
    $deletedCount += Remove-FileAndCount "$env:SystemDrive\*.trace"
    $deletedCount += Remove-FileAndCount "$env:windir\*.bak"
}

# Limpiar archivos de restauración creados por la utilidad checkdisk
Measure-StepTime "Limpiando archivos de checkdisk" {
    $deletedCount += Remove-FileAndCount "$env:SystemDrive\*.chk"
}

# Limpiar la papelera de reciclaje
Measure-StepTime "Vaciando la Papelera de reciclaje" {
    $deletedCount += Remove-FileAndCount "$env:SystemDrive\$Recycle.Bin"
}

# Eliminar informe de energía de powercfg
Measure-StepTime "Eliminando informe de energía de powercfg" {
    $deletedCount += Remove-FileAndCount "$env:windir\system32\energy-report.html"
}

# Eliminar archivos de instalación de controladores no utilizados
Measure-StepTime "Eliminando archivos de instalación de controladores no utilizados" {
    $deletedCount += Remove-FileAndCount "$env:SystemDrive\AMD\*"
    $deletedCount += Remove-FileAndCount "$env:SystemDrive\NVIDIA\*"
    $deletedCount += Remove-FileAndCount "$env:SystemDrive\INTEL\*"
}

# Limpiar la caché de Windows Update
Measure-StepTime "Limpiando caché de Windows Update" {
    $deletedCount += Remove-FileAndCount "$env:windir\SoftwareDistribution\Download\*"
}


# Eliminar archivos de caché de Prefetch
Measure-StepTime "Limpiando archivos de Prefetch" {
    $deletedCount += Remove-FileAndCount "$env:SystemDrive\Windows\Prefetch\*"
}

# Eliminar archivos de minidumps de errores del sistema
Measure-StepTime "Eliminando minidumps de errores del sistema" {
    $deletedCount += Remove-FileAndCount "$env:SystemDrive\Windows\Minidump\*"
}

# Limpiar la carpeta de informes de errores de Windows (WER)
Measure-StepTime "Limpiando informes de errores de Windows (WER)" {
    $deletedCount += Remove-FileAndCount "$env:SystemDrive\ProgramData\Microsoft\Windows\WER\*"
}

# Limpiar logs de Windows Update
Measure-StepTime "Limpiando logs de Windows Update" {
    $deletedCount += Remove-FileAndCount "$env:SystemDrive\Windows\Logs\WindowsUpdate\*"
}

# Limpiar archivos de respaldo de WinSxS
Measure-StepTime "Limpiando archivos de respaldo de WinSxS" {
    dism /online /cleanup-image /startcomponentcleanup /resetbase
}

# Limpiar los registros de eventos
$logsLimpiados = @()  # Inicializar un array para almacenar los logs limpiados

Measure-StepTime "Limpiando registros de eventos" {
    $logNames = Get-WinEvent -ListLog * | ForEach-Object { $_.LogName }

    foreach ($logName in $logNames) {
        try {
            wevtutil cl $logName
            $logsLimpiados += $logName
        }
        catch {
            Write-Host "No se pudo limpiar el log $logName - " $_.Exception.Message -ForegroundColor Yellow
            # También podrías verificar si el error está relacionado con acceso denegado
            if ($_.Exception.Message -like "*acceso denegado*") {
                Write-Host "Acceso denegado al log $logName" -ForegroundColor Red
            }
        }
    }
}

# Limpiar logs de eventos comunes (Application, System, Security) usando Clear-EventLog
Measure-StepTime "Limpiando logs comunes de eventos (Application, System, Security)" {
    foreach ($logName in @("Application", "System", "Security")) {
        try {
            Clear-EventLog -LogName $logName -ErrorAction SilentlyContinue
            $logsLimpiados += $logName  # Almacenar el nombre del log limpiado
        }
        catch {
            Write-Host "No se pudo limpiar el log con Clear-EventLog: $logName - " $_.Exception.Message -ForegroundColor Yellow
        }
    }
}

# Mostrar los logs limpiados al final
if ($logsLimpiados.Count -gt 0) {
    Write-Host "`nLogs de eventos limpiados:" -ForegroundColor Green
    $logsLimpiados | ForEach-Object { Write-Host $_ -ForegroundColor Green }
} else {
    Write-Host "No se encontraron logs de eventos que limpiar." -ForegroundColor Yellow
}

Write-Host "Proceso de limpieza de logs de eventos completado." -ForegroundColor Green

# Obtener el espacio en disco después de la limpieza
$after = Get-PSDrive C

Write-Host "Limpieza completada con éxito" -ForegroundColor Green

# Calcular y mostrar la diferencia de espacio libre antes y después de la limpieza
$freedSpace = [math]::round(($before.Free - $after.Free) / 1GB, 2)
Write-Host "Espacio liberado: $freedSpace GB" -ForegroundColor Green

# Mostrar el total de archivos eliminados
Write-Host "Archivos eliminados: $deletedCount" -ForegroundColor Green
