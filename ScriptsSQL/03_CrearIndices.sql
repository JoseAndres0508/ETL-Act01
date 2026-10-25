/* =====================================================================
   ISW-623 Actividad 1 - Script 03: índices posteriores a la carga

   Ejecutar DESPUÉS de que el paquete SSIS terminó de cargar el padrón.
   Crear el índice con la tabla ya llena es mucho más rápido que
   mantenerlo fila por fila durante la carga.
   Se puede ejecutar varias veces.
   ===================================================================== */

USE PadronElectoral;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = N'IX_Padron_CodElec' AND object_id = OBJECT_ID(N'dbo.Padron'))
    CREATE INDEX IX_Padron_CodElec ON dbo.Padron (CodElec);
GO

/* Si el índice ya existe y se va a repetir la carga completa, bórrelo
   antes de cargar:   DROP INDEX IX_Padron_CodElec ON dbo.Padron;  */

SELECT i.name AS Indice, OBJECT_NAME(i.object_id) AS Tabla
FROM   sys.indexes AS i
WHERE  i.object_id = OBJECT_ID(N'dbo.Padron') AND i.name IS NOT NULL;
GO
