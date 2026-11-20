# Tabla: __ASIENTOS (vista relacionada: APUNTES)

**Módulo A3ERP**: Contabilidad
**Tipo de objeto**: TABLE (`__ASIENTOS`, `BASE TABLE`) / VIEW (`APUNTES`, misma tabla + `CUENTAS` ya unida)
**Descripción**: Libro diario completo. Una fila = un **apunte** (línea de un asiento) — **no existe
una tabla de cabecera de asiento separada**; varios apuntes con el mismo `NUMASIENTO` forman un
asiento completo (verificado: `DEBE` y `HABER` cuadran exactos por asiento, partida doble).

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| IDAPUNTE | `money` | No | Clave primaria real del apunte. |
| NUMASIENTO | `money` | Sí | Clave de **agrupación** de apuntes en el mismo asiento — no es FK a otra tabla, es una secuencia propia de esta misma tabla. |
| NUMAPUNTE | `money` | No | **Identificador del asiento para la API COM**: es lo que devuelve `Asiento.Anade()` y lo que espera `Opcion("EditAsiento")` en el parámetro `NumApunte`. Verificado en X_DEMO (2026-10, GestionImnovilizado): todos los apuntes de un asiento creado con `Asiento` comparten el mismo `NUMAPUNTE` (p. ej. 138754 con sus 3 apuntes). Relación exacta con `NUMASIENTO` no investigada. |
| NUMLIN | `int` | No | Línea dentro del asiento. |
| FECHA | `datetime` | Sí | Fecha del apunte — eje temporal; el ejercicio fiscal se deriva de `YEAR(FECHA)` (no existe tabla de ejercicios real, ver `PERIODOS`). |
| IDCUENTA | `money` | No | FK real a `CUENTAS.IDCUENTA` — ver `CUENTAS.md`, recordar filtrar `PLACON='NPGC'` (o el plan activo del cliente). |
| DEBE, HABER | `money` | Sí | Importes de partida doble — no hay una única columna "importe con signo" a nivel de apunte. |
| DEBEMON, HABERMON | `money` | Sí | Mismo importe en moneda del apunte (`CODMON`) si difiere del euro. |
| CENTROCOSTE, CENTROCOSTE2, CENTROCOSTE3 | `varchar(8)` | Sí | Tres niveles de centro de coste — FK reales a `CENTROSC`. **La imputación analítica contable va aquí, en la propia línea de apunte** (no hay tabla de reparto aparte). "Sin centro" = `'       1'` (con padding), no `NULL` — ver gotcha. |
| CODDEL | `varchar(8)` | Sí | Sin relación confirmada con `DEPARTAMENTOS` (nombres de columna distintos: `CODDEL` vs `CODDEP`, sin FK declarada). 0% relleno en el cliente verificado — no se ha podido confirmar con datos. |
| DIARIO | `varchar(8)` | Sí | FK real a `DIARIOS` (`DIARIO`/`DESCDIA`). |
| CODCONCE | `varchar(8)` | Sí | FK real a `CONCEPTO` (`CODCONCE`/`DESCCON`). |
| GRUPO | `int` | Sí | ⚠️ **NO es el grupo PGC** — ver gotcha. |
| PROCEDE | `varchar(2)` | Sí | Origen del apunte: `FC`/`FV` (factura compra/venta), `CR` (cobro), `PA` (pago), `AM` (amortización automática), u otros/vacío (mayoría en el cliente verificado — entrada manual). |
| TIPOCONT | `varchar(3)` | No | FK real a `TIPOSCON`. |
| TIPAPU | `varchar` | Sí | **Tipo de apunte**: `A` apertura (1/1), `N` normal, `P` regularización de PyG (31/12, salda grupos 6/7 contra 129), `T` cierre (31/12). Ver gotcha. |
| TEXTO, DESCAPU | `text` / `varchar(100)` | Sí | Descripción libre del apunte. |

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| IDCUENTA | CUENTAS.IDCUENTA | FK real (`FK___ASIENTOS_CUENTAS_IDCUENTA`) |
| CENTROCOSTE / 2 / 3 | CENTROSC.CENTROCOSTE | FK reales (`FK___ASIENTOS_CENTROSC_CENTROCOSTE[2/3]`) |
| DIARIO | DIARIOS.DIARIO | FK real (`FK___ASIENTOS_DIARIOS_DIARIO`) |
| CODCONCE | CONCEPTO.CODCONCE | FK real (`FK___ASIENTOS_CONCEPTO_CODCONCE`) |
| CODMON | MONEDAS.CODMON | FK real (`FK___ASIENTOS_MONEDAS_CODMON`) |
| TIPOCONT | TIPOSCON.TIPOCONT | FK real (`FK___ASIENTOS_TIPOSCON_TIPOCONT`) |
| CODDEL | DEPARTAMENTOS.CODDEP (?) | **No confirmada** — sin FK declarada, columna 0% rellena en el cliente verificado |

## Notas / gotchas

- **`GRUPO` no es el grupo PGC.** Verificado con datos: 98,6% de los apuntes tienen `GRUPO=0`, el
  resto se reparte en valores hasta 19+ con recuentos muy bajos — no encaja con ningún reparto por
  grupo contable real (el grupo 7 de ingresos tendría muchos más apuntes que un `GRUPO` alto con 1
  fila). Parece un campo interno sin relación con la clasificación contable. **Para el grupo PGC de
  un apunte, usar siempre `LEFT(CUENTA,2)` vía `IDCUENTA → CUENTAS`** (o la vista `APUNTES`), nunca
  esta columna.
- **`APUNTES`** (VIEW) tiene todas las columnas de `__ASIENTOS` más `CUENTA`, `DESCCUE`, `PLACON` ya
  resueltas — preferible a unir `__ASIENTOS` con `CUENTAS` a mano, pero sigue haciendo falta filtrar
  `PLACON='NPGC'` explícitamente.
- No existe una tabla de "ejercicios"/años fiscales real y poblada en el esquema — el único
  candidato por nombre (`PERIODOS`) tiene una sola fila de configuración por defecto sin usar. El
  ejercicio se deriva de `YEAR(FECHA)`.
- **`TIPAPU` identifica los asientos especiales** (verificado en una instalación con 16 ejercicios:
  un único asiento `A` el 1/1, un `P` y un `T` el 31/12 de cada ejercicio cerrado; el resto `N`).
  **Para cuenta de resultados filtrar `TIPAPU = 'N'`** (o al menos excluir `P` y `T`): el asiento
  `P` salda todas las cuentas 6/7 a cero, así que sin excluirlo cualquier ejercicio cerrado da
  resultado 0. Comprobado: `SUM(DEBE-HABER)` de grupos 6/7 con `TIPAPU='N'` = importe exacto
  llevado a la 129 en el asiento `P`. Un ejercicio abierto todavía no tiene `P` ni `T`.
  ⚠️ La vista nativa `Apuntes_Resultado` (cuentas `>= '6'` y `< '8'`) **no filtra `TIPAPU`**.
- **Analítica en la línea, no en tabla aparte.** Cada apunte lleva sus 3 centros; un gasto
  repartido entre varios centros se guarda como **varias líneas de apunte** (verificado: no hay
  `(NUMASIENTO, NUMLIN)` duplicados). Por eso aparecen importes con medio céntimo (`money` con 4
  decimales) — las exportaciones Excel de A3 redondean cada línea a 2 decimales, puede haber
  diferencias de 0,01 € al cuadrar.
- **"Sin centro" es `'       1'`** (7 espacios + `1`, centro "General" por defecto de
  `DATOSCON.CENTROCOSTE`/`2`/`3`), no `NULL` ni vacío. Usar `LTRIM()` al comparar/agrupar
  (`LTRIM(CENTROCOSTE) = '1'` → sin imputar). El padding está en el dato (`varchar`, no `CHAR`),
  así que `'1'` a secas no hace match.
- `PROCEDE='AM'` (amortización automática) verificado que cae exactamente en pareja grupo `68`
  (gasto) / grupo `28` (amortización acumulada, contrapartida de balance) — pero no todo apunte del
  grupo `68` viene necesariamente de `PROCEDE='AM'` (podría haber amortización manual); para
  clasificar por PGC, filtrar siempre por cuenta, no por `PROCEDE`.
- **Centros de coste por defecto según la empresa.** En EHEALTH "sin centro" es `'       1'`; en
  X_DEMO, los apuntes creados con `Asiento.AApunte` (sin analítica explícita) salen con `BCN/1/PB`.
  Vienen de `DATOSCON.CENTROCOSTE/2/3` de cada empresa: no asumir un valor fijo.
- Para localizar los apuntes creados por una DLL: `NUMAPUNTE > <máximo anterior>` y un patrón en
  `DESCAPU` (p. ej. `'%inmovilizado ' + código + ' %'`). Ojo con el padding de los códigos dentro del
  texto si la DLL no los recorta.
- **`NUMASIENTO` no reinicia por ejercicio** en las BD vistas: en JALLUCA (2024-2025) la secuencia
  continúa de un año al siguiente (2024: apertura `A` = 1 … cierre `T` = 780; 2025: `A` = 782 …), con
  algún hueco, y no hay asiento 0 (verificado por SQL, proyecto RocRoi, 2026-11). No asumir que cada
  ejercicio empieza en 1.
- 🔴 **in&out de APUNTES renumera los asientos**: no conserva el `NUMASIENTO` del `.xls` ni sus
  huecos; los numera de forma consecutiva y encadena un ejercicio tras otro (UR_RAFTING: el `.xls` se
  preparó con 1..3245 y 3246..5734; salió 1..3227 y 3229..5716). El contenido, los saldos y los
  recuentos por `TIPAPU` coinciden (38 de 44 comprobaciones OK; los 6 KO eran solo la numeración y
  un exceso de cuentas). Validar por contenido/saldos, nunca emparejando por `NUMASIENTO`
  (verificado por SQL, proyecto RocRoi, 2026-11).
- `FECHACIERRE` vale `1900-01-01` cuando no hay cierre fijado, tanto en `DATOSCON` como en
  `DATOSCONFIG` (verificado en JALLUCA, UR_RAFTING y PRELUDE, 2026-11).
- Existe una vista nativa de A3ERP, `Ape_Saldos_PYG_Version_NPGC`, que agrega estos apuntes por
  cuenta/mes/ejercicio y los clasifica ya según el modelo oficial abreviado de Pérdidas y Ganancias
  español — ver ficha propia. Suele ser preferible a agregar `__ASIENTOS`/`APUNTES` a mano para
  cualquier informe de P&G. Si se necesita el desglose por centro de coste, ver
  `Ape_Saldos_Con_Analitica` (ficha propia).
- Detalle completo del análisis para EBITDA (fórmula, verificación con datos reales, magnitudes) en
  el repo del proyecto: `Dashboards/EBITDA/docs/esquema-contable-ebitda.md`.
