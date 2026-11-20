# Vista: Ape_Saldos_PYG_Version_NPGC (hermana: Ape_Saldos_Balance_Version_NPGC)

**Módulo A3ERP**: Contabilidad
**Tipo de objeto**: VIEW (confirmado en `INFORMATION_SCHEMA.TABLES` contra `EHEALTH`)
**Descripción**: Saldos contables agregados por cuenta/mes/ejercicio, **ya clasificados según el
modelo oficial abreviado de Pérdidas y Ganancias español** (formato AECA/ICAC). Nativa de A3ERP —
no hay que reconstruir la clasificación P&G a mano a partir de prefijos de cuenta.

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| CODIGO | `varchar` | — | Código de línea oficial del modelo PYG abreviado (p. ej. `A.01.1`, `A.04.1`, `A.08.0`). |
| Titulo | `varchar` | — | Descripción de la línea oficial (p. ej. "8. Amortización del inmovilizado."). |
| CUENTA | `varchar` | — | Cuenta contable de detalle (plan `NPGC`). |
| Ejercicio | `int` | — | Año — ya calculado, no hace falta derivarlo de `__ASIENTOS.FECHA`. |
| Mes | `int` | — | Mes — granularidad mensual. |
| **Saldo** | `money` | — | Importe del período, **ya con el signo correcto de P&G** (ingresos en positivo, gastos en negativo — verificado con datos reales). |
| CodGrupo, CodGrupo2/DescGrupo2, CodGrupo3/DescGrupo3, CodGrupo4/DescGrupo4 | `varchar` | — | Jerarquía de grupo/subgrupo/cuenta/subcuenta — redundante con `CUENTAS` pero ya resuelta. |
| CodAnalitica1/Nivel1Analitica, CodAnalitica2/Nivel2Analitica, CodAnalitica3/Nivel3Analitica | `varchar` | — | Corresponden a los 3 niveles de centro de coste (`CENTROCOSTE`/`2`/`3` de `__ASIENTOS`). |

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| CUENTA | CUENTAS.CUENTA (plan NPGC) | Deducida — la vista ya trae el código de cuenta resuelto, no hace falta unir de nuevo |

## Notas / gotchas

- **Cobertura verificada** (cliente `EHEALTH`): 2019–2026 (8 ejercicios, mismo rango que
  `__ASIENTOS`), 5.282 filas.
- **`Saldo` ya viene con signo correcto** — verificado con datos reales de 2025: líneas de ingreso
  (`A.01.1` Ventas, `A.01.2` Prestaciones de servicios...) en positivo, líneas de gasto (`A.04.1`
  Consumo de mercaderías, `A.06.1` Sueldos, `A.08.0` Amortización...) en negativo. No hace falta
  invertir signo según tipo de línea.
- **Resultado de Explotación** = `SUM(Saldo)` de las líneas `A.01` a `A.13` (excluye `A.14` en
  adelante, que son resultado financiero e impuestos). Verificado con datos reales de 2025:
  Resultado de Explotación = -66.149,13 €.
- **Amortización del inmovilizado** = `SUM(Saldo)` de la línea única `A.08.0` — no hace falta sumar
  cuentas `68x` sueltas. Verificado 2025: -324.827,84 €.
- Si un cliente no tiene actividad en una línea del modelo PYG (p. ej. no tiene cuentas de detalle
  en el grupo 69 "deterioro" o 71 "variación de existencias"), esa línea simplemente **no aparece**
  en la vista — no sale con `Saldo=0`, sale ausente. Al sumar por rango de `CODIGO` (`LIKE 'A.0%'`)
  esto no da problemas (una línea ausente no aporta nada a la suma), pero si se necesita listar
  todas las líneas posibles del modelo PYG (para un informe con todas las filas siempre visibles,
  aunque sea a 0), hay que partir de un catálogo fijo de líneas oficiales, no de `SELECT DISTINCT`
  sobre esta vista.
- Existe una vista hermana, `Ape_Saldos_Balance_Version_NPGC`, con la misma lógica pero para el
  Balance de Situación — no investigada en detalle (fuera de alcance del análisis de EBITDA).
- Detalle completo de la verificación EBITDA (fórmula, cálculo paso a paso con datos reales) en el
  repo del proyecto: `Dashboards/EBITDA/docs/esquema-contable-ebitda.md`.
