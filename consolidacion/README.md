# Consolidación automática de la base de conocimiento

Cada día laborable, al final de la jornada, una tarea programada de Windows lanza Claude Code sin supervisión
para revisar lo trabajado y proponer cambios en la base. **Nada entra en `main` sin que Toni lo apruebe.**

## Cómo funciona

```
Chats Cowork/claude.ai ──"captura para la base"──► _inbox/*.md ─┐
Sesiones de Claude Code (%USERPROFILE%\.claude\projects) ───────┼─► consolidar.ps1 (19:00, L-V; y al iniciar sesión si la última pasada tiene ≥ 12 h)
Docs de repos de C:\SENYUM (CLAUDE.md, docs/, CHANGELOG) ───────┘        │
                                                                         ▼
                                       rama `consolidacion` (worktree aparte)
                                       + consolidacion/propuestas/AAAA-MM-DD_HHMM.md
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
- Si hay propuestas sin revisar, las siguientes pasadas se acumulan en la misma rama (una propuesta por pasada, con fecha y hora en el nombre).

## Ficheros

| Fichero | Qué es | En git |
|---|---|---|
| `prompt-consolidador.md` | Instrucciones del consolidador (reglas, fuentes, mapa de destino, formato de propuesta) | sí |
| `consolidar.ps1` | Script que lanza la pasada: worktree, `claude -p`, log, aviso | sí |
| `propuestas/AAAA-MM-DD_HHMM.md` | Propuesta de cada pasada, nunca se sobrescribe una existente (en la rama `consolidacion`) | sí |
| `extraer_sesiones.py` | Convierte las sesiones `.jsonl` de Claude Code en texto compacto para la pasada | sí |
| `estado.json` | Hora de inicio de la última pasada completada (lo escribe el script, no Claude) | no |
| `trabajo/` | Inventario y sesiones extraídas de la pasada en curso (se vacía en cada ejecución) | no |
| `logs/` | Salida de cada ejecución | no |
| `trabajo-historico/<fecha>_<hhmm>/` | Fuentes extraídas de cada pasada con propuesta, para comprobar la evidencia en la revisión (se borran a los 30 días) | no |

## Revisar una propuesta

Abrir Claude Code en `C:\SENYUM\base-conocimiento` y pedir "revisa la consolidación pendiente". Procedimiento:

1. Leer las propuestas de `consolidacion` no fusionadas y `git diff main...consolidacion`.
2. Presentar los cambios por número, correcciones primero. Toni dice cuáles acepta.
3. Si acepta todo: `git merge --no-ff consolidacion`. Si acepta una parte: revertir en la rama lo rechazado y fusionar.
4. Tras fusionar, **no borrar ni recrear** la rama ni su worktree: basta con avanzarla a `main`
   (`git -C C:\SENYUM\base-conocimiento-consolidacion merge --ff-only main`) y hacer `git push origin main consolidacion`
   (sin `--force`). Como `main` ya contiene la rama tras el merge, siempre es un avance directo.
5. Lo rechazado se apunta en `propuestas/rechazados.md` para que el consolidador no lo vuelva a proponer.

## Si algo va mal

- Ver el último fichero de `logs/`.
- Deshacer una fusión: `git revert -m 1 <hash del merge>`.
- Repetir un día: editar `ultima_pasada` en `estado.json` y lanzar `consolidar.ps1` a mano.
- Resultado `INCOMPLETA`: `ultima_pasada` no avanza, así que la siguiente pasada vuelve a cubrir el mismo periodo.

## Copia de seguridad y remoto

- **Dónde está.** Repositorio de GitHub `https://github.com/toni-senyum/Base-Conocimiento-A3ERP` (remoto `origin`, debe ser
  **privado**). Es la única copia fuera de este equipo: `C:\SENYUM` no está en OneDrive ni tiene Historial de archivos
  ni copias de Windows.
- **Cuándo se sube.** Al final de cada pasada (bloque `finally` de `consolidar.ps1`), con propuesta, `SIN NOVEDADES`,
  `INCOMPLETA` o error: `git push origin main consolidacion`. Un fallo (sin red, credencial caducada, más de 120 s) no
  tumba la pasada: queda un `AVISO` en el log. Si es de autenticación, sale la notificación
  «Base conocimiento: renovar credencial de GitHub»; se arregla con un `git push` manual en `C:\SENYUM\base-conocimiento`
  (Git Credential Manager abre el navegador una vez).
- **Autenticación.** HTTPS con Git Credential Manager. Ningún token va en el repositorio, en el script ni en el log.
  En la tarea programada se fuerza `GCM_INTERACTIVE=never` y `GIT_TERMINAL_PROMPT=0` para que nunca se quede esperando.
- **Qué se sube.** Las ramas `main` y `consolidacion` con todo lo que está en git (skills, docs, herramientas,
  `consolidacion/`, propuestas y `rechazados.md`).
- **Qué NO se sube** (`.gitignore`, hay que recrearlo a mano en un equipo nuevo): `scripts/config.ini` (conexión local),
  `consolidacion/estado.json`, `consolidacion/logs/`, `consolidacion/trabajo/`, `consolidacion/trabajo-historico/`
  (fuentes extraídas de cada pasada con propuesta, 30 días), el token de Claude y la tarea programada.

### Restaurar en un equipo nuevo

1. **Clonar:** `git clone https://github.com/toni-senyum/Base-Conocimiento-A3ERP.git C:\SENYUM\base-conocimiento`
   (la primera vez, Git Credential Manager pide el login en el navegador).
2. **Worktree de la consolidación:**
   `git -C C:\SENYUM\base-conocimiento worktree add C:\SENYUM\base-conocimiento-consolidacion consolidacion`
   (si la rama no existe en local, `git fetch origin` antes; se crea desde `origin/consolidacion`).
3. **Enlaces de skills** (junctions, desde `main`), en `%USERPROFILE%\.claude\skills`:
   `a3rp-api-com`, `a3rp-diccionarios`, `a3rp-dll`, `a3rp-modelo-datos-sql` →
   `C:\SENYUM\base-conocimiento\skills\<nombre>` (`mklink /J <enlace> <destino>`).
4. **Configuración local:** copiar `scripts\config.example.ini` a `scripts\config.ini` y rellenarlo.
5. **Token de Claude Code:** ejecutar `claude setup-token` y guardarlo como variable de **entorno de usuario**
   `CLAUDE_CODE_OAUTH_TOKEN` (`[Environment]::SetEnvironmentVariable('CLAUDE_CODE_OAUTH_TOKEN','<token>','User')`).
   El script lo lee de ahí si el proceso no lo hereda.
6. **Tarea programada** «Senyum - Consolidación base conocimiento», con la cuenta del usuario (interactiva): L–V a las 19:00,
   acción `wscript.exe "C:\SENYUM\base-conocimiento\consolidacion\lanzar-oculto.vbs"`, «ejecutar en cuanto sea posible si se
   pasó la hora» y límite de 1 h.
   **Segundo desencadenador (al iniciar sesión).** Si el equipo está apagado a las 19:00, «ejecutar en cuanto sea posible»
   lo intenta al arrancar, pero con una tarea interactiva falla si aún no hay sesión (evento 332) y no reintenta. Para
   recuperar esa pasada hay una segunda tarea, «Senyum - Consolidación base conocimiento (inicio de sesión)», con la misma
   cuenta, desencadenador «Al iniciar sesión» (solo ese usuario) con 3 min de retraso y acción
   `wscript.exe "...\lanzar-oculto.vbs" -AlIniciarSesion` (el .vbs reenvía sus argumentos a `consolidar.ps1`).
   Es una tarea aparte y no un segundo desencadenador de la principal porque Windows no permite argumentos distintos por
   desencadenador, y así la de las 19:00 no lleva el parámetro. Con `-AlIniciarSesion`, si `ultima_pasada` de
   `estado.json` tiene menos de 12 h, el script registra «Pasada al iniciar sesión omitida: última pasada hace X h» y
   sale con 0 sin hacer nada más; si tiene 12 h o más (o falta `estado.json`), hace la pasada normal.
7. **Comprobar:** `consolidar.ps1 -SoloInventario` (sin Claude ni estado) y, después, `schtasks /run /tn "Senyum - Consolidación base conocimiento"`
   y mirar en el último fichero de `logs/` la línea `git push origin main consolidacion: OK`.
   `estado.json` no se restaura: si falta, la primera pasada mira las últimas 72 h.
