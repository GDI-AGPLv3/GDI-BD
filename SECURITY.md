# Politica de Seguridad

## Reportar Vulnerabilidades

Si descubres una vulnerabilidad de seguridad en GDI-BD, por favor reportala de forma responsable.

**NO** abras un issue publico para reportar vulnerabilidades de seguridad.

### Como Reportar

Envia un email a: **security@gdilatam.com**

Incluye:
- Descripcion de la vulnerabilidad
- Pasos para reproducirla
- Impacto potencial
- Sugerencia de solucion (si la tienes)

### Que Esperar

- Confirmacion de recepcion dentro de 48 horas
- Evaluacion inicial dentro de 5 dias habiles
- Actualizacion sobre el progreso de la solucion

### Alcance

Esta politica cubre:
- Scripts SQL del schema publico (`sql/`)
- Estructura de tablas y constraints
- Permisos y accesos definidos en el schema

### Fuera de Alcance

- Instancias de produccion de GDI (contactar al operador correspondiente)
- Vulnerabilidades en PostgreSQL (reportar al equipo de PostgreSQL)

## Versiones Soportadas

| Version | Soporte |
|---------|---------|
| 4.x     | Si      |
| < 4.0   | No      |

## Reconocimiento

Agradecemos a quienes reportan vulnerabilidades de forma responsable. Con tu permiso, incluiremos tu nombre en los agradecimientos del proyecto.
