# Vista: Ape_Saldos_Con_Analitica

**Módulo A3ERP**: Contabilidad
**Tipo de objeto**: VIEW (nativa de A3ERP)
**Descripción**: Saldo contable **mensual** por cuenta de detalle × 3 niveles de centro de coste ×
tipo contable × diario, con descripciones de centros y agrupaciones de cuenta de 2, 3 y 4 dígitos
ya resueltas. Es la alternativa a `Ape_Saldos_PYG_Version_NPGC` cuando se necesita el desglose por
centro de coste (esa vista clasifica por línea oficial de PyG pero no es el camino para analítica).

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| Ejercicio, Mes | `int` | — | `DATEPART(yy/mm, FECHA)` — año y mes **naturales**. |
| CUENTA, DescripcionCuenta | `varchar` | — | Cuenta de detalle (9 dígitos) y descripción, plan `NPGC`. |
| **Saldo** | `money` | — | `SUM(HABER - DEBE)` **solo de apuntes `TIPAPU` `A` (apertura) y `N` (normal)**; `P` (regularización) y `T` (cierre) aportan 0. Signo: **ingresos positivos, gastos negativos** (opuesto a `DEBE-HABER`). |
| CodTipoContable, TipoContable | — | — | `TIPOSCON`. |
| CodigoDiario, Diario | — | — | `DIARIOS`. |
| CodAnalitica1/2/3 | `varchar(8)` | — | `CENTROCOSTE`/`2`/`3` del apunte — **con el padding original**: "sin centro" = `'       1'`. |
| Nivel1Analitica/2/3 | `varchar(50)` | Sí | Descripción del centro vía `Centrosc_1`/`_2`/`_3` (LEFT JOIN: `NULL` si el código no está marcado para ese nivel en `CENTROSC.APLINIVELn`). |
| CodGrupo, CodGrupo2/DescGrupo2, CodGrupo3/DescGrupo3, CodGrupo4/DescGrupo4 | `varchar` | — | Prefijos de 1, 2, 3 y 4 dígitos de la cuenta con su descripción (plan `NPGC`). |

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| CUENTA | CUENTAS.CUENTA (`PLACON='NPGC'`) | Resuelta dentro de la vista (INNER JOIN) |
| CodAnalitica1/2/3 | CENTROSC.CENTROCOSTE | Resuelta dentro de la vista (LEFT JOIN vía `Centrosc_n`) |

## Notas / gotchas

- **Definición** (`OBJECT_DEFINITION`): agrupa `APUNTES` por año, mes, cuenta, tipo contable,
  diario y los 3 centros; INNER JOIN a `CUENTAS` en los niveles de 2, 3 y 4 dígitos, a `TIPOSCON`
  y a `CAMBIOMO` (`FECHA >= CAMBIOMO.FECHAAPU`).
- ⚠️ **INNER JOINs a las cuentas de 2, 3 y 4 dígitos**: si en el plan del cliente falta una cuenta
  de agrupación (p. ej. no existe la de 4 dígitos para una subcuenta), esos apuntes **desaparecen
  en silencio** de la vista. Antes de usarla en un informe, cuadrar su total contra `__ASIENTOS`.
- Las descripciones de 4 dígitos pueden venir como texto genérico `"** Cuenta xxxx"` cuando el
  plan `NPGC` del cliente no tiene la cuenta de agrupación bien descrita — no fiarse de
  `DescGrupo4` para etiquetas de informe sin revisarlas.
- Mes/ejercicio naturales: si la empresa tiene un ejercicio que no empieza en enero, hay que
  recalcularlo (ver `DATOSCON.MesIni`, como hace la vista `Presupuestos`).
- Incluye el asiento de apertura (`A`) en el saldo: para cuentas de balance el saldo acumulado
  cuadra, para cuentas 6/7 no afecta (la apertura no las toca).
- Candidata como origen agregado para Power BI (una fila por mes en vez de por apunte). Estructura
  revisada solo por su definición; **rendimiento y cuadre contra `__ASIENTOS` no verificados aún**
  con datos — comprobarlos en el primer proyecto que la use y actualizar esta ficha.
