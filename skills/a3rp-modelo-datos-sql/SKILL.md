---
name: a3rp-modelo-datos-sql
description: >
  Usa esta skill cuando haya que explorar o entender el esquema de la base de datos SQL Server
  de una instalación de A3ERP (Asesor Plus ERP) con fines de LECTURA / informes: descubrir qué
  tablas y vistas existen, verificar relaciones no declaradas formalmente, confirmar el significado
  real de una columna antes de usarla, conectar contra la base de datos de un cliente vía
  CONEXION_PBI.xml, o preparar un modelo de datos para Power BI u otra herramienta de BI/reporting.
  Activar también ante preguntas como "¿qué tabla tiene X en A3ERP?", "¿cómo se relaciona la tabla
  Y con Z?", "quiero montar un informe sobre..." o "conéctate a la base de datos de este cliente".
  NO usar para crear o extender tablas/campos oficiales de A3ERP (→ skill a3rp-diccionarios) ni
  para ejecutar operaciones de negocio como crear una factura o tocar stock (→ skill a3rp-api-com).
---

# Skill: Modelo de Datos SQL de A3ERP (lectura / BI)

## Cuándo usar esta skill y cuándo no

A3ERP tiene tres caminos de acceso a sus datos, cada uno con su skill:

| Necesidad | Skill |
|---|---|
| Crear o extender un campo/tabla **oficial** de A3ERP (reconocido por el propio ERP) | `a3rp-diccionarios` |
| Ejecutar una operación de **negocio** (crear factura, actualizar stock) respetando validaciones/triggers de A3ERP | `a3rp-api-com` — nunca escribir directo en SQL para esto |
| **Entender** qué tablas/vistas existen, cómo se relacionan de verdad, qué contiene un campo — para lectura, informes, Power BI, análisis ad-hoc | **Esta skill** |

Esta skill es de **solo lectura**. Nunca proponer `INSERT`/`UPDATE`/`DELETE` contra tablas de A3ERP desde aquí — para escritura, remitir a `a3rp-api-com`.

---

## Patrón de conexión a la base de datos de un cliente

A3ERP guarda los datos de conexión activos en un fichero XML local, de ruta y nombre fijos:

```
C:\ProgramData\A3\a3Erp\CONEXION_PBI.xml
```

```xml
<config>
  <Server>NOMBRE_SERVIDOR\A3ERP</Server>
  <Database>NOMBRE_BASE_DATOS</Database>
</config>
```

Cada máquina/cliente rellena `Server`/`Database` con su instancia real (si se abre desde dentro de
A3ERP, el propio ERP lo rellena según la empresa activa). Leer este fichero primero, en vez de asumir
o pedir el servidor a mano — es el patrón estándar en todas las instalaciones de A3ERP con Power BI.

En Power Query (M), el patrón es:
```
let
    xmlTable = Xml.Tables(File.Contents("C:\ProgramData\A3\a3Erp\CONEXION_PBI.xml")),
    SERVIDOR = xmlTable[Server]{0},
    DATABASE = xmlTable[Database]{0},
    Origen = Sql.Database(SERVIDOR, DATABASE)
```
Para exploración directa (fuera de Power BI), leer el XML y conectar por T-SQL normal con esos mismos valores.

---

## Metodología de exploración empírica

**Nunca asumir la estructura de una tabla por su nombre.** Verificar siempre contra la base de datos
real (`INFORMATION_SCHEMA`, muestreo de filas) antes de dar nada por sentado. Lecciones ya aprendidas
explorando A3ERP en varios proyectos:

- **Una vista puede parecer una tabla.** `Familia_Estadis` es una `VIEW`, no una tabla — confirmar
  siempre `TABLE_TYPE` en `INFORMATION_SCHEMA.TABLES` antes de asumir que tiene índices propios o que
  se puede escribir en ella.
- **Las jerarquías no siempre son columnas planas.** La jerarquía de familias de artículo vive en
  `SIE_ESTRUCTURASFAMILIAARTICULO` como lista de adyacencia (una fila por relación padre-hijo), no
  como columnas `Nivel1`/`Nivel2`/... — comprobar siempre cómo está modelada una jerarquía antes de
  escribir la consulta o el modelo semántico.
- **Los campos `CHAR` de longitud fija llevan padding.** `ARTICULO.CODART` es `CHAR`, no `VARCHAR` —
  requiere `LTRIM`/`RTRIM` (o `TRIM`) al comparar o mostrar; si no, los espacios de relleno rompen
  comparaciones y `JOIN`s en silencio.
- **El nombre de una columna no garantiza su semántica real.** Contrastar siempre contra datos reales
  antes de asumir qué campo es el correcto — p. ej. en `Clientes`, `RAZON` **no** es la razón social
  sino el nombre comercial; la razón social es `NOMFISCAL` y `NOMCLI` el nombre de la Organización
  (⚠️ corregido 2026-10, proyecto RocRoi; ver `Clientes.md`).
- **No fijar en el código valores que dependen de la empresa** (plan contable, centros de coste por
  defecto, estructura de cuentas): leerlos de `DATOSCON` (`PLACON`, `CENTROCOSTE/2/3`,
  `COMPOSICI1..5`). Ver `CUENTAS.md`.
- **"Sin valor" no siempre es `NULL`.** En `AMORTIZA.FECHABAJA`, "sin baja" es `31/12/9999`; en
  centros de coste de apuntes, un código por defecto con padding. Un `NULL` inesperado en un campo
  así suele delatar una escritura defectuosa.
- **A3ERP no siempre declara relaciones formales (FK).** Buscar relaciones por convención de nombre
  de columna (sufijos compartidos, mismo dominio de valores) y verificarlas cruzando datos reales, no
  solo confiar en `INFORMATION_SCHEMA.KEY_COLUMN_USAGE` (puede estar incompleto).

---

## Proceso paso a paso para investigar una tabla o área nueva

1. Leer `CONEXION_PBI.xml` y conectar contra la base de datos real del cliente.
2. Enumerar objetos candidatos por nombre aproximado en `INFORMATION_SCHEMA.TABLES` (filtrando
   `TABLE_TYPE` para distinguir `BASE TABLE` de `VIEW` desde el principio).
3. Sacar la estructura de columnas (`INFORMATION_SCHEMA.COLUMNS`): nombre, tipo, nulabilidad.
4. Muestrear filas reales (`SELECT TOP 20 ...`) para verificar el significado real de las columnas
   ambiguas — nunca confiar solo en el nombre.
5. Buscar relaciones no declaradas con otras tablas ya conocidas (columnas de nombre similar,
   valores que cruzan).
6. Documentar el hallazgo en `docs/esquema/` de esta skill (ver plantilla abajo), aunque sea parcial —
   así no hay que re-descubrirlo la próxima vez, en este proyecto o en otro cliente.

---

## Plantilla de documentación de tabla/vista

```markdown
# [Tabla|Vista]: [NOMBRE]

**Módulo A3ERP**: [Facturación / Clientes / Artículos / ...]
**Tipo de objeto**: TABLE / VIEW
**Descripción**: [qué representa]

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| [COLUMNA] | [TIPO] | Sí/No | [gotcha si aplica: CHAR con padding, semántica verificada, etc.] |

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|

## Notas / gotchas
- [cualquier hallazgo empírico: vista vs tabla, jerarquía como lista de adyacencia, semántica de
  columna verificada contra datos reales, decisiones de negocio relevantes al filtrar/agregar]
```

---

## Catálogo de exploración por módulo

| Módulo | Tablas/vistas exploradas | Estado |
|---|---|---|
| Facturación | Facturas, LineasFactura | ✅ explorado (proyecto A3ERP-PowerBI) |
| Clientes | Clientes (VIEW), `__CLIENTES` (campos de cuenta, NIF-IVA) | ✅ explorado (proyecto A3ERP-PowerBI; campos de cuenta y nombres en proyecto RocRoi) |
| Artículos/Almacén | Articulos, FamiliasArticulo, Familia_Estadis (VIEW), SIE_ESTRUCTURASFAMILIAARTICULO | ✅ explorado (proyecto A3ERP-PowerBI) |
| Comercial | Representantes, CABEPEDC/CABEPEDV (cabeceras Pedido Compra/Venta) | ✅ explorado (proyecto A3ERP-PowerBI; pedidos: proyecto INTEMAN) |
| Utilidades (no A3ERP) | Calendario (tabla calculada DAX, no vive en SQL Server) | ✅ explorado (proyecto A3ERP-PowerBI) |
| Sistema (A3ERP$SISTEMA) | EMPRESAS | ✅ explorado (proyecto A3ERP-PowerBI) |
| Contabilidad | CUENTAS, __ASIENTOS (vista APUNTES), Ape_Saldos_PYG_Version_NPGC (VIEW), Ape_Saldos_Con_Analitica (VIEW), CENTROSC, DEPARTAMENTOS, PRESUP, LINEPRES (vista Presupuestos) | ✅ explorado (proyecto A3ERP-PowerBI, dashboard EBITDA, cliente EHEALTH; CENTROSC ampliado con campo de terceros en proyecto INTEMAN; analítica en apuntes, TIPAPU y presupuesto mensual en proyecto FMMC) |
| Compras | Ver CABEPEDC en `comercial/PedidosCompraVenta.md`; CABEFACC (`facturacion/FacturasCompra.md`); líneas de compra en `LineasFactura.md` (IDFACC, CTACONL, BASEMONEDA); `__PROVEED` (`compras/Proveedores.md`) | 🔶 parcial (proyectos INTEMAN, GestionImnovilizado y RocRoi) |
| Inmovilizado | AMORTIZA (`contabilidad/AMORTIZA.md`) | ✅ explorado (proyecto GestionImnovilizado, X_DEMO 2026-10) |
| Transversal / extensiones | VINCULOS, DLLS (`sistema/`) | ✅ explorado (proyecto GestionImnovilizado) |
| Tesorería | `CARTERA`: solo una nota (no tiene columna de cuenta), en `contabilidad/CUENTAS.md` | ⏳ pendiente |

Detalle de cada tabla en `docs/esquema/[modulo]/[tabla].md`.

---

## Checklist antes de dar un esquema por entendido

- [ ] Tipo de objeto confirmado (`TABLE` vs `VIEW`) en `INFORMATION_SCHEMA.TABLES`
- [ ] Columnas de interés muestreadas con datos reales, no solo inferidas por el nombre
- [ ] Relaciones no declaradas verificadas cruzando datos, no solo asumidas por convención de nombre
- [ ] Campos `CHAR` de longitud fija revisados por necesidad de `TRIM`
- [ ] Hallazgo documentado en `docs/esquema/` para no repetir la investigación

---

## Relación con las otras skills de A3ERP

- **`a3rp-diccionarios`**: para crear o extender campos/tablas oficiales reconocidos por A3ERP —
  distinto de esta skill, que es solo lectura del esquema real de SQL Server.
- **`a3rp-api-com`**: para cualquier operación de negocio (crear/modificar registros) — siempre
  preferible a escribir en SQL directo, que se salta validaciones y triggers de A3ERP.
- Excepción conocida a "escribir solo vía API": `VINCULOS` (el objeto `Maestro` no la admite) y la
  actualización de baja en `AMORTIZA` de GestionImnovilizado, ambas con SQL parametrizado (reglas de
  ADODB en `a3rp-api-com`).
- **Cargas con in&out** (clientes, proveedores, direcciones): lo aprendido está en
  `docs/herramientas/inout-maestros-clientes-proveedores.md` (en la raíz de `.claude`).
- **`a3rp-dll`**: normalmente no necesita SQL directo — accede a A3ERP vía la API COM, así que rara
  vez cruza con esta skill salvo para entender de dónde vienen los datos que expone la API.
