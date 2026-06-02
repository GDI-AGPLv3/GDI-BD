-- ============================================================================
-- GDI LATAM - CREAR USUARIO "Testing Automatizado" + API Key
-- ============================================================================
-- Descripcion: Crea usuario de testing con API key para pruebas automaticas
-- Version: 1.2.0
--
-- USO: Ejecutar en CADA ambiente (DEV, ARIES, ARG)
--      Requiere que el schema del municipio ya exista con datos seed
--      Cambiar las 5 variables del bloque DO segun ambiente
--
-- API KEYS POR AMBIENTE (generadas con secrets.token_hex(16)):
--   DEV:   <YOUR_API_KEY_PLAIN_HEX>
--   ARIES: <YOUR_API_KEY_PLAIN_HEX>
--   ARG:   <YOUR_API_KEY_PLAIN_HEX>
--
-- IDs fijos (mismos en TODOS los ambientes):
--   User ID:    a1000000-0000-0000-0000-0000000000ff
--   API Key ID: c1000000-0000-0000-0000-0000000000ff
--   Sector:     Innovacion PRIV (51000000-0000-0000-0000-000000000003)
--   Rol:        Usuario General (a0000000-0000-0000-0000-000000000001)
--   Sello:      Innovador (city_seal 1)
--
-- EJECUTADO:
--   DEV (2026-03-04): OK - curl 200 verificado
-- ============================================================================

DO $$
DECLARE
    -- >>> CAMBIAR ESTOS 5 VALORES POR AMBIENTE <<<
    v_schema_name     TEXT := '100_test';
    v_municipality_id UUID := 'b5500000-0000-0000-0000-000000000100';
    v_api_key_plain   TEXT := '<YOUR_API_KEY_PLAIN_HEX>';
    v_api_key_hash    TEXT := '<YOUR_API_KEY_HASH_SHA256>';
    v_api_key_prefix  TEXT := 'gdi-test-dev';

    -- IDs fijos (NO cambiar)
    v_user_id         UUID := 'a1000000-0000-0000-0000-0000000000ff';
    v_api_key_id      UUID := 'c1000000-0000-0000-0000-0000000000ff';
    v_sector_id       UUID := '51000000-0000-0000-0000-000000000003'; -- Innovacion PRIV
    v_role_general    UUID := 'a0000000-0000-0000-0000-000000000001'; -- Usuario General
    v_seal_innovador  INT  := 1; -- city_seal "Innovador"

    -- Interno
    v_seal_col TEXT;
BEGIN
    -- ======================================================================
    -- PASO 1: Crear usuario en schema del municipio
    -- ======================================================================
    EXECUTE format(
        'INSERT INTO %I.users (id, auth_id, email, full_name, sector_id, estado, created_at)
         VALUES ($1, $2, $3, $4, $5, 1, NOW())
         ON CONFLICT (id) DO UPDATE SET
           full_name = EXCLUDED.full_name,
           email = EXCLUDED.email,
           sector_id = EXCLUDED.sector_id',
        v_schema_name
    ) USING
        v_user_id,
        'testing-auto|' || v_schema_name,
        'testing-auto@example.com',
        'Testing Automatizado',
        v_sector_id;

    RAISE NOTICE '[1/5] Usuario "Testing Automatizado" creado en %.users', v_schema_name;

    -- ======================================================================
    -- PASO 2: Asignar rol Usuario General
    -- ======================================================================
    EXECUTE format(
        'INSERT INTO %I.user_roles (id, user_id, role_id, created_at)
         VALUES (gen_random_uuid(), $1, $2, NOW())
         ON CONFLICT DO NOTHING',
        v_schema_name
    ) USING v_user_id, v_role_general;

    RAISE NOTICE '[2/5] Rol "Usuario General" asignado';

    -- ======================================================================
    -- PASO 3: Asignar sello "Innovador" (permite firmar docs)
    -- Detecta columna: city_seal_id (BD existente) o seal_id (BD nueva)
    -- ======================================================================
    SELECT column_name INTO v_seal_col
    FROM information_schema.columns
    WHERE table_schema = v_schema_name
      AND table_name = 'user_seals'
      AND column_name IN ('seal_id', 'city_seal_id')
    ORDER BY column_name DESC
    LIMIT 1;

    EXECUTE format(
        'INSERT INTO %I.user_seals (id, user_id, %I, created_at)
         VALUES (gen_random_uuid(), $1, $2, NOW())
         ON CONFLICT DO NOTHING',
        v_schema_name, v_seal_col
    ) USING v_user_id, v_seal_innovador;

    RAISE NOTICE '[3/5] Sello "Innovador" asignado (col: %)', v_seal_col;

    -- ======================================================================
    -- PASO 4: Crear API Key en public.api_keys
    -- ======================================================================
    INSERT INTO public.api_keys (
        id, api_key_hash, api_key_prefix, municipality_id,
        name, description, is_active, rate_limit_per_minute, created_by, created_at
    ) VALUES (
        v_api_key_id,
        v_api_key_hash,
        v_api_key_prefix,
        v_municipality_id,
        'Testing Automatizado',
        'API Key para tests automaticos (/test-dev, /test-aries, /test-arg)',
        true,
        200,
        'claude-code',
        NOW()
    )
    ON CONFLICT (id) DO UPDATE SET
        api_key_hash = EXCLUDED.api_key_hash,
        api_key_prefix = EXCLUDED.api_key_prefix,
        municipality_id = EXCLUDED.municipality_id,
        name = EXCLUDED.name,
        is_active = true;

    RAISE NOTICE '[4/5] API Key creada (prefix: %)', v_api_key_prefix;

    -- ======================================================================
    -- PASO 5: Asociar usuario a la API Key
    -- ======================================================================
    INSERT INTO public.api_key_users (id, api_key_id, user_id, schema_name, created_at)
    VALUES (gen_random_uuid(), v_api_key_id, v_user_id, v_schema_name, NOW())
    ON CONFLICT DO NOTHING;

    RAISE NOTICE '[5/5] Usuario asociado a API Key';

    -- ======================================================================
    -- RESUMEN
    -- ======================================================================
    RAISE NOTICE '';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '  TESTING AUTOMATIZADO - CONFIGURADO';
    RAISE NOTICE '============================================================';
    RAISE NOTICE '  Schema:      %', v_schema_name;
    RAISE NOTICE '  User ID:     %', v_user_id;
    RAISE NOTICE '  Nombre:      Testing Automatizado';
    RAISE NOTICE '  Sector:      Innovacion (PRIV)';
    RAISE NOTICE '  Rol:         Usuario General';
    RAISE NOTICE '  Sello:       Innovador';
    RAISE NOTICE '  API Key:     %', v_api_key_plain;
    RAISE NOTICE '  API Prefix:  %', v_api_key_prefix;
    RAISE NOTICE '============================================================';
    RAISE NOTICE '  curl headers:';
    RAISE NOTICE '    -H "X-API-Key: %"', v_api_key_plain;
    RAISE NOTICE '    -H "X-User-ID: %"', v_user_id;
    RAISE NOTICE '============================================================';
END $$;

-- ============================================================================
-- VERIFICACION
-- ============================================================================
-- SELECT id, full_name, email, sector_id FROM "{SCHEMA}".users WHERE id = 'a1000000-0000-0000-0000-0000000000ff';
-- SELECT id, api_key_prefix, name, is_active FROM public.api_keys WHERE id = 'c1000000-0000-0000-0000-0000000000ff';
-- SELECT * FROM public.api_key_users WHERE api_key_id = 'c1000000-0000-0000-0000-0000000000ff';

-- ============================================================================
-- VALORES POR AMBIENTE (copiar al bloque DECLARE):
-- ============================================================================
--
-- DEV (<your-postgres-app>, tunnel 5433):
--   v_schema_name     := '100_test';
--   v_municipality_id := 'b5500000-0000-0000-0000-000000000100';
--   v_api_key_plain   := '<YOUR_API_KEY_PLAIN_HEX>';
--   v_api_key_hash    := '<YOUR_API_KEY_HASH_SHA256>';
--   v_api_key_prefix  := 'gdi-test-dev';
--
-- ARIES (<your-postgres-app>, tunnel 5434):
--   v_schema_name     := '100_test';
--   v_municipality_id := (SELECT id FROM public.municipalities WHERE schema_name = '100_test');
--   v_api_key_plain   := '<YOUR_API_KEY_PLAIN_HEX>';
--   v_api_key_hash    := '<YOUR_API_KEY_HASH_SHA256>';
--   v_api_key_prefix  := 'gdi-test-ari';
--
-- ARG (<your-postgres-app>, tunnel 5435):
--   v_schema_name     := '100_test';
--   v_municipality_id := (SELECT id FROM public.municipalities WHERE schema_name = '100_test');
--   v_api_key_plain   := '<YOUR_API_KEY_PLAIN_HEX>';
--   v_api_key_hash    := '<YOUR_API_KEY_HASH_SHA256>';
--   v_api_key_prefix  := 'gdi-test-arg';
--
-- ============================================================================
