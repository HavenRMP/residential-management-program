-- ==============================================================================
-- Archivo: supabase/migrations/20261001000000_vw_visitas_proximas.sql
-- Proyecto: HAVEN
-- Descripción: Elimina vw_visitas_hoy y crea vw_visitas_proximas basada en 
--              ventana móvil (24h) conservando el contrato completo de DTOs.
-- ==============================================================================

-- ==============================================================================
-- 1. ELIMINAR VISTAS ANTERIORES
-- ==============================================================================
DROP VIEW IF EXISTS public.vw_visitas_hoy CASCADE;
DROP VIEW IF EXISTS public.vw_visitas_proximas CASCADE;
-- ==============================================================================
-- 2. VISTA: vw_visitas_proximas (Ventana móvil 24h con contrato completo de DTO)
-- ==============================================================================
CREATE VIEW public.vw_visitas_proximas AS
SELECT 
    v.id, 
    v.vivienda_id,
    viv.numero_casa, 
    viv.condominio_id, 
    v.creado_por,
    TRIM(u.nombre || ' ' || COALESCE(u.apellidos, '')) AS creado_por_nombre,
    v.nombre_visitante, 
    v.apellidos_visitante, 
    v.telefono_visitante, 
    v.motivo, 
    v.num_acompanantes, 
    v.vehiculo_placas, 
    v.notas,
    v.fecha_llegada_esperada, 
    v.horas_vigencia,
    -- Expiración calculada (doble aliasing para DTO y clientes legacy)
    (v.fecha_llegada_esperada + (v.horas_vigencia || ' hours')::interval) AS vigencia_hasta,
    (v.fecha_llegada_esperada + (v.horas_vigencia || ' hours')::interval) AS fecha_expiracion,
    -- Estado calculado en tiempo real (doble aliasing)
    CASE 
        WHEN v.estado = 'programada' AND (v.fecha_llegada_esperada + (v.horas_vigencia || ' hours')::interval) <= now() THEN 'expirada'
        ELSE v.estado 
    END AS estado,
    CASE 
        WHEN v.estado = 'programada' AND (v.fecha_llegada_esperada + (v.horas_vigencia || ' hours')::interval) <= now() THEN 'expirada'
        ELSE v.estado 
    END AS estado_calculado,
    -- Código de acceso (doble aliasing)
    v.codigo_acceso AS codigo,
    v.codigo_acceso,
    v.hora_entrada, 
    v.hora_salida,
    v.creado_en
FROM public.visitas v
JOIN public.viviendas viv ON v.vivienda_id = viv.id
LEFT JOIN public.usuarios u ON v.creado_por = u.id
WHERE (
    v.estado = 'programada'
    -- Ventana móvil: visitas cuya llegada sea dentro de las próximas 24 horas
    AND v.fecha_llegada_esperada <= (now() + interval '24 hours')
    -- Y que sigan vigentes (no hayan caducado en tiempo absoluto)
    AND (v.fecha_llegada_esperada + (v.horas_vigencia || ' hours')::interval) > now()
) OR (v.estado = 'en_curso');