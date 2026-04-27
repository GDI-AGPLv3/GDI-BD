-- ============================================================================
-- GDI LATAM - SEED DATA GLOBAL (Multi-Tenant)
-- ============================================================================
-- Descripcion: Datos iniciales para tablas globales
-- Version: 4.0.0 (Multi-Tenant)
-- PostgreSQL: 17.0+
--
-- CONTENIDO:
--   - 4 Roles
--   - 65 Global Document Types (61 publicos + 2 internos: PV, CAEX + MEMO + NOTA + IFRLM)
--   - 30 Global Case Templates
--   - Document Display States (6)
--   - 3 Global Registry Families (ARQ, LUM, ORD)
--
-- NOTA: ranks y seals son per-tenant (ver 03-create-municipio.sql)
-- ============================================================================

-- ============================================================================
-- ROLES (4)
-- ============================================================================

INSERT INTO "public"."roles" ("role_id", "role_name", "description") VALUES
('a0000000-0000-0000-0000-000000000001'::uuid, 'Usuario General', 'Usuario basico del sistema'),
('a0000000-0000-0000-0000-000000000002'::uuid, 'Funcionario', 'Funcionario con permisos operativos'),
('a0000000-0000-0000-0000-000000000003'::uuid, 'Administrador', 'Administrador con todos los permisos'),
('a0000000-0000-0000-0000-000000000004'::uuid, 'Sistema TEST', 'Usuario del sistema para numeracion (no editable, no eliminable)');

-- ============================================================================
-- GLOBAL DOCUMENT TYPES (65)
-- ============================================================================

INSERT INTO "public"."global_document_types"
("id", "name", "acronym", "description", "signature_type", "is_visible", "is_active", "type", "trust") VALUES
('d0000000-0000-0000-0000-000000000001'::uuid, 'Informe', 'IF', 'Informe tecnico o administrativo', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000002'::uuid, 'Nota', 'NOTA', 'Nota oficial con destinatarios TO/CC/BCC y tracking de apertura', 'required', true, true, 'NOTA', true),
('d0000000-0000-0000-0000-000000000003'::uuid, 'Providencia', 'PROV', 'Providencia administrativa', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000004'::uuid, 'Acta', 'ACT', 'Acta de reunion, evento, accion, etc.', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000005'::uuid, 'Anexo', 'ANEXO', 'Anexo documental', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000006'::uuid, 'Anexo Grafico Importado', 'ANIMP', 'Anexo grafico importado', 'required', true, true, 'Importado', true),
('d0000000-0000-0000-0000-000000000007'::uuid, 'Documento de Capacitacion', 'CAP', 'Documento para capacitacion', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000008'::uuid, 'Informe Grafico Importado', 'IFGRA', 'Informe grafico importado desde archivo externo', 'required', true, true, 'Importado', true),
('d0000000-0000-0000-0000-000000000009'::uuid, 'Constancia', 'CONST', 'Constancia administrativa', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-00000000000a'::uuid, 'Comunicacion Servicio', 'COMSE', 'Comunicacion de servicio', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-00000000000b'::uuid, 'Minuta', 'MIN', 'Minuta de reunion o acuerdo', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-00000000000c'::uuid, 'Carta Documento', 'CDOC', 'Carta documento', 'required', true, true, 'Importado', false),
('d0000000-0000-0000-0000-00000000000d'::uuid, 'Instructivo', 'INST', 'Instructivo administrativo', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-00000000000e'::uuid, 'Solicitud Generica', 'SOLG', 'Solicitud generica', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-00000000000f'::uuid, 'Decreto', 'DECRE', 'Decreto municipal', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000010'::uuid, 'Resolucion', 'RESOL', 'Resolucion administrativa', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000011'::uuid, 'Ordenanza', 'ORD', 'Ordenanza municipal', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000012'::uuid, 'Disposicion', 'DISPO', 'Disposicion administrativa', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000013'::uuid, 'Dictamen', 'DICTA', 'Dictamen legal o tecnico', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000014'::uuid, 'Convenio', 'CONV', 'Convenio o acuerdo interinstitucional', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000015'::uuid, 'Oficio Judicial', 'OFJUD', 'Oficio judicial', 'required', true, true, 'Importado', false),
('d0000000-0000-0000-0000-000000000016'::uuid, 'Contrato', 'CONT', 'Contrato administrativo', 'required', true, true, 'Importado', true),
('d0000000-0000-0000-0000-000000000017'::uuid, 'Poder / Mandato', 'PODER', 'Poder o mandato legal', 'required', true, true, 'Importado', true),
('d0000000-0000-0000-0000-000000000018'::uuid, 'Acuerdo de Partes', 'ACPAR', 'Acuerdo de partes', 'required', true, true, 'Importado', true),
('d0000000-0000-0000-0000-000000000019'::uuid, 'Escritura Publica', 'ESCR', 'Escritura publica notarial', 'required', true, true, 'Importado', true),
('d0000000-0000-0000-0000-00000000001a'::uuid, 'Cedula de Notificacion', 'CEDNT', 'Cedula de notificacion', 'required', true, true, 'Importado', false),
('d0000000-0000-0000-0000-00000000001b'::uuid, 'Proyecto de Ordenanza', 'PROORD', 'Proyecto de ordenanza', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-00000000001c'::uuid, 'Proyecto de Decreto', 'PRODEC', 'Proyecto de decreto', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-00000000001d'::uuid, 'Proyecto de Resolucion', 'PRORES', 'Proyecto de resolucion', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-00000000001e'::uuid, 'Proyecto Disposicion', 'PRODIS', 'Proyecto de disposicion', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-00000000001f'::uuid, 'Acta de Inspeccion', 'AINSP', 'Acta de inspeccion', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000020'::uuid, 'Permiso General', 'PERMI', 'Permiso general', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000021'::uuid, 'Permiso de Obra', 'POBRA', 'Permiso de obra', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000022'::uuid, 'Cert. Inspeccion Final', 'CIF', 'Certificado de inspeccion final', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000023'::uuid, 'Cert. Habilit. Comercio', 'HCOM', 'Certificado de habilitacion de comercio', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000024'::uuid, 'Certificado Parcelario', 'CPARC', 'Certificado parcelario', 'required', true, true, 'Importado', true),
('d0000000-0000-0000-0000-000000000025'::uuid, 'Plano', 'PLANO', 'Plano catastral o arquitectonico', 'required', true, true, 'Importado', false),
('d0000000-0000-0000-0000-000000000026'::uuid, 'Titulo de Propiedad', 'TITPR', 'Titulo de propiedad', 'required', true, true, 'Importado', false),
('d0000000-0000-0000-0000-000000000027'::uuid, 'Cedula Catastral', 'CECAT', 'Cedula catastral', 'required', true, true, 'Importado', false),
('d0000000-0000-0000-0000-000000000028'::uuid, 'Contrato de Alquiler', 'CALQ', 'Contrato de alquiler', 'required', true, true, 'Importado', false),
('d0000000-0000-0000-0000-000000000029'::uuid, 'Permiso de Demolicion', 'PDEM', 'Permiso de demolicion', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-00000000002a'::uuid, 'Permiso de Uso de Suelo', 'PUSO', 'Permiso de uso de suelo', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-00000000002b'::uuid, 'Cert. Aptitud Ambiental', 'CAPTA', 'Certificado de aptitud ambiental', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-00000000002c'::uuid, 'Informe de Factibilidad', 'IFACT', 'Informe de factibilidad', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-00000000002d'::uuid, 'Visado de Plano', 'VISPL', 'Visado de plano', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-00000000002e'::uuid, 'Cert. de Zonificacion', 'CZON', 'Certificado de zonificacion', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-00000000002f'::uuid, 'Boleta Deuda Obras', 'BDOBR', 'Boleta de deuda de obras', 'required', true, true, 'Importado', true),
('d0000000-0000-0000-0000-000000000030'::uuid, 'Acta Paralizacion Obra', 'APOBR', 'Acta de paralizacion de obra', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000031'::uuid, 'Memoria Descriptiva', 'MEMDE', 'Memoria descriptiva de proyecto', 'required', true, true, 'Importado', false),
('d0000000-0000-0000-0000-000000000032'::uuid, 'Cert. Numeracion Domic.', 'CNDOM', 'Certificado de numeracion domiciliaria', 'required', true, true, 'Importado', true),
('d0000000-0000-0000-0000-000000000033'::uuid, 'Inf. Linea Edificacion', 'ILINE', 'Informe de linea de edificacion', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000034'::uuid, 'Perm. Cartel Publicit.', 'PCARD', 'Permiso de cartel publicitario', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000035'::uuid, 'Hab. Espectaculo Publico', 'HESP', 'Habilitacion de espectaculo publico', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000036'::uuid, 'Cert. Deuda Cero Obras', 'CD0OB', 'Certificado de deuda cero en obras', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000037'::uuid, 'Constancia de Pago', 'PAGO', 'Constancia de pago', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000038'::uuid, 'Orden de Compra', 'OC', 'Orden de compra', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-000000000039'::uuid, 'Pre-Pliego', 'PREPL', 'Pre-pliego para compras y contrataciones', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-00000000003a'::uuid, 'Pliego Definitivo', 'PLIEG', 'Pliego definitivo para licitaciones', 'required', true, true, 'HTML', true),
('d0000000-0000-0000-0000-00000000003b'::uuid, 'Factura / Remito', 'FACT', 'Factura o remito comercial', 'required', true, true, 'Importado', false),
('d0000000-0000-0000-0000-00000000003e'::uuid, 'Ordenanza HCD', 'PLORD', 'Ordenanza sancionada por el Honorable Concejo Deliberante', 'required', true, true, 'Importado', true),
('d0000000-0000-0000-0000-00000000003f'::uuid, 'Resolucion HCD', 'PLRES', 'Resolucion emitida por el Honorable Concejo Deliberante', 'required', true, true, 'Importado', true),
('d0000000-0000-0000-0000-000000000040'::uuid, 'Comunicacion HCD', 'PLCOM', 'Comunicacion oficial del Honorable Concejo Deliberante', 'required', true, true, 'Importado', true),
('d0000000-0000-0000-0000-000000000041'::uuid, 'Decreto HCD', 'PLDEC', 'Decreto del Honorable Concejo Deliberante (archivado/desarchivado de expedientes, licencias de concejales, decretos de comisiones internas).', 'required', true, true, 'Importado', true),
-- Tipos internos del sistema (no visibles, no activos)
('d0000000-0000-0000-0000-00000000003c'::uuid, 'Pase', 'PV', 'Pase de expediente (Uso exclusivo modulo EE)', 'required', false, false, 'HTML', true),
('d0000000-0000-0000-0000-00000000003d'::uuid, 'Caratula', 'CAEX', 'Caratula de expediente (Uso exclusivo modulo EE)', 'required', false, false, 'HTML', true),
-- Tipo interno del sistema: activo pero no visible (fallback numeracion / tests)
('d0000000-0000-0000-0000-000000000042'::uuid, 'Testing', 'TST', 'Documento generado automaticamente cuando una firma falla (Uso exclusivo del sistema)', 'required', false, true, 'HTML', true),
-- Memos (persona-a-persona)
('d0000000-0000-0000-0000-000000000070'::uuid, 'Memo', 'MEMO', 'Memorandum persona-a-persona con destinatarios TO/CC/BCC', 'required', true, true, 'MEMO', true),
-- Informes RLM (generados on-demand desde un legajo)
('d0000000-0000-0000-0000-000000000080'::uuid, 'Informe RLM', 'IFRLM', 'Informe de Registro Legajo Multiproposito (generado on-demand desde un legajo RLM)', 'required', true, true, 'HTML', true);

-- Tipos con numeracion especial por tipo+departamento
UPDATE "public"."global_document_types"
SET "special_numbering" = true
WHERE "acronym" IN ('DECRE', 'RESOL', 'ORD', 'DISPO');

-- ============================================================================
-- GLOBAL CASE TEMPLATES (30)
-- ============================================================================

INSERT INTO "public"."global_case_templates"
("id", "type_name", "acronym", "description", "is_active") VALUES
('b0000000-0000-0000-0000-000000000001'::uuid, 'Varios', 'EEVAR', 'Tramite general para asuntos diversos que no encuadran en una categoria especifica del municipio', true),
('b0000000-0000-0000-0000-000000000002'::uuid, 'Licitacion Publica', 'LICPUB', 'Proceso de licitacion publica para la adquisicion de bienes, servicios u obras con publicacion en boletin oficial', true),
('b0000000-0000-0000-0000-000000000003'::uuid, 'Solicitudes RRHH', 'SRRHH', 'Solicitudes internas dirigidas al area de Recursos Humanos, incluyendo pedidos de licencia, certificaciones y cambios de situacion', true),
('b0000000-0000-0000-0000-000000000004'::uuid, 'Capacitacion', 'ECAPA', 'Gestion de programas de capacitacion y formacion continua para agentes y funcionarios municipales', true),
('b0000000-0000-0000-0000-000000000005'::uuid, 'Testing Automatizado', 'TEST', 'Expediente reservado para pruebas automatizadas del equipo de TESTERS del sistema de gestion documental', true),
('b0000000-0000-0000-0000-000000000006'::uuid, 'Habilitacion Comercial', 'HABI', 'Tramite de habilitacion de locales comerciales, incluyendo verificacion de requisitos edilicios, zonificacion y documentacion fiscal', true),
('b0000000-0000-0000-0000-000000000007'::uuid, 'Permiso Industrial', 'HIND', 'Tramite de permiso para instalacion o funcionamiento de establecimientos industriales con evaluacion de impacto ambiental', true),
('b0000000-0000-0000-0000-000000000008'::uuid, 'Compras y Contrataciones', 'COMP', 'Gestion integral de compras directas, contrataciones menores y procesos de adquisicion de bienes y servicios municipales', true),
('b0000000-0000-0000-0000-000000000009'::uuid, 'Demanda Judicial', 'DEM', 'Seguimiento de demandas judiciales en las que el municipio actua como parte actora o demandada ante la justicia', true),
('b0000000-0000-0000-0000-00000000000a'::uuid, 'Recursos Humanos', 'RRHH', 'Gestion administrativa del personal municipal, incluyendo altas, bajas, legajos, sanciones y movimientos de planta', true),
('b0000000-0000-0000-0000-00000000000b'::uuid, 'Obra Publica', 'OBPUB', 'Planificacion, licitacion, ejecucion y control de obras publicas municipales de infraestructura y equipamiento urbano', true),
('b0000000-0000-0000-0000-00000000000c'::uuid, 'Reclamo Vecinal', 'RECVE', 'Registro y seguimiento de reclamos presentados por vecinos sobre servicios publicos, infraestructura o convivencia barrial', true),
('b0000000-0000-0000-0000-00000000000d'::uuid, 'Subsidio Social', 'SUBSO', 'Tramitacion de subsidios, ayudas economicas y prestaciones sociales destinadas a personas en situacion de vulnerabilidad', true),
('b0000000-0000-0000-0000-00000000000e'::uuid, 'Licencia de Conducir', 'LICED', 'Tramite de emision, renovacion o recategorizacion de licencias de conducir otorgadas por el municipio', true),
('b0000000-0000-0000-0000-00000000000f'::uuid, 'Infracciones de Transito', 'INFTR', 'Gestion de actas de infraccion de transito, descargos, resoluciones sancionatorias y cobro de multas viales', true),
('b0000000-0000-0000-0000-000000000010'::uuid, 'Medio Ambiente', 'MAMBI', 'Gestion de tramites medioambientales, incluyendo evaluaciones de impacto, denuncias por contaminacion y permisos ambientales', true),
('b0000000-0000-0000-0000-000000000011'::uuid, 'Catastro y Tierras', 'CATIE', 'Tramites catastrales, regularizacion de tierras fiscales, subdivisiones, unificaciones y actualizacion de datos parcelarios', true),
('b0000000-0000-0000-0000-000000000012'::uuid, 'Presupuesto Municipal', 'PRESU', 'Elaboracion, aprobacion, ejecucion y control del presupuesto municipal y modificaciones de partidas presupuestarias', true),
('b0000000-0000-0000-0000-000000000013'::uuid, 'Convenio Marco', 'CONVM', 'Negociacion, suscripcion y seguimiento de convenios marco con organismos publicos, privados o de la sociedad civil', true),
('b0000000-0000-0000-0000-000000000014'::uuid, 'Sumario Administrativo', 'SUMAD', 'Instruccion de sumarios administrativos por faltas disciplinarias del personal municipal, con garantia de debido proceso', true),
('b0000000-0000-0000-0000-000000000015'::uuid, 'Defensa del Consumidor', 'DECON', 'Atencion de denuncias y mediaciones en materia de defensa del consumidor y usuarios ante comercios del municipio', true),
('b0000000-0000-0000-0000-000000000016'::uuid, 'Espectaculo Publico', 'ESPEC', 'Autorizacion y control de espectaculos publicos, eventos masivos y actividades recreativas en jurisdiccion municipal', true),
('b0000000-0000-0000-0000-000000000017'::uuid, 'Bromatologia', 'BROMA', 'Inspecciones bromatologicas a establecimientos elaboradores y expendedores de alimentos, control sanitario y habilitaciones', true),
('b0000000-0000-0000-0000-000000000018'::uuid, 'Transporte Publico', 'TPUBL', 'Regulacion, habilitacion y fiscalizacion del transporte publico de pasajeros y servicios de movilidad urbana municipal', true),
('b0000000-0000-0000-0000-000000000019'::uuid, 'Zoonosis', 'ZOONO', 'Control de zoonosis, campanas de vacunacion y castracion, captura de animales sueltos y denuncias por maltrato animal', true),
('b0000000-0000-0000-0000-00000000001a'::uuid, 'Patrimonio Cultural', 'PATCU', 'Proteccion, catalogacion y puesta en valor del patrimonio historico, arquitectonico y cultural del municipio', true),
('b0000000-0000-0000-0000-00000000001b'::uuid, 'Cementerio Municipal', 'CEMEN', 'Gestion administrativa del cementerio municipal, incluyendo concesiones de parcelas, inhumaciones y mantenimiento general', true),
('b0000000-0000-0000-0000-00000000001c'::uuid, 'Desarrollo Urbano', 'DESUR', 'Planificacion del desarrollo urbano, revision del codigo de ordenamiento territorial y proyectos de mejora del espacio publico', true),
('b0000000-0000-0000-0000-00000000001d'::uuid, 'Mesa de Entrada General', 'MEGEN', 'Recepcion, registro y derivacion de toda documentacion ingresada por mesa de entrada a las areas correspondientes', true),
('b0000000-0000-0000-0000-00000000001e'::uuid, 'Seguridad Ciudadana', 'SEGCI', 'Coordinacion de politicas de seguridad ciudadana, monitoreo de camaras, prevencion del delito y articulacion con fuerzas de seguridad', true);

-- ============================================================================
-- DOCUMENT DISPLAY STATES (6)
-- ============================================================================

INSERT INTO "public"."document_display_states"
("id", "display_state_code", "display_state_name", "description") VALUES
(1, 'DRAFT', 'Borrador', 'Documento en estado borrador'),
(2, 'PENDING_SIGN', 'Pendiente de Firma', 'Documento enviado a firmar'),
(3, 'SIGNED', 'Firmado', 'Documento firmado'),
(4, 'REJECTED', 'Rechazado', 'Documento rechazado'),
(5, 'CANCELLED', 'Cancelado', 'Documento cancelado'),
(6, 'NUMBERED', 'Numerado', 'Documento oficial numerado');

-- Reset sequence
SELECT setval('document_display_states_id_seq', 6);

-- ============================================================================
-- GLOBAL REGISTRY FAMILIES (8)
-- ============================================================================

INSERT INTO "public"."global_registry_families"
  ("id", "code", "name", "description", "default_data_schema", "default_states")
VALUES
(
  'f0000000-0000-0000-0000-000000000001',
  'ARQ',
  'Registro de Arquitectura y Obras Particulares',
  'Legajos de obras, habilitaciones y permisos de construccion',
  '{"direccion":{"type":"text","label":"Direccion","required":true},"tipo_obra":{"type":"select","label":"Tipo de Obra","options":["Nueva","Ampliacion","Refaccion","Demolicion"],"required":true}}'::jsonb,
  '["Activo","En Inspeccion","Aprobado","Rechazado","Suspendido","Archivado"]'::jsonb
),
(
  'f0000000-0000-0000-0000-000000000002',
  'LUM',
  'Registro de Luminarias y Alumbrado Publico',
  'Legajos de instalaciones de alumbrado, reclamos y mantenimiento',
  '{"ubicacion":{"type":"text","label":"Ubicacion","required":true},"tipo_luminaria":{"type":"select","label":"Tipo de Luminaria","options":["LED","Sodio","Halogena","Otro"],"required":true}}'::jsonb,
  '["Activo","En Reparacion","Fuera de Servicio","Reemplazado","Archivado"]'::jsonb
),
(
  'f0000000-0000-0000-0000-000000000003',
  'NORMA',
  'Normativa HCD',
  'Registro de normativa emitida por el Honorable Concejo Deliberante',
  '{"numero_norma":{"type":"text","label":"Numero de Norma","required":true,"has_document":false,"has_expiration":false,"has_verification":false},"tipo_norma":{"type":"select","label":"Tipo de Norma","options":["Ordenanza","Decreto","Resolucion","Comunicacion","Declaracion","Ordenanza Fiscal","Ordenanza Tributaria"],"required":true,"has_expiration":false,"has_verification":false},"fecha_sancion":{"type":"date","label":"Fecha de Sancion","required":true,"has_document":false,"has_expiration":false,"has_verification":false},"materia":{"type":"select","label":"Materia","options":["Recursos Humanos","Salud Publica","Tierras","Tributario","Nomenclatura","Seguridad","Institucional","Transporte","Presupuesto","Seguridad Social","Medio Ambiente","Obras Publicas","Educacion","Cultura","Otro"],"required":false,"has_document":false,"has_expiration":false,"has_verification":false},"numero_expediente":{"type":"text","label":"Expediente HCD","required":false,"has_expiration":false,"has_verification":false},"sesion_tipo":{"type":"select","label":"Tipo de Sesion","options":["Ordinaria","Extraordinaria","Especial","Asamblea","Preparatoria","Prorroga"],"required":false,"has_expiration":false,"has_verification":false},"sesion_fecha":{"type":"date","label":"Fecha de Sesion","required":false,"has_document":false,"has_expiration":false,"has_verification":false},"sesion_numero":{"type":"text","label":"Numero de Sesion","required":false,"has_expiration":false,"has_verification":false}}'::jsonb,
  '["Vigente","Derogada","Modificada","Suspendida","En Revision","Archivada"]'::jsonb
),
(
  '31e17040-f954-4a51-b2cc-8a96f16efadd',
  'PER',
  'Registro de Personal Municipal',
  'Legajos del personal del municipio',
  '{"cuil":{"type":"text","label":"CUIL","required":true},"cargo":{"type":"text","label":"Cargo","required":true},"legajo":{"type":"text","label":"Nro Legajo","required":true},"sector":{"type":"text","label":"Sector","required":false}}'::jsonb,
  '["Activo","Licencia","Baja"]'::jsonb
),
(
  '3cdb2798-7aee-4260-8f9d-f51bee036b27',
  'PROV',
  'Registro de Proveedores',
  'Legajos de proveedores del municipio',
  '{"cuit":{"type":"text","label":"CUIT","required":true},"rubro":{"type":"text","label":"Rubro","required":true},"contacto":{"type":"text","label":"Contacto","required":false},"razon_social":{"type":"text","label":"Razon Social","required":true}}'::jsonb,
  '["Activo","Suspendido","Inhabilitado"]'::jsonb
),
(
  '556c714d-a9e5-48cd-bd15-603289a21d21',
  'COM',
  'Registro de Comercios y Habilitaciones',
  'Legajos de comercios habilitados por el municipio',
  '{"cuit":{"type":"text","label":"CUIT","required":true},"rubro":{"type":"select","label":"Rubro","options":["Gastronomia","Indumentaria","Servicios","Industria","Otro"],"required":true},"direccion":{"type":"text","label":"Direccion","required":true},"razon_social":{"type":"text","label":"Razon Social","required":true}}'::jsonb,
  '["Activo","En Tramite","Suspendido","Clausurado","Baja"]'::jsonb
),
(
  '5fb751b7-eea3-4efb-afec-3208dfe447fa',
  'INM',
  'Registro de Inmuebles Municipales',
  'Legajos de inmuebles propiedad del municipio',
  '{"uso":{"type":"select","label":"Uso","options":["Administrativo","Educativo","Salud","Deportivo","Cultural","Otro"],"required":true},"direccion":{"type":"text","label":"Direccion","required":true},"superficie":{"type":"number","label":"Superficie (m2)","required":false},"nomenclatura":{"type":"text","label":"Nomenclatura Catastral","required":true}}'::jsonb,
  '["Activo","Transferido","Baja"]'::jsonb
),
(
  '85949e4c-b755-47c5-b023-99f69cb305ae',
  'VEH',
  'Registro de Flota Municipal',
  'Legajos de vehiculos de la flota del municipio',
  '{"anio":{"type":"number","label":"Anio","required":true},"tipo":{"type":"select","label":"Tipo","options":["Auto","Camioneta","Camion","Maquinaria","Moto"],"required":true},"marca":{"type":"text","label":"Marca","required":true},"modelo":{"type":"text","label":"Modelo","required":true},"dominio":{"type":"text","label":"Dominio","required":true}}'::jsonb,
  '["Operativo","En Reparacion","Baja"]'::jsonb
);

-- ============================================================================
-- FIN SEED DATA GLOBAL
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'SEED DATA GLOBAL COMPLETADO';
    RAISE NOTICE '============================================================';
    RAISE NOTICE 'Roles: 3 (Usuario General, Funcionario, Administrador)';
    RAISE NOTICE 'Global Document Types: 68 (publicos + 4 HCD + internos PV/CAEX/TST + MEMO + NOTA + IFRLM)';
    RAISE NOTICE 'Global Case Templates: 30';
    RAISE NOTICE 'Document Display States: 6';
    RAISE NOTICE 'Global Registry Families: 8 (ARQ, LUM, NORMA, PER, PROV, COM, INM, VEH)';
    RAISE NOTICE '============================================================';
END $$;
