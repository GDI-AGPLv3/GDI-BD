"""
Migración 042: Crear case_responsibles y case_favorites en todas las BDs PRD.
Ejecutar con DATABASE_URL o pasar credenciales como args.
Uso: python migrate_042_case_responsibles_favorites.py <host> <port> <password> [dry_run]
"""
import sys
import psycopg2

DDL_TEMPLATE = """
DO $$
BEGIN
  -- case_responsibles
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = '{schema}' AND table_name = 'case_responsibles'
  ) THEN
    CREATE TABLE "{schema}"."case_responsibles" (
      "id"         UUID        NOT NULL DEFAULT gen_random_uuid(),
      "case_id"    UUID        NOT NULL,
      "user_id"    UUID        NOT NULL,
      "sector_id"  UUID        NOT NULL,
      "type"       VARCHAR(20) NOT NULL CHECK ("type" IN ('ADMIN', 'ADDITIONAL')),
      "added_by"   UUID        NOT NULL,
      "added_at"   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      "removed_by" UUID,
      "removed_at" TIMESTAMPTZ,
      "is_active"  BOOLEAN     NOT NULL DEFAULT true,
      CONSTRAINT "cr_pkey"          PRIMARY KEY ("id"),
      CONSTRAINT "cr_case_fkey"     FOREIGN KEY ("case_id")   REFERENCES "{schema}"."cases" ("id"),
      CONSTRAINT "cr_user_fkey"     FOREIGN KEY ("user_id")   REFERENCES "{schema}"."users" ("id"),
      CONSTRAINT "cr_sector_fkey"   FOREIGN KEY ("sector_id") REFERENCES "{schema}"."sectors" ("id"),
      CONSTRAINT "cr_added_by_fkey" FOREIGN KEY ("added_by")  REFERENCES "{schema}"."users" ("id")
    );
    RAISE NOTICE 'CREATED: {schema}.case_responsibles';
  ELSE
    RAISE NOTICE 'SKIP: {schema}.case_responsibles ya existe';
  END IF;

  -- case_favorites
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = '{schema}' AND table_name = 'case_favorites'
  ) THEN
    CREATE TABLE "{schema}"."case_favorites" (
      "id"         UUID        NOT NULL DEFAULT gen_random_uuid(),
      "user_id"    UUID        NOT NULL,
      "case_id"    UUID        NOT NULL,
      "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      CONSTRAINT "cf_pkey"      PRIMARY KEY ("id"),
      CONSTRAINT "cf_user_fkey" FOREIGN KEY ("user_id") REFERENCES "{schema}"."users" ("id") ON DELETE CASCADE,
      CONSTRAINT "cf_case_fkey" FOREIGN KEY ("case_id") REFERENCES "{schema}"."cases" ("id") ON DELETE CASCADE,
      CONSTRAINT "cf_unique"    UNIQUE ("user_id", "case_id")
    );
    RAISE NOTICE 'CREATED: {schema}.case_favorites';
  ELSE
    RAISE NOTICE 'SKIP: {schema}.case_favorites ya existe';
  END IF;
END
$$;

-- Índices (IF NOT EXISTS = idempotentes)
CREATE UNIQUE INDEX IF NOT EXISTS "idx_{schema_idx}_cr_unique_admin"
  ON "{schema}"."case_responsibles" ("case_id")
  WHERE "type" = 'ADMIN' AND "is_active" = true;

CREATE INDEX IF NOT EXISTS "idx_{schema_idx}_cr_case_active"
  ON "{schema}"."case_responsibles" ("case_id", "is_active");

CREATE INDEX IF NOT EXISTS "idx_{schema_idx}_cr_user"
  ON "{schema}"."case_responsibles" ("user_id")
  WHERE "is_active" = true;

CREATE INDEX IF NOT EXISTS "idx_{schema_idx}_cr_sector"
  ON "{schema}"."case_responsibles" ("sector_id")
  WHERE "is_active" = true;

CREATE INDEX IF NOT EXISTS "idx_{schema_idx}_case_favorites_user"
  ON "{schema}"."case_favorites" ("user_id", "created_at" DESC);
"""

def get_tenant_schemas(cur):
    cur.execute("""
        SELECT schema_name FROM information_schema.schemata
        WHERE schema_name NOT IN ('public','pg_catalog','information_schema','pg_toast')
          AND schema_name NOT LIKE 'pg_%'
          AND schema_name NOT LIKE '%_audit'
        ORDER BY schema_name
    """)
    return [r[0] for r in cur.fetchall()]

def run_migration(host, port, password, dry_run=False):
    conn_str = f"host={host} port={port} dbname=railway user=postgres password={password} sslmode=require connect_timeout=10"
    print(f"\n{'='*60}")
    print(f"Conectando a {host}:{port} ...")
    try:
        conn = psycopg2.connect(conn_str)
    except Exception as e:
        # Intentar sin SSL si falla
        conn_str_nossl = conn_str.replace("sslmode=require", "sslmode=prefer")
        conn = psycopg2.connect(conn_str_nossl)

    conn.autocommit = False
    cur = conn.cursor()

    schemas = get_tenant_schemas(cur)
    print(f"Schemas encontrados: {schemas}")

    for schema in schemas:
        schema_idx = schema.replace('-', '_')
        ddl = DDL_TEMPLATE.format(schema=schema, schema_idx=schema_idx)
        if dry_run:
            print(f"[DRY RUN] Aplicaría migración en: {schema}")
            continue
        try:
            cur.execute(ddl)
            # Capturar notices
            for notice in conn.notices:
                print(f"  {notice.strip()}")
            conn.notices.clear()
            conn.commit()
            print(f"  OK: {schema}")
        except Exception as e:
            conn.rollback()
            print(f"  ERROR: {schema}: {e}")

    cur.close()
    conn.close()
    print(f"{'='*60}")

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Uso: python migrate_042_... <host> <port> <password> [dry_run]")
        sys.exit(1)
    host = sys.argv[1]
    port = int(sys.argv[2])
    password = sys.argv[3]
    dry_run = len(sys.argv) > 4 and sys.argv[4] == 'dry_run'
    run_migration(host, port, password, dry_run)
