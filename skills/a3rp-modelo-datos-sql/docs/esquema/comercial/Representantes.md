# Tabla: REPRESEN (modelo Power BI: Representantes)

**Módulo A3ERP**: Comercial
**Tipo de objeto**: TABLE (`BASE TABLE`, confirmado en `INFORMATION_SCHEMA.TABLES` contra una BD de pruebas)
**Descripción**: Representante/agente comercial. Una fila = un representante.

## Columnas relevantes

| Columna | Tipo | Nulo | Notas |
|---|---|---|---|
| CODREP | `varchar(8)` | No | Clave. |
| NOMREP | `varchar(50)` | Sí | |
| PORCOMIS | `decimal` | Sí | Porcentaje de comisión. |
| BLOQUEADO | `varchar(1)` | Sí | |

## Relaciones (declaradas o inferidas)

| Columna | Tabla relacionada | Tipo de relación |
|---|---|---|
| CODREP | Facturas (CABEFACV.CODREP) | FK real, referenciada desde el lado "muchos" (`FK_CABEFACV_REPRESEN_CODREP`) |
| CODREP | Clientes (CLIENTES.CODREP) | Relación de negocio (representante por defecto del cliente, ver `Clientes.md`) — no verificada como FK declarada en este pase |

## Notas / gotchas

- Tabla pequeña y sencilla en una BD de pruebas (4 filas en el modelo actual). Sin hallazgos propios más allá de la estructura de columnas y las 2 relaciones de arriba — pendiente de profundizar si el proyecto empieza a reportar por comercial.
