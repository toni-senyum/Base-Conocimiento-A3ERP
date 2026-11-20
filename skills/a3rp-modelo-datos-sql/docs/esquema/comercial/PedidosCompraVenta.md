# Tablas: CABEPEDC, CABEPEDV (cabeceras de Pedido de Compra / Pedido de Venta)

**Módulo A3ERP**: Compras (`CABEPEDC`) / Ventas (`CABEPEDV`)
**Tipo de objeto**: TABLE (ambas), confirmado contra `X_DEMO`
**Descripción**: Cabecera de pedido de compra (`CABEPEDC`, documento `PC` en eventos/API) y de
pedido de venta (`CABEPEDV`, documento `PV`). Mismo patrón de nomenclatura que otras cabeceras de
documento de a3ERP (`CABEOFEC/V`, `CABEALBC/V`, `CABEFACC/V`, `CABEDEPC/V`...).

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| CENTROCOSTE | `varchar(8)` | Sí | FK real a `CENTROSC.CENTROCOSTE` — centro de coste imputado en el pedido, a nivel de cabecera (no de línea). |
| CODPER | `varchar(8)` | Sí | FK real a `PERSONA.CODPER` (`FK_CABEPEDC_PERSONA_CODPER` / `FK_CABEPEDV_PERSONA_CODPER`). Ver nota abajo — **no dar por hecho su semántica solo por el nombre**. |
| CODPRO | — | No | Solo `CABEPEDC` — código de proveedor. Distingue de `CABEPEDV`. |
| CODCLI | — | No | Solo `CABEPEDV` — código de cliente. Distingue de `CABEPEDC`. |

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| CENTROCOSTE | CENTROSC.CENTROCOSTE | FK real |
| CODPER | PERSONA.CODPER | FK real, nativa de a3ERP |

## Notas / gotchas

- **`CODPER` es un patrón genérico de a3ERP, no algo específico de pedidos.** Aparece con el mismo
  nombre y la misma FK hacia `PERSONA` en casi todas las cabeceras de documento
  (`CABEALBC/V`, `CABEFACC/V`, `CABEOFEC/V`, `CABEDEPC/V`, `CABEEXPE`, `CABEAUTO`,
  `CABECAMPANA`...) y en tablas de CRM (`ACCIONES`, `OportunidadesListado`). La estructura de
  `PERSONA` (`IDCARGO`, `PRECIOHORA`, `OLKSINCRONIZAR`, filtros de acciones/departamento) sugiere
  que es el campo nativo genérico "persona/comercial vinculado al documento" del módulo CRM de
  a3ERP — **un concepto de negocio distinto** al de "responsable de centro de coste". **No asumir
  que se puede reutilizar sin más para otro propósito solo porque el tipo/FK coincidan** — antes de
  reutilizar un campo nativo con un propósito distinto al suyo original, confirmar en la GUI si ya
  se usa visiblemente para algo (no hay tabla de captions/etiquetas accesible por SQL para
  confirmarlo por ese camino).
- Verificado en `X_DEMO`: `CODPER` **siempre vacío** en ambas tablas (0/11 filas en `CABEPEDC`,
  0/28 en `CABEPEDV`) en el momento de la comprobación — no concluyente sobre si se usa en otros
  clientes/entornos.
- `CENTROCOSTE` en cabecera de pedido es el mismo concepto/tabla que `CENTROSC` documentada en
  `contabilidad/CentroCosteYPresupuesto.md` — ver ese documento para el resto del esquema de centro
  de coste (incluye el campo de terceros `SEN_CODPERSONA` añadido vía diccionario `PERSONACC` en el
  proyecto INTEMAN, que asigna una persona responsable a cada centro de coste).
- Contexto de descubrimiento: proyecto INTEMAN (traspaso automático, vía DLL de eventos, de la
  persona responsable del centro de coste a la cabecera del pedido al guardar — ver skill
  `a3rp-dll`). La decisión de si el destino final es este `CODPER` nativo o un campo propio nuevo
  (`SEN_CODPERSONA`, vía diccionario) fue una decisión de negocio explícita del cliente, no una
  cuestión de esquema — documentarla aquí solo como antecedente, el diseño vivo del proyecto está
  en el repo del proyecto (`Inteman\Desarrollos\CentroCosteYPersona\Diseño\`).
- **`CABEALBC` (albarán de compra) confirmado idéntico en estos dos campos** (X_DEMO, 2026-09-23):
  `CENTROCOSTE varchar(8)` y `CODPER varchar(8)`, ambos nulables, misma collation
  (`Modern_Spanish_CI_AS`), con `FK_CABEALBC_CENTROSC_CENTROCOSTE` y `FK_CABEALBC_PERSONA_CODPER`.
  Ojo: en X_DEMO las FK de `CENTROCOSTE` (pedido y albarán) están **deshabilitadas**
  (`is_disabled=1`) y las de `CODPER` activas pero `is_not_trusted=1` — no fiarse de ellas como
  garantía de integridad. Vínculo línea pedido → línea albarán: `LINEALBA.IDPEDC` +
  `LINEALBA.NUMLINPED`; pendiente de servir en `LINEPEDI` = `UNIDADES - UNISERVIDA - UNIANULADA`.
  Los albaranes generados desde pedido en X_DEMO heredan `CENTROCOSTE` de cabecera (p. ej. IDALBC
  215 ← IDPEDC 187, `BCN`); si heredan también `CODPER` está pendiente de prueba (INTEMAN).
