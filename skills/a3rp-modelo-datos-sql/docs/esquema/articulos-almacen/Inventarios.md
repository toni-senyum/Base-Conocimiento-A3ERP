# Tablas: CABEINVE, LINEINVE y STOCKALM (inventarios y stock por almacén)

**Módulo A3ERP**: Artículos/Almacén
**Tipo de objeto**: tablas. Nombres de tabla y columnas consultados por SELECT en una BD de pruebas (proyecto RocRoi/Migracion, 2026-11). **Los tipos de datos NO se verificaron** (solo se vieron valores); no se contrastó con `INFORMATION_SCHEMA`.
**Descripción**: `CABEINVE` = cabecera de inventario (uno por almacén y fecha). `LINEINVE` = sus líneas (una por artículo). `STOCKALM` = stock resultante por almacén y artículo.

## Columnas verificadas (por nombre)

| Tabla | Columnas usadas en consultas que funcionaron | Notas |
|---|---|---|
| CABEINVE | `IDINVEN`, `CODALM`, `FECHA`, `MOTIVO`, `DEFINITIVO` | `DEFINITIVO` = `'T'` / `'F'`. `CODALM` con relleno a la izquierda a 8 (`'       2'`), como los demás códigos numéricos. `IDINVEN` se devuelve con 4 decimales (`14.0000`): numérico. |
| LINEINVE | `IDINVEN`, `IDLIN`, `CODART`, `UNIDADES`, `PRCMEDIO` | Unir con la cabecera por `IDINVEN`. `PRCMEDIO` = coste unitario cargado. |
| STOCKALM | `CODALM`, `CODART` (+ la columna de unidades) | Usar `LTRIM` en `CODALM`/`CODART` al agrupar o comparar. El nombre exacto de la columna de unidades no consta en la fuente. |

## Comportamiento verificado (RocRoi/Migracion, 2026-11)

- **Crear una cabecera de inventario** hace que a3ERP cree en `LINEINVE` una línea a 0 por cada artículo de `ARTICULO` (2.143 líneas por cabecera cuando había 2.143 artículos; 2.145 en las cabeceras nuevas).
- **Importar** (Gestión de inventarios → Importar) **mueve el stock en el momento de importar**, aunque la cabecera esté con `DEFINITIVO = 'F'`: tras importar 6 inventarios sin marcar, `STOCKALM` coincidió artículo a artículo con los ficheros. Reimportar **sustituye**, no suma. Marcar `DEFINITIVO` (prueba en un almacén) **no duplica** el stock. La importación **no genera asientos** (`APUNTES` y `__ASIENTOS` sin cambios).
- **Borrar una cabecera de inventario no borra las filas de `STOCKALM`: las deja con 0 unidades** (almacén 1: 1.208 filas a 0 uds tras borrar su cabecera).
- **Sustituir una carga por otra** (borrar el inventario antiguo y crear/importar uno nuevo con otra fecha): los artículos que tenían stock en el antiguo y no vienen en el nuevo quedan a 0 (comprobado con líneas del antiguo que debían quedar a 0).
- **La plantilla exportada** desde un inventario con stock **arrastra las unidades y el coste existentes** (columnas K y L en la hoja de 12 columnas). Para una recarga hay que partir de una plantilla a 0 o poner K/L a 0 antes de rellenar; si no, los artículos que ya no tienen stock conservarían la cifra vieja.
- `IDINVEN` **no equivale al número de almacén** salvo en las primeras cabeceras: en la misma BD, las cabeceras recreadas fueron `IDINVEN` 14 a 19. No suponer la equivalencia en consultas.
- `MOVSTOCKS` **no tiene columna `FECHA`** (error de SELECT: «El nombre de columna 'FECHA' no es válido»). Para saber cuándo se cargó, `CABEINVE.FECHA` es la fecha del inventario; la fecha real de edición consta en `REPLOG` (se vieron filas con fecha-hora, usuario, `MOD`, tabla `CABEINVE` e id; nombres de columna de `REPLOG` sin verificar).

## Consulta de cuadre (patrón que funcionó)

```sql
-- Por almacén: líneas con unidades en su inventario
SELECT c.CODALM, COUNT(l.IDLIN) AS lineas, ISNULL(SUM(l.UNIDADES),0) AS uds,
       ISNULL(SUM(l.UNIDADES * l.PRCMEDIO),0) AS importe
FROM CABEINVE c LEFT JOIN LINEINVE l ON l.IDINVEN = c.IDINVEN AND l.UNIDADES <> 0
GROUP BY c.CODALM;
```

## Relaciones

`LINEINVE.IDINVEN` → `CABEINVE.IDINVEN`; `LINEINVE.CODART` → `ARTICULO.CODART`; `CABEINVE.CODALM` / `STOCKALM.CODALM` → `ALMACEN.CODALM` (inferidas por nombre; no se comprobó si hay FK declarada).
