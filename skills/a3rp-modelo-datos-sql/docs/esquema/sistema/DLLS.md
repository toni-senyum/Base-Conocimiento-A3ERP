# Tabla: DLLS

**Módulo A3ERP**: Sistema de extensiones (en la base de datos **de cada empresa**, no en `A3ERP$SISTEMA`)
**Tipo de objeto**: TABLE (confirmado contra una BD de pruebas, 2026-10)
**Descripción**: DLLs COM que a3ERP debe cargar para esa empresa (eventos y programas externos). Una fila = una clase COM.

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| IDDLL | numérico | No | Clave. Se asigna como `MAX(IDDLL) + 1`. |
| DLL | `varchar` | No | ProgID de la clase COM (`Namespace.Clase`, p. ej. `GestionImnovilizado.ActiveX`). |
| FABRICANTE | `varchar` | Sí | Libre; recomendable que coincida con la carpeta `Extensiones\<Fabricante>\`. |
| PRODUCTO | `varchar` | Sí | Ídem con `Extensiones\<Fabricante>\<Producto>\`. |
| ORDENDEEJECUCION | numérico | Sí | **Nombre exacto `ORDENDEEJECUCION`** (no `ORDENEJECUCION`: un script con ese nombre falla). En una BD de pruebas, la DLL de GestionImnovilizado tiene `IDDLL=13`, orden `35004`. |

## Script idempotente

```sql
-- Ejecutar en la BD de CADA empresa donde se use la DLL
IF NOT EXISTS (SELECT IDDLL FROM DLLS WHERE DLL = 'Namespace.Clase')
BEGIN
    DECLARE @id INT
    SELECT @id = ISNULL(MAX(IDDLL), 0) + 1 FROM DLLS
    INSERT INTO DLLS (IDDLL, DLL, FABRICANTE, PRODUCTO, ORDENDEEJECUCION)
    VALUES (@id, 'Namespace.Clase', 'Fabricante', 'Producto', 1)
END
```

## Notas / gotchas

- Para validar el script sin ejecutarlo: `SET NOEXEC ON` + el script (comprueba nombres de columna).
- Ver skill `a3rp-dll` para el registro COM (RegAsm x86) que también hace falta.
