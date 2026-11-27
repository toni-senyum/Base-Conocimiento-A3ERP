# Tabla: CARTERA (vencimientos/efectos) y su relación con facturas, agrupaciones y remesas

**Módulo A3ERP**: Tesorería
**Tipo de objeto**: TABLE (`BASE TABLE`, confirmado en `INFORMATION_SCHEMA.TABLES`). Tipos y nulabilidad de sus columnas **no recogidos** (solo se listaron nombres y valores).
**Descripción**: una fila por efecto (vencimiento) de cobro o pago. Una factura de venta genera uno o varios.

Verificado por SELECT en la BD demo `X_DEMO` de a3ERP (proyecto Drivers, 2026-11). Es una BD de demostración con pocos datos: los casos que no aparecen en ella (cobro parcial, impagado, confirming, remesa al descuento, varias agrupaciones por factura) **no están comprobados**.

## Columnas relevantes

| Columna | Notas |
|---|---|
| IDCARTERA | Clave de fila |
| COBPAG | `C` cobro (clientes) / `P` pago (proveedores): la tabla mezcla ambos |
| PROCEDE / PROCEDEID | Origen del efecto. `FV` = factura de venta (`PROCEDEID` = `CABEFACV.IDFACV`), `FC` = factura de compra, `AG` = efecto propio de una agrupación (`PROCEDEID` = `__AGRUPACIONES.NUMAGRU`). Había también filas con `PROCEDE` vacío |
| NUMCARTERA / NUMVEN | Nº de cartera de la factura (común a todos sus efectos) y nº de vencimiento dentro de ella |
| PAGADO | `T` cobrado, `F` pendiente, `D` devuelto |
| FECHA / FECHAEFECTIVA | Fecha de vencimiento / fecha de cobro |
| IMPORTE / IMPORTECOB | Importe del efecto / importe cobrado (ver gotchas) |
| PADREAGRU | → `__AGRUPACIONES.NUMAGRU` (el efecto está agrupado) |
| PADREREME / NUMREME | `PADREREME` → `__REMESAS.IDREMESA`; el nº visible de la remesa es `__REMESAS.NUMDOC` |
| PADREDEV / PADREDEV2 | Cadena de devoluciones (ver gotchas) |
| IMPDEVOL / FECHADEVOL / TIPODEVOL | Datos de la devolución |
| ESIMPAGADO / ESDUDOSOCOBRO | Marcas `T`/`F`. En la BD demo `ESIMPAGADO` era `F` en todos los efectos |
| DOCPAG / CODBAN | Documento de pago y banco |

## Relaciones

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| PROCEDEID (con `PROCEDE='FV'`) | `CABEFACV.IDFACV` | Inferida; enlazó todos los efectos de factura de la BD demo. Coincide con `CABEFACV.NUMCARTERA` (`IDFACV` = `NUMCARTERA` en todos ellos) |
| PADREAGRU | `__AGRUPACIONES.NUMAGRU` | Confirmada por las vistas de a3ERP (`EfectosClientes`, `Cobrados`) |
| PADREREME | `__REMESAS.IDREMESA` | Confirmada por las mismas vistas |

Vistas de a3ERP sobre `CARTERA` (su `CREATE`/definición se puede leer y sirve de especificación): `EfectosClientes` (cobros sin remesa ni tesorería), `Cobrados`, `Cobros`, `Agrupados`, `Agrupaciones`, `EnCartera`, `RemesablesC`, `RemesadosC`, `DudosoCobro`. P. ej. `Cobrados` = `COBPAG='C' AND PAGADO='T'` con `ANTICIPO` vacío o `C`, sin remesa (`ISNULL(NUMREME,0)=0`), sin agrupación (`ISNULL(PADREAGRU,0)=0`), `ISNULL(TESORERIA,'F')<>'T'` y `ISNULL(ESIMPAGADO,'F')='F'`.

## Notas / gotchas

- **Estado de cobro de una factura** = agregado de sus efectos; no hay un campo en `CABEFACV`.
- **Efectos agrupados**: el efecto original aparece con `PAGADO='T'` e `IMPORTECOB = IMPORTE` y sin `FECHAEFECTIVA`, aunque lo que se cobre sea la agrupación (observado en 5 efectos de 2 agrupaciones). Para el cobro real hay que mirar el efecto `PROCEDE='AG'`/la agrupación.
- **`IMPORTECOB` no equivale a «cobrado»**: en efectos devueltos (`D`) y agrupados vale lo mismo que `IMPORTE`.
- **Devoluciones**: el efecto original queda en `PAGADO='D'` y a3ERP crea efectos nuevos de la misma factura (con `PADREDEV` = `NUMCARTERA` del original y `PADREDEV2` = `NUMVEN` del devuelto, visto en una cadena). Por eso el nº de efectos de una factura crece con cada devolución. En la BD demo todos los efectos `D` tenían un sustituto.
- **`CARTERA.CODBAN` no es el banco de cobro**: en la BD demo coincidía con `__CLIENTES.CODBAN` (banco habitual del cliente) en todos los efectos de cobro de factura. El banco real de un cobro remesado sale de la remesa.
- **`IMPAGADO`** es un importe (distinto de 0 en efectos devueltos); la marca de impagado es `ESIMPAGADO`.
- Los borradores (`CABEFACV.BORRADOR=1`) no tenían efectos en la BD demo.
- No se encontraron columnas de auditoría (usuario/fecha de modificación) en `CARTERA` ni en `CABEFACV` (búsqueda por nombre de columna).
