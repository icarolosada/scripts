# Cambiar la política de ejecución temporalmente
$originalPolicy = Get-ExecutionPolicy
Set-ExecutionPolicy Bypass -Scope Process -Force

function Get-WifiProfiles {
    # Obtiene los perfiles de WiFi guardados en el sistema
    $wifiProfiles = netsh wlan show profiles | Select-String "\:\s(.*)$" | ForEach-Object { $_.Matches[0].Groups[1].Value }
    return $wifiProfiles
}

function Get-WifiKey {
    param (
        [string]$profile
    )
    # Obtiene la información de la clave del perfil
    $wifiKeyOutput = netsh wlan show profile name="$profile" key=clear
    $wifiKey = $wifiKeyOutput | Select-String "Key Content"
    
    if ($wifiKey) {
        # Extrae y devuelve la clave de la red
        return $wifiKey.ToString().Split(':')[1].Trim()
    } else {
        return $null
    }
}

function Display-WifiInfo {
    param (
        [string[]]$wifiProfiles
    )

    # Recorre cada perfil y obtiene la clave de seguridad (si existe)
    foreach ($profile in $wifiProfiles) {
        Write-Host "Red WiFi: $profile" -ForegroundColor Cyan
        
        # Obtiene la clave de la red WiFi
        $key = Get-WifiKey -profile $profile
        
        # Muestra la clave si se encuentra
        if ($key) {
            Write-Host "Clave: $key" -ForegroundColor Green
        } else {
            Write-Host "Clave: No disponible" -ForegroundColor Red
        }
        Write-Host "`n"
    }
}

try {
    # Obtiene los perfiles de WiFi
    $wifiProfiles = Get-WifiProfiles
    
    if ($wifiProfiles.Count -eq 0) {
        Write-Host "No se encontraron perfiles WiFi guardados." -ForegroundColor Yellow
    } else {
        # Muestra la información de los perfiles WiFi
        Display-WifiInfo -wifiProfiles $wifiProfiles
    }
}
catch {
    Write-Host "Ocurrió un error al obtener la información de las redes WiFi." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}
finally {
    # Restaurar la política de ejecución original
    Set-ExecutionPolicy $originalPolicy -Scope Process -Force
}
