# Tablas: destinatarios de documentos por email (`__CLIENTES_DESTINATARIOS_*`)

**Módulo A3ERP**: Clientes (a3ERP v15)
**Tipo de objeto**: TABLE (tipos y nulabilidad **no comprobados** en `INFORMATION_SCHEMA`)
**Descripción**: configuración de la ficha de cliente de v15 que indica a qué contactos y cargos se envía cada tipo de documento por email.

Verificado en a3ERP v15 (una BD de pruebas v15; verificado en proyecto CertificadosCalidad, 2026-11), detectando qué cambia en la BD al configurar un cliente desde la ficha.

## Columnas relevantes

`__CLIENTES_DESTINATARIOS_CONTACTOSRELACION`

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| CODCLI | ? | ? | Cliente |
| IDCONTACTORELACION | ? | ? | Contacto (relación contacto–cliente) |
| TIPODOCUMENTO | ? | ? | Ver enum abajo |

`__CLIENTES_DESTINATARIOS_CARGOS`

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| CODCLI | ? | ? | Cliente |
| IDCARGO | ? | ? | Cargo: se envía a los contactos con ese cargo |
| TIPODOCUMENTO | ? | ? | Ver enum abajo |

**`TIPODOCUMENTO`** (coincide con el enum del ActiveX): 1 factura, 2 albarán, 3 depósito, 4 pedido, 5 oferta.

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| IDCONTACTORELACION | `__CONTACTOSRELACION` | Inferida (por nombre y datos) |
| `__CONTACTOSRELACION` → contacto | `__CONTACTOS` | Inferida |
| CODCLI | `__CLIENTES.CODCLI` | Inferida |

## Notas / gotchas

- Contacto y cargo van en **tablas distintas**; un mismo tipo de documento puede tener ambos.
- Al guardar la ficha, a3ERP **borra e inserta** todas las filas del cliente (no actualiza) (verificado en una sola prueba).
- **Email** del destinatario: el de la relación contacto–cliente (`__CONTACTOSRELACION.EMAIL`) tiene prioridad sobre el de la ficha del contacto (`__CONTACTOS.EMAIL`).
- Casilla "Enviar por e-mail" del contacto: `__CONTACTOS.ENVIAREMAIL` (en `__CONTACTOSRELACION` suele quedar NULL). Del cliente: `__CLIENTES.ENVIARDOCEMAIL`; email de documentos por defecto: `__CLIENTES.E_MAIL_DOCS`.
- El objeto ActiveX `DestinatarioCliente` lee/escribe esta misma configuración (devuelve ID de fila de estas tablas). Ver `a3rp-api-com`.

### Reglas del envío nativo (validadas contra el envío de albarán/factura de a3ERP v15)

Cada caso se probó **una vez** en una BD de pruebas v15 (verificado en proyecto CertificadosCalidad, 2026-11).

- a3ERP **propone** los destinatarios configurados sin filtrar por las casillas «Enviar por e-mail»; las casillas se comprueban **al enviar**.
- Contacto con la casilla desmarcada: no se le envía y a3ERP registra un acontecimiento («No se ha realizado el envío al contacto … porque tiene indicado no "enviar email"»); el resto de destinatarios sí recibe.
- Cliente con `ENVIARDOCEMAIL` desmarcado: no se envía nada; acontecimiento «El Cliente no permite la recepción de correos electrónicos».
- Contactos con la relación o el contacto **obsoletos** sí se proponen y se puede enviar: no hay que filtrarlos.
- Cargos: el cargo es común a todos los contactos, pero solo cuentan los contactos **del propio cliente** con ese cargo.
- Varios destinatarios: todos en «Para», separados por `;`.
- Tipo de documento **sin** destinatarios configurados: se propone `__CLIENTES.E_MAIL_DOCS`; el email general de la ficha no interviene.
- Consulta que reprodujo el envío nativo en todos los casos probados: casilla efectiva del contacto = `COALESCE(relación.ENVIAREMAIL, contacto.ENVIAREMAIL, 0)`; `ENVIARDOCEMAIL <> 'T'` excluye todos los destinatarios; sin configuración → `E_MAIL_DOCS`.
- **No comprobado**: qué hace a3ERP si hay configuración pero **todos** los contactos quedan excluidos por la casilla (si cae a `E_MAIL_DOCS` o no envía nada); y en facturas, el uso del cliente de facturación (`CABEFACV.CODCLIFAC` + opción de empresa `DATOSCONFIG.ENVIOSMAILFACTUSARCLIFAC`, identificados solo por el nombre).
