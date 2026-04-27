-- ============================================================================
-- Migracion 042: ampliar public.ai_usage_log.operation de VARCHAR(20) a VARCHAR(40)
-- ============================================================================
-- Motivo: strings como 'short_resume_backfill' (22 chars) y
-- 'short_resume_case_backfill' (27 chars) rompen el INSERT en VARCHAR(20),
-- causando perdida silenciosa de logs de costo en el AIWorker de GDI-AgenteLANG.
-- PG17: ALTER TYPE solo para AUMENTAR longitud de VARCHAR es operacion no-lock.
-- Idempotente: verifica antes de alterar.
-- ============================================================================

BEGIN;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name   = 'ai_usage_log'
          AND column_name  = 'operation'
          AND character_maximum_length < 40
    ) THEN
        ALTER TABLE public.ai_usage_log
            ALTER COLUMN operation TYPE VARCHAR(40);
        RAISE NOTICE 'ai_usage_log.operation ampliada a VARCHAR(40)';
    ELSE
        RAISE NOTICE 'ai_usage_log.operation ya esta en VARCHAR(40)+, skip';
    END IF;
END $$;

COMMIT;
