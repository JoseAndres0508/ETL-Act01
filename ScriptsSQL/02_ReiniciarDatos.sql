/* =====================================================================
   ISW-623 Actividad 1 - Script 02: reiniciar datos entre pruebas

   Vacía las tablas de datos y reinicia los contadores de identidad
   para volver a ejecutar el paquete desde cero.
   NO borra la base de datos ni la estructura, y conserva el catálogo
   de motivos de rechazo (dbo.CatMotivoRechazo).

   El orden importa: primero las tablas hijas y al final las padres,
   por las claves foráneas.

   CUIDADO: borra TODO el contenido cargado, incluida la bitácora.
   ===================================================================== */

USE PadronElectoral;
GO

-- TRUNCATE es mucho más rápido que DELETE con 3.7 millones de filas.
-- Solo se puede usar en tablas que ninguna clave foránea referencia
-- (Padron y ErroresPadron); además reinicia el IDENTITY de ErroresPadron.
TRUNCATE TABLE dbo.ErroresPadron;
TRUNCATE TABLE dbo.Padron;

-- Estas dos sí son referenciadas por claves foráneas: se usa DELETE.
DELETE FROM dbo.UbicacionElectoral;
DELETE FROM dbo.BitacoraEjecucion;
GO

DBCC CHECKIDENT (N'dbo.BitacoraEjecucion', RESEED, 0);
GO

SELECT 'UbicacionElectoral' AS Tabla, COUNT(*) AS Filas FROM dbo.UbicacionElectoral
UNION ALL SELECT 'Padron',            COUNT(*) FROM dbo.Padron
UNION ALL SELECT 'ErroresPadron',     COUNT(*) FROM dbo.ErroresPadron
UNION ALL SELECT 'BitacoraEjecucion', COUNT(*) FROM dbo.BitacoraEjecucion;
GO
