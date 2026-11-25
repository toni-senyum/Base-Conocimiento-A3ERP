# Tabla: DATOSCONFIG (datos generales de la empresa) — modelos de impresión y relacionadas

**Módulo A3ERP**: Configuración / Datos generales
**Tipo de objeto**: TABLE (no comprobado en `INFORMATION_SCHEMA`; tipos y nulabilidad sin comprobar)
**Descripción**: configuración general de la empresa. Aquí solo se documentan los campos de modelos de impresión y los relacionados con el envío de documentos y Verifactu.

Fuentes: a3ERP v15 (VM de pruebas, X_DEMO, 2026-11; proyecto CertificadosCalidad) y código en producción de `ExportacionFacturasPDF` (2026-07).

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| NOMMODALB, NOMMODFAC, NOMMODFACSIF, … | ? | ? | Modelo por defecto de empresa ("datos generales") de cada documento. Hay unos 40 `NOMMOD*`. Mismo formato que en `__CLIENTES` (`LSTIMPRALBV.000`). Verificado en la VM: al marcar un modelo por defecto en datos generales se escribe aquí (y no en `Listados.INI`) |
| TIPOCONT | ? | ? | Según `ExportacionFacturasPDF`: puede haber **una fila por tipo contable**; el modelo se busca por el `TIPOCONT` del documento y, si no, se toma la primera fila |
| IDMULTIEMP | ? | ? | Según `ExportacionFacturasPDF`: fila por multiempresa, usada cuando el cliente tiene `_DATGENMULT_` (vía `TIPOSCON.IDMULTIEMP`) |
| ENVIOSMAILFACTUSARCLIFAC | ? | ? | **No verificado** (solo por el nombre): opción de enviar las facturas al cliente de facturación |

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| TIPOCONT | `TIPOSCON.TIPOCONT`, `CABEFACV.TIPOCONT` | Inferida (código en producción) |
| IDMULTIEMP | `TIPOSCON.IDMULTIEMP` | Inferida (código en producción) |

## Tablas relacionadas usadas en el mismo contexto

- **`__LAF_DATOSCONFIG`** (Verifactu, v15): `ACTIVADO`, `ACTIVADOVERIFACTU`, `FECHAACTIVACION`, `FECHAACTIVACIONVERIFACTU`, `FECHADESACTIVACIONVERIFACTU`, `EVENTOPENDIENTE`. `ExportacionFacturasPDF` considera Verifactu activo con `ACTIVADO = 1` (ignora las fechas). Solo existe en v15.
- **`SERIES`**: `FACTURABORRADOR` (la serie es de facturas borrador; `ExportacionFacturasPDF` no las exporta) y `NOAPLICA` (la serie no aplica Verifactu → modelo de factura normal).

## Notas / gotchas

- En X_DEMO todos los `NOMMOD*` estaban vacíos (modelo original).
- Con `Listado` (ActiveX) estos valores **no se aplican solos**: hay que leerlos y pasarlos en `Modelo` (ver `a3rp-api-com`).
