# Contribuir a GDI-BD

Gracias por tu interes en contribuir al schema de base de datos de GDI Latam.

## Como Contribuir

### Reportar Issues

1. Verifica que el issue no exista ya en [Issues](https://github.com/GDI-APGLv3/GDI-BD/issues)
2. Crea un nuevo issue con:
   - Descripcion clara del problema o mejora
   - Version de PostgreSQL que usas
   - Pasos para reproducir (si es un bug)

### Enviar Pull Requests

1. Haz fork del repositorio
2. Crea una rama descriptiva: `feature/nueva-tabla` o `fix/constraint-faltante`
3. Realiza tus cambios en la rama
4. Asegurate de que los scripts SQL ejecutan sin errores en PostgreSQL 17+
5. Envia el Pull Request con:
   - Descripcion de los cambios
   - Motivo de la modificacion
   - Impacto en tablas existentes

### Lineamientos para SQL

- Usar comillas dobles para identificadores: `"public"."tabla"`
- Incluir `COMMENT ON TABLE/COLUMN` para documentacion
- Usar UUIDs (`gen_random_uuid()`) como primary keys
- Incluir `created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()` en todas las tablas
- Mantener compatibilidad con PostgreSQL 17+

### Lineamientos Generales

- Mantener el codigo SQL limpio y documentado
- No incluir datos sensibles, credenciales o URLs de produccion
- Seguir el estilo existente del proyecto
- Un commit por cambio logico

## Codigo de Conducta

Se espera que todos los contribuidores mantengan un ambiente respetuoso y profesional.

## Licencia

Al contribuir, aceptas que tu contribucion se publique bajo la licencia [AGPL-v3](LICENSE).
