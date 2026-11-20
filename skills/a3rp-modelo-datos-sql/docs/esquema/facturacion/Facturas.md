# Tabla: CABEFACV (modelo Power BI: Facturas)

**Módulo A3ERP**: Facturación
**Tipo de objeto**: TABLE (`BASE TABLE`, confirmado en `INFORMATION_SCHEMA.TABLES` contra `X_DEMO`)
**Descripción**: Cabecera de factura de venta. Una fila = una factura (confirmada o borrador, rectificativa o no — el modelo filtra en el partition, ver gotchas).

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| IDFACV | `money` | No | Clave primaria del modelo. Tipo real `money`, no `int`/`bigint` — aterriza como `double` en Power BI; funcional para relaciones, pero candidato a forzar a entero en Power Query por limpieza. |
| SERIE | `varchar(8)` | Sí | |
| NUMDOC | `money` | No | Número de documento (no confundir con IDFACV, que es la clave interna). |
| FECHA | `datetime` | Sí | Fecha de la factura; base de la relación con `Calendario`. |
| FECHACONTABLE | `datetime` | Sí | Fecha contable, puede diferir de FECHA. |
| CODCLI | `varchar(8)` | No | FK real hacia `CLIENTES.CODCLI`. |
| CODREP | `varchar(8)` | Sí | FK real hacia `REPRESEN.CODREP` — representante de **esta factura** (no el por defecto del cliente, ver `Clientes.md`). |
| CODMON | `varchar(8)` | No | Moneda. |
| FORPAG | `varchar(8)` | No | Forma de pago. |
| DOCPAG | `varchar(8)` | No | |
| TARIFA | `varchar(8)` | Sí | |
| TOTDOC | `money` | Sí | Importe **con IVA**. Base de la medida `Total Facturado` = `SUM(TOTDOC)`. |
| BASE | `money` | Sí | Base imponible de cabecera (sin IVA). |
| TOTIVA | `money` | Sí | |
| TOTREC | `money` | Sí | Recargo de equivalencia. |
| BORRADOR | `bit` | Sí | Filtro del modelo: solo se cargan filas con `BORRADOR = false` (facturas confirmadas). |
| RECTIFICATIVA | `varchar(1)` | Sí | Filtro del modelo: solo se cargan filas con `RECTIFICATIVA = 'F'` (no rectificativas). |

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| CODCLI | Clientes (CLIENTES) | FK real (`FK_CABEFACV___CLIENTES_CODCLI`) |
| CODREP | Representantes (REPRESEN) | FK real (`FK_CABEFACV_REPRESEN_CODREP`) |
| FECHA | Calendario | Relación de modelo con tabla de fechas calculada (no es FK de SQL Server) |
| IDFACV | LineasFactura (LINEFACT.IDFACV) | Referenciada desde el lado "muchos" (ver `LineasFactura.md`) |

## Notas / gotchas

- El modelo de A3ERP-PowerBI filtra explícitamente en el partition: solo `BORRADOR = false AND RECTIFICATIVA = 'F'`. Sin este filtro, cualquier medida de importes sumaría borradores y facturas rectificativas — verificar siempre este filtro antes de reutilizar `CABEFACV` en otro proyecto.
- `IDFACV`, `NUMDOC`, `TOTDOC`, `BASE`, `TOTIVA`, `TOTREC` son todos tipo `money` en SQL Server, no `int`/`decimal` — Power Query los trae como `double`.
- No se ha verificado en este pase si `CABEFACV` guarda también otros tipos de documento aparte de factura de venta (a confirmar antes de reutilizar esta tabla para otro módulo).
