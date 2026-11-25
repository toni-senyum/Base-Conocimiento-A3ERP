# Tabla: DATOSCONFIG (datos generales de la empresa) — modelos de impresión y relacionadas

**Módulo A3ERP**: Configuración / Datos generales
**Tipo de objeto**: TABLE (no comprobado en `INFORMATION_SCHEMA`; tipos y nulabilidad sin comprobar)
**Descripción**: configuración general de la empresa. Aquí solo se documentan los campos de modelos de impresión y los relacionados con el envío de documentos y Verifactu.

Fuentes: a3ERP v15 (una BD de pruebas v15; verificado en proyecto CertificadosCalidad, 2026-11) y código en producción (verificado en proyecto ExportacionFacturasPDF, 2026-07).

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| NOMMODALB, NOMMODFAC, NOMMODFACSIF, … | ? | ? | Modelo por defecto de empresa ("datos generales") de cada documento. Hay unos 40 `NOMMOD*`. Mismo formato que en `__CLIENTES` (`LSTIMPRALBV.000`). Al marcar un modelo por defecto en datos generales se escribe aquí y no en `Listados.INI` (verificado en una sola prueba) |
| TIPOCONT | ? | ? | Según código en producción: puede haber **una fila por tipo contable**; el modelo se busca por el `TIPOCONT` del documento y, si no, se toma la primera fila |
| IDMULTIEMP | ? | ? | Según código en producción: fila por multiempresa, usada cuando el cliente tiene `_DATGENMULT_` (vía `TIPOSCON.IDMULTIEMP`) |

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| TIPOCONT | `TIPOSCON.TIPOCONT`, `CABEFACV.TIPOCONT` | Inferida (código en producción) |
| IDMULTIEMP | `TIPOSCON.IDMULTIEMP` | Inferida (código en producción) |

## Tablas relacionadas usadas en el mismo contexto

- **`__LAF_DATOSCONFIG`** (Verifactu, v15): `ACTIVADO`, `ACTIVADOVERIFACTU`, `FECHAACTIVACION`, `FECHAACTIVACIONVERIFACTU`, `FECHADESACTIVACIONVERIFACTU`, `EVENTOPENDIENTE`. `ExportacionFacturasPDF` considera Verifactu activo con `ACTIVADO = 1` (ignora las fechas). Solo existe en v15.
- **`SERIES`**: `FACTURABORRADOR` (la serie es de facturas borrador; el código en producción no las exporta) y `NOAPLICA` (la serie no aplica Verifactu → modelo de factura normal).

## Notas / gotchas

- En la BD de pruebas v15 todos los `NOMMOD*` estaban vacíos (modelo original).
- Con `Listado` (ActiveX) estos valores **no se aplican solos**: hay que leerlos y pasarlos en `Modelo` (ver `a3rp-api-com`).

## Pendiente de verificar

- `ENVIOSMAILFACTUSARCLIFAC`: opción de empresa que, por el nombre, haría que las facturas se envíen al cliente de facturación. **No verificado** (solo por el nombre); tipo y nulabilidad sin comprobar.
