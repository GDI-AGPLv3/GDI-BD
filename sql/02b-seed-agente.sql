-- ============================================================================
-- 02b-seed-agente.sql
-- Tablas de GDI-AgenteLANG en schema public
-- ============================================================================
--
-- Crea las 7 tablas que GDI-AgenteLANG genera en su startup (lifespan).
-- Ejecutar DESPUES de 01-install.sql y ANTES o DESPUES de 02-seed-global.sql.
--
-- Todas usan CREATE TABLE IF NOT EXISTS (idempotente, safe to re-run).
--
-- Tablas:
--   1. chat_messages         - Historial de conversaciones del chat IA
--   2. ai_usage_log          - Log de llamadas AI con tokens y costo
--   3. ai_usage_limits       - Limites diarios de gasto por schema
--   4. checkpoint_migrations - Control de version del checkpointer LangGraph
--   5. checkpoints           - Estado de conversaciones LangGraph
--   6. checkpoint_blobs      - Datos binarios de canales del grafo
--   7. checkpoint_writes     - Writes pendientes entre nodos del grafo
--
-- Fuentes:
--   - GDI-AgenteLANG/app/db/messages.py (chat_messages)
--   - GDI-AgenteLANG/app/services/usage_tracker.py (ai_usage_log, ai_usage_limits)
--   - langgraph-checkpoint-postgres (checkpoint_*)
-- ============================================================================


-- ============================================================================
-- TABLA 1: chat_messages
-- Historial queryable de mensajes del chat IA (user + assistant)
-- Fuente: app/db/messages.py :: setup_chat_messages_table()
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    conversation_id TEXT NOT NULL,
    schema_name TEXT NOT NULL,
    user_id TEXT NOT NULL,
    case_id UUID,
    role TEXT NOT NULL,
    content TEXT NOT NULL,
    chat_type TEXT NOT NULL,
    metadata JSONB
);

CREATE INDEX IF NOT EXISTS idx_chat_messages_conversation
    ON public.chat_messages(conversation_id);

CREATE INDEX IF NOT EXISTS idx_chat_messages_user
    ON public.chat_messages(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_chat_messages_schema
    ON public.chat_messages(schema_name, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_chat_messages_case
    ON public.chat_messages(case_id) WHERE case_id IS NOT NULL;


-- ============================================================================
-- TABLA 2: ai_usage_log
-- Log de cada llamada AI con tokens consumidos y costo estimado
-- Fuente: app/services/usage_tracker.py :: setup_ai_usage_tables()
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.ai_usage_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    schema_name VARCHAR(100) NOT NULL,
    document_id UUID,
    case_id UUID,
    operation VARCHAR(40) NOT NULL,
    model VARCHAR(100) NOT NULL,
    openrouter_id VARCHAR(100),
    prompt_tokens INT NOT NULL DEFAULT 0,
    completion_tokens INT NOT NULL DEFAULT 0,
    total_tokens INT GENERATED ALWAYS AS (prompt_tokens + completion_tokens) STORED,
    estimated_cost_usd DECIMAL(10,6) NOT NULL DEFAULT 0,
    status VARCHAR(20) NOT NULL DEFAULT 'success',
    error_message TEXT,
    metadata JSONB,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_usage_log_schema
    ON public.ai_usage_log(schema_name);

CREATE INDEX IF NOT EXISTS idx_ai_usage_log_created
    ON public.ai_usage_log(created_at);

CREATE INDEX IF NOT EXISTS idx_ai_usage_log_schema_created
    ON public.ai_usage_log(schema_name, created_at);

CREATE INDEX IF NOT EXISTS idx_ai_usage_log_openrouter
    ON public.ai_usage_log(openrouter_id) WHERE openrouter_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ai_usage_log_schema_status_created
    ON public.ai_usage_log(schema_name, status, created_at);


-- ============================================================================
-- TABLA 3: ai_usage_limits
-- Limites diarios de gasto AI por schema (con acumulador fast-path)
-- Fuente: app/services/usage_tracker.py :: setup_ai_usage_tables()
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.ai_usage_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    schema_name VARCHAR(100) UNIQUE NOT NULL,
    daily_limit_usd DECIMAL(10,2) NOT NULL DEFAULT 10.00,
    is_enabled BOOLEAN NOT NULL DEFAULT true,
    today_cost_usd DECIMAL(10,6) NOT NULL DEFAULT 0,
    today_date DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);


-- ============================================================================
-- TRIGGERS: updated_at (ai_usage_log, ai_usage_limits)
-- ============================================================================

DROP TRIGGER IF EXISTS trg_ai_usage_log_updated_at ON public.ai_usage_log;
CREATE TRIGGER trg_ai_usage_log_updated_at BEFORE UPDATE ON public.ai_usage_log
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_ai_usage_limits_updated_at ON public.ai_usage_limits;
CREATE TRIGGER trg_ai_usage_limits_updated_at BEFORE UPDATE ON public.ai_usage_limits
    FOR EACH ROW EXECUTE FUNCTION public.fn_set_updated_at();

-- ============================================================================
-- TABLA 4: checkpoint_migrations
-- Control de version del checkpointer LangGraph (v0..v9)
-- Fuente: langgraph-checkpoint-postgres :: AsyncPostgresSaver.setup()
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.checkpoint_migrations (
    v INTEGER PRIMARY KEY
);

-- Seed de versiones (0-9) que LangGraph espera encontrar
INSERT INTO public.checkpoint_migrations (v)
VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)
ON CONFLICT (v) DO NOTHING;


-- ============================================================================
-- TABLA 5: checkpoints
-- Estado serializado de cada conversacion LangGraph
-- Fuente: langgraph-checkpoint-postgres :: AsyncPostgresSaver.setup()
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.checkpoints (
    thread_id TEXT NOT NULL,
    checkpoint_ns TEXT NOT NULL DEFAULT '',
    checkpoint_id TEXT NOT NULL,
    parent_checkpoint_id TEXT,
    type TEXT,
    checkpoint JSONB NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}',
    PRIMARY KEY (thread_id, checkpoint_ns, checkpoint_id)
);

CREATE INDEX IF NOT EXISTS checkpoints_thread_id_idx
    ON public.checkpoints(thread_id);


-- ============================================================================
-- TABLA 6: checkpoint_blobs
-- Datos binarios de canales del grafo (estados serializados)
-- Fuente: langgraph-checkpoint-postgres :: AsyncPostgresSaver.setup()
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.checkpoint_blobs (
    thread_id TEXT NOT NULL,
    checkpoint_ns TEXT NOT NULL DEFAULT '',
    channel TEXT NOT NULL,
    version TEXT NOT NULL,
    type TEXT NOT NULL,
    blob BYTEA,
    PRIMARY KEY (thread_id, checkpoint_ns, channel, version)
);

CREATE INDEX IF NOT EXISTS checkpoint_blobs_thread_id_idx
    ON public.checkpoint_blobs(thread_id);


-- ============================================================================
-- TABLA 7: checkpoint_writes
-- Writes pendientes entre nodos del grafo LangGraph
-- Fuente: langgraph-checkpoint-postgres :: AsyncPostgresSaver.setup()
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.checkpoint_writes (
    thread_id TEXT NOT NULL,
    checkpoint_ns TEXT NOT NULL DEFAULT '',
    checkpoint_id TEXT NOT NULL,
    task_id TEXT NOT NULL,
    idx INTEGER NOT NULL,
    channel TEXT NOT NULL,
    type TEXT,
    blob BYTEA NOT NULL,
    task_path TEXT NOT NULL DEFAULT '',
    PRIMARY KEY (thread_id, checkpoint_ns, checkpoint_id, task_id, idx)
);

CREATE INDEX IF NOT EXISTS checkpoint_writes_thread_id_idx
    ON public.checkpoint_writes(thread_id);


-- ============================================================================
-- FIN
-- ============================================================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '=== 02b-seed-agente.sql completado ===';
    RAISE NOTICE 'Tablas creadas (IF NOT EXISTS):';
    RAISE NOTICE '  1. public.chat_messages';
    RAISE NOTICE '  2. public.ai_usage_log';
    RAISE NOTICE '  3. public.ai_usage_limits';
    RAISE NOTICE '  4. public.checkpoint_migrations (+ seed v0..v9)';
    RAISE NOTICE '  5. public.checkpoints';
    RAISE NOTICE '  6. public.checkpoint_blobs';
    RAISE NOTICE '  7. public.checkpoint_writes';
    RAISE NOTICE '';
END $$;
