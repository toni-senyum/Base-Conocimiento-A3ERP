# Tabla: LINEFACT (modelo Power BI: LineasFactura)

**Módulo A3ERP**: Facturación
**Tipo de objeto**: TABLE (`BASE TABLE`, confirmado en `INFORMATION_SCHEMA.TABLES` contra una BD de pruebas)
**Descripción**: Líneas de factura (de venta **y** de compra, según el ERP — ver gotchas). Una fila = una línea de una factura.

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| IDLIN | `money` | No | Clave primaria del modelo. Mismo caso que `IDFACV`: `money` en SQL Server, `double` en Power BI. |
| IDFACV | `money` | Sí* | FK real hacia `CABEFACV.IDFACV`. `INFORMATION_SCHEMA` lo marca `NULL`able, pero en la práctica siempre viene relleno en una línea de venta — es la cabecera a la que pertenece. |
| NUMLINFAC | `int` | No | Número de línea dentro de la factura. |
| CODART | `varchar(15)` | No | **Corrección importante, ver gotcha** — no es `CHAR`. |
| DESCLIN | `varchar(100)` | Sí | Descripción libre de la línea (puede diferir de `ARTICULO.DESCART`). |
| UNIDADES | `float` | No | |
| PRECIO | `float` | Sí | Precio unitario. |
| BASE | `money` | Sí | Base imponible de la línea (sin IVA). Base de `Ventas por Familia (Base Imponible)` = `SUM(BASE)`. |
| TIPIVA | `varchar(8)` | No | |
| CODALM | `varchar(8)` | Sí | Almacén. |

### Columnas de líneas de compra (verificadas en una BD de pruebas, 2026-10, proyecto GestionImnovilizado)

| Columna | Notas |
|---|---|
| IDFACC | Cabecera de factura de **compra** (`CABEFACC.IDFACC`, ver `FacturasCompra.md`). Relleno en las líneas de compra en lugar de `IDFACV`. |
| CTACONL | Cuenta contable de la línea. En compras de inmovilizado debería ser 20x/21x/22x; con frecuencia viene 60x (compras), lo que hace que el activo herede una cuenta de gasto. |
| BASEMONEDA | Base de la línea en moneda; usada como valor de adquisición del inmovilizado. |
| FECHA | Fecha de la línea/factura. |
| CENTROCOSTE, CENTROCOSTE2, CENTROCOSTE3 | Analítica de la línea (en la ficha: Departamento / Centro 2 / Centro 3). |
| UBICACION | |
| IDLIN | Se guarda en `AMORTIZA.IDLIN` al dar de alta inmovilizado → permite saber si la línea ya tiene activo. |

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| IDFACV | Facturas (CABEFACV.IDFACV) | FK real (`FK_LINEFACT_CABEFACV_IDFACV`) |
| CODART | Articulos (ARTICULO.CODART) | FK real (`FK_LINEFACT_ARTICULO_CODART`) |
| IDFACC | Facturas de compra (CABEFACC.IDFACC) | Verificada con datos (una BD de pruebas) |
| IDLIN | Inmovilizado (AMORTIZA.IDLIN) | Inferida y verificada con datos (una BD de pruebas) |

## Notas / gotchas

- **`LINEFACT` mezcla líneas de venta y de compra** — confirmado en una BD de pruebas (2026-10): las de compra
  llevan `IDFACC`. Según el brief del proyecto — el modelo de A3ERP-PowerBI filtra explícitamente a líneas de venta (excluyendo las que referencian `IDFACC` en vez de `IDFACV`) para no mezclar sentidos. Verificar siempre este filtro antes de reutilizar la tabla.
- **`CODART` es `VARCHAR(15)`, NO `CHAR`** (corregido tras verificar contra una BD de pruebas — ver detalle completo en `Articulos.md`, mismo campo/misma causa). El efecto práctico (necesita `LTRIM`/`RTRIM`) sigue siendo el mismo, pero la causa real es que A3ERP graba los códigos puramente numéricos justificados a la derecha con espacios hasta ocupar los 15 caracteres — no que la columna sea de longitud fija.
- La medida `Ventas por Familia (Base Imponible)` excluye los artículos de código `52`/`53` ("Portes" en una BD de pruebas) — ver `Articulos.md` para la decisión sobre por qué no se usa `AFESTOCK` en su lugar.
