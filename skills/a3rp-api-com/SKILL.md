---
name: a3rp-api-com
description: >
  Usa esta skill cuando el código deba LLAMAR a a3ERP (Asesor Plus / a3ERP, Wolters Kluwer) desde
  fuera, a través del objeto COM `a3ERPActiveX`: conectar con `Enlace`, obtener la conexión ADO
  real a la base de datos de una empresa, crear/modificar pedidos, facturas, albaranes, maestros
  (`Maestro`, `Pedido`, `Factura`, `Albaran`, `Oferta`...), generar asientos (`Asiento`, `AApunte`,
  `AApunteNax`), abrir opciones de a3ERP (`Opcion`), o navegar cualquier objeto de
  `a3ERPACTIVEX`. También para depurar errores COM al instanciar estos objetos y para ejecutar SQL
  propio con ADODB desde .NET (parámetros, fechas, `Command.Execute`). Si en cambio lo que
  se necesita es una DLL que a3ERP CARGA y LLAMA cuando el usuario hace algo dentro del programa
  (guardar un documento, cambiar un campo) → usa `a3rp-dll`. Ver también `a3rp-modelo-datos-sql`
  para entender de qué tablas vienen los datos que expone esta API, y `a3rp-diccionarios` para
  campos/tablas de terceros.
---

# Skill: a3ERPACTIVEX (API COM de a3ERP)

Ver también: `a3rp-dll` para el caso inverso (a3ERP llama a tu código); `a3rp-modelo-datos-sql`
para el esquema real de las tablas.

## Documentación de referencia
Los manuales oficiales viven normalmente en `.claude\docs\api-com\` del proyecto (o donde el
usuario los haya dejado — preguntar si no aparecen):
- `Ultima Vesion ActiveX.pdf` — referencia completa y actual de todos los objetos de
  `a3ERPACTIVEX` (la más fiable; consultarla primero).
- `Manual ActiveX.pdf` — ejemplos de uso más antiguos, útiles como patrones de código puntuales
  (p. ej. consulta SQL directa vía `TAdoQuery`).
- `Manual Eventos A3ERP 2022.pdf` — pertenece a `a3rp-dll`, no a esta skill, pero documenta también
  el objeto `Enlace` desde el ángulo de una DLL de eventos.

**Nunca inventar nombres de objetos, propiedades o métodos de `a3ERPACTIVEX`.** Si el manual no
está disponible, pedirlo antes de generar código contra un método no verificado.

---

## ⚠️ Modelo de objetos real — no es un único objeto raíz "Application"

A diferencia de otras integraciones COM típicas, `a3ERPACTIVEX` **no expone un objeto raíz único**
del que cuelgan submódulos (nada de `A3RP.Application.Facturacion`). Expone una **lista plana de
objetos independientes**, cada uno con su propio CoClass/ProgID, que se instancian por separado
según lo que se necesite. Lista (no exhaustiva, ver `Ultima Vesion ActiveX.pdf` para la completa):

| Objeto | Para qué sirve |
|---|---|
| `Enlace` / `Enlace1450` | Conexión con la BD de una empresa, estado, usuario, obtención de la conexión ADO real. **Punto de entrada obligatorio antes que cualquier otro objeto.** |
| `Varios` / `Varios1201` | Precios, cambios de moneda, identificadores únicos, cuentas, IVA/IGIC. |
| `Maestro` | Navegar/añadir/modificar artículos, proveedores, clientes, cuentas, bancos, almacenes, representantes, transportistas, tarifas, idiomas, etc. |
| `Pedido`, `Oferta`, `Factura`, `Albaran`, `Deposito`, `Regularizacion`, `Traspaso` | Alta/modificación/borrado del documento comercial correspondiente. |
| `Seleccion` | Pantalla estándar de selección de a3ERP para cualquier tabla. |
| `Asiento`, `Cartera`, `OperacionesCartera`, `Agrupacion`, `Remesa` | Contabilidad y cartera de efectos. |
| `Opcion` / `OpcionModal` | Llamar a cualquier opción visual de a3ERP. |
| `Expediente`, `Cuota`, `OrdenProduccion`, `Estructura`, `Presupuesto` | Otros módulos de negocio. |

Cada objeto se instancia con su propia CoClass (patrón Delphi visto en ejemplos reales:
`CoNombreObjeto.Create`; en C#/.NET, vía `Type.GetTypeFromProgID("a3ERPActiveX.NombreObjeto")` +
`Activator.CreateInstance`, o con el Interop generado si se importó la TLB registrada).

Desde versión 14, **todos los objetos implementan `IMensajes`** (`FijarNivel`/`AnularNivel`) para
poder anular/habilitar mensajes visuales (alarmas, avisos) durante la operación.

---

## Objeto `Enlace` — punto de entrada obligatorio

Es el primer objeto a instanciar siempre: abre/cierra la conexión con la BD de una empresa y da
acceso a la conexión ADO real que usa a3ERP internamente.

```csharp
var enlace = new Enlace();
enlace.Iniciar(sEmpresa, sUbicacion);   // sUbicacion está obsoleto, pasar cadena vacía
// ... trabajar ...
enlace.Acabar();                        // solo si la conexión la abriste tú explícitamente así
```

Propiedades relevantes: `bError`, `Nerror`, `SMensaje` (info de error), `Estado` (`EstadoEnlace`:
0 NoActivo, 1 Activo, 2 Conectado), `EmpresaActiva`, `Usuario`, `Conexion` /
`ConexionSistema` (parámetros de conexión, sin contraseña), `VersionA3ERP`.

### `GetConexionDB(Nombre: "EMPRESA" | "SISTEMA")` → conexión ADO real — la forma correcta de hacer SQL propio
```csharp
object conexionEmpresa = enlace.GetConexionDB("EMPRESA"); // tipo ADOCONNECTION
```
Es la manera recomendada de ejecutar SQL propio (`SELECT` de lectura, consultas de apoyo) **sin
abrir una conexión ni sesión adicional** — reutiliza la conexión que a3ERP ya tiene abierta y
autenticada.

🔴 **Regla explícita de la documentación oficial: nunca cerrar la conexión devuelta por
`GetConexionDB`** — cerraría la conexión real que usa a3ERP, no una copia. Tampoco crear una
conexión propia con usuario/contraseña aparte para lo mismo: consumiría una licencia adicional de
a3ERP sin necesidad.

Ejemplo real de consulta directa (patrón Delphi, `TAdoQuery` + `ConnectionString := <objetoConexion>`):
```pascal
query := TAdoQuery.create(nil);
query.ConnectionString := enlaceOConexion; // p. ej. boaEnlace.Conexion, o el objeto de GetConexionDB
query.SQL.Text := 'select IDOPEREMESA FROM __OPEREMESA WHERE IDREMESA = 2';
query.open;
```
En C#, usar `conexionEmpresa` (ya un objeto de conexión ADO) directamente con un `OleDbCommand`/
equivalente en vez de crear una nueva `SqlConnection` con cadena de conexión propia.

### Otras funciones útiles de `Enlace`
- `ParamConexion(sEmpresa, sUbicacion)` → array con tipo de motor (MSSQL), servidor y nombre de BD
  de una empresa — útil para construir una conexión directa fuera del propio proceso de a3ERP.
- `Empresas` → lista de empresas del sistema por defecto.
- `SelecEmpresa` / `SelecEmpresaActiva` / `SelecMultiEmpresaActiva` — selección visual de empresa.
- `ModulosActivos`, `ListaMaestros` — introspección de qué hay activo/disponible.
- `PermisosOpcion(opcion)` → `Permisos` (0 Todo, 1 SoloLectura, 2 Nada) del usuario logado para una
  opción concreta.
- `VersionA3ERP` → versión del ejecutable, formato `Major.Minor.Release.build`.

---

## Objeto `Pedido` (y análogos `Factura`, `Albaran`, `Oferta`, `Deposito`...)

Exponen indexadores tipados para leer/escribir campos de cabecera, línea y componentes/detalle por
nombre de campo físico:

```csharp
pedido.AsStringCab["CENTROCOSTE"]    // leer/escribir un campo string de cabecera
pedido.AsFloatCab["ALGUNCAMPO"]
pedido.AsIntegerLin["CODART"]        // ídem para líneas
```
Variantes: `AsStringCab/AsFloatCab/AsIntegerCab/AsBooleanCab/AsCurrencyCab/AsVariantCab` para
cabecera; sufijo `Lin` para líneas; `Comp` para componentes; `Des` (solo lectura) para detalle.

Métodos típicos: `Nuevo(fecha, codCliPro, esDeCompra)`, `Modifica(idDocu, esDeCompra)`,
`Borra(idDocu, esDeCompra)`, `NuevaLinea`/`NuevaLineaArt`/`EditarLinea`/`BorrarLinea`,
`CalcularImpuestosyTotales`, `Anade` (confirma el alta y devuelve el id). Propiedad
`AvisarCentroCosteCabecera` controla si al cambiar el centro de coste en cabecera se avisa/propaga
a las líneas — confirma que el centro de coste es un concepto nativo de cabecera en estos objetos,
no algo exclusivo de un módulo.

**Esta es la vía recomendada para crear/modificar documentos desde fuera de a3ERP** (automatismos,
integraciones externas) — usar SQL directo solo para lectura/reporting cuando esta API no exponga
el dato (ver `a3rp-modelo-datos-sql`).

---

## SQL propio con ADODB desde .NET — reglas verificadas

Con la conexión de `GetConexionDB` (`ADODB.Connection`) y consultas parametrizadas (`?`):

🔴 **`Command.Execute(out ra, null, opciones)` envía el PRIMER parámetro como `DEFAULT`.** El segundo
argumento de `Execute` no es "nada": es un array de valores de parámetros, y `null` se interpreta como
valor del parámetro 1. Lo que llega a SQL Server (capturado con Extended Events en
GestionImnovilizado):
```
exec sp_executesql N'UPDATE AMORTIZA SET CANCELADA = ''T'', FECHABAJA = DEFAULT, VALORVENTA = @P2 WHERE CODAMO = @P3', ...
```
Si la columna no tiene default queda `NULL` (y si lo tiene, se graba el default) **sin ningún error**.
Este fallo tuvo la fecha de baja a NULL durante meses y no se arreglaba cambiando el tipo del
parámetro. **Usar siempre `Type.Missing`:**
```csharp
cmd.Execute(out object recordsAffected, Type.Missing, (int)ExecuteOptionEnum.adExecuteNoRecords);
```
- **SELECT parametrizado**: `rs.Open(cmd, Type.Missing, CursorTypeEnum.adOpenForwardOnly,
  LockTypeEnum.adLockReadOnly, -1)`. (El error "sintaxis incorrecta cerca de la palabra clave
  'default'" que aparece al hacer SELECT con `Command.Execute(..., null, ...)` es este mismo fallo:
  `WHERE X = DEFAULT`.)
- **Fechas**: parámetro `DataTypeEnum.adDBTimeStamp` con `DateTime` nativo. Nunca texto
  `"dd-MM-yyyy"` con `adVarChar`.
- **Importes**: `adCurrency`. **Códigos con padding** (p. ej. `CODAMO`): pasarlos tal cual llegan de
  a3ERP (`"      26"`) o rellenar con `PadLeft(n)` antes de comparar.
- **Búsqueda sin acentos**: las columnas suelen ser `Modern_Spanish_CI_AS` (distinguen acentos);
  usar `COLUMNA COLLATE Modern_Spanish_CI_AI LIKE ?` y escapar `%`, `_`, `[` en el parámetro.
- `ISNUMERIC` acepta `'1E5'`, `'-'`, `'1,5'`… → usar `TRY_CAST(... AS INT)`.

---

## Objeto `Maestro` — alta/modificación de registros de maestros

Verificado en GestionImnovilizado sobre la tabla `AMORTIZA` (inmovilizado):

```csharp
dynamic m = Activator.CreateInstance(Type.GetTypeFromProgID("a3ERPActiveX.Maestro"));
try
{
    m.Iniciar("AMORTIZA");
    m.Nuevo();
    string codigo = m.NuevoCodigoNum();          // string; Trim() y validar que es entero
    m.AsString["CODAMO"]  = codigo;
    m.AsString["NOMAMO"]  = "Ordenador";
    m.AsFloat["TOTAMO"]   = 1000.0;
    m.AsInteger["IDLIN"]  = idLin;
    m.Guarda(false);                             // bSobreescribir=false → alta nueva
}
catch (COMException) { m.Cancelar(); throw; }
finally { m.Acabar(); Marshal.ReleaseComObject(m); }
```

- **`dynamic` obligatorio**: los indexadores `AsString[]`, `AsFloat[]`, `AsInteger[]` no se resuelven
  en el interop generado; con el tipo COM estático no compila.
- **`Guarda(bool bSobreescribir)`**: `false` = crear registro nuevo, **da error si el código ya
  existe** (no significa "sin confirmación UI", como llegó a estar documentado).
- **`NuevoCodigoNum(): string`** (DispId 23): "último registro numérico + 1", el mismo criterio con el
  que a3ERP propone el código en la ficha. **No bloquea**: con usuarios simultáneos puede devolver
  un código ya ocupado → reintentar (`Cancelar()` + comprobar si existe + pedir otro, máx. 3).
  Llamado tras `Nuevo()` funcionó en pruebas.
- `Cancelar()` descarta el registro en curso; `OmitirMensajes` (bool) existe en la interfaz.
- Campos que el maestro rellena por defecto: p. ej. `CTAAMORT` en `AMORTIZA` (X_DEMO: `28190000`).
- `VINCULOS` **no es un maestro**: el objeto no la admite → INSERT con SQL parametrizado (ver
  `a3rp-modelo-datos-sql`, `sistema/VINCULOS.md`).

---

## Objeto `Asiento` — generar asientos contables

```csharp
var asiento = new Asiento();
asiento.Iniciar();
asiento.Nuevo(fecha /* "dd/MM/yyyy" */, "1", "N");          // "1" = diario, "N" = asiento normal
asiento.AApunte("EURO", cuenta, debe, concepto, haber, "", "");
asiento.AApunteNax("", concepto, cc1, cc2, cc3, "EURO", cuenta, importe, importe, 0, 0, "", fecha);
decimal numApunte = asiento.Anade();                        // id del asiento (__ASIENTOS.NUMAPUNTE)
asiento.Acabar();
```
- `AApunte`: 7 parámetros posicionales (moneda, cuenta, debe, concepto, haber, …). Sin analítica
  explícita: a3ERP aplica los centros de coste por defecto de la empresa.
- `AApunteNax`: 13 parámetros posicionales, con los 3 centros de coste. Firma verificada con
  a3ERP v14.05.02 (X_DEMO, 2026-10); si cambia la versión, fallaría en tiempo de ejecución.
  Documentar siempre la versión con la que se comprobó.
- El diario `"1"` en `Nuevo` es lo habitual, pero hay empresas que usan otro: en una DLL que se
  distribuye, parametrizarlo o documentarlo como limitación (GestionImnovilizado lo tiene fijo y
  documentado en «Requisitos y supuestos»).
- 🔴 **a3ERP rechaza un apunte con debe y haber a 0** ("El debe o haber han de ser diferente a 0").
  Omitir los apuntes de importe 0 (p. ej. amortización acumulada = 0 en la baja de un activo nuevo).
- `Anade()` devuelve el `NUMAPUNTE`; tratar `<= 0` como error.

## Objeto `Opcion` — abrir una pantalla de a3ERP

```csharp
var op = new Opcion();
op.Iniciar();
op.IdOpcion = "EditAsiento";
op.AnadirParametro("Accion", "Edicion");
op.AnadirParametro("NumApunte", numApunte.ToString());
op.Ejecutar();
```

El PDF de referencia documenta además un objeto `OperacionesInmovilizado` con método `BajaElemento`
(baja nativa de inmovilizado). No investigado ni presente en el interop de X_DEMO de 2026: verificar
antes de usarlo.

---

## Errores COM comunes

```csharp
catch (COMException ex) when (ex.HResult == unchecked((int)0x80040154))
{
    // REGDB_E_CLASSNOTREG: el objeto no está registrado — revisar instalación de a3ERPActiveX
    // y que el proyecto compile en x86, no Any CPU/x64 (a3ERPActiveX está registrado en 32 bits).
}
catch (COMException ex) when (ex.HResult == unchecked((int)0x800706BA))
{
    // RPC_S_SERVER_UNAVAILABLE: a3ERP/a3ERPActiveX no accesible.
}
```
El problema más frecuente en la práctica no es un HRESULT — es compilar como "Any CPU" en una
máquina de 64 bits: .NET compila entonces en 64 bits y no encuentra el COM de 32 bits de a3ERP
("no puedo encontrarlo" al instanciar). **Compilar siempre Platform Target = x86.**

---

## Checklist antes de usar esta API

- [ ] Proyecto compilado en x86 (Platform Target), nunca Any CPU/x64.
- [ ] `Enlace.Iniciar` llamado (y con conexión válida) antes de usar cualquier otro objeto.
- [ ] Si hace falta SQL propio, usar `Enlace.GetConexionDB` — nunca abrir una conexión nueva con
      credenciales propias, y nunca cerrar la conexión devuelta.
- [ ] Nombre de objeto/propiedad/método verificado contra `Ultima Vesion ActiveX.pdf`, no inventado.
- [ ] Objetos COM liberados correctamente al terminar (`Marshal.ReleaseComObject` en
      `finally` cuando aplique; `enlace.Acabar()` solo si la conexión la abrió el propio código).
- [ ] `COMException` capturada con log del `HResult`.
- [ ] Ningún `Command.Execute(..., null, ...)`: siempre `Type.Missing`. Fechas como `adDBTimeStamp`.
- [ ] Tras cada escritura, verificado por SQL que **todas** las columnas se han grabado (un `DEFAULT`
      silencioso no da error).
- [ ] Ningún apunte de importe 0 enviado a `Asiento`.
