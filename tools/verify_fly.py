"""Verificar deploy de Postgres en Fly.io"""
import psycopg2

DB_URL = "postgresql://postgres:S_OOdCXHbqSxm7L4J-SVeY-SvUlREci3@localhost:5433/railway"

conn = psycopg2.connect(DB_URL)
cur = conn.cursor()

print("=== EXTENSIONES ===")
cur.execute("SELECT name, installed_version FROM pg_available_extensions WHERE name IN ('vector','unaccent','pg_trgm') ORDER BY name")
for name, ver in cur.fetchall():
    status = ver if ver else "(disponible, no instalada)"
    print(f"  {name:15} {status}")

print("\n=== EXTENSIONES INSTALADAS ===")
cur.execute("SELECT extname, extversion FROM pg_extension ORDER BY extname")
for name, ver in cur.fetchall():
    print(f"  {name:15} {ver}")

print("\n=== SCHEMAS ===")
cur.execute("SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('pg_catalog','information_schema','pg_toast') ORDER BY schema_name")
for (s,) in cur.fetchall():
    print(f"  {s}")

print("\n=== TABLAS PUBLIC ===")
cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE' ORDER BY table_name")
rows = cur.fetchall()
print(f"  Total: {len(rows)}")
for (t,) in rows:
    print(f"  - {t}")

print("\n=== TABLAS 100_test ===")
cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='100_test' AND table_type='BASE TABLE' ORDER BY table_name")
rows = cur.fetchall()
print(f"  Total: {len(rows)}")
for (t,) in rows:
    print(f"  - {t}")

print("\n=== TEST PGVECTOR ===")
try:
    cur.execute("SELECT '[1,2,3]'::vector")
    print(f"  OK: {cur.fetchone()[0]}")
except Exception as e:
    print(f"  ERROR: {e}")

cur.close()
conn.close()
print("\nVerificacion completa.")
