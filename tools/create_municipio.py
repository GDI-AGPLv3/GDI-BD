#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Crear municipio nuevo en GDI Latam (interactivo)
Ejecuta 03-create-municipio.sql con reemplazo de placeholders.

Uso:
    export DATABASE_URL='postgresql://user:pass@host:port/db'
    python tools/create_municipio.py
"""

import psycopg2
import sys
import os
import re
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


def replace_placeholders(sql, replacements):
    """Reemplaza placeholders en el SQL usando un diccionario"""
    for key, value in replacements.items():
        sql = sql.replace(key, str(value))
    return sql


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


def get_next_schema_number(conn):
    """Consulta MAX(schema_number) de public.municipalities y retorna +1"""
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT COALESCE(MAX(schema_number), 99) FROM public.municipalities")
            max_num = cur.fetchone()[0]
            return max_num + 1
    except psycopg2.Error as e:
        print(f"  [WARN] No se pudo consultar schema_number: {e}")
        conn.rollback()
        return 101


def ask_input(prompt, default=None, validator=None, error_msg=None):
    """Pide input al usuario con validacion opcional"""
    while True:
        if default:
            raw = input(f"  {prompt} [{default}]: ").strip()
            value = raw if raw else default
        else:
            value = input(f"  {prompt}: ").strip()
            if not value:
                print("    (campo obligatorio)")
                continue
        if validator and not validator(value):
            print(f"    {error_msg or '(valor invalido)'}")
            continue
        return value


def verify_schema(conn, schema_name):
    """Verifica que el schema se creo correctamente"""
    try:
        with conn.cursor() as cur:
            # Contar tablas en el schema
            cur.execute("""
                SELECT COUNT(*) FROM information_schema.tables
                WHERE table_schema = %s AND table_type = 'BASE TABLE'
            """, (schema_name,))
            table_count = cur.fetchone()[0]
            print(f"  Tablas en {schema_name}: {table_count}")

            # Contar tablas en schema audit
            audit_schema = f"{schema_name}_audit"
            cur.execute("""
                SELECT COUNT(*) FROM information_schema.tables
                WHERE table_schema = %s AND table_type = 'BASE TABLE'
            """, (audit_schema,))
            audit_count = cur.fetchone()[0]
            print(f"  Tablas en {audit_schema}: {audit_count}")

            # Verificar municipio en public.municipalities
            cur.execute("""
                SELECT name, acronym, schema_name, is_active
                FROM public.municipalities
                WHERE schema_name = %s
            """, (schema_name,))
            muni = cur.fetchone()
            if muni:
                print(f"  Municipio: {muni[0]} ({muni[1]}) - schema: {muni[2]} - activo: {muni[3]}")
            else:
                print(f"  [WARN] Municipio no encontrado en public.municipalities")

            # Verificar settings
            cur.execute(f'SELECT COUNT(*) FROM "{schema_name}".settings')
            settings_count = cur.fetchone()[0]
            print(f"  Settings: {settings_count}")

            # Verificar departamento ROOT
            cur.execute(f"SELECT COUNT(*) FROM \"{schema_name}\".departments WHERE acronym = 'ROOT'")
            root_count = cur.fetchone()[0]
            print(f"  Departamento ROOT: {'OK' if root_count > 0 else 'FALTA'}")

            # Verificar case_templates
            cur.execute(f'SELECT COUNT(*) FROM "{schema_name}".case_templates')
            ct_count = cur.fetchone()[0]
            print(f"  Case Templates: {ct_count}")

            return table_count > 0

    except psycopg2.Error as e:
        print(f"  [ERROR] Verificacion fallida: {e}")
        conn.rollback()
        return False


def main():
    """Funcion principal - flujo interactivo"""
    print(f"\n{'='*70}")
    print("  GDI LATAM - CREAR MUNICIPIO NUEVO")
    print(f"{'='*70}\n")

    # Conectar a BD para obtener schema_number
    try:
        conn = psycopg2.connect(DATABASE_URL)
        print("  [OK] Conectado a la base de datos\n")
    except psycopg2.Error as e:
        print(f"  [ERROR] No se pudo conectar: {e}")
        return 1

    next_schema = get_next_schema_number(conn)

    # --- Paso 1: Datos del municipio ---
    print("  --- Datos del municipio ---\n")

    municipality_name = ask_input("Nombre del municipio (ej: Municipalidad de La Plata)")

    acronym = ask_input(
        "Acronimo (4 chars max, ej: LPLA)",
        validator=lambda v: bool(re.match(r'^[A-Za-z]{2,4}$', v)),
        error_msg="(debe ser 2-4 letras, sin numeros ni espacios)"
    ).upper()

    country = ask_input(
        "Codigo pais (2 chars)",
        default="AR",
        validator=lambda v: bool(re.match(r'^[A-Z]{2}$', v.upper())),
        error_msg="(debe ser 2 letras, ej: AR, BR, UY)"
    ).upper()

    city = ask_input("Ciudad (ej: La Plata, Buenos Aires)")

    primary_color = ask_input(
        "Color primario hex sin # (ej: 16158C)",
        default="16158C",
        validator=lambda v: bool(re.match(r'^[0-9A-Fa-f]{6}$', v)),
        error_msg="(debe ser 6 chars hex, ej: 16158C, 006400, FF0000)"
    )

    # --- Paso 2: Buckets R2 ---
    acr_lower = acronym.lower()
    print(f"\n  --- Buckets Cloudflare R2 ---\n")

    bucket_oficial = ask_input(
        "Bucket oficial",
        default=f"gdi-{acr_lower}-oficial"
    )

    bucket_tosign = ask_input(
        "Bucket tosign",
        default=f"gdi-{acr_lower}-tosign"
    )

    # --- Paso 3: Auto-calcular schema ---
    schema_number = next_schema
    schema_name = f"{schema_number}_{acr_lower}"
    audit_schema_name = f"{schema_name}_audit"

    # --- Paso 4: Resumen ---
    print(f"\n{'='*70}")
    print("  RESUMEN - Nuevo Municipio")
    print(f"{'='*70}")
    print(f"  Nombre:          {municipality_name}")
    print(f"  Acronimo:        {acronym}")
    print(f"  Pais:            {country}")
    print(f"  Ciudad:          {city}")
    print(f"  Color primario:  #{primary_color}")
    print(f"  Schema number:   {schema_number}")
    print(f"  Schema name:     {schema_name}")
    print(f"  Audit schema:    {audit_schema_name}")
    print(f"  Bucket oficial:  {bucket_oficial}")
    print(f"  Bucket tosign:   {bucket_tosign}")
    print(f"{'='*70}")

    confirm = input("\n  Confirmar creacion? (s/N): ").strip().lower()
    if confirm not in ('s', 'si', 'y', 'yes'):
        print("\n  [CANCELADO] No se creo el municipio.")
        conn.close()
        return 0

    # --- Paso 5: Ejecutar script SQL ---
    print(f"\n{'='*70}")
    print("  EJECUTANDO 03-create-municipio.sql")
    print(f"{'='*70}")

    # Placeholders
    replacements = {
        "{SCHEMA_NAME}": schema_name,
        "{BUCKET_OFICIAL}": bucket_oficial,
        "{BUCKET_TOSIGN}": bucket_tosign,
        "{CITY}": city,
        "{PRIMARY_COLOR}": primary_color,
        "{MUNICIPALITY_NAME}": municipality_name,
        "{ACRONYM}": acronym,
        "{COUNTRY}": country,
        "{SCHEMA_NUMBER}": str(schema_number),
    }

    script_path = SQL_DIR / "03-create-municipio.sql"
    if not script_path.exists():
        print(f"\n  [ERROR] Archivo no encontrado: {script_path}")
        conn.close()
        return 1

    sql = read_script(script_path)
    sql = replace_placeholders(sql, replacements)

    success = execute_script(conn, "03-create-municipio.sql", sql)

    # --- Paso 6: Verificacion ---
    print(f"\n{'='*70}")
    print("  VERIFICACION")
    print(f"{'='*70}\n")

    verify_schema(conn, schema_name)

    conn.close()

    # --- Paso 7: Resumen final ---
    print(f"\n{'='*70}")
    print(f"  RESULTADO: {'OK' if success else 'ERROR'}")
    print(f"{'='*70}")

    if success:
        print(f"\n  [OK] Municipio '{municipality_name}' creado exitosamente!")
        print(f"\n  --- PASOS MANUALES PENDIENTES ---")
        print(f"  1. Crear buckets en Cloudflare R2:")
        print(f"     - {bucket_oficial}")
        print(f"     - {bucket_tosign}")
        print(f"  2. Configurar permisos CORS en los buckets")
        print(f"  3. Crear usuarios reales en Auth0 y asociarlos al schema {schema_name}")
        print(f"  4. (Opcional) Subir logo y isologo via BackOffice")
        print(f"{'='*70}\n")
        return 0
    else:
        print(f"\n  [ERROR] Script fallo. Revisar errores arriba.")
        print(f"  Si es necesario, limpiar con:")
        print(f"    DROP SCHEMA IF EXISTS \"{schema_name}\" CASCADE;")
        print(f"    DROP SCHEMA IF EXISTS \"{audit_schema_name}\" CASCADE;")
        print(f"    DELETE FROM public.municipalities WHERE schema_name = '{schema_name}';")
        print(f"{'='*70}\n")
        return 1


if __name__ == "__main__":
    sys.exit(main())
