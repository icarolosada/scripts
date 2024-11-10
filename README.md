# Varios Scripts Útiles

Este repositorio contiene varios scripts útiles escritos en PowerShell para tareas relacionadas con la administración y limpieza del sistema, diagnóstico de redes WiFi, y análisis de páginas web. Cada script está diseñado para facilitar tareas específicas en entornos Windows.

## Contenido

- **`SystemCleaner.ps1`**: Script para limpiar archivos temporales, logs, minidumps, caché de Windows Update y otros archivos innecesarios. Incluye un procedimiento de limpieza eficiente y muestra el tiempo de ejecución de cada paso.
- **`VerClavesWifiGuardadas.ps1`**: Script para mostrar las claves WiFi guardadas en el sistema.
- **`DiagnosticoPagina.ps1`**: Script para realizar un diagnóstico de una página web y verificar su disponibilidad y estado.

## Uso de los Scripts

### 1. **SystemCleaner.ps1**
Este script ayuda a limpiar tu sistema de archivos innecesarios. Puedes usarlo para liberar espacio en disco eliminando archivos temporales, caché de Windows Update, logs y más.

**Pasos para ejecutar:**
1. Abre PowerShell como Administrador.
2. Navega a la carpeta donde se encuentra el script.
3. Ejecuta el siguiente comando:
   ```powershell
   .\SystemCleaner.ps1
