# Cambiar la política de ejecución temporalmente (si no lo has configurado en el .bat)
$originalPolicy = Get-ExecutionPolicy
Set-ExecutionPolicy Bypass -Scope Process -Force

try {
    # Obtiene los perfiles de WiFi guardados en el sistema
    $wifiProfiles = netsh wlan show profiles | Select-String "\:\s(.*)$" | ForEach-Object { $_.Matches[0].Groups[1].Value }

    # Recorre cada perfil y obtiene la clave de seguridad (si existe)
    foreach ($profile in $wifiProfiles) {
        # Muestra el nombre de la red WiFi
        Write-Output "Red WiFi: $profile"
        
        # Obtiene la información de la clave del perfil
        $wifiKeyOutput = netsh wlan show profile name="$profile" key=clear
        $wifiKey = $wifiKeyOutput | Select-String "Key Content"  # "Key Content" en lugar de "Contenido de la clave"

        # Muestra la clave si se encuentra, en color verde
        if ($wifiKey) {
            $key = $wifiKey.ToString().Split(':')[1].Trim()
            Write-Output "Clave: $key`n"
        } else {
            Write-Output "Clave: No disponible`n"
        }
    }
}
finally {
    # Restaurar la política de ejecución original
    Set-ExecutionPolicy $originalPolicy -Scope Process -Force
}
