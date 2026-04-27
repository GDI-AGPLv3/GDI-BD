-- ############################################################################
-- ##                                                                        ##
-- ##   !!  ATENCION: ARCHIVO HERMANO QUE DEBE SINCRONIZARSE A MANO  !!      ##
-- ##                                                                        ##
-- ##   ARCHIVO HERMANO:                                                     ##
-- ##     GDI-BackOffice-Back/sql/03-create-web-schema.sql                   ##
-- ##                                                                        ##
-- ##   DIFERENCIAS:                                                         ##
-- ##     - ESTE archivo: ejecutado por GDI-BD/tools/create_municipio.py     ##
-- ##       Tiene 9 placeholders y hace TODOS los INSERTs inline.            ##
-- ##     - HERMANO: ejecutado por endpoint POST /onboarding/create-...      ##
-- ##       Solo {SCHEMA_NAME}. INSERTs comentados (los hace Python en       ##
-- ##       GDI-BackOffice-Back/services/web_create_schema.py).              ##
-- ##                                                                        ##
-- ##   SI MODIFICAS ESTE ARCHIVO (tablas, columnas, indices, triggers):     ##
-- ##     1. Aplicar el MISMO cambio en 03-create-web-schema.sql             ##
-- ##     2. Si afecta seeds: tambien editar web_create_schema.py            ##
-- ##                                                                        ##
-- ##   NO HAY SYNC AUTOMATICO. Drift = municipios nuevos con estructura     ##
-- ##   diferente segun el camino usado. Ver docs/drift-audit si pasa.       ##
-- ##                                                                        ##
-- ############################################################################

-- ============================================================================
-- GDI LATAM - CREAR MUNICIPIO (Multi-Tenant)
-- ============================================================================
-- Descripcion: Crea un municipio completo: schema + audit + datos iniciales
-- Version: 5.0.0
-- PostgreSQL: 17.0+ con pgvector
--
-- CONTENIDO: Schema municipio (33 tablas) + schema audit + datos iniciales + registro tenant
--
-- PLACEHOLDERS REQUERIDOS (reemplazar antes de ejecutar):
--   {SCHEMA_NAME}       - Nombre del schema (ej: 100_test, 101_bsas)
--   {MUNICIPALITY_NAME} - Nombre del municipio (ej: Test Municipality)
--   {ACRONYM}           - Acronimo 4 chars (ej: TXST)
--   {COUNTRY}           - Codigo pais (ej: AR, BR, UY)
--   {SCHEMA_NUMBER}     - Numero auto-incremental (ej: 100, 101)
--   {BUCKET_OFICIAL}    - Bucket Cloudflare para documentos (ej: gdi-wxyz-oficial)
--   {BUCKET_TOSIGN}     - Bucket Cloudflare para firmar (ej: gdi-wxyz-tosign)
--   {CITY}              - Nombre de la ciudad (ej: LATAM, Buenos Aires)
--   {PRIMARY_COLOR}     - Color primario sin # (ej: 16158C, 006400)
--
-- EJECUCION:
--   psql -U postgres -h host -d gdi < 03-create-municipio.sql
--   (Despues de reemplazar todos los placeholders)
-- ============================================================================

-- ============================================================================
-- SECCION 1: SCHEMA MUNICIPIO
-- ============================================================================

DROP SCHEMA IF EXISTS "{SCHEMA_NAME}" CASCADE;

CREATE SCHEMA "{SCHEMA_NAME}";

-- NOTA: Los ENUMs estan en schema public (compartidos por todos los municipios):
--   - public.document_status
--   - public.document_signer_status
--   - public.movement_type
--   - public.status_case
--   - public.case_creation_channel
--   - public.relation_type

-- ============================================================================
-- GRUPO A: ESTRUCTURA ORGANIZACIONAL
-- ============================================================================

-- TABLA 1: departments
CREATE TABLE "{SCHEMA_NAME}"."departments" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "name" VARCHAR(100) NOT NULL,
  "acronym" VARCHAR(20),
  "parent_id" UUID,
  "rank_id" UUID,  -- FK a {SCHEMA_NAME}.ranks (per-tenant)
  "head_user_id" UUID,
  "primary_color" VARCHAR(7),
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "start_date" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "end_date" TIMESTAMPTZ,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "departments_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "departments_parent_fkey" FOREIGN KEY ("parent_id") REFERENCES "{SCHEMA_NAME}"."departments" ("id")
);

-- TABLA 2: sectors
CREATE TABLE "{SCHEMA_NAME}"."sectors" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "department_id" UUID NOT NULL,
  "acronym" VARCHAR(10) NOT NULL,
  "primary_color" VARCHAR(7),
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "start_date" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "end_date" TIMESTAMPTZ,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "sectors_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "sectors_department_fkey" FOREIGN KEY ("department_id") REFERENCES "{SCHEMA_NAME}"."departments" ("id"),
  CONSTRAINT "sectors_acronym_unique" UNIQUE ("department_id", "acronym")
);

-- ============================================================================
-- GRUPO B: USUARIOS
-- ============================================================================

-- TABLA 3: users
CREATE TABLE "{SCHEMA_NAME}"."users" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "auth_id" TEXT,  -- ID de Auth0
  "auth_method" VARCHAR(20) NOT NULL DEFAULT 'social',  -- 'social' o 'database'
  "email" TEXT NOT NULL,
  "full_name" VARCHAR(150) NOT NULL,
  "profile_picture_url" TEXT,  -- URL de foto de perfil (Auth0)
  "CountryID" VARCHAR(20),
  "sector_id" UUID,
  "estado" INT NOT NULL DEFAULT 1,
  "last_access" TIMESTAMPTZ,
  "can_global_search_documents" BOOLEAN NOT NULL DEFAULT true,
  "can_global_search_cases" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "users_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "users_email_unique" UNIQUE ("email"),
  CONSTRAINT "users_sector_fkey" FOREIGN KEY ("sector_id") REFERENCES "{SCHEMA_NAME}"."sectors" ("id")
);

-- TABLA 4: user_roles
CREATE TABLE "{SCHEMA_NAME}"."user_roles" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "user_id" UUID NOT NULL,
  "role_id" UUID NOT NULL,  -- FK a public.roles
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "user_roles_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "user_roles_user_fkey" FOREIGN KEY ("user_id") REFERENCES "{SCHEMA_NAME}"."users" ("id"),
  CONSTRAINT "user_roles_role_fkey" FOREIGN KEY ("role_id") REFERENCES "public"."roles" ("role_id"),
  CONSTRAINT "user_roles_unique" UNIQUE ("user_id", "role_id")
);

-- TABLA 5: user_seals (1 sello por usuario)
CREATE TABLE "{SCHEMA_NAME}"."user_seals" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "user_id" UUID NOT NULL,
  "city_seal_id" INT NOT NULL,  -- FK a city_seals local
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "user_seals_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "user_seals_user_fkey" FOREIGN KEY ("user_id") REFERENCES "{SCHEMA_NAME}"."users" ("id"),
  CONSTRAINT "user_seals_user_unique" UNIQUE ("user_id")
);

-- TABLA 6: user_sector_permissions
CREATE TABLE "{SCHEMA_NAME}"."user_sector_permissions" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "user_id" UUID NOT NULL,
  "sector_id" UUID NOT NULL,
  "can_view" BOOLEAN NOT NULL DEFAULT true,
  "can_edit" BOOLEAN NOT NULL DEFAULT false,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "user_sector_permissions_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "user_sector_permissions_user_fkey" FOREIGN KEY ("user_id") REFERENCES "{SCHEMA_NAME}"."users" ("id"),
  CONSTRAINT "user_sector_permissions_sector_fkey" FOREIGN KEY ("sector_id") REFERENCES "{SCHEMA_NAME}"."sectors" ("id"),
  CONSTRAINT "user_sector_permissions_unique" UNIQUE ("user_id", "sector_id")
);

-- TABLA 7: estado_users
CREATE TABLE "{SCHEMA_NAME}"."estado_users" (
  "id" SERIAL NOT NULL,
  "estado" VARCHAR(50) NOT NULL,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "estado_users_pkey" PRIMARY KEY ("id")
);

-- ============================================================================
-- GRUPO C: RANGOS Y SELLOS (per-tenant)
-- ============================================================================
-- Cada municipio define sus propios rangos jerarquicos y sellos.
-- Los sellos pueden estar vinculados a un rango (ej: "Secretario") o ser genericos (ej: "Innovador").
-- El campo `level` en ranks determina la jerarquia (1 = mas alto).

-- TABLA 8: ranks (jerarquias del municipio)
CREATE TABLE "{SCHEMA_NAME}"."ranks" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "name" VARCHAR(50) NOT NULL,
  "level" INT NOT NULL,  -- 1 = Intendente (mas alto), 2 = Secretario, 3 = Director...
  "head_signature" VARCHAR(100),  -- Texto que aparece en firma de documentos
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "ranks_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "ranks_name_unique" UNIQUE ("name"),
  CONSTRAINT "ranks_level_unique" UNIQUE ("level")
);

COMMENT ON TABLE "{SCHEMA_NAME}"."ranks" IS 'Jerarquias del municipio (per-tenant)';
COMMENT ON COLUMN "{SCHEMA_NAME}"."ranks"."level" IS '1 = mas alto (Intendente), numeros mayores = menor jerarquia';

-- TABLA 9: city_seals (sellos del municipio)
CREATE TABLE "{SCHEMA_NAME}"."city_seals" (
  "id" SERIAL NOT NULL,
  "name" TEXT NOT NULL,
  "description" TEXT,
  "rank_id" UUID,  -- NULL = sello generico (cualquier usuario), NOT NULL = sello con rango
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "city_seals_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "city_seals_name_unique" UNIQUE ("name"),
  CONSTRAINT "city_seals_rank_fkey" FOREIGN KEY ("rank_id") REFERENCES "{SCHEMA_NAME}"."ranks" ("id")
);

COMMENT ON TABLE "{SCHEMA_NAME}"."city_seals" IS 'Sellos del municipio. rank_id NULL = generico';
COMMENT ON COLUMN "{SCHEMA_NAME}"."city_seals"."rank_id" IS 'Si NOT NULL, el usuario con este sello tiene ese rango jerarquico';

-- FKs diferidas: tablas que se crean antes de sus dependencias
ALTER TABLE "{SCHEMA_NAME}"."departments"
  ADD CONSTRAINT "departments_rank_fkey" FOREIGN KEY ("rank_id") REFERENCES "{SCHEMA_NAME}"."ranks" ("id");
ALTER TABLE "{SCHEMA_NAME}"."user_seals"
  ADD CONSTRAINT "user_seals_seal_fkey" FOREIGN KEY ("city_seal_id") REFERENCES "{SCHEMA_NAME}"."city_seals" ("id");

-- ============================================================================
-- GRUPO D: DOCUMENTOS
-- ============================================================================

-- TABLA 10: document_types
CREATE TABLE "{SCHEMA_NAME}"."document_types" (
  "id" SERIAL NOT NULL,
  "global_document_type_id" UUID NOT NULL,  -- FK a public.global_document_types
  "name" VARCHAR(100) NOT NULL,
  "acronym" VARCHAR(6) NOT NULL,
  "description" TEXT,
  "required_signature" VARCHAR(50),
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "type" "public"."document_type_source" NOT NULL DEFAULT 'HTML',
  "trust" BOOLEAN NOT NULL DEFAULT true,
  "special_numbering" BOOLEAN NOT NULL DEFAULT false,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "document_types_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "document_types_acronym_unique" UNIQUE ("acronym"),
  CONSTRAINT "document_types_global_fkey" FOREIGN KEY ("global_document_type_id") REFERENCES "public"."global_document_types" ("id")
);

-- TABLA 11: document_types_allowed_by_rank
-- Define que rango minimo se necesita para numerar un tipo de documento.
-- Si un doc_type tiene rank "Director" (level=3), cualquier usuario con level <= 3 puede numerar.
CREATE TABLE "{SCHEMA_NAME}"."document_types_allowed_by_rank" (
  "id" SERIAL NOT NULL,
  "document_type_id" INT NOT NULL,
  "rank_id" UUID NOT NULL,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "document_types_allowed_by_rank_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "dtabr_document_type_fkey" FOREIGN KEY ("document_type_id") REFERENCES "{SCHEMA_NAME}"."document_types" ("id"),
  CONSTRAINT "dtabr_rank_fkey" FOREIGN KEY ("rank_id") REFERENCES "{SCHEMA_NAME}"."ranks" ("id"),
  CONSTRAINT "dtabr_unique" UNIQUE ("document_type_id", "rank_id")
);

-- TABLA 12: enabled_document_types_by_sector
CREATE TABLE "{SCHEMA_NAME}"."enabled_document_types_by_sector" (
  "id" SERIAL NOT NULL,
  "document_type_id" INT NOT NULL,
  "sector_id" UUID NOT NULL,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "enabled_edts_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "enabled_edts_document_type_fkey" FOREIGN KEY ("document_type_id") REFERENCES "{SCHEMA_NAME}"."document_types" ("id"),
  CONSTRAINT "enabled_edts_sector_fkey" FOREIGN KEY ("sector_id") REFERENCES "{SCHEMA_NAME}"."sectors" ("id"),
  CONSTRAINT "enabled_edts_unique" UNIQUE ("document_type_id", "sector_id")
);

-- TABLA 13: document_draft
CREATE TABLE "{SCHEMA_NAME}"."document_draft" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "created_by" UUID NOT NULL,
  "document_type_id" INT,
  "reference" VARCHAR(100) NOT NULL,
  "content" JSONB,
  "status" "public"."document_status" NOT NULL DEFAULT 'draft',
  "sent_to_sign_at" TIMESTAMPTZ,
  "sent_by" UUID,
  "document_number" TEXT,
  "numbered_at" TIMESTAMPTZ,
  "numbered_by" UUID,
  "is_deleted" BOOLEAN NOT NULL DEFAULT false,
  "resume" TEXT,
  "short_resume" TEXT,
  "last_modified_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "document_draft_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "document_draft_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "{SCHEMA_NAME}"."users" ("id"),
  CONSTRAINT "document_draft_document_type_fkey" FOREIGN KEY ("document_type_id") REFERENCES "{SCHEMA_NAME}"."document_types" ("id")
);

-- TABLA 14: document_signers
CREATE TABLE "{SCHEMA_NAME}"."document_signers" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "document_id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "is_numerator" BOOLEAN NOT NULL DEFAULT false,
  "signing_order" INT,
  "status" "public"."document_signer_status" NOT NULL DEFAULT 'pending',
  "signed_at" TIMESTAMPTZ,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "document_signers_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "document_signers_document_fkey" FOREIGN KEY ("document_id") REFERENCES "{SCHEMA_NAME}"."document_draft" ("id"),
  CONSTRAINT "document_signers_user_fkey" FOREIGN KEY ("user_id") REFERENCES "{SCHEMA_NAME}"."users" ("id")
);

-- TABLA 15: document_rejections
CREATE TABLE "{SCHEMA_NAME}"."document_rejections" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "document_id" UUID NOT NULL,
  "rejected_by" UUID NOT NULL,
  "reason" TEXT,
  "rejected_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "document_rejections_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "document_rejections_document_fkey" FOREIGN KEY ("document_id") REFERENCES "{SCHEMA_NAME}"."document_draft" ("id"),
  CONSTRAINT "document_rejections_user_fkey" FOREIGN KEY ("rejected_by") REFERENCES "{SCHEMA_NAME}"."users" ("id")
);

-- TABLA 16: official_documents
CREATE TABLE "{SCHEMA_NAME}"."official_documents" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "document_type_id" INT NOT NULL,
  "reference" VARCHAR(100) NOT NULL,
  "content" JSONB NOT NULL,
  "official_number" VARCHAR(50) NOT NULL,
  "year" SMALLINT NOT NULL,
  "department_id" UUID NOT NULL,
  "numerator_id" UUID NOT NULL,
  "signed_at" TIMESTAMPTZ,  -- nullable: NULL = numero reservado, NOT NULL = firmado y oficial
  "signers" JSONB,
  "global_sequence" INT,
  "signer_sector_ids" UUID[],  -- Array de sector_ids de todos los firmantes
  "resume" TEXT,
  "short_resume" TEXT,
  "special_number" INT NULL,
  "numbering_regime" VARCHAR(10) NULL,
  "reservation_status" VARCHAR(20) NULL,
  "reserved_at" TIMESTAMPTZ NULL,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "official_documents_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "official_documents_document_type_fkey" FOREIGN KEY ("document_type_id") REFERENCES "{SCHEMA_NAME}"."document_types" ("id"),
  CONSTRAINT "official_documents_department_fkey" FOREIGN KEY ("department_id") REFERENCES "{SCHEMA_NAME}"."departments" ("id"),
  CONSTRAINT "official_documents_numerator_fkey" FOREIGN KEY ("numerator_id") REFERENCES "{SCHEMA_NAME}"."users" ("id"),
  CONSTRAINT "official_documents_numbering_regime_check" CHECK (numbering_regime IN ('GLOBAL', 'SPECIAL')),
  CONSTRAINT "official_documents_reservation_status_check" CHECK (reservation_status IN ('RESERVED', 'CONFIRMED', 'CANCELLED'))
);

-- TABLA 16b: document_number_counters (contador por tipo+año+departamento)
-- Lleva el ultimo numero emitido para tipos con numeracion especial (special_numbering = true).
-- La PK compuesta garantiza un unico contador por combinacion tipo+año+departamento.
CREATE TABLE "{SCHEMA_NAME}"."document_number_counters" (
  "document_type_id" INT NOT NULL,
  "year" SMALLINT NOT NULL,
  "department_id" UUID NOT NULL,
  "last_number" INT NOT NULL DEFAULT 0,
  "active_reservation_document_id" UUID NULL,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "document_number_counters_pkey" PRIMARY KEY ("document_type_id", "year", "department_id"),
  CONSTRAINT "document_number_counters_doc_type_fkey" FOREIGN KEY ("document_type_id") REFERENCES "{SCHEMA_NAME}"."document_types" ("id"),
  CONSTRAINT "document_number_counters_department_fkey" FOREIGN KEY ("department_id") REFERENCES "{SCHEMA_NAME}"."departments" ("id")
);

-- ============================================================================
-- GRUPO E: EXPEDIENTES
-- ============================================================================

-- TABLA 17: case_templates
CREATE TABLE "{SCHEMA_NAME}"."case_templates" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "global_case_template_id" UUID NOT NULL,  -- FK a public.global_case_templates
  "type_name" VARCHAR(100) NOT NULL,
  "acronym" VARCHAR(6) NOT NULL,
  "description" TEXT,
  "creation_channel" "public"."case_creation_channel" NOT NULL DEFAULT 'web',
  "filing_department_id" UUID NOT NULL,
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "case_templates_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "case_templates_acronym_unique" UNIQUE ("acronym"),
  CONSTRAINT "case_templates_global_fkey" FOREIGN KEY ("global_case_template_id") REFERENCES "public"."global_case_templates" ("id"),
  CONSTRAINT "case_templates_department_fkey" FOREIGN KEY ("filing_department_id") REFERENCES "{SCHEMA_NAME}"."departments" ("id")
);

-- TABLA 18: case_template_allowed_departments
CREATE TABLE "{SCHEMA_NAME}"."case_template_allowed_departments" (
  "case_template_id" UUID NOT NULL,
  "department_id" UUID NOT NULL,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "ctad_pkey" PRIMARY KEY ("case_template_id", "department_id"),
  CONSTRAINT "ctad_case_template_fkey" FOREIGN KEY ("case_template_id") REFERENCES "{SCHEMA_NAME}"."case_templates" ("id"),
  CONSTRAINT "ctad_department_fkey" FOREIGN KEY ("department_id") REFERENCES "{SCHEMA_NAME}"."departments" ("id")
);

-- TABLA 19: cases
CREATE TABLE "{SCHEMA_NAME}"."cases" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "case_number" VARCHAR(50) NOT NULL,
  "reference" VARCHAR(250) NOT NULL,
  "status" "public"."status_case" NOT NULL DEFAULT 'inactive',
  "case_template_id" UUID NOT NULL,
  "created_by_user_id" UUID NOT NULL,
  "owner_department_id" UUID NOT NULL,
  "owner_sector_id" UUID,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "ai_summary" TEXT,
  "short_ai_summary" TEXT,
  "ai_summary_updated_at" TIMESTAMPTZ,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "cases_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "cases_number_unique" UNIQUE ("case_number"),
  CONSTRAINT "cases_template_fkey" FOREIGN KEY ("case_template_id") REFERENCES "{SCHEMA_NAME}"."case_templates" ("id"),
  CONSTRAINT "cases_created_by_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "{SCHEMA_NAME}"."users" ("id"),
  CONSTRAINT "cases_department_fkey" FOREIGN KEY ("owner_department_id") REFERENCES "{SCHEMA_NAME}"."departments" ("id"),
  CONSTRAINT "cases_sector_fkey" FOREIGN KEY ("owner_sector_id") REFERENCES "{SCHEMA_NAME}"."sectors" ("id")
);

-- TABLA 20: case_movements
CREATE TABLE "{SCHEMA_NAME}"."case_movements" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "case_id" UUID NOT NULL,
  "type" "public"."movement_type" NOT NULL,
  "user_id" UUID,
  "creator_sector_id" UUID NOT NULL,
  "admin_sector_id" UUID NOT NULL,
  "assigned_sector_id" UUID,
  "assigned_user_id" UUID,
  "reason" VARCHAR(200) NOT NULL,
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "closed_at" TIMESTAMPTZ,
  "closing_reason" VARCHAR(200),
  "closed_by" UUID,
  "supporting_document_id" UUID,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "case_movements_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "case_movements_case_fkey" FOREIGN KEY ("case_id") REFERENCES "{SCHEMA_NAME}"."cases" ("id"),
  CONSTRAINT "case_movements_user_fkey" FOREIGN KEY ("user_id") REFERENCES "{SCHEMA_NAME}"."users" ("id"),
  CONSTRAINT "case_movements_creator_sector_fkey" FOREIGN KEY ("creator_sector_id") REFERENCES "{SCHEMA_NAME}"."sectors" ("id"),
  CONSTRAINT "case_movements_admin_sector_fkey" FOREIGN KEY ("admin_sector_id") REFERENCES "{SCHEMA_NAME}"."sectors" ("id")
);

-- TABLA 21: case_official_documents
CREATE TABLE "{SCHEMA_NAME}"."case_official_documents" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "case_id" UUID NOT NULL,
  "official_document_id" UUID NOT NULL,
  "linking_user_id" UUID NOT NULL,
  "order_number" INT NOT NULL,
  "linking_date" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "deactivated_at" TIMESTAMPTZ,
  "deactivated_by_user_id" UUID,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "case_official_documents_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "cod_case_fkey" FOREIGN KEY ("case_id") REFERENCES "{SCHEMA_NAME}"."cases" ("id"),
  CONSTRAINT "cod_official_document_fkey" FOREIGN KEY ("official_document_id") REFERENCES "{SCHEMA_NAME}"."official_documents" ("id"),
  CONSTRAINT "cod_linking_user_fkey" FOREIGN KEY ("linking_user_id") REFERENCES "{SCHEMA_NAME}"."users" ("id")
);

-- TABLA 22: case_proposed_documents
CREATE TABLE "{SCHEMA_NAME}"."case_proposed_documents" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "case_id" UUID NOT NULL,
  "document_draft_id" UUID NOT NULL,
  "proposing_user_id" UUID NOT NULL,
  "proposing_date" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "case_proposed_documents_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "cpd_case_fkey" FOREIGN KEY ("case_id") REFERENCES "{SCHEMA_NAME}"."cases" ("id"),
  CONSTRAINT "cpd_document_draft_fkey" FOREIGN KEY ("document_draft_id") REFERENCES "{SCHEMA_NAME}"."document_draft" ("id"),
  CONSTRAINT "cpd_proposing_user_fkey" FOREIGN KEY ("proposing_user_id") REFERENCES "{SCHEMA_NAME}"."users" ("id")
);

-- ============================================================================
-- GRUPO F: CONFIGURACION
-- ============================================================================

-- TABLA 23: settings
CREATE TABLE "{SCHEMA_NAME}"."settings" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "timezone" TEXT NOT NULL DEFAULT 'America/Argentina/Buenos_Aires',
  "bucket_oficial" TEXT NOT NULL,
  "bucket_tosign" TEXT NOT NULL,
  "city" VARCHAR(100) DEFAULT 'LATAM',
  "address" VARCHAR(150),
  "contact_email" VARCHAR(100),
  "website_url" VARCHAR(150),
  "annual_slogan" VARCHAR(255),
  "logo_url" TEXT,
  "isologo_url" TEXT,
  "cover_url" TEXT,
  "primary_color" VARCHAR(6) DEFAULT '16158C',
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "settings_pkey" PRIMARY KEY ("id")
);

-- ============================================================================
-- GRUPO G: AGENTE IA (GDI-Agente)
-- ============================================================================
-- Tabla de chunks con embeddings para búsqueda semántica (RAG)
-- NOTA: conversations, messages, pending_actions y tool_executions fueron
--       eliminadas. LangGraph usa su propio checkpointer en schema public.

-- TABLA 24: document_chunks (vectores para RAG)
CREATE TABLE "{SCHEMA_NAME}"."document_chunks" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "official_document_id" UUID NOT NULL,
  "chunk_index" INTEGER NOT NULL,
  "chunk_text" TEXT NOT NULL,
  "embedding" vector(1536),
  "embedding_model" VARCHAR(100) NOT NULL DEFAULT 'text-embedding-3-small',
  "indexed_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "document_chunks_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "document_chunks_official_fkey" FOREIGN KEY ("official_document_id") REFERENCES "{SCHEMA_NAME}"."official_documents" ("id"),
  CONSTRAINT "document_chunks_unique" UNIQUE ("official_document_id", "chunk_index")
);

COMMENT ON TABLE "{SCHEMA_NAME}"."document_chunks" IS 'Chunks de documentos oficiales con embeddings para búsqueda semántica';

-- ============================================================================
-- GRUPO H: NOTAS (Documentos con destinatarios)
-- ============================================================================
-- Sistema de NOTAS: documentos oficiales con destinatarios (TO/CC/BCC) y tracking de apertura

-- TABLA 25: notes_recipients (destinatarios de notas)
CREATE TABLE "{SCHEMA_NAME}"."notes_recipients" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "document_id" UUID NOT NULL,
  "sector_id" UUID NOT NULL,
  "recipient_type" VARCHAR(3) NOT NULL,
  "sender_sector_id" UUID NOT NULL,
  "is_archived" BOOLEAN NOT NULL DEFAULT false,
  "archived_at" TIMESTAMPTZ NULL,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "notes_recipients_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "notes_recipients_document_fkey" FOREIGN KEY ("document_id") REFERENCES "{SCHEMA_NAME}"."document_draft" ("id"),
  CONSTRAINT "notes_recipients_sector_fkey" FOREIGN KEY ("sector_id") REFERENCES "{SCHEMA_NAME}"."sectors" ("id"),
  CONSTRAINT "notes_recipients_sender_fkey" FOREIGN KEY ("sender_sector_id") REFERENCES "{SCHEMA_NAME}"."sectors" ("id"),
  CONSTRAINT "notes_recipients_type_check" CHECK ("recipient_type" IN ('TO', 'CC', 'BCC')),
  CONSTRAINT "notes_recipients_unique" UNIQUE ("document_id", "sector_id")
);

COMMENT ON TABLE "{SCHEMA_NAME}"."notes_recipients" IS 'Destinatarios de notas oficiales (TO, CC, BCC) con soporte para archivado';

-- TABLA 26: notes_openings (tracking de apertura de notas)
CREATE TABLE "{SCHEMA_NAME}"."notes_openings" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "document_id" UUID NOT NULL,
  "sector_id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "opened_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "notes_openings_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "notes_openings_document_fkey" FOREIGN KEY ("document_id") REFERENCES "{SCHEMA_NAME}"."document_draft" ("id"),
  CONSTRAINT "notes_openings_sector_fkey" FOREIGN KEY ("sector_id") REFERENCES "{SCHEMA_NAME}"."sectors" ("id"),
  CONSTRAINT "notes_openings_user_fkey" FOREIGN KEY ("user_id") REFERENCES "{SCHEMA_NAME}"."users" ("id"),
  CONSTRAINT "notes_openings_unique" UNIQUE ("document_id", "user_id")
);

COMMENT ON TABLE "{SCHEMA_NAME}"."notes_openings" IS 'Registro de apertura de notas (tracking simple sí/no)';

-- TABLA 27: memo_recipients (destinatarios de memos persona-a-persona)
CREATE TABLE "{SCHEMA_NAME}"."memo_recipients" (
  "id"                  UUID NOT NULL DEFAULT gen_random_uuid(),
  "document_id"         UUID NOT NULL,
  "recipient_user_id"   UUID NOT NULL,
  "sender_user_id"      UUID NOT NULL,
  "recipient_type"      VARCHAR(3) NOT NULL,
  "recipient_sector_id" UUID NULL,
  "sender_sector_id"    UUID NULL,
  "is_archived"         BOOLEAN NOT NULL DEFAULT false,
  "archived_at"         TIMESTAMPTZ NULL,
  "opened_at"           TIMESTAMPTZ NULL,
  "created_at"          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at"          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "memo_recipients_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "memo_recipients_document_fkey"
    FOREIGN KEY ("document_id") REFERENCES "{SCHEMA_NAME}"."document_draft" ("id"),
  CONSTRAINT "memo_recipients_recipient_fkey"
    FOREIGN KEY ("recipient_user_id") REFERENCES "{SCHEMA_NAME}"."users" ("id"),
  CONSTRAINT "memo_recipients_sender_fkey"
    FOREIGN KEY ("sender_user_id") REFERENCES "{SCHEMA_NAME}"."users" ("id"),
  CONSTRAINT "memo_recipients_rec_sector_fkey"
    FOREIGN KEY ("recipient_sector_id") REFERENCES "{SCHEMA_NAME}"."sectors" ("id"),
  CONSTRAINT "memo_recipients_sender_sector_fkey"
    FOREIGN KEY ("sender_sector_id") REFERENCES "{SCHEMA_NAME}"."sectors" ("id"),
  CONSTRAINT "memo_recipients_type_check"
    CHECK ("recipient_type" IN ('TO', 'CC', 'BCC')),
  CONSTRAINT "memo_recipients_unique"
    UNIQUE ("document_id", "recipient_user_id")
);

COMMENT ON TABLE "{SCHEMA_NAME}"."memo_recipients" IS 'Destinatarios de memos persona-a-persona (TO, CC, BCC) con tracking de apertura inline';

-- ============================================================================
-- GRUPO I: REGISTROS
-- ============================================================================
-- Sistema de registros configurables por familia (ARQ, LUM, NORMA, etc.)
-- Cada familia define su propio schema de datos (JSONB) y estados posibles.

-- TABLA 27: registry_families (familias de registros del municipio)
CREATE TABLE "{SCHEMA_NAME}"."registry_families" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "global_registry_family_id" UUID,
  "code" VARCHAR(10) NOT NULL,
  "name" VARCHAR(200) NOT NULL,
  "description" TEXT,
  "data_schema" JSONB DEFAULT '{}',
  "states" JSONB DEFAULT '["Activo","Inactivo","Suspendido","Archivado"]',
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "registry_families_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "registry_families_code_unique" UNIQUE ("code"),
  CONSTRAINT "registry_families_global_fkey" FOREIGN KEY ("global_registry_family_id") REFERENCES "public"."global_registry_families" ("id")
);

COMMENT ON TABLE "{SCHEMA_NAME}"."registry_families" IS 'Familias de registros del municipio (copiadas y personalizadas desde global)';

-- TABLA 28: registry_family_permissions (permisos por sector)
CREATE TABLE "{SCHEMA_NAME}"."registry_family_permissions" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "registry_family_id" UUID NOT NULL,
  "sector_id" UUID NOT NULL,
  "can_create" BOOLEAN NOT NULL DEFAULT false,
  "can_edit" BOOLEAN NOT NULL DEFAULT false,
  "can_view" BOOLEAN NOT NULL DEFAULT true,
  "can_verify" BOOLEAN NOT NULL DEFAULT false,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "registry_family_permissions_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "rfp_family_fkey" FOREIGN KEY ("registry_family_id") REFERENCES "{SCHEMA_NAME}"."registry_families" ("id"),
  CONSTRAINT "rfp_sector_fkey" FOREIGN KEY ("sector_id") REFERENCES "{SCHEMA_NAME}"."sectors" ("id"),
  CONSTRAINT "rfp_unique" UNIQUE ("registry_family_id", "sector_id")
);

COMMENT ON TABLE "{SCHEMA_NAME}"."registry_family_permissions" IS 'Permisos de sectores sobre familias de registros';

-- TABLA 29: records (registros individuales)
CREATE TABLE "{SCHEMA_NAME}"."records" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "record_number" VARCHAR(50) NOT NULL,
  "display_name" VARCHAR(200) NOT NULL,
  "registry_family_id" UUID NOT NULL,
  "data" JSONB DEFAULT '{}',
  "state" VARCHAR(50) DEFAULT 'Activo',
  "next_expiration" DATE,
  "created_by_user_id" UUID NOT NULL,
  "created_by_sector_id" UUID NOT NULL,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "resume" TEXT,
  "resume_updated_at" TIMESTAMPTZ,
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "records_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "records_number_unique" UNIQUE ("record_number"),
  CONSTRAINT "records_family_fkey" FOREIGN KEY ("registry_family_id") REFERENCES "{SCHEMA_NAME}"."registry_families" ("id"),
  CONSTRAINT "records_user_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "{SCHEMA_NAME}"."users" ("id"),
  CONSTRAINT "records_sector_fkey" FOREIGN KEY ("created_by_sector_id") REFERENCES "{SCHEMA_NAME}"."sectors" ("id")
);

COMMENT ON TABLE "{SCHEMA_NAME}"."records" IS 'Registros individuales con datos JSONB segun schema de la familia';

-- TABLA 30: record_history (historial de cambios)
CREATE TABLE "{SCHEMA_NAME}"."record_history" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "record_id" UUID NOT NULL,
  "action" VARCHAR(50) NOT NULL,
  "field_name" VARCHAR(100),
  "before_value" JSONB,
  "after_value" JSONB,
  "user_id" UUID NOT NULL,
  "sector_id" UUID NOT NULL,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "record_history_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "record_history_record_fkey" FOREIGN KEY ("record_id") REFERENCES "{SCHEMA_NAME}"."records" ("id"),
  CONSTRAINT "record_history_user_fkey" FOREIGN KEY ("user_id") REFERENCES "{SCHEMA_NAME}"."users" ("id"),
  CONSTRAINT "record_history_sector_fkey" FOREIGN KEY ("sector_id") REFERENCES "{SCHEMA_NAME}"."sectors" ("id")
);

COMMENT ON TABLE "{SCHEMA_NAME}"."record_history" IS 'Historial de cambios en registros';

-- TABLA 31: record_relations (relaciones entre registros)
CREATE TABLE "{SCHEMA_NAME}"."record_relations" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "source_record_id" UUID NOT NULL,
  "target_record_id" UUID NOT NULL,
  "relation_type" "public"."relation_type" NOT NULL DEFAULT 'related',
  "notes" TEXT,
  "created_by_user_id" UUID NOT NULL,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "record_relations_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "record_relations_source_fkey" FOREIGN KEY ("source_record_id") REFERENCES "{SCHEMA_NAME}"."records" ("id"),
  CONSTRAINT "record_relations_target_fkey" FOREIGN KEY ("target_record_id") REFERENCES "{SCHEMA_NAME}"."records" ("id"),
  CONSTRAINT "record_relations_user_fkey" FOREIGN KEY ("created_by_user_id") REFERENCES "{SCHEMA_NAME}"."users" ("id"),
  CONSTRAINT "record_relations_unique" UNIQUE ("source_record_id", "target_record_id")
);

COMMENT ON TABLE "{SCHEMA_NAME}"."record_relations" IS 'Relaciones entre registros (ej: obra relacionada con luminaria)';

-- TABLA 32: record_case_links (vinculos registro-expediente)
CREATE TABLE "{SCHEMA_NAME}"."record_case_links" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "record_id" UUID NOT NULL,
  "case_id" UUID NOT NULL,
  "notes" TEXT,
  "linked_by_user_id" UUID NOT NULL,
  "linked_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "record_case_links_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "record_case_links_record_fkey" FOREIGN KEY ("record_id") REFERENCES "{SCHEMA_NAME}"."records" ("id"),
  CONSTRAINT "record_case_links_case_fkey" FOREIGN KEY ("case_id") REFERENCES "{SCHEMA_NAME}"."cases" ("id"),
  CONSTRAINT "record_case_links_user_fkey" FOREIGN KEY ("linked_by_user_id") REFERENCES "{SCHEMA_NAME}"."users" ("id"),
  CONSTRAINT "record_case_links_unique" UNIQUE ("record_id", "case_id")
);

COMMENT ON TABLE "{SCHEMA_NAME}"."record_case_links" IS 'Vinculos entre registros y expedientes';

-- TABLA 33: record_document_links (vinculos registro-documento)
CREATE TABLE "{SCHEMA_NAME}"."record_document_links" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "record_id" UUID NOT NULL,
  "document_id" UUID NOT NULL,
  "field_name" VARCHAR(100),
  "notes" TEXT,
  "linked_by_user_id" UUID NOT NULL,
  "linked_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "record_document_links_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "record_document_links_record_fkey" FOREIGN KEY ("record_id") REFERENCES "{SCHEMA_NAME}"."records" ("id"),
  CONSTRAINT "record_document_links_user_fkey" FOREIGN KEY ("linked_by_user_id") REFERENCES "{SCHEMA_NAME}"."users" ("id"),
  CONSTRAINT "record_document_links_unique" UNIQUE ("record_id", "document_id")
);

COMMENT ON TABLE "{SCHEMA_NAME}"."record_document_links" IS 'Vinculos entre registros y documentos (draft u oficial)';

-- ============================================================================
-- INDICES
-- ============================================================================

-- Grupo B: Usuarios
CREATE INDEX "idx_{SCHEMA_NAME}_users_email" ON "{SCHEMA_NAME}"."users" ("email");
CREATE INDEX "idx_{SCHEMA_NAME}_users_sector" ON "{SCHEMA_NAME}"."users" ("sector_id");

-- Grupo D: Documentos
CREATE INDEX "idx_{SCHEMA_NAME}_document_draft_status" ON "{SCHEMA_NAME}"."document_draft" ("status");
CREATE INDEX "idx_{SCHEMA_NAME}_document_draft_created_by" ON "{SCHEMA_NAME}"."document_draft" ("created_by");
CREATE INDEX "idx_{SCHEMA_NAME}_document_draft_type" ON "{SCHEMA_NAME}"."document_draft" ("document_type_id");
CREATE INDEX "idx_{SCHEMA_NAME}_document_draft_created_by_date" ON "{SCHEMA_NAME}"."document_draft" ("created_by", "created_at" DESC);

-- document_signers: tabla de alta frecuencia (buscar firmantes, docs pendientes)
CREATE INDEX "idx_{SCHEMA_NAME}_doc_signers_document" ON "{SCHEMA_NAME}"."document_signers" ("document_id");
CREATE INDEX "idx_{SCHEMA_NAME}_doc_signers_user" ON "{SCHEMA_NAME}"."document_signers" ("user_id");
CREATE INDEX "idx_{SCHEMA_NAME}_doc_signers_status" ON "{SCHEMA_NAME}"."document_signers" ("status");

-- official_documents: búsqueda por número, fecha, departamento
CREATE INDEX "idx_{SCHEMA_NAME}_official_docs_signer_sectors" ON "{SCHEMA_NAME}"."official_documents" USING GIN ("signer_sector_ids");
CREATE INDEX "idx_{SCHEMA_NAME}_official_docs_number" ON "{SCHEMA_NAME}"."official_documents" ("official_number");
CREATE INDEX "idx_{SCHEMA_NAME}_official_docs_signed_at" ON "{SCHEMA_NAME}"."official_documents" ("signed_at" DESC);
CREATE INDEX "idx_{SCHEMA_NAME}_official_docs_department" ON "{SCHEMA_NAME}"."official_documents" ("department_id");

-- Grupo E: Expedientes
CREATE INDEX "idx_{SCHEMA_NAME}_cases_status" ON "{SCHEMA_NAME}"."cases" ("status");
CREATE INDEX "idx_{SCHEMA_NAME}_cases_owner_dept" ON "{SCHEMA_NAME}"."cases" ("owner_department_id");

-- case_movements: historial de expediente, asignaciones
CREATE INDEX "idx_{SCHEMA_NAME}_case_mov_case" ON "{SCHEMA_NAME}"."case_movements" ("case_id");
CREATE INDEX "idx_{SCHEMA_NAME}_case_mov_assigned_sector" ON "{SCHEMA_NAME}"."case_movements" ("assigned_sector_id");
CREATE INDEX "idx_{SCHEMA_NAME}_case_mov_case_date" ON "{SCHEMA_NAME}"."case_movements" ("case_id", "created_at" DESC);

-- case_official_documents: documentos de expediente
CREATE INDEX "idx_{SCHEMA_NAME}_case_off_docs_case" ON "{SCHEMA_NAME}"."case_official_documents" ("case_id");
CREATE INDEX "idx_{SCHEMA_NAME}_case_off_docs_doc" ON "{SCHEMA_NAME}"."case_official_documents" ("official_document_id");

-- Grupo E.1: Índices de Performance para /cases (optimiza subqueries correlacionadas)
-- Índice 1: Lookup de admin_sector (creation/transfer con estado cerrado)
CREATE INDEX "idx_{SCHEMA_NAME}_case_mov_admin_lookup" ON "{SCHEMA_NAME}"."case_movements" ("case_id", "type", "is_active", "closed_at" DESC)
    WHERE "type" IN ('creation', 'transfer');

-- Índice 2: Verificar si expediente tiene transfers
CREATE INDEX "idx_{SCHEMA_NAME}_case_mov_transfers" ON "{SCHEMA_NAME}"."case_movements" ("case_id")
    WHERE "type" = 'transfer';

-- Índice 3: Sectores asignados activos
CREATE INDEX "idx_{SCHEMA_NAME}_case_mov_assigned_active" ON "{SCHEMA_NAME}"."case_movements" ("case_id", "assigned_sector_id")
    WHERE "is_active" = true AND "assigned_sector_id" IS NOT NULL;

-- Índice 4: Documentos oficiales activos por fecha de vinculación
CREATE INDEX "idx_{SCHEMA_NAME}_case_off_docs_active" ON "{SCHEMA_NAME}"."case_official_documents" ("case_id", "linking_date" DESC)
    WHERE "is_active" = true;

-- Grupo E.2: Indices de Escalabilidad (100K+ filas)
-- cases: ORDER BY created_at en listado
CREATE INDEX "idx_{SCHEMA_NAME}_cases_created_at" ON "{SCHEMA_NAME}"."cases" ("created_at" DESC);
-- cases: filtro activos + ORDER BY combinado
CREATE INDEX "idx_{SCHEMA_NAME}_cases_active_created" ON "{SCHEMA_NAME}"."cases" ("created_at" DESC)
    WHERE "status" = 'active';

-- document_draft: ORDER BY last_modified_at en listado
CREATE INDEX "idx_{SCHEMA_NAME}_doc_draft_last_modified" ON "{SCHEMA_NAME}"."document_draft" ("last_modified_at" DESC);

-- document_signers: compuesto para LEFT JOIN hotpath en query de documentos
CREATE INDEX "idx_{SCHEMA_NAME}_doc_signers_doc_user" ON "{SCHEMA_NAME}"."document_signers" ("document_id", "user_id");

-- case_proposed_documents: propuestas de vinculación
CREATE INDEX "idx_{SCHEMA_NAME}_case_prop_docs_case" ON "{SCHEMA_NAME}"."case_proposed_documents" ("case_id");

-- Grupo G: Agente IA (solo document_chunks)
CREATE INDEX "idx_{SCHEMA_NAME}_chunks_doc" ON "{SCHEMA_NAME}"."document_chunks" ("official_document_id");

-- Indice vectorial HNSW para búsqueda semántica
CREATE INDEX "idx_{SCHEMA_NAME}_chunks_embedding" ON "{SCHEMA_NAME}"."document_chunks"
    USING hnsw ("embedding" vector_cosine_ops);

-- Grupo H: Notas
CREATE INDEX "idx_{SCHEMA_NAME}_notes_recipients_document" ON "{SCHEMA_NAME}"."notes_recipients" ("document_id");
CREATE INDEX "idx_{SCHEMA_NAME}_notes_recipients_sector" ON "{SCHEMA_NAME}"."notes_recipients" ("sector_id");
CREATE INDEX "idx_{SCHEMA_NAME}_notes_recipients_sender" ON "{SCHEMA_NAME}"."notes_recipients" ("sender_sector_id");
CREATE INDEX "idx_{SCHEMA_NAME}_notes_openings_document" ON "{SCHEMA_NAME}"."notes_openings" ("document_id");
CREATE INDEX "idx_{SCHEMA_NAME}_notes_openings_sector" ON "{SCHEMA_NAME}"."notes_openings" ("sector_id");

-- Grupo H.1: Índices parciales para archivado de notas
CREATE INDEX "idx_{SCHEMA_NAME}_notes_recipients_not_archived" ON "{SCHEMA_NAME}"."notes_recipients" ("sector_id")
    WHERE is_archived = false;
CREATE INDEX "idx_{SCHEMA_NAME}_notes_recipients_archived" ON "{SCHEMA_NAME}"."notes_recipients" ("sector_id")
    WHERE is_archived = true;

-- Grupo H.2: Memos
CREATE INDEX "idx_{SCHEMA_NAME}_memo_recipients_document" ON "{SCHEMA_NAME}"."memo_recipients" ("document_id");
CREATE INDEX "idx_{SCHEMA_NAME}_memo_recipients_sender" ON "{SCHEMA_NAME}"."memo_recipients" ("sender_user_id");
CREATE INDEX "idx_{SCHEMA_NAME}_memo_recipients_not_archived" ON "{SCHEMA_NAME}"."memo_recipients" ("recipient_user_id")
    WHERE is_archived = false;
CREATE INDEX "idx_{SCHEMA_NAME}_memo_recipients_archived" ON "{SCHEMA_NAME}"."memo_recipients" ("recipient_user_id")
    WHERE is_archived = true;

-- Grupo I: Registros
CREATE INDEX "idx_{SCHEMA_NAME}_records_family" ON "{SCHEMA_NAME}"."records" ("registry_family_id");
CREATE INDEX "idx_{SCHEMA_NAME}_records_state" ON "{SCHEMA_NAME}"."records" ("state");
CREATE INDEX "idx_{SCHEMA_NAME}_records_created_by" ON "{SCHEMA_NAME}"."records" ("created_by_user_id");
CREATE INDEX "idx_{SCHEMA_NAME}_records_data" ON "{SCHEMA_NAME}"."records" USING GIN ("data");
CREATE INDEX "idx_{SCHEMA_NAME}_records_expiration" ON "{SCHEMA_NAME}"."records" ("next_expiration")
    WHERE "next_expiration" IS NOT NULL;
CREATE INDEX "idx_{SCHEMA_NAME}_record_history_record" ON "{SCHEMA_NAME}"."record_history" ("record_id");
CREATE INDEX "idx_{SCHEMA_NAME}_record_relations_source" ON "{SCHEMA_NAME}"."record_relations" ("source_record_id");
CREATE INDEX "idx_{SCHEMA_NAME}_record_relations_target" ON "{SCHEMA_NAME}"."record_relations" ("target_record_id");
CREATE INDEX "idx_{SCHEMA_NAME}_record_case_links_record" ON "{SCHEMA_NAME}"."record_case_links" ("record_id");
CREATE INDEX "idx_{SCHEMA_NAME}_record_doc_links_record" ON "{SCHEMA_NAME}"."record_document_links" ("record_id");
CREATE INDEX "idx_{SCHEMA_NAME}_record_doc_links_doc" ON "{SCHEMA_NAME}"."record_document_links" ("document_id");

-- Grupo D.2: Numeracion unificada
CREATE INDEX "idx_{SCHEMA_NAME}_counters_updated_at" ON "{SCHEMA_NAME}"."document_number_counters" ("updated_at");

CREATE UNIQUE INDEX "idx_{SCHEMA_NAME}_official_docs_one_reserved_special"
  ON "{SCHEMA_NAME}"."official_documents" ("document_type_id", "department_id", "year")
  WHERE reservation_status = 'RESERVED' AND numbering_regime = 'SPECIAL';

CREATE INDEX "idx_{SCHEMA_NAME}_official_docs_cancelled_global"
  ON "{SCHEMA_NAME}"."official_documents" ("year", "reserved_at")
  WHERE reservation_status = 'CANCELLED' AND numbering_regime = 'GLOBAL';

CREATE INDEX "idx_{SCHEMA_NAME}_official_docs_cancelled_special"
  ON "{SCHEMA_NAME}"."official_documents" ("document_type_id", "department_id", "year", "reserved_at")
  WHERE reservation_status = 'CANCELLED' AND numbering_regime = 'SPECIAL';

CREATE INDEX "idx_{SCHEMA_NAME}_official_docs_reserved_at"
  ON "{SCHEMA_NAME}"."official_documents" ("reserved_at")
  WHERE reservation_status = 'RESERVED';

-- Grupo A.1: UNIQUE parcial en departments.acronym (activos)
CREATE UNIQUE INDEX "idx_{SCHEMA_NAME}_departments_acronym_active"
  ON "{SCHEMA_NAME}"."departments" ("acronym")
  WHERE is_active = true AND acronym IS NOT NULL;

-- Grupo SYNC: Índices en updated_at para backup incremental (23 tablas)
CREATE INDEX "idx_{SCHEMA_NAME}_departments_updated_at" ON "{SCHEMA_NAME}"."departments"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_sectors_updated_at" ON "{SCHEMA_NAME}"."sectors"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_ranks_updated_at" ON "{SCHEMA_NAME}"."ranks"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_city_seals_updated_at" ON "{SCHEMA_NAME}"."city_seals"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_users_updated_at" ON "{SCHEMA_NAME}"."users"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_user_roles_updated_at" ON "{SCHEMA_NAME}"."user_roles"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_user_seals_updated_at" ON "{SCHEMA_NAME}"."user_seals"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_user_sector_permissions_updated_at" ON "{SCHEMA_NAME}"."user_sector_permissions"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_estado_users_updated_at" ON "{SCHEMA_NAME}"."estado_users"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_document_types_updated_at" ON "{SCHEMA_NAME}"."document_types"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_document_types_allowed_by_rank_updated_at" ON "{SCHEMA_NAME}"."document_types_allowed_by_rank"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_enabled_document_types_by_sector_updated_at" ON "{SCHEMA_NAME}"."enabled_document_types_by_sector"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_cases_updated_at" ON "{SCHEMA_NAME}"."cases"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_case_movements_updated_at" ON "{SCHEMA_NAME}"."case_movements"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_case_templates_updated_at" ON "{SCHEMA_NAME}"."case_templates"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_case_template_allowed_departments_updated_at" ON "{SCHEMA_NAME}"."case_template_allowed_departments"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_case_official_documents_updated_at" ON "{SCHEMA_NAME}"."case_official_documents"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_case_proposed_documents_updated_at" ON "{SCHEMA_NAME}"."case_proposed_documents"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_official_documents_updated_at" ON "{SCHEMA_NAME}"."official_documents"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_document_signers_updated_at" ON "{SCHEMA_NAME}"."document_signers"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_document_rejections_updated_at" ON "{SCHEMA_NAME}"."document_rejections"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_notes_recipients_updated_at" ON "{SCHEMA_NAME}"."notes_recipients"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_notes_openings_updated_at" ON "{SCHEMA_NAME}"."notes_openings"("updated_at");
CREATE INDEX "idx_{SCHEMA_NAME}_memo_recipients_updated_at" ON "{SCHEMA_NAME}"."memo_recipients"("updated_at");

-- ============================================================================
-- TRIGGERS: updated_at (todas las tablas)
-- ============================================================================
-- Auto-update updated_at en BEFORE UPDATE usando public.fn_set_updated_at()

-- Grupo A: Estructura Organizacional
DROP TRIGGER IF EXISTS trg_departments_updated_at ON "{SCHEMA_NAME}"."departments";
CREATE TRIGGER trg_departments_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."departments"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_sectors_updated_at ON "{SCHEMA_NAME}"."sectors";
CREATE TRIGGER trg_sectors_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."sectors"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

-- Grupo B: Usuarios
DROP TRIGGER IF EXISTS trg_users_updated_at ON "{SCHEMA_NAME}"."users";
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."users"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_user_roles_updated_at ON "{SCHEMA_NAME}"."user_roles";
CREATE TRIGGER trg_user_roles_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."user_roles"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_user_seals_updated_at ON "{SCHEMA_NAME}"."user_seals";
CREATE TRIGGER trg_user_seals_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."user_seals"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_user_sector_permissions_updated_at ON "{SCHEMA_NAME}"."user_sector_permissions";
CREATE TRIGGER trg_user_sector_permissions_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."user_sector_permissions"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_estado_users_updated_at ON "{SCHEMA_NAME}"."estado_users";
CREATE TRIGGER trg_estado_users_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."estado_users"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

-- Grupo C: Rangos y Sellos
DROP TRIGGER IF EXISTS trg_ranks_updated_at ON "{SCHEMA_NAME}"."ranks";
CREATE TRIGGER trg_ranks_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."ranks"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_city_seals_updated_at ON "{SCHEMA_NAME}"."city_seals";
CREATE TRIGGER trg_city_seals_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."city_seals"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

-- Grupo D: Documentos
DROP TRIGGER IF EXISTS trg_document_types_updated_at ON "{SCHEMA_NAME}"."document_types";
CREATE TRIGGER trg_document_types_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."document_types"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_document_types_allowed_by_rank_updated_at ON "{SCHEMA_NAME}"."document_types_allowed_by_rank";
CREATE TRIGGER trg_document_types_allowed_by_rank_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."document_types_allowed_by_rank"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_enabled_document_types_by_sector_updated_at ON "{SCHEMA_NAME}"."enabled_document_types_by_sector";
CREATE TRIGGER trg_enabled_document_types_by_sector_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."enabled_document_types_by_sector"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_document_draft_updated_at ON "{SCHEMA_NAME}"."document_draft";
CREATE TRIGGER trg_document_draft_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."document_draft"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_document_signers_updated_at ON "{SCHEMA_NAME}"."document_signers";
CREATE TRIGGER trg_document_signers_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."document_signers"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_document_rejections_updated_at ON "{SCHEMA_NAME}"."document_rejections";
CREATE TRIGGER trg_document_rejections_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."document_rejections"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_official_documents_updated_at ON "{SCHEMA_NAME}"."official_documents";
CREATE TRIGGER trg_official_documents_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."official_documents"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_document_number_counters_updated_at ON "{SCHEMA_NAME}"."document_number_counters";
CREATE TRIGGER "trg_document_number_counters_updated_at"
  BEFORE UPDATE ON "{SCHEMA_NAME}"."document_number_counters"
  FOR EACH ROW EXECUTE FUNCTION "public"."fn_set_updated_at"();

-- Grupo E: Expedientes
DROP TRIGGER IF EXISTS trg_case_templates_updated_at ON "{SCHEMA_NAME}"."case_templates";
CREATE TRIGGER trg_case_templates_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."case_templates"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_case_template_allowed_departments_updated_at ON "{SCHEMA_NAME}"."case_template_allowed_departments";
CREATE TRIGGER trg_case_template_allowed_departments_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."case_template_allowed_departments"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_cases_updated_at ON "{SCHEMA_NAME}"."cases";
CREATE TRIGGER trg_cases_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."cases"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_case_movements_updated_at ON "{SCHEMA_NAME}"."case_movements";
CREATE TRIGGER trg_case_movements_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."case_movements"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_case_official_documents_updated_at ON "{SCHEMA_NAME}"."case_official_documents";
CREATE TRIGGER trg_case_official_documents_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."case_official_documents"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_case_proposed_documents_updated_at ON "{SCHEMA_NAME}"."case_proposed_documents";
CREATE TRIGGER trg_case_proposed_documents_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."case_proposed_documents"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

-- Grupo F: Configuracion
DROP TRIGGER IF EXISTS trg_settings_updated_at ON "{SCHEMA_NAME}"."settings";
CREATE TRIGGER trg_settings_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."settings"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

-- Grupo G: Agente IA
DROP TRIGGER IF EXISTS trg_document_chunks_updated_at ON "{SCHEMA_NAME}"."document_chunks";
CREATE TRIGGER trg_document_chunks_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."document_chunks"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

-- Grupo H: Notas
DROP TRIGGER IF EXISTS trg_notes_recipients_updated_at ON "{SCHEMA_NAME}"."notes_recipients";
CREATE TRIGGER trg_notes_recipients_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."notes_recipients"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_notes_openings_updated_at ON "{SCHEMA_NAME}"."notes_openings";
CREATE TRIGGER trg_notes_openings_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."notes_openings"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_memo_recipients_updated_at ON "{SCHEMA_NAME}"."memo_recipients";
CREATE TRIGGER trg_memo_recipients_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."memo_recipients"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

-- Grupo I: Registros
DROP TRIGGER IF EXISTS trg_registry_families_updated_at ON "{SCHEMA_NAME}"."registry_families";
CREATE TRIGGER trg_registry_families_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."registry_families"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_registry_family_permissions_updated_at ON "{SCHEMA_NAME}"."registry_family_permissions";
CREATE TRIGGER trg_registry_family_permissions_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."registry_family_permissions"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_records_updated_at ON "{SCHEMA_NAME}"."records";
CREATE TRIGGER trg_records_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."records"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_record_history_updated_at ON "{SCHEMA_NAME}"."record_history";
CREATE TRIGGER trg_record_history_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."record_history"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_record_relations_updated_at ON "{SCHEMA_NAME}"."record_relations";
CREATE TRIGGER trg_record_relations_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."record_relations"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_record_case_links_updated_at ON "{SCHEMA_NAME}"."record_case_links";
CREATE TRIGGER trg_record_case_links_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."record_case_links"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_record_document_links_updated_at ON "{SCHEMA_NAME}"."record_document_links";
CREATE TRIGGER trg_record_document_links_updated_at BEFORE UPDATE ON "{SCHEMA_NAME}"."record_document_links"
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

-- ============================================================================
-- TRIGGER: Sincronizar users con public.user_registry
-- ============================================================================
-- Cuando se crea/actualiza/elimina un usuario, se sincroniza automaticamente
-- con public.user_registry para el sistema multi-tenant
-- NOTA: El nombre del municipio se obtiene via JOIN con municipalities.name

CREATE OR REPLACE FUNCTION "{SCHEMA_NAME}"."fn_sync_user_registry"()
RETURNS TRIGGER AS $$
DECLARE
    v_schema_name TEXT := TG_TABLE_SCHEMA;
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Insertar en user_registry (display_name y profile_picture_url se obtienen de otras tablas)
        INSERT INTO public.user_registry (email, schema_name, is_default)
        VALUES (NEW.email, v_schema_name, false)
        ON CONFLICT (email, schema_name) DO NOTHING;
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        -- Si cambio el email, actualizar en user_registry
        IF OLD.email IS DISTINCT FROM NEW.email THEN
            UPDATE public.user_registry
            SET email = NEW.email
            WHERE email = OLD.email AND schema_name = v_schema_name;
        END IF;
        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        -- Eliminar de user_registry
        DELETE FROM public.user_registry
        WHERE email = OLD.email AND schema_name = v_schema_name;
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger en tabla users
CREATE TRIGGER "trg_sync_user_registry"
    AFTER INSERT OR UPDATE OR DELETE ON "{SCHEMA_NAME}"."users"
    FOR EACH ROW EXECUTE FUNCTION "{SCHEMA_NAME}"."fn_sync_user_registry"();

-- ============================================================================
-- SECCION 2: SCHEMA AUDIT
-- ============================================================================

DROP SCHEMA IF EXISTS "{SCHEMA_NAME}_audit" CASCADE;

CREATE SCHEMA "{SCHEMA_NAME}_audit";

-- ============================================================================
-- TABLA: audit_log
-- ============================================================================

CREATE TABLE "{SCHEMA_NAME}_audit"."audit_log" (
  "id" BIGSERIAL NOT NULL,
  "event_time" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "schema_name" TEXT NOT NULL,
  "table_name" TEXT NOT NULL,
  "operation" TEXT NOT NULL,  -- INSERT, UPDATE, DELETE
  "user_name" TEXT,
  "user_id" UUID,  -- ID del usuario que hizo el cambio (inyectado via GUC app.user_id)
  "auth_source" VARCHAR(20),  -- Origen: jwt, api_key, mcp_oauth, testing, system
  "old_row" JSONB,
  "new_row" JSONB,
  "changed_fields" TEXT[],  -- Lista de campos modificados
  CONSTRAINT "audit_log_pkey" PRIMARY KEY ("id")
);

COMMENT ON TABLE "{SCHEMA_NAME}_audit"."audit_log" IS 'Registro de auditoria del municipio';

-- Indice para busquedas por fecha
CREATE INDEX "idx_{SCHEMA_NAME}_audit_audit_log_event_time" ON "{SCHEMA_NAME}_audit"."audit_log" ("event_time");
CREATE INDEX "idx_{SCHEMA_NAME}_audit_audit_log_table" ON "{SCHEMA_NAME}_audit"."audit_log" ("table_name");
CREATE INDEX "idx_{SCHEMA_NAME}_audit_audit_log_user" ON "{SCHEMA_NAME}_audit"."audit_log" ("user_id");

-- ============================================================================
-- FUNCION: fn_log_change
-- ============================================================================

CREATE OR REPLACE FUNCTION "{SCHEMA_NAME}_audit"."fn_log_change"()
RETURNS TRIGGER AS $$
DECLARE
    v_old_row JSONB := NULL;
    v_new_row JSONB := NULL;
    v_changed_fields TEXT[] := '{}';
    v_key TEXT;
    v_user_id UUID := NULL;
    v_auth_source VARCHAR(20) := NULL;
BEGIN
    -- Leer contexto de aplicación (inyectado via GUC por el backend)
    -- current_setting(..., true) retorna NULL si no existe en lugar de error
    BEGIN
        v_user_id := NULLIF(current_setting('app.user_id', true), '')::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;

    BEGIN
        v_auth_source := NULLIF(current_setting('app.auth_source', true), '');
    EXCEPTION WHEN OTHERS THEN
        v_auth_source := NULL;
    END;

    IF TG_OP = 'INSERT' THEN
        v_new_row := to_jsonb(NEW);

        INSERT INTO "{SCHEMA_NAME}_audit".audit_log(
            schema_name, table_name, operation, user_name, user_id, auth_source, new_row
        ) VALUES (
            TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP, current_user, v_user_id, v_auth_source, v_new_row
        );

        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        v_old_row := to_jsonb(OLD);
        v_new_row := to_jsonb(NEW);

        -- Detectar campos cambiados
        FOR v_key IN SELECT jsonb_object_keys(v_new_row)
        LOOP
            IF v_old_row->v_key IS DISTINCT FROM v_new_row->v_key THEN
                v_changed_fields := array_append(v_changed_fields, v_key);
            END IF;
        END LOOP;

        INSERT INTO "{SCHEMA_NAME}_audit".audit_log(
            schema_name, table_name, operation, user_name, user_id, auth_source, old_row, new_row, changed_fields
        ) VALUES (
            TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP, current_user, v_user_id, v_auth_source, v_old_row, v_new_row, v_changed_fields
        );

        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        v_old_row := to_jsonb(OLD);

        INSERT INTO "{SCHEMA_NAME}_audit".audit_log(
            schema_name, table_name, operation, user_name, user_id, auth_source, old_row
        ) VALUES (
            TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP, current_user, v_user_id, v_auth_source, v_old_row
        );

        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGERS (6 tablas auditadas)
-- ============================================================================
-- Estructura organizacional: departments, sectors
-- Documentos oficiales: official_documents (numeracion)
-- Expedientes: cases, case_movements (asignacion, transferencia, subsanacion),
--              case_official_documents (vinculacion de docs)
-- Trazabilidad: user_id + auth_source inyectados via GUC por el Backend

-- Departments
DROP TRIGGER IF EXISTS "trg_audit_departments" ON "{SCHEMA_NAME}"."departments";
CREATE TRIGGER "trg_audit_departments"
    AFTER INSERT OR UPDATE OR DELETE ON "{SCHEMA_NAME}"."departments"
    FOR EACH ROW EXECUTE FUNCTION "{SCHEMA_NAME}_audit"."fn_log_change"();

-- Sectors
DROP TRIGGER IF EXISTS "trg_audit_sectors" ON "{SCHEMA_NAME}"."sectors";
CREATE TRIGGER "trg_audit_sectors"
    AFTER INSERT OR UPDATE OR DELETE ON "{SCHEMA_NAME}"."sectors"
    FOR EACH ROW EXECUTE FUNCTION "{SCHEMA_NAME}_audit"."fn_log_change"();

-- Official Documents
DROP TRIGGER IF EXISTS "trg_audit_official_documents" ON "{SCHEMA_NAME}"."official_documents";
CREATE TRIGGER "trg_audit_official_documents"
    AFTER INSERT OR UPDATE OR DELETE ON "{SCHEMA_NAME}"."official_documents"
    FOR EACH ROW EXECUTE FUNCTION "{SCHEMA_NAME}_audit"."fn_log_change"();

-- Cases
DROP TRIGGER IF EXISTS "trg_audit_cases" ON "{SCHEMA_NAME}"."cases";
CREATE TRIGGER "trg_audit_cases"
    AFTER INSERT OR UPDATE OR DELETE ON "{SCHEMA_NAME}"."cases"
    FOR EACH ROW EXECUTE FUNCTION "{SCHEMA_NAME}_audit"."fn_log_change"();

-- Case Movements (asignacion, transferencia, subsanacion, document_link)
DROP TRIGGER IF EXISTS "trg_audit_case_movements" ON "{SCHEMA_NAME}"."case_movements";
CREATE TRIGGER "trg_audit_case_movements"
    AFTER INSERT OR UPDATE OR DELETE ON "{SCHEMA_NAME}"."case_movements"
    FOR EACH ROW EXECUTE FUNCTION "{SCHEMA_NAME}_audit"."fn_log_change"();

-- Case Official Documents (vinculacion/desvinculacion de docs a expedientes)
DROP TRIGGER IF EXISTS "trg_audit_case_official_documents" ON "{SCHEMA_NAME}"."case_official_documents";
CREATE TRIGGER "trg_audit_case_official_documents"
    AFTER INSERT OR UPDATE OR DELETE ON "{SCHEMA_NAME}"."case_official_documents"
    FOR EACH ROW EXECUTE FUNCTION "{SCHEMA_NAME}_audit"."fn_log_change"();

-- ============================================================================
-- SECCION 3: DATOS INICIALES
-- ============================================================================

-- ============================================================================
-- SETTINGS
-- ============================================================================

INSERT INTO "{SCHEMA_NAME}"."settings" (
    "timezone",
    "bucket_oficial",
    "bucket_tosign",
    "city",
    "primary_color"
) VALUES (
    'America/Argentina/Buenos_Aires',
    '{BUCKET_OFICIAL}',
    '{BUCKET_TOSIGN}',
    '{CITY}',
    '{PRIMARY_COLOR}'
);

-- ============================================================================
-- ESTADO_USERS
-- ============================================================================

INSERT INTO "{SCHEMA_NAME}"."estado_users" ("id", "estado") VALUES
(1, 'Activo'),
(2, 'Inactivo'),
(3, 'Suspendido'),
(4, 'Pendiente');

-- ============================================================================
-- DOCUMENT TYPES: IFRLM
-- ============================================================================

-- Insertar IFRLM en document_types del tenant nuevo
INSERT INTO "{SCHEMA_NAME}"."document_types"
    ("global_document_type_id", "name", "acronym", "description", "required_signature", "is_active", "type", "trust")
SELECT
    'd0000000-0000-0000-0000-000000000080'::uuid,
    'Informe RLM',
    'IFRLM',
    'Informe de Registro Legajo Multiproposito (generado on-demand desde un legajo RLM)',
    'required',
    true,
    'HTML',
    true
WHERE NOT EXISTS (
    SELECT 1 FROM "{SCHEMA_NAME}"."document_types"
    WHERE acronym = 'IFRLM'
);

-- ============================================================================
-- SECCION 4: REGISTRO DEL TENANT
-- ============================================================================

-- ============================================================================
-- 1. Crear municipio en public.municipalities
-- ============================================================================

INSERT INTO "public"."municipalities"
("id", "name", "acronym", "country", "schema_number", "schema_name", "is_active")
VALUES
(
    gen_random_uuid(),
    '{MUNICIPALITY_NAME}',
    '{ACRONYM}',
    '{COUNTRY}',
    {SCHEMA_NUMBER},
    '{SCHEMA_NAME}',
    true
);

-- ============================================================================
-- 2. Crear departamento root + case_templates base
-- ============================================================================

DO $$
DECLARE
    v_dept_id UUID;
BEGIN
    -- Crear departamento root
    INSERT INTO "{SCHEMA_NAME}"."departments"
    ("id", "name", "acronym", "is_active")
    VALUES
    (
        gen_random_uuid(),
        'Root Department',
        'ROOT',
        true
    );

    -- Obtener el ID del departamento creado
    SELECT id INTO v_dept_id FROM "{SCHEMA_NAME}"."departments"
    WHERE acronym = 'ROOT' LIMIT 1;

    -- Crear case_templates base (EEVAR + ECAPA)
    INSERT INTO "{SCHEMA_NAME}"."case_templates"
    ("id", "global_case_template_id", "type_name", "acronym", "description", "creation_channel", "filing_department_id", "is_active")
    VALUES
    (
        gen_random_uuid(),
        'b0000000-0000-0000-0000-000000000001'::uuid,
        'Expediente Varios',
        'EEVAR',
        'Expediente para temas varios',
        'web',
        v_dept_id,
        true
    ),
    (
        gen_random_uuid(),
        'b0000000-0000-0000-0000-000000000004'::uuid,
        'Expediente de Capacitacion',
        'ECAPA',
        'Expediente de Capacitacion',
        'web',
        v_dept_id,
        true
    );

    RAISE NOTICE 'Departamento root y case_templates creados exitosamente';
END $$;

-- ============================================================================
-- RESUMEN FINAL
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'MUNICIPIO {SCHEMA_NAME} CREADO EXITOSAMENTE';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '';
    RAISE NOTICE 'SCHEMA MUNICIPIO:';
    RAISE NOTICE '  Tablas: 33 (Grupos A-I)';
    RAISE NOTICE '  Indices: 47 (Performance + Vectorial)';
    RAISE NOTICE '  Triggers: 34 (33 updated_at + 1 sync user_registry)';
    RAISE NOTICE '';
    RAISE NOTICE 'SCHEMA AUDIT:';
    RAISE NOTICE '  Tabla: audit_log (con auth_source para trazabilidad)';
    RAISE NOTICE '  Funcion: fn_log_change';
    RAISE NOTICE '  Triggers: 6 (departments, sectors, official_documents, cases, case_movements, case_official_documents)';
    RAISE NOTICE '';
    RAISE NOTICE 'DATOS INICIALES:';
    RAISE NOTICE '  Settings: 1 (con buckets Cloudflare)';
    RAISE NOTICE '  Estado Users: 4 (Activo, Inactivo, Suspendido, Pendiente)';
    RAISE NOTICE '  Municipio: {MUNICIPALITY_NAME} registrado en public.municipalities';
    RAISE NOTICE '  Departamento: ROOT creado';
    RAISE NOTICE '  Case Templates: 2 (EEVAR, ECAPA)';
    RAISE NOTICE '';
    RAISE NOTICE 'MUNICIPIO LISTO PARA USAR';
    RAISE NOTICE '============================================================';
END $$;
