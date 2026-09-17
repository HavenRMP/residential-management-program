-- ==============================================================================
-- Archivo: supabase/migrations/20260916120000_residentes_sin_vivienda.sql
-- Proyecto: HAVEN
-- Descripción: Vista para consultar residentes activos (rol_id = 2) sin vivienda
--              asignada en la tabla relacional vivienda_residente.
-- ==============================================================================

-- 1. CREACIÓN DE LA VISTA
DROP VIEW IF EXISTS public.vw_residentes_sin_vivienda CASCADE;

CREATE VIEW public.vw_residentes_sin_vivienda AS
SELECT 
    u.id,
    u.rol_id,
    u.rol_nombre,
    u.email,
    u.nombre,
    u.apellidos,
    u.telefono,
    u.condominio_id,
    u.activo,
    u.debe_cambiar_password,
    u.creado_en
FROM public.vw_usuarios u
WHERE u.rol_id = 2
  AND u.activo = true
  AND NOT EXISTS (
      SELECT 1 
      FROM public.vivienda_residente vr 
      WHERE vr.usuario_id = u.id
  );

-- 2. PERMISOS Y RECARGA EN POSTGREST
GRANT SELECT ON public.vw_residentes_sin_vivienda TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';