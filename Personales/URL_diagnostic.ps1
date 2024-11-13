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
    if ($ping.StatusCode -eq 0) {
        Write-Output "Ping exitoso. Tiempo de respuesta promedio: $($ping | Measure-Object ResponseTime -Average | Select-Object -ExpandProperty Average) ms"
    } else {
        Write-Output "Ping fallido. Código de estado: $($ping.StatusCode)"
    }
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
Write-Output "`n8. Verificación de los certificados SSL:"
try {
    # Conectar al servidor utilizando HTTPS
    $tcpClient = New-Object System.Net.Sockets.TcpClient($hostname, 443)
    $sslStream = New-Object System.Net.Security.SslStream(
        [System.Net.Sockets.NetworkStream]::new($tcpClient.Client)
    )

    # Iniciar la autenticación SSL
    $sslStream.AuthenticateAsClient($hostname)

    # Obtener el certificado del servidor
    $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($sslStream.RemoteCertificate)
    $sslStream.Close()
    $tcpClient.Close()

    # Mostrar información básica del certificado
    Write-Output "Certificado SSL:"
    Write-Output "  - Asunto (Subject): $($cert.Subject)"
    Write-Output "  - Emisor (Issuer): $($cert.Issuer)"
    Write-Output "  - Algoritmo de firma: $($cert.SignatureAlgorithm.FriendlyName)"
    Write-Output "  - Válido desde: $($cert.NotBefore)"
    Write-Output "  - Válido hasta: $($cert.NotAfter)"

    # Validación de la fecha de vencimiento
    if ($cert.NotAfter -lt (Get-Date)) {
        Write-Output "  - Estado: ❌ El certificado ha caducado."
    } elseif ($cert.NotAfter -lt (Get-Date).AddDays(30)) {
        Write-Output "  - Estado: ⚠️ El certificado caducará en los próximos 30 días."
    } else {
        Write-Output "  - Estado: ✅ El certificado es válido."
    }

    # Verificar si el certificado es auto-firmado (issuer = subject)
    if ($cert.Subject -eq $cert.Issuer) {
        Write-Output "  - Advertencia: ⚠️ El certificado es auto-firmado. Esto puede ser inseguro."
    }

    # Verificación adicional de firma y propósito
    if (-not $cert.Extensions) {
        Write-Output "  - Advertencia: No se encontraron extensiones en el certificado."
    } else {
        foreach ($extension in $cert.Extensions) {
            if ($extension.Oid.FriendlyName -eq "Enhanced Key Usage") {
                Write-Output "  - Propósito del certificado: $($extension.Format($true))"
            }
        }
    }
}
catch {
    Write-Output "Error: No se pudo verificar el certificado SSL o no se puede establecer una conexión segura. Detalles: $_"
}

# 9. Prueba de DNS inverso (reverse DNS lookup)
Write-Output "`n9. Prueba de DNS inverso:"
try {
    $ipAddress = [System.Net.Dns]::GetHostAddresses($hostname)[0].ToString()
    $reverseDNS = [System.Net.Dns]::GetHostEntry($ipAddress).HostName
    Write-Output "DNS inverso: $reverseDNS"
} catch {
    Write-Output "Error: No se pudo realizar la búsqueda DNS inversa."
}

# 10. Comprobación de los servidores de nombres (DNS servers)
Write-Output "`n10. Comprobación de los servidores de nombres (DNS servers):"
try {
    $dnsServers = Resolve-DnsName -Name $hostname -Type A  # Tipo A para obtener las direcciones IPv4
    if ($dnsServers) {
        $dnsServers | ForEach-Object { Write-Output "Servidor DNS: $($_.NameHost)" }
    } else {
        Write-Output "No se encontraron servidores de nombres."
    }
} catch {
    Write-Output "Error: No se pudo resolver el nombre de dominio. Detalles: $_"
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
    # Establecer tiempo de espera máximo para la solicitud
    $timeout = 10  # Tiempo en segundos
    $startTime = Get-Date

    # Realizar la solicitud HTTP con un tiempo de espera
    $response = Invoke-WebRequest -Uri $pagina -TimeoutSec $timeout

    $endTime = Get-Date
    $loadTime = ($endTime - $startTime).TotalSeconds  # Convertir el tiempo a segundos
    $contentSize = $response.Content.Length

    Write-Output "Tiempo de carga: $([math]::Round($loadTime, 2)) segundos"  # Mostrar el tiempo con 2 decimales
    Write-Output "Tamaño del contenido descargado: $([math]::Round($contentSize / 1MB, 2)) MB"  # Mostrar tamaño con 2 decimales

} catch [System.Net.WebException] {
    Write-Output "Error de WebException: No se pudo cargar el contenido del sitio. Detalles: $_"
} catch [System.TimeoutException] {
    Write-Output "Error: El tiempo de espera para cargar el contenido excedió el límite de $timeout segundos."
} catch {
    Write-Output "Error: No se pudo cargar el contenido del sitio. Detalles: $_"
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

# 16. Verificación de Firewall
Write-Output "`n16. Verificación de Firewall:"

# Definir el puerto a verificar (80 para HTTP, 443 para HTTPS)
$port = 80
$hostname = "example.com"  # Cambia esto por el hostname o IP que deseas verificar

# Intentar establecer una conexión a través del puerto
try {
    $tcpConnection = Test-NetConnection -ComputerName $hostname -Port $port -WarningAction SilentlyContinue

    if ($tcpConnection.TcpTestSucceeded) {
        Write-Output "La conexión al puerto $port en $hostname fue exitosa. No hay restricciones de firewall."
    } else {
        Write-Output "Error: No se pudo establecer una conexión al puerto $port en $hostname. Puede haber un firewall bloqueando el acceso."
    }
} catch {
    Write-Output "Error: No se pudo verificar el firewall para $hostname."
}



Write-Output "`nTroubleshoot finalizado para: $pagina"
