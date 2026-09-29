-- ==============================================================================
-- ARCHIVO: supabase/migrations/20260917000000_rol_vigilancia.sql
-- PROYECTO: HAVEN
-- DESCRIPCIÓN: Asegurar roles Vigilancia y Mantenimiento en catálogo base.
-- ==============================================================================

-- 1. CATÁLOGO BASE DE ROLES (Garantizar id 3 y 4 de forma idempotente)
INSERT INTO public.roles (id, nombre, descripcion) VALUES
  (3, 'Vigilancia', 'Control de accesos y registro de visitas'),
  (4, 'Mantenimiento', 'Atención y resolución de reportes e incidencias')
ON CONFLICT (id) DO UPDATE 
SET nombre = EXCLUDED.nombre,
    descripcion = EXCLUDED.descripcion;

SELECT setval('public.roles_id_seq', GREATEST((SELECT MAX(id) FROM public.roles), 4));