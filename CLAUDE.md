# Base de conocimiento A3RP / a3ERP (Senyum)

Repo git local con el conocimiento reutilizable sobre a3ERP: skills `a3rp-*`, docs de API COM, fichas de esquema SQL,
herramientas de carga. Índice general en `README.md`.

- **`main` es producción.** Las skills `a3rp-*` se cargan desde aquí mediante enlaces, así que lo que esté en `main`
  lo usa Claude en todos los proyectos. No edites conocimiento directamente en `main` sin que Toni lo haya pedido o aprobado.
- **Los cambios de conocimiento entran** por la rama `consolidacion` (consolidador diario automático, worktree en
  `C:\SENYUM\base-conocimiento-consolidacion`) o por actualizaciones que Toni apruebe explícitamente.
- **"Revisa la consolidación pendiente"** → sigue la sección «Revisar una propuesta» de `consolidacion/README.md`.
- Nunca datos confidenciales de clientes (NIF, importes, credenciales, cadenas de conexión). Sin `.bak`: el historial es git.
