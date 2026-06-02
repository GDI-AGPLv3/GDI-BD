"""
check_migrations.py — Verifica estado de migraciones vs BD.

Compara los archivos .sql en sql/migrations/ (excluyendo archive/)
contra la tabla public.schema_migrations en la BD.

Uso:
    DATABASE_URL=postgresql://... python tools/check_migrations.py
"""

import os
import re
import sys
import psycopg2

# Ruta base del repo (relativa a este script)
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MIGRATIONS_DIR = os.path.join(REPO_ROOT, "sql", "migrations")


def get_pending_files():
    """Lista archivos .sql en migrations/ (sin archive/)."""
    files = []
    for entry in os.listdir(MIGRATIONS_DIR):
        if entry.endswith(".sql") and os.path.isfile(os.path.join(MIGRATIONS_DIR, entry)):
            files.append(entry)
    return sorted(files)


def extract_version(filename):
    """Extrae version del nombre de archivo. Ej: 057_algo.sql -> '057'."""
    match = re.match(r"^(\d+[a-z]?)_", filename)
    if match:
        return match.group(1)
    return None


def get_applied_versions(conn):
    """Obtiene versiones ya aplicadas desde schema_migrations."""
    with conn.cursor() as cur:
        cur.execute("SELECT version FROM public.schema_migrations ORDER BY version;")
        return {row[0] for row in cur.fetchall()}


def main():
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        print("ERROR: DATABASE_URL no esta definida en el entorno.")
        sys.exit(1)

    pending_files = get_pending_files()

    if not pending_files:
        print("No hay archivos de migracion pendientes en sql/migrations/")
        print("(La carpeta solo contiene el directorio archive/)")
        return

    try:
        conn = psycopg2.connect(database_url)
    except Exception as e:
        print(f"ERROR conectando a la BD: {e}")
        sys.exit(1)

    try:
        applied = get_applied_versions(conn)
    except Exception as e:
        print(f"ERROR leyendo schema_migrations: {e}")
        print("Tip: Correr primero sql/migrations/000_create_schema_migrations.sql")
        conn.close()
        sys.exit(1)

    conn.close()

    print(f"\n{'VERSION':<10} {'ARCHIVO':<50} {'ESTADO'}")
    print("-" * 75)

    falta_aplicar = []
    for filename in pending_files:
        version = extract_version(filename)
        if version is None:
            estado = "SKIP (sin version)"
        elif version in applied:
            estado = "OK (aplicada)"
        else:
            estado = "PENDIENTE"
            falta_aplicar.append(filename)
        print(f"{version or '?':<10} {filename:<50} {estado}")

    print()
    if falta_aplicar:
        print(f"PENDIENTES ({len(falta_aplicar)}):")
        for f in falta_aplicar:
            print(f"  python tools/migrate.py sql/migrations/{f}")
    else:
        print("Todas las migraciones estan aplicadas.")


if __name__ == "__main__":
    main()
