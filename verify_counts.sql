-- PASO 3: Verificar conteos
SELECT 'departments' AS tabla, COUNT(*) AS total FROM "100_test".departments
UNION ALL SELECT 'sectors', COUNT(*) FROM "100_test".sectors
UNION ALL SELECT 'users', COUNT(*) FROM "100_test".users
UNION ALL SELECT 'user_seals', COUNT(*) FROM "100_test".user_seals
UNION ALL SELECT 'document_types', COUNT(*) FROM "100_test".document_types
UNION ALL SELECT 'case_templates', COUNT(*) FROM "100_test".case_templates
UNION ALL SELECT 'city_seals', COUNT(*) FROM "100_test".city_seals
ORDER BY tabla;
