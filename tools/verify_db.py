#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Verificar que la BD se creo correctamente
"""

import psycopg2
import sys
import os

os.environ['PYTHONIOENCODING'] = 'utf-8'
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

# Configuración de conexión via variable de entorno
DATABASE_URL = os.environ.get("DATABASE_URL")
if not DATABASE_URL:
    print("[ERROR] Variable de entorno DATABASE_URL no configurada")
    print("Ejemplo: export DATABASE_URL='postgresql://user:pass@host:port/db'")
    sys.exit(1)

def verify():
    try:
        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor()

        print("\n" + "="*80)
        print("VERIFICACION DE SCHEMAS Y TABLAS")
        print("="*80 + "\n")

        # 1. Verificar schema public
        cur.execute("""
            SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
        """)
        public_tables = cur.fetchone()[0]
        print(f"[Schema PUBLIC]")
        print(f"  Tablas: {public_tables}")

        cur.execute("""
            SELECT table_name FROM information_schema.tables
            WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
            ORDER BY table_name
        """)
        for row in cur.fetchall():
            print(f"    - {row[0]}")

        # 2. Verificar schema 100_test
        cur.execute("""
            SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema = '100_test' AND table_type = 'BASE TABLE'
        """)
        tenant_tables = cur.fetchone()[0]
        print(f"\n[Schema 100_test]")
        print(f"  Tablas: {tenant_tables}")

        cur.execute("""
            SELECT table_name FROM information_schema.tables
            WHERE table_schema = '100_test' AND table_type = 'BASE TABLE'
            ORDER BY table_name
        """)
        for row in cur.fetchall():
            print(f"    - {row[0]}")

        # 3. Verificar schema 100_test_audit
        cur.execute("""
            SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema = '100_test_audit' AND table_type = 'BASE TABLE'
        """)
        audit_tables = cur.fetchone()[0]
        print(f"\n[Schema 100_test_audit]")
        print(f"  Tablas: {audit_tables}")

        cur.execute("""
            SELECT table_name FROM information_schema.tables
            WHERE table_schema = '100_test_audit' AND table_type = 'BASE TABLE'
            ORDER BY table_name
        """)
        for row in cur.fetchall():
            print(f"    - {row[0]}")

        # 4. Datos en public
        print(f"\n[Datos en SCHEMA PUBLIC]")

        cur.execute("SELECT COUNT(*) FROM public.roles")
        roles_count = cur.fetchone()[0]
        print(f"  Roles: {roles_count}")

        cur.execute("SELECT COUNT(*) FROM public.global_registry_families")
        registry_families_count = cur.fetchone()[0]
        print(f"  Global Registry Families: {registry_families_count}")

        cur.execute("SELECT COUNT(*) FROM public.global_document_types")
        doc_types_count = cur.fetchone()[0]
        print(f"  Global Document Types: {doc_types_count}")

        cur.execute("SELECT COUNT(*) FROM public.global_case_templates")
        case_templates_count = cur.fetchone()[0]
        print(f"  Global Case Templates: {case_templates_count}")

        cur.execute("SELECT COUNT(*) FROM public.municipalities")
        municipalities_count = cur.fetchone()[0]
        print(f"  Municipalities: {municipalities_count}")

        cur.execute("SELECT COUNT(*) FROM public.document_display_states")
        display_states_count = cur.fetchone()[0]
        print(f"  Document Display States: {display_states_count}")

        # 5. Datos en 100_test
        print(f"\n[Datos en SCHEMA 100_test]")

        cur.execute("SELECT COUNT(*) FROM \"100_test\".settings")
        settings_count = cur.fetchone()[0]
        print(f"  Settings: {settings_count}")

        cur.execute("SELECT COUNT(*) FROM \"100_test\".estado_users")
        estado_users_count = cur.fetchone()[0]
        print(f"  Estado Users: {estado_users_count}")

        cur.execute("SELECT COUNT(*) FROM \"100_test\".city_seals")
        city_seals_count = cur.fetchone()[0]
        print(f"  City Seals: {city_seals_count}")

        cur.execute("SELECT COUNT(*) FROM \"100_test\".document_types")
        doc_types_tenant_count = cur.fetchone()[0]
        print(f"  Document Types: {doc_types_tenant_count}")

        cur.execute("SELECT COUNT(*) FROM \"100_test\".case_templates")
        case_templates_tenant_count = cur.fetchone()[0]
        print(f"  Case Templates: {case_templates_tenant_count}")

        # 6. Verificar audit
        print(f"\n[Datos en SCHEMA 100_test_audit]")

        cur.execute("SELECT COUNT(*) FROM \"100_test_audit\".audit_log")
        audit_log_count = cur.fetchone()[0]
        print(f"  Audit Logs: {audit_log_count}")

        print(f"\n" + "="*80)
        print("[OK] Base de datos verificada correctamente")
        print("="*80 + "\n")

        cur.close()
        conn.close()

    except psycopg2.Error as e:
        print(f"[ERROR] {e}")
        sys.exit(1)

if __name__ == "__main__":
    verify()
