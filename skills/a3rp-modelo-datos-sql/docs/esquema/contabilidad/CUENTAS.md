# Tabla: CUENTAS

**Módulo A3ERP**: Contabilidad
**Tipo de objeto**: TABLE (`BASE TABLE`, confirmado en `INFORMATION_SCHEMA.TABLES` contra `EHEALTH`)
**Descripción**: Plan de cuentas contables. Una fila = una cuenta (a cualquier nivel de jerarquía:
grupo, subgrupo, cuenta, subcuenta de detalle).

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| IDCUENTA | `money` | No | Clave primaria real. Tipo `money` (mismo patrón que `IDFACV`/`IDLIN` en Facturación) — aterriza como `double` en Power BI. |
| CUENTA | `varchar(12)` | No | Código de cuenta contable (p. ej. `600`, `600000000`). **No es único por sí solo** — ver gotcha `PLACON`. Los dos primeros dígitos son el grupo PGC. |
| **PLACON** | `varchar(4)` | No | **`'PGC'` o `'NPGC'` — dos planes de cuentas en paralelo con los mismos códigos duplicados. Ver gotcha crítico.** |
| DESCCUE | `varchar(100)` | Sí | Descripción de la cuenta. |
| NIVEL | `tinyint` | Sí | Nivel de jerarquía: 1 (grupo) → 2 (subgrupo) → 3 (cuenta) → 5 (subcuenta de detalle). Sin nivel 4 en el cliente verificado. |
| DETALLE | `varchar(1)` | Sí | `'T'` = cuenta de detalle (la única donde se postea de verdad), `'F'` = cuenta de agrupación. |
| BLOQUEADO, OBSOLETO | `varchar(1)` | Sí | Flags T/F, no investigados en profundidad. |
| CODMON | `varchar(8)` | Sí | FK a `MONEDAS`. |
| BSA/BSAP/BSN/BSNP/BSS/BSSP/NBSA/NBSAP/NBSN/NBSNP/NBSP/NBSPP/PGA/PGAH/PGAN/PGN/PGNH/PGS/PGSH/NPGA/NPGN/NPGP | `varchar(10)` | Sí | Códigos de mapeo a las líneas oficiales de Balance de Situación (`BS*`) y Pérdidas y Ganancias (`PG*`). No descifrados columna a columna — la vista `Ape_Saldos_PYG_Version_NPGC` ya expone la clasificación de P&G resuelta, ver esa ficha. |
| ACTPAS | `varchar(1)` | Sí | Probablemente Activo/Pasivo — no verificado con datos. |

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| IDCUENTA | __ASIENTOS.IDCUENTA | FK real (`FK___ASIENTOS_CUENTAS_IDCUENTA`), referenciada desde el lado "muchos" |
| CODMON | MONEDAS | FK real (`FK_CUENTAS_MONEDAS_CODMON`) |

## Notas / gotchas

- **Dos planes de cuentas en paralelo (`PLACON`).** Verificado contra `EHEALTH` (E-Health Technical
  Solutions): 1.462 filas `PLACON='PGC'` y 4.092 filas `PLACON='NPGC'`, con los mismos códigos de
  cuenta duplicados en ambos planes (p. ej. `600` existe como fila distinta en cada uno). Verificado
  cruzando con los apuntes reales (`__ASIENTOS.IDCUENTA`): el 100% de los apuntes de este cliente
  usan `PLACON='NPGC'`, cero apuntes contra `'PGC'`. **Cualquier consulta debe filtrar
  `WHERE PLACON = 'NPGC'`** (o el plan que resulte activo en el cliente concreto — no asumir que
  será siempre `NPGC`, repetir esta verificación por cliente) para no duplicar filas al unir con
  `__ASIENTOS`/`APUNTES`.
- Solo las cuentas con `DETALLE='T'` reciben apuntes — en el cliente verificado, siempre coinciden
  con `NIVEL=5`. Las de `DETALLE='F'` son cuentas de agrupación (no se postea directamente ahí).
- Existe una vista, `APUNTES`, que ya trae `__ASIENTOS` unida con `CUENTAS` (añade `CUENTA`,
  `DESCCUE`, `PLACON`) — preferible a hacer el `JOIN` a mano, pero sigue haciendo falta filtrar
  `PLACON='NPGC'` explícitamente (la vista no lo hace por defecto).
- **Plan activo de la empresa: `DATOSCON.PLACON`** (una sola fila). Es la forma de no fijar `'NPGC'`
  en el código: leerlo de ahí y usar `'NPGC'` solo como valor de reserva si viniera vacío.
  Verificado en `X_DEMO` (2026-10, proyecto GestionImnovilizado): `DATOSCON.PLACON = 'NPGC'`; 1.509
  cuentas NPGC (471 de detalle) y 732 PGC; las 139 cuentas usadas en `__ASIENTOS` son todas NPGC.
- **Unicidad garantizada**: índice único `IDX_CUENTAS (PLACON, CUENTA)`. Dentro de un plan no hay
  códigos repetidos; los 627 repetidos de X_DEMO son el mismo código en los dos planes, a veces con
  descripción distinta (p. ej. `28130000`).
- **Estructura de niveles**: `DATOSCON.COMPOSICI1..5` (dígitos por nivel; X_DEMO: 2/1/1/0/4 → cuentas
  de detalle de 8 dígitos). En X_DEMO coinciden siempre `DETALLE='T'`, `NIVEL=5` y longitud 8, pero
  el indicador fiable entre empresas es **`DETALLE='T'`** (la longitud depende de la configuración).
- **Bloqueo**: columnas `BLOQUEADO` (+ `MOTIVOBLOQUEO`), `OBSOLETO` y `DESDEFECHA`/`HASTAFECHA`;
  normalmente `NULL` → filtrar con `ISNULL(BLOQUEADO,'F') <> 'T' AND ISNULL(OBSOLETO,'F') <> 'T'`.
- **Búsqueda por descripción sin acentos**: `DESCCUE` es `Modern_Spanish_CI_AS` (distingue acentos:
  `LIKE '%perdidas%'` no encuentra "Pérdidas"). Usar `DESCCUE COLLATE Modern_Spanish_CI_AI LIKE ?`.
- Selector de cuentas "de apunte" verificado (GestionImnovilizado v1.2.0):
  ```sql
  SELECT CUENTA, DESCCUE FROM CUENTAS
  WHERE PLACON = ? AND DETALLE = 'T'
    AND ISNULL(BLOQUEADO,'F') <> 'T' AND ISNULL(OBSOLETO,'F') <> 'T'
    AND (CUENTA LIKE ? OR DESCCUE COLLATE Modern_Spanish_CI_AI LIKE ?)
  ORDER BY CUENTA
  ```
- Las funciones de apunte de a3ERPActiveX (`AApunte`, `AApunteNax`) reciben el **código** de cuenta,
  no `IDCUENTA`; a3ERP lo resuelve contra el plan activo.
- Cuentas de pérdidas por baja de inmovilizado (PGC): `670` intangible, `671` material, `672`
  inversiones inmobiliarias. En X_DEMO solo existe la subcuenta `67100000`.
- 🔴 **Borrar una ficha de cliente o proveedor en a3ERP borra también sus cuentas.** Verificado en
  OUTDOOR (proyecto RocRoi, 2026-10), en un ensayo local y en producción, con 19 fichas:
  - a3ERP **no pregunta nada** sobre las cuentas. Borra la ficha, su organización y sus direcciones,
    y todas sus **cuentas propias** (las que no usa ninguna otra ficha) **sin apuntes**, en los dos
    planes: la 430/400/410, la 431/401 de efectos, la 4311 de descuento y la 438/407 de anticipos.
    En el caso real fueron 121 cuentas (68 NPGC + 53 PGC), no las 38 principales que se esperaban.
  - Se **conservan** las cuentas compartidas (p. ej. `43150000`, `43600000`, `40100000`, `40700000`),
    aunque no tengan apuntes, y la cuenta que tiene apuntes (con sus apuntes intactos).
  - Si se vuelve a dar de alta el mismo código (por in&out), se reutiliza la cuenta que se conservó:
    no se crea una segunda ni se tocan sus apuntes.
  - Antes de borrar: listar las cuentas que referencia la ficha (campos de cuenta de `__CLIENTES` /
    `__PROVEED`, ver `clientes/Clientes.md` y `compras/Proveedores.md`) y comprobar que no tienen
    apuntes ni cartera. Después: comprobar que no falta ninguna cuenta que referencie una ficha que
    se queda. El recuento total de `CUENTAS` solo es informativo.
- La cuenta 438 de anticipos de los clientes solo existía en **NPGC**; el resto de cuentas propias,
  en los dos planes (OUTDOOR). Por eso el número de cuentas por ficha puede no ser par.
- **`CARTERA` no tiene columna de cuenta.** Para saber si una cuenta de cliente o proveedor tiene
  efectos hay que filtrar por `CODCLI` / `CODPRO` y por la cuenta de descuento `CTADES` (OUTDOOR,
  2026-10).
- Detalle completo del análisis para EBITDA (grupos PGC relevantes, magnitudes reales verificadas)
  en el repo del proyecto: `Dashboards/EBITDA/docs/esquema-contable-ebitda.md`.
