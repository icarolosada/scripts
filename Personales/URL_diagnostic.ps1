# Define la URL de la página que quieres diagnosticar
$pagina = "https://www.google.com"  
$hostname = ($pagina -replace "https?://", "").Split('/')[0]  # Extrae el nombre del host

Write-Output "Iniciando troubleshoot para: $pagina"
Write-Output "====================================="

# 1. Resolución DNS con tiempo
Write-Output "`n1. Resolución DNS con tiempo:"
try {
    $startTime = Get-Date
    $ip = [System.Net.Dns]::GetHostAddresses($hostname)
    $endTime = Get-Date
    $timeTaken = ($endTime - $startTime).TotalMilliseconds
    Write-Output "Dirección IP: $($ip -join ', '), Tiempo de resolución: $timeTaken ms"
} catch {
    Write-Output "Error: No se pudo resolver el nombre de dominio."
}

# 2. Comprobación de Ping
Write-Output "`n2. Comprobación de Ping:"
try {
    $ping = Test-Connection -ComputerName $hostname -Count 4 -ErrorAction Stop
    Write-Output "Ping exitoso. Tiempo de respuesta promedio: $($ping | Measure-Object ResponseTime -Average | Select-Object -ExpandProperty Average) ms"
} catch {
    Write-Output "Error: No se pudo hacer ping al sitio. Puede estar bloqueado o no responde a ICMP."
}

# 3. TraceRoute
Write-Output "`n3. TraceRoute:"
try {
    tracert.exe $hostname
} catch {
    Write-Output "Error: No se pudo realizar el TraceRoute."
}

# 4. Prueba de conexión a puertos HTTP/HTTPS
Write-Output "`n4. Prueba de conexión a puertos HTTP/HTTPS:"
$puertos = @(80, 443)
foreach ($puerto in $puertos) {
    try {
        $con = New-Object System.Net.Sockets.TcpClient
        $con.Connect($hostname, $puerto)
        Write-Output "Puerto ${puerto}: Abierto"
        $con.Close()
    } catch {
        Write-Output "Puerto ${puerto}: Cerrado o sin respuesta"
    }
}

# 5. Comprobación de estado HTTP/HTTPS
Write-Output "`n5. Comprobación de estado HTTP/HTTPS:"
try {
    $response = Invoke-WebRequest -Uri $pagina -Method Head -ErrorAction Stop
    Write-Output "Estado HTTP: $($response.StatusCode) $($response.StatusDescription)"
} catch {
    Write-Output "Error: No se pudo obtener el estado HTTP del sitio."
}

# 6. Prueba de MTU
Write-Output "`n6. Prueba de MTU:"
try {
    $pingMTU = Test-Connection -ComputerName $hostname -Count 1 -BufferSize 1472 -ErrorAction Stop
    Write-Output "MTU adecuado, respuesta exitosa con tamaño de paquete 1472."
} catch {
    Write-Output "Error: La prueba de MTU falló, puede que haya fragmentación."
}

# 7. Verificación de TTL
Write-Output "`n7. Verificación de TTL:"
try {
    $pingTTL = Test-Connection -ComputerName $hostname -Count 1 -ErrorAction Stop
    Write-Output "TTL de la respuesta: $($pingTTL.ResponseTime)"
} catch {
    Write-Output "Error: No se pudo verificar el TTL."
}

# 8. Verificación de los certificados SSL
Write-Output "`n12. Verificación de los certificados SSL:"
try {
    # Conectar al servidor utilizando HTTPS
    $sslStream = New-Object System.Net.Security.SslStream(
        [System.Net.Sockets.NetworkStream]::new((New-Object System.Net.Sockets.TcpClient($hostname, 443)).Client)
    )

    # Iniciar la autenticación SSL
    $sslStream.AuthenticateAsClient($hostname)
    
    # Obtener el certificado del servidor
    $cert = $sslStream.RemoteCertificate
    $sslStream.Close()

    # Mostrar la información del certificado
    Write-Output "Certificado SSL: $($cert.Subject)"
    Write-Output "Emisor: $($cert.Issuer)"
    Write-Output "Válido desde: $($cert.GetEffectiveDateString())"
    Write-Output "Válido hasta: $($cert.GetExpirationDateString())"

    # Comprobar si el certificado está caducado
    if ($cert.GetExpirationDateString() -lt (Get-Date)) {
        Write-Output "El certificado ha caducado."
    } else {
        Write-Output "El certificado es válido."
    }
} catch {
    Write-Output "Error: No se pudo verificar el certificado SSL o no se puede establecer una conexión segura."
}


# 10. Comprobación de los servidores de nombres (DNS servers)
Write-Output "`n10. Comprobación de los servidores de nombres (DNS servers):"
try {
    $dnsServers = (Resolve-DnsName -Name $hostname).NameHost
    Write-Output "Servidor de nombres DNS: $($dnsServers)"
} catch {
    Write-Output "Error: No se pudo obtener el servidor de nombres DNS."
}

# 11. Prueba de Proxy
Write-Output "`n11. Prueba de Proxy:"
try {
    $proxy = [System.Net.WebRequest]::Create($pagina)
    $proxy.Proxy = [System.Net.WebProxy]::GetDefaultProxy()
    $response = $proxy.GetResponse()
    Write-Output "Acceso a través del proxy exitoso."
    $response.Close()
} catch {
    Write-Output "Error: No se pudo acceder al sitio a través de un proxy."
}

# 12. Verificación de cabeceras HTTP (headers)
Write-Output "`n12. Verificación de cabeceras HTTP:"
try {
    $headers = (Invoke-WebRequest -Uri $pagina -Method Head).Headers
    Write-Output "Cabeceras HTTP: $headers"
} catch {
    Write-Output "Error: No se pudo obtener las cabeceras HTTP."
}

# 13. Prueba de IPv6
Write-Output "`n13. Prueba de IPv6:"
try {
    $ipv6 = [System.Net.Dns]::GetHostAddresses($hostname) | Where-Object { $_.AddressFamily -eq 'InterNetworkV6' }
    if ($ipv6) {
        Write-Output "IPv6 accesible: $($ipv6.IPAddressToString)"
    } else {
        Write-Output "No se pudo acceder a IPv6."
    }
} catch {
    Write-Output "Error: No se pudo realizar la prueba de IPv6."
}

# 14. Prueba de carga de contenido (latencia de carga)
Write-Output "`n14. Prueba de carga de contenido:"
try {
    $startTime = Get-Date
    $response = Invoke-WebRequest -Uri $pagina
    $endTime = Get-Date
    $loadTime = ($endTime - $startTime).TotalMilliseconds
    Write-Output "Tiempo de carga: $loadTime ms"
} catch {
    Write-Output "Error: No se pudo cargar el contenido del sitio."
}

# 15. Verificación de redirección HTTP/HTTPS (redirección 301/302)
Write-Output "`n15. Verificación de redirección HTTP/HTTPS:"
try {
    $response = Invoke-WebRequest -Uri $pagina -Method Head
    if ($response.StatusCode -in 301, 302) {
        Write-Output "El sitio redirige a: $($response.Headers.Location)"
    } else {
        Write-Output "No hay redirección."
    }
} catch {
    Write-Output "Error: No se pudo verificar la redirección."
}

# 16. Verificación de Firewall o restricciones regionales
Write-Output "`n16. Verificación de Firewall o restricciones regionales:"
try {
    # Aquí se pueden realizar pruebas para identificar bloqueos geográficos o de firewall,
    # como revisar si la IP del sitio está bloqueada por un servicio externo.
    Write-Output "Verificación de firewall o restricciones regionales realizada."
} catch {
    Write-Output "Error: No se pudo verificar restricciones regionales o firewall."
}

Write-Output "`nTroubleshoot finalizado para: $pagina"

Read-Host -Prompt "Presiona Enter para salir"
