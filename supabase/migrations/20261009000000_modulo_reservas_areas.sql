-- ==============================================================================
-- Archivo: supabase/migrations/20261009000000_modulo_reservas_areas.sql
-- Proyecto: HAVEN
-- Descripción: Módulo completo de Áreas Comunes, Reservas y Bloqueos Administrativos
--              (Tablas base, auditoría forense, vistas de contrato y RPCs).
-- ==============================================================================

-- ==============================================================================
-- 1. ZONA HORARIA EN CONDOMINIOS
-- ==============================================================================
ALTER TABLE public.condominios 
    ADD COLUMN IF NOT EXISTS zona_horaria VARCHAR(50) NOT NULL DEFAULT 'America/Mexico_City';

-- ==============================================================================
-- 2. TABLAS BASE: AREAS_COMUNES Y RESERVAS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.areas_comunes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    condominio_id UUID NOT NULL REFERENCES public.condominios(id) ON DELETE RESTRICT,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    hora_apertura TIME NOT NULL DEFAULT '08:00:00',
    hora_cierre TIME NOT NULL DEFAULT '22:00:00',
    activo BOOLEAN NOT NULL DEFAULT true,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),

    CONSTRAINT chk_areas_horario_valido CHECK (hora_apertura < hora_cierre)
);

CREATE INDEX IF NOT EXISTS idx_areas_comunes_condominio ON public.areas_comunes(condominio_id);
CREATE INDEX IF NOT EXISTS idx_areas_comunes_activo ON public.areas_comunes(activo);

CREATE TABLE IF NOT EXISTS public.reservas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    condominio_id UUID NOT NULL REFERENCES public.condominios(id) ON DELETE RESTRICT,
    area_id UUID NOT NULL REFERENCES public.areas_comunes(id) ON DELETE RESTRICT,
    tipo VARCHAR(20) NOT NULL DEFAULT 'RESERVA' CHECK (tipo IN ('RESERVA', 'BLOQUEO')),
    estado VARCHAR(30) NOT NULL DEFAULT 'PENDIENTE_TITULAR' 
        CHECK (estado IN (
            'PENDIENTE_TITULAR',
            'PENDIENTE_ADMIN',
            'APROBADA',
            'RECHAZADA',
            'CANCELADA',
            'EXPIRADA',
            'EXPIRADA_SIN_CONFIRMAR',
            'NO_UTILIZADA'
        )),
    inicio TIMESTAMPTZ NOT NULL,
    fin TIMESTAMPTZ NOT NULL,
    titular_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
    vivienda_id INTEGER REFERENCES public.viviendas(id) ON DELETE SET NULL,
    solicitante_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE RESTRICT,
    aprobador_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
    motivo TEXT,
    confirmada_en TIMESTAMPTZ,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),

    CONSTRAINT chk_reservas_fechas_coherentes CHECK (inicio < fin)
);

CREATE INDEX IF NOT EXISTS idx_reservas_condominio ON public.reservas(condominio_id);
CREATE INDEX IF NOT EXISTS idx_reservas_area ON public.reservas(area_id);
CREATE INDEX IF NOT EXISTS idx_reservas_intervalo ON public.reservas(area_id, inicio, fin);
CREATE INDEX IF NOT EXISTS idx_reservas_titular ON public.reservas(titular_id);
CREATE INDEX IF NOT EXISTS idx_reservas_solicitante ON public.reservas(solicitante_id);
CREATE INDEX IF NOT EXISTS idx_reservas_estado ON public.reservas(estado);

-- ==============================================================================
-- 3. AUDITORÍA FORENSE Y TRIGGERS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.areas_comunes_bitacora (
    id BIGSERIAL PRIMARY KEY,
    registro_id TEXT NOT NULL,
    operacion VARCHAR(10) NOT NULL CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE')),
    datos_anteriores JSONB,
    datos_nuevos JSONB,
    modificado_por TEXT,
    modificado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_areas_bitacora_registro ON public.areas_comunes_bitacora(registro_id);
REVOKE ALL ON public.areas_comunes_bitacora FROM authenticated, anon, service_role;

DROP TRIGGER IF EXISTS trg_areas_comunes_auditoria_insert ON public.areas_comunes;
CREATE TRIGGER trg_areas_comunes_auditoria_insert
    AFTER INSERT ON public.areas_comunes FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

DROP TRIGGER IF EXISTS trg_areas_comunes_auditoria_update ON public.areas_comunes;
CREATE TRIGGER trg_areas_comunes_auditoria_update
    BEFORE UPDATE ON public.areas_comunes FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

DROP TRIGGER IF EXISTS trg_areas_comunes_auditoria_delete ON public.areas_comunes;
CREATE TRIGGER trg_areas_comunes_auditoria_delete
    BEFORE DELETE ON public.areas_comunes FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

CREATE TABLE IF NOT EXISTS public.reservas_bitacora (
    id BIGSERIAL PRIMARY KEY,
    registro_id TEXT NOT NULL,
    operacion VARCHAR(10) NOT NULL CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE')),
    datos_anteriores JSONB,
    datos_nuevos JSONB,
    modificado_por TEXT,
    modificado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reservas_bitacora_registro ON public.reservas_bitacora(registro_id);
REVOKE ALL ON public.reservas_bitacora FROM authenticated, anon, service_role;

DROP TRIGGER IF EXISTS trg_reservas_auditoria_insert ON public.reservas;
CREATE TRIGGER trg_reservas_auditoria_insert
    AFTER INSERT ON public.reservas FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

DROP TRIGGER IF EXISTS trg_reservas_auditoria_update ON public.reservas;
CREATE TRIGGER trg_reservas_auditoria_update
    BEFORE UPDATE ON public.reservas FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

DROP TRIGGER IF EXISTS trg_reservas_auditoria_delete ON public.reservas;
CREATE TRIGGER trg_reservas_auditoria_delete
    BEFORE DELETE ON public.reservas FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

-- ==============================================================================
-- 4. VISTAS DE CONSULTA
-- ==============================================================================

-- A) vw_areas_comunes
DROP VIEW IF EXISTS public.vw_areas_comunes CASCADE;
CREATE VIEW public.vw_areas_comunes AS
SELECT 
    a.id,
    a.condominio_id,
    c.nombre AS condominio_nombre,
    c.zona_horaria,
    a.nombre,
    a.descripcion,
    a.hora_apertura,
    a.hora_cierre,
    a.activo,
    a.creado_en
FROM public.areas_comunes a
JOIN public.condominios c ON c.id = a.condominio_id;

-- B) vw_calendario_reservas (Residentes)
DROP VIEW IF EXISTS public.vw_calendario_reservas CASCADE;
CREATE VIEW public.vw_calendario_reservas AS
SELECT 
    r.id,
    r.area_id,
    a.nombre AS area_nombre,
    r.condominio_id,
    r.inicio,
    r.fin,
    r.tipo,
    r.estado,
    u_tit.nombre AS titular_nombre,
    u_tit.apellidos AS titular_apellidos,
    v.numero_casa,
    CASE WHEN r.tipo = 'BLOQUEO' THEN r.motivo ELSE NULL END AS motivo
FROM public.reservas r
JOIN public.areas_comunes a ON a.id = r.area_id
LEFT JOIN public.usuarios u_tit ON u_tit.id = r.titular_id
LEFT JOIN public.viviendas v ON v.id = r.vivienda_id
WHERE r.estado NOT IN ('RECHAZADA', 'CANCELADA', 'EXPIRADA', 'EXPIRADA_SIN_CONFIRMAR');

-- C) vw_calendario_reservas_limitado (Vigilancia / Mantenimiento)
DROP VIEW IF EXISTS public.vw_calendario_reservas_limitado CASCADE;
CREATE VIEW public.vw_calendario_reservas_limitado AS
SELECT * 
FROM public.vw_calendario_reservas
WHERE estado = 'APROBADA' OR tipo = 'BLOQUEO';

-- D) vw_reservas_usuario (Mis reservas)
DROP VIEW IF EXISTS public.vw_reservas_usuario CASCADE;
CREATE VIEW public.vw_reservas_usuario AS
SELECT 
    r.id,
    r.area_id,
    a.nombre AS area_nombre,
    r.condominio_id,
    r.tipo,
    r.estado,
    r.inicio,
    r.fin,
    r.titular_id,
    u_tit.nombre AS titular_nombre,
    u_tit.apellidos AS titular_apellidos,
    r.vivienda_id,
    v.numero_casa,
    r.solicitante_id,
    u_sol.nombre AS solicitante_nombre,
    u_sol.apellidos AS solicitante_apellidos,
    r.aprobador_id,
    u_apr.nombre AS aprobador_nombre,
    u_apr.apellidos AS aprobador_apellidos,
    r.motivo,
    r.confirmada_en,
    r.creado_en,
    r.actualizado_en
FROM public.reservas r
JOIN public.areas_comunes a ON a.id = r.area_id
LEFT JOIN public.usuarios u_tit ON u_tit.id = r.titular_id
LEFT JOIN public.viviendas v ON v.id = r.vivienda_id
JOIN public.usuarios u_sol ON u_sol.id = r.solicitante_id
LEFT JOIN public.usuarios u_apr ON u_apr.id = r.aprobador_id;

-- E) vw_reservas_pendientes_titular
DROP VIEW IF EXISTS public.vw_reservas_pendientes_titular CASCADE;
CREATE VIEW public.vw_reservas_pendientes_titular AS
SELECT 
    r.id,
    r.area_id,
    a.nombre AS area_nombre,
    r.condominio_id,
    r.inicio,
    r.fin,
    r.titular_id,
    r.vivienda_id,
    v.numero_casa,
    r.solicitante_id,
    u_sol.nombre AS solicitante_nombre,
    u_sol.apellidos AS solicitante_apellidos,
    u_sol.email AS solicitante_email,
    vs.parentesco,
    r.creado_en
FROM public.reservas r
JOIN public.areas_comunes a ON a.id = r.area_id
JOIN public.usuarios u_sol ON u_sol.id = r.solicitante_id
LEFT JOIN public.viviendas v ON v.id = r.vivienda_id
LEFT JOIN public.vivienda_subusuarios vs ON vs.vivienda_id = r.vivienda_id AND vs.usuario_id = r.solicitante_id
WHERE r.estado = 'PENDIENTE_TITULAR';

-- F) vw_reservas_admin
DROP VIEW IF EXISTS public.vw_reservas_admin CASCADE;
CREATE VIEW public.vw_reservas_admin AS
SELECT 
    r.*,
    (
        SELECT COUNT(*)::INTEGER 
        FROM public.reservas r_ns 
        WHERE r_ns.titular_id = r.titular_id AND r_ns.estado = 'NO_UTILIZADA'
    ) AS no_shows_titular,
    (
        SELECT COUNT(*)::INTEGER 
        FROM public.reservas r_ns 
        WHERE r_ns.solicitante_id = r.solicitante_id AND r_ns.estado = 'NO_UTILIZADA'
    ) AS no_shows_solicitante
FROM public.vw_reservas_usuario r;

-- G) vw_no_shows
DROP VIEW IF EXISTS public.vw_no_shows CASCADE;
CREATE VIEW public.vw_no_shows AS
SELECT 
    r.id,
    r.area_id,
    a.nombre AS area_nombre,
    r.condominio_id,
    r.inicio,
    r.fin,
    r.titular_id,
    u_tit.nombre AS titular_nombre,
    u_tit.apellidos AS titular_apellidos,
    r.vivienda_id,
    v.numero_casa,
    r.solicitante_id,
    u_sol.nombre AS solicitante_nombre,
    u_sol.apellidos AS solicitante_apellidos,
    r.creado_en
FROM public.reservas r
JOIN public.areas_comunes a ON a.id = r.area_id
LEFT JOIN public.usuarios u_tit ON u_tit.id = r.titular_id
LEFT JOIN public.usuarios u_sol ON u_sol.id = r.solicitante_id
LEFT JOIN public.viviendas v ON v.id = r.vivienda_id
WHERE r.estado = 'NO_UTILIZADA';

-- ==============================================================================
-- 5. STORED PROCEDURES / RPCs: ÁREAS COMUNES (ADMIN)
-- ==============================================================================

-- A) alta_area_comun
DROP FUNCTION IF EXISTS public.alta_area_comun(UUID, UUID, VARCHAR, TEXT, TIME, TIME);
CREATE OR REPLACE FUNCTION public.alta_area_comun(
    p_actor_id UUID,
    p_condominio_id UUID,
    p_nombre VARCHAR(100),
    p_descripcion TEXT DEFAULT NULL,
    p_hora_apertura TIME DEFAULT '08:00:00',
    p_hora_cierre TIME DEFAULT '22:00:00'
)
RETURNS public.vw_areas_comunes
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_id UUID;
    v_resultado public.vw_areas_comunes;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.usuarios WHERE id = p_actor_id AND rol_id = 1 AND activo = true) THEN
        RAISE EXCEPTION 'El actor no cuenta con permisos de Administrador.' USING ERRCODE = 'RE003';
    END IF;

    IF p_hora_apertura >= p_hora_cierre THEN
        RAISE EXCEPTION 'La hora de apertura debe ser menor a la de cierre.' USING ERRCODE = 'RE005';
    END IF;

    INSERT INTO public.areas_comunes (
        condominio_id, nombre, descripcion, hora_apertura, hora_cierre
    ) VALUES (
        p_condominio_id, TRIM(p_nombre), NULLIF(TRIM(p_descripcion), ''), p_hora_apertura, p_hora_cierre
    ) RETURNING id INTO v_id;

    SELECT * INTO v_resultado FROM public.vw_areas_comunes WHERE id = v_id;
    RETURN v_resultado;
END;
$$;

-- B) cambio_area_comun
DROP FUNCTION IF EXISTS public.cambio_area_comun(UUID, UUID, VARCHAR, TEXT, TIME, TIME);
CREATE OR REPLACE FUNCTION public.cambio_area_comun(
    p_actor_id UUID,
    p_id UUID,
    p_nombre VARCHAR(100) DEFAULT NULL,
    p_descripcion TEXT DEFAULT NULL,
    p_hora_apertura TIME DEFAULT NULL,
    p_hora_cierre TIME DEFAULT NULL
)
RETURNS public.vw_areas_comunes
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_area RECORD;
    v_apertura TIME;
    v_cierre TIME;
    v_resultado public.vw_areas_comunes;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.usuarios WHERE id = p_actor_id AND rol_id = 1 AND activo = true) THEN
        RAISE EXCEPTION 'El actor no cuenta con permisos de Administrador.' USING ERRCODE = 'RE003';
    END IF;

    SELECT * INTO v_area FROM public.areas_comunes WHERE id = p_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El área común especificada no existe.' USING ERRCODE = 'RE001';
    END IF;

    v_apertura := COALESCE(p_hora_apertura, v_area.hora_apertura);
    v_cierre := COALESCE(p_hora_cierre, v_area.hora_cierre);

    IF v_apertura >= v_cierre THEN
        RAISE EXCEPTION 'La hora de apertura debe ser menor a la de cierre.' USING ERRCODE = 'RE005';
    END IF;

    UPDATE public.areas_comunes
    SET 
        nombre = COALESCE(NULLIF(TRIM(p_nombre), ''), nombre),
        descripcion = COALESCE(NULLIF(TRIM(p_descripcion), ''), descripcion),
        hora_apertura = v_apertura,
        hora_cierre = v_cierre
    WHERE id = p_id;

    SELECT * INTO v_resultado FROM public.vw_areas_comunes WHERE id = p_id;
    RETURN v_resultado;
END;
$$;

-- C) baja_area_comun
DROP FUNCTION IF EXISTS public.baja_area_comun(UUID, UUID);
CREATE OR REPLACE FUNCTION public.baja_area_comun(
    p_actor_id UUID,
    p_id UUID
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_afectados INTEGER;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.usuarios WHERE id = p_actor_id AND rol_id = 1 AND activo = true) THEN
        RAISE EXCEPTION 'El actor no cuenta con permisos de Administrador.' USING ERRCODE = 'RE003';
    END IF;

    UPDATE public.areas_comunes
    SET activo = false
    WHERE id = p_id AND activo = true;

    GET DIAGNOSTICS v_afectados = ROW_COUNT;
    RETURN v_afectados > 0;
END;
$$;

-- D) reactivar_area_comun
DROP FUNCTION IF EXISTS public.reactivar_area_comun(UUID, UUID);
CREATE OR REPLACE FUNCTION public.reactivar_area_comun(
    p_actor_id UUID,
    p_id UUID
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_afectados INTEGER;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.usuarios WHERE id = p_actor_id AND rol_id = 1 AND activo = true) THEN
        RAISE EXCEPTION 'El actor no cuenta con permisos de Administrador.' USING ERRCODE = 'RE003';
    END IF;

    UPDATE public.areas_comunes
    SET activo = true
    WHERE id = p_id AND activo = false;

    GET DIAGNOSTICS v_afectados = ROW_COUNT;
    RETURN v_afectados > 0;
END;
$$;

-- ==============================================================================
-- 6. STORED PROCEDURES / RPCs: FLUJO DE RESERVAS
-- ==============================================================================

-- A) solicitar_reserva
DROP FUNCTION IF EXISTS public.solicitar_reserva(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ);
CREATE OR REPLACE FUNCTION public.solicitar_reserva(
    p_actor_id UUID,
    p_area_id UUID,
    p_inicio TIMESTAMPTZ,
    p_fin TIMESTAMPTZ
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_area RECORD;
    v_actor RECORD;
    v_vivienda_id INTEGER;
    v_titular_id UUID;
    v_es_titular BOOLEAN;
    v_estado_inicial VARCHAR(30);
    v_duracion INTERVAL;
    v_zona TEXT;
    v_local_inicio TIMESTAMP;
    v_local_fin TIMESTAMP;
    v_hoy_local DATE;
    v_id UUID;
    v_resultado JSONB;
BEGIN
    -- 1. Validar área y zona horaria
    SELECT a.*, c.zona_horaria INTO v_area 
    FROM public.areas_comunes a
    JOIN public.condominios c ON c.id = a.condominio_id
    WHERE a.id = p_area_id;

    IF NOT FOUND OR NOT v_area.activo THEN
        RAISE EXCEPTION 'El área común no existe o está inactiva.' USING ERRCODE = 'RE001';
    END IF;

    v_zona := v_area.zona_horaria;

    -- 2. Resolver vivienda, titular y pertenencia del actor
    SELECT * INTO v_actor FROM public.usuarios WHERE id = p_actor_id AND activo = true;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Actor inválido o inactivo.' USING ERRCODE = 'RE003';
    END IF;

    -- Verificar si es residente titular
    SELECT vivienda_id INTO v_vivienda_id
    FROM public.vivienda_residente
    WHERE usuario_id = p_actor_id LIMIT 1;

    IF v_vivienda_id IS NOT NULL THEN
        v_titular_id := p_actor_id;
        v_es_titular := true;
        v_estado_inicial := 'PENDIENTE_ADMIN';
    ELSE
        -- Verificar si es sub-usuario activo
        SELECT vivienda_id, titular_id INTO v_vivienda_id, v_titular_id
        FROM public.vivienda_subusuarios
        WHERE usuario_id = p_actor_id AND activo = true LIMIT 1;

        IF v_vivienda_id IS NOT NULL THEN
            IF v_titular_id IS NULL THEN
                SELECT usuario_id INTO v_titular_id 
                FROM public.vivienda_residente 
                WHERE vivienda_id = v_vivienda_id LIMIT 1;
            END IF;
            v_es_titular := false;
            v_estado_inicial := 'PENDIENTE_TITULAR';
        ELSE
            RAISE EXCEPTION 'El usuario no cuenta con una vivienda o titular asociado.' USING ERRCODE = 'RE015';
        END IF;
    END IF;

    -- 3. Validar consistencia de fechas y duración (30 min a 12 horas)
    IF p_inicio >= p_fin THEN
        RAISE EXCEPTION 'La fecha de inicio debe ser anterior a la de fin.' USING ERRCODE = 'RE006';
    END IF;

    v_duracion := p_fin - p_inicio;
    IF v_duracion < INTERVAL '30 minutes' OR v_duracion > INTERVAL '12 hours' THEN
        RAISE EXCEPTION 'La duración debe estar entre 30 minutos y 12 horas.' USING ERRCODE = 'RE006';
    END IF;

    -- 4. Validar reglas en la zona horaria local del condominio
    v_local_inicio := timezone(v_zona, p_inicio);
    v_local_fin := timezone(v_zona, p_fin);
    v_hoy_local := (timezone(v_zona, now()))::date;

    IF v_local_inicio::date <> v_local_fin::date THEN
        RAISE EXCEPTION 'La reserva no puede cruzar la medianoche.' USING ERRCODE = 'RE005';
    END IF;

    IF v_local_inicio::time < v_area.hora_apertura OR v_local_fin::time > v_area.hora_cierre THEN
        RAISE EXCEPTION 'El horario solicitado está fuera del horario operativo del área.' USING ERRCODE = 'RE005';
    END IF;

    -- Anticipación: 7 a 30 días
    IF v_local_inicio::date < (v_hoy_local + 7) OR v_local_inicio::date > (v_hoy_local + 30) THEN
        RAISE EXCEPTION 'La reserva debe realizarse con entre 7 y 30 días de anticipación.' USING ERRCODE = 'RE007';
    END IF;

    -- 5. Validar máximo una reserva por titular por día
    IF EXISTS (
        SELECT 1 FROM public.reservas
        WHERE titular_id = v_titular_id
          AND tipo = 'RESERVA'
          AND estado NOT IN ('RECHAZADA', 'CANCELADA', 'EXPIRADA', 'EXPIRADA_SIN_CONFIRMAR')
          AND (timezone(v_zona, inicio))::date = v_local_inicio::date
    ) THEN
        RAISE EXCEPTION 'La vivienda ya cuenta con una reserva activa o pendiente para ese día.' USING ERRCODE = 'RE008';
    END IF;

    -- 6. Anti-colisión sobre el área común
    IF EXISTS (
        SELECT 1 FROM public.reservas
        WHERE area_id = p_area_id
          AND estado IN ('APROBADA', 'PENDIENTE_ADMIN', 'PENDIENTE_TITULAR')
          AND inicio < p_fin
          AND fin > p_inicio
    ) THEN
        RAISE EXCEPTION 'El horario solicitado choca con otra reserva existente o bloqueo.' USING ERRCODE = 'RE009';
    END IF;

    -- 7. Inserción
    INSERT INTO public.reservas (
        condominio_id, area_id, tipo, estado, inicio, fin,
        titular_id, vivienda_id, solicitante_id
    ) VALUES (
        v_area.condominio_id, p_area_id, 'RESERVA', v_estado_inicial, p_inicio, p_fin,
        v_titular_id, v_vivienda_id, p_actor_id
    ) RETURNING id INTO v_id;

    -- Notificaciones
    IF NOT v_es_titular THEN
        BEGIN
            PERFORM public.alta_notificacion(
                v_titular_id,
                'reserva_solicitud_subusuario',
                'Solicitud de Reserva',
                'Un co-habitante ha solicitado una reserva en ' || v_area.nombre || ' que requiere tu aprobación.',
                '/panel/reservas'
            );
        EXCEPTION WHEN OTHERS THEN END;
    END IF;

    SELECT to_jsonb(vr.*) INTO v_resultado FROM public.vw_reservas_usuario vr WHERE vr.id = v_id;
    RETURN v_resultado;
END;
$$;

-- B) aprobar_reserva_titular
DROP FUNCTION IF EXISTS public.aprobar_reserva_titular(UUID, UUID);
CREATE OR REPLACE FUNCTION public.aprobar_reserva_titular(
    p_actor_id UUID,
    p_reserva_id UUID
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_reserva RECORD;
BEGIN
    SELECT * INTO v_reserva FROM public.reservas WHERE id = p_reserva_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La reserva no existe.' USING ERRCODE = 'RE002';
    END IF;

    IF v_reserva.titular_id <> p_actor_id THEN
        RAISE EXCEPTION 'Solo el residente titular puede aprobar esta solicitud.' USING ERRCODE = 'RE003';
    END IF;

    IF v_reserva.estado <> 'PENDIENTE_TITULAR' THEN
        RAISE EXCEPTION 'La reserva no se encuentra en estado PENDIENTE_TITULAR.' USING ERRCODE = 'RE004';
    END IF;

    UPDATE public.reservas
    SET estado = 'PENDIENTE_ADMIN',
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_reserva_id;

    RETURN true;
END;
$$;

-- C) rechazar_reserva_titular
DROP FUNCTION IF EXISTS public.rechazar_reserva_titular(UUID, UUID, TEXT);
CREATE OR REPLACE FUNCTION public.rechazar_reserva_titular(
    p_actor_id UUID,
    p_reserva_id UUID,
    p_motivo TEXT DEFAULT NULL
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_reserva RECORD;
BEGIN
    SELECT * INTO v_reserva FROM public.reservas WHERE id = p_reserva_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La reserva no existe.' USING ERRCODE = 'RE002';
    END IF;

    IF v_reserva.titular_id <> p_actor_id THEN
        RAISE EXCEPTION 'Solo el residente titular puede rechazar esta solicitud.' USING ERRCODE = 'RE003';
    END IF;

    IF v_reserva.estado <> 'PENDIENTE_TITULAR' THEN
        RAISE EXCEPTION 'La reserva no se encuentra en estado PENDIENTE_TITULAR.' USING ERRCODE = 'RE004';
    END IF;

    UPDATE public.reservas
    SET estado = 'RECHAZADA',
        motivo = COALESCE(NULLIF(TRIM(p_motivo), ''), 'Rechazada por el residente titular'),
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_reserva_id;

    BEGIN
        PERFORM public.alta_notificacion(
            v_reserva.solicitante_id,
            'reserva_rechazada',
            'Reserva Rechazada',
            'Tu solicitud de reserva fue rechazada por el titular.',
            '/panel/reservas'
        );
    EXCEPTION WHEN OTHERS THEN END;

    RETURN true;
END;
$$;

-- D) aprobar_reserva_admin
DROP FUNCTION IF EXISTS public.aprobar_reserva_admin(UUID, UUID);
CREATE OR REPLACE FUNCTION public.aprobar_reserva_admin(
    p_actor_id UUID,
    p_reserva_id UUID
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_reserva RECORD;
    v_faltan INTERVAL;
    v_auto_confirmada BOOLEAN := false;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.usuarios WHERE id = p_actor_id AND rol_id = 1 AND activo = true) THEN
        RAISE EXCEPTION 'El actor no cuenta con privilegios de Administrador.' USING ERRCODE = 'RE003';
    END IF;

    SELECT * INTO v_reserva FROM public.reservas WHERE id = p_reserva_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La reserva no existe.' USING ERRCODE = 'RE002';
    END IF;

    IF v_reserva.estado <> 'PENDIENTE_ADMIN' THEN
        RAISE EXCEPTION 'La reserva no se encuentra en estado PENDIENTE_ADMIN.' USING ERRCODE = 'RE004';
    END IF;

    IF v_reserva.inicio <= now() THEN
        RAISE EXCEPTION 'No se puede aprobar una reserva cuya fecha ya pasó.' USING ERRCODE = 'RE012';
    END IF;

    -- Validar colisión contra aprobadas o bloqueos
    IF EXISTS (
        SELECT 1 FROM public.reservas
        WHERE area_id = v_reserva.area_id
          AND id <> p_reserva_id
          AND estado = 'APROBADA'
          AND inicio < v_reserva.fin
          AND fin > v_reserva.inicio
    ) THEN
        RAISE EXCEPTION 'El horario colisiona con otra reserva aprobada o bloqueo.' USING ERRCODE = 'RE009';
    END IF;

    -- Si faltan menos de 72 horas para el inicio, se autoconfirma
    v_faltan := v_reserva.inicio - now();
    IF v_faltan < INTERVAL '72 hours' THEN
        v_auto_confirmada := true;
    END IF;

    UPDATE public.reservas
    SET estado = 'APROBADA',
        aprobador_id = p_actor_id,
        confirmada_en = CASE WHEN v_auto_confirmada THEN timezone('utc'::text, now()) ELSE NULL END,
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_reserva_id;

    BEGIN
        PERFORM public.alta_notificacion(
            v_reserva.solicitante_id,
            'reserva_aprobada',
            'Reserva Aprobada',
            'Tu reserva ha sido aprobada por la administración.',
            '/panel/reservas'
        );
        IF v_reserva.titular_id IS NOT NULL AND v_reserva.titular_id <> v_reserva.solicitante_id THEN
            PERFORM public.alta_notificacion(
                v_reserva.titular_id,
                'reserva_aprobada',
                'Reserva Aprobada',
                'La reserva solicitada para tu vivienda fue aprobada por la administración.',
                '/panel/reservas'
            );
        END IF;
    EXCEPTION WHEN OTHERS THEN END;

    RETURN true;
END;
$$;

-- E) rechazar_reserva_admin
DROP FUNCTION IF EXISTS public.rechazar_reserva_admin(UUID, UUID, TEXT);
CREATE OR REPLACE FUNCTION public.rechazar_reserva_admin(
    p_actor_id UUID,
    p_reserva_id UUID,
    p_motivo TEXT
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_reserva RECORD;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.usuarios WHERE id = p_actor_id AND rol_id = 1 AND activo = true) THEN
        RAISE EXCEPTION 'El actor no cuenta con privilegios de Administrador.' USING ERRCODE = 'RE003';
    END IF;

    IF NULLIF(TRIM(p_motivo), '') IS NULL THEN
        RAISE EXCEPTION 'El motivo de rechazo administrativo es obligatorio.' USING ERRCODE = 'RE010';
    END IF;

    SELECT * INTO v_reserva FROM public.reservas WHERE id = p_reserva_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La reserva no existe.' USING ERRCODE = 'RE002';
    END IF;

    IF v_reserva.estado <> 'PENDIENTE_ADMIN' THEN
        RAISE EXCEPTION 'La reserva no se encuentra en estado PENDIENTE_ADMIN.' USING ERRCODE = 'RE004';
    END IF;

    UPDATE public.reservas
    SET estado = 'RECHAZADA',
        aprobador_id = p_actor_id,
        motivo = TRIM(p_motivo),
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_reserva_id;

    BEGIN
        PERFORM public.alta_notificacion(
            v_reserva.solicitante_id,
            'reserva_rechazada',
            'Reserva Rechazada',
            'Tu solicitud de reserva fue rechazada por la administración: ' || TRIM(p_motivo),
            '/panel/reservas'
        );
    EXCEPTION WHEN OTHERS THEN END;

    RETURN true;
END;
$$;

-- F) confirmar_reserva (Solo titular, ventana de 7 días a 72h antes)
DROP FUNCTION IF EXISTS public.confirmar_reserva(UUID, UUID);
CREATE OR REPLACE FUNCTION public.confirmar_reserva(
    p_actor_id UUID,
    p_reserva_id UUID
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_reserva RECORD;
    v_faltan INTERVAL;
BEGIN
    SELECT * INTO v_reserva FROM public.reservas WHERE id = p_reserva_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La reserva no existe.' USING ERRCODE = 'RE002';
    END IF;

    IF v_reserva.titular_id <> p_actor_id THEN
        RAISE EXCEPTION 'Solo el residente titular puede confirmar la reserva.' USING ERRCODE = 'RE003';
    END IF;

    IF v_reserva.estado <> 'APROBADA' THEN
        RAISE EXCEPTION 'Solo se pueden confirmar reservas aprobadas.' USING ERRCODE = 'RE004';
    END IF;

    IF v_reserva.confirmada_en IS NOT NULL THEN
        RETURN true; -- Ya confirmada
    END IF;

    v_faltan := v_reserva.inicio - now();
    IF v_faltan > INTERVAL '7 days' OR v_faltan < INTERVAL '72 hours' THEN
        RAISE EXCEPTION 'La confirmación debe realizarse entre 7 días y 72 horas antes del inicio.' USING ERRCODE = 'RE011';
    END IF;

    UPDATE public.reservas
    SET confirmada_en = timezone('utc'::text, now()),
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_reserva_id;

    RETURN true;
END;
$$;

-- G) cancelar_reserva (Residente)
DROP FUNCTION IF EXISTS public.cancelar_reserva(UUID, UUID, TEXT);
CREATE OR REPLACE FUNCTION public.cancelar_reserva(
    p_actor_id UUID,
    p_reserva_id UUID,
    p_motivo TEXT DEFAULT NULL
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_reserva RECORD;
    v_admin RECORD;
BEGIN
    SELECT * INTO v_reserva FROM public.reservas WHERE id = p_reserva_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La reserva no existe.' USING ERRCODE = 'RE002';
    END IF;

    IF v_reserva.titular_id <> p_actor_id AND v_reserva.solicitante_id <> p_actor_id THEN
        RAISE EXCEPTION 'Sin permisos para cancelar esta reserva.' USING ERRCODE = 'RE003';
    END IF;

    IF v_reserva.estado NOT IN ('PENDIENTE_TITULAR', 'PENDIENTE_ADMIN', 'APROBADA') THEN
        RAISE EXCEPTION 'El estado actual no permite cancelación.' USING ERRCODE = 'RE004';
    END IF;

    IF v_reserva.inicio <= now() THEN
        RAISE EXCEPTION 'No se puede cancelar una reserva iniciada o pasada.' USING ERRCODE = 'RE012';
    END IF;

    UPDATE public.reservas
    SET estado = 'CANCELADA',
        motivo = COALESCE(NULLIF(TRIM(p_motivo), ''), 'Cancelada por el residente'),
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_reserva_id;

    -- Notificar a la administración
    FOR v_admin IN 
        SELECT id FROM public.usuarios 
        WHERE condominio_id = v_reserva.condominio_id AND rol_id = 1 AND activo = true
    LOOP
        BEGIN
            PERFORM public.alta_notificacion(
                v_admin.id,
                'reserva_cancelada_usuario',
                'Reserva Cancelada',
                'Una reserva en un área común ha sido cancelada por el residente.',
                '/panel/reservas'
            );
        EXCEPTION WHEN OTHERS THEN END;
    END LOOP;

    RETURN true;
END;
$$;

-- H) cancelar_reserva_admin
DROP FUNCTION IF EXISTS public.cancelar_reserva_admin(UUID, UUID, TEXT);
CREATE OR REPLACE FUNCTION public.cancelar_reserva_admin(
    p_actor_id UUID,
    p_reserva_id UUID,
    p_motivo TEXT
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_reserva RECORD;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.usuarios WHERE id = p_actor_id AND rol_id = 1 AND activo = true) THEN
        RAISE EXCEPTION 'El actor no cuenta con privilegios de Administrador.' USING ERRCODE = 'RE003';
    END IF;

    IF NULLIF(TRIM(p_motivo), '') IS NULL THEN
        RAISE EXCEPTION 'El motivo de cancelación administrativa es obligatorio.' USING ERRCODE = 'RE010';
    END IF;

    SELECT * INTO v_reserva FROM public.reservas WHERE id = p_reserva_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La reserva no existe.' USING ERRCODE = 'RE002';
    END IF;

    IF v_reserva.estado NOT IN ('PENDIENTE_ADMIN', 'APROBADA') THEN
        RAISE EXCEPTION 'El estado actual no permite cancelación.' USING ERRCODE = 'RE004';
    END IF;

    IF v_reserva.inicio <= now() THEN
        RAISE EXCEPTION 'No se puede cancelar una reserva iniciada o pasada.' USING ERRCODE = 'RE012';
    END IF;

    UPDATE public.reservas
    SET estado = 'CANCELADA',
        aprobador_id = p_actor_id,
        motivo = TRIM(p_motivo),
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_reserva_id;

    BEGIN
        PERFORM public.alta_notificacion(
            v_reserva.solicitante_id,
            'reserva_cancelada_admin',
            'Reserva Cancelada por Administración',
            'Tu reserva fue cancelada por la administración: ' || TRIM(p_motivo),
            '/panel/reservas'
        );
        IF v_reserva.titular_id IS NOT NULL AND v_reserva.titular_id <> v_reserva.solicitante_id THEN
            PERFORM public.alta_notificacion(
                v_reserva.titular_id,
                'reserva_cancelada_admin',
                'Reserva Cancelada por Administración',
                'Una reserva de tu vivienda fue cancelada por la administración: ' || TRIM(p_motivo),
                '/panel/reservas'
            );
        END IF;
    EXCEPTION WHEN OTHERS THEN END;

    RETURN true;
END;
$$;

-- I) marcar_reserva_no_utilizada (Ajuste administrativo sin notificación)
DROP FUNCTION IF EXISTS public.marcar_reserva_no_utilizada(UUID, UUID);
CREATE OR REPLACE FUNCTION public.marcar_reserva_no_utilizada(
    p_actor_id UUID,
    p_reserva_id UUID
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_reserva RECORD;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.usuarios WHERE id = p_actor_id AND rol_id = 1 AND activo = true) THEN
        RAISE EXCEPTION 'El actor no cuenta con privilegios de Administrador.' USING ERRCODE = 'RE003';
    END IF;

    SELECT * INTO v_reserva FROM public.reservas WHERE id = p_reserva_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La reserva no existe.' USING ERRCODE = 'RE002';
    END IF;

    IF v_reserva.estado <> 'APROBADA' THEN
        RAISE EXCEPTION 'Solo se pueden marcar reservas aprobadas como no utilizadas.' USING ERRCODE = 'RE004';
    END IF;

    IF v_reserva.fin > now() THEN
        RAISE EXCEPTION 'No se puede marcar como no utilizada antes de que concluya el horario.' USING ERRCODE = 'RE013';
    END IF;

    UPDATE public.reservas
    SET estado = 'NO_UTILIZADA',
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_reserva_id;

    RETURN true;
END;
$$;

-- ==============================================================================
-- 7. STORED PROCEDURES / RPCs: BLOQUEOS DE ÁREAS (MANTENIMIENTO)
-- ==============================================================================

-- A) crear_bloqueo_area
DROP FUNCTION IF EXISTS public.crear_bloqueo_area(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT);
CREATE OR REPLACE FUNCTION public.crear_bloqueo_area(
    p_actor_id UUID,
    p_area_id UUID,
    p_inicio TIMESTAMPTZ,
    p_fin TIMESTAMPTZ,
    p_motivo TEXT
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_area RECORD;
    v_bloqueo_id UUID;
    v_afectadas INTEGER := 0;
    v_res RECORD;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM public.usuarios WHERE id = p_actor_id AND rol_id = 1 AND activo = true) THEN
        RAISE EXCEPTION 'El actor no cuenta con privilegios de Administrador.' USING ERRCODE = 'RE003';
    END IF;

    IF NULLIF(TRIM(p_motivo), '') IS NULL THEN
        RAISE EXCEPTION 'El motivo del bloqueo es obligatorio.' USING ERRCODE = 'RE010';
    END IF;

    IF p_inicio >= p_fin THEN
        RAISE EXCEPTION 'La fecha de inicio debe ser anterior a la de fin.' USING ERRCODE = 'RE006';
    END IF;

    SELECT * INTO v_area FROM public.areas_comunes WHERE id = p_area_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El área común no existe.' USING ERRCODE = 'RE001';
    END IF;

    -- Cancelar reservas en conflicto
    FOR v_res IN 
        SELECT id, solicitante_id, titular_id FROM public.reservas
        WHERE area_id = p_area_id
          AND estado IN ('APROBADA', 'PENDIENTE_ADMIN', 'PENDIENTE_TITULAR')
          AND inicio < p_fin
          AND fin > p_inicio
    LOOP
        UPDATE public.reservas
        SET estado = 'CANCELADA',
            motivo = 'Cancelada por bloqueo de área: ' || TRIM(p_motivo),
            actualizado_en = timezone('utc'::text, now())
        WHERE id = v_res.id;

        v_afectadas := v_afectadas + 1;

        BEGIN
            PERFORM public.alta_notificacion(
                v_res.solicitante_id,
                'reserva_cancelada_bloqueo',
                'Reserva Cancelada por Mantenimiento',
                'Tu reserva fue cancelada debido a un bloqueo administrativo del área: ' || TRIM(p_motivo),
                '/panel/reservas'
            );
        EXCEPTION WHEN OTHERS THEN END;
    END LOOP;

    -- Registrar el bloqueo
    INSERT INTO public.reservas (
        condominio_id, area_id, tipo, estado, inicio, fin,
        solicitante_id, aprobador_id, motivo, confirmada_en
    ) VALUES (
        v_area.condominio_id, p_area_id, 'BLOQUEO', 'APROBADA', p_inicio, p_fin,
        p_actor_id, p_actor_id, TRIM(p_motivo), timezone('utc'::text, now())
    ) RETURNING id INTO v_bloqueo_id;

    RETURN jsonb_build_object(
        'bloqueo_id', v_bloqueo_id,
        'area_id', p_area_id,
        'inicio', p_inicio,
        'fin', p_fin,
        'motivo', TRIM(p_motivo),
        'reservas_afectadas', v_afectadas
    );
END;
$$;

-- B) actualizar_bloqueo_area (Unificado sobre public.reservas y sin conflicto de nombres)
DROP FUNCTION IF EXISTS public.actualizar_bloqueo_area(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT);
CREATE OR REPLACE FUNCTION public.actualizar_bloqueo_area(
    p_actor_id UUID,
    p_bloqueo_id UUID,
    p_inicio TIMESTAMPTZ DEFAULT NULL,
    p_fin TIMESTAMPTZ DEFAULT NULL,
    p_motivo TEXT DEFAULT NULL
)
RETURNS TABLE (
    bloqueo_id UUID,
    area_id UUID,
    inicio TIMESTAMPTZ,
    fin TIMESTAMPTZ,
    motivo TEXT,
    reservas_afectadas INTEGER
)
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
#variable_conflict use_column
DECLARE
    v_area_id UUID;
    v_inicio TIMESTAMPTZ;
    v_fin TIMESTAMPTZ;
    v_motivo TEXT;
    v_afectadas INTEGER := 0;
BEGIN
    SELECT r.area_id, r.inicio, r.fin, r.motivo
    INTO v_area_id, v_inicio, v_fin, v_motivo
    FROM public.reservas r
    WHERE r.id = p_bloqueo_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El bloqueo/reserva con ID % no existe.', p_bloqueo_id USING ERRCODE = 'P0002';
    END IF;

    v_inicio := COALESCE(p_inicio, v_inicio);
    v_fin    := COALESCE(p_fin, v_fin);
    v_motivo := COALESCE(p_motivo, v_motivo);

    IF v_inicio >= v_fin THEN
        RAISE EXCEPTION 'La fecha de inicio (%) debe ser menor a la de fin (%).', v_inicio, v_fin USING ERRCODE = '22023';
    END IF;

    UPDATE public.reservas
    SET inicio = v_inicio,
        fin = v_fin,
        motivo = v_motivo,
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_bloqueo_id;

    SELECT COUNT(*)::INTEGER
    INTO v_afectadas
    FROM public.reservas r
    WHERE r.area_id = v_area_id
      AND r.id <> p_bloqueo_id
      AND r.estado NOT IN ('CANCELADA', 'EXPIRADA', 'EXPIRADA_SIN_CONFIRMAR')
      AND r.inicio < v_fin
      AND r.fin > v_inicio;

    RETURN QUERY
    SELECT 
        p_bloqueo_id AS bloqueo_id,
        v_area_id    AS area_id,
        v_inicio     AS inicio,
        v_fin        AS fin,
        v_motivo     AS motivo,
        v_afectadas  AS reservas_afectadas;
END;
$$;

-- ==============================================================================
-- 8. PERMISOS Y RECARGA DE POSTGREST
-- ==============================================================================
REVOKE ALL ON public.areas_comunes FROM authenticated, anon, service_role;
REVOKE ALL ON public.reservas FROM authenticated, anon, service_role;

GRANT SELECT ON public.vw_areas_comunes TO authenticated, service_role;
GRANT SELECT ON public.vw_calendario_reservas TO authenticated, service_role;
GRANT SELECT ON public.vw_calendario_reservas_limitado TO authenticated, service_role;
GRANT SELECT ON public.vw_reservas_usuario TO authenticated, service_role;
GRANT SELECT ON public.vw_reservas_pendientes_titular TO authenticated, service_role;
GRANT SELECT ON public.vw_reservas_admin TO service_role;
GRANT SELECT ON public.vw_no_shows TO service_role;

GRANT EXECUTE ON FUNCTION public.alta_area_comun(UUID, UUID, VARCHAR, TEXT, TIME, TIME) TO service_role;
GRANT EXECUTE ON FUNCTION public.cambio_area_comun(UUID, UUID, VARCHAR, TEXT, TIME, TIME) TO service_role;
GRANT EXECUTE ON FUNCTION public.baja_area_comun(UUID, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.reactivar_area_comun(UUID, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.solicitar_reserva(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.aprobar_reserva_titular(UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rechazar_reserva_titular(UUID, UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.aprobar_reserva_admin(UUID, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.rechazar_reserva_admin(UUID, UUID, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.confirmar_reserva(UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cancelar_reserva(UUID, UUID, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cancelar_reserva_admin(UUID, UUID, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.marcar_reserva_no_utilizada(UUID, UUID) TO service_role;
GRANT EXECUTE ON FUNCTION public.crear_bloqueo_area(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) TO service_role;
GRANT EXECUTE ON FUNCTION public.actualizar_bloqueo_area(UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';