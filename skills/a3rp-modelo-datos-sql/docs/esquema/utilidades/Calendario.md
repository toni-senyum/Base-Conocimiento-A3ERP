# Tabla calculada: Calendario (modelo Power BI)

**Módulo A3ERP**: N/A — **no es un objeto de A3ERP/SQL Server**. No existe en `X_DEMO` ni en ninguna base de datos del ERP; es una tabla auxiliar generada dentro del propio modelo semántico de Power BI (DAX `CALENDAR()` + `GENERATE`, ver `scripts/generate_tmdl.py::render_calendario_tmdl()` en el proyecto A3ERP-PowerBI).
**Tipo de objeto**: Tabla calculada (DAX), modo `import` con `partition ... = calculated`.
**Descripción**: Tabla de fechas estándar para relacionarse con `Facturas[FECHA]` y habilitar jerarquías de tiempo (Año/Mes) en visuales.

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| Fecha | `date` | No | `CALENDAR(MIN(Facturas[Fecha]), MAX(Facturas[Fecha]))`. Clave; marcada `dataCategory: Time` a nivel de tabla. |
| Anio | `int64` | No | |
| Mes | `int64` | No | Tiene una columna oculta de orden (`NumeroMes`) para que "Enero" no ordene alfabéticamente. |
| AnioMes | `string` | No | Tiene una columna oculta de orden (`AnioMesNumero`). |

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| Fecha | Facturas (CABEFACV.FECHA) | Relación de modelo (many-to-one, cardinalidad por defecto) — no es FK de SQL Server, es el patrón habitual de tabla de fechas |

## Notas / gotchas

- **No confundir con un objeto real de A3ERP** — no aparece en `INFORMATION_SCHEMA.TABLES` de `X_DEMO` porque no vive ahí; es 100% generado en el modelo semántico de Power BI.
- Cubre el rango completo de `Facturas[Fecha]` en el momento de generarse — en `X_DEMO`, del 2019-01-05 al 2026-08-13 (~2.778 días). Si `Facturas[Fecha]` cambia de rango (más datos reales), esta tabla crece automáticamente al regenerarse.
- Power BI Desktop le añade automáticamente una columna `Date` inferida (duplicado de `Fecha`) la primera vez que se abre el `.pbip` si algún visual usa la jerarquía de fecha nativa — el generador (`generate_tmdl.py`) no la declara; regenerar el `.tmdl` desde cero se la llevaría por delante si no se tiene en cuenta.
