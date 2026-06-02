#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check_template_drift.py - Drift detector entre los dos templates SQL hermanos
que crean el schema de un municipio.

CONTEXTO
--------
La duplicacion de templates es INTENCIONAL (cada copia cumple un rol distinto):

  - GDI-BD/sql/03-create-municipio.sql        (FUENTE DE VERDAD del DDL)
      Ejecutado por tools/create_municipio.py. 9 placeholders + INSERTs inline.

  - GDI-BackOffice-Back/sql/03-create-web-schema.sql  (COPIA OPERATIVA)
      Ejecutado por services/web_create_schema.py cuando un admin crea un
      municipio desde el BackOffice. Solo {SCHEMA_NAME}, sin INSERTs (los hace
      Python parametrizado).

NO hay que unificarlos. Lo que SI tiene que coincidir es el **DDL del schema
de tenant**: tablas, columnas, constraints, indices y triggers. Si divergen,
los municipios nacen con estructura distinta segun el camino usado (esto ya
paso una vez con memo_recipients y rompio 3 municipios).

Este script compara SOLO el DDL (Seccion 1 + Seccion 2). Ignora a proposito:
  - Los seeds / INSERTs (Seccion 3 y 4) -> son distintos por diseno.
  - Los headers / comentarios.
  - El orden en que aparecen los CREATE INDEX / CREATE TRIGGER.
  - El prefijo de los nombres de indice derivado de {SCHEMA_NAME}.

Compara:
  - TABLAS: existencia + por cada columna (nombre, tipo normalizado,
    nullability, default) + constraints a nivel tabla (PK/FK/UNIQUE/CHECK).
  - INDICES: keyed por (tabla, columnas, UNIQUE?, predicado WHERE).
  - TRIGGERS: keyed por (tabla, timing+evento, funcion).

USO
---
    python tools/check_template_drift.py
    python tools/check_template_drift.py --bo-back /ruta/a/GDI-BackOffice-Back
    python tools/check_template_drift.py --quiet      # solo exit code

Exit code 0 = sincronizados. 1 = drift detectado. 2 = error (archivo no
encontrado, etc). Pensado para correr como step de CI o test local.
"""

import argparse
import os
import re
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Rutas por defecto. El script vive en GDI-BD/tools/. El template fuente de
# verdad esta en GDI-BD/sql/. El hermano vive en el repo sibling
# GDI-BackOffice-Back (hermano de GDI-BD en el arbol de carpetas).
# ---------------------------------------------------------------------------
THIS_FILE = Path(__file__).resolve()
GDI_BD_ROOT = THIS_FILE.parent.parent                 # .../GDI-BD
APP_ROOT = GDI_BD_ROOT.parent                         # .../APP-GDILatam

CANONICAL_DEFAULT = GDI_BD_ROOT / "sql" / "03-create-municipio.sql"
OPERATIVE_DEFAULT = APP_ROOT / "GDI-BackOffice-Back" / "sql" / "03-create-web-schema.sql"

# Donde corta el DDL que debe coincidir. En ambos archivos la "SECCION 3"
# arranca los datos iniciales (seeds), que son intencionalmente distintos.
DDL_END_MARKER = "SECCION 3"


# ---------------------------------------------------------------------------
# Carga + recorte del DDL comparable
# ---------------------------------------------------------------------------
def load_ddl(path: Path) -> str:
    raw = path.read_text(encoding="utf-8")
    # Cortar todo lo que venga desde "SECCION 3" (datos iniciales / seeds).
    idx = raw.find(DDL_END_MARKER)
    if idx != -1:
        # retroceder hasta el inicio de la linea/banner de comentario
        line_start = raw.rfind("\n", 0, idx)
        raw = raw[: line_start if line_start != -1 else idx]
    return raw


def strip_sql_comments(sql: str) -> str:
    # Quita comentarios de linea -- ... (sin tocar comillas; los templates no
    # tienen "--" dentro de strings de DDL).
    out_lines = []
    for line in sql.splitlines():
        # respetar -- dentro de un literal no es necesario aca (DDL puro)
        i = line.find("--")
        if i != -1:
            line = line[:i]
        out_lines.append(line)
    return "\n".join(out_lines)


def norm_ws(s: str) -> str:
    return re.sub(r"\s+", " ", s).strip()


def strip_quotes(ident: str) -> str:
    return ident.strip().strip('"').strip()


# ---------------------------------------------------------------------------
# Parser de CREATE TABLE
# ---------------------------------------------------------------------------
CREATE_TABLE_RE = re.compile(
    r'CREATE\s+TABLE\s+"\{SCHEMA_NAME\}(?:_audit)?"\."(?P<table>[^"]+)"\s*\((?P<body>.*?)\)\s*;',
    re.IGNORECASE | re.DOTALL,
)

# tokens de constraint a nivel tabla
CONSTRAINT_KEYWORDS = ("CONSTRAINT", "PRIMARY KEY", "FOREIGN KEY", "UNIQUE", "CHECK")


def split_top_level(body: str):
    """Divide el cuerpo de un CREATE TABLE por comas de nivel superior,
    respetando parentesis anidados."""
    parts = []
    depth = 0
    cur = []
    for ch in body:
        if ch == "(":
            depth += 1
            cur.append(ch)
        elif ch == ")":
            depth -= 1
            cur.append(ch)
        elif ch == "," and depth == 0:
            parts.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    if cur:
        parts.append("".join(cur))
    return [norm_ws(p) for p in parts if norm_ws(p)]


# tipos: normalizamos para que TIMESTAMPTZ == timestamptz, etc.
def normalize_type(coltype: str) -> str:
    t = coltype.strip().lower()
    # remover el esquema en tipos calificados publicos -> dejar nombre del tipo
    t = t.replace('"public".', "").replace("public.", "")
    t = t.replace('"', "")
    t = re.sub(r"\s+", " ", t)
    return t.strip()


def parse_column(piece: str):
    """Devuelve dict de columna o None si la pieza es un constraint."""
    upper = piece.upper()
    if upper.startswith(CONSTRAINT_KEYWORDS):
        return None

    m = re.match(r'"(?P<name>[^"]+)"\s+(?P<rest>.*)$', piece)
    if not m:
        return None
    name = m.group("name")
    rest = m.group("rest").strip()

    # Extraer el tipo: hasta la primera palabra clave de atributo conocida.
    # Tipos pueden ser: UUID, VARCHAR(100), TIMESTAMPTZ, UUID[], vector(1536),
    # "public"."document_status", tsvector GENERATED ALWAYS AS (...) STORED
    # Detectar GENERATED para no confundirlo con default.
    is_generated = bool(re.search(r"\bGENERATED\s+ALWAYS\s+AS\b", rest, re.IGNORECASE))

    # nullability
    not_null = bool(re.search(r"\bNOT\s+NULL\b", rest, re.IGNORECASE))
    explicit_null = bool(re.search(r"(?<!NOT )\bNULL\b", rest, re.IGNORECASE)) and not not_null

    # default (best-effort; normalizamos NOW() y gen_random_uuid())
    default = None
    dm = re.search(r"\bDEFAULT\s+(?P<def>.+?)(?:\s+NOT\s+NULL|\s+NULL|\s+CHECK|\s+REFERENCES|$)",
                   rest, re.IGNORECASE)
    if dm:
        default = norm_ws(dm.group("def")).lower().rstrip()

    # tipo = todo hasta el primer atributo (NOT NULL / NULL / DEFAULT / CHECK /
    # CONSTRAINT / GENERATED / REFERENCES)
    type_part = re.split(
        r"\b(NOT\s+NULL|NULL|DEFAULT|CHECK|CONSTRAINT|GENERATED|REFERENCES)\b",
        rest, maxsplit=1, flags=re.IGNORECASE,
    )[0]
    coltype = normalize_type(type_part)

    return {
        "name": name,
        "type": coltype,
        "not_null": not_null,
        "generated": is_generated,
        "default": default,
    }


def parse_constraint(piece: str):
    """Normaliza una constraint a nivel tabla a una representacion comparable.
    Ignoramos el NOMBRE de la constraint (a veces difiere) y comparamos
    semantica: tipo + columnas + (para FK) tabla/columnas referenciadas +
    (para CHECK) la expresion."""
    p = norm_ws(piece)
    # quitar "CONSTRAINT "nombre"" inicial
    p = re.sub(r'^CONSTRAINT\s+"[^"]+"\s+', "", p, flags=re.IGNORECASE)
    up = p.upper()

    def cols_in(s):
        inner = s[s.find("(") + 1 : s.rfind(")")]
        return tuple(strip_quotes(c).lower() for c in inner.split(","))

    if up.startswith("PRIMARY KEY"):
        return ("PK", cols_in(p))
    if up.startswith("UNIQUE"):
        return ("UNIQUE", cols_in(p))
    if up.startswith("FOREIGN KEY"):
        # FOREIGN KEY (cols) REFERENCES "schema"."tbl" (cols) [ON DELETE ...]
        mfk = re.match(
            r'FOREIGN\s+KEY\s*\((?P<cols>[^)]*)\)\s*REFERENCES\s+(?P<ref>.+)$',
            p, re.IGNORECASE,
        )
        if not mfk:
            return ("FK_RAW", p.lower())
        cols = tuple(strip_quotes(c).lower() for c in mfk.group("cols").split(","))
        ref = mfk.group("ref")
        # normalizar tabla referenciada: {SCHEMA_NAME} -> TENANT, public se queda
        refm = re.match(
            r'"(?P<sch>[^"]+)"\."(?P<tbl>[^"]+)"\s*\((?P<rcols>[^)]*)\)(?P<tail>.*)$',
            ref.strip(), re.IGNORECASE,
        )
        if refm:
            sch = refm.group("sch")
            sch = "TENANT" if "{SCHEMA_NAME}" in sch else sch.lower()
            rtbl = refm.group("tbl").lower()
            rcols = tuple(strip_quotes(c).lower() for c in refm.group("rcols").split(","))
            tail = norm_ws(refm.group("tail")).upper()  # ON DELETE CASCADE etc
            return ("FK", cols, sch, rtbl, rcols, tail)
        return ("FK_RAW", norm_ws(ref).lower())
    if up.startswith("CHECK"):
        expr = p[p.find("(") + 1 : p.rfind(")")]
        # normalizar espacios y comillas para comparar. Tambien colapsar el
        # espacio luego de las comas dentro de listas IN (...) para que
        # "('a','b')" == "('a', 'b')" (mismo CHECK, distinto formateo).
        expr = norm_ws(expr).lower().replace('"', "")
        expr = re.sub(r",\s*", ",", expr)
        return ("CHECK", expr)
    return ("OTHER", p.lower())


def parse_tables(ddl: str):
    """tabla -> {columns: {name: coldict}, constraints: set(...)}"""
    tables = {}
    for m in CREATE_TABLE_RE.finditer(ddl):
        table = m.group("table")
        body = m.group("body")
        cols = {}
        cons = set()
        for piece in split_top_level(body):
            col = parse_column(piece)
            if col is not None:
                cols[col["name"]] = col
            else:
                cons.add(parse_constraint(piece))
        tables[table] = {"columns": cols, "constraints": cons}
    return tables


# ---------------------------------------------------------------------------
# Parser de CREATE INDEX
# ---------------------------------------------------------------------------
CREATE_INDEX_RE = re.compile(
    r'CREATE\s+(?P<unique>UNIQUE\s+)?INDEX\s+"?(?P<name>[^"\s]+)"?\s+'
    r'ON\s+"\{SCHEMA_NAME\}(?:_audit)?"\."(?P<table>[^"]+)"\s*'
    r'(?P<using>USING\s+\w+\s*)?'
    r'\((?P<cols>.*?)\)\s*'
    r'(?P<where>WHERE\s+.*?)?;',
    re.IGNORECASE | re.DOTALL,
)


def index_key(m):
    table = m.group("table").lower()
    unique = bool(m.group("unique"))
    using = norm_ws(m.group("using") or "").lower()
    cols = norm_ws(m.group("cols")).lower().replace('"', "")
    cols = re.sub(r"\s*,\s*", ",", cols)
    where = norm_ws(m.group("where") or "").lower().replace('"', "")
    where = re.sub(r"\s+", " ", where)
    return (table, unique, using, cols, where)


def parse_indexes(ddl: str):
    out = {}
    for m in CREATE_INDEX_RE.finditer(ddl):
        out[index_key(m)] = m.group("name")
    return out


# ---------------------------------------------------------------------------
# Parser de CREATE TRIGGER
# ---------------------------------------------------------------------------
CREATE_TRIGGER_RE = re.compile(
    r'CREATE\s+TRIGGER\s+"?(?P<name>[^"\s]+)"?\s+'
    r'(?P<timing>BEFORE|AFTER|INSTEAD\s+OF)\s+(?P<events>.*?)\s+'
    r'ON\s+"\{SCHEMA_NAME\}(?:_audit)?"\."(?P<table>[^"]+)"\s+'
    r'FOR\s+EACH\s+ROW\s+EXECUTE\s+FUNCTION\s+(?P<fn>.*?);',
    re.IGNORECASE | re.DOTALL,
)


def trigger_key(m):
    table = m.group("table").lower()
    timing = norm_ws(m.group("timing")).lower()
    events = norm_ws(m.group("events")).lower()
    fn = norm_ws(m.group("fn")).lower().replace('"', "")
    # normalizar {SCHEMA_NAME} en la funcion -> TENANT
    fn = fn.replace("{schema_name}", "tenant")
    return (table, timing, events, fn)


def parse_triggers(ddl: str):
    out = {}
    for m in CREATE_TRIGGER_RE.finditer(ddl):
        out[trigger_key(m)] = m.group("name")
    return out


# ---------------------------------------------------------------------------
# Comparacion
# ---------------------------------------------------------------------------
def compare(canon, oper):
    """Devuelve lista de strings (diffs). Vacia = sincronizado."""
    diffs = []

    ct, ot = parse_tables(canon), parse_tables(oper)
    ci, oi = parse_indexes(canon), parse_indexes(oper)

    # Equivalencia UNIQUE: un CONSTRAINT UNIQUE (col...) y un CREATE UNIQUE
    # INDEX sin USING y sin WHERE sobre las mismas columnas imponen el MISMO
    # invariante. Foldear esos indices UNIQUE planos dentro de las constraints
    # de su tabla y sacarlos de la comparacion de indices, para no marcar como
    # drift una diferencia que es solo estilistica (constraint vs index).
    def fold_unique_indexes(tables, indexes):
        for k in list(indexes):
            table, unique, using, cols, where = k
            if unique and not using and not where:
                col_tuple = tuple(c for c in cols.split(",") if c)
                if table in tables:
                    tables[table]["constraints"].add(("UNIQUE", col_tuple))
                    del indexes[k]

    fold_unique_indexes(ct, ci)
    fold_unique_indexes(ot, oi)

    # tablas faltantes / extra
    canon_tbls, oper_tbls = set(ct), set(ot)
    for t in sorted(canon_tbls - oper_tbls):
        diffs.append(f"[TABLA FALTANTE en operativo] '{t}' existe en GDI-BD pero no en BO-Back")
    for t in sorted(oper_tbls - canon_tbls):
        diffs.append(f"[TABLA EXTRA en operativo] '{t}' existe en BO-Back pero no en GDI-BD")

    # comparar tablas comunes
    for t in sorted(canon_tbls & oper_tbls):
        c_cols, o_cols = ct[t]["columns"], ot[t]["columns"]
        for col in sorted(set(c_cols) - set(o_cols)):
            diffs.append(f"[COLUMNA FALTANTE] {t}.{col} en GDI-BD pero no en BO-Back")
        for col in sorted(set(o_cols) - set(c_cols)):
            diffs.append(f"[COLUMNA EXTRA] {t}.{col} en BO-Back pero no en GDI-BD")
        for col in sorted(set(c_cols) & set(o_cols)):
            a, b = c_cols[col], o_cols[col]
            if a["type"] != b["type"]:
                diffs.append(
                    f"[TIPO DISTINTO] {t}.{col}: GDI-BD='{a['type']}' vs BO-Back='{b['type']}'")
            if a["not_null"] != b["not_null"]:
                diffs.append(
                    f"[NULLABILITY DISTINTA] {t}.{col}: GDI-BD NOT NULL={a['not_null']} "
                    f"vs BO-Back NOT NULL={b['not_null']}")
            if a["generated"] != b["generated"]:
                diffs.append(
                    f"[GENERATED DISTINTO] {t}.{col}: GDI-BD generated={a['generated']} "
                    f"vs BO-Back generated={b['generated']}")
            if (a["default"] or "") != (b["default"] or ""):
                diffs.append(
                    f"[DEFAULT DISTINTO] {t}.{col}: GDI-BD default='{a['default']}' "
                    f"vs BO-Back default='{b['default']}'")

        # constraints
        c_cons, o_cons = ct[t]["constraints"], ot[t]["constraints"]
        for con in sorted(c_cons - o_cons, key=lambda x: str(x)):
            diffs.append(f"[CONSTRAINT FALTANTE] {t}: {con} en GDI-BD pero no en BO-Back")
        for con in sorted(o_cons - c_cons, key=lambda x: str(x)):
            diffs.append(f"[CONSTRAINT EXTRA] {t}: {con} en BO-Back pero no en GDI-BD")

    # indices (ya foldeados los UNIQUE planos como constraints arriba)
    for k in sorted(set(ci) - set(oi), key=lambda x: str(x)):
        diffs.append(
            f"[INDICE FALTANTE] tabla={k[0]} unique={k[1]} using='{k[2]}' "
            f"cols=({k[3]}) where='{k[4]}'  (en GDI-BD, falta en BO-Back; ref name={ci[k]})")
    for k in sorted(set(oi) - set(ci), key=lambda x: str(x)):
        diffs.append(
            f"[INDICE EXTRA] tabla={k[0]} unique={k[1]} using='{k[2]}' "
            f"cols=({k[3]}) where='{k[4]}'  (en BO-Back, no en GDI-BD; ref name={oi[k]})")

    # triggers
    ctr, otr = parse_triggers(canon), parse_triggers(oper)
    for k in sorted(set(ctr) - set(otr), key=lambda x: str(x)):
        diffs.append(
            f"[TRIGGER FALTANTE] tabla={k[0]} {k[1]} {k[2]} fn={k[3]} "
            f"(en GDI-BD, falta en BO-Back; ref name={ctr[k]})")
    for k in sorted(set(otr) - set(ctr), key=lambda x: str(x)):
        diffs.append(
            f"[TRIGGER EXTRA] tabla={k[0]} {k[1]} {k[2]} fn={k[3]} "
            f"(en BO-Back, no en GDI-BD; ref name={otr[k]})")

    return diffs, (ct, ot, ci, oi, ctr, otr)


def main():
    ap = argparse.ArgumentParser(description="Drift detector entre los 2 templates SQL hermanos.")
    ap.add_argument("--canonical", default=str(CANONICAL_DEFAULT),
                    help="Ruta a GDI-BD/sql/03-create-municipio.sql (fuente de verdad)")
    ap.add_argument("--operative", default=str(OPERATIVE_DEFAULT),
                    help="Ruta a GDI-BackOffice-Back/sql/03-create-web-schema.sql")
    ap.add_argument("--bo-back", default=None,
                    help="Raiz del repo GDI-BackOffice-Back (atajo; usa sql/03-create-web-schema.sql)")
    ap.add_argument("--quiet", action="store_true", help="Solo exit code, sin detalle")
    args = ap.parse_args()

    canon_path = Path(args.canonical)
    if args.bo_back:
        oper_path = Path(args.bo_back) / "sql" / "03-create-web-schema.sql"
    else:
        oper_path = Path(args.operative)

    for label, p in (("canonical (GDI-BD)", canon_path), ("operative (BO-Back)", oper_path)):
        if not p.is_file():
            print(f"ERROR: no se encontro el template {label}: {p}", file=sys.stderr)
            return 2

    canon = strip_sql_comments(load_ddl(canon_path))
    oper = strip_sql_comments(load_ddl(oper_path))

    diffs, models = compare(canon, oper)
    ct, ot, ci, oi, ctr, otr = models

    if not args.quiet:
        print("=" * 78)
        print("DRIFT CHECK: templates SQL de creacion de municipio")
        print("=" * 78)
        print(f"  Fuente de verdad : {canon_path}")
        print(f"  Copia operativa  : {oper_path}")
        print(f"  Tablas DDL       : GDI-BD={len(ct)}  BO-Back={len(ot)}")
        print(f"  Indices DDL      : GDI-BD={len(ci)}  BO-Back={len(oi)}")
        print(f"  Triggers DDL     : GDI-BD={len(ctr)} BO-Back={len(otr)}")
        print("-" * 78)

    if not diffs:
        if not args.quiet:
            print("OK: los dos templates estan SINCRONIZADOS en el DDL del schema de tenant.")
        return 0

    if not args.quiet:
        print(f"DRIFT DETECTADO: {len(diffs)} diferencia(s) en el DDL que DEBE coincidir.\n")
        for d in diffs:
            print(f"  - {d}")
        print("\n" + "-" * 78)
        print("ACCION: sincronizar a mano los dos archivos (la duplicacion es")
        print("intencional, pero el DDL del schema de tenant tiene que coincidir).")
        print("  * GDI-BD/sql/03-create-municipio.sql      (fuente de verdad)")
        print("  * GDI-BackOffice-Back/sql/03-create-web-schema.sql  (copia operativa)")
    return 1


if __name__ == "__main__":
    sys.exit(main())
