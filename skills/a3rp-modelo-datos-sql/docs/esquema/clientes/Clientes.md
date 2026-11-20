# Vista: CLIENTES (modelo Power BI: Clientes)

**Módulo A3ERP**: Clientes
**Tipo de objeto**: VIEW (confirmado en `INFORMATION_SCHEMA.TABLES` contra `X_DEMO` — no tiene índices propios)
**Descripción**: Ficha de cliente, con nombre/NIF/dirección ya resueltos desde `__ORGANIZACION` (de ahí que sea vista y no tabla base).

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| CODCLI | `varchar(8)` | No | Clave. |
| NOMCLI | `varchar(100)` | No | Nombre de la **Organización** (el nombre principal de la ficha) — ver gotcha NOMCLI / NOMFISCAL / RAZON. |
| RAZON | `varchar(100)` | Sí | **Nombre comercial** (⚠️ corregido 2026-10: antes ponía "razón social fiscal"). |
| NIFCLI | `varchar(20)` | Sí | NIF. En clientes de la UE, el NIF-IVA **sin** el prefijo del país (ver `__CLIENTES` abajo). |
| DIRCLI | `varchar(60)` | Sí | |
| POBCLI | `varchar(50)` | Sí | |
| CODPROVI | `varchar(4)` | Sí | |
| CODPAIS | `varchar(4)` | Sí | |
| TELCLI | `varchar(15)` | Sí | |
| E_MAIL | `varchar(150)` | Sí | |
| CODREP | `varchar(8)` | Sí | Representante **por defecto** del cliente — no el de cada factura (ese es `CABEFACV.CODREP`, ver `Facturas.md`). |
| TARIFA | `varchar(8)` | Sí | |
| BLOQUEADO | `varchar(1)` | Sí | |

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| CODCLI | Facturas (CABEFACV.CODCLI) | FK real, referenciada desde el lado "muchos" (`FK_CABEFACV___CLIENTES_CODCLI`) |
| CODREP | Representantes (REPRESEN.CODREP) | Relación de negocio (representante por defecto), no verificada como FK declarada en este pase |

## Notas / gotchas

- **`CLIENTES` es VIEW, no tabla base** — confirmado en `INFORMATION_SCHEMA.TABLES`. Trae ya resueltos nombre/NIF/dirección desde `__ORGANIZACION`, por eso no hace falta un `JOIN` aparte para tener `NOMCLI`/`RAZON` pobladas.
- **`NOMCLI` / `NOMFISCAL` / `RAZON`** (⚠️ corregido 2026-10, confirmado por Toni en el proyecto RocRoi, cargas de in&out en OUTDOOR): en la ficha de A3ERP, `NOMCLI` es el nombre de la **Organización**, `NOMFISCAL` la **Razón social** y `RAZON` el **nombre comercial**. Antes esta ficha decía que `RAZON` era la razón social fiscal: no lo es. En proveedores es igual (`NOMPRO`, `NOMFISCAL`, `RAZON`). Para listar o rankear clientes se sigue recomendando `NOMCLI`, que es lo que A3ERP trata como "nombre a mostrar" (p. ej. `CABEFACV.NOMCLI`, copia congelada del nombre en cada factura). En X_DEMO coinciden casi siempre, pero en datos migrados pueden diferir mucho (el comercial suele venir de otro sistema).

## Tabla base `__CLIENTES`: campos de cuenta contable

Verificado por SQL en OUTDOOR (proyecto RocRoi, 2026-10). Cada cliente tiene, al darlo de alta, sus **cuentas propias**, que a3ERP crea con el número del cliente:

| Campo | Cuenta típica (cliente 4) | Qué es | Plan |
|---|---|---|---|
| `CUENTA`, `CTAPORCUENTA` | `43000004` | Cuenta del cliente y pagos por cuenta | NPGC y PGC |
| `CTALETRA` | `43100004` | Efectos en cartera | NPGC y PGC |
| `CTADESC` | `43110004` | Efectos al descuento | NPGC y PGC |
| `CTAANTVNPGC`, `CTAPROVISIONNPGC` | `43800004` | Anticipos y provisión de fondos | Solo NPGC |

- Dudoso cobro (`43600000`), impagados (`43150000`), ventas, abonos e IRPF suelen ser **cuentas compartidas** por todos los clientes.
- `__ORGANIZACION` **no** tiene campos de cuenta.
- 🔴 **Borrar la ficha borra sus cuentas propias** si no tienen apuntes: ver `contabilidad/CUENTAS.md`.
- **NIF-IVA**: no hay un campo aparte. En las fichas UE va en `NIFCLI` **sin** el prefijo del país (`04072990247`, no `IT04072990247`); el país sale de `PAISFISCAL`. En la BD existe la función `AEAT_NIF_CALCULO`, que parece añadir el prefijo a partir de `PAISFISCAL` para AEAT (SII/349) — **no verificado** con una presentación real. Las facturas impresas muestran el NIF sin prefijo.
- Cuidado con los NIF numéricos que han pasado por Excel: pierden los ceros iniciales (o salen en notación científica, p. ej. `2,10122E+11`).
