---
name: a3rp-diccionarios
description: >
  Usa esta skill (1) para cualquier consulta sobre la estructura de datos de A3RP/a3ERP:
  nombre de tablas, campos, tipos de datos, relaciones entre tablas, claves primarias/foráneas,
  o cualquier pregunta sobre el modelo de datos del ERP, y también (2) para CREAR o EXTENDER un
  diccionario de terceros de a3ERP — la herramienta de extensibilidad de Wolters Kluwer que permite
  añadir tablas, columnas y claves foráneas propias a a3ERP sin tocar su núcleo. Activar cuando se
  pida "añadir un campo a [tabla] mediante diccionario", "crear un diccionario a3ERP", "generar los
  XML de un diccionario a mano", "relacionar dos tablas con una FK en el diccionario", cuando se
  genere código .NET que acceda a tablas de A3RP (SQL o vía API), cuando se pida crear mapeos o DTOs
  basados en tablas de A3RP, o cuando el usuario pregunte "¿cómo se llama el campo de X en A3RP?" o
  "¿en qué tabla está Y?". Imprescindible antes de generar cualquier consulta SQL o acceso a datos
  contra la base de datos de A3RP, y antes de tocar la carpeta `Extensiones\` de un servidor a3ERP.
---

# Skill: Diccionarios de A3RP / a3ERP

Esta skill cubre **dos cosas distintas que comparten nombre** en el mundo a3ERP — léelo antes de
seguir, para no confundirlas:

1. **Diccionario de documentación** (sección A) — los `.md` en `docs/diccionarios/` de este
   repositorio, que documentan tablas y campos ya existentes en a3ERP para poder escribir SQL o
   DTOs sin inventar nombres.
2. **Diccionario a3ERP / "Diccionario de terceros"** (sección B) — la herramienta de
   extensibilidad de Wolters Kluwer (`Diccionario.exe`) que permite **añadir** tablas, columnas y
   claves foráneas propias a a3ERP (p. ej. un campo `SEN_CODPERSONA` en Centro de Coste). Esto
   incluye tanto el flujo estándar por GUI como, ya validado end-to-end en entorno de pruebas, la
   generación directa de sus ficheros XML sin abrir la GUI.

Ver también: `a3rp-modelo-datos-sql`, para explorar/entender el esquema de solo lectura antes de
decidir qué tabla/campo extender en la sección B.

---

# A. Consulta de estructura de datos existente

## REGLA CRÍTICA

**Nunca inventar nombres de tablas o campos.** Si la información no está en `docs/diccionarios/`,
indicar explícitamente al usuario que debe aportar el diccionario correspondiente antes de generar
código de acceso a datos.

## Documentación de referencia

```
docs/diccionarios/
├── index.md              ← índice de módulos y sus tablas principales
├── contabilidad/
│   ├── plan-de-cuentas.md
│   ├── asientos.md
│   └── ...
├── facturacion/
│   ├── facturas-venta.md
│   ├── lineas-factura.md
│   └── ...
├── clientes/
│   ├── clientes.md
│   └── ...
├── almacen/
│   ├── articulos.md
│   ├── movimientos.md
│   └── ...
└── [modulo]/
```

## Cómo usar los diccionarios al generar código

### 1. Antes de escribir SQL
```
→ Consultar docs/diccionarios/[modulo]/[tabla].md
→ Verificar: nombre exacto de tabla, nombres de campos, tipos, PKs
→ Solo entonces generar la query
```

### 2. Al crear DTOs / modelos
```csharp
// Siempre documentar de qué tabla proviene cada propiedad
/// <summary>
/// DTO de factura de venta.
/// Fuente: tabla [NOMBRE_TABLA] — ver docs/diccionarios/facturacion/facturas-venta.md
/// </summary>
public class FacturaVentaDto
{
    /// <summary>Campo: [NOMBRE_CAMPO] (PK)</summary>
    public string Id { get; set; }

    /// <summary>Campo: [NOMBRE_CAMPO_CLIENTE] — FK a tabla Clientes</summary>
    public string ClienteId { get; set; }

    // ...
}
```

### 3. Al acceder vía API COM vs SQL directo
- **Preferir siempre la API COM** para escritura (garantiza integridad y triggers de A3RP)
- SQL directo: solo para lecturas/reporting cuando la API no exponga el dato
- Nunca escribir directamente en tablas de A3RP sin pasar por la API — **esto aplica a tablas
  nativas de a3ERP con acceso normal**; ver sección B para el caso distinto de un campo propio
  añadido vía diccionario de terceros, que sí se puede escribir directamente por SQL una vez
  desplegado (es una columna real de la tabla).

## Plantilla de documentación de tabla

*(Usar este formato al añadir tablas a `docs/diccionarios/`)*

```markdown
# Tabla: [NOMBRE_TABLA]

**Módulo**: [Módulo A3RP]
**Descripción**: [Qué representa esta tabla]

## Campos

| Campo | Tipo | Nulo | PK | FK | Descripción |
|-------|------|------|----|----|-------------|
| [CAMPO] | VARCHAR(x) / INT / DATE / ... | Sí/No | ✓/- | - | Descripción |
| [CAMPO_FK] | INT | No | - | → [TABLA_REF].[PK] | ... |

## Índices relevantes

| Nombre | Campos | Tipo |
|--------|--------|------|
| PK_[TABLA] | [CAMPO] | PK |
| IX_[TABLA]_[CAMPO] | [CAMPO] | Único/No único |

## Notas
- [Cualquier comportamiento especial, campos calculados, etc.]
```

## Guía de acceso seguro a datos A3RP

### Si la base de datos es SQL Server

```csharp
// Usar siempre parámetros — nunca interpolación de strings en queries
using var conn = new SqlConnection(_connectionString);
using var cmd = new SqlCommand(
    "SELECT [CAMPO1], [CAMPO2] FROM [TABLA] WHERE [PK] = @id", conn);
cmd.Parameters.AddWithValue("@id", id);

await conn.OpenAsync();
using var reader = await cmd.ExecuteReaderAsync();
// ...
```

### Cadena de conexión
```json
{
  "ConnectionStrings": {
    "A3RP": "Server=[servidor];Database=[bbdd_a3rp];Integrated Security=true;"
  }
}
```

*(Ver `docs/diccionarios/index.md` para nombre real de la base de datos)*

## Módulos y tablas clave

*(Completar con `docs/diccionarios/index.md` cuando esté disponible)*

| Módulo | Tablas principales | Estado doc |
|--------|-------------------|------------|
| Clientes | - | ⏳ pendiente |
| Facturación | - | ⏳ pendiente |
| Artículos/Almacén | - | ⏳ pendiente |
| Contabilidad | - | ⏳ pendiente |
| Compras | - | ⏳ pendiente |

---

# B. Crear/extender un diccionario a3ERP (Diccionario.exe y XML directo)

Validado end-to-end en entorno de pruebas local (X_DEMO, sept. 2026): añadir un campo
`SEN_CODPERSONA` a `CENTROSC` con FK a `PERSONA`, **generando los 15 ficheros XML del
diccionario directamente, sin abrir Diccionario.exe ni una sola vez**, y confirmando después en la
GUI y por SQL que quedó correcto. Ver `reference/diccionario-a3erp-formato.md` en esta misma skill
para el detalle técnico completo (formato exacto, ejemplos reales byte a byte, y la historia del
bug que motivó la corrección más importante de este documento). Esta sección es el resumen
operativo; **antes de generar un diccionario nuevo por primera vez, lee también el fichero de
referencia completo**, no solo este resumen.

## B.0 — Qué es y las dos formas de crearlo

Un "diccionario de terceros" es una librería de metadatos (no de código) que le dice a a3ERP qué
tablas/columnas/relaciones propias existen además del núcleo del ERP. Vive como una carpeta de 15
XML dentro de `Sistema.Custom\Sistema\Extensiones\<Empresa>\<Producto>\Diccionarios\<Libreria>\`.

Dos formas de generarlo, ambas válidas — la elección depende del contexto:

- **Vía GUI (`Diccionario.exe`)** — el camino por defecto y más seguro cuando hay un humano
  delante que puede operar la herramienta. La GUI valida en caliente (tipos, tablas existentes,
  índices por FK) y calcula por ti varios campos (timestamps, truncados, etc.).
- **XML directo (sin abrir la GUI)** — más rápido de automatizar, y **ya demostrado que funciona**,
  pero sin ninguna validación: un atributo mal puesto se guarda sin error y el problema solo se
  detecta visualmente en la GUI después (ver B.4, el caso real que nos pasó). Úsalo cuando el
  usuario lo pida explícitamente para un entorno de pruebas/desarrollo, nunca por defecto contra un
  entorno real sin que el usuario lo sepa y sin pasar el checklist de validación de B.6.

En ambos casos: **la validación final siempre se hace abriendo el resultado en Diccionario.exe**
antes de darlo por bueno, y el despliegue a un entorno real de cliente es una fase aparte,
explícita, nunca implícita en la generación del diccionario.

## B.1 — Estructura de carpetas obligatoria

Nunca mezclar el diccionario desplegable con documentación/notas de trabajo. Patrón usado y
validado:

```
<Proyecto>\
  Extensiones\                      ← ESPEJO EXACTO de lo que se copia dentro de
    <EMPRESA>\                        Sistema.Custom\Sistema\Extensiones\ del servidor.
      <Producto>\                     Aquí NUNCA debe haber nada que no haya generado
        Diccionarios\                la propia herramienta (ni documentación, ni notas).
          <Libreria>\              ← Diccionario.exe debe apuntar aquí al crear/abrir
                                     el diccionario (o generar aquí los 15 XML a mano).
        Binarios\                  ← crear solo si hace falta
        Menús\                     ← crear solo si hace falta
  Desarrollo\                       ← documentación, diseño, brief, notas. NUNCA se copia
    <Producto>\                       al servidor.
      README.md
      diseno-....md
      Documentacion\
        Diccionario_a3ERP_Guia_de_uso.pdf
```

Antes de copiar nada a un servidor real: comprobar que `Extensiones\` no contiene ningún `.md`,
`.pdf`, README ni nota — solo lo generado por la herramienta.

## B.2 — Los 15 ficheros y el formato DATAPACKET

Cada diccionario es siempre el mismo juego de 15 XML (los no usados quedan con `<ROWDATA></ROWDATA>`
vacío, pero con su `<METADATA>` intacto):

```
Libreria.xml  Dependencias.xml  Tablas.xml  Columnas.xml  Indices.xml
Relaciones.xml  Integridad.xml  Constraints.xml  Triggers.xml  Vistas.xml
Procedimientos.xml  Funciones.xml  Plantillas.xml  PreActualizaciones.xml
Actualizaciones.xml
```

Todos son `DATAPACKET Version="2.0"` — formato de persistencia `TClientDataSet` de Delphi/Borland
(el motor de Diccionario.exe está hecho en Delphi). Este formato **no está documentado
públicamente por Wolters Kluwer** (0 menciones en la guía oficial en PDF); todo lo de esta sección
viene de inspección directa de librerías reales y de un ciclo de prueba-error propio.

Estructura común:
```xml
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
  <DATAPACKET Version="2.0">
<METADATA>
<FIELDS>
  <FIELD attrname="..." fieldtype="string.uni" WIDTH="..."/>   <!-- texto -->
  <FIELD attrname="..." fieldtype="i4"/>                        <!-- entero -->
  <FIELD attrname="..." fieldtype="boolean"/>                   <!-- TRUE/FALSE -->
  <FIELD attrname="..." fieldtype="dateTime"/>                  <!-- AAAAMMDDThh:mm:ssnnn -->
  <FIELD attrname="..." fieldtype="bin.hex" SUBTYPE="WideText"/><!-- texto largo -->
</FIELDS>
<PARAMS/>
</METADATA>
<ROWDATA>
<ROW atributo1="valor1" atributo2="valor2" .../>   <!-- una fila = una línea, todo en atributos -->
</ROWDATA>
</DATAPACKET>
```

Reglas de valor:
- Booleanos: literalmente `"TRUE"` / `"FALSE"` — nunca `1`/`0` ni `"True"`.
- Fechas: `AAAAMMDDThh:mm:ssnnn` (p. ej. `20260918T12:00:00000`).
- Acentos/ñ en texto: entidades HTML (`&#243;` = ó, `&#241;` = ñ, etc.), nunca UTF-8 crudo dentro
  del atributo.

Plantillas exactas (METADATA confirmado) de `Libreria.xml`, `Tablas.xml`, `Columnas.xml`,
`Integridad.xml`, `Relaciones.xml` e `Indices.xml`: ver `reference/plantillas/` en esta skill.
Para los otros 9 ficheros (siempre vacíos en nuestro caso — `Dependencias`, `Constraints`,
`Triggers`, `Vistas`, `Procedimientos`, `Funciones`, `Plantillas`, `PreActualizaciones`,
`Actualizaciones`): **no reinventar su `<METADATA>` a mano** — cópialos tal cual desde una librería
ya validada (p. ej. `Extensiones\SENYUM\GestionCC\Diccionarios\PERSONACC\` en el entorno local de
Senyum, o cualquier otra librería que ya se haya abierto y guardado con Diccionario.exe) y déjalos
con `<ROWDATA></ROWDATA>` vacío salvo que el diccionario nuevo realmente necesite usarlos.

## B.3 — Reglas de contenido confirmadas

- **Maestro (`Tipo="M"`) vs General (`Tipo="G"`)**: Maestro se marca **solo** en la tabla nativa de
  a3ERP que **recibe** el campo nuevo. Cualquier tabla que solo se referencia como padre de una FK
  (aunque sea nativa) va como General. Confirmado con ejemplo real (`CABEOFEC`=Maestro recibe
  campo, `CENTROSC`=General solo referenciada) y con nuestro propio caso (`CENTROSC`=Maestro recibe
  `SEN_CODPERSONA`, `PERSONA`=General solo referenciada por la FK). Sí hay que dar de alta también
  la tabla General referenciada — no basta con la que recibe el campo.
- **`Editor` (entero, en `Columnas.xml`)**: `0`=Sin editor, `1`=Campo, `2`=Combo, `3`=Check,
  `4`=Memo, `5`=Imagen, `6`=Depende del campo (guía pág. 11).
- **`EsDescripcion`** (booleano, `Columnas.xml`) = el flag "Descr. Tabla" de la GUI: marca qué
  columna es el nombre legible de una tabla, para que los selectores de FK muestren nombre y no
  solo código.
- **Fila de referencia de la clave del padre**: cuando una tabla se añade solo como padre de una
  FK (tipo General), su columna clave necesita también su propia fila en `Columnas.xml` —
  `EnMantenimiento="F"`, `Editor="0"`, `EsDescripcion="FALSE"` — igual patrón que
  `PERSONA.CODPER` en nuestro caso o `CENTROSC.CENTROCOSTE` en el ejemplo real de referencia. No
  hace falta registrar el campo descriptivo de esa tabla (p. ej. `PERSONA.NOMPER` no se registra).
- **`Externo`** (booleano, `Tablas.xml`): ponlo `"TRUE"` explícito en la práctica totalidad de
  filas (tablas nuevas o nativas, receptoras o solo-referenciadas) — es el patrón mayoritario
  confirmado y el que usamos en la versión final validada. Se ha visto un único caso real donde
  se omite en vez de `FALSE`/`TRUE` para una tabla solo-referenciada; no es necesario replicar esa
  omisión, `TRUE` explícito funciona.
- **`Identificador`** (entero, `Libreria.xml`, identifica la librería): **no documentado por la
  guía, sin rango ni patrón conocido** (valores vistos en local: 8, 27, 32, y 902 el nuestro).
  Elige un número claramente alejado de los ya vistos en el servidor de destino y pide al usuario
  que confirme en la propia GUI que no colisiona con ningún otro diccionario instalado (local o de
  terceros) antes de dar el diccionario por bueno — no hay visibilidad completa desde fuera de la
  herramienta.
- **`Comentarios`** en `Libreria.xml` es `bin.hex SUBTYPE="WideText"` pero se escribe igual que
  cualquier otro atributo de texto (con entidades HTML para acentos); no hace falta codificarlo en
  hexadecimal a mano.

## B.4 — 🔴 EL GOTCHA MÁS IMPORTANTE: Relaciones.xml NO es el fichero de Claves Foráneas

**El fichero que alimenta la pestaña "Claves Foráneas" de la GUI es `Integridad.xml`, NO
`Relaciones.xml`.** Esto se confirmó tras un fallo real: escribimos la FK en `Relaciones.xml` (con
un `<METADATA>` inventado que sí incluía `TipoRelacion`/`TipoRelacionU`) y el diccionario **se
guardó sin ningún error**, pero la FK nunca apareció en la pestaña "Claves Foráneas" de ninguna de
las dos tablas.

Causa raíz (confirmada byte a byte contra una librería real sin tocar desde 2024): Diccionario.exe
**no confía en el `<METADATA>` que trae el XML** — al abrir/guardar, reescribe el `<FIELDS>` de
cada fichero según su propio esquema interno fijo por *nombre de fichero*, pero **no reubica las
filas de `<ROWDATA>` entre ficheros**. Resultado: la fila se quedó físicamente en `Relaciones.xml`
(cuyo esquema real no tiene `TipoRelacion`/`TipoRelacionU` — esos dos atributos se descartaron en
silencio al guardar), y la pestaña "Claves Foráneas" simplemente no consulta ese fichero. Se
guarda sin error y a la vez no aparece en ningún sitio — el fallo es completamente silencioso.

**Regla operativa: cualquier FK/clave foránea va siempre en `Integridad.xml`.**
`Relaciones.xml` se deja siempre con `<ROWDATA></ROWDATA>` vacío (así está en todas las librerías
reales vistas; su función exacta no está confirmada, posiblemente vestigial). Esquema real de
`Integridad.xml`:

```
TablaPadre / TablaHija / CamposPadre / CamposHija / TipoRelacion / TipoRelacionU / FiltroPadre / FiltroHija
```

Ejemplo real confirmado (patrón general, no solo el nuestro):
```xml
<ROW TablaPadre="PERSONA" TablaHija="CENTROSC" CamposPadre="CODPER" CamposHija="SEN_CODPERSONA"
     TipoRelacion="R" TipoRelacionU="R"/>
```

La lección general detrás de este bug aplica a cualquier fichero del diccionario, no solo a este
par: **si algo no aparece en la GUI tras un guardado sin errores, sospecha primero de que el dato
está en el fichero equivocado**, no de que el valor esté mal escrito.

## B.5 — Códigos de `TipoRelacion` / `TipoRelacionU` (borrado / actualización)

- **`"R"` = Restrictiva** — confirmado por ejemplo real (`CENTROSC`→`SEN_PERMISOS`,
  `TipoRelacion="R" TipoRelacionU="R"`) y por la guía (sección 6.3, pág. 13).
- **Cascada**: el diseño original de nuestro caso pedía borrado Restrictiva / actualización
  Cascada, pero **no hay ningún ejemplo real ni confirmación empírica del código exacto para
  Cascada** — la versión final desplegada y validada en X_DEMO usa `TipoRelacionU="R"`
  (Restrictiva también en actualización), no Cascada. Si un caso futuro necesita Cascada de
  verdad: créala primero en la GUI con el desplegable "Tipo relación actualización", guarda, y lee
  el `TipoRelacionU` resultante en `Integridad.xml` — esa es la forma fiable de confirmar el
  código, no lo adivines por analogía con `"R"`.
- **"Establecer a null"**: código sin confirmar, mismo método de verificación que Cascada.

## B.6 — Checklist obligatorio tras generar XML a mano (nunca saltárselo)

1. Abrir la carpeta del diccionario en Diccionario.exe como diccionario existente — no debe dar
   ningún error/excepción.
2. Librería: nombre, autor y demás datos de contacto correctos; `Identificador` sin conflicto
   (confirmar con el usuario si la GUI no avisa de nada).
3. Tablas: aparecen todas con el `Tipo` (Maestro/General) esperado.
4. Columnas: tipo, longitud, nulos, `Editor` y descripción de cada columna nueva correctos; la
   fila de referencia de la clave del padre también aparece.
5. **Claves Foráneas** (pestaña, con cada tabla implicada seleccionada): la FK aparece, con
   `TipoRelacion`/`TipoRelacionU` mostrados como se espera. Si no aparece pero el guardado no dio
   error → revisar inmediatamente si la fila quedó en `Relaciones.xml` en vez de `Integridad.xml`
   (B.4).
6. Resto de pestañas (Índices, Integridad si no se usa, Constraints, Triggers, Vistas,
   Procedimientos, Funciones, Plantillas, Pre/Actualizaciones) se abren vacías sin error.
7. Guardar cambios desde la propia GUI al menos una vez (esto también homogeneiza cualquier
   `<METADATA>` que hubiéramos escrito distinto al esquema interno real).
8. Activar el diccionario **solo en el entorno de pruebas acordado** (nunca en un entorno real sin
   que el usuario lo pida explícitamente como fase aparte): Otros/Datos generales/Preferencias →
   "Aplicar campos externos (diccionarios de terceros)", y activar la librería en Configuración de
   diccionarios de la empresa. Reiniciar a3ERP.
   **Antes de este paso, confirmar qué instalación de a3ERP es la que se está activando — ver B.8,
   puede haber más de una en la misma máquina.**
9. Verificar en la ficha correspondiente que el campo aparece con el editor esperado (combo,
   check, etc.), y verificar por SQL directo: la columna existe con el tipo correcto, la FK existe
   como constraint real en SQL Server, y los valores hacen join correctamente con la tabla padre.
   **Repetir esta verificación SQL cada vez que se retome el proyecto tras una pausa** (ver B.8) —
   no basta con haberlo confirmado una vez en el pasado.
10. Confirmar que `Extensiones\` sigue sin contener nada que no haya generado la herramienta.

## B.8 — 🔴 Confirmar SIEMPRE qué instalación de a3ERP es la "real" antes de dar un despliegue por bueno

Descubierto en el proyecto INTEMAN (GestionCC, sept. 2026): una misma máquina puede tener **más de
una carpeta de instalación de a3ERP** con estructura `Extensiones\` propia, y no todas son la que
carga `a3ERP.exe` en tiempo de ejecución. Caso real encontrado:

- `A3\A3Erp\` — la instalación REAL en ejecución (`a3ERP.exe`, `a3ERPActiveX.dll`). Su
  `Extensiones\...\Binarios\` es de donde a3ERP carga de verdad binarios/DLLs de eventos.
  Normalmente protegida por permisos de Windows (requiere sesión elevada para escribir).
- `A3\ERP\Sistema.Custom\Sistema\Extensiones\...` — una carpeta *con la misma estructura*,
  escribible sin permisos especiales, con ficheros propios (`.a3ErpKey`) que no existen en la
  instalación real — aparentemente un árbol de staging/despliegue usado por alguna herramienta de
  instalación o por el propio `Diccionario.exe` internamente, **no** la ruta que carga `a3ERP.exe`.

Un diccionario generado/editado y "activado" contra el árbol equivocado puede **parecer
completamente correcto** (Diccionario.exe lo abre sin error, la GUI muestra la columna, incluso se
puede confirmar visualmente) sin que la columna llegue a existir nunca en la base de datos real que
usa la empresa activa — exactamente lo que pasó con `PERSONACC`/`SEN_CODPERSONA`: dado por
"completado y validado en X_DEMO" en la documentación, pero la comprobación SQL directa (semanas
después) mostró que la columna no existía físicamente. Causa: el diccionario se había desplegado y
activado en un entorno de pruebas distinto al que se estaba usando para verificar por SQL.

**Reglas operativas:**
- Antes de dar cualquier diccionario por "desplegado y activado en `<entorno>`", confirmar
  explícitamente con el usuario en qué carpeta de instalación física corre ese entorno — si hay
  dudas de que pueda haber más de una instalación en la máquina, comprobarlo (p. ej. buscar
  `a3ERP.exe`/`a3ERPActiveX.dll` reales en `Program Files (x86)\A3\` y ver cuál carpeta
  `Extensiones\` cuelga de esa misma instalación, o revisar el acceso directo/lanzador que usa el
  usuario para abrir a3ERP).
- **No basta con verificar una vez y darlo por bueno para siempre.** Si el proyecto se retoma tras
  una pausa, o si el entorno de pruebas ha podido cambiar (reinstalación, otro entorno de pruebas
  usado en paralelo, restauración de base de datos), repetir la comprobación SQL directa
  (`INFORMATION_SCHEMA.COLUMNS`) antes de construir lógica de negocio que dependa de esa columna.
- Si aparecen dos árboles `Extensiones` y no está claro cuál es el real: la señal más fiable es
  comprobar contra qué carpeta apunta el `OutputPath`/despliegue de una DLL de eventos **ya
  desplegada y funcionando de verdad** (si existe alguna) — esa es, por definición, la instalación
  real.

---

## B.7 — Caso de referencia completo

El diccionario `PERSONACC` (Senyum/GestionCC, campo `SEN_CODPERSONA` en `CENTROSC` con FK a
`PERSONA`) es el caso real que validó todo este flujo, íntegramente generado por XML a mano y
confirmado correcto en GUI y por SQL en un entorno de pruebas. **Importante (ver B.8): esa
confirmación por SQL se hizo en un entorno de pruebas que después resultó no ser el mismo que
X_DEMO** — repetir siempre la comprobación SQL en el entorno exacto que se vaya a usar, no asumir
que sigue siendo válida de una sesión a otra. Dos fuentes:

- `reference/diccionario-a3erp-formato.md` en esta skill: el relato técnico completo (formato
  observado, diagnóstico del bug de B.4 con el diff byte a byte, y todas las dudas marcadas
  explícitamente como no confirmadas).
- `reference/plantillas/`: los 6 XML con datos (Libreria, Tablas, Columnas, Integridad,
  Relaciones, Indices) tal como quedaron en la versión final validada — útiles como plantilla
  literal para el próximo diccionario (cambiar nombres/valores, mantener estructura y METADATA).
