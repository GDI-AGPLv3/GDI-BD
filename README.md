# GDI-BD

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![PostgreSQL 17+](https://img.shields.io/badge/PostgreSQL-17%2B-336791.svg)](https://www.postgresql.org/)

Schema PostgreSQL para el **Sistema de Gestion Documental Inteligente (GDI)** - una plataforma de gestion documental multi-tenant disenada para gobiernos de America Latina.

## Que Contiene

Este repositorio publica el **schema publico** de GDI: las tablas globales compartidas por todos los municipios (tenants).

| Archivo | Descripcion | Lineas |
|---------|-------------|--------|
| `sql/01-install.sql` | Extensiones, enums y 9 tablas globales | 369 |
| `sql/02-seed-global.sql` | Datos de catalogo iniciales | 197 |

## Requisitos

- **PostgreSQL 17+**
- Extensiones: `pgvector`, `unaccent`, `pg_trgm`

## Instalacion Rapida

```bash
# Crear base de datos
createdb gdi

# Instalar schema publico (tablas globales)
psql -d gdi -f sql/01-install.sql

# Cargar datos de catalogo
psql -d gdi -f sql/02-seed-global.sql
```

## Tablas del Schema Publico (9)

| # | Tabla | Descripcion |
|---|-------|-------------|
| 1 | `roles` | Roles globales del sistema |
| 2 | `global_document_types` | Tipos de documento (61 tipos) |
| 3 | `global_case_templates` | Plantillas de expediente (30 templates) |
| 4 | `municipalities` | Lista de municipios (cada uno = un schema) |
| 5 | `document_display_states` | Estados de visualizacion de documentos |
| 6 | `user_registry` | Mapeo email-schema para multi-tenant |
| 7 | `api_keys` | API Keys para REST API (GDI-MCP Server) |
| 8 | `api_key_users` | Usuarios autorizados por API Key |
| 9 | `global_registry_families` | Familias de registros globales |

## Datos Seed (02-seed-global.sql)

| Catalogo | Cantidad | Ejemplos |
|----------|----------|----------|
| Roles | 3 | Usuario General, Funcionario, Administrador |
| Tipos de Documento | 61 | Informe, Decreto, Resolucion, Nota, Acta... |
| Plantillas de Expediente | 30 | Licitacion Publica, Obra Publica, Habilitacion Comercial... |
| Estados de Visualizacion | 6 | Borrador, Pendiente de Firma, Firmado, Numerado... |
| Familias de Registros | 3 | Arquitectura (ARQ), Luminarias (LUM), Normativa (ORD) |

## Tipos Enumerados

```
country_enum         AR, BR, UY, CL, PY, BO, PE, EC, CO, VE, MX
document_status      draft, sent_to_sign, signed, rejected, cancelled
document_signer_status  pending, signed, rejected
movement_type        creation, transfer, assignment, assignment_close,
                     status_change, document_link, subsanacion,
                     document_proposal, document_proposal_reject
status_case          inactive, active, archived
case_creation_channel   web, api, both
document_type_source    HTML, Importado, NOTA
```

## Arquitectura Multi-Tenant

GDI usa un modelo de **schema-per-tenant**: cada municipio tiene su propio schema PostgreSQL con sus tablas locales (usuarios, documentos, expedientes, etc.). Las tablas en `public` son globales y compartidas.

```
PostgreSQL
+-- public              <-- Este repositorio (9 tablas globales)
|   +-- roles
|   +-- global_document_types
|   +-- municipalities
|   +-- ...
+-- 100_test            <-- Schema municipio (ejemplo)
|   +-- users
|   +-- departments
|   +-- official_documents
|   +-- ... (33 tablas)
+-- 101_bsas            <-- Otro municipio
|   +-- ... (33 tablas)
+-- {N}_audit           <-- Auditoria por municipio
    +-- audit_log
```

## Ecosistema GDI

GDI es un sistema modular. Otros componentes open source:

| Componente | Repositorio |
|------------|-------------|
| Backend API (FastAPI) | [GDI-Backend](https://github.com/GDI-APGLv3/GDI-Backend) |
| Frontend (Next.js) | [GDI-Frontend](https://github.com/GDI-APGLv3/GDI-Frontend) |
| Documentacion | [Site-Docs](https://github.com/GDI-APGLv3/Site-Docs) |

## Licencia

Este proyecto esta licenciado bajo la **GNU Affero General Public License v3.0** - ver el archivo [LICENSE](LICENSE) para detalles.

---

Desarrollado por [GDI Latam](https://github.com/GDI-APGLv3) para gobiernos de America Latina.
