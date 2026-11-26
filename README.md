# Base de conocimiento a3ERP para Claude

Base de conocimiento de **a3ERP** (Asesor Plus, Wolters Kluwer) para Claude: skills, documentación de
apoyo y plantillas que Claude Code usa para desarrollar contra a3ERP (API COM, DLLs, diccionarios y
modelo de datos SQL). "A3RP / Asesor Plus" en los documentos es a3ERP.

Ruta: `C:\SENYUM\base-conocimiento` (repositorio git local, sin remoto).

## Estructura de carpetas

```
base-conocimiento/
├── README.md
├── _inbox/            ← notas de captura pendientes de consolidar (una por chat/proyecto)
├── agents/            ← definiciones de agentes
├── docs/
│   ├── api-com/       ← documentación de la API COM
│   ├── diccionarios/  ← diccionarios de tablas y campos
│   ├── dlls/          ← guías de DLLs
│   ├── ejemplos/      ← código de referencia (Ejemplo Completo)
│   └── herramientas/  ← in&out y UTILIDADES (plantillas y tablas Excel/PDF)
├── scripts/           ← utilidades (config.example.ini; config.ini local, ignorado por git)
└── skills/
    ├── a3rp-api-com/
    ├── a3rp-diccionarios/   (reference/plantillas)
    ├── a3rp-dll/
    └── a3rp-modelo-datos-sql/   (docs/esquema: fichas por área)
```

## Skills disponibles

| Skill | Cuándo se activa |
|---|---|
| `a3rp-dll` | DLL que a3ERP carga y llama: de eventos o de programas externos (botón del rayo). Compilación, registro COM, identidad COM fija, empaquetado e instalador |
| `a3rp-api-com` | Llamar a a3ERP desde código vía `a3ERPActiveX` (`Enlace`, `Maestro`, `Asiento`, `Opcion`, documentos) y reglas de SQL con ADODB desde .NET |
| `a3rp-diccionarios` | Crear/extender tablas y campos oficiales de a3ERP (diccionarios) |
| `a3rp-modelo-datos-sql` | Entender el esquema SQL real (lectura, informes, Power BI); fichas en `skills/a3rp-modelo-datos-sql/docs/esquema/` |

Documentos de apoyo fuera de las skills: `docs/herramientas/inout-maestros-clientes-proveedores.md`
(cargas de clientes y proveedores con in&out).

## Proyectos de referencia

| Proyecto | Qué demuestra | Dónde |
|---|---|---|
| `ValidacionOfertasCompraCL` | DLL de eventos real: `Iniciar` + `Enlace.GetConexionDB`, formato de `Cabecera` | `Clientes\Federación Catalana Natacion\Desarrollos\A3ERPValidacionOfertasCompra\` |
| INTEMAN | DLL de eventos `AntesDeGuardarDocumentoV2` sobre pedidos | (ver skill `a3rp-dll`) |
| `GestionImnovilizado` (v1.2.0) | DLL de programas externos (alta/baja de inmovilizado), `Maestro`, `Asiento`, `Opcion`, SQL con ADODB, configuraciones Debug/DebugA3ERP/Release, identidad COM fija, `PathMap`, paquete con instalador y releases. Producto estándar, adaptado a `plantilla-proyecto` | `C:\SENYUM\GestionImnovilizado\` · GitHub `senyum-team/GestionImnovilizado` (rama `main`) |
| RocRoi | Migración de maestros de clientes y proveedores con in&out (fusión con Business Central y correcciones): formato, cómo escribe in&out, direcciones, NIF-IVA, regímenes de IVA y borrado de fichas con sus cuentas. Resumen en `docs/herramientas/inout-maestros-clientes-proveedores.md` | `...\Clientes\RocRoi\Migracion\Tratameinto\00_ROCROI PALLARS SOBIRA SL\00_Documentacion_Migracion\` |

## Cómo se cargan estas skills en Claude Code

Claude Code no busca skills por encima de la raíz de un repositorio git, así que las skills no se
cargan como `project` desde `C:\SENYUM\<proyecto>`. Solución: un enlace (junction) por skill en
`%USERPROFILE%\.claude\skills\` que apunta a esta carpeta. Cargan como `user` en cualquier carpeta y
sigue habiendo una sola copia, aquí:

```
set ORIG=C:\SENYUM\base-conocimiento\skills
set DEST=%USERPROFILE%\.claude\skills
for %S in (a3rp-api-com a3rp-diccionarios a3rp-dll a3rp-modelo-datos-sql) do mklink /J "%DEST%\%S" "%ORIG%\%S"
```

- Al añadir una skill nueva, crear también su enlace.
- Para quitar un enlace usar SOLO `rmdir "<enlace>"` (sin `/s`, ni `del`): borrarían el contenido del destino.
- Las normas generales de A3ERP/.NET están en `C:\SENYUM\CLAUDE.md`.

## Cómo se alimenta

- La skill `alimentar-base-conocimiento-senyum` vuelca lo aprendido en un chat o proyecto: propone
  cambios, se aprueban y se aplican aquí.
- Las notas pendientes de consolidar se dejan en `_inbox/` (una por chat/proyecto).
- El historial vive en git (`git log`), y sustituye a los antiguos `.bak`.
