# Consolidación automática de la base de conocimiento

Cada día laborable, al final de la jornada, una tarea programada de Windows lanza Claude Code sin supervisión
para revisar lo trabajado y proponer cambios en la base. **Nada entra en `main` sin que Toni lo apruebe.**

## Cómo funciona

```
Chats Cowork/claude.ai ──"captura para la base"──► _inbox/*.md ─┐
Sesiones de Claude Code (%USERPROFILE%\.claude\projects) ───────┼─► consolidar.ps1 (19:00, L-V)
Docs de repos de C:\SENYUM (CLAUDE.md, docs/, CHANGELOG) ───────┘        │
                                                                         ▼
                                       rama `consolidacion` (worktree aparte)
                                       + consolidacion/propuestas/AAAA-MM-DD.md
                                                                         │
                                                  Toni revisa ──► merge a main
```

- **Captura**: al cerrar un chat con algo útil, se pide "captura para la base" (skill `alimentar-base-conocimiento-senyum`),
  que deja una nota en `_inbox/`.
- **Consolidación**: `consolidar.ps1` prepara las fuentes (inventario de notas, sesiones de Claude Code extraídas a texto
  y repos con cambios de documentación desde la última pasada). Si no hay nada, termina sin lanzar Claude. Si hay algo,
  ejecuta `claude -p` con `prompt-consolidador.md` y, según el resultado, actualiza `estado.json`. Trabaja en el worktree
  `C:\SENYUM\base-conocimiento-consolidacion` (rama `consolidacion`), nunca en `main`, porque las skills se cargan
  desde `main` mediante enlaces y lo no revisado no debe entrar en producción.
- Si hay propuestas sin revisar, las siguientes pasadas se acumulan en la misma rama (una propuesta por día).

## Ficheros

| Fichero | Qué es | En git |
|---|---|---|
| `prompt-consolidador.md` | Instrucciones del consolidador (reglas, fuentes, mapa de destino, formato de propuesta) | sí |
| `consolidar.ps1` | Script que lanza la pasada: worktree, `claude -p`, log, aviso | sí |
| `propuestas/AAAA-MM-DD.md` | Propuesta de cada día (en la rama `consolidacion`) | sí |
| `extraer_sesiones.py` | Convierte las sesiones `.jsonl` de Claude Code en texto compacto para la pasada | sí |
| `estado.json` | Hora de inicio de la última pasada completada (lo escribe el script, no Claude) | no |
| `trabajo/` | Inventario y sesiones extraídas de la pasada en curso (se vacía en cada ejecución) | no |
| `logs/` | Salida de cada ejecución | no |

## Revisar una propuesta

Abrir Claude Code en `C:\SENYUM\base-conocimiento` y pedir "revisa la consolidación pendiente". Procedimiento:

1. Leer las propuestas de `consolidacion` no fusionadas y `git diff main...consolidacion`.
2. Presentar los cambios por número, correcciones primero. Toni dice cuáles acepta.
3. Si acepta todo: `git merge --no-ff consolidacion`. Si acepta una parte: revertir en la rama lo rechazado y fusionar.
4. Tras fusionar, recrear la rama `consolidacion` desde `main` (worktree incluido) para la siguiente pasada.
5. Lo rechazado se apunta en `propuestas/rechazados.md` para que el consolidador no lo vuelva a proponer.

## Si algo va mal

- Ver el último fichero de `logs/`.
- Deshacer una fusión: `git revert -m 1 <hash del merge>`.
- Repetir un día: editar `ultima_pasada` en `estado.json` y lanzar `consolidar.ps1` a mano.
- Resultado `INCOMPLETA`: `ultima_pasada` no avanza, así que la siguiente pasada vuelve a cubrir el mismo periodo.
