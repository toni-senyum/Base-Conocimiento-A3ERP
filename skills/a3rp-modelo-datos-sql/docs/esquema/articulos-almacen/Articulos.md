# Tabla: ARTICULO (modelo Power BI: Articulos)

**Módulo A3ERP**: Artículos/Almacén
**Tipo de objeto**: TABLE (`BASE TABLE`, confirmado en `INFORMATION_SCHEMA.TABLES` contra una BD de pruebas)
**Descripción**: Ficha de artículo. Una fila = un artículo.

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| CODART | `varchar(15)` | No | Clave. **No es `CHAR`** — ver gotcha del padding. |
| DESCART | `varchar(100)` | Sí | |
| FAMARTDESCVEN | `varchar(8)` | Sí | FK **deducida** hacia `FamiliasArticulo.CODFAM` — sin FK declarada en SQL Server. |
| TIPIVA | `varchar(8)` | Sí | |
| ESVENTA | `varchar(1)` | Sí | |
| OBSOLETO | `varchar(1)` | Sí | |
| PRCVENTA | `float` | Sí | |
| AFESTOCK | `varchar(1)` | Sí | "No afecta a stock" — candidato descartado para excluir "Portes" (ver gotcha). |
| CODFAMEST | `varchar(8)` | Sí | **Familia estadística real** — FK **deducida** hacia `FamiliasArticulo.CODFAM` (`FICHERO='Estadis'`), distinta de `FAMARTDESCVEN`. En una BD de pruebas: poblada al 100% (83/83) tras la escritura de prueba del 2026-09-14 — ver gotcha "FAMARTDESCVEN vs CODFAMEST" y nota sobre la excepción de escritura. |

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| CODART | LineasFactura (LINEFACT.CODART) | FK real (`FK_LINEFACT_ARTICULO_CODART`) |
| FAMARTDESCVEN | FamiliasArticulo (FAMILIAS.CODFAM, `FICHERO='DescArt'`) | **Deducida** — sin FK declarada, verificada cruzando datos reales (`FAMILIAS` es genérica/multi-propósito, ver `FamiliasArticulo.md`) |
| CODFAMEST | FamiliasArticulo (FAMILIAS.CODFAM, `FICHERO='Estadis'`) | **Deducida** — misma tabla `FAMILIAS`, subconjunto distinto (ver gotcha) |

## Notas / gotchas

- **`CODART` es `VARCHAR(15)`, NO `CHAR`** — corregido tras verificar contra `INFORMATION_SCHEMA.COLUMNS` en una BD de pruebas (dato que se me había pasado como "es CHAR" resultó no serlo; ver aviso al final de esta ronda de documentación). El efecto práctico verificado con `DATALENGTH()` sigue siendo real: los códigos **puramente numéricos** (p. ej. `"52"`, `"53"`) se graban justificados a la derecha con espacios hasta ocupar los 15 caracteres completos (`DATALENGTH = 15`), mientras que los códigos alfanuméricos (p. ej. `"T1"`) se graban sin relleno (`DATALENGTH = 2`). Sea cual sea la causa exacta (probablemente el propio ERP al escribir códigos numéricos), el efecto es el mismo que si fuera `CHAR`: hace falta `LTRIM`/`RTRIM`/`Text.Trim` al comparar o filtrar — un filtro como `CODART = '52'` sin el trim no encuentra nada.
- **`AFESTOCK`** se investigó como alternativa genérica a la lista de códigos `52`/`53` para excluir "Portes" de `Ventas por Familia`. **Descartado**: también marca `'F'` el artículo genérico "sin codificar" (`CODART = 0`), que sí es una venta real (tiene familia `RECA` asignada) — usarlo tal cual excluiría más de lo pedido. Se mantiene la lista de códigos explícita en la medida `Ventas por Familia (Base Imponible)`, documentada como específica de una BD de pruebas (revisar en el entorno real del cliente).
- No hay FK declarada en SQL Server entre `ARTICULO.FAMARTDESCVEN` y `FAMILIAS.CODFAM` — la relación se dedujo por convención de nombre/dominio de valores y se verificó cruzando datos reales.
- **`FAMARTDESCVEN` vs `CODFAMEST` — dos familias distintas, no confundir (hallazgo 2026-09-14).** `FAMARTDESCVEN` es la familia de **descuento de venta** (literal: "familia artículo descuento venta"), la que ya usa el dashboard de A3ERP-PowerBI (`Ventas por Familia (Base Imponible)`) vía `FAMILIAS` filtrada a `FICHERO='DescArt'`. `CODFAMEST` es la familia **estadística** real — un concepto de negocio distinto, vía `FAMILIAS` filtrada a `FICHERO='Estadis'`. Verificado empíricamente contra una BD de pruebas (83 artículos): `FAMARTDESCVEN` encaja al 100% (62/62 valores poblados) contra `FICHERO='DescArt'` y al 0% contra `FICHERO='Estadis'` — las dos familias son dominios de valores completamente distintos, no intercambiables. Antes de esta verificación, una ronda anterior de esta misma documentación decía por error que el modelo usaba `FICHERO='Estadis'` para `FamiliasArticulo` — **era un error de transcripción de quien documentó, no un bug del `.tmdl`** (el generador ya usaba `DescArt` correctamente desde el principio); queda corregido aquí y en `FamiliasArticulo.md`.
- **`CODFAMEST` estaba casi vacía en origen (2/83 artículos) y se pobló manualmente en una BD de pruebas el 2026-09-14** con una clasificación estadística nueva, coherente con el catálogo real (tienda de bicicletas/deporte) — los 8 códigos `Estadis` originales (`AGUBR`, `AUT`, `BCN`, `CREK`, `INI`, `KAYAK`, `PESCA`, `RECR`) no tenían relación alguna con este catálogo (parecían de otro negocio, deportes acuáticos) y se borraron. Detalle completo de la propuesta, el criterio de clasificación artículo a artículo y el SQL ejecutado en `Integracion/00-Documentacion/propuesta-familias-estadisticas.md`.
  **⚠️ Excepción puntual, no un patrón a repetir**: esta skill (`a3rp-modelo-datos-sql`) es de **solo lectura** por regla general — la escritura de arriba se autorizó explícitamente por ser una BD de pruebas un entorno de prueba sin datos ni clientes reales. **No replicar este tipo de escritura contra la base de datos de un cliente real** sin una autorización igual de explícita; para operaciones de negocio contra un cliente real, usar siempre `a3rp-api-com` (respeta validaciones/triggers de A3ERP), nunca SQL directo.
