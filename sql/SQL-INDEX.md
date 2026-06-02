# SQL-INDEX.md - Indice y Auditoria de Scripts SQL

Generado: 2026-02-26
Base de datos auditada: <your-postgres-app> (Fly.io) via localhost:5433, db `railway`

---

## 1. Resumen Ejecutivo

### Veredicto: Los 4 SQLs principales pueden recrear la BD completa desde cero. OK.

Los archivos `01-install.sql`, `02-seed-global.sql`, `02b-seed-agente.sql` y `04-seed-demo.sql` cubren **el 100% de la estructura existente** en DEV. No hay tablas huerfanas ni columnas faltantes.

| Metrica | SQL Local | BD DEV | Estado |
|---------|-----------|--------|--------|
| Tablas public | 10 (01-install) + 7 (02b-seed-agente) = 17 | 17 | OK |
| Tablas 100_test | 33 (04-seed-demo) | 33 | OK |
| Tablas 100_test_audit | 1 (04-seed-demo) | 1 | OK |
| Enums | 7 (01-install) | 7 | OK |
| Extensiones | 3 (vector, unaccent, pg_trgm) | 3 + plpgsql | OK |
| Triggers 100_test | 7 (6 audit + 1 sync) | 7 | OK |

---

## 2. Inventario de Archivos SQL

### 2.1 Scripts Principales (sql/)

| # | Archivo | Que hace | Schema | Orden | Estado |
|---|---------|----------|--------|-------|--------|
| 1 | `01-install.sql` | Crea extensiones (vector, unaccent, pg_trgm), 7 enums, 10 tablas en public (roles, global_document_types, global_case_templates, municipalities, document_display_states, user_registry, api_keys, api_key_users, global_registry_families, tenant_certificates) con indices y constraints | `public` | 1ro | **OK** |
| 2 | `02-seed-global.sql` | Inserta datos iniciales: 3 roles, 61 global_document_types, 30 global_case_templates, 6 document_display_states, 3 global_registry_families | `public` | 2do | **OK** |
| 3 | `02b-seed-agente.sql` | Crea 7 tablas de GDI-AgenteLANG en public: chat_messages, ai_usage_log, ai_usage_limits, checkpoint_migrations (+ seed v0-v9), checkpoints, checkpoint_blobs, checkpoint_writes. Todas con `CREATE TABLE IF NOT EXISTS` (idempotente) | `public` | 3ro (o paralelo a 02) | **OK** |
| 4 | `03-create-municipio.sql` | Template con 9 placeholders para crear municipio real: schema con 33 tablas (Grupos A-I) + indices + trigger sync_user_registry + schema audit (audit_log + fn_log_change + 6 triggers) + datos iniciales (settings, estado_users, municipio, ROOT dept, 2 case_templates) | `{SCHEMA_NAME}` + `{SCHEMA_NAME}_audit` + `public` | Produccion: 4to | **OK** |
| 5 | `04-seed-demo.sql` | Archivo autonomo que crea schema 100_test completo: 33 tablas + indices + triggers + audit + datos demo (10 depts, 14 sectors, 3 ranks, 4 seals, 16 users, 20 doc types, 6 case templates, 3 registry families, 5 drafts, API key, ai_usage_limits) | `100_test` + `100_test_audit` + `public` | Dev: 4to | **OK** |

### 2.2 Migraciones (sql/migrations/)

| # | Archivo | Que hace | Estado |
|---|---------|----------|--------|
| 0 | `044_document_chunks_hybrid.sql` | Multi-tenant: agrega `text_for_embedding TEXT` + `content_tsv tsvector GENERATED ALWAYS STORED` + índice GIN en `document_chunks` de todos los schemas con esa tabla. Habilita Hybrid Search (Vector + BM25) y headers contextuales. Proyecto MejorasLANG V1 Sprint 1. | **ACTIVO** - Aplicada en DEV (2026-04-29). DEMO/ARIES/ARG postpuestos. |
| 1 | `043_rag_query_log.sql` | Crea `public.rag_query_log` para auditoría del endpoint semantic_search. 15 columnas (contexto, query, retrieval, performance). 3 índices: (schema_name, created_at DESC), GIN trigram sobre query, partial sobre final_returned=0. Proyecto MejorasLANG V1 Sprint 0. | **ACTIVO** - Aplicada en DEV (2026-04-29). PRD postpuesto. |

> **Nota 2026-06-01**: las migraciones 058, 059 y 060 fueron archivadas en `sql/migrations/archive/` porque sus índices ya están horneados en los dos templates canónicos (ver sección 2.3 y 7 abajo).

#### Índices de mig 059/060 — ahora en los templates

Los 3 índices de performance de las migraciones 059 y 060 fueron incorporados directamente en:
- `sql/03-create-municipio.sql` (fuente de verdad)
- `GDI-BackOffice-Back/sql/03-create-web-schema.sql` (copia operativa)

Nuevos municipios los heredan automáticamente sin necesidad de migración adicional.

| Índice | Tabla | Tipo | Origen |
|--------|-------|------|--------|
| `idx_{SCHEMA_NAME}_document_draft_resume_null` | `document_draft` | Parcial `WHERE resume IS NULL` en `(id)` | mig 059 |
| `idx_{SCHEMA_NAME}_official_documents_resume_null` | `official_documents` | Parcial `WHERE resume IS NULL` en `(id)` | mig 059 |
| `idx_{SCHEMA_NAME}_departments_head_user_id` | `departments` | BTREE en `(head_user_id)` | mig 060 |
| 1 | `014_add_notes_tables.sql` | Template generico: crea notes_recipients + notes_openings por schema | **OBSOLETO** - Integrado en 03 y 04 |
| 2 | `014_add_cases_performance_indexes.sql` | 4 indices de performance para case_movements y case_official_documents | **OBSOLETO** - Integrado en 03 y 04 |
| 3 | `014_apply_to_100_test.sql` | Aplica notas especificamente a 100_test | **OBSOLETO** - Integrado en 04 |
| 4 | `015_add_auth_source_to_audit.sql` | Agrega columna auth_source a audit_log + actualiza fn_log_change | **OBSOLETO** - Integrado en 03 y 04 |
| 5 | `016_add_api_key_users.sql` | Crea tabla public.api_key_users | **OBSOLETO** - Integrado en 01 |
| 6 | `017_add_nota_to_document_type_source.sql` | Agrega valor 'NOTA' al enum document_type_source | **OBSOLETO** - Integrado en 01 |
| 7 | `018_add_notes_archived.sql` | Template: agrega is_archived + archived_at a notes_recipients | **OBSOLETO** - Integrado en 03 y 04 |
| 8 | `022_add_assignment_close_movement_type.sql` | Agrega 'assignment_close' al enum movement_type | **OBSOLETO** - Integrado en 01 |
| 9 | `023_add_primary_color_departments_sectors.sql` | Agrega primary_color a departments y sectors | **OBSOLETO** - Integrado en 03 y 04 |
| 10 | `024_add_global_search_flags.sql` | Agrega can_global_search_documents/cases a users | **OBSOLETO** - Integrado en 03 y 04 |
| 11 | `025_add_trust_to_document_types.sql` | Agrega columna trust a global_document_types y tenant document_types | **OBSOLETO** - Integrado en 01 y 03/04 |
| 12 | `026_add_scalability_indexes.sql` | 4 indices de escalabilidad (cases, document_draft, document_signers) | **OBSOLETO** - Integrado en 03 y 04 |
| 13 | `027_add_tenant_certificates.sql` | Crea tabla public.tenant_certificates | **OBSOLETO** - Integrado en 01 |

### 2.3 Archivos Sueltos (raiz GDI-BD/)

| Archivo | Que hace | Estado |
|---------|----------|--------|
| `truncate_100_test.sql` | TRUNCATE de tablas de 100_test. **Referencia tablas eliminadas**: tool_executions, pending_actions, messages, conversations, rank_seals, enabled_document_types_by_department | **DESACTUALIZADO** - Nombres de tabla obsoletos |
| `verify_counts.sql` | SELECT COUNT de tablas principales de 100_test | **OK** (funcional, aunque basico) |

---

## 3. Flujo de Ejecucion Recomendado

### Dev/Test (100_test)
```
01-install.sql --> 02-seed-global.sql --> 02b-seed-agente.sql --> 04-seed-demo.sql
```

### Produccion (municipio nuevo)
```
01-install.sql --> 02-seed-global.sql --> 02b-seed-agente.sql --> 03-create-municipio.sql (con placeholders reemplazados)
```

**IMPORTANTE**: 01+02+02b solo se ejecutan una vez (primera BD). Para agregar municipios adicionales, solo se ejecuta 03.

---

## 4. Comparacion Detallada: SQL vs BD DEV

### 4.1 Schema `public` - 17 tablas en BD

| Tabla en BD | Cubierta por SQL | Notas |
|-------------|------------------|-------|
| roles | 01-install.sql | OK - Coincide exactamente |
| global_document_types | 01-install.sql | OK - Coincide (incluye trust, is_visible) |
| global_case_templates | 01-install.sql | OK - Coincide |
| municipalities | 01-install.sql | OK - Coincide |
| document_display_states | 01-install.sql | OK - Coincide |
| user_registry | 01-install.sql | OK - Coincide |
| api_keys | 01-install.sql | OK - Coincide |
| api_key_users | 01-install.sql | OK - Coincide |
| global_registry_families | 01-install.sql | OK - Coincide |
| tenant_certificates | 01-install.sql | OK - Coincide |
| chat_messages | 02b-seed-agente.sql | OK - Coincide |
| ai_usage_log | 02b-seed-agente.sql | OK - Coincide |
| ai_usage_limits | 02b-seed-agente.sql | OK - Coincide |
| checkpoint_migrations | 02b-seed-agente.sql | OK - Coincide |
| checkpoints | 02b-seed-agente.sql | OK - Coincide |
| checkpoint_blobs | 02b-seed-agente.sql | OK - Coincide |
| checkpoint_writes | 02b-seed-agente.sql | OK - Coincide |

**Resultado: 17/17 tablas cubiertas. Sin discrepancias.**

### 4.2 Schema `100_test` - 33 tablas en BD

| Tabla en BD | # en SQL | Grupo | Coincide |
|-------------|----------|-------|----------|
| departments | 1 | A: Organizacion | OK |
| sectors | 2 | A: Organizacion | OK |
| users | 3 | B: Usuarios | OK |
| user_roles | 4 | B: Usuarios | OK |
| user_seals | 5 | B: Usuarios | OK |
| user_sector_permissions | 6 | B: Usuarios | OK |
| estado_users | 7 | B: Usuarios | OK |
| ranks | 8 | C: Rangos y Sellos | OK |
| city_seals | 9 | C: Rangos y Sellos | OK |
| document_types | 10 | D: Documentos | OK |
| document_types_allowed_by_rank | 11 | D: Documentos | OK |
| enabled_document_types_by_sector | 12 | D: Documentos | OK |
| document_draft | 13 | D: Documentos | OK |
| document_signers | 14 | D: Documentos | OK |
| document_rejections | 15 | D: Documentos | OK |
| official_documents | 16 | D: Documentos | OK |
| case_templates | 17 | E: Expedientes | OK |
| case_template_allowed_departments | 18 | E: Expedientes | OK |
| cases | 19 | E: Expedientes | OK |
| case_movements | 20 | E: Expedientes | OK |
| case_official_documents | 21 | E: Expedientes | OK |
| case_proposed_documents | 22 | E: Expedientes | OK |
| settings | 23 | F: Configuracion | OK |
| document_chunks | 24 | G: Agente IA | OK |
| notes_recipients | 25 | H: Notas | OK |
| notes_openings | 26 | H: Notas | OK |
| registry_families | 27 | I: Registros | OK |
| registry_family_permissions | 28 | I: Registros | OK |
| records | 29 | I: Registros | OK |
| record_history | 30 | I: Registros | OK |
| record_relations | 31 | I: Registros | OK |
| record_case_links | 32 | I: Registros | OK |
| record_document_links | 33 | I: Registros | OK |

**Resultado: 33/33 tablas cubiertas. Sin discrepancias.**

### 4.3 Schema `100_test_audit` - 1 tabla en BD

| Tabla en BD | Cubierta por SQL | Notas |
|-------------|------------------|-------|
| audit_log | 04-seed-demo.sql | OK - 11 columnas incluyendo auth_source y changed_fields |

**Resultado: 1/1 tabla cubierta. Sin discrepancias.**

### 4.4 Comparacion de Columnas (detalle por tabla)

He verificado columna por columna las 51 tablas (17 public + 33 tenant + 1 audit). **Todas coinciden exactamente** en:
- Nombres de columna
- Tipos de datos
- Nullability (NOT NULL / NULL)
- Defaults
- Constraints (PK, FK, UNIQUE, CHECK)

No se encontro ninguna discrepancia columna-nivel.

### 4.5 Enums

| Enum | Valores en SQL | Valores en BD | Estado |
|------|---------------|---------------|--------|
| country_enum | AR,BR,UY,CL,PY,BO,PE,EC,CO,VE,MX | AR,BR,UY,CL,PY,BO,PE,EC,CO,VE,MX | OK |
| document_status | draft,sent_to_sign,signed,rejected,cancelled | draft,sent_to_sign,signed,rejected,cancelled | OK |
| document_signer_status | pending,signed,rejected | pending,signed,rejected | OK |
| movement_type | creation,transfer,assignment,assignment_close,status_change,document_link,subsanacion,document_proposal,document_proposal_reject | Idem | OK |
| status_case | inactive,active,archived | inactive,active,archived | OK |
| case_creation_channel | web,api,both | web,api,both | OK |
| document_type_source | HTML,Importado,NOTA | HTML,Importado,NOTA | OK |

**Resultado: 7/7 enums coinciden.**

### 4.6 Indices

**100_test schema**: 51 indices custom (sin contar PKs y UNIQUEs automaticos) en el SQL, todos presentes en BD. La BD tiene exactamente los indices que crean los SQLs.

**public schema**: Todos los indices declarados en 01-install.sql y 02b-seed-agente.sql existen en BD.

**100_test_audit schema**: 3 indices custom (event_time, table_name, user_id) + PK. Todos presentes.

### 4.7 Triggers

| Trigger en BD | Tabla | Funcion | SQL |
|---------------|-------|---------|-----|
| trg_audit_departments | departments | 100_test_audit.fn_log_change | 04-seed-demo.sql |
| trg_audit_sectors | sectors | 100_test_audit.fn_log_change | 04-seed-demo.sql |
| trg_audit_official_documents | official_documents | 100_test_audit.fn_log_change | 04-seed-demo.sql |
| trg_audit_cases | cases | 100_test_audit.fn_log_change | 04-seed-demo.sql |
| trg_audit_case_movements | case_movements | 100_test_audit.fn_log_change | 04-seed-demo.sql |
| trg_audit_case_official_documents | case_official_documents | 100_test_audit.fn_log_change | 04-seed-demo.sql |
| trg_sync_user_registry | users | 100_test.fn_sync_user_registry | 04-seed-demo.sql |

**Resultado: 7/7 triggers coinciden.**

### 4.8 Extensiones

| Extension | SQL | BD | Estado |
|-----------|-----|-----|--------|
| vector | 01-install.sql | v0.8.1 | OK |
| unaccent | 01-install.sql | v1.1 | OK |
| pg_trgm | 01-install.sql | v1.6 | OK |
| plpgsql | (built-in) | v1.0 | OK (no necesita CREATE) |

---

## 5. Migraciones: Estado y Recomendacion

### Todas las migraciones son OBSOLETAS

Las 13 migraciones en `sql/migrations/` fueron creadas para actualizar BDs existentes de forma incremental. **Todas ya estan integradas en los templates base** (01-install.sql, 03-create-municipio.sql, 04-seed-demo.sql).

Para un deploy desde cero, las migraciones NO son necesarias. Solo sirven para:
- Referencia historica de que cambios se hicieron
- Aplicar cambios a BDs de PRD que no se pueden recrear

**Recomendacion**: Conservar como referencia pero no ejecutar en deploys nuevos.

### Gaps en numeracion (migraciones eliminadas previamente)
- 001-013, 019-021: Eliminadas en limpiezas anteriores (documentado en CLAUDE.md)
- Solo quedan 014-018, 022-027

### Archivadas en sql/migrations/archive/ (2026-06-01)
- `058_checkpoint_indexes.sql`: índices de schema public para LangGraph checkpointer. Ya aplicada en todos los deploys.
- `059_agentelang_polling_index.sql`: índices parciales `document_draft_resume_null` y `official_documents_resume_null`. **Horneada en templates** (03-create-municipio.sql + 03-create-web-schema.sql).
- `060_departments_head_user_index.sql`: índice `departments_head_user_id`. **Horneada en templates** (03-create-municipio.sql + 03-create-web-schema.sql).

---

## 6. Archivos con Problemas

### 6.1 `truncate_100_test.sql` (DESACTUALIZADO)

Referencia **6 tablas que ya no existen** en el schema:
- `tool_executions` -- Eliminada (era Grupo G del agente)
- `pending_actions` -- Eliminada
- `messages` -- Eliminada
- `conversations` -- Eliminada
- `rank_seals` -- Eliminada (simplificada a user_seals.seal_id -> city_seal_id)
- `enabled_document_types_by_department` -- Renombrada a `enabled_document_types_by_sector`

**Y no incluye** tablas nuevas:
- notes_recipients, notes_openings (Grupo H)
- registry_families, registry_family_permissions, records, record_history, record_relations, record_case_links, record_document_links (Grupo I)
- ranks (Grupo C)

**Ejecutar este archivo causaria errores.**

### 6.2 Migracion `014_add_notes_tables.sql` (TEMPLATE SIN REEMPLAZO)

Contiene placeholders `{SCHEMA_NAME}` literales. No es ejecutable directamente sin sed/replace. El archivo `014_apply_to_100_test.sql` es la version ejecutable para 100_test.

### 6.3 Migracion `018_add_notes_archived.sql` (TEMPLATE SIN REEMPLAZO)

Mismo caso que 014. Contiene `{SCHEMA_NAME}` literal.

---

## 7. Consistencia entre 03-create-municipio.sql y 04-seed-demo.sql

El archivo 04 es una version "hardcodeada" de 03 para el schema 100_test. Ambos deben mantenerse sincronizados.

| Aspecto | 03 (template) | 04 (demo) | Coincide |
|---------|---------------|-----------|----------|
| Tablas | 33 | 33 | SI |
| Columnas por tabla | Identicas | Identicas | SI |
| Indices | 47 custom | 47 custom | SI |
| Trigger sync | fn_sync_user_registry | fn_sync_user_registry | SI |
| Audit schema | audit_log + fn_log_change + 6 triggers | Idem | SI |
| Settings columns | 13 columnas | 13 columnas | SI |
| FKs diferidas | departments.rank_fkey + user_seals.seal_fkey | Idem | SI |

**Los dos archivos estan perfectamente sincronizados.**

---

## 8. Conclusion

**La BD se puede recrear completa desde cero ejecutando los 4 archivos principales en orden:**

```
01-install.sql      -> Schema public (10 tablas + enums + extensiones)
02-seed-global.sql  -> Datos globales (roles, doc types, case templates, etc.)
02b-seed-agente.sql -> Tablas AgenteLANG (7 tablas public)
04-seed-demo.sql    -> Schema 100_test completo (33 tablas + audit + datos demo)
```

**Acciones recomendadas:**
1. Eliminar o archivar `truncate_100_test.sql` (desactualizado, causaria errores)
2. Las migraciones pueden conservarse como referencia historica pero marcarlas como obsoletas
3. No se encontraron discrepancias entre los SQLs y la BD real
