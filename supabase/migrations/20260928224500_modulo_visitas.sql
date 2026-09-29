-- ==============================================================================
-- Archivo: supabase/migrations/20260928224500_modulo_visitas.sql
-- Proyecto: HAVEN
-- Descripción: Módulo de Visitas (Tabla, Auditoría, Vistas y RPCs)
-- ==============================================================================

-- ==============================================================================
-- 1. ESTRUCTURA DE TABLA Y RESTRICCIONES
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.visitas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vivienda_id INTEGER NOT NULL REFERENCES public.viviendas(id) ON DELETE CASCADE,
    creado_por UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE RESTRICT,
    nombre_visitante VARCHAR(100) NOT NULL,
    apellidos_visitante VARCHAR(100) NOT NULL,
    telefono_visitante VARCHAR(20),
    motivo VARCHAR(20) NOT NULL CHECK (motivo IN ('personal', 'familiar', 'proveedor', 'servicio', 'paqueteria')),
    num_acompanantes INTEGER NOT NULL DEFAULT 0 CHECK (num_acompanantes >= 0 AND num_acompanantes <= 20),
    vehiculo_placas VARCHAR(15),
    notas VARCHAR(500),
    fecha_llegada_esperada TIMESTAMPTZ NOT NULL,
    horas_vigencia INTEGER NOT NULL DEFAULT 12 CHECK (horas_vigencia >= 1 AND horas_vigencia <= 72),
    estado VARCHAR(20) NOT NULL DEFAULT 'programada' CHECK (estado IN ('programada', 'en_curso', 'finalizada', 'cancelada')),
    codigo_acceso VARCHAR(6) NOT NULL,
    codigo_usado BOOLEAN NOT NULL DEFAULT false,
    hora_entrada TIMESTAMPTZ,
    registrado_entrada_por UUID REFERENCES public.usuarios(id),
    hora_salida TIMESTAMPTZ,
    registrado_salida_por UUID REFERENCES public.usuarios(id),
    creado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Índice único condicional para evitar códigos duplicados en visitas activas
DROP INDEX IF EXISTS public.idx_codigo_visita_vigente;
CREATE UNIQUE INDEX idx_codigo_visita_vigente 
ON public.visitas (codigo_acceso) 
WHERE estado = 'programada';
-- ==============================================================================
-- 2. TABLA ESPEJO DE AUDITORÍA Y TRIGGERS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.visitas_bitacora (
    id BIGSERIAL PRIMARY KEY,
    registro_id TEXT NOT NULL,
    operacion VARCHAR(10) NOT NULL CHECK (operacion IN ('INSERT','UPDATE','DELETE')),
    datos_anteriores JSONB,
    datos_nuevos JSONB,
    modificado_por TEXT,
    modificado_en TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_visitas_bitacora_registro ON public.visitas_bitacora(registro_id);
REVOKE ALL ON public.visitas_bitacora FROM authenticated, anon, service_role;

-- Triggers de auditoría vinculados a fn_auditoria()
DROP TRIGGER IF EXISTS trg_visitas_auditoria_insert ON public.visitas;
CREATE TRIGGER trg_visitas_auditoria_insert
    AFTER INSERT ON public.visitas FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

DROP TRIGGER IF EXISTS trg_visitas_auditoria_update ON public.visitas;
CREATE TRIGGER trg_visitas_auditoria_update
    BEFORE UPDATE ON public.visitas FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

DROP TRIGGER IF EXISTS trg_visitas_auditoria_delete ON public.visitas;
CREATE TRIGGER trg_visitas_auditoria_delete
    BEFORE DELETE ON public.visitas FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();
    -- ==============================================================================
-- 3. GENERADOR DE CÓDIGOS DE ACCESO
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.fn_generar_codigo_visita() 
RETURNS VARCHAR AS $$
DECLARE
    v_caracteres VARCHAR := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; -- Sin I, 1, 0, O
    v_codigo VARCHAR := '';
    i INTEGER;
BEGIN
    FOR i IN 1..6 LOOP
        v_codigo := v_codigo || substr(v_caracteres, (random() * length(v_caracteres) + 1)::integer, 1);
    END LOOP;
    RETURN v_codigo;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- ==============================================================================
-- 4. VISTA: vw_mis_visitas (Para el residente en sesión)
-- ==============================================================================
DROP VIEW IF EXISTS public.vw_mis_visitas CASCADE;

CREATE VIEW public.vw_mis_visitas AS
SELECT 
    v.id,
    v.vivienda_id,
    viv.numero_casa,
    viv.condominio_id,
    v.creado_por,
    v.nombre_visitante,
    v.apellidos_visitante,
    v.telefono_visitante,
    v.motivo,
    v.num_acompanantes,
    v.vehiculo_placas,
    v.notas,
    v.fecha_llegada_esperada,
    v.horas_vigencia,
    (v.fecha_llegada_esperada + (v.horas_vigencia || ' hours')::interval) AS fecha_expiracion,
    CASE 
        WHEN v.estado = 'programada' AND (v.fecha_llegada_esperada + (v.horas_vigencia || ' hours')::interval) <= now() THEN 'expirada'
        ELSE v.estado 
    END AS estado_calculado,
    v.codigo_acceso,
    v.hora_entrada,
    v.hora_salida,
    v.creado_en
FROM public.visitas v
JOIN public.viviendas viv ON v.vivienda_id = viv.id
WHERE EXISTS (
    SELECT 1 FROM public.vivienda_residente vr 
    WHERE vr.vivienda_id = v.vivienda_id AND vr.usuario_id = auth.uid()
);

GRANT SELECT ON public.vw_mis_visitas TO authenticated;

-- ==============================================================================
-- 5. VISTA: vw_visitas_hoy (Para vigilancia en caseta)
-- ==============================================================================
DROP VIEW IF EXISTS public.vw_visitas_hoy CASCADE;

CREATE VIEW public.vw_visitas_hoy AS
SELECT 
    v.id, 
    viv.numero_casa, 
    viv.condominio_id, 
    v.nombre_visitante, 
    v.apellidos_visitante, 
    v.telefono_visitante, 
    v.motivo, 
    v.num_acompanantes, 
    v.vehiculo_placas, 
    v.notas,
    v.fecha_llegada_esperada, 
    v.horas_vigencia,
    CASE 
        WHEN v.estado = 'programada' AND (v.fecha_llegada_esperada + (v.horas_vigencia || ' hours')::interval) <= now() THEN 'expirada'
        ELSE v.estado 
    END AS estado_calculado,
    u.nombre || ' ' || u.apellidos AS creado_por_nombre,
    v.hora_entrada, 
    v.creado_en
FROM public.visitas v
JOIN public.viviendas viv ON v.vivienda_id = viv.id
JOIN public.usuarios u ON v.creado_por = u.id
WHERE (
    -- Es "hoy" en CDMX
    (v.fecha_llegada_esperada AT TIME ZONE 'UTC' AT TIME ZONE 'America/Mexico_City')::date = (now() AT TIME ZONE 'UTC' AT TIME ZONE 'America/Mexico_City')::date
    AND v.estado = 'programada'
    AND (v.fecha_llegada_esperada + (v.horas_vigencia || ' hours')::interval) > now()
) OR (v.estado = 'en_curso');

GRANT SELECT ON public.vw_visitas_hoy TO service_role;
-- ==============================================================================
-- 6. VISTA: vw_visitas_historico (Para Administradores)
-- ==============================================================================
DROP VIEW IF EXISTS public.vw_visitas_historico CASCADE;

CREATE VIEW public.vw_visitas_historico AS
SELECT 
    v.id, 
    viv.numero_casa, 
    viv.condominio_id,
    v.nombre_visitante, 
    v.apellidos_visitante, 
    v.motivo, 
    v.fecha_llegada_esperada,
    CASE 
        WHEN v.estado = 'programada' AND (v.fecha_llegada_esperada + (v.horas_vigencia || ' hours')::interval) <= now() THEN 'expirada'
        ELSE v.estado 
    END AS estado_calculado,
    v.hora_entrada, 
    v.hora_salida, 
    v.creado_en
FROM public.visitas v
JOIN public.viviendas viv ON v.vivienda_id = viv.id;

GRANT SELECT ON public.vw_visitas_historico TO service_role;