/* =====================================================================
   ISW-623 Actividad 1 - Script 04: consultas de verificación (Persona 5)

   Ejecutar DESPUÉS del paquete Carga_Padron.dtsx con los archivos de
   prueba sintéticos. Cada bloque indica el resultado esperado.
   Se puede ejecutar completo (F5); los resultados salen en pestañas.
   ===================================================================== */

USE PadronElectoral;
GO

/* 1. Última ejecución registrada en la bitácora (RF-10) */
SELECT TOP (1) *
FROM   dbo.BitacoraEjecucion
ORDER BY IdEjecucion DESC;
GO

/* 2. Cuadre leídos = cargados + rechazados, según la bitácora
      Esperado: Padrón 1032 = 1008 + 24 ; Catálogo 2183 = 2179 + 4  */
SELECT TOP (1)
       IdEjecucion,
       'distelec.txt'        AS Archivo,
       CatalogoLeidos        AS Leidos,
       CatalogoCargados      AS Cargados,
       CatalogoRechazados    AS Rechazados,
       CASE WHEN CatalogoLeidos = CatalogoCargados + CatalogoRechazados
            THEN 'Cuadra' ELSE 'NO CUADRA' END AS Control
FROM   dbo.BitacoraEjecucion ORDER BY IdEjecucion DESC;

SELECT TOP (1)
       IdEjecucion,
       'PADRON_COMPLETO.txt' AS Archivo,
       PadronLeidos          AS Leidos,
       PadronCargados        AS Cargados,
       PadronRechazados      AS Rechazados,
       CASE WHEN PadronLeidos = PadronCargados + PadronRechazados
            THEN 'Cuadra' ELSE 'NO CUADRA' END AS Control
FROM   dbo.BitacoraEjecucion ORDER BY IdEjecucion DESC;
GO

/* 3. Mismo cuadre, contando directamente en las tablas
      (no depende de los Row Count del paquete) */
SELECT 'distelec.txt' AS Archivo,
       (SELECT COUNT(*) FROM dbo.UbicacionElectoral)                              AS Cargados,
       (SELECT COUNT(*) FROM dbo.ErroresPadron WHERE Archivo = 'distelec.txt')     AS Rechazados,
       (SELECT COUNT(*) FROM dbo.UbicacionElectoral)
     + (SELECT COUNT(*) FROM dbo.ErroresPadron WHERE Archivo = 'distelec.txt')     AS Total,
       2183 AS LineasDelArchivo
UNION ALL
SELECT 'PADRON_COMPLETO.txt',
       (SELECT COUNT(*) FROM dbo.Padron),
       (SELECT COUNT(*) FROM dbo.ErroresPadron WHERE Archivo = 'PADRON_COMPLETO.txt'),
       (SELECT COUNT(*) FROM dbo.Padron)
     + (SELECT COUNT(*) FROM dbo.ErroresPadron WHERE Archivo = 'PADRON_COMPLETO.txt'),
       1032;
GO

/* 4. Errores por motivo: obtenido contra esperado (matriz de casos) */
WITH Esperado AS (
    SELECT * FROM (VALUES
        ('PADRON_COMPLETO.txt', 'LINEA_MALFORMADA',   2),
        ('PADRON_COMPLETO.txt', 'CEDULA_VACIA',       3),
        ('PADRON_COMPLETO.txt', 'CEDULA_LONGITUD',    2),
        ('PADRON_COMPLETO.txt', 'CEDULA_CARACTERES',  3),
        ('PADRON_COMPLETO.txt', 'FECHA_INVALIDA',     8),
        ('PADRON_COMPLETO.txt', 'CODELEC_NO_EXISTE',  4),
        ('PADRON_COMPLETO.txt', 'CEDULA_DUPLICADA',   2),
        ('distelec.txt',        'CATALOGO_INVALIDO',  3),
        ('distelec.txt',        'CATALOGO_DUPLICADO', 1)
    ) AS v (Archivo, CodigoMotivo, Cantidad)
),
Obtenido AS (
    SELECT Archivo, CodigoMotivo, COUNT(*) AS Cantidad
    FROM   dbo.ErroresPadron
    GROUP BY Archivo, CodigoMotivo
)
SELECT COALESCE(e.Archivo, o.Archivo)           AS Archivo,
       COALESCE(e.CodigoMotivo, o.CodigoMotivo) AS CodigoMotivo,
       e.Cantidad                                AS Esperado,
       ISNULL(o.Cantidad, 0)                     AS Obtenido,
       CASE WHEN e.Cantidad = ISNULL(o.Cantidad, 0) THEN 'Sí' ELSE 'NO' END AS Coincide
FROM   Esperado e
FULL JOIN Obtenido o ON o.Archivo = e.Archivo AND o.CodigoMotivo = e.CodigoMotivo
ORDER BY Archivo, CodigoMotivo;
GO

/* 5. Integridad referencial: padrón sin ubicación (esperado: 0 filas) */
SELECT p.Cedula, p.CodElec
FROM   dbo.Padron p
LEFT JOIN dbo.UbicacionElectoral u ON u.CodElec = p.CodElec
WHERE  u.CodElec IS NULL;
GO

/* 6. Duplicados: la primera aparición está cargada y la repetida rechazada
      (esperado: 2 filas, ambas con EstaEnPadron = 'Sí') */
SELECT e.IdError,
       LEFT(LTRIM(e.RegistroOriginal), 9) AS Cedula,
       CASE WHEN EXISTS (SELECT 1 FROM dbo.Padron p
                         WHERE p.Cedula = LEFT(LTRIM(e.RegistroOriginal), 9))
            THEN 'Sí' ELSE 'NO' END       AS EstaEnPadron,
       e.RegistroOriginal
FROM   dbo.ErroresPadron e
WHERE  e.CodigoMotivo = 'CEDULA_DUPLICADA';
GO

/* 7. Casos válidos especiales de la matriz (esperado: 8 filas) */
SELECT v.Cedula, c.Caso, v.Nombre, v.Apellido1, v.Apellido2,
       v.FechaCaduc, v.CodElec, v.Provincia, v.Canton, v.Distrito,
       p.Relleno
FROM  (VALUES
        ('012345678', 'P01 cero inicial conservado'),
        ('203456781', 'P02 espacios eliminados'),
        ('304567892', 'P03 código con espacios -> 301001'),
        ('405678913', 'P04 Apellido2 = NULL'),
        ('506789124', 'P05 Ñ correcta'),
        ('607891235', 'P06 29/02/2028 válido'),
        ('708912346', 'P07 RELLENO = X'),
        ('109123457', 'P08 consulado 848001')
      ) AS c (Cedula, Caso)
JOIN  dbo.vw_PadronConUbicacion v ON v.Cedula = c.Cedula
JOIN  dbo.Padron p                ON p.Cedula = c.Cedula
ORDER BY v.Cedula;
GO

/* 8. Distrito con coma conservado (esperado: CAI. JORGE ART. M. C (AMBITOS A,B)) */
SELECT CodElec, Provincia, Canton, Distrito
FROM   dbo.UbicacionElectoral
WHERE  CodElec = '201060';
GO

/* 9. Detalle de todos los rechazados con su descripción */
SELECT IdEjecucion, Archivo, CodigoMotivo, Motivo, RegistroOriginal
FROM   dbo.vw_ErroresDetalle
ORDER BY Archivo, CodigoMotivo, IdError;
GO
