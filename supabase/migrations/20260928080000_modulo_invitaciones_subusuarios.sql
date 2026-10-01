-- ==============================================================================
-- Archivo: supabase/migrations/20260928080000_modulo_invitaciones_subusuarios.sql
-- Proyecto: HAVEN
-- Descripción: Módulo de Invitaciones y Sub-usuarios por Vivienda
-- ==============================================================================

-- ==============================================================================
-- 1. ESTRUCTURA DE TABLA Y RESTRICCIONES
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.invitaciones_subusuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vivienda_id INTEGER NOT NULL REFERENCES public.viviendas(id) ON DELETE CASCADE,
    creado_por UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE RESTRICT,
    email_invitado VARCHAR(255) NOT NULL,
    codigo_invitacion VARCHAR(8) NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'pendiente' 
        CHECK (estado IN ('pendiente', 'aceptada', 'rechazada', 'expirada', 'revocada')),
    usuario_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
    expira_en TIMESTAMPTZ NOT NULL DEFAULT (timezone('utc'::text, now()) + INTERVAL '24 hours'),
    respondido_en TIMESTAMPTZ,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Índice para acelerar búsquedas por vivienda y estado
CREATE INDEX IF NOT EXISTS idx_invitaciones_subusuarios_vivienda 
ON public.invitaciones_subusuarios (vivienda_id, estado);

-- Índice único condicional: no permitir códigos duplicados en invitaciones pendientes
DROP INDEX IF EXISTS public.idx_codigo_invitacion_subusuario_vigente;
CREATE UNIQUE INDEX idx_codigo_invitacion_subusuario_vigente 
ON public.invitaciones_subusuarios (codigo_invitacion) 
WHERE estado = 'pendiente';

-- ==============================================================================
-- 2. TABLA DE BITÁCORA (AUDITORÍA FORENSE)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.invitaciones_subusuarios_bitacora (
    id BIGSERIAL PRIMARY KEY,
    registro_id TEXT NOT NULL,
    operacion VARCHAR(10) NOT NULL CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE')),
    datos_anteriores JSONB,
    datos_nuevos JSONB,
    modificado_por TEXT,
    modificado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índices para optimizar búsquedas en el historial forense
CREATE INDEX IF NOT EXISTS idx_invitaciones_subusuarios_bitacora_registro 
    ON public.invitaciones_subusuarios_bitacora(registro_id);

CREATE INDEX IF NOT EXISTS idx_invitaciones_subusuarios_bitacora_fecha 
    ON public.invitaciones_subusuarios_bitacora(modificado_en);

-- Revocar accesos directos por seguridad
REVOKE ALL ON public.invitaciones_subusuarios_bitacora FROM authenticated, anon, service_role;

-- ==============================================================================
-- 3. TRIGGERS DE AUDITORÍA CONECTADOS A fn_auditoria()
-- ==============================================================================
DROP TRIGGER IF EXISTS trg_invitaciones_subusuarios_auditoria_insert ON public.invitaciones_subusuarios;
CREATE TRIGGER trg_invitaciones_subusuarios_auditoria_insert
    AFTER INSERT ON public.invitaciones_subusuarios
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

DROP TRIGGER IF EXISTS trg_invitaciones_subusuarios_auditoria_update ON public.invitaciones_subusuarios;
CREATE TRIGGER trg_invitaciones_subusuarios_auditoria_update
    BEFORE UPDATE ON public.invitaciones_subusuarios
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

DROP TRIGGER IF EXISTS trg_invitaciones_subusuarios_auditoria_delete ON public.invitaciones_subusuarios;
CREATE TRIGGER trg_invitaciones_subusuarios_auditoria_delete
    BEFORE DELETE ON public.invitaciones_subusuarios
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

    -- ==============================================================================
-- 4. FUNCIÓN GENERADORA DE CÓDIGOS DE INVITACIÓN
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.fn_generar_codigo_invitacion_subusuario()
RETURNS VARCHAR(8) AS $$
DECLARE
    v_caracteres TEXT := '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; -- Excluye caracteres ambiguos (0, O, 1, I)
    v_resultado TEXT := '';
    i INTEGER;
BEGIN
    FOR i IN 1..8 LOOP
        v_resultado := v_resultado || substr(v_caracteres, (random() * length(v_caracteres) + 1)::integer, 1);
    END LOOP;
    RETURN v_resultado;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- ==============================================================================
-- 5. VISTA DE CONSULTA: vw_invitaciones_subusuarios
-- ==============================================================================
-- Asegurar soporte de columna parentesco para compatibilidad con backend
ALTER TABLE public.invitaciones_subusuarios 
    ADD COLUMN IF NOT EXISTS parentesco VARCHAR(50) DEFAULT 'Familiar';

DROP VIEW IF EXISTS public.vw_invitaciones_subusuarios CASCADE;

CREATE VIEW public.vw_invitaciones_subusuarios AS
SELECT 
    i.id,
    i.vivienda_id,
    v.numero_casa,
    v.condominio_id,
    c.nombre AS condominio_nombre,
    i.creado_por AS titular_id,
    TRIM(u_titular.nombre || ' ' || COALESCE(u_titular.apellidos, '')) AS titular_nombre,
    i.usuario_id AS invitado_id,
    i.email_invitado AS invitado_email,
    i.codigo_invitacion AS codigo,
    i.codigo_invitacion,
    COALESCE(i.parentesco, 'Familiar') AS parentesco,
    i.estado,
    i.expira_en,
    i.creado_en
FROM public.invitaciones_subusuarios i
JOIN public.viviendas v ON v.id = i.vivienda_id
LEFT JOIN public.condominios c ON c.id = v.condominio_id
LEFT JOIN public.usuarios u_titular ON u_titular.id = i.creado_por
LEFT JOIN public.usuarios u_invitado ON u_invitado.id = i.usuario_id;