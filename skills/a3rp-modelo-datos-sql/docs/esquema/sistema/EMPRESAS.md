# Tabla: EMPRESAS (base A3ERP$SISTEMA)

**Módulo A3ERP**: Sistema / administración de instalación (catálogo centralizado de empresas)
**Tipo de objeto**: TABLE (`BASE TABLE`, confirmado en `INFORMATION_SCHEMA.TABLES` contra `A3ERP$SISTEMA`)
**Descripción**: Catálogo centralizado de todas las empresas dadas de alta en esta instalación de A3ERP. Una fila = una empresa = una base de datos SQL Server distinta. Vive en la base **`A3ERP$SISTEMA`** (nombre real confirmado contra `sys.databases` — el nombre `A3E$SISTEMA` que se manejaba antes de verificar era un lapsus, no existe como tal).

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| IDEMPRESA | `int` | No | Clave interna numérica de la empresa. |
| IDEMP | `uniqueidentifier` | No | Identificador GUID de la empresa (además del `int`) — no se ha investigado para qué lo usa A3ERP internamente, no hace falta para este caso de uso. |
| **DATABASENAME** | `varchar(150)` | Sí | **Nombre real de la base de datos SQL Server de esa empresa** — verificado contra `sys.databases`: los 21 valores de esta columna aparecen tal cual en la lista de bases del servidor (`X_DEMO`, `TERRAFLOR`, `JALLUCA`, `ROCROI_PIRINEUS`, etc.). Es la columna clave para este caso de uso: sirve directamente como parámetro de `Sql.Database(servidor, DATABASENAME)`. |
| **DESCRIPCION** | `varchar(250)` | **No** | **Nombre/razón social a mostrar.** A veces coincide literalmente con `DATABASENAME` (p. ej. `TERRAFLOR`/`TERRAFLOR`), a veces es una razón social más legible (`GUTIERREZZAMORAOSCAR` → `"GUTIERREZ ZAMORA, OSCAR"`), y en instalaciones de prueba/demo puede ser un texto auto-generado (`"GARCIANOGUERAJORDI - Auto generada (1365239512)"`). Es la única columna de la tabla marcada `NOT NULL` — fiable como texto a mostrar siempre. |
| SERVERNAME | `varchar(150)` | Sí | Servidor SQL Server que aloja la base de esa empresa. En esta instalación, **todas** las filas (21/21) tienen el mismo valor (`SNYMPT01\A3ERP`) — un único servidor para todas las empresas. La columna existe para instalaciones multi-servidor; **no asumir que siempre será así en otro cliente** (ver limitación en la propuesta del selector). |
| ESCLIENTE | `varchar(1)` | Sí | Flag `T`/`F`. En esta instalación, `F` en las 21 filas — no aporta ninguna señal de filtrado aquí (puede que sí en otras instalaciones con agrupación de empresas). |
| ESASESOR | `varchar(1)` | Sí | Flag `T`/`F`, mismo caso que `ESCLIENTE` (todo `F` aquí). |
| ESCENTRAL | `varchar(1)` | Sí | Flag `T`/`F`, mismo caso (todo `F` aquí). |
| ESDELEGACION | `varchar(1)` | Sí | Flag `T`/`F`, mismo caso (todo `F` aquí). |
| REMOTA | `varchar(1)` | Sí | Flag `T`/`F` — indicaría si la empresa se gestiona en remoto. Todo `F` en esta instalación. |
| COMPRUEBO | `varchar(1)` | Sí | Sin investigar en detalle — todo `F` en esta instalación. |
| COMPRUEBOLIBACTIVAS | `int` | Sí | Sin investigar — probablemente nº de libros contables activos a comprobar. No relevante para este caso de uso. |
| ESTADONEXUS | `int` | Sí | Estado de sincronización con "Nexus" (integración externa de A3ERP) — `NULL` en 17/21 filas, `0` en 4/21. No relevante aquí. |
| NEXTTELEMETRY | `datetime` | Sí | Marca de tiempo de telemetría — administrativo, no relevante aquí. |
| IMAGENEMPRESA | `image` | Sí | Logo/imagen de la empresa en binario. No relevante para este caso de uso (y `image` es un tipo obsoleto en SQL Server, típicamente evitado en consultas masivas). |

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| DATABASENAME | *(ninguna FK real — apunta al **nombre de una base de datos**, no a una tabla)* | Es la clave de negocio que enlaza esta fila con toda una base de datos completa (el modelo de facturación de esa empresa vive allí). No es una relación SQL normal, es la pieza central del diseño del selector de empresa (ver propuesta). |

## Notas / gotchas

- **21 filas registradas en `EMPRESAS`, pero muchas más bases en el servidor** (`sys.databases` devuelve ~38 bases no-sistema). `EMPRESAS` es el catálogo **curado** de empresas realmente dadas de alta en A3ERP — bases como `2021IB`…`2026IB` (parecen archivos anuales), `GestionBackup`, `DBQSPro`, `TEST`, `X_TICKELIA`, `ROCROI_PIRINEUS_SL` (con sufijo `_SL` distinto del `ROCROI_PIRINEUS` que sí está en `EMPRESAS`) **no aparecen** en `EMPRESAS` — no asumir que "toda base del servidor es una empresa válida"; `EMPRESAS.DATABASENAME` es la única fuente fiable de qué bases son empresas reales de A3ERP.
- Todas las columnas flag (`ESCLIENTE`/`ESASESOR`/`ESCENTRAL`/`ESDELEGACION`/`REMOTA`/`COMPRUEBO`) salen `F` en las 21 filas de esta instalación — **no sirven de filtro aquí**, aunque existan para ese propósito en instalaciones más grandes/agrupadas. Si se reutiliza este patrón en otro cliente, comprobar de nuevo si esas columnas tienen valores mixtos antes de decidir si hace falta filtrar por ellas.
- `DESCRIPCION` es la única columna `NOT NULL` de la tabla — es la elección correcta para mostrar siempre un texto, incluso en los casos "Auto generada (...)" de instalaciones de prueba.
- No se ha verificado si `DATABASENAME` puede repetirse (misma base usada por más de una fila de `EMPRESAS`) ni si puede haber mayúsculas/minúsculas inconsistentes respecto al nombre real de la base — a revisar si en el futuro se automatiza la generación de consultas a partir de esta tabla sin supervisión.
