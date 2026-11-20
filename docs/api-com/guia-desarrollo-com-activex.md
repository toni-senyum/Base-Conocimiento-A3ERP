# Guía de Desarrollo COM/ActiveX para A3ERP

> Fuente: apuntes propios recopilados. Última revisión: 2024; actualizada 2026-10 con lo verificado
> en el proyecto GestionImnovilizado (registro COM, identidad COM, nombre real de `ListaProcedimientos`).
> Detalle completo y patrones verificados en las skills `a3rp-dll` y `a3rp-api-com`.

---

## 1. DLL Nativa de 32 bits vs DLL ActiveX (COM)

### DLL Nativa de 32 bits
- Biblioteca convencional compilada en C/C++
- No expone interfaz COM
- Se carga en memoria del proceso en tiempo de ejecución
- Sin vinculación al modelo COM

### DLL ActiveX (COM)
- Basada en el modelo COM de Microsoft
- Expone interfaces COM: métodos, propiedades y eventos
- Usable por cualquier aplicación que soporte COM (Office, A3ERP, etc.)
- Permite comunicación estandarizada entre componentes de software

**Resumen**: para A3ERP siempre trabajamos con DLLs ActiveX (COM), no con DLLs nativas.

---

## 2. ⚠️ Problema crítico: Platform Target en .NET

### El problema
Visual Studio configura por defecto **"Any CPU"** como plataforma de destino. En sistemas Windows de 64 bits, esto hace que .NET compile la aplicación como 64 bits y **no encuentre el NAX/COM de A3ERP** (registrado como 32 bits).

Error típico: *"no puedo encontrarlo"* al intentar instanciar el objeto COM.

### Solución obligatoria
**Siempre compilar con Platform Target = `x86` (32 bits)**

> Propiedades del proyecto → Compilación → Plataforma de destino → **x86**

Esto garantiza que A3ERP encuentra la DLL independientemente de si la máquina es x86 o AMD64.

### Alternativas (menos recomendadas)
- Usar la herramienta `CorFlags` para forzar el bit 32bits al ensamblado ya compilado
- Migrar la aplicación de 32 a 64 bits (complejo, ver: https://blog.mattmags.com/2007/06/30/accessing-32-bit-dlls-from-64-bit-code/)

---

## 3. Exponer una clase .NET a COM para A3ERP

### Opción A: Exponer todo el ensamblado (no recomendada)
En Propiedades de la aplicación → Información del ensamblado → marcar **"COM Visible"**.
Expone todas las clases. Poco selectivo.

### Opción B: Exponer solo clases específicas (recomendada)
Marcar únicamente las clases necesarias con el atributo:

```csharp
[System.Runtime.InteropServices.ComVisible(true)]
```

Esto limita la superficie expuesta a COM, que es lo que instanciará A3ERP.

### Pasos en Visual Studio

1. Crear proyecto de **Biblioteca de clases** en C#
2. Añadir `[ComVisible(true)]` a la clase que instanciará A3ERP
3. Abrir Propiedades del proyecto → pestaña **Compilar**
4. Habilitar **"Registrar para interoperabilidad COM"**
   - ⚠️ Esta opción registra automáticamente la DLL — sustituye a `regasm`
   - ⚠️ **Solo en una configuración dedicada a instalar** (p. ej. `DebugA3ERP`) y con caché de registro
     / carpeta `obj` propia. MSBuild guarda en `obj\` una caché de registro y **cualquier compilación
     posterior sin esta opción que use la misma carpeta desregistra la DLL** sin avisar (caso real:
     la extensión quedó sin ProgID/CLSID tras un Rebuild de Debug). Ver skill `a3rp-dll`.
5. Compilar con **Platform Target = x86** (en el `PropertyGroup` global, para todas las configuraciones)
6. Si la DLL se va a distribuir, **fijar la identidad COM**: `[Guid]` y `[ProgId]` en la clase, `[Guid]`
   en la interfaz, `[assembly: ComVisible(false)]` y `[assembly: TypeLibVersion(1, 0)]`. Si no, una
   versión nueva cambia los GUID y a3ERP deja de encontrar la clase en el cliente.

---

## 4. Estructura mínima de una clase para A3ERP

> ⚠️ **Corrección (2026-10):** el método obligatorio se llama **`ListaProcedimientos()`** y devuelve
> `object[]`, no `ObtenerEventos()`/`string[]` como decían estos apuntes. Confirmado en el manual
> oficial y en código en producción (`ValidacionOfertasCompraCL`, `GestionImnovilizado`). El
> ejemplo de abajo ya está corregido. Para DLL de **programas externos** (botón del rayo), el método
> de entrada es `Opcion(string IdOpcion, string Parametro)`: ver skill `a3rp-dll`.

```csharp
using System.Runtime.InteropServices;

// 1. Definir interfaz con los métodos que A3ERP llamará
[ComVisible(true)]
public interface IEventosA3ERP
{
    // Método obligatorio: devuelve la lista de procedimientos que implementamos
    // A3ERP lo llama antes de lanzar cualquier evento
    object[] ListaProcedimientos();

    // Métodos públicos que recibirán los eventos
    void AlCrearFactura(/* parámetros según evento */);
    void AlGuardarCliente(/* parámetros según evento */);
    // ... añadir según eventos suscritos
}

// 2. Implementar la interfaz en la clase expuesta a COM
[ComVisible(true)]
[ClassInterface(ClassInterfaceType.None)]
public class EventosA3ERP : IEventosA3ERP
{
    public object[] ListaProcedimientos()
    {
        return new object[] { "AlCrearFactura", "AlGuardarCliente" };
    }

    public void AlCrearFactura(/* params */)
    {
        // lógica del evento
    }

    public void AlGuardarCliente(/* params */)
    {
        // lógica del evento
    }
}
```

**Reglas importantes:**
- Los métodos que reciben eventos deben ser **públicos**
- El método `ListaProcedimientos()` es obligatorio — A3ERP lo llama primero para conocer qué eventos tiene disponibles
- Los nombres de evento de este ejemplo (`AlCrearFactura`…) son ilustrativos: los reales
  (`AntesDeGuardarDocumentoV2`…) están en el manual de eventos y en la skill `a3rp-dll`
- Los eventos no suscritos simplemente no se llaman

---

## 5. Registro de la DLL en el sistema cliente

### Paso 1: Copiar los binarios
Copiar la DLL compilada (y dependencias) al servidor/cliente donde corra A3ERP.

### Paso 2: Registrar en la tabla DLLS de A3ERP
En la base de datos de la empresa, registrar la DLL en la **tabla DLLS** con el formato:

```
NAMESPACE.NOMBRECLASE
```

> Generalmente el namespace coincide con el nombre de la DLL.
> Ejemplo: `MiEmpresa.EventosA3ERP`

En VB.NET el formato es: `NombreDLL.NombreClase`

### Paso 3: Registrar con RegAsm
Ejecutar como **Administrador**:

```bat
C:\Windows\Microsoft.NET\Framework\v4.0.30319\RegAsm.exe ^
    "C:\ruta\a\MiDLL.dll" /tlb /codebase
```

> Si en Visual Studio se habilitó "Registrar para interoperabilidad COM", este paso
> se hace automáticamente al compilar en la máquina de desarrollo.
> En producción siempre hay que ejecutarlo manualmente.

- Usar **siempre el RegAsm de `Framework`** (32 bits), **nunca el de `Framework64`**: a3ERP es un
  proceso de 32 bits y solo ve el registro en la vista `WOW6432Node`.
- El aviso `RA0000` por usar `/codebase` con una DLL sin firmar es esperado.
- La tabla `DLLS` está en la BD **de cada empresa**; su columna es `ORDENDEEJECUCION`.
- Para distribuir a clientes: paquete con instalador (`instalar.cmd`) que comprueba que a3ERP está
  cerrado, hace copia de seguridad **fuera** de la carpeta `Extensiones`, desregistra la versión
  anterior, copia y registra. Patrón completo en la skill `a3rp-dll`.

---

## 6. Elegir entre DLL Nativa vs COM en .NET

| Opción | Cuándo usarla |
|--------|--------------|
| DLL Nativa (Visual C++ / plugins) | Equivalente al método Delphi del manual de eventos A3ERP 2022 |
| DLL COM (.NET/C#) | **Opción recomendada para C#** — más sencilla de mantener |

Referencia manual eventos A3ERP 2022:
https://media.a3software.com/a3responde/files/21582-a3ERP_Manual_eventos_2022.pdf

---

## 7. Enlaces de referencia

| Recurso | URL |
|---------|-----|
| Capa COM con .NET | https://www.codeproject.com/Articles/990/Understanding-Classic-COM-Interoperability-With-NE |
| Elegir herramienta de desarrollo | https://comunidadnexus.wordpress.com/2009/03/02/fusionandose-con-nexus-o-el-baile-del-junco/ |
| Eventos A3ERP | https://comunidadnexus.wordpress.com/2009/02/25/cuando-el-nexus-habla/ |
| Migrar app 32→64 bits | https://blog.mattmags.com/2007/06/30/accessing-32-bit-dlls-from-64-bit-code/ |
