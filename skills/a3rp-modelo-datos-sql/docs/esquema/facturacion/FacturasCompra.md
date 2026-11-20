# Tabla: CABEFACC (cabecera de factura de compra)

**Módulo A3ERP**: Compras / Facturación (en "Mantenimiento de programas externos": *Cabeceras de facturas de compra*)
**Tipo de objeto**: TABLE (confirmado contra `X_DEMO`, 2026-10)
**Descripción**: Cabecera de factura de compra. Una fila = una factura de proveedor. Sus líneas están en `LINEFACT` (la misma tabla que las de venta, ver `LineasFactura.md`).

Explorada parcialmente en el proyecto GestionImnovilizado (alta de inmovilizado desde factura de compra).

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| IDFACC | numérico | No | Clave. Es el `Parametro` que a3ERP pasa a un programa externo configurado en esta tabla. |
| SERIE | `varchar` | Sí | Viene con espacios: aplicar `Trim()`. Puede ser `NULL` (visto en X_DEMO). |
| NUMDOC | `money` | ? | Número de factura. ADODB lo devuelve como `Decimal`: `Convert.ToInt64(Convert.ToDecimal(...))` para mostrarlo sin decimales. |
| CODPRO | `varchar` | ? | Proveedor. |
| REFERENCIA | `varchar` | ? | Referencia (campo "Ref." de la ficha). |

Nulabilidad marcada `?` = no verificada en `INFORMATION_SCHEMA`.

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| IDFACC | LINEFACT.IDFACC | Líneas de la factura de compra |
| IDFACC | VINCULOS.IDENTHIJO (con `TIPOHIJO='CabeFacC'`) | Vínculos desde inmovilizado |

## Notas / gotchas

- Formato de número "legible" usado en GestionImnovilizado: `SERIE.Trim() + "/" + NUMDOC entero`
  (p. ej. `"2026/13"`). Con serie vacía queda `"/13"`.
- No se ha explorado el resto de columnas (totales, IVA, estado).
