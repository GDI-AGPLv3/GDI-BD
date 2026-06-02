"""
migrate.py — Aplica UNA migracion especifica y la registra en schema_migrations.

Uso:
    DATABASE_URL=postgresql://... python tools/migrate.py sql/migrations/057_algo.sql

El script:
1. Lee el archivo SQL indicado
2. Ejecuta el SQL en la BD
3. Registra la version en public.schema_migrations
4. Aborta si la version ya esta registrada (idempotente)
"""

import os
import re
import sys
import hashlib
import psycopg2


def extract_version(filename):
    """Extrae version del nombre de archivo. Ej: 057_algo.sql -> '057'."""
    basename = os.path.basename(filename)
    match = re.match(r"^(\d+[a-z]?)_", basename)
    if match:
        return match.group(1)
    return None


def extract_name(filename):
    """Extrae nombre descriptivo. Ej: 057_crear_tabla_x.sql -> 'crear_tabla_x'."""
    basename = os.path.basename(filename).replace(".sql", "")
    match = re.match(r"^\d+[a-z]?_(.*)", basename)
    if match:
        return match.group(1)
    return basename


def main():
    if len(sys.argv) != 2:
        print("Uso: python tools/migrate.py sql/migrations/NNN_nombre.sql")
        sys.exit(1)

    sql_path = sys.argv[1]

    # Resolver path relativo desde raiz del repo
    if not os.path.isabs(sql_path):
        repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        sql_path = os.path.join(repo_root, sql_path)

    if not os.path.isfile(sql_path):
        print(f"ERROR: No existe el archivo: {sql_path}")
        sys.exit(1)

    version = extract_version(sql_path)
    if not version:
        print(f"ERROR: No se pudo extraer version del nombre: {os.path.basename(sql_path)}")
        print("El archivo debe tener formato: NNN_nombre.sql o NNNa_nombre.sql")
        sys.exit(1)

    name = extract_name(sql_path)

    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        print("ERROR: DATABASE_URL no esta definida en el entorno.")
        sys.exit(1)

    with open(sql_path, "r", encoding="utf-8") as f:
        sql_content = f.read()

    checksum = hashlib.sha256(sql_content.encode()).hexdigest()[:16]

    try:
        conn = psycopg2.connect(database_url)
        conn.autocommit = False
    except Exception as e:
        print(f"ERROR conectando a la BD: {e}")
        sys.exit(1)

    try:
        with conn.cursor() as cur:
            # Verificar si ya esta aplicada
            cur.execute(
                "SELECT applied_at FROM public.schema_migrations WHERE version = %s",
                (version,)
            )
            row = cur.fetchone()
            if row:
                print(f"SKIP: version '{version}' ya aplicada el {row[0]}")
                conn.close()
                sys.exit(0)

            # Ejecutar el SQL
            print(f"Aplicando migracion {version} ({name})...")
            cur.execute(sql_content)

            # Registrar en schema_migrations
            cur.execute(
                """INSERT INTO public.schema_migrations (version, name, checksum)
                   VALUES (%s, %s, %s)""",
                (version, name, checksum)
            )

        conn.commit()
        print(f"OK: Migracion {version} aplicada y registrada.")

    except Exception as e:
        conn.rollback()
        print(f"ERROR aplicando migracion: {e}")
        conn.close()
        sys.exit(1)

    conn.close()


if __name__ == "__main__":
    main()
