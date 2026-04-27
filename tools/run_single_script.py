#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Ejecutar un script SQL individual
"""

import psycopg2
import sys
import os
from pathlib import Path

# Cargar .env si existe
env_path = Path(__file__).parent.parent / ".env"
if env_path.exists():
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                os.environ.setdefault(key.strip(), value.strip())

# Configuración de conexión via variable de entorno
DATABASE_URL = os.environ.get("DATABASE_URL")
if not DATABASE_URL:
    print("[ERROR] Variable de entorno DATABASE_URL no configurada")
    print("Ejemplo: export DATABASE_URL='postgresql://user:pass@host:port/db'")
    sys.exit(1)

# Directorio de archivos SQL
SQL_DIR = Path(__file__).parent.parent / "sql"

def run_script(script_file):
    try:
        script_path = SQL_DIR / script_file

        if not script_path.exists():
            print(f"[ERROR] Archivo no encontrado: {script_path}")
            return False

        with open(script_path, 'r', encoding='utf-8') as f:
            sql = f.read()

        conn = psycopg2.connect(DATABASE_URL)
        cur = conn.cursor()

        print(f"\nEjecutando: {script_file}\n")
        cur.execute(sql)
        conn.commit()

        print(f"\n[OK] {script_file} completado exitosamente")

        cur.close()
        conn.close()
        return True

    except psycopg2.Error as e:
        print(f"[ERROR] {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Uso: python run_single_script.py <nombre_script.sql>")
        print(f"Directorio SQL: {SQL_DIR}")
        sys.exit(1)

    script_file = sys.argv[1]
    success = run_script(script_file)
    sys.exit(0 if success else 1)
