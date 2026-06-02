#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Instalacion limpia de BD para 100_test
Elimina y recrea todo: public + 100_test + 100_test_audit

Flujo: 01-install.sql → 02-seed-global.sql → 04-seed-demo.sql

Uso:
    export DATABASE_URL='postgresql://user:pass@host:port/db'
    python tools/install.py
"""

import psycopg2
import sys
import os
from pathlib import Path

# Configurar encoding
os.environ['PYTHONIOENCODING'] = 'utf-8'
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

# Directorio de archivos SQL
SQL_DIR = Path(__file__).parent.parent / "sql"

# Configuracion de conexion via variable de entorno
DATABASE_URL = os.environ.get("DATABASE_URL")
if not DATABASE_URL:
    print("[ERROR] Variable de entorno DATABASE_URL no configurada")
    print("Ejemplo: export DATABASE_URL='postgresql://user:pass@host:port/db'")
    sys.exit(1)


def read_script(script_path):
    """Lee un archivo SQL"""
    with open(script_path, 'r', encoding='utf-8') as f:
        return f.read()


def execute_script(conn, script_name, sql):
    """Ejecuta un script SQL"""
    try:
        with conn.cursor() as cur:
            print(f"\n{'='*70}")
            print(f"  Ejecutando: {script_name}")
            print(f"{'='*70}")
            cur.execute(sql)
            conn.commit()
            print(f"  [OK] {script_name} completado")
            return True
    except psycopg2.Error as e:
        conn.rollback()
        print(f"  [ERROR] Error en {script_name}:")
        print(f"    {e}")
        return False


def main():
    """Funcion principal"""
    print(f"\n{'='*70}")
    print("  GDI LATAM - INSTALACION LIMPIA (100_test)")
    print(f"{'='*70}")
    print(f"\n  DATABASE_URL: {DATABASE_URL[:40]}...")
    print(f"  Flujo: 01-install.sql -> 02-seed-global.sql -> 04-seed-demo.sql")
    print(f"\n  ATENCION: Esto eliminara los schemas 100_test y 100_test_audit")
    print(f"  y recreara toda la estructura desde cero.\n")

    confirm = input("  Continuar? (s/N): ").strip().lower()
    if confirm not in ('s', 'si', 'y', 'yes'):
        print("\n  [CANCELADO]")
        return 0

    # Conectar
    try:
        conn = psycopg2.connect(DATABASE_URL)
        print("\n  [OK] Conectado a la base de datos")
    except psycopg2.Error as e:
        print(f"  [ERROR] No se pudo conectar: {e}")
        return 1

    # Guard: verificar que no estamos conectados a una BD de produccion.
    # Los hostnames de PRD en Fly.io contienen 'prd' o 'demo'.
    # El tunnel local de DEV siempre pasa por localhost:5433.
    prd_indicators = ['prd', 'aries-postgres', 'arg-postgres', 'demo-postgres']
    db_url_lower = DATABASE_URL.lower()
    if any(ind in db_url_lower for ind in prd_indicators):
        print("\n  [ERROR] La DATABASE_URL parece apuntar a una BD de PRODUCCION.")
        print("  install.py es EXCLUSIVO para DEV (100_test). Abortar.")
        conn.close()
        return 1

    # Paso 1: DROP schemas existentes
    print(f"\n{'='*70}")
    print(f"  PASO 1: Limpiar schemas existentes")
    print(f"{'='*70}")

    try:
        with conn.cursor() as cur:
            cur.execute('DROP SCHEMA IF EXISTS "100_test" CASCADE')
            print(f"  [OK] DROP SCHEMA 100_test")
            cur.execute('DROP SCHEMA IF EXISTS "100_test_audit" CASCADE')
            print(f"  [OK] DROP SCHEMA 100_test_audit")
            # Limpiar municipio de public.municipalities si existe
            cur.execute("DELETE FROM public.municipalities WHERE schema_name = '100_test'")
            conn.commit()
            print(f"  [OK] Limpieza completada")
    except psycopg2.Error as e:
        conn.rollback()
        print(f"  [WARN] Error al limpiar (puede ser primera instalacion): {e}")

    # Paso 2: Ejecutar scripts en orden
    print(f"\n{'='*70}")
    print(f"  PASO 2: Ejecutar scripts SQL")
    print(f"{'='*70}")

    # Scripts sin placeholders (04-seed-demo.sql tiene todo hardcoded)
    scripts = [
        "01-install.sql",
        "02-seed-global.sql",
        "04-seed-demo.sql",
    ]

    success_count = 0
    total = len(scripts)

    for script_file in scripts:
        script_path = SQL_DIR / script_file

        if not script_path.exists():
            print(f"\n  [SKIP] Archivo no encontrado: {script_file}")
            continue

        sql = read_script(script_path)

        if execute_script(conn, script_file, sql):
            success_count += 1
        else:
            print(f"\n  [ABORT] Error en {script_file}. Abortando.")
            break

    conn.close()

    # Paso 3: Verificacion
    print(f"\n{'='*70}")
    print(f"  PASO 3: Verificacion")
    print(f"{'='*70}\n")

    # Importar y ejecutar verify
    try:
        tools_dir = str(Path(__file__).parent)
        if tools_dir not in sys.path:
            sys.path.insert(0, tools_dir)
        from verify_db import verify
        verify()
    except ImportError:
        print("  [WARN] No se pudo importar verify_db.py, saltando verificacion")
    except Exception as e:
        print(f"  [WARN] Error en verificacion: {e}")

    # Resultado final
    print(f"\n{'='*70}")
    print(f"  RESULTADO: {success_count}/{total} scripts ejecutados")
    print(f"{'='*70}")

    if success_count == total:
        print(f"\n  [OK] Instalacion limpia completada exitosamente!")
        return 0
    else:
        print(f"\n  [ERROR] Algunos scripts fallaron. Revisar errores arriba.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
