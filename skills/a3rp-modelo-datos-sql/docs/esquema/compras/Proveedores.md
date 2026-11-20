# Tabla: __PROVEED (proveedores y acreedores)

**Módulo A3ERP**: Compras
**Tipo de objeto**: tabla base (se ha consultado así en OUTDOOR). **No verificado** en `INFORMATION_SCHEMA.TABLES`, ni qué vista la expone.
**Descripción**: Ficha de proveedor (cuentas 400) o acreedor (cuentas 410).

Verificado por SQL en OUTDOOR (proyecto RocRoi, 2026-10). Tipos y nulabilidad **no verificados** en `INFORMATION_SCHEMA.COLUMNS`.

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| CODPRO | — | — | Código. Los acreedores pueden tener códigos alfanuméricos (p. ej. `A83`). |
| CUENTA | — | — | Cuenta del proveedor (`400xxxxx`) o del acreedor (`410xxxxx`). |
| CTALETRA | — | — | Efectos: `401xxxxx` propia en proveedores 400; cuenta **compartida** (`40100000`) en acreedores 410. |
| CTAANTC | — | — | Anticipos: `407xxxxx` propia en proveedores 400; **compartida** (`40700000`) en acreedores 410. |
| NOMPRO | — | — | Nombre de la **Organización**. |
| NOMFISCAL | — | — | **Razón social**. |
| RAZON | — | — | **Nombre comercial** (ver `clientes/Clientes.md`). |
| NIFPRO | — | — | NIF. En proveedores UE, el NIF-IVA **sin** prefijo del país (igual que `NIFCLI`). |

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| CUENTA, CTALETRA, CTAANTC | CUENTAS.CUENTA (en los dos planes, `PLACON`) | Inferida por valor; no verificada como FK |
| CODPRO | CARTERA.CODPRO | Inferida; `CARTERA` no tiene columna de cuenta |

## Notas / gotchas

- Cuentas propias por ficha (OUTDOOR): proveedores 400 → 3 (400, 401, 407) en NPGC y en PGC; acreedores 410 → solo la 410, en los dos planes.
- 🔴 **Borrar la ficha borra sus cuentas propias sin apuntes** y conserva las compartidas y las que tienen apuntes: ver `contabilidad/CUENTAS.md`.
- `__ORGANIZACION` no tiene campos de cuenta.
