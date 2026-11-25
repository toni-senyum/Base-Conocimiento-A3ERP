# Tablas: TARIFAS y TARIFAVE (tarifas de venta de artículos)

**Módulo A3ERP**: Artículos/Almacén
**Tipo de objeto**: tablas. Esquema consultado por SELECT en varias BD (proyecto RocRoi, 2026-11). Los tipos y la PK/índices salen de ese informe; no se contrastó con `INFORMATION_SCHEMA` en este repo.
**Descripción**: `TARIFAS` = cabecera (una fila por tarifa). `TARIFAVE` = precios (una fila por artículo, tarifa, moneda, fechas y unidades).

## TARIFAS (cabecera)

| Columna | Tipo | Notas |
|---|---|---|
| TARIFA | `varchar(8)` | Código. Un código numérico se guarda con relleno a la izquierda (`'       1'`, DATALENGTH 8). |
| DESCTARIFA | `varchar(50)` | |
| TIPO | `varchar(1)` | `V` = venta. |

⚠️ **No hay campo de IVA incluido en la cabecera de tarifa.** La única marca es `DATOSCONFIG.IVAINCLUIDO` (global de la empresa): con `F`, `ARTICULO.PRCVENTA` y `TARIFAVE.PRECIO` se guardan **netos**. Cargar un PVP con IVA tal cual duplicaría el IVA: dividir antes (p. ej. entre 1,21) o decidir conscientemente cambiar `IVAINCLUIDO` (afecta a toda la empresa). (verificado en proyecto RocRoi, 2026-11)

## TARIFAVE (precios)

| Columna | Tipo | Notas |
|---|---|---|
| IDTARIFAV | `money` | PK. |
| CODART | `varchar(15)` | Mismo relleno que `ARTICULO.CODART`. |
| TARIFA | `varchar(8)` | |
| CODMON | `varchar(8)` | |
| PRECIO | `float` | |
| FECMIN / FECMAX | `datetime` | Sin límite de vigencia: `1900-01-01` / `9999-12-31`. |
| UNIDADES | `float` | Tramo por unidades. |

Índices: único `IDX_TARIFAVE` = (TARIFA, CODMON, CODART, FECMIN, FECMAX, UNIDADES); no único `ARTTAR` = (CODART, TARIFA, FECMAX).

## Notas / gotchas

- Un mismo artículo-tarifa puede tener varias filas si cambian `UNIDADES` o las fechas (por el índice único).
- En una BD con datos reales (migración de un cliente), `UNIDADES = 0.0` en todas las filas: el campo está en el esquema pero no se usaba. **No está verificado cómo interpreta a3ERP `UNIDADES`** (ver Dudosos de la propuesta 2026-11-24); si hacen falta precios por nº de personas, la alternativa que no depende de `UNIDADES` es una tarifa por columna de precio.
- 🔴 **Carga con in&out de la hoja `TARIFAVE`**: la hoja debe llevar los campos de la clave única (`TARIFA`, `CODMON`, `CODART`, `FECMIN`, `FECMAX`, `UNIDADES`) además de `PRECIO`; no se informa `IDTARIFAV`. Sin `CODMON`/`FECMIN`/`FECMAX`/`UNIDADES`, in&out rechaza cada fila con «Falta campo clave» (el mensaje sale 3 veces por fila) y no carga nada. Valores que importaron bien para «sin vigencia»: `CODMON` = `EURO`, `FECMIN` = 01/01/1900, `FECMAX` = 31/12/9999, `UNIDADES` = 0, con las fechas como celdas de fecha reales y `UNIDADES` como número. Tras la importación, `IDTARIFAV` quedó único y no nulo en todas las filas. (verificado en proyecto RocRoi, 2026-11)
- **Decimales de precio**: con `DATOSCONFIG.IVAINCLUIDO = F` y `NUMDECPRC = 4`, `ARTICULO.PRCVENTA` y `TARIFAVE.PRECIO` se guardan con 3-4 decimales (neto = PVP/1,21 sin redondear a 2) y `ROUND(neto×1,21; 2)` devuelve el PVP original. (verificado en proyecto RocRoi, 2026-11; se midió con `NUMDECPRC = 4` ya puesto, no se probó con otro valor)
- Relaciones: `TARIFAVE.CODART` → `ARTICULO.CODART`; `TARIFAVE.TARIFA` → `TARIFAS.TARIFA` (inferidas por nombre; no se comprobó si hay FK declarada).
