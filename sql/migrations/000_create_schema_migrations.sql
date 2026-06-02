-- Tabla de control de migraciones. Correr UNA VEZ en cada BD nueva.
CREATE TABLE IF NOT EXISTS public.schema_migrations (
    version      TEXT PRIMARY KEY,
    name         TEXT NOT NULL,
    applied_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    applied_by   TEXT,
    checksum     TEXT
);

-- Historial de migraciones ya aplicadas (024-056)
INSERT INTO public.schema_migrations (version, name, applied_at) VALUES
('024', 'initial_archive_batch', '2026-04-21 00:00:00+00'),
('025', 'initial_archive_batch', '2026-04-21 00:00:00+00'),
('026', 'initial_archive_batch', '2026-04-21 00:00:00+00'),
('027', 'initial_archive_batch', '2026-04-21 00:00:00+00'),
('028', 'initial_archive_batch', '2026-04-21 00:00:00+00'),
('029', 'initial_archive_batch', '2026-04-21 00:00:00+00'),
('030', 'initial_archive_batch', '2026-04-21 00:00:00+00'),
('031', 'initial_archive_batch', '2026-04-21 00:00:00+00'),
('032', 'initial_archive_batch', '2026-04-21 00:00:00+00'),
('033', 'initial_archive_batch', '2026-04-21 00:00:00+00'),
('034', 'initial_archive_batch', '2026-04-21 00:00:00+00'),
('035', 'initial_archive_batch', '2026-04-21 00:00:00+00'),
('036', 'initial_archive_batch', '2026-04-21 00:00:00+00'),
('037', 'initial_archive_batch', '2026-04-21 00:00:00+00'),
('038', 'initial_archive_batch', '2026-04-21 00:00:00+00'),
('039', 'initial_archive_batch', '2026-04-21 00:00:00+00'),
('040', 'initial_archive_batch', '2026-04-21 00:00:00+00'),
('041', 'initial_archive_batch', '2026-04-21 00:00:00+00'),
('042a', 'ai_usage_log_operation_varchar40', '2026-05-05 00:00:00+00'),
('042b', 'case_responsibles_favorites', '2026-05-19 00:00:00+00'),
('043', 'rag_query_log', '2026-05-01 00:00:00+00'),
('044', 'document_chunks_hybrid_search', '2026-05-01 00:00:00+00'),
('045', 'firma_audit_log', '2026-05-01 00:00:00+00'),
('047', 'document_types_signature_policy_rename', '2026-05-01 00:00:00+00'),
('048a', 'digital_signature_sessions', '2026-05-01 00:00:00+00'),
('048b', 'global_document_types_signature_policy', '2026-05-01 00:00:00+00'),
('050', 'document_signers_firma_digital', '2026-05-01 00:00:00+00'),
('051', 'document_signers_indices_firma_digital', '2026-05-01 00:00:00+00'),
('052', 'firma_audit_log_session_id_varchar', '2026-05-01 00:00:00+00'),
('053', 'movement_type_responsible_add_remove', '2026-05-28 00:00:00+00'),
('054', 'case_responsibles_table', '2026-05-19 00:00:00+00'),
('055', 'case_favorites_table', '2026-05-19 00:00:00+00'),
('056', 'catalog_proposals', '2026-05-01 00:00:00+00')
ON CONFLICT (version) DO NOTHING;
