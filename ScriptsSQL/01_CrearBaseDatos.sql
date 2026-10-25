
USE master;
GO

IF DB_ID(N'PadronElectoral') IS NULL
    CREATE DATABASE PadronElectoral;
GO

/* Con 3.7 millones de filas el registro de transacciones crece mucho
   en el modelo FULL (el valor por defecto). Para este proyecto no se
   necesitan copias del registro, así que se usa SIMPLE. */
ALTER DATABASE PadronElectoral SET RECOVERY SIMPLE;
GO

USE PadronElectoral;
GO

/* ---------------------------------------------------------------------
   1. Bitácora de ejecución (RF-10)
   Una fila por ejecución del paquete. La llena la Persona 5 con los
   contadores (Row Count) al terminar el flujo.
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.BitacoraEjecucion', N'U') IS NULL
CREATE TABLE dbo.BitacoraEjecucion (
    IdEjecucion          INT IDENTITY(1,1)  NOT NULL,
    Paquete              VARCHAR(100)       NOT NULL,
    FechaInicio          DATETIME2(0)       NOT NULL
        CONSTRAINT DF_Bitacora_FechaInicio DEFAULT (SYSDATETIME()),
    FechaFin             DATETIME2(0)       NULL,
    Estado               VARCHAR(20)        NOT NULL
        CONSTRAINT DF_Bitacora_Estado DEFAULT ('EnEjecucion'),
    CatalogoLeidos       INT                NULL,
    CatalogoCargados     INT                NULL,
    CatalogoRechazados   INT                NULL,
    PadronLeidos         INT                NULL,
    PadronCargados       INT                NULL,
    PadronRechazados     INT                NULL,
    Observaciones        VARCHAR(500)       NULL,
    CONSTRAINT PK_BitacoraEjecucion PRIMARY KEY (IdEjecucion),
    CONSTRAINT CK_Bitacora_Estado
        CHECK (Estado IN ('EnEjecucion', 'Exitoso', 'Fallido'))
);
GO

/* ---------------------------------------------------------------------
   2. Catálogo de ubicaciones electorales (RF-02), archivo distelec.txt
   Los cuatro campos del archivo. El código electoral es TEXTO de
   seis caracteres: nunca se convierte a número.
   En el archivo real los nombres vienen rellenados con espacios a la
   derecha y el distrito del código 201060 contiene una coma; el flujo
   debe leer el catálogo con 4 columnas (la última absorbe la coma) y
   aplicar TRIM antes de cargar. Largos máximos reales ya recortados:
   provincia 10, cantón 22, distrito 34.
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.UbicacionElectoral', N'U') IS NULL
CREATE TABLE dbo.UbicacionElectoral (
    CodElec    CHAR(6)      NOT NULL,
    Provincia  VARCHAR(50)  NOT NULL,
    Canton     VARCHAR(50)  NOT NULL,
    Distrito   VARCHAR(80)  NOT NULL,
    CONSTRAINT PK_UbicacionElectoral PRIMARY KEY (CodElec),
    CONSTRAINT CK_UbicacionElectoral_CodElec CHECK (LEN(CodElec) = 6)
);
GO

/* ---------------------------------------------------------------------
   3. Padrón electoral (RF-01, RF-09), archivo PADRON_COMPLETO.txt
   Los ocho campos del archivo. La cédula es TEXTO de 9 dígitos para
   conservar los ceros iniciales. RELLENO se guarda tal como viene del
   archivo (no se asume vacío). En el archivo real es siempre 1 espacio,
   que tras el TRIM queda como cadena vacía.
   La provincia, cantón y distrito NO se repiten aquí: se obtienen por
   la clave foránea CodElec (vista dbo.vw_PadronConUbicacion).
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.Padron', N'U') IS NULL
CREATE TABLE dbo.Padron (
    Cedula      VARCHAR(9)    NOT NULL,
    CodElec     CHAR(6)       NOT NULL,
    Relleno     VARCHAR(20)   NULL,
    FechaCaduc  DATE          NOT NULL,
    Junta       VARCHAR(10)   NOT NULL,
    Nombre      VARCHAR(50)   NOT NULL,
    Apellido1   VARCHAR(50)   NOT NULL,
    Apellido2   VARCHAR(50)   NULL,      -- hay personas sin segundo apellido
    FechaCarga  DATETIME2(0)  NOT NULL
        CONSTRAINT DF_Padron_FechaCarga DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Padron PRIMARY KEY (Cedula),
    CONSTRAINT FK_Padron_UbicacionElectoral
        FOREIGN KEY (CodElec) REFERENCES dbo.UbicacionElectoral (CodElec),
    CONSTRAINT CK_Padron_Cedula
        CHECK (LEN(Cedula) = 9 AND Cedula NOT LIKE '%[^0-9]%')
);
GO

/* ---------------------------------------------------------------------
   4. Motivos de rechazo (RF-08)
   Lista cerrada de códigos. El paquete SSIS debe usar exactamente
   estos valores en la columna CodigoMotivo de dbo.ErroresPadron.
   Si el equipo necesita un motivo nuevo, se agrega aquí con un INSERT.
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.CatMotivoRechazo', N'U') IS NULL
CREATE TABLE dbo.CatMotivoRechazo (
    CodigoMotivo  VARCHAR(30)   NOT NULL,
    Descripcion   VARCHAR(200)  NOT NULL,
    CONSTRAINT PK_CatMotivoRechazo PRIMARY KEY (CodigoMotivo)
);
GO

INSERT INTO dbo.CatMotivoRechazo (CodigoMotivo, Descripcion)
SELECT v.CodigoMotivo, v.Descripcion
FROM (VALUES
    ('CEDULA_VACIA',        'La cédula viene vacía o solo con espacios'),
    ('CEDULA_LONGITUD',     'La cédula no tiene exactamente 9 caracteres'),
    ('CEDULA_CARACTERES',   'La cédula contiene caracteres que no son dígitos'),
    ('CEDULA_DUPLICADA',    'La cédula ya fue cargada antes (se conserva la primera aparición)'),
    ('FECHA_INVALIDA',      'FECHACADUC no es una fecha válida en formato AAAAMMDD'),
    ('CODELEC_NO_EXISTE',   'El código electoral no existe en el catálogo de ubicaciones'),
    ('CATALOGO_INVALIDO',   'Registro del catálogo con código o nombres vacíos o con longitud incorrecta'),
    ('CATALOGO_DUPLICADO',  'El código electoral del catálogo ya fue cargado antes'),
    ('LINEA_MALFORMADA',    'La línea no tiene el número de columnas esperado o no se pudo leer')
) AS v (CodigoMotivo, Descripcion)
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.CatMotivoRechazo c WHERE c.CodigoMotivo = v.CodigoMotivo
);
GO

/* ---------------------------------------------------------------------
   5. Registros rechazados (RF-08)
   Guarda el registro original y el motivo. NumeroLinea puede quedar
   NULL si el flujo no logra calcularlo.
   Sirve para ambos archivos: la columna Archivo indica el origen.
   --------------------------------------------------------------------- */
IF OBJECT_ID(N'dbo.ErroresPadron', N'U') IS NULL
CREATE TABLE dbo.ErroresPadron (
    IdError           INT IDENTITY(1,1)  NOT NULL,
    IdEjecucion       INT                NULL,
    Archivo           VARCHAR(100)       NOT NULL,
    NumeroLinea       INT                NULL,
    RegistroOriginal  VARCHAR(1000)      NULL,
    CodigoMotivo      VARCHAR(30)        NOT NULL,
    FechaRegistro     DATETIME2(0)       NOT NULL
        CONSTRAINT DF_ErroresPadron_FechaRegistro DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_ErroresPadron PRIMARY KEY (IdError),
    CONSTRAINT FK_ErroresPadron_Motivo
        FOREIGN KEY (CodigoMotivo) REFERENCES dbo.CatMotivoRechazo (CodigoMotivo),
    CONSTRAINT FK_ErroresPadron_Bitacora
        FOREIGN KEY (IdEjecucion) REFERENCES dbo.BitacoraEjecucion (IdEjecucion)
);
GO

/* ---------------------------------------------------------------------
   6. Índices de apoyo
   (las claves primarias ya crean su propio índice)
   El índice sobre dbo.Padron(CodElec) NO se crea aquí: mantenerlo
   durante la carga de 3.7 millones de filas la hace mucho más lenta.
   Se crea después en 03_CrearIndices.sql.
   --------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.indexes
               WHERE name = N'IX_ErroresPadron_Motivo' AND object_id = OBJECT_ID(N'dbo.ErroresPadron'))
    CREATE INDEX IX_ErroresPadron_Motivo ON dbo.ErroresPadron (CodigoMotivo);
GO

/* ---------------------------------------------------------------------
   7. Vistas para consultas y demostración (RF-07)
   --------------------------------------------------------------------- */
CREATE OR ALTER VIEW dbo.vw_PadronConUbicacion
AS
SELECT  p.Cedula,
        p.Nombre,
        p.Apellido1,
        p.Apellido2,
        p.FechaCaduc,
        p.Junta,
        p.CodElec,
        u.Provincia,
        u.Canton,
        u.Distrito
FROM    dbo.Padron AS p
JOIN    dbo.UbicacionElectoral AS u ON u.CodElec = p.CodElec;
GO

CREATE OR ALTER VIEW dbo.vw_ErroresDetalle
AS
SELECT  e.IdError,
        e.IdEjecucion,
        e.Archivo,
        e.NumeroLinea,
        e.CodigoMotivo,
        m.Descripcion AS Motivo,
        e.RegistroOriginal,
        e.FechaRegistro
FROM    dbo.ErroresPadron AS e
JOIN    dbo.CatMotivoRechazo AS m ON m.CodigoMotivo = e.CodigoMotivo;
GO

/* ---------------------------------------------------------------------
   8. Comprobación final: lista los objetos creados
   --------------------------------------------------------------------- */
SELECT  t.name AS Tabla,
        (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id = t.object_id) AS Columnas
FROM    sys.tables AS t
WHERE   t.schema_id = SCHEMA_ID(N'dbo')
ORDER BY t.name;
GO
