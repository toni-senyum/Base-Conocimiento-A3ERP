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
- **Email** del destinatario: `__CONTACTOSRELACION.EMAIL` y, si está vacío, `__CONTACTOS.EMAIL`.
- Casilla "Enviar por e-mail" del contacto: `__CONTACTOS.ENVIAREMAIL` (en `__CONTACTOSRELACION` suele quedar NULL). Del cliente: `__CLIENTES.ENVIARDOCEMAIL`; email de documentos por defecto: `__CLIENTES.E_MAIL_DOCS`.
- El objeto ActiveX `DestinatarioCliente` lee/escribe esta misma configuración (devuelve ID de fila de estas tablas). Ver `a3rp-api-com`.
- **No validado** frente al envío nativo de a3ERP (supuestos de la consulta de prueba, comprobar antes de usar en producción):
  - que los contactos de un cargo se limiten a los del propio cliente;
  - que el email por defecto (`E_MAIL_DOCS`) se use solo cuando el tipo de documento no tiene configuración, y qué pasa si está vacío;
  - el efecto de las casillas desmarcadas (cliente y contacto);
  - en facturas, el uso del cliente de facturación (`CABEFACV.CODCLIFAC` + opción de empresa `DATOSCONFIG.ENVIOSMAILFACTUSARCLIFAC`, identificados solo por el nombre).
