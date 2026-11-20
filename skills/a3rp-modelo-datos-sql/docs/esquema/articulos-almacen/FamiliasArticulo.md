# Tabla: FAMILIAS (modelo Power BI: FamiliasArticulo)

**Módulo A3ERP**: Artículos/Almacén
**Tipo de objeto**: TABLE (`BASE TABLE`, confirmado en `INFORMATION_SCHEMA.TABLES` contra `X_DEMO`)
**Descripción**: Tabla **multi-propósito** de "familias" — no solo de artículo, discriminada por `FICHERO`. El modelo de A3ERP-PowerBI usa el subconjunto `FICHERO = 'DescArt'` (familia de **descuento de venta**) para `FamiliasArticulo`/`Ventas por Familia`. El subconjunto `FICHERO = 'Estadis'` es una familia **distinta** (estadística), usada por `ARTICULO.CODFAMEST` — ver `Articulos.md` y el gotcha "`DescArt` vs `Estadis`" más abajo. **Corrección (2026-09-14)**: una versión anterior de esta ficha decía por error que el modelo usaba `FICHERO='Estadis'` — era un error de transcripción, el `.tmdl` siempre usó `DescArt` correctamente.

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| ID | `int` | No | |
| CODFAM | `varchar(8)` | No | Clave (dentro de un `FICHERO` dado; no es única en toda la tabla sin ese filtro — hay dos subconjuntos relevantes aquí: `DescArt` y `Estadis`, ver Notas). |
| DESCFAM | `varchar(50)` | Sí | |
| FICHERO | `varchar(8)` | No | Discrimina el "tipo" de familia — ver gotcha. No forma parte de las columnas cargadas en el modelo, pero es la clave del filtro. |

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| CODFAM (`FICHERO='DescArt'`) | Articulos (ARTICULO.FAMARTDESCVEN) | **Deducida** — sin FK declarada (ver `Articulos.md`) |
| CODFAM (`FICHERO='Estadis'`) | Articulos (ARTICULO.CODFAMEST) | **Deducida** — sin FK declarada (ver `Articulos.md`) |

## Notas / gotchas

- **`FAMILIAS` es multi-propósito**: en `X_DEMO`, `FICHERO` tiene 5 valores distintos (`ComiArt`, `ComiCli`, `DescArt`, `DescCli`, `Estadis`) — no todas las filas son "familias de artículo para descuento de venta". El modelo de A3ERP-PowerBI (`FamiliasArticulo`) se queda con `FICHERO = 'DescArt'` (4 filas en crudo en `X_DEMO`: `CARR`, `OCIO`, `RECA`, `TEST`; Power Query añade además una fila sintética `SINFAM`/"Sin familia" — pendiente de confirmar por qué el recuento final documentado en el README del proyecto dice 3 familias reales y no 4, revisar si `TEST` se filtra en algún paso no revisado en esta ronda).
- **`FICHERO = 'Estadis'` es un subconjunto DISTINTO**, no usado por `FamiliasArticulo`/el dashboard — es la familia estadística real, referenciada desde `ARTICULO.CODFAMEST` (no desde `FAMARTDESCVEN`). Verificado empíricamente (2026-09-14, 83 artículos de `X_DEMO`): `FAMARTDESCVEN` encaja al 100% con `DescArt` y al 0% con `Estadis` — son dominios de valores completamente distintos, no intercambiables. Los 8 códigos `Estadis` originales (`AGUBR`, `AUT`, `BCN`, `CREK`, `INI`, `KAYAK`, `PESCA`, `RECR`) no tenían relación con este catálogo (parecían de otro negocio) y se sustituyeron por una clasificación estadística nueva coherente con el catálogo real (tienda de bicicletas/deporte): `BICI`, `CUADROS`, `RUEDAS`, `MECANICA`, `ACCESOR`, `MANTEN`, `ROPA`, `SERVIC`, `VARIOS`. Detalle completo (criterio artículo a artículo, SQL ejecutado) en `Integracion/00-Documentacion/propuesta-familias-estadisticas.md`.
  **⚠️ Esta escritura fue una excepción puntual autorizada por tratarse de `X_DEMO` (entorno de prueba, sin datos ni clientes reales) — no un patrón a repetir contra bases de datos de clientes reales**, donde esta skill sigue siendo estrictamente de solo lectura.
- Existe una **vista** `Familia_Estadis` (columnas `CODFAM`, `DESCFAM`) que parece ser justo un wrapper ya filtrado a `FICHERO = 'Estadis'` — confirmada como `VIEW` en `INFORMATION_SCHEMA.TABLES`. No se usa en el modelo actual de A3ERP-PowerBI (que filtra `FAMILIAS` directamente en Power Query), pero es la vía más directa si se necesita este mismo subconjunto en otro proyecto.
- La **jerarquía** de familias de artículo (no usada en el modelo actual, que trata las familias como plano) vive en `SIE_ESTRUCTURASFAMILIAARTICULO` (`BASE TABLE`, confirmada) como **lista de adyacencia**: columnas `ID`, `ID_FAMILIAPADRE`, `ID_FAMILIAHIJA` (una fila por relación padre-hijo) — no hay columnas `Nivel1`/`Nivel2`/... Si en el futuro se necesita una jerarquía de familias, hay que construirla a partir de esta tabla (recursión o `PATH`/`PATHITEM` en DAX), no asumir que ya viene aplanada.
