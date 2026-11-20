# Tabla: AMORTIZA (inmovilizado)

**Módulo A3ERP**: Contabilidad / Inmovilizado (ficha "Elemento de inmovilizado"; en "Mantenimiento de programas externos" la tabla aparece como *Amortizaciones*)
**Tipo de objeto**: TABLE (`BASE TABLE`, confirmado contra `X_DEMO`, 2026-10)
**Descripción**: Elementos de inmovilizado (activos fijos). Una fila = un elemento, con sus datos de adquisición, amortización acumulada y, si procede, su baja.

Explorada en el proyecto GestionImnovilizado (DLL de alta desde factura de compra y baja con asiento).

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| CODAMO | `varchar(8)` | No | **Clave primaria** (`PK_AMORTIZA`, clustered). Los códigos numéricos se guardan **justificados a la derecha con espacios** hasta 8 caracteres (`'      26'`). Conviven con códigos alfanuméricos (en X_DEMO, `P100`–`P107`). Comparar con `LTRIM(CODAMO)` o rellenar el parámetro con `PadLeft(8)`. |
| IDAMO | `money` | No | Identificador interno, índice único. **No** es `IDENTITY`: lo asigna a3ERP desde la tabla de contadores `IDENTIFICADORES`. |
| NOMAMO | `varchar` | Sí | Descripción del elemento. |
| CANTIDAD | numérico | Sí | Unidades. |
| CTAINMOVILIZADO | `varchar` | Sí | Cuenta del activo (debería ser grupo 20/21/22). La **baja la abona**. Tiene CHECK de integridad contra cuentas. |
| CTAAMORT | `varchar` | Sí | Cuenta de amortización acumulada (28x). Si no se informa, el objeto `Maestro` pone un valor por defecto (X_DEMO: `28190000`). CHECK contra cuentas. |
| CTAGASTOS | `varchar` | Sí | Cuenta de gasto de amortización (68x). CHECK contra cuentas. No usada por la DLL. |
| CENTROCOSTE, CENTROCOSTE2, CENTROCOSTE3 | `varchar(8)` | Sí | Analítica del elemento. CHECK contra `CENTROSC`. |
| UBICACION | `varchar` | Sí | |
| FECHAFAC | fecha | Sí | Fecha de la factura de compra. |
| TOTAMO | `money` | Sí | Valor de adquisición. |
| TOTACUMF | `money` | Sí | Amortización acumulada (la que usa la DLL para el asiento de baja). No verificado si existe una variante contable/fiscal distinta. |
| IDLIN | `money` | Sí | **Línea de factura de compra de origen** (`LINEFACT.IDLIN`). Sirve para detectar si una línea ya se dio de alta como inmovilizado. |
| NUMDOC | `varchar` | Sí | En las altas de la DLL: `SERIE/NUMDOC` de la factura (`"A/12345"`), no el `NUMDOC` numérico. |
| CODPRO | `varchar(8)` | Sí | Proveedor. |
| REFERENCIA | `varchar` | Sí | Referencia de la factura de compra. |
| CANCELADA | `varchar(1)` | Sí | `'T'` = dado de baja, `'F'` = activo. |
| FECHABAJA | `datetime` | Sí | **`31/12/9999` = sin baja** (valor que pone a3ERP), no `NULL`. Sin DEFAULT ni regla. Si aparece `NULL` en un elemento cancelado, es casi seguro una escritura defectuosa (ver gotcha). |
| VALORVENTA | `money` | Sí | Precio de venta en la baja. Informativo: el asiento de venta va por facturación. `NULL` en elementos sin baja. |

Tipo y nulabilidad verificados en `INFORMATION_SCHEMA` solo para `CODAMO`, `IDAMO` y `FECHABAJA`;
en el resto, el tipo es el observado al leer/escribir desde la DLL y la nulabilidad no está
comprobada.

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| IDLIN | LINEFACT.IDLIN (línea de factura de **compra**) | Inferida y verificada con datos |
| CODAMO | VINCULOS.IDENT (con `TIPO='Amortiza'`) | Mantenida por triggers (ver abajo) |
| CTAINMOVILIZADO / CTAAMORT / CTAGASTOS | CUENTAS.CUENTA (del plan activo) | CHECK de integridad |
| CENTROCOSTE / 2 / 3 | CENTROSC.CENTROCOSTE | CHECK de integridad |

## Notas / gotchas

- **4 triggers AFTER** (`TGR_AMORTIZA_VINCULOS_*`): al modificar `CODAMO` o borrar un elemento,
  actualizan o borran sus filas de `VINCULOS`. Ninguno toca `FECHABAJA` ni `CANCELADA`. Borrar un
  elemento desde a3ERP **no deja vínculos huérfanos**.
- **Códigos reutilizables**: si se borra el último elemento, el siguiente alta reutiliza el código.
- **El siguiente código numérico** = `MAX(TRY_CAST(CODAMO AS INT)) + 1` (no `ISNUMERIC`, que acepta
  `'1E5'`, `'-'`…). Coincide con lo que propone la ficha (`Maestro.NuevoCodigoNum`).
- **Fecha de inicio de amortización**: en altas desde la DLL, a3ERP la pone al día siguiente del
  alta, no a la fecha de la factura.
- **FECHABAJA a NULL en todas las bajas antiguas** de GestionImnovilizado (hasta v1.1.0): la DLL
  enviaba el parámetro como `DEFAULT` (`Command.Execute` con `null`, ver `a3rp-api-com`). En
  cualquier instalación que usara una versión anterior, revisar
  `WHERE CANCELADA='T' AND FECHABAJA IS NULL`.
- Para escribir: alta con el objeto `Maestro` (`a3rp-api-com`). La baja de la DLL actualiza
  `CANCELADA`, `FECHABAJA`, `VALORVENTA` con un `UPDATE` parametrizado.
