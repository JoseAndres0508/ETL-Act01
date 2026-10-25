<#
  ISW-623 Actividad 1 - Verificador de archivos de entrada

  Revisa distelec.txt y PADRON_COMPLETO.txt en DatosEntrada y muestra:
    - cantidad de líneas
    - líneas que no tienen el número esperado de columnas
    - longitud mínima y máxima de cada campo
    - campos vacíos por columna

  Sirve para comprobar el formato REAL de los archivos (incluido RELLENO)
  antes de configurar los Flat File Source. No modifica ningún archivo.

  Uso (PowerShell):
      .\Verificar_Archivos.ps1
      .\Verificar_Archivos.ps1 -RutaBase "C:\ProyectoPadron"

  NOTA: asume archivos separados por coma, sin comas dentro de los campos.
  Los nombres de columna son los esperados; confirme el orden real con la
  primera línea que imprime el script.
#>
param(
    [string]$RutaBase = (Split-Path -Parent $PSScriptRoot)
)

# ISO-8859-1 lee cada byte como un carácter: sirve para medir longitudes
$codificacion = [System.Text.Encoding]::GetEncoding(28591)

function Revisar-Archivo {
    param([string]$Ruta, [int]$Esperadas, [string[]]$Nombres)

    Write-Host ""
    Write-Host ("=" * 70)
    Write-Host $Ruta
    Write-Host ("=" * 70)

    if (-not (Test-Path $Ruta)) {
        Write-Host "NO EXISTE el archivo." -ForegroundColor Red
        return
    }

    $lineas = [System.IO.File]::ReadAllLines($Ruta, $codificacion)
    Write-Host "Líneas totales: $($lineas.Count)"
    if ($lineas.Count -eq 0) { return }
    Write-Host "Primera línea:  $($lineas[0])"

    $min = New-Object 'int[]' $Esperadas
    $max = New-Object 'int[]' $Esperadas
    $vacios = New-Object 'int[]' $Esperadas
    for ($i = 0; $i -lt $Esperadas; $i++) { $min[$i] = [int]::MaxValue }

    $malas = New-Object System.Collections.ArrayList
    $numero = 0
    foreach ($linea in $lineas) {
        $numero++
        $campos = $linea.Split(',')
        if ($campos.Count -ne $Esperadas) {
            [void]$malas.Add([pscustomobject]@{ Linea = $numero; Columnas = $campos.Count; Texto = $linea })
            continue
        }
        for ($i = 0; $i -lt $Esperadas; $i++) {
            $largo = $campos[$i].Length
            if ($largo -lt $min[$i]) { $min[$i] = $largo }
            if ($largo -gt $max[$i]) { $max[$i] = $largo }
            if ($campos[$i].Trim().Length -eq 0) { $vacios[$i]++ }
        }
    }

    $buenas = $lineas.Count - $malas.Count
    Write-Host "Líneas con $Esperadas columnas: $buenas"
    if ($malas.Count -gt 0) {
        Write-Host "Líneas con otro número de columnas: $($malas.Count) (primeras 10)" -ForegroundColor Yellow
        $malas | Select-Object -First 10 | Format-Table -AutoSize -Wrap
    }

    $resumen = for ($i = 0; $i -lt $Esperadas; $i++) {
        [pscustomobject]@{
            Posicion = $i + 1
            Campo    = $Nombres[$i]
            LongMin  = if ($buenas -gt 0) { $min[$i] } else { "-" }
            LongMax  = if ($buenas -gt 0) { $max[$i] } else { "-" }
            Vacios   = $vacios[$i]
        }
    }
    $resumen | Format-Table -AutoSize
}

Revisar-Archivo -Ruta (Join-Path $RutaBase "DatosEntrada\PADRON_COMPLETO.txt") -Esperadas 8 `
    -Nombres @("CEDULA", "CODELEC", "RELLENO", "FECHACADUC", "JUNTA", "NOMBRE", "APELLIDO1", "APELLIDO2")

Revisar-Archivo -Ruta (Join-Path $RutaBase "DatosEntrada\distelec.txt") -Esperadas 4 `
    -Nombres @("CODELEC", "PROVINCIA", "CANTON", "DISTRITO")
