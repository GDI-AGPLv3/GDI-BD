-- ============================================================================
-- GDI LATAM - SCHEMA PUBLIC (Multi-Tenant)
-- ============================================================================
-- Descripcion: Tablas globales compartidas por todos los municipios
-- Version: 4.0.0 (Multi-Tenant + pgvector + API Keys)
-- PostgreSQL: 17.0+
--
-- CONTENIDO: 9 tablas globales
--   1. roles
--   2. global_document_types
--   3. global_case_templates
--   4. municipalities
--   5. document_display_states
--   6. user_registry
--   7. api_keys (GDI-MCP Server REST API)
--   8. api_key_users (Usuarios autorizados por API Key)
--   9. global_registry_families (Familias de registros)
--
-- NOTA: ranks y global_seals fueron movidos a schema per-tenant (v4.0.0)
--       Cada municipio define sus propios ranks y sellos en city_seals
-- ============================================================================

-- ============================================================================
-- EXTENSIONES REQUERIDAS
-- ============================================================================
-- Habilitar extensiones necesarias para el sistema
-- Solo se ejecuta una vez, globalmente

CREATE EXTENSION IF NOT EXISTS vector;    -- Búsqueda vectorial (RAG) para GDI-Agente
CREATE EXTENSION IF NOT EXISTS unaccent;  -- Búsquedas sin acentos (Backend filters)
CREATE EXTENSION IF NOT EXISTS pg_trgm;   -- Búsqueda por similitud (trigram)

-- ============================================================================
-- TIPOS ENUMERADOS
-- ============================================================================

DROP TYPE IF EXISTS "public"."country_enum" CASCADE;
CREATE TYPE "public"."country_enum" AS ENUM (
  'AR',
  'BR',
  'UY',
  'CL',
  'PY',
  'BO',
  'PE',
  'EC',
  'CO',
  'VE',
  'MX'
);

DROP TYPE IF EXISTS "public"."document_status" CASCADE;
CREATE TYPE "public"."document_status" AS ENUM (
  'draft',
  'sent_to_sign',
  'signed',
  'rejected',
  'cancelled'
);

DROP TYPE IF EXISTS "public"."document_signer_status" CASCADE;
CREATE TYPE "public"."document_signer_status" AS ENUM (
  'pending',
  'signed',
  'rejected'
);

DROP TYPE IF EXISTS "public"."movement_type" CASCADE;
CREATE TYPE "public"."movement_type" AS ENUM (
  'creation',
  'transfer',
  'assignment',
  'assignment_close',
  'status_change',
  'document_link',
  'subsanacion',
  'document_proposal',
  'document_proposal_reject'
);

DROP TYPE IF EXISTS "public"."status_case" CASCADE;
CREATE TYPE "public"."status_case" AS ENUM (
  'inactive',
  'active',
  'archived'
);

DROP TYPE IF EXISTS "public"."case_creation_channel" CASCADE;
CREATE TYPE "public"."case_creation_channel" AS ENUM (
  'web',
  'api',
  'both'
);

DROP TYPE IF EXISTS "public"."document_type_source" CASCADE;
CREATE TYPE "public"."document_type_source" AS ENUM (
  'HTML',
  'Importado',
  'NOTA'
);

-- ============================================================================
-- TABLA 1: roles
-- ============================================================================
-- Roles globales del sistema (compartidos por todos los municipios)

DROP TABLE IF EXISTS "public"."roles" CASCADE;
CREATE TABLE "public"."roles" (
  "role_id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "role_name" VARCHAR(50) NOT NULL,
  "description" TEXT,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "roles_pkey" PRIMARY KEY ("role_id"),
  CONSTRAINT "roles_name_unique" UNIQUE ("role_name")
);

COMMENT ON TABLE "public"."roles" IS 'Roles globales del sistema';

-- ============================================================================
-- TABLA 2: global_document_types
-- ============================================================================
-- Tipos de documento globales (9 tipos)

DROP TABLE IF EXISTS "public"."global_document_types" CASCADE;
CREATE TABLE "public"."global_document_types" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "name" VARCHAR(100) NOT NULL,
  "acronym" VARCHAR(6) NOT NULL,
  "description" TEXT,
  "signature_type" VARCHAR(50) DEFAULT 'required',
  "is_visible" BOOLEAN NOT NULL DEFAULT true,  -- false = uso exclusivo interno (PV, CAEX)
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "type" "public"."document_type_source" NOT NULL DEFAULT 'HTML',
  "trust" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "global_document_types_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "global_document_types_acronym_unique" UNIQUE ("acronym"),
  CONSTRAINT "global_document_types_acronym_length" CHECK (char_length(acronym) <= 6)
);

COMMENT ON TABLE "public"."global_document_types" IS 'Tipos de documento globales';
COMMENT ON COLUMN "public"."global_document_types"."is_visible" IS 'false para tipos de uso interno (PV, CAEX)';
COMMENT ON COLUMN "public"."global_document_types"."type" IS 'HTML = creado con editor, Importado = PDF subido';
COMMENT ON COLUMN "public"."global_document_types"."trust" IS 'true = documento gobierno (confiable), false = documento externo (requiere validacion IA)';

-- ============================================================================
-- TABLA 3: global_case_templates
-- ============================================================================
-- Plantillas de expediente globales (4 plantillas)

DROP TABLE IF EXISTS "public"."global_case_templates" CASCADE;
CREATE TABLE "public"."global_case_templates" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "type_name" VARCHAR(100) NOT NULL,
  "acronym" VARCHAR(6) NOT NULL,
  "description" TEXT,
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "global_case_templates_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "global_case_templates_acronym_unique" UNIQUE ("acronym")
);

COMMENT ON TABLE "public"."global_case_templates" IS 'Plantillas de expediente globales';

-- ============================================================================
-- TABLA 4: municipalities
-- ============================================================================
-- Lista de municipios (cada uno tiene su propio schema)

DROP TABLE IF EXISTS "public"."municipalities" CASCADE;
CREATE TABLE "public"."municipalities" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "name" TEXT NOT NULL,
  "acronym" VARCHAR(4) NOT NULL,  -- Auto: combinacion WXYZ
  "country" "public"."country_enum" NOT NULL,
  "primary_color" VARCHAR(6) NOT NULL DEFAULT '16158C',
  "schema_number" INT NOT NULL,  -- 100, 101, 102... (auto)
  "schema_name" TEXT NOT NULL,   -- "100_test", "101_bsas" (auto)
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "created_by" UUID,
  CONSTRAINT "municipalities_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "municipalities_acronym_unique" UNIQUE ("acronym"),
  CONSTRAINT "municipalities_schema_number_unique" UNIQUE ("schema_number"),
  CONSTRAINT "municipalities_schema_name_unique" UNIQUE ("schema_name")
);

COMMENT ON TABLE "public"."municipalities" IS 'Lista de municipios (cada uno tiene su schema)';
COMMENT ON COLUMN "public"."municipalities"."acronym" IS 'Auto-generado con WXYZ, cambia cuando pagan';
COMMENT ON COLUMN "public"."municipalities"."schema_number" IS 'Numero auto-incremental desde 100';

-- ============================================================================
-- TABLA 5: document_display_states
-- ============================================================================
-- Estados de visualizacion de documentos

DROP TABLE IF EXISTS "public"."document_display_states" CASCADE;
CREATE TABLE "public"."document_display_states" (
  "id" SERIAL NOT NULL,
  "display_state_code" VARCHAR(50) NOT NULL,
  "display_state_name" VARCHAR(100) NOT NULL,
  "description" TEXT,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "document_display_states_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "document_display_states_code_unique" UNIQUE ("display_state_code")
);

COMMENT ON TABLE "public"."document_display_states" IS 'Estados de visualizacion de documentos';

-- ============================================================================
-- TABLA 6: user_registry
-- ============================================================================
-- Mapea email -> schemas permitidos (multi-tenant)
-- Un usuario puede tener acceso a multiples municipios

DROP TABLE IF EXISTS "public"."user_registry" CASCADE;
CREATE TABLE "public"."user_registry" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "email" TEXT NOT NULL,
  "schema_name" TEXT NOT NULL,
  "is_default" BOOLEAN NOT NULL DEFAULT false,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "user_registry_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "user_registry_email_schema_unique" UNIQUE ("email", "schema_name")
);

COMMENT ON TABLE "public"."user_registry" IS 'Mapeo de email a schemas permitidos (multi-tenant). Nombre municipio se obtiene de municipalities.name, foto de perfil de {schema}.users';
COMMENT ON COLUMN "public"."user_registry"."is_default" IS 'Municipio por defecto del usuario';

-- Indice para busquedas por email
CREATE INDEX "idx_user_registry_email" ON "public"."user_registry" ("email");

-- ============================================================================
-- TABLA 7: api_keys (GDI-MCP Server REST API)
-- ============================================================================
-- API Keys para acceso REST a GDI-MCP Server
-- Cada municipalidad puede tener múltiples API Keys

DROP TABLE IF EXISTS "public"."api_keys" CASCADE;
CREATE TABLE "public"."api_keys" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "api_key" VARCHAR(64) NOT NULL,
  "municipality_id" UUID NOT NULL,
  "name" VARCHAR(100) NOT NULL,
  "description" TEXT,
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "expires_at" TIMESTAMPTZ,
  "last_used_at" TIMESTAMPTZ,
  "rate_limit_per_minute" INT DEFAULT 60,
  "created_by" VARCHAR(100),
  CONSTRAINT "api_keys_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "api_keys_key_unique" UNIQUE ("api_key"),
  CONSTRAINT "api_keys_municipality_fkey" FOREIGN KEY ("municipality_id") REFERENCES "public"."municipalities" ("id")
);

COMMENT ON TABLE "public"."api_keys" IS 'API Keys para REST API de GDI-MCP Server';
COMMENT ON COLUMN "public"."api_keys"."api_key" IS 'Key única (formato: sk_live_xxx o sk_test_xxx)';
COMMENT ON COLUMN "public"."api_keys"."municipality_id" IS 'Municipalidad asociada - determina el schema';
COMMENT ON COLUMN "public"."api_keys"."name" IS 'Nombre descriptivo del cliente/integración';
COMMENT ON COLUMN "public"."api_keys"."expires_at" IS 'NULL = no expira';
COMMENT ON COLUMN "public"."api_keys"."last_used_at" IS 'Se actualiza en cada uso';
COMMENT ON COLUMN "public"."api_keys"."rate_limit_per_minute" IS 'Límite de requests por minuto';

-- Índice para búsqueda rápida de API Key activa
CREATE INDEX "idx_api_keys_key" ON "public"."api_keys" ("api_key") WHERE "is_active" = true;

-- Índice para búsqueda por municipalidad
CREATE INDEX "idx_api_keys_municipality" ON "public"."api_keys" ("municipality_id");

-- ============================================================================
-- TABLA 8: api_key_users (Usuarios autorizados por API Key)
-- ============================================================================
-- Asocia usuarios a API Keys para trazabilidad en REST API.
-- El cliente DEBE enviar X-User-ID con cada request para identificar
-- qué usuario está realizando la operación.

DROP TABLE IF EXISTS "public"."api_key_users" CASCADE;
CREATE TABLE "public"."api_key_users" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "api_key_id" UUID NOT NULL,
  "user_id" UUID NOT NULL,           -- UUID del usuario en el schema del tenant
  "schema_name" VARCHAR(100) NOT NULL, -- Schema donde existe el usuario
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "api_key_users_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "api_key_users_key_user_schema_unique" UNIQUE ("api_key_id", "user_id", "schema_name"),
  CONSTRAINT "api_key_users_key_fkey" FOREIGN KEY ("api_key_id") REFERENCES "public"."api_keys" ("id") ON DELETE CASCADE
);

COMMENT ON TABLE "public"."api_key_users" IS 'Usuarios autorizados por API Key para REST API';
COMMENT ON COLUMN "public"."api_key_users"."user_id" IS 'UUID del usuario en el schema del tenant';
COMMENT ON COLUMN "public"."api_key_users"."schema_name" IS 'Schema donde existe el usuario (ej: 100_test)';

-- Índice para búsqueda por API Key (obtener usuarios autorizados)
CREATE INDEX "idx_api_key_users_key" ON "public"."api_key_users" ("api_key_id");

-- Índice para búsqueda por usuario (ver a qué API Keys tiene acceso)
CREATE INDEX "idx_api_key_users_user" ON "public"."api_key_users" ("user_id", "schema_name");

-- ============================================================================
-- TABLA 9: global_registry_families (Familias de registros)
-- ============================================================================
-- Familias de registros globales con esquema de datos y estados por defecto.
-- Cada municipio puede copiar y personalizar estas familias en su schema.

DROP TABLE IF EXISTS "public"."global_registry_families" CASCADE;
CREATE TABLE "public"."global_registry_families" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "code" VARCHAR(10) NOT NULL,
  "name" VARCHAR(200) NOT NULL,
  "description" TEXT,
  "default_data_schema" JSONB DEFAULT '{}',
  "default_states" JSONB DEFAULT '["Activo","Inactivo","Suspendido","Archivado"]',
  "is_active" BOOLEAN NOT NULL DEFAULT true,
  "created_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  "updated_at" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT "global_registry_families_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "global_registry_families_code_unique" UNIQUE ("code")
);

COMMENT ON TABLE "public"."global_registry_families" IS 'Familias de registros globales con esquema de datos por defecto';
COMMENT ON COLUMN "public"."global_registry_families"."default_data_schema" IS 'Schema JSONB que define los campos del registro';
COMMENT ON COLUMN "public"."global_registry_families"."default_states" IS 'Array JSON de estados posibles del registro';

-- ============================================================================
-- TABLAS AUTOMÁTICAS (GDI-AgenteLANG - NO crear manualmente)
-- ============================================================================
-- Las siguientes tablas son creadas automáticamente por GDI-AgenteLANG
-- durante el startup (lifespan). Se crean en schema public.
--
-- LangGraph checkpointer (checkpointer.setup()):
--   - checkpoints           Estado del grafo por thread_id (conversación)
--   - checkpoint_blobs      Datos binarios grandes (mensajes, estado)
--   - checkpoint_writes     Escrituras pendientes (concurrencia)
--   - checkpoint_migrations Control de versión del schema de checkpoints
--
-- Chat history (setup_chat_messages_table()):
--   - chat_messages          Historial de chat relacional y consultable
--                            (conversation_id, user_id, role, content, etc.)
--
-- NO crear estas tablas manualmente.
-- El thread_id tiene formato: {municipality_id}:{conversation_id}
-- para aislamiento multi-tenant.
-- ============================================================================

-- ============================================================================
-- FIN SCHEMA PUBLIC
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'SCHEMA PUBLIC CREADO';
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Tablas creadas: 9';
    RAISE NOTICE '  1. roles';
    RAISE NOTICE '  2. global_document_types';
    RAISE NOTICE '  3. global_case_templates';
    RAISE NOTICE '  4. municipalities';
    RAISE NOTICE '  5. document_display_states';
    RAISE NOTICE '  6. user_registry';
    RAISE NOTICE '  7. api_keys (GDI-MCP REST API)';
    RAISE NOTICE '  8. api_key_users (Usuarios autorizados por API Key)';
    RAISE NOTICE '  9. global_registry_families (Familias de registros)';
    RAISE NOTICE '  NOTA: ranks y seals son per-tenant (schema local)';
    RAISE NOTICE '============================================================';
END $$;
