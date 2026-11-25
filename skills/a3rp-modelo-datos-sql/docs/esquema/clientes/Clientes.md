# Vista: CLIENTES (modelo Power BI: Clientes)

**Módulo A3ERP**: Clientes
**Tipo de objeto**: VIEW (confirmado en `INFORMATION_SCHEMA.TABLES` contra una BD de pruebas — no tiene índices propios)
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
- **Longitudes del código postal y de la dirección fiscal** (`INFORMATION_SCHEMA.COLUMNS`: `varchar`,
  nulables; verificado en proyecto RocRoi, 2026-11; `DIRCLI` 60 y `POBCLI` 50 ya constan en la tabla de
  arriba): `DTOCLI` 10 (código postal), `DIRFISCAL` 120, `POBFISCAL` 50, `DTOFISCAL` 10. Los campos
  fiscales también están en `__ORGANIZACION` (comprobados `DIRFISCAL` 120 y `DTOFISCAL` 10). Leer las
  longitudes de `INFORMATION_SCHEMA` antes de generar ficheros de carga.

## Tabla base `__CLIENTES`: modelos de impresión y envío de documentos por email

Verificado por SQL en a3ERP v15 (una BD de pruebas v15; verificado en proyecto CertificadosCalidad, 2026-11), asignando modelos desde la ficha y leyendo los campos. Tipos SQL no comprobados en `INFORMATION_SCHEMA`.

| Campo | En la ficha (bloque "Modelos de impresión y nº de copias") | Notas |
|---|---|---|
| `NOMMODFAC` | Factura | |
| `NOMMODFACSIF` | Factura SIF | Modelo para facturas con Verifactu/SIF activo |
| `NOMMODALB` | Albarán | |
| `NOMMODDEP` | Depósito | |
| `NOMMODPED` | Pedido | |
| `NOMMODOFE` | Oferta | |
| `NOMMODFACALB` | — (no aparece en la ficha de cliente) | No interviene en "Según cliente" |
| `ENVIARDOCEMAIL` | Casilla "Enviar por e-mail" del cliente | Reglas exactas no validadas frente al envío nativo |
| `E_MAIL_DOCS` | Email para documentos | Se usa cuando no hay destinatarios configurados (no validado del todo) |

- **Valor de los `NOMMOD*`**: a3ERP guarda el **nombre de fichero del modelo con extensión** (p. ej. `LSTIMPRALBV.000`), sin ruta.
- **"Según datos generales"** en la ficha = `_DATGEN_`. En código en producción (verificado en proyecto ExportacionFacturasPDF, 2026-07) también se trata `_DATGENMULT_` (multiempresa: se resuelve con `TIPOSCON.IDMULTIEMP`). Vacío y NULL equivalen a "sin modelo propio".
- Los campos de copias y "Usa tallas" del mismo bloque no se han mapeado.
- Cómo resolver el modelo efectivo e imprimir con él: `a3rp-api-com`, objeto `Listado`. Modelos de empresa: `configuracion/DATOSCONFIG.md`. Destinatarios por tipo de documento: `clientes/DestinatariosDocumentos.md`.
