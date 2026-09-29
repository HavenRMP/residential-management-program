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

-- ==============================================================================
-- 7. STORED PROCEDURE: alta_visita
-- ==============================================================================
DROP FUNCTION IF EXISTS public.alta_visita(UUID, INTEGER, VARCHAR, VARCHAR, VARCHAR, VARCHAR, INTEGER, VARCHAR, VARCHAR, TIMESTAMPTZ, INTEGER);

CREATE OR REPLACE FUNCTION public.alta_visita(
    p_actor_id UUID, 
    p_vivienda_id INTEGER, 
    p_nombre_visitante VARCHAR, 
    p_apellidos_visitante VARCHAR, 
    p_telefono_visitante VARCHAR, 
    p_motivo VARCHAR, 
    p_num_acompanantes INTEGER, 
    p_vehiculo_placas VARCHAR, 
    p_notas VARCHAR, 
    p_fecha_llegada_esperada TIMESTAMPTZ, 
    p_horas_vigencia INTEGER DEFAULT 12
) 
RETURNS JSONB 
SECURITY DEFINER 
SET search_path = public 
LANGUAGE plpgsql AS $$
DECLARE
    v_codigo VARCHAR;
    v_visita_id UUID;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.viviendas WHERE id = p_vivienda_id AND activo = true) THEN
        RAISE EXCEPTION USING ERRCODE = 'VI009', MESSAGE = 'La vivienda no existe o está inactiva.';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM public.vivienda_residente WHERE vivienda_id = p_vivienda_id AND usuario_id = p_actor_id) THEN
        RAISE EXCEPTION USING ERRCODE = 'VI002', MESSAGE = 'El actor no pertenece a esta vivienda.';
    END IF;
    
    LOOP
        BEGIN
            v_codigo := public.fn_generar_codigo_visita();
            INSERT INTO public.visitas (
                vivienda_id, creado_por, nombre_visitante, apellidos_visitante, telefono_visitante, motivo, 
                num_acompanantes, vehiculo_placas, notas, fecha_llegada_esperada, horas_vigencia, codigo_acceso
            ) VALUES (
                p_vivienda_id, p_actor_id, p_nombre_visitante, p_apellidos_visitante, p_telefono_visitante, p_motivo,
                COALESCE(p_num_acompanantes, 0), p_vehiculo_placas, p_notas, p_fecha_llegada_esperada, p_horas_vigencia, v_codigo
            ) RETURNING id INTO v_visita_id;
            EXIT; -- Éxito, sale del loop
        EXCEPTION WHEN unique_violation THEN
            -- Ignora y vuelve a intentar generar código si hay colisión (23505)
        END;
    END LOOP;
    
    RETURN jsonb_build_object('id', v_visita_id, 'codigo_acceso', v_codigo);
END;
$$;
-- ==============================================================================
-- 8. STORED PROCEDURE: cambio_visita
-- ==============================================================================
DROP FUNCTION IF EXISTS public.cambio_visita(UUID, UUID, VARCHAR, VARCHAR, VARCHAR, VARCHAR, INTEGER, VARCHAR, VARCHAR, TIMESTAMPTZ, INTEGER);

CREATE OR REPLACE FUNCTION public.cambio_visita(
    p_id UUID, 
    p_actor_id UUID, 
    p_nombre_visitante VARCHAR DEFAULT NULL, 
    p_apellidos_visitante VARCHAR DEFAULT NULL, 
    p_telefono_visitante VARCHAR DEFAULT NULL, 
    p_motivo VARCHAR DEFAULT NULL, 
    p_num_acompanantes INTEGER DEFAULT NULL, 
    p_vehiculo_placas VARCHAR DEFAULT NULL, 
    p_notas VARCHAR DEFAULT NULL, 
    p_fecha_llegada_esperada TIMESTAMPTZ DEFAULT NULL, 
    p_horas_vigencia INTEGER DEFAULT NULL
) 
RETURNS BOOLEAN 
SECURITY DEFINER 
SET search_path = public 
LANGUAGE plpgsql AS $$
DECLARE
    v_visita RECORD;
BEGIN
    SELECT * INTO v_visita FROM public.visitas WHERE id = p_id;
    IF NOT FOUND THEN 
        RAISE EXCEPTION USING ERRCODE = 'VI001', MESSAGE = 'La visita no existe.'; 
    END IF;

    IF v_visita.creado_por != p_actor_id THEN 
        RAISE EXCEPTION USING ERRCODE = 'VI002', MESSAGE = 'Solo el creador puede modificar la visita.'; 
    END IF;

    IF v_visita.estado != 'programada' THEN 
        RAISE EXCEPTION USING ERRCODE = 'VI003', MESSAGE = 'Solo se pueden modificar visitas programadas.'; 
    END IF;

    UPDATE public.visitas SET
        nombre_visitante = COALESCE(p_nombre_visitante, nombre_visitante),
        apellidos_visitante = COALESCE(p_apellidos_visitante, apellidos_visitante),
        telefono_visitante = COALESCE(p_telefono_visitante, telefono_visitante),
        motivo = COALESCE(p_motivo, motivo),
        num_acompanantes = COALESCE(p_num_acompanantes, num_acompanantes),
        vehiculo_placas = COALESCE(p_vehiculo_placas, vehiculo_placas),
        notas = COALESCE(p_notas, notas),
        fecha_llegada_esperada = COALESCE(p_fecha_llegada_esperada, fecha_llegada_esperada),
        horas_vigencia = COALESCE(p_horas_vigencia, horas_vigencia)
    WHERE id = p_id;

    RETURN true;
END;
$$;
-- ==============================================================================
-- 9. STORED PROCEDURE: cancelar_visita
-- ==============================================================================
DROP FUNCTION IF EXISTS public.cancelar_visita(UUID, UUID);

CREATE OR REPLACE FUNCTION public.cancelar_visita(
    p_id UUID, 
    p_actor_id UUID
) 
RETURNS BOOLEAN 
SECURITY DEFINER 
SET search_path = public 
LANGUAGE plpgsql AS $$
DECLARE
    v_visita RECORD;
BEGIN
    SELECT * INTO v_visita FROM public.visitas WHERE id = p_id;
    IF NOT FOUND THEN 
        RAISE EXCEPTION USING ERRCODE = 'VI001', MESSAGE = 'La visita no existe.'; 
    END IF;

    IF v_visita.creado_por != p_actor_id THEN 
        RAISE EXCEPTION USING ERRCODE = 'VI002', MESSAGE = 'Solo el creador puede cancelar la visita.'; 
    END IF;

    IF v_visita.estado != 'programada' THEN 
        RAISE EXCEPTION USING ERRCODE = 'VI003', MESSAGE = 'El estado actual no permite cancelación.'; 
    END IF;

    UPDATE public.visitas 
    SET estado = 'cancelada' 
    WHERE id = p_id;

    RETURN true;
END;
$$;
-- ==============================================================================
-- 10. STORED PROCEDURE: validar_codigo_visita (Caseta / Vigilancia)
-- ==============================================================================
DROP FUNCTION IF EXISTS public.validar_codigo_visita(VARCHAR);

CREATE OR REPLACE FUNCTION public.validar_codigo_visita(
    p_codigo VARCHAR(6)
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql AS $$
DECLARE
    v_visita RECORD;
    v_resultado JSONB;
BEGIN
    SELECT 
        v.*,
        viv.numero_casa,
        u.nombre || ' ' || u.apellidos AS creado_por_nombre,
        (v.fecha_llegada_esperada + (v.horas_vigencia || ' hours')::interval) AS fecha_expiracion
    INTO v_visita
    FROM public.visitas v
    JOIN public.viviendas viv ON v.vivienda_id = viv.id
    JOIN public.usuarios u ON v.creado_por = u.id
    WHERE v.codigo_acceso = UPPER(TRIM(p_codigo))
    ORDER BY v.creado_en DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION USING ERRCODE = 'VI001', MESSAGE = 'Código de acceso no encontrado o no existe.';
    END IF;

    IF v_visita.estado != 'programada' THEN
        RAISE EXCEPTION USING ERRCODE = 'VI003', MESSAGE = 'La visita no se encuentra en estado programada (estado actual: ' || v_visita.estado || ').';
    END IF;

    IF v_visita.fecha_expiracion <= now() THEN
        RAISE EXCEPTION USING ERRCODE = 'VI004', MESSAGE = 'El código de acceso ha expirado.';
    END IF;

    SELECT jsonb_build_object(
        'id', v_visita.id,
        'vivienda_id', v_visita.vivienda_id,
        'numero_casa', v_visita.numero_casa,
        'nombre_visitante', v_visita.nombre_visitante,
        'apellidos_visitante', v_visita.apellidos_visitante,
        'telefono_visitante', v_visita.telefono_visitante,
        'motivo', v_visita.motivo,
        'num_acompanantes', v_visita.num_acompanantes,
        'vehiculo_placas', v_visita.vehiculo_placas,
        'notas', v_visita.notas,
        'fecha_llegada_esperada', v_visita.fecha_llegada_esperada,
        'fecha_expiracion', v_visita.fecha_expiracion,
        'creado_por_nombre', v_visita.creado_por_nombre,
        'estado', v_visita.estado
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$$;
-- ==============================================================================
-- 11. STORED PROCEDURE: registrar_entrada_visita (Caseta / Vigilancia)
-- ==============================================================================
DROP FUNCTION IF EXISTS public.registrar_entrada_visita(UUID, UUID);

CREATE OR REPLACE FUNCTION public.registrar_entrada_visita(
    p_visita_id UUID, 
    p_actor_id UUID
) 
RETURNS JSONB 
SECURITY DEFINER 
SET search_path = public 
LANGUAGE plpgsql AS $$
DECLARE
    v_visita RECORD;
    v_actor_condominio UUID;
BEGIN
    SELECT condominio_id INTO v_actor_condominio FROM public.usuarios WHERE id = p_actor_id;
    SELECT v.*, viv.condominio_id INTO v_visita 
    FROM public.visitas v 
    JOIN public.viviendas viv ON v.vivienda_id = viv.id 
    WHERE v.id = p_visita_id;

    IF NOT FOUND THEN 
        RAISE EXCEPTION USING ERRCODE = 'VI001', MESSAGE = 'La visita no existe.'; 
    END IF;

    IF v_visita.condominio_id != v_actor_condominio THEN 
        RAISE EXCEPTION USING ERRCODE = 'VI002', MESSAGE = 'Sin permisos en este condominio.'; 
    END IF;

    IF v_visita.estado != 'programada' THEN 
        RAISE EXCEPTION USING ERRCODE = 'VI003', MESSAGE = 'La visita no está programada.'; 
    END IF;

    IF (v_visita.fecha_llegada_esperada + (v_visita.horas_vigencia || ' hours')::interval) <= now() THEN 
        RAISE EXCEPTION USING ERRCODE = 'VI005', MESSAGE = 'Visita expirada.'; 
    END IF;

    UPDATE public.visitas 
    SET estado = 'en_curso', 
        codigo_usado = true, 
        hora_entrada = now(), 
        registrado_entrada_por = p_actor_id
    WHERE id = p_visita_id 
    RETURNING * INTO v_visita;

    RETURN to_jsonb(v_visita);
END;
$$;
-- ==============================================================================
-- 12. STORED PROCEDURE: registrar_salida_visita (Caseta / Vigilancia)
-- ==============================================================================
DROP FUNCTION IF EXISTS public.registrar_salida_visita(UUID, UUID);

CREATE OR REPLACE FUNCTION public.registrar_salida_visita(
    p_visita_id UUID, 
    p_actor_id UUID
) 
RETURNS JSONB 
SECURITY DEFINER 
SET search_path = public 
LANGUAGE plpgsql AS $$
DECLARE
    v_visita RECORD;
    v_actor_condominio UUID;
BEGIN
    SELECT condominio_id INTO v_actor_condominio FROM public.usuarios WHERE id = p_actor_id;
    SELECT v.*, viv.condominio_id INTO v_visita 
    FROM public.visitas v 
    JOIN public.viviendas viv ON v.vivienda_id = viv.id 
    WHERE v.id = p_visita_id;

    IF NOT FOUND THEN 
        RAISE EXCEPTION USING ERRCODE = 'VI001', MESSAGE = 'La visita no existe.'; 
    END IF;

    IF v_visita.condominio_id != v_actor_condominio THEN 
        RAISE EXCEPTION USING ERRCODE = 'VI002', MESSAGE = 'Sin permisos en este condominio.'; 
    END IF;

    IF v_visita.estado != 'en_curso' THEN 
        RAISE EXCEPTION USING ERRCODE = 'VI007', MESSAGE = 'No se puede registrar salida sin entrada previa (o ya finalizó).'; 
    END IF;

    UPDATE public.visitas 
    SET estado = 'finalizada', 
        hora_salida = now(), 
        registrado_salida_por = p_actor_id
    WHERE id = p_visita_id 
    RETURNING * INTO v_visita;

    RETURN to_jsonb(v_visita);
END;
$$;