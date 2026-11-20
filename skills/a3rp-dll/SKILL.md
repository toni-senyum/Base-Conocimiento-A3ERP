---
name: a3rp-dll
description: >
  Usa esta skill para crear, modificar, depurar, compilar, registrar o empaquetar una DLL que a3ERP
  (Asesor Plus / a3ERP, Wolters Kluwer) CARGA Y LLAMA: tanto una DLL de EVENTOS (a3ERP la llama
  cuando ocurre algo: guardar un documento o maestro, cambiar un campo, imprimir, entrar/salir de
  una empresa...) como una DLL de PROGRAMAS EXTERNOS (el usuario pulsa el botón del rayo de una
  ficha y a3ERP llama a `Opcion(IdOpcion, Parametro)`). Actívala cuando el usuario mencione: DLL de
  eventos, enganchar/engancharse a un evento de a3ERP, AntesDeGuardar / DespuesDeGuardar, programas
  externos, botón del rayo, `@ProgID@Opcion`, registrar una DLL en la tabla DLLS,
  ListaProcedimientos, RegAsm / registro COM, instalador o paquete de una extensión, o cualquier
  desarrollo que deba reaccionar a una acción del usuario dentro de a3ERP. Si en cambio lo que
  se necesita es que TU código llame a a3ERP desde fuera (crear una factura, leer un maestro,
  automatizar algo externamente) → usa `a3rp-api-com`. Ver también `a3rp-diccionarios` para
  extender tablas/campos antes de leerlos/escribirlos desde esta DLL, y `a3rp-modelo-datos-sql`
  para entender el esquema real de las tablas que toque la DLL.
---

# Skill: DLLs de a3ERP (eventos y programas externos)

## Qué hace esta skill
Guía la creación de las dos clases de DLL que a3ERP carga y llama:

| Tipo | Quién la dispara | Método de entrada | Proyecto de referencia |
|---|---|---|---|
| **DLL de eventos** | a3ERP, automáticamente, al guardar/borrar/cambiar algo | Métodos con nombre fijo (`AntesDeGuardarDocumentoV2`…) | INTEMAN, `ValidacionOfertasCompraCL` |
| **DLL de programas externos** | El usuario, pulsando el botón del rayo de una ficha | `Opcion(string IdOpcion, string Parametro)` | `GestionImnovilizado` (v1.2.0, 2026-10) |

El patrón de eventos está validado en el proyecto INTEMAN (traspaso de persona responsable de
centro de coste a pedidos) y confirmado contra código real en producción de Senyum
(`ValidacionOfertasCompraCL`). El de programas externos, en `GestionImnovilizado` (alta de
inmovilizado desde factura de compra y baja con asiento), ver sección "DLL de programas externos".

Las secciones de **compilación, registro COM, identidad COM y empaquetado** aplican a los dos tipos.

**Nunca inventar nombres de eventos, de tablas o de métodos.** Todo lo de este documento viene de
la guía oficial (`Manual Eventos A3ERP 2022.pdf`, disponible en `docs/api-com/` si existe en el
proyecto) y de código real ya desplegado. Si hace falta un evento no cubierto aquí, consultar el
manual antes de asumir su firma.

---

## El error más caro que se puede cometer aquí

Hubo una hipótesis de diseño (basada solo en la lectura del manual) que decía que la DLL debía
implementar `IniciarGeneral` y recibir la conexión a base de datos ya inyectada como parámetro.
**Es incorrecta en la práctica** — ningún ejemplo real encontrado la usa así. El patrón real,
confirmado en código de producción, es mucho más simple (ver sección "Conexión a base de datos").
**Regla general: antes de dar una hipótesis de este manual por buena, contrástala contra una DLL de
eventos real ya desplegada si hay alguna disponible** (ver "Dónde buscar código de referencia"
abajo) — el manual a veces documenta variantes que la práctica real no usa.

---

## Estructura mínima de la clase

```csharp
using System.Runtime.InteropServices;

[ComVisible(true)]
[ClassInterface(ClassInterfaceType.None)]
public class EventosMiProducto
{
    // Obligatorio: a3ERP lo llama primero para saber qué eventos implementamos.
    // Nombre EXACTO confirmado en manual oficial y en código real: "ListaProcedimientos"
    // (NO "ObtenerEventos", pese a que así aparece en algunas notas/apuntes no oficiales).
    public object[] ListaProcedimientos()
    {
        return new object[] { "Iniciar", "Finalizar", "AntesDeGuardarDocumentoV2" };
    }

    private Enlace enlace;          // a3ERPActiveX.Enlace — ver a3rp-api-com
    private object conexionEmpresa; // ADOCONNECTION, obtenida vía Enlace, nunca creada a mano

    // Ciclo de vida — ver sección siguiente
    public void Iniciar(string connEmpresaNexus, string connSistemaNexus)
    {
        enlace = new Enlace();
        enlace.Iniciar("", "");
        conexionEmpresa = enlace.GetConexionDB("EMPRESA");
    }

    public void Finalizar()
    {
        conexionEmpresa = null;   // soltar referencia, NUNCA cerrarla
        enlace = null;
    }

    public bool AntesDeGuardarDocumentoV2(string documento, double idDoc, object cabecera,
                                           object lineas, int estado)
    {
        try
        {
            // lógica del evento — ver "Reglas duras" antes de escribir nada aquí
            return true;
        }
        catch
        {
            // JAMÁS dejar que una excepción salga de aquí — ver "Reglas duras"
            return true;
        }
    }
}
```

Reglas de la guía oficial sobre esta estructura:
- Los métodos que reciben eventos deben ser **públicos**.
- `ListaProcedimientos()` (o el nombre real usado por la versión de a3ERP instalada — **no
  case-sensitive**, pero verificarlo con un log si algo no se dispara) es obligatorio y se llama
  antes que cualquier evento, para saber cuáles implementamos.
- Un evento no listado en `ListaProcedimientos()` simplemente no se llama nunca — no hace falta
  "desactivarlo" de otra forma.
- Compilar siempre **x86 (Platform Target)** — nunca "Any CPU" ni x64. En Windows de 64 bits, "Any
  CPU" compila como 64 bits y a3ERP (registrado en 32 bits) no la encuentra. Error típico: *"no
  puedo encontrarlo"* al instanciar.
- Marcar solo la clase que a3ERP instanciará con `[ComVisible(true)]` (mejor que marcar todo el
  ensamblado como COM Visible desde Propiedades del proyecto — más selectivo).
- En Visual Studio, "Registrar para interoperabilidad COM" sustituye a ejecutar `regasm`
  manualmente en la máquina de desarrollo (en producción sí hay que ejecutarlo a mano).
  ⚠️ **Tiene una trampa grave con varias configuraciones de compilación**: ver sección
  "Compilación y registro COM" antes de activarlo.

---

## Ciclo de vida y conexión a base de datos (patrón real confirmado)

El flujo real (visto en `Principal.cs` de `ValidacionOfertasCompraCL`, DLL de eventos de Senyum ya
en producción):

1. **`Iniciar(string connEmpresaNexus, string connSistemaNexus)`** — se dispara al entrar en una
   empresa de a3ERP. Los dos parámetros (cadenas de conexión ADO sin contraseña) llegan pero **no
   se usan** para conectar.
2. Dentro de `Iniciar` (o en el constructor), la propia DLL crea **su propio objeto COM**
   `a3ERPActiveX.Enlace` y lo inicializa vacío:
   ```csharp
   enlace = new Enlace();
   enlace.Iniciar("", "");
   ```
3. Se obtiene la conexión ADO real, ya autenticada, con:
   ```csharp
   conexionEmpresa = enlace.GetConexionDB("EMPRESA"); // o "SISTEMA" para la BD de sistema
   ```
   Esta conexión se guarda en un campo de la clase y se reutiliza en los eventos posteriores
   (p. ej. para un `SELECT` propio contra alguna tabla). Es un objeto `ADOCONNECTION` — ver
   `a3rp-api-com` para más detalle del objeto `Enlace`.
4. **Regla explícita de la guía: esta conexión JAMÁS debe cerrarse** — cerrarla cierra la conexión
   real que usa a3ERP. Tampoco crear una conexión propia con usuario/password aparte: consumiría
   una licencia adicional de a3ERP sin necesidad.
5. **`Finalizar()`** se dispara al desconectar de la empresa (cierre de app o cambio de empresa).
   Soltar las referencias (`= null`) pero no cerrar nada explícitamente.

Existen variantes más antiguas/alternativas en el manual (`IniciarConSistema`, `IniciarGeneral` —
esta última añade además las interfaces COM de conexión ya abiertas como parámetro) pero **no hay
evidencia de que se usen en la práctica real** — usar el patrón `Iniciar` + `Enlace.GetConexionDB`
salvo que se encuentre una razón concreta para lo contrario.

---

## Eventos de guardado de documentos (pedidos, facturas, albaranes...)

- **`AntesDeGuardarDocumentoV2(string documento, double idDoc, object cabecera, object lineas, int estado)`**
  → `bool`. Se dispara **antes** de comprometer el guardado. `false` cancela el guardado (llamando
  después a `UltimoMotivo()` si está implementado, para pedir un mensaje al usuario). `Cabecera` es
  editable — incluye campos de diccionario de terceros — así que es el sitio recomendado para leer
  y también **escribir** campos de cabecera en la misma transacción del guardado.
  - `documento`: `OC`/`OV` oferta, `PC`/`PV` pedido, `AC`/`AV` albarán, `FC`/`FV` factura,
    `DC`/`DV` depósito, `RE` regularización, `TR` traspaso, `PR` orden de producción (compra/venta
    según la letra final `C`/`V`).
  - `estado`: 0=Alta, 1=Modificación, 2=Borrado, 3=Sirviendo líneas, 4=Anulando líneas,
    5=Revertir anulación.
  - Preferir siempre la versión V2 sobre `AntesDeGuardarDocumento` (sin V2) — la guía la desaconseja
    explícitamente a favor de esta.
- **`DespuesDeGuardarDocumentoV2(string documento, double idDoc, int estado)`** — se dispara cuando
  los cambios ya están en firme en BD. Usar solo cuando la modificación no se pueda hacer desde la
  versión "Antes" (p. ej. si hace falta el documento ya guardado para tocar tablas de terceros).
- **`UltimoMotivo()`** → `string` — a3ERP lo llama tras un `false` en `AntesDeGuardarDocumento(V2)`
  para pedir el mensaje a mostrar al usuario. Cadena vacía = sin mensaje.

### Formato del parámetro `Cabecera` (y `Lineas`) — confirmado con código real

Es del tipo compuesto `Conjunto de Datos` de la guía: una matriz cuyo primer elemento es el número
de `Registro`s, y cada `Registro` es a su vez una matriz `[nºCampos, Campo1, Campo2, ...]` donde
cada `Campo` es `object[] {NombreCampo, Valor}`. `Cabecera` trae siempre exactamente 1 `Registro`.

Confirmado con código real (`Utils\CabeceraMapper.cs` de `ValidacionOfertasCompraCL`, que solo
lee — la escritura sigue sin un ejemplo real encontrado, solo la afirmación de la guía):
```csharp
object[] registroCabecera = ((cabecera as object[])[1] as object[]);
// registroCabecera[0] = número de campos
// registroCabecera[1..n] = cada uno object[] {NombreCampo, Valor}
```
**Antes de dar por buena la escritura en un proyecto nuevo**: probar con una DLL mínima que
escriba un valor de prueba y confirmarlo por GUI/SQL — no asumir que "leer y escribir son
simétricos" sin comprobarlo.

---

## DLL de programas externos (botón del rayo)

Patrón verificado en `GestionImnovilizado` (repo `senyum-team/GestionImnovilizado`, v1.2.0). Útil
cuando la acción la **decide el usuario** desde una ficha concreta (p. ej. "generar inmovilizado
desde esta factura de compra"), en vez de reaccionar automáticamente a un guardado.

### Contrato COM

```csharp
[ComVisible(true)]
[Guid("F23C64C5-....")]                       // IID fijo, ver "Identidad COM fija"
public interface IActiveX
{
    object[] ListaProcedimientos();           // devuelve { "INICIAR", "FINALIZAR", "OPCION" }
    void Iniciar(string conexionSistema, string conexionEmpresa);
    void Finalizar();
    void Opcion(string IdOpcion, string Parametro);   // punto de entrada real
}

[ComVisible(true)]
[Guid("51588E90-....")]                       // CLSID fijo
[ProgId("MiProducto.ActiveX")]
[ClassInterface(ClassInterfaceType.None)]
public class ActiveX : IActiveX { ... }
```

### Configuración en a3ERP

`Otros → Mantenimiento de programas externos` (requiere `Datos generales → Preferencias → Activar
programas externos`). Se elige la **Tabla** (la ficha donde aparecerá el botón) y se añade una fila:

| Campo | Valor |
|---|---|
| Programa o librería | `@<ProgID>@<IdOpcion>` — p. ej. `@GestionImnovilizado.ActiveX@BAJA` |
| Descripción | Texto que verá el usuario en el menú del rayo (p. ej. "Generar baja") |
| Procedimiento de la DLL | *(vacío)* |

- Lo que va **tras la segunda `@` es el `IdOpcion`** que recibe `Opcion()`. No poner
  `@ProgID@Opcion` (error real que estuvo documentado en el proyecto y no funciona).
- a3ERP pasa en `Parametro` **la clave del registro abierto** en la ficha. Verificado:
  tabla *Amortizaciones* → `CODAMO` (con el padding de espacios del campo, p. ej. `"      26"`);
  tabla *Cabeceras de facturas de compra* → `IDFACC`.
- En la ficha aparece un **botón con forma de rayo** (junto a Código en el inmovilizado, junto a
  Ref. en la factura de compra). Si hay varios programas en la misma tabla, el rayo despliega un
  **menú con la Descripción** de cada uno → que sea clara.
- La DLL también debe estar en la tabla `DLLS` de cada empresa (ver "Registro en a3ERP").

### Conexión dentro de `Opcion`

```csharp
var enlace = new Enlace();
enlace.SelecEmpresaActiva();                                // empresa que el usuario tiene abierta
var conexion = (ADODB.Connection)enlace.GetConexionDB("EMPRESA");
if (conexion != null && conexion.State == 1) { /* ... */ }  // 1 = abierta. NUNCA cerrarla.
```

### Diferencias con la DLL de eventos

- **Aquí sí se muestran formularios** (Windows Forms modales con `ShowDialog()`): la acción la ha
  pedido el usuario. La regla "nunca pantallas" es de los eventos.
- Cada `Opcion` debe capturar sus excepciones y mostrar un `MessageBox` comprensible; nunca dejar
  que una excepción vuelva a a3ERP.
- No hay transacción compartida: `Maestro`/`Asiento` usan su propia conexión interna, distinta de
  la ADO de `GetConexionDB`. Diseñar el proceso para que, si falla a mitad, quede consistente
  (p. ej. grabar el vínculo justo después de cada `Guarda`, no todos al final) y **decirle al
  usuario qué se creó y qué no**.
- Proteger la operación contra repeticiones (p. ej. no volver a crear inmovilizado desde una línea
  de factura que ya lo tiene: comprobar por `IDLIN`).

---

## Compilación y registro COM (aplica a los dos tipos)

### ⚠️ Trampa: la caché de registro COM de MSBuild desregistra la DLL

Con `RegisterForComInterop=true`, MSBuild guarda en `obj\` una caché
(`*.csproj.UnmanagedRegistration.cache`). **Cualquier compilación posterior con
`RegisterForComInterop` desactivado que comparta esa carpeta `obj\` ejecuta el desregistro
automáticamente** (target `UnmanagedUnregistration`). Resultado real en GestionImnovilizado: la DLL
instalada en a3ERP quedó sin ProgID/CLSID/TypeLib tras un simple Rebuild de Debug, sin ningún aviso.

Solución aplicada (verificada):
- Tres configuraciones separadas:

| Configuración | Salida | Registro COM | Uso |
|---|---|---|---|
| `Debug` | `bin\Debug\` | No | Comprobar que compila. **No toca a3ERP** |
| `DebugA3ERP` | Carpeta `Extensiones\...\Binarios\` (vía propiedad sobrescribible, p. ej. `$(MSBuildProgramFiles32)\A3\ERP\...`) | Sí | Probar en el a3ERP local. VS como administrador |
| `Release` | `bin\Release\` | No | Generar el paquete de distribución |

- `PlatformTarget=x86` en el `PropertyGroup` global (aplica a todas), no solo en Debug.
- **Caché de registro e `IntermediateOutputPath` por configuración**, para que una no desregistre
  lo que registró otra.
- Nunca `OutputPath` relativo con `..\..\..\` hacia `Program Files`: depende de la profundidad de la
  carpeta del proyecto.
- Cualquier compilación "de prueba" con salida redirigida debe usar también su propia carpeta `obj`
  (`/p:IntermediateOutputPath=...`).

### Identidad COM fija (imprescindible si la DLL se distribuye)

Sin atributos explícitos, .NET calcula CLSID/IID/TypeLib a partir de nombres y versión del
ensamblado: cambiar la versión o renombrar algo deja a a3ERP sin encontrar la clase en el cliente.
- `[Guid]` + `[ProgId]` explícitos en la clase y `[Guid]` en la interfaz (copiar los valores con los
  que ya está registrada si la DLL ya existe).
- `[assembly: ComVisible(false)]` y `[ComVisible(true)]` solo en la clase y la interfaz que a3ERP
  usa. Con el ensamblado entero visible se registran formularios, DTOs e interfaces internas cuyos
  GUID cambian con cada versión.
- `[assembly: TypeLibVersion(1, 0)]` fijo; si no, la TypeLib cambia de versión con el ensamblado.
- Verificar tras instalar que ProgID → CLSID → `InprocServer32` (vista `WOW6432Node`) → `CodeBase`
  apuntan a la DLL de `Binarios\`, y que solo cambia la subclave de versión del ensamblado.

### Trazas

`Trace.WriteLine` (no `Debug.WriteLine`): Release solo define `TRACE`, así que con `Debug` la traza
desaparece justo en la DLL que se distribuye. Se ven con DebugView (Sysinternals).

---

## Reglas duras (de la guía oficial — nunca saltárselas)

- **Nunca mostrar pantallas visuales** dentro de un evento, salvo que el propio evento lo pida
  explícitamente (p. ej. llamadas a pantallas externas).
- **La DLL jamás debe lanzar una excepción.** Envolver el cuerpo de cada evento en `try/catch`; ante
  un error inesperado, hacer log y devolver el valor que deja continuar el flujo normal (`true` en
  los eventos booleanos de "Antes...") en vez de romper la operación del usuario.
- **No asumir que los eventos llegan agrupados para una única entidad** — a3ERP puede trabajar con
  varios documentos/maestros a la vez y disparar eventos intercalados. Si hace falta compartir
  estado entre llamadas, etiquetarlo por documento/IdDoc, nunca en una variable de instancia sin
  clave.
- Activar el log de DLLs durante desarrollo/pruebas: `%APPDATA%\A3\CONFIGURACION.INI` →
  ```ini
  [DLLS]
  Log=1
  ```
  genera log en `%APPDATA%\A3\LOGS\DLLS` — indica qué métodos se han llamado, con qué orden, y si
  alguno lanzó una excepción. Es la forma más rápida de confirmar empíricamente (en vez de
  adivinar) si `ListaProcedimientos` está devolviendo lo que a3ERP espera y si el evento se disparó.

---

## Registro en a3ERP (tabla `DLLS`)

```sql
if not exists(select IDDLL from DLLS where DLL = 'Namespace.NombreClase')
begin
   declare @id int
   select @id = max(iddll) + 1 from dlls
   insert into dlls(iddll, dll, fabricante, producto, ORDENDEEJECUCION)
   values(@id, 'Namespace.NombreClase', 'FABRICANTE', 'PRODUCTO', 1)
end
```
- `DLL` = nombre completo de la clase COM a instanciar (namespace + clase en .NET; en VB.NET,
  `NombreDLL.NombreClase`). Si se cambia el namespace principal del proyecto, cambia también este
  valor.
- `FABRICANTE`/`PRODUCTO` son libres para una DLL COM (no tienen por qué coincidir con la ruta),
  pero es recomendable que sí coincidan con la carpeta real en
  `Extensiones\<Fabricante>\<Producto>\Binarios\` donde se copian los binarios, por consistencia.
- La tabla `DLLS` está en la base de datos **de cada empresa**: el alta se hace una vez por empresa.
  La columna es `ORDENDEEJECUCION` (no `ORDENEJECUCION`, error que llegó a estar documentado).
- Registrar la librería COM con el RegAsm **de 32 bits** (como Administrador) si no se hizo ya en
  desarrollo vía "Registrar para interoperabilidad COM" de Visual Studio:
  `%WINDIR%\Microsoft.NET\Framework\v4.0.30319\RegAsm.exe "<dll>" /codebase /tlb` —
  **nunca** el de `Framework64`. El aviso `RA0000` por registrar con `/codebase` una DLL sin firmar es
  esperado.
- Alternativa: registrar la fila de `DLLS` desde una actualización de diccionario (útil si el
  producto ya tiene uno) — en ese caso, la actualización SQL debe diseñarse para ejecutarse una
  única vez, o se duplicará el registro en cada aplicación de actualizaciones.

---

## Empaquetado y distribución a clientes

Patrón implantado en `GestionImnovilizado` (`build/empaquetar.ps1` + plantillas en
`build/paquete/`), probado instalando el paquete sobre el a3ERP local:

- **Script de empaquetado** que compila `Release` (localizando MSBuild con `vswhere`), lee la versión
  del ensamblado compilado y genera `dist\<Producto>_<versión>\` + `.zip` con: `Binarios\` (DLL y
  dependencias que deje Release, p. ej. `ADODB.dll`; sin `.pdb`), `instalar.cmd/.ps1`,
  `desinstalar.cmd/.ps1`, `registrar_dll.sql`, `LEEME.txt` y `CHANGELOG.md`. `dist/` en `.gitignore`.
- **`instalar.ps1`**: comprueba administrador y que `a3ERP.exe` **no** está en ejecución (si lo
  está, sale sin tocar nada; nunca lo cierra) → copia de seguridad de `Binarios\` en
  `%ProgramData%\<Fabricante>\<Producto>\backup_<fecha>\` → desregistra la versión anterior →
  vacía `Binarios\` → copia → registra con RegAsm x86 → verifica ProgID/CLSID/CodeBase → log. Si algo
  falla, restaura la copia y la vuelve a registrar.
- **Copias de seguridad SIEMPRE fuera de la carpeta `Extensiones`**: a3ERP carga extensiones desde ahí
  y una DLL duplicada en una subcarpeta es un riesgo.
- Al vaciar `Binarios\`: comprobar que la ruta termina exactamente en
  `\Sistema.Custom\Sistema\Extensiones\<Fabricante>\<Producto>\Binarios` y abortar si `Binarios`
  o algo dentro es un enlace (junction/symlink). Nunca borrar la carpeta del producto: ahí conviven
  `diccionarios`, `Iconos`, `Menús`… que no son de la DLL.
- `*.cmd eol=crlf` en `.gitattributes` (cmd.exe falla con LF).
- **`registrar_dll.sql`** idempotente (`IF NOT EXISTS`) para ejecutar en cada empresa.
- **Versionado**: `AssemblyVersion`/`FileVersion`/`InformationalVersion`, `CHANGELOG.md` (Keep a
  Changelog), etiqueta git anotada `vX.Y.Z` y release en GitHub con el zip y su SHA256 en las notas
  (`gh release create ... --verify-tag`). Comprobar que la DLL del zip tiene el mismo hash que la
  instalada y probada.
- 🔴 **Sin `PathMap`, la DLL incrusta la ruta absoluta del PDB** (`C:\Users\<usuario>\OneDrive -
  ...\Clientes\<cliente>\...\obj\Release\X.pdb`): cualquiera que reciba el zip ve el usuario de
  Windows, la carpeta y el nombre del cliente. En el `.csproj`:
  ```xml
  <Deterministic>true</Deterministic>
  <PathMap Condition=" '$(Configuration)' != 'DebugA3ERP' ">$([MSBuild]::EnsureTrailingSlash('$(MSBuildProjectDirectory)'))=/_/</PathMap>
  ```
  La ruta queda como `/_/obj/<config>/X.pdb`. Se excluye `DebugA3ERP` porque es la de depurar dentro
  de a3ERP y necesita las rutas reales. Comprobar buscando en la DLL (`findstr`/`strings`) que no
  aparecen `C:\Users`, `OneDrive` ni el nombre del cliente. Verificado en GestionImnovilizado,
  2026-10; las releases 1.1.0 y 1.2.0, anteriores al cambio, quedaron marcadas como de uso interno.
- **Producto estándar**: si la DLL se va a instalar en más de un cliente, el repo no lleva nombres,
  datos ni pendientes de clientes concretos (lo de cada instalación va a su Jira), y una sección
  «Requisitos y supuestos» documenta los valores fijos: diario y tipo del asiento, divisa, prefijos
  de cuentas, `COLLATE`, versión de a3ERP con la que se comprobaron las firmas COM.

---

## Dónde buscar código de referencia real (antes de programar a ciegas)

Antes de implementar un evento nuevo o dudar del formato de un parámetro, **buscar si ya existe una
DLL de eventos real desplegada** cuyo código fuente esté accesible en algún proyecto de cliente
(no solo el `.dll` compilado en `Extensiones\<Fabricante>\<Producto>\Binarios\`, que no sirve de
referencia de código). Ejemplo ya usado con éxito en el proyecto INTEMAN: código fuente de
`ValidacionOfertasCompraCL` en
`Clientes\Federación Catalana Natacion\Desarrollos\A3ERPValidacionOfertasCompra\ClassLibrary\` —
confirmó tanto el patrón de conexión (`Enlace`/`GetConexionDB`) como el formato real de `Cabecera`
(`Utils\CabeceraMapper.cs`), corrigiendo una hipótesis de diseño basada solo en el manual.

Para **programas externos, objetos `Maestro`/`Asiento`/`Opcion`, configuraciones de compilación,
identidad COM e instalador**: `GestionImnovilizado` en `C:\SENYUM\GestionImnovilizado\` (repo
`senyum-team/GestionImnovilizado`, rama `main`; producto estándar sin datos de clientes). Su
`CLAUDE.md`, `docs/a3ERPACTIVEX_usage.md`, `docs/ARCHITECTURE.md` (incluye «Requisitos y supuestos»)
y `docs/HISTORICO_BUGS.md` documentan cada fallo encontrado y su causa real; lo abierto está en
`docs/ESTADO_Y_PENDIENTES.md`.

---

## Buenas prácticas de arquitectura y control de versiones (git/GitHub)

Aunque el "pegamento" COM de estas DLLs es forzosamente rígido (nombres de método fijos, tipos
`object[]` sin tipar, imposible de testear sin a3ERP corriendo), eso no es excusa para que el resto
del proyecto sea igual de rígido. Aplicar siempre:

**Arquitectura — separar el pegamento COM de la lógica de negocio**
- La clase `[ComVisible(true)]` con `ListaProcedimientos`/`Iniciar`/`Finalizar`/los eventos debe ser
  una capa **fina**: solo recibe el evento, delega en clases internas normales, y decide qué
  devolver. Nunca meter la lógica de negocio (parseo de `Cabecera`, consultas SQL, reglas de
  decisión) directamente en el cuerpo del método de evento.
- Extraer a clases/métodos aparte, sin dependencia de tipos COM, todo lo que se pueda probar sin
  a3ERP corriendo: el mapeo `object[]` ↔ diccionario de campos (reutilizable entre proyectos, ver
  `CabeceraMapper.cs` como precedente), y la lógica de negocio pura (p. ej. "dado un centro de
  coste, ¿qué persona corresponde y hay que escribirla o no"). Estas clases sí se pueden cubrir con
  tests unitarios (xUnit/NUnit) pasándoles datos de ejemplo, aunque el propio evento COM no se
  pueda testear en aislamiento.
- Centralizar el logging en una clase propia (p. ej. `Logger.Log(string mensaje)` a fichero) en vez
  de esparcir `File.AppendAllText` sueltos por cada evento — facilita activar/desactivar detalle y
  mantener un formato consistente.
- Nunca dejar que una excepción de la capa de negocio llegue sin capturar a la capa COM — cada
  evento público atrapa cualquier excepción de las clases internas, hace log y devuelve el valor
  seguro (ver "Reglas duras").

**Control de versiones — un repo git por DLL/proyecto**
- 🔴 **Norma de Senyum (2026-10):** cada proyecto es un repositorio **privado en `senyum-team`**,
  con el mismo nombre que su carpeta en `C:\SENYUM\` (fuera de OneDrive: git dentro de una carpeta
  sincronizada da conflictos y bloqueos). Los proyectos nuevos nacen de `plantilla-proyecto`; los
  anteriores a la plantilla se suben con `senyum-github → proyecto-anterior.md`. Control de secretos
  instalado en cada PC, trabajo en rama propia y cambios por PR. El procedimiento completo está en
  la skill `senyum-metodo:senyum-github`; no duplicarlo aquí.
- Cada DLL vive en su propio repositorio desde el primer commit del proyecto de Visual Studio — no
  dejar el desarrollo sin versionar mientras se prueba.
- `.gitignore` de Visual Studio desde el principio (plantilla estándar de GitHub para VS: excluye
  `bin/`, `obj/`, `.vs/`, `*.user`, `*.suo` — no subir binarios compilados ni ficheros de usuario
  locales al repo).
- Commits atómicos y descriptivos por cambio funcional (no un único commit gigante al final) — así
  el histórico documenta el propio proceso de "hipótesis → verificación empírica → corrección" que
  es habitual en estos proyectos (ver "El error más caro que se puede cometer aquí").
- Rama `main` estable; cambios grandes o arriesgados (p. ej. cambiar el campo destino de la
  escritura, o un evento nuevo) en una rama de feature aparte hasta confirmarlos en el entorno de
  pruebas (X_DEMO u homólogo).
- `README.md` mínimo en el repo: qué hace la DLL, en qué evento se engancha, cómo se registra
  (tabla `DLLS`), dónde se despliegan los binarios, y qué diccionario(s) de terceros necesita como
  prerrequisito — así no hace falta reconstruir el contexto solo leyendo el código.
- Etiquetar (`git tag`) las versiones que se despliegan a un entorno de cliente real, coherente con
  el `AssemblyVersion`/`AssemblyFileVersion` del proyecto — facilita saber exactamente qué código
  está corriendo en producción si hay que depurar un problema reportado por el cliente.

---

## Checklist antes de entregar una DLL de eventos

- [ ] `ListaProcedimientos()` implementado y devuelve exactamente los eventos usados.
- [ ] Platform Target = x86, clase marcada `[ComVisible(true)]`.
- [ ] Conexión a BD obtenida vía `Enlace.GetConexionDB`, nunca creada con credenciales propias, y
      nunca cerrada.
- [ ] Ningún evento lanza excepciones sin capturar — todo el cuerpo en `try/catch` con log.
- [ ] Ninguna pantalla visual mostrada desde un evento (salvo que el propio evento la contemple).
- [ ] Ningún nombre de tabla/campo inventado — verificado contra `a3rp-modelo-datos-sql` o SQL real.
- [ ] Log de DLLs activado y probado en local antes de dar el desarrollo por bueno.
- [ ] Alta en tabla `DLLS` de la empresa de pruebas, binarios en
      `Extensiones\<Fabricante>\<Producto>\Binarios\`.
- [ ] Probado end-to-end contra un entorno de pruebas (nunca directo contra el entorno real del
      cliente).
- [ ] Lógica de negocio separada del pegamento COM, en clases testeables sin a3ERP corriendo.
- [ ] Repo git inicializado desde el principio, con `.gitignore` de Visual Studio y `README.md`
      mínimo; commits atómicos; versión desplegada etiquetada (`git tag`).

Adicional para DLL de programas externos y para cualquier DLL que se distribuya:
- [ ] Entrada en "Mantenimiento de programas externos" con `@<ProgID>@<IdOpcion>` y una Descripción
      clara; probada desde el botón del rayo.
- [ ] Configuraciones Debug / DebugA3ERP / Release con caché de registro COM separada; ninguna
      compilación de prueba desregistra la DLL instalada.
- [ ] CLSID, IID, ProgID y versión de TypeLib fijos; ensamblado `ComVisible(false)`.
- [ ] Paquete generado desde el commit etiquetado; instalador probado (incluido que se niega con
      a3ERP abierto); DLL del zip = DLL probada (mismo SHA256).
- [ ] `PathMap` + `Deterministic` en Release: la DLL no contiene rutas locales (`C:\Users`,
      OneDrive, carpeta del cliente).
- [ ] Repo sin nombres ni datos de clientes y con «Requisitos y supuestos» documentados.
