# Diccionario a3ERP — formato XML interno (reverse-engineered)

Este documento recoge, sin editar el relato, lo aprendido inspeccionando librerías reales y
generando desde cero (sin GUI) el diccionario `PERSONACC` (Senyum → INTEMAN, campo
`SEN_CODPERSONA` en `CENTROSC`, FK a `PERSONA`), validado end-to-end en una BD de pruebas en septiembre de
2026. Es la fuente de la que se ha extraído el resumen operativo en `SKILL.md`, sección B — léelo
si necesitas más contexto o precisión que el resumen, o si algo no cuadra con lo que ves en un
diccionario real y quieres entender por qué.

## Librerías reales inspeccionadas (solo lectura)

Todas en `C:\Program Files (x86)\A3\ERP\Sistema.Custom\Sistema\Extensiones\Senyum\` (servidor local
de pruebas):

- **`ValidacionOfertasCompra\diccionarios\ValidacionOfertasCompra\`** — librería Senyum "desde
  cero" (no plantilla de Wolters Kluwer). La más útil como referencia: tiene una FK real
  (`CENTROSC`→`SEN_PERMISOS`, campo `SEN_CENTRO_COSTE`) y el ejemplo Maestro/General
  (`CABEOFEC`=Maestro recibe `SEN_ACEPTADA`, `CENTROSC`=General solo referenciada). Sus valores de
  cabecera (`Autor="Senyum Managment"`, dirección, teléfono, web, email, `VersionDiccionario`) se
  han usado como plantilla para `PERSONACC`.
- **`ExportadorFacturas\diccionarios\ExportadorFacturas\`** — librería Senyum sin FK, tabla
  auxiliar aislada `SEN_CONFIG`.
- **`CertificadosCalidad\diccionarios\tenas\`** — ⚠️ el nombre de carpeta interno es `tenas`, no
  `CertificadosCalidad`; `Libreria.xml` declara `Autor="Wolters Kluwer"`, `Identificador="27"` — es
  una plantilla de WK reutilizada/renombrada, no una librería Senyum original. Tiene FK real
  (`ARTICULO`→`SNY_ARTICULOS_EXCLUIDOS`, campo `CODART`) pero también una inconsistencia: marca
  `ARTICULO` como `Maestro="TRUE"` aunque solo se referencia como padre de FK — contradice la
  regla literal de la guía. No replicar ese patrón; se trata como anomalía, no como caso a imitar.

Ninguna de las tres se ha modificado en ningún momento — toda la inspección fue de solo lectura.

## Estructura de carpetas y ficheros

Cada diccionario vive en `<Producto>\diccionarios\<NombreLibreria>\` con siempre el mismo juego de
15 XML, aunque el diccionario concreto no use todos: `Libreria.xml`, `Dependencias.xml`,
`Tablas.xml`, `Columnas.xml`, `Indices.xml`, `Relaciones.xml`, `Integridad.xml`,
`Constraints.xml`, `Triggers.xml`, `Vistas.xml`, `Procedimientos.xml`, `Funciones.xml`,
`Plantillas.xml`, `PreActualizaciones.xml`, `Actualizaciones.xml`. Los no usados quedan con
`<ROWDATA></ROWDATA>` vacío.

## Formato general

Todos son `DATAPACKET Version="2.0"` — formato de persistencia `TClientDataSet` de Delphi/Borland
(el motor interno de Diccionario.exe está hecho en Delphi). `<METADATA><FIELDS>` define el
esquema (nombre, tipo, ancho); `<ROWDATA><ROW .../>` trae los datos como atributos XML, una fila
por línea. Booleanos como `"TRUE"`/`"FALSE"` (nunca `1`/`0` ni `"True"`), fechas como
`AAAAMMDDThh:mm:ssnnn`, acentos vía entidades HTML (`&#243;`=ó).

- **`Libreria.xml`**: una única fila con los datos generales — `Nombre`, `Version/Revision/Parche`,
  `Autor/Direccion/Telefono/web/email`, y `Identificador` (entero) + `VersionDiccionario` +
  `IdentObjetos`. Campos declarados en `<FIELDS>` pero que las librerías reales **omiten por
  completo** en su `<ROW>` (no aparecen ni vacíos): `MinVersionAct`, `MinRevisionAct`,
  `MinParcheAct`, `MinIdentificadorAct`, `IdentObjetos`. Se ha replicado esa misma omisión en
  `PERSONACC`.
- **`Tablas.xml`**: una fila por tabla dada de alta — `Tabla`, `Descripcion`, flags
  `Virtual/Interna/Maestro/Obsoleta/Auxiliar/Externo/Jerarquia`, `Tipo` (`M`=Maestro, `G`=General,
  `A`=Auxiliar), `Estado`, timestamps `Modificado`/`ModificadoLogico`, `Compartido` (visto siempre
  `="1"`, sin explicación en la guía).
- **`Columnas.xml`**: una fila por columna nueva (o por columna nativa registrada como referencia
  de FK) — `Tabla/Columna/Tipo/Longitud/Escala/PermiteNulos/Descripcion/ValoresPosibles/Defecto`,
  `EsDescripcion` (booleano — el "Descr. Tabla" de la GUI), `Calculado` (`T`/`F`),
  `EnMantenimiento` (`T`/`F`), `Editor` (entero: 0=Sin editor, 1=Campo, 2=Combo, 3=Check,
  4=Memo, 5=Imagen, 6=Depende del campo — orden de la guía PDF pág. 11), `Identidad`,
  `DescripcionCorta`, `Propiedad`, `Cuadrado` (confirmado en la guía: justificación a la derecha —
  `TRUE` en campos código, `FALSE` en texto libre).
- **`Indices.xml`**: `Tabla/Indice/Columnas/Clave/Unico/Agrupado` — solo aparece para tablas
  nuevas propias, nunca para tablas nativas (que ya traen su propio índice de a3ERP).
- **`Integridad.xml`**: es el fichero real de Claves Foráneas (ver más abajo la corrección sobre
  esto). Esquema: `TablaPadre/TablaHija/CamposPadre/CamposHija/TipoRelacion/TipoRelacionU/
  FiltroPadre/FiltroHija`.
- **`Relaciones.xml`**: mismos campos que `Integridad.xml` pero **sin** `TipoRelacion`/
  `TipoRelacionU` (6 campos, no 8) — vacío en las tres librerías reales vistas. Función exacta no
  confirmada (posible vestigio de una versión anterior del formato, o concepto no expuesto en la
  GUI actual). No aparece descrito en la guía PDF.
- **`Dependencias.xml`**: corresponde a la sección "Dependencias" de la guía (versión mínima/máxima
  de otra librería de la que depende esta), vacío en las tres librerías vistas, sin ejemplo real
  con datos.

## "Ident. del diccionario" (`Identificador` en `Libreria.xml`)

No mencionado ni una vez en la guía PDF (0 coincidencias de "Identificador"/"Ident."). Valores
vistos en este servidor: `ValidacionOfertasCompra=32`, `ExportadorFacturas=8`,
`tenas/CertificadosCalidad=27` (asignado por Wolters Kluwer, no por Senyum), `PERSONACC=902`
(elegido a mano para este proyecto, sin conflicto conocido en este servidor). No hay patrón
numérico evidente. Recomendación: no inventar un número "seguro" sin más — si la propia GUI
propone/autogenera uno al crear la librería, usar ese; si hay que ponerlo a mano, verificar antes
en la GUI que no coincide con ningún otro diccionario instalado (no hay visibilidad completa desde
fuera de la herramienta de qué otros diccionarios de terceros pueda haber a nivel global).

## Maestro vs General — regla confirmada

La guía (pág. 8) dice: *"Maestro: son los ficheros maestros de a3ERP. No se usa en diccionarios de
terceros. Solo en caso de añadir campos a una tabla de a3ERP Maestra, hay que indicar este tipo.
General: son el resto de las tablas que se definen en el diccionario de terceros."*

Confirmado con `ValidacionOfertasCompra`: `CABEOFEC` (recibe `SEN_ACEPTADA`) →
`Maestro="TRUE" Tipo="M"`; `CENTROSC` (solo referenciada como padre de FK) →
`Maestro="FALSE" Tipo="G"`. Aplicado a `PERSONACC`: `CENTROSC` (recibe `SEN_CODPERSONA`) → Maestro;
`PERSONA` (solo referenciada) → General. Sí hay que dar de alta la tabla General referenciada, no
solo la receptora.

⚠️ Excepción observada, no replicar: en `tenas/CertificadosCalidad`, `ARTICULO` está marcado
`Maestro="TRUE"` pese a ser solo-referenciada — contradice la guía. Es una plantilla de WK
reutilizada, probablemente un error de esa librería concreta; no se sigue ese patrón.

## EXPERIMENTO — PERSONACC generado a mano, sin usar Diccionario.exe

Experimento explícito pedido por el usuario sobre el entorno de pruebas: generar los 15
XML de `PERSONACC` completamente a mano, sin abrir la GUI ni una vez, para comprobar si es viable.

### Qué se escribió

Ruta: `Extensiones\SENYUM\GestionCC\Diccionarios\PERSONACC\` (15 ficheros nuevos).

- **Libreria.xml**: `Nombre="PERSONACC"`, `Version="1" Revision="0" Parche=""`, datos de contacto
  copiados de `ValidacionOfertasCompra` (`Autor="Senyum Managment"`, dirección, teléfono, web,
  email), `VersionDiccionario="140502"`, `Comentarios="Asignación de persona responsable a Centro
  de Coste (INTEMAN)"`, `Identificador="902"`.
- **Tablas.xml**: `CENTROSC` (`Tipo="M"`, recibe el campo) y `PERSONA` (`Tipo="G"`, solo
  referenciada), ambas con `Externo="TRUE"` explícito.
- **Columnas.xml**: `CENTROSC.SEN_CODPERSONA` (varchar(8), nulos sí, `Editor="2"` Combo,
  `EnMantenimiento="T"`) y `PERSONA.CODPER` (fila de referencia de la clave del padre,
  `EnMantenimiento="F"`, `Editor="0"`, `PermiteNulos="FALSE"`, `Cuadrado="TRUE"` — mismo patrón que
  `CENTROSC.CENTROCOSTE` en el ejemplo real). No se registró `PERSONA.NOMPER`.
- **Indices.xml**: vacío (ambas tablas son nativas con índice propio).
- La FK se escribió **primero en `Relaciones.xml`** (con un `<METADATA>` inventado que sí incluía
  `TipoRelacion`/`TipoRelacionU`) — este fue el error que causó el diagnóstico de más abajo.
- Resto de ficheros (`Integridad`, `Constraints`, `Triggers`, `Vistas`, `Procedimientos`,
  `Funciones`, `Plantillas`, `PreActualizaciones`, `Actualizaciones`): vacíos, mismo esquema
  `METADATA` confirmado fichero a fichero contra las tres librerías reales.

### Dudas marcadas explícitamente como "sin confirmar" en el momento de generarlo
1. `Identificador="902"` — arbitrario, riesgo de colisión no descartable desde fuera de la GUI.
2. Código de `TipoRelacionU` para Cascada — sin ejemplo real, solo hipótesis.
3. `Externo="TRUE"` en la fila de la tabla solo-referenciada — el único ejemplo real de este
   patrón omite el atributo en vez de ponerlo a `FALSE`/`TRUE`.
4. Timestamps `Modificado`/`ModificadoLogico` puestos a mano — no se sabía si Diccionario.exe los
   exige coherentes o los recalcula sin más al abrir un diccionario nunca tocado por la GUI.
5. `DescripcionCorta` sin truncar — posible campo auto-calculado por la GUI.

## DIAGNÓSTICO — por qué la FK no aparecía en "Claves Foráneas"

### Síntoma
Tras generar el diccionario, la FK escrita a mano en `Relaciones.xml` no aparecía en la pestaña
"Claves Foráneas" de Diccionario.exe al seleccionar ni `CENTROSC` ni `PERSONA`, aunque el
diccionario se guardaba sin ningún error visible.

### Diff byte a byte
Al releer (solo lectura, sin paralelizar esta vez) `Relaciones.xml` e `Integridad.xml` de
`ValidacionOfertasCompra` para comparar, apareció una discrepancia grave con lo documentado
inicialmente: el contenido real de esos dos ficheros no era el que se había anotado la primera vez.
Comprobación de timestamps del sistema de ficheros — ninguno de los dos se había modificado desde
que se creó la librería en 2024, ni en esta sesión ni en ninguna otra. Es decir, el contenido leído
era el que siempre había estado ahí: **el error estuvo en la transcripción inicial**,
probablemente al procesar una tanda de 15 lecturas en paralelo — se atribuyó el contenido de
`Integridad.xml` a `Relaciones.xml` y viceversa.

Contenido real confirmado (releído fichero a fichero, sin paralelizar, contrastado con los bytes
en disco):

| Fichero | `<FIELDS>` reales | `<ROWDATA>` real (ValidacionOfertasCompra) |
|---|---|---|
| `Relaciones.xml` | `TablaPadre/TablaHija/CamposPadre/CamposHija/FiltroPadre/FiltroHija` (6 campos, **sin** `TipoRelacion`/`TipoRelacionU`) | vacío |
| `Integridad.xml` | `TablaPadre/TablaHija/CamposPadre/CamposHija/TipoRelacion/TipoRelacionU/FiltroPadre/FiltroHija` (8 campos) | `TablaPadre="CENTROSC" TablaHija="SEN_PERMISOS" CamposPadre="CENTROCOSTE" CamposHija="SEN_CENTRO_COSTE" TipoRelacion="R" TipoRelacionU="R"` |

Es decir: exactamente al revés de lo documentado en el primer pase. El fichero que realmente
alimenta la pestaña "Claves Foráneas" es `Integridad.xml`, no `Relaciones.xml`.

### Por qué "se guardaba sin error" pero la FK no se veía
1. Diccionario.exe **no confía en el `<METADATA>` que trae el XML**: al guardar, reescribe el
   `<FIELDS>` de cada fichero según su propio esquema interno fijo por nombre de fichero — por eso
   nuestro `Relaciones.xml` volvió a los 6 campos "correctos" (sin `TipoRelacion`/
   `TipoRelacionU`) y nuestro `Integridad.xml` pasó a tener los 8 campos "correctos".
2. Pero la **fila de datos** (`<ROW>`) se queda físicamente en el fichero donde se puso
   (`Relaciones.xml`), porque Diccionario.exe no tiene forma de saber que esa fila "debía" estar
   en `Integridad.xml` — solo sabe recolocar el esquema, no reinterpretar dónde va cada fila.
3. Como el esquema real de `Relaciones.xml` no tiene `TipoRelacion`/`TipoRelacionU`, esos dos
   atributos de la fila se descartaron en silencio al guardar — no hay validación visible.
4. Resultado: una fila sin ningún error de XML, en un fichero que Diccionario.exe sí sabe leer,
   pero que la pestaña "Claves Foráneas" simplemente no consulta.

Hipótesis descartada: un identificador interno de fila/tabla en `Tablas.xml` que `Relaciones.xml`
pudiera usar en vez del nombre de tabla. `Tablas.xml` no cambió de contenido en ningún momento del
proceso y su esquema no incluye ningún campo tipo id/rowid; el enlace `TablaPadre="CENTROSC"` con
`Tabla="CENTROSC"` de `Tablas.xml` es puramente por nombre de tabla en texto, no por un id oculto.

### Corrección aplicada
1. `Relaciones.xml` de `PERSONACC`: `<ROWDATA>` vaciado (se quitó la fila mal ubicada).
2. `Integridad.xml` de `PERSONACC`: añadida la fila de la FK, ahora en el fichero correcto:
   `TablaPadre="PERSONA" TablaHija="CENTROSC" CamposPadre="CODPER" CamposHija="SEN_CODPERSONA"
   TipoRelacion="R" TipoRelacionU="R"`.
3. `Tablas.xml` de `PERSONACC`, fila `PERSONA`: se probó quitar el atributo `Externo="TRUE"` (por
   analogía con el único ejemplo real de tabla solo-referenciada que lo omite), aunque se confirmó
   que `Tablas.xml` no había sido tocado por Diccionario.exe al guardar, así que ese valor no
   estaba causando ningún problema — el cambio fue solo por alinear con el patrón real, no por
   evidencia de que rompiera algo. **La versión final desplegada y validada usa `Externo="TRUE"`
   en ambas filas** (ver `reference/plantillas/Tablas.xml`) — es el patrón mayoritario y el que
   quedó funcionando.

### Validado por el usuario tras la corrección
FK visible correctamente en la pestaña "Claves Foráneas" de `CENTROSC` (`CODPER`↔`SEN_CODPERSONA`,
Restrictiva). El campo `TipoRelacionU` quedó en `"R"` (Restrictiva) en la versión final desplegada
— no se confirmó empíricamente el código de "Cascada" para `TipoRelacionU` en este proyecto; si un
caso futuro necesita Cascada de verdad, confirmar el código cambiándolo desde el propio desplegable
de la GUI y releyendo `Integridad.xml` después, en vez de adivinar por analogía con `"R"`.

## Validación final end-to-end (una BD de pruebas)

Confirmado correcto por el usuario ("Funciona perfecto!"):
- Apertura sin errores en Diccionario.exe, guardado desde la GUI sin cambios de metadata
  inesperados.
- Activación en la empresa de pruebas ("Aplicar campos externos (diccionarios de terceros)" +
  librería `PERSONACC` activada).
- El campo aparece en la ficha de Centro de Coste como desplegable (Combo).
- Verificación SQL: la columna `SEN_CODPERSONA` existe en `CENTROSC` con el tipo correcto, la FK
  existe como constraint real en SQL Server, y los valores hacen join correctamente contra
  `PERSONA`.

## Recomendación general

Generar XML a mano **es viable** (contrariamente a la recomendación inicial de este mismo
documento en una versión anterior, que decía seguir siempre por la GUI) — ya está demostrado en un
caso real completo. Sigue siendo más arriesgado que la GUI porque no hay ninguna validación en
escritura (un valor mal puesto se guarda sin avisar, como pasó con la FK), así que:

- Úsalo cuando el usuario lo pida explícitamente y sobre todo en entornos de pruebas/desarrollo.
- Sigue siempre el checklist de validación en GUI de `SKILL.md` sección B.6 después de generar —
  nunca lo des por bueno solo porque el guardado no dio error.
- Cuando algo no aparezca en la GUI pese a guardar sin error, sospecha primero de "dato en el
  fichero equivocado" (como aquí) antes que de "valor de atributo mal escrito".
- Para los ficheros que siempre quedan vacíos (los 9 no cubiertos por `reference/plantillas/`),
  copia su `<METADATA>` de una librería ya validada en vez de reescribirlo de memoria.
