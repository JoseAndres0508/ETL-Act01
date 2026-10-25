# ETL del padrón electoral (ISW-623, Actividad 1)

## Estructura del proyecto

| Carpeta | Contenido | Responsable |
|---|---|---|
| `DatosEntrada/` | `distelec.txt` y `PADRON_COMPLETO.txt` (archivos de prueba sintéticos) | Persona 2 |
| `DatosRechazados/` | Archivo de registros rechazados que genera el paquete | Persona 4 |
| `ScriptsSQL/` | `01_CrearBaseDatos.sql`, `02_ReiniciarDatos.sql` y las consultas de verificación | Jose Andres / Persona 5 |
| `ProyectoSSIS/` | Solución SSIS (`Carga_Padron.dtsx` y administradores de conexión) | Persona 4 integra |
| `Documentacion/` | Informe técnico, bitácora, guion de demo | Jose Andres |
| `Documentacion/Secciones/` | Aquí entrega cada persona su `Seccion_P#_Nombre.docx` | Todos |
| `Herramientas/` | `Verificar_Archivos.ps1`, para comprobar longitudes y columnas de los archivos | Todos |

## Puesta en marcha en un equipo nuevo

1. Copiar la carpeta completa a cualquier ruta, por ejemplo `C:\ProyectoPadron`.
2. Abrir `ScriptsSQL/01_CrearBaseDatos.sql` en SQL Server Management Studio y ejecutarlo (F5). Crea la base `PadronElectoral` y todas las tablas. Se puede ejecutar varias veces sin perder datos.
3. Abrir la solución de `ProyectoSSIS/` y cambiar **solo** los tres parámetros del proyecto (siguiente sección).
4. Ejecutar el paquete maestro.
5. Para repetir una prueba desde cero, ejecutar `ScriptsSQL/02_ReiniciarDatos.sql`.

## Rutas configurables en SSIS

Nada de rutas escritas a mano dentro de los paquetes. Se crean **tres parámetros de proyecto**
(en Visual Studio: clic derecho al proyecto, *Project.params*):

| Parámetro | Tipo | Valor de ejemplo |
|---|---|---|
| `RutaBase` | String | `C:\ProyectoPadron` |
| `Servidor` | String | `localhost` (o `.\SQLEXPRESS`) |
| `BaseDatos` | String | `PadronElectoral` |

Luego, en cada administrador de conexión se asigna una **expresión** a la propiedad
`ConnectionString` (o a `ServerName` / `InitialCatalog` en el OLE DB):

| Administrador de conexión | Propiedad | Expresión |
|---|---|---|
| Flat File: padrón | `ConnectionString` | `@[$Project::RutaBase] + "\\DatosEntrada\\PADRON_COMPLETO.txt"` |
| Flat File: catálogo | `ConnectionString` | `@[$Project::RutaBase] + "\\DatosEntrada\\distelec.txt"` |
| Flat File: rechazados | `ConnectionString` | `@[$Project::RutaBase] + "\\DatosRechazados\\PadronRechazado.txt"` |
| OLE DB: SQL Server | `ServerName` | `@[$Project::Servidor]` |
| OLE DB: SQL Server | `InitialCatalog` | `@[$Project::BaseDatos]` |

En las expresiones de SSIS la barra invertida se escribe doble (`\\`).
Con esto, para correr el proyecto en otro equipo solo se editan los tres parámetros.

## Acuerdos de diseño que ya están reflejados en el script SQL

- Cédula `VARCHAR(9)` y código electoral `CHAR(6)`: siempre texto, nunca número.
- Los archivos de prueba deben guardarse en **ANSI Windows-1252** y las conexiones de archivo plano usar la página de códigos **1252**, para que las tildes y la ñ lleguen bien a las columnas `VARCHAR`.
- El padrón no repite provincia/cantón/distrito: se relaciona por `CodElec` (clave foránea) y la vista `vw_PadronConUbicacion` los muestra juntos.
- Regla de duplicados: la cédula es clave primaria. Si se repite, se carga la **primera aparición** y las siguientes se rechazan con el motivo `CEDULA_DUPLICADA`. No se elimina nada en silencio.
- Los motivos de rechazo son una lista cerrada en `dbo.CatMotivoRechazo`:
  `CEDULA_VACIA`, `CEDULA_LONGITUD`, `CEDULA_CARACTERES`, `CEDULA_DUPLICADA`, `FECHA_INVALIDA`,
  `CODELEC_NO_EXISTE`, `CATALOGO_INVALIDO`, `CATALOGO_DUPLICADO`, `LINEA_MALFORMADA`.
  Para agregar uno nuevo basta un `INSERT` en esa tabla.
- `dbo.ErroresPadron` guarda errores de **ambos** archivos (columna `Archivo`). `NumeroLinea` admite NULL.
- `dbo.BitacoraEjecucion` es donde la Persona 5 escribe los contadores de leídos, cargados y rechazados.
