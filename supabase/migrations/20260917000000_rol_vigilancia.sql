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
-- ==============================================================================
-- 2. VISTA PARA CASETA DE VIGILANCIA: vw_viviendas_con_residentes
-- Permite al personal de seguridad consultar viviendas activas y sus residentes
-- ==============================================================================
DROP VIEW IF EXISTS public.vw_viviendas_con_residentes CASCADE;

CREATE VIEW public.vw_viviendas_con_residentes AS
SELECT 
    v.id,
    v.numero_casa,
    v.tipo,
    v.condominio_id,
    c.nombre AS condominio_nombre,
    v.activo,
    COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'id', u.id,
                'nombre', u.nombre,
                'apellidos', u.apellidos,
                'telefono', u.telefono,
                'email', u.email
            )
        ) FILTER (WHERE u.id IS NOT NULL),
        '[]'::jsonb
    ) AS residentes,
    COUNT(vr.usuario_id)::INTEGER AS total_residentes,
    (COUNT(vr.usuario_id) > 0) AS esta_ocupada,
    v.creado_en
FROM public.viviendas v
JOIN public.condominios c ON c.id = v.condominio_id
LEFT JOIN public.vivienda_residente vr ON vr.vivienda_id = v.id
LEFT JOIN public.usuarios u ON u.id = vr.usuario_id AND u.activo = true
WHERE v.activo = true
GROUP BY v.id, v.numero_casa, v.tipo, v.condominio_id, c.nombre, v.activo, v.creado_en;

-- Permisos de lectura para autenticados y backend
GRANT SELECT ON public.vw_viviendas_con_residentes TO authenticated, service_role;

-- ==============================================================================
-- 3. INCREMENTO DE VERSIÓN (SemVer Minor)
-- ==============================================================================
UPDATE public.version 
SET 
    numero_version = CASE 
        WHEN numero_version ~ '^[0-9]+\.[0-9]+(\.[0-9]+)?$' THEN
            split_part(numero_version, '.', 1) || '.' || 
            ((split_part(numero_version, '.', 2)::integer) + 1)::text || 
            CASE 
                WHEN split_part(numero_version, '.', 3) <> '' THEN '.' || split_part(numero_version, '.', 3) 
                ELSE '' 
            END
        WHEN numero_version ~ '^[0-9]+$' THEN
            ((numero_version::integer) + 1)::text
        ELSE numero_version || '.1'
    END,
    updated_at = now();

NOTIFY pgrst, 'reload schema';