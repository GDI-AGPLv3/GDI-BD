# GDI LATAM - Base de Datos PostgreSQL 17

Repositorio de scripts SQL y herramientas Python para la base de datos multi-tenant de GDI Latam.

## Resumen

**Estructura:** 1 schema publico + N schemas por municipio + N schemas de auditoria
**Tablas:** 9 publicas + 33 por municipio + 1 auditoria por municipio
**Deploy:** Docker custom en Fly.io con init automatico
**Extensiones:** pgvector 0.8.1, unaccent 1.1, pg_trgm 1.6

## Deploy en Fly.io

```bash
cd GDI-BD

# 1. Crear app + volumen + password
flyctl apps create <your-postgres-app> --org personal
flyctl volumes create pg_data --region gru --size 1 --app <your-postgres-app> --yes
flyctl secrets set POSTGRES_PASSWORD=tu_password --app <your-postgres-app>

# 2. Deploy (build + init automatico)
flyctl deploy --app <your-postgres-app>

# 3. Verificar
flyctl proxy 5433:5432 -a <your-postgres-app>
# En otra terminal:
python tools/verify_fly.py
```

El Dockerfile copia los SQL a `docker-entrypoint-initdb.d/`. Se ejecutan automaticamente en el primer boot (PGDATA vacio). La BD se llama `railway` (compatibilidad con backends).

### Conexion

| Contexto | Connection String |
|----------|-------------------|
| Servicios Fly (interna) | `postgresql://postgres:PASSWORD@<your-postgres-app>.internal:5432/railway` |
| Local via proxy | `postgresql://postgres:PASSWORD@localhost:5433/railway` |

### Redespliegue limpio

```bash
flyctl apps destroy <your-postgres-app> --yes
# Repetir pasos 1-3
```

## Instalacion Local (sin Docker)

```bash
# 1. Configurar .env
cd GDI-BD
cp .env.example .env
# Editar DATABASE_URL con tu conexion PostgreSQL

# 2. Instalacion limpia de 100_test (dev/test)
cd tools
python install.py

# 3. Crear municipio nuevo (produccion)
python create_municipio.py
```

## Estructura de Carpetas

```
GDI-BD/
├── Dockerfile                    # PostgreSQL 17 + pgvector (deploy Fly.io)
├── fly.toml                      # Config Fly.io (app, volumen, VM)
├── .dockerignore                 # Excluye tools, docs, .env del build
│
├── sql/                          # Scripts SQL (5 archivos)
│   ├── 01-install.sql            # BD nueva: extensiones + enums + 9 tablas public
│   ├── 02-seed-global.sql        # Datos globales: roles, doc types, case templates
│   ├── 02b-seed-agente.sql       # Tablas GDI-AgenteLANG (chat, checkpoints, usage)
│   ├── 03-create-municipio.sql   # Crear municipio real (template con placeholders)
│   └── 04-seed-demo.sql          # Crear 100_test + datos demo (autonomo, sin placeholders)
│
├── tools/                        # Scripts Python
│   ├── create_municipio.py       # Crear municipio nuevo (interactivo, usa 03)
│   ├── install.py                # Instalacion limpia de 100_test (01→02→04)
│   ├── run_single_script.py      # Ejecutar script SQL individual
│   ├── verify_db.py              # Verificar integridad de BD
│   └── verify_fly.py             # Verificar deploy en Fly.io
│
├── .env.example                  # Template credenciales
├── .gitignore
└── README.md
```

## Flujo de Deploy

### Produccion (municipio nuevo)

```
01-install.sql            ← 9 tablas publicas + extensiones (una vez)
↓
02-seed-global.sql        ← Roles, doc types, case templates (una vez)
↓
03-create-municipio.sql   ← Schema + audit + settings + registro (por municipio)
```

### Dev/Test (100_test)

```
01-install.sql            ← 9 tablas publicas + extensiones
↓
02-seed-global.sql        ← Datos globales
↓
04-seed-demo.sql          ← 100_test completo con datos demo (autonomo)
```

## Placeholders de 03-create-municipio.sql

| Placeholder | Ejemplo | Descripcion |
|-------------|---------|-------------|
| {SCHEMA_NAME} | 100_test | Nombre del schema |
| {MUNICIPALITY_NAME} | Test Municipality | Nombre del municipio |
| {ACRONYM} | TXST | Acronimo 4 chars |
| {COUNTRY} | AR | Codigo pais (enum) |
| {SCHEMA_NUMBER} | 100 | Numero auto-incremental |
| {BUCKET_OFICIAL} | gdi-txst-oficial | Bucket Cloudflare R2 |
| {BUCKET_TOSIGN} | gdi-txst-tosign | Bucket Cloudflare R2 |
| {CITY} | LATAM | Ciudad para firma digital |
| {PRIMARY_COLOR} | 16158C | Color sin # |

## Tablas del Schema PUBLIC (9)

| # | Tabla | Descripcion |
|---|-------|-------------|
| 1 | `roles` | 3 roles (Usuario General, Funcionario, Administrador) |
| 2 | `global_document_types` | Tipos de documento globales (61) |
| 3 | `global_case_templates` | Plantillas de expediente globales (30) |
| 4 | `municipalities` | Registro de municipios activos |
| 5 | `document_display_states` | 6 estados de visualizacion |
| 6 | `user_registry` | Mapeo email -> schema de municipio |
| 7 | `api_keys` | API Keys para REST API (GDI-MCP Server) |
| 8 | `api_key_users` | Usuarios autorizados por API Key |
| 9 | `global_registry_families` | Familias de registros con schema por defecto |

## Tablas del Schema MUNICIPIO (33)

### Grupo A: Estructura (2)
`departments` | `sectors`

### Grupo B: Usuarios (5)
`users` | `user_roles` | `user_seals` | `user_sector_permissions` | `estado_users`

### Grupo C: Rangos y Sellos (2)
`ranks` | `city_seals`

### Grupo D: Documentos (7)
`document_types` | `document_types_allowed_by_rank` | `enabled_document_types_by_sector` | `document_draft` | `document_signers` | `document_rejections` | `official_documents`

### Grupo E: Expedientes (6)
`case_templates` | `case_template_allowed_departments` | `cases` | `case_movements` | `case_official_documents` | `case_proposed_documents`

### Grupo F: Configuracion (1)
`settings`

### Grupo G: Agente IA (1)
`document_chunks`

### Grupo H: Notas (2)
`notes_recipients` | `notes_openings`

### Grupo I: Registros (7)
`registry_families` | `registry_family_permissions` | `records` | `record_history` | `record_relations` | `record_case_links` | `record_document_links`

## Verificar Deploy

```bash
cd tools
python verify_db.py
```

## Crear Nuevo Municipio

```bash
cd tools
python create_municipio.py
```

El script pregunta: nombre, acronimo, pais, ciudad, color. Ejecuta `03-create-municipio.sql` automaticamente y muestra instrucciones para los buckets R2.

## Cloudflare R2 - Buckets Requeridos

Cada municipio necesita 2 buckets (crear manualmente):
- `gdi-{acronym}-oficial` - Documentos oficiales firmados
- `gdi-{acronym}-tosign` - Documentos pendientes de firma

## Variables de Entorno

```bash
# .env (copiar desde .env.example)
DATABASE_URL=postgresql://user:pass@host:port/railway
```

### Fly.io

| Variable | Donde | Valor |
|----------|-------|-------|
| `POSTGRES_PASSWORD` | `fly secrets` | Password de postgres |
| `POSTGRES_DB` | `fly.toml [env]` | `railway` |
| `PGDATA` | `fly.toml [env]` | `/var/lib/postgresql/data/pgdata` |

## Tecnologia

- **PostgreSQL:** 17.0+
- **pgvector:** 0.8.1 (busqueda semantica / RAG)
- **unaccent:** 1.1 (busquedas sin acentos)
- **pg_trgm:** 1.6 (busqueda por similitud)
- **Python:** 3.11+ (psycopg2)
- **Docker:** pgvector/pgvector:pg17
- **Deploy:** Fly.io (region gru, Sao Paulo)
- **Multi-tenant:** 1 schema por municipio

---

**Version:** 7.0.0
**Ultima actualizacion:** 2026-02-20
