# GDI Latam - PostgreSQL 17 + pgvector
# Deploy: fly deploy
# Extensiones: vector (pgvector), unaccent, pg_trgm

FROM pgvector/pgvector:pg17

# pgvector ya viene pre-instalado en esta imagen
# unaccent y pg_trgm vienen en postgresql-contrib (incluido en imagen base)

# Init scripts - se ejecutan en orden alfabetico en el primer boot
# (solo cuando PGDATA esta vacio)
COPY sql/01-install.sql        /docker-entrypoint-initdb.d/01-install.sql
COPY sql/02-seed-global.sql    /docker-entrypoint-initdb.d/02-seed-global.sql
COPY sql/02b-seed-agente.sql   /docker-entrypoint-initdb.d/03-seed-agente.sql
COPY sql/04-seed-demo.sql      /docker-entrypoint-initdb.d/04-seed-demo.sql
