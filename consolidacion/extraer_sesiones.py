#!/usr/bin/env python
"""Convierte las sesiones .jsonl de Claude Code del inventario en texto compacto.

Uso: python extraer_sesiones.py <inventario.json> <carpeta_salida>

De cada .jsonl de inventario["sesiones"] genera <carpeta_salida>/<proyecto>_<sesion>.txt con la carpeta de trabajo,
las fechas, los mensajes de usuario y asistente (solo texto) y los resultados de herramientas truncados a
LIMITE caracteres (los errores, completos hasta ese mismo limite). Solo biblioteca estandar.
Escribe en cada entrada del inventario el campo "txt" y reescribe el inventario.
"""
import json
import os
import sys

LIMITE = 1500


def recortar(texto, limite=LIMITE):
    texto = texto.strip()
    if len(texto) <= limite:
        return texto
    return texto[:limite] + " [...truncado, %d caracteres en total]" % len(texto)


def texto_de_contenido(contenido):
    """Devuelve el texto plano de un campo content (str o lista de bloques)."""
    if isinstance(contenido, str):
        return contenido
    partes = []
    if isinstance(contenido, list):
        for b in contenido:
            if isinstance(b, dict) and b.get("type") == "text":
                partes.append(b.get("text", ""))
            elif isinstance(b, str):
                partes.append(b)
    return "\n".join(partes)


def es_ruido(texto):
    t = texto.lstrip()
    return (not t) or t.startswith("<system-reminder>") or t.startswith("<command-") \
        or t.startswith("<local-command") or t.startswith("Caveat:")


def procesar(ruta_jsonl):
    cwd = None
    primera = ultima = None
    lineas = []
    with open(ruta_jsonl, encoding="utf-8", errors="replace") as f:
        for crudo in f:
            try:
                d = json.loads(crudo)
            except ValueError:
                continue
            if not isinstance(d, dict):
                continue
            ts = d.get("timestamp")
            if ts:
                primera = primera or ts
                ultima = ts
            cwd = cwd or d.get("cwd")
            tipo = d.get("type")
            if tipo not in ("user", "assistant") or d.get("isMeta"):
                continue
            msg = d.get("message") or {}
            contenido = msg.get("content")
            if tipo == "assistant":
                t = texto_de_contenido(contenido)
                if t.strip():
                    lineas.append("[ASISTENTE] " + t.strip())
                continue
            # tipo == user: texto del usuario y/o resultados de herramientas
            if isinstance(contenido, list):
                for b in contenido:
                    if not isinstance(b, dict):
                        continue
                    if b.get("type") == "tool_result":
                        r = recortar(texto_de_contenido(b.get("content")))
                        if r:
                            etiqueta = "RESULTADO-ERROR" if b.get("is_error") else "RESULTADO"
                            lineas.append("[%s] %s" % (etiqueta, r))
                    elif b.get("type") == "text" and not es_ruido(b.get("text", "")):
                        lineas.append("[USUARIO] " + b["text"].strip())
            else:
                t = texto_de_contenido(contenido)
                if not es_ruido(t):
                    lineas.append("[USUARIO] " + t.strip())
    return cwd, primera, ultima, lineas


def main():
    if len(sys.argv) != 3:
        sys.exit("Uso: extraer_sesiones.py <inventario.json> <carpeta_salida>")
    ruta_inv, salida = sys.argv[1], sys.argv[2]
    with open(ruta_inv, encoding="utf-8-sig") as f:
        inv = json.load(f)
    os.makedirs(salida, exist_ok=True)
    for s in inv.get("sesiones", []):
        jsonl = s["jsonl"]
        proyecto = os.path.basename(os.path.dirname(jsonl))
        sesion = os.path.splitext(os.path.basename(jsonl))[0]
        cwd, primera, ultima, lineas = procesar(jsonl)
        destino = os.path.join(salida, "%s_%s.txt" % (proyecto, sesion))
        with open(destino, "w", encoding="utf-8", newline="\n") as out:
            out.write("Proyecto: %s\nCarpeta de trabajo: %s\nInicio: %s\nFin: %s\nOrigen: %s\n\n"
                      % (proyecto, cwd, primera, ultima, jsonl))
            out.write("\n\n".join(lineas) + "\n")
        s["txt"] = destino
    with open(ruta_inv, "w", encoding="utf-8", newline="\n") as f:
        json.dump(inv, f, ensure_ascii=False, indent=2)
    print("Sesiones extraidas: %d" % len(inv.get("sesiones", [])))


if __name__ == "__main__":
    main()
