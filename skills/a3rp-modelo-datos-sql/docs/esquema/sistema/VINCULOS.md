# Tabla: VINCULOS

**Módulo A3ERP**: Transversal (documentos vinculados entre registros)
**Tipo de objeto**: TABLE (`BASE TABLE`, confirmado contra `X_DEMO`, 2026-10)
**Descripción**: Vínculos entre registros de distintas tablas (lo que a3ERP muestra como documentos vinculados). Una fila = un vínculo padre → hijo.

Explorada en el proyecto GestionImnovilizado (vínculo inmovilizado → factura de compra).

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| A3DOC | `bit` | No | DEFAULT `0`. **Todos** los vínculos de X_DEMO (incluidos los no creados por la DLL) tienen `0`. GestionImnovilizado lo envía explícitamente a `0`. |
| IDENT | `varchar` | Sí | Clave del registro padre, **con el mismo padding que en su tabla** (para inmovilizado: `CODAMO` a 8 caracteres, `'      22'`). |
| IDENTHIJO | `int` / numérico | Sí | Clave del registro hijo (p. ej. `IDFACC` de la factura de compra). |
| TIPO | `varchar` | Sí | Tabla del padre. Valor visto: `Amortiza`. |
| TIPOHIJO | `varchar` | Sí | Tabla del hijo. Valores vistos: `CabeFacC`, `Fichero`, `CabeOfeC`. |
| DESCRIPCION | `varchar(255)` | Sí | Texto libre (la DLL pone "Factura de compra"). |
| FECHAALTA, FECHAMODIF | `datetime` | Sí | Pasar como `adDBTimeStamp` con `DateTime`, nunca como texto. |
| IDSITUACION | `int` | Sí | `NULL` en los vínculos de la DLL. |
| NOTAS, TAGS | `varchar` | Sí | |

`A3DOC` verificado en el esquema (`bit NOT NULL DEFAULT 0`); en el resto, el tipo es el que usa la
DLL al insertar y la nulabilidad no está comprobada.

## Combinaciones vistas en X_DEMO

| TIPO / TIPOHIJO | Origen |
|---|---|
| `Amortiza` / `CabeFacC` | GestionImnovilizado (activo → factura de compra) |
| `CabeAlbV` / `Fichero` | Otra extensión o a3ERP (certificados PDF) |
| `CabeAlbV` / `CabeOfeC` | Prueba manual |

## Notas / gotchas

- **No es una tabla maestro**: el objeto `Maestro` de a3ERPActiveX no la admite. Las altas desde una
  DLL se hacen con `INSERT` parametrizado (es la excepción a "escribir siempre vía API").
- Los triggers de `AMORTIZA` mantienen sus vínculos al cambiar o borrar el código del elemento.
- No hay ningún vínculo `Amortiza`/`CabeFacC` creado por a3ERP de forma nativa con el que comparar;
  el valor de `A3DOC` se ha dejado en 0 por coherencia con los datos existentes.
