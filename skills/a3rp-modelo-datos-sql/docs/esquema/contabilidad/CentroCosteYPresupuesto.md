# Tablas: CENTROSC, DEPARTAMENTOS, PRESUP, LINEPRES (+ vista Presupuestos)

**Módulo A3ERP**: Contabilidad
**Tipo de objeto**: TABLE (las cuatro) / VIEW (`Presupuestos`, pivota `LINEPRES` en `mes1`…`mes12`)
**Descripción**: Catálogo de centro de coste (`CENTROSC`), catálogo de departamentos
(`DEPARTAMENTOS`, no relacionado con centro de coste) y presupuesto contable por
cuenta × centros × ejercicio (`PRESUP`, total anual) con su desglose mensual (`LINEPRES`).

## Columnas relevantes

### CENTROSC

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| CENTROCOSTE | `varchar(8)` | No | Clave primaria. El centro por defecto "General" es `'       1'` (7 espacios + `1`) — es el valor que A3 guarda en los apuntes **sin centro**. Usar `LTRIM()`. |
| DESCCENTRO | `varchar(50)` | Sí | Descripción del centro. |
| APLINIVEL1, APLINIVEL2, APLINIVEL3 | `varchar(1)` | Sí | A cuál de las 3 dimensiones de centro de coste (`CENTROCOSTE`/`2`/`3` de `__ASIENTOS`) aplica este centro. Un único maestro para los 3 niveles; vistas `Centrosc_1`/`_2`/`_3` filtran por `APLINIVELn='T'`. **Sin jerarquía en el maestro** (ni columna padre ni fecha de alta): los 3 niveles son dimensiones independientes; si el cliente sigue una jerarquía N1→N2→N3 es solo por costumbre, comprobarla con las combinaciones reales de `__ASIENTOS`. |
| BLOQUEADO, OBSOLETO | `varchar(1)` | Sí | Flags T/F. |
| SEN_CODPERSONA | `varchar(8)` | Sí | **Campo de terceros**, no nativo de a3ERP — añadido vía diccionario `PERSONACC` (proyecto INTEMAN, ver skill `a3rp-diccionarios`). FK a `PERSONA.CODPER`: persona responsable del centro de coste. Solo existe en instalaciones donde se haya desplegado ese diccionario — no asumir su presencia sin comprobarlo (`sys.columns`/`INFORMATION_SCHEMA.COLUMNS`, no aparece en un `CENTROSC` de a3ERP "de fábrica"). |

### DEPARTAMENTOS

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| CODDEP | `varchar(8)` | No | Clave primaria. |
| NOMDEP | `varchar(50)` | Sí | Nombre del departamento. |

### PRESUP

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| CUENTA | `varchar(12)` | No | Cuenta presupuestada, a **cualquier nivel** del plan (verificado con cuentas de 4 dígitos, p. ej. `7010`) — se corresponde con `CUENTAS.CUENTA` por código, no por `IDCUENTA`. |
| EJERCICIO | `smallint` | No | Ejercicio del presupuesto. |
| EJERCICIOORI | `smallint` | Sí | — |
| CENTROCOSTE, CENTROCOSTE2, CENTROCOSTE3 | `varchar(8)` | Sí | FK reales a `CENTROSC`. Sin centro = `'       1'`, igual que en `__ASIENTOS`. |
| IMPORTE | `money` | Sí | Importe presupuestado **anual** (= suma de `LINEPRES.IMPORTE` de la misma clave). |
| CODMON, INCREMENTO, ORIIMPORTE, ORIPESO, TIPOCONT | — | Sí | No investigadas en detalle. |

### LINEPRES

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| CUENTA, EJERCICIO, CENTROCOSTE, CENTROCOSTE2, CENTROCOSTE3, TIPOCONT, CODMON | — | — | Misma clave que `PRESUP`. |
| MES | `int` | — | Mes 1–12 **natural**; la vista `Presupuestos` lo convierte a mes de ejercicio con `DATOSCON.MesIni`. |
| IMPORTE | `money` | — | Importe del mes. |
| PESO | — | — | Peso/porcentaje de reparto del mes (1,0 cuando se introduce importe directo). |

### Vista Presupuestos

Pivota `LINEPRES` a una fila por `ejercicio, cuenta, tipocont, centrocoste, centrocoste2,
centrocoste3` con columnas `mes1`…`mes12`, `total`, `por1`…`por12`, `totalpeso`. Ajusta ejercicio y
mes si el ejercicio no empieza en enero (`DATOSCON.MesIni`). Para Power BI es más cómodo leer
`LINEPRES` directamente (ya viene en formato largo, una fila por mes).

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| PRESUP.CENTROCOSTE / 2 / 3 | CENTROSC.CENTROCOSTE | FK reales (`FK_PRESUP_CENTROSC_CENTROCOSTE[2/3]`) |
| PRESUP.CODMON | MONEDAS.CODMON | FK real (`FK_PRESUP_MONEDAS_CODMON`) |
| PRESUP.TIPOCONT | TIPOSCON.TIPOCONT | FK real (`FK_PRESUP_TIPOSCON_TIPOCONT`) |
| PRESUP.CUENTA | CUENTAS.CUENTA | Deducida, no declarada — por código de cuenta a cualquier nivel (verificado con cuentas de 4 dígitos) |
| LINEPRES (CUENTA, EJERCICIO, CENTROCOSTE/2/3, TIPOCONT) | PRESUP (misma clave) | Deducida — cabecera anual / líneas mensuales (verificado: suma de meses = `PRESUP.IMPORTE`) |
| __ASIENTOS.CODDEL | DEPARTAMENTOS.CODDEP | **No confirmada** — nombres de columna distintos, sin FK declarada |

## Notas / gotchas

- **Verificado contra el cliente `EHEALTH` (E-Health Technical Solutions): la dimensión de centro
  de coste existe en el esquema (FK reales declaradas desde `__ASIENTOS`) pero no está poblada con
  más de un valor real.** `CENTROSC` tiene **1 sola fila** (`CENTROCOSTE='1'`,
  `DESCCENTRO='General'`); `__ASIENTOS.CENTROCOSTE` está poblado al 100% pero con ese único valor
  en todos los apuntes; `CENTROCOSTE2`/`CENTROCOSTE3` a 0% de relleno. **No asumir que esto es así
  en todos los clientes** — repetir la comprobación (`SELECT CENTROCOSTE, COUNT(*) ... GROUP BY`)
  antes de decidir si un dashboard puede desglosar por centro de coste.
- **`DEPARTAMENTOS` estaba vacía (0 filas)** en el cliente verificado — el campo `CODDEL` de
  `__ASIENTOS` (0% relleno) no se ha podido relacionar con ninguna tabla real por falta de datos.
- **`PRESUP` tenía 1 sola fila, con `IMPORTE = 0`** en el cliente verificado — residual, no
  presupuesto activo. El módulo de presupuesto existe en el esquema (tabla completa, FKs reales)
  pero no estaba en uso.
- **Alcance del módulo de presupuestos de A3** (verificado en una segunda instalación con datos de
  prueba): detalle **cuenta (cualquier nivel) × 3 niveles de centro × mes × ejercicio**, total
  anual en `PRESUP` y reparto mensual en `LINEPRES`. **No tiene campo de versión ni escenario**:
  una única versión por ejercicio/cuenta/centros. Si el proyecto necesita presupuesto + forecast +
  escenarios, A3 solo puede guardar una de ellas (p. ej. la versión aprobada); el resto necesita
  tabla/plantilla propia.
- **Signo**: comparar con el real usando el mismo criterio con que el usuario haya introducido el
  presupuesto — no verificado si A3 guarda los ingresos en positivo o en negativo (los datos de
  prueba vistos tenían ingresos en positivo, mientras que el real `DEBE-HABER` los da en negativo).
- Detalle completo de la investigación (incluida la pregunta explícita de alcance sobre si un
  dashboard v1 puede incluir desglose por centro de coste) en el repo del proyecto:
  `Dashboards/EBITDA/docs/esquema-contable-ebitda.md`.
- **Extensión de terceros (proyecto INTEMAN)**: `CENTROSC` recibió el campo `SEN_CODPERSONA` vía
  diccionario `PERSONACC` para poder asignar una persona responsable a cada centro de coste, con
  traspaso automático a la cabecera de pedidos de compra/venta (`CABEPEDC`/`CABEPEDV`, ver
  `comercial/PedidosCompraVenta.md`) mediante una DLL de eventos (skill `a3rp-dll`). Diseño completo
  en `Inteman\Diccionarios\Desarrollo\GestionCC\` del proyecto.
