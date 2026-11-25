# in&out: carga y corrección de clientes, proveedores y direcciones

Lo aprendido cargando y corrigiendo los maestros de clientes y proveedores de OUTDOOR GLOBAL CORP
(proyecto RocRoi, 2026-10): la fusión con Business Central (unas 2.500 fichas) y cinco rondas de
corrección. Salvo que se diga lo contrario, todo está **verificado** con pruebas en `X_DEMO` y con las
cargas en la BD de la empresa, comprobadas después por SQL campo a campo.

Repo del proyecto (documentación completa):
`...\Clientes\RocRoi\Migracion\Tratameinto\00_ROCROI PALLARS SOBIRA SL\00_Documentacion_Migracion\06_Fusion_Clientes_Proveedores_BC\`

## Formato del fichero

- `.xls` (generado con `xlwt`); el **nombre de la hoja es la tabla** (`CLIENTES`, `PROVEED`, `DIRENT`…).
- Los códigos van como **texto**, con el mismo formato que la primera carga (relleno incluido).
- Plantillas oficiales de columnas: `docs/herramientas/UTILIDADES/Tablas/PDF/` (`Clientes.pdf`,
  `Proveedores.pdf`, `Direcciones Entrega Clientes.pdf`…).
- Importar desde una **ruta corta y local** (p. ej. `C:\Temp\...`). Desde OneDrive, con rutas largas
  (más de 260 caracteres), da problemas. Copiar siempre la última versión del fichero antes de importar
  y revisar su `LOG`.
- No probado: si in&out admite dos hojas de tabla en el mismo fichero. Se ha usado un fichero por tabla.

## Cómo escribe

- **No vacía la tabla**: sobrescribe por clave y da de alta lo que no existe.
- 🔴 **Una celda vacía borra el valor** del campo. **Una columna que no va en el fichero conserva su
  valor.** Para corregir, enviar solo el código y las columnas que cambian.
- Las fichas se dan de alta con las cuentas propias que crea a3ERP (ver
  `skills/a3rp-modelo-datos-sql/docs/esquema/clientes/Clientes.md`).
- Si se da de alta un código que se había borrado y cuya cuenta se conservó por tener apuntes, se
  reutiliza esa cuenta: no se crea otra y los apuntes quedan intactos.

## Direcciones

- La **dirección 1** (`NUMDIR = 1`) **no se puede editar** por in&out ("No se puede editar la primera
  dirección de entrega"). Se actualiza desde la ficha enviando `DIRCLI1` / `DIRPRO1`; el nombre de la
  dirección (`NOMENT`) sigue a `NOMCLI`.
- Las direcciones adicionales se envían **sin** `IDDIRENT`: a3ERP lo asigna, con un contador
  compartido con `__DIRENTPRO`. `NUMDIR`, desde el siguiente libre de cada ficha.
- **a3ERP rellena la población a partir del CP**: enviarla siempre explícita, también cuando no cambia.
- Si cambia la dirección, enviar también la **dirección fiscal** completa (`DIRFISCAL`, `DTOFISCAL`,
  `POBFISCAL`, `PROVIFISCAL`, `PAISFISCAL`). Si el país no es `ES`, `PROVIFISCAL` vacío.
- En el alta, `PROVIFISCAL` / `PAISFISCAL` toman el valor por defecto de la empresa (en OUTDOOR,
  `08` / `ES`) aunque el cliente sea extranjero: enviarlos en el fichero.
- `PROVIFISCAL` se guarda con **relleno** de ancho fijo (`'  22'`, no `'22'`; igual que `CODPROVI`
  `'  25'`): comparar con `LTRIM`/`RTRIM` (verificado en proyecto RocRoi, 2026-11).
- Al corregir la dirección fiscal de fichas extranjeras cambia también `TIPODOCNIF` en `CLIENTES` /
  `PROVEED` y en su fila de `__ORGANIZACION`: es un efecto esperado, no un fallo (verificado en proyecto
  RocRoi, 2026-11).

## Datos

- **NIF-IVA**: va en `NIFCLI` / `NIFPRO` **sin** el prefijo del país (ver `Clientes.md`).
- Los NIF numéricos que han pasado por Excel pierden los ceros iniciales o salen en notación
  científica: revisarlos antes de cargar.
- Normalizar los caracteres Unicode raros que traen otros sistemas (p. ej. `，` de ancho completo, `⁰`).

## Regímenes de IVA en la ficha

Probados en `X_DEMO` con facturas (libro de IVA y clave del 349), salvo donde se indica:

| Operación | Régimen + tipo | Resultado |
|---|---|---|
| Venta nacional / compra nacional | `VNAC` / `CNAC` + `ORD21` | El tipo de la **línea** manda sobre el de la ficha: una factura con artículos al 10 % (`RED10`) y al 4 % (`SRE`) sale con varias bases |
| Entrega intracomunitaria de bienes | `VCEE` + `EXE` | Clave **E** del 349 |
| Prestación de servicios a empresa UE | `PISRD` + `NOSUJETO` | Clave **S** del 349, no sujeta por localización |
| Adquisición intracomunitaria de bienes / de servicios | `CCEE` / `AISLT` | — (no probado con factura) |
| Importación / servicio de fuera de la UE | `IMP` + `NOSUJETO` / `SUJPAS` | — (no probado con factura) |
| Canarias, Ceuta y Melilla | `OPECCM` + `NOSUJETO` | Probado con ventas a Canarias |
| Compra con IVA extranjero no deducible | `CNOSUJ` + `NOSUJETO` | **No verificado**: la prueba en X_DEMO quedó a medias |

Los códigos de régimen son los de la empresa: comprobarlos en cada instalación antes de usarlos.

## Borrado

in&out no borra. Las fichas se borran a mano en a3ERP, y eso **borra también sus cuentas propias sin
apuntes** sin preguntar: ver `skills/a3rp-modelo-datos-sql/docs/esquema/contabilidad/CUENTAS.md`.

## Método que funcionó

- Antes de generar, guardar una **foto** (JSON) de las fichas que se van a tocar; el generador se para
  si la BD ya está modificada y no hay foto. Así es reejecutable y trazable.
- Un fichero por corrección y tabla, con una hoja `TRAZABILIDAD` (valor original, valor final y origen
  de cada campo) y una hoja `LOG`. Un mismo campo no puede salir en dos ficheros.
- Un SQL de verificación de solo lectura que compara cada campo de la trazabilidad con la BD: se
  ejecuta antes de importar (deben salir exactamente los cambios previstos), después (0 diferencias) y
  después de borrar.
- Ensayo completo en una copia local de producción antes de tocar producción.
