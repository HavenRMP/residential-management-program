-- ==============================================================================
-- Archivo: supabase/migrations/20261008120000_modulo_paqueteria.sql
-- Proyecto: HAVEN
-- Descripción: Módulo completo de Paquetería (Tabla base, Auditoría forense,
--              Vistas de consulta y Stored Procedures para Caseta y Residentes).
-- ==============================================================================

-- ==============================================================================
-- 1. TABLA BASE: PAQUETES
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.paquetes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    condominio_id UUID NOT NULL REFERENCES public.condominios(id) ON DELETE RESTRICT,
    vivienda_id INTEGER NOT NULL REFERENCES public.viviendas(id) ON DELETE CASCADE,
    destinatario_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
    destinatario_nombre VARCHAR(100),
    empresa_reparto VARCHAR(50) NOT NULL,
    codigo_rastreo VARCHAR(100),
    descripcion VARCHAR(200),
    estado VARCHAR(20) NOT NULL DEFAULT 'recibido' 
        CHECK (estado IN ('esperado', 'recibido', 'entregado', 'devuelto', 'cancelado')),
    fecha_esperada DATE,
    fecha_recepcion TIMESTAMPTZ,
    recibido_por UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
    fecha_entrega TIMESTAMPTZ,
    entregado_por UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
    entregado_a UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
    entregado_a_nombre VARCHAR(100),
    cierre_motivo VARCHAR(200),
    notas VARCHAR(500),
    creado_por UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE RESTRICT,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Índices de consulta y rendimiento
CREATE INDEX IF NOT EXISTS idx_paquetes_condominio ON public.paquetes(condominio_id);
CREATE INDEX IF NOT EXISTS idx_paquetes_vivienda ON public.paquetes(vivienda_id);
CREATE INDEX IF NOT EXISTS idx_paquetes_destinatario ON public.paquetes(destinatario_id);
CREATE INDEX IF NOT EXISTS idx_paquetes_estado ON public.paquetes(estado);
CREATE INDEX IF NOT EXISTS idx_paquetes_caseta_activos ON public.paquetes(condominio_id, estado)
    WHERE estado IN ('recibido', 'esperado');

-- ==============================================================================
-- 2. TABLA ESPEJO DE AUDITORÍA Y TRIGGERS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.paquetes_bitacora (
    id BIGSERIAL PRIMARY KEY,
    registro_id TEXT NOT NULL,
    operacion VARCHAR(10) NOT NULL CHECK (operacion IN ('INSERT', 'UPDATE', 'DELETE')),
    datos_anteriores JSONB,
    datos_nuevos JSONB,
    modificado_por TEXT,
    modificado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_paquetes_bitacora_registro ON public.paquetes_bitacora(registro_id);
CREATE INDEX IF NOT EXISTS idx_paquetes_bitacora_fecha ON public.paquetes_bitacora(modificado_en);

REVOKE ALL ON public.paquetes_bitacora FROM authenticated, anon, service_role;

-- Disparadores de auditoría conectados a fn_auditoria()
DROP TRIGGER IF EXISTS trg_paquetes_auditoria_insert ON public.paquetes;
CREATE TRIGGER trg_paquetes_auditoria_insert
    AFTER INSERT ON public.paquetes
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

DROP TRIGGER IF EXISTS trg_paquetes_auditoria_update ON public.paquetes;
CREATE TRIGGER trg_paquetes_auditoria_update
    BEFORE UPDATE ON public.paquetes
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

DROP TRIGGER IF EXISTS trg_paquetes_auditoria_delete ON public.paquetes;
CREATE TRIGGER trg_paquetes_auditoria_delete
    BEFORE DELETE ON public.paquetes
    FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

-- ==============================================================================
-- 3. VISTAS DE CONSULTA
-- ==============================================================================

-- A) Vista de destinatarios por vivienda (Resolución de usuarios y notificaciones push)
DROP VIEW IF EXISTS public.vw_vivienda_usuarios CASCADE;
CREATE VIEW public.vw_vivienda_usuarios AS
SELECT 
    vr.vivienda_id,
    vr.usuario_id,
    'titular'::VARCHAR(20) AS tipo_relacion,
    u.nombre,
    u.apellidos,
    TRIM(u.nombre || ' ' || COALESCE(u.apellidos, '')) AS nombre_completo,
    u.email,
    u.telefono
FROM public.vivienda_residente vr
JOIN public.usuarios u ON u.id = vr.usuario_id
WHERE u.activo = true
UNION ALL
SELECT 
    vs.vivienda_id,
    vs.usuario_id,
    'subusuario'::VARCHAR(20) AS tipo_relacion,
    u.nombre,
    u.apellidos,
    TRIM(u.nombre || ' ' || COALESCE(u.apellidos, '')) AS nombre_completo,
    u.email,
    u.telefono
FROM public.vivienda_subusuarios vs
JOIN public.usuarios u ON u.id = vs.usuario_id
WHERE vs.activo = true AND u.activo = true;

-- B) Vista para Vigilancia en Caseta (Paquetes en custodia y esperados)
DROP VIEW IF EXISTS public.vw_paquetes_caseta CASCADE;
CREATE VIEW public.vw_paquetes_caseta AS
SELECT 
    p.id,
    p.condominio_id,
    p.vivienda_id,
    v.numero_casa,
    p.destinatario_id,
    COALESCE(TRIM(u_dest.nombre || ' ' || COALESCE(u_dest.apellidos, '')), p.destinatario_nombre, 'Residente') AS destinatario_nombre,
    p.empresa_reparto,
    p.codigo_rastreo,
    p.descripcion,
    p.estado,
    p.fecha_esperada,
    p.fecha_recepcion,
    p.recibido_por,
    TRIM(u_rec.nombre || ' ' || COALESCE(u_rec.apellidos, '')) AS recibido_por_nombre,
    p.fecha_entrega,
    p.entregado_por,
    TRIM(u_ent.nombre || ' ' || COALESCE(u_ent.apellidos, '')) AS entregado_por_nombre,
    p.entregado_a,
    COALESCE(TRIM(u_ent_a.nombre || ' ' || COALESCE(u_ent_a.apellidos, '')), p.entregado_a_nombre) AS entregado_a_nombre,
    p.cierre_motivo,
    p.notas,
    p.creado_en,
    p.actualizado_en
FROM public.paquetes p
JOIN public.viviendas v ON v.id = p.vivienda_id
LEFT JOIN public.usuarios u_dest ON u_dest.id = p.destinatario_id
LEFT JOIN public.usuarios u_rec ON u_rec.id = p.recibido_por
LEFT JOIN public.usuarios u_ent ON u_ent.id = p.entregado_por
LEFT JOIN public.usuarios u_ent_a ON u_ent_a.id = p.entregado_a
WHERE p.estado IN ('recibido', 'esperado');

-- C) Vista para App de Residentes (Consulta por vivienda)
DROP VIEW IF EXISTS public.vw_paquetes_residente CASCADE;
CREATE VIEW public.vw_paquetes_residente AS
SELECT 
    p.id,
    p.condominio_id,
    p.vivienda_id,
    v.numero_casa,
    p.destinatario_id,
    COALESCE(TRIM(u_dest.nombre || ' ' || COALESCE(u_dest.apellidos, '')), p.destinatario_nombre, 'Residente') AS destinatario_nombre,
    p.empresa_reparto,
    p.codigo_rastreo,
    p.descripcion,
    p.estado,
    p.fecha_esperada,
    p.fecha_recepcion,
    TRIM(u_rec.nombre || ' ' || COALESCE(u_rec.apellidos, '')) AS recibido_por_nombre,
    p.fecha_entrega,
    COALESCE(TRIM(u_ent_a.nombre || ' ' || COALESCE(u_ent_a.apellidos, '')), p.entregado_a_nombre) AS entregado_a_nombre,
    p.cierre_motivo,
    p.notas,
    p.creado_por,
    p.creado_en
FROM public.paquetes p
JOIN public.viviendas v ON v.id = p.vivienda_id
LEFT JOIN public.usuarios u_dest ON u_dest.id = p.destinatario_id
LEFT JOIN public.usuarios u_rec ON u_rec.id = p.recibido_por
LEFT JOIN public.usuarios u_ent_a ON u_ent_a.id = p.entregado_a;

-- D) Vista de Histórico Completo (Panel de Administración)
DROP VIEW IF EXISTS public.vw_paquetes_historico CASCADE;
CREATE VIEW public.vw_paquetes_historico AS
SELECT 
    p.id,
    p.condominio_id,
    c.nombre AS condominio_nombre,
    p.vivienda_id,
    v.numero_casa,
    p.destinatario_id,
    COALESCE(TRIM(u_dest.nombre || ' ' || COALESCE(u_dest.apellidos, '')), p.destinatario_nombre, 'Residente') AS destinatario_nombre,
    p.empresa_reparto,
    p.codigo_rastreo,
    p.descripcion,
    p.estado,
    p.fecha_esperada,
    p.fecha_recepcion,
    TRIM(u_rec.nombre || ' ' || COALESCE(u_rec.apellidos, '')) AS recibido_por_nombre,
    p.fecha_entrega,
    TRIM(u_ent.nombre || ' ' || COALESCE(u_ent.apellidos, '')) AS entregado_por_nombre,
    p.entregado_a,
    COALESCE(TRIM(u_ent_a.nombre || ' ' || COALESCE(u_ent_a.apellidos, '')), p.entregado_a_nombre) AS entregado_a_nombre,
    p.cierre_motivo,
    p.notas,
    p.creado_en,
    p.actualizado_en
FROM public.paquetes p
JOIN public.condominios c ON c.id = p.condominio_id
JOIN public.viviendas v ON v.id = p.vivienda_id
LEFT JOIN public.usuarios u_dest ON u_dest.id = p.destinatario_id
LEFT JOIN public.usuarios u_rec ON u_rec.id = p.recibido_por
LEFT JOIN public.usuarios u_ent ON u_ent.id = p.entregado_por
LEFT JOIN public.usuarios u_ent_a ON u_ent_a.id = p.entregado_a;

-- ==============================================================================
-- 4. STORED PROCEDURES / RPCs: RESIDENTES (PAQUETES ESPERADOS)
-- ==============================================================================

-- A) Pre-registro de paquete esperado
DROP FUNCTION IF EXISTS public.alta_paquete_esperado(INTEGER, VARCHAR, UUID, VARCHAR, VARCHAR, VARCHAR, DATE, UUID);
CREATE OR REPLACE FUNCTION public.alta_paquete_esperado(
    p_vivienda_id INTEGER,
    p_empresa_reparto VARCHAR(50),
    p_destinatario_id UUID DEFAULT NULL,
    p_destinatario_nombre VARCHAR(100) DEFAULT NULL,
    p_codigo_rastreo VARCHAR(100) DEFAULT NULL,
    p_descripcion VARCHAR(200) DEFAULT NULL,
    p_fecha_esperada DATE DEFAULT NULL,
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_actor UUID;
    v_condominio_id UUID;
    v_id UUID;
    v_resultado JSONB;
BEGIN
    v_actor := COALESCE(p_actor_id, auth.uid());
    IF v_actor IS NULL THEN
        RAISE EXCEPTION 'No se proporcionó un actor válido.' USING ERRCODE = '42501';
    END IF;

    -- Validar que la vivienda exista y pertenezca al actor
    SELECT condominio_id INTO v_condominio_id FROM public.viviendas WHERE id = p_vivienda_id AND activo = true;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'La vivienda no existe o está inactiva.' USING ERRCODE = 'PQ001';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.vw_vivienda_usuarios WHERE vivienda_id = p_vivienda_id AND usuario_id = v_actor
    ) THEN
        RAISE EXCEPTION 'El usuario no pertenece a la vivienda especificada.' USING ERRCODE = 'PQ002';
    END IF;

    IF NULLIF(TRIM(p_empresa_reparto), '') IS NULL THEN
        RAISE EXCEPTION 'La empresa de reparto es obligatoria.' USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.paquetes (
        condominio_id,
        vivienda_id,
        destinatario_id,
        destinatario_nombre,
        empresa_reparto,
        codigo_rastreo,
        descripcion,
        estado,
        fecha_esperada,
        creado_por
    ) VALUES (
        v_condominio_id,
        p_vivienda_id,
        COALESCE(p_destinatario_id, v_actor),
        NULLIF(TRIM(p_destinatario_nombre), ''),
        TRIM(p_empresa_reparto),
        NULLIF(TRIM(p_codigo_rastreo), ''),
        NULLIF(TRIM(p_descripcion), ''),
        'esperado',
        p_fecha_esperada,
        v_actor
    ) RETURNING id INTO v_id;

    SELECT to_jsonb(vp.*) INTO v_resultado FROM public.vw_paquetes_residente vp WHERE vp.id = v_id;
    RETURN v_resultado;
END;
$$;

-- B) Modificar paquete esperado (Regla PQ002 flexibilizada a nivel de vivienda)
DROP FUNCTION IF EXISTS public.cambio_paquete_esperado(UUID, UUID, VARCHAR, UUID, VARCHAR, VARCHAR, VARCHAR, DATE);
CREATE OR REPLACE FUNCTION public.cambio_paquete_esperado(
    p_id UUID,
    p_actor_id UUID,
    p_empresa_reparto VARCHAR(50) DEFAULT NULL,
    p_destinatario_id UUID DEFAULT NULL,
    p_destinatario_nombre VARCHAR(100) DEFAULT NULL,
    p_codigo_rastreo VARCHAR(100) DEFAULT NULL,
    p_descripcion VARCHAR(200) DEFAULT NULL,
    p_fecha_esperada DATE DEFAULT NULL
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_paquete RECORD;
    v_resultado JSONB;
BEGIN
    SELECT * INTO v_paquete FROM public.paquetes WHERE id = p_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El paquete no existe.' USING ERRCODE = 'PQ001';
    END IF;

    IF v_paquete.estado != 'esperado' THEN
        RAISE EXCEPTION 'Solo se pueden modificar paquetes en estado esperado.' USING ERRCODE = 'PQ003';
    END IF;

    -- Validar pertenencia a la vivienda (titular o sub-usuario)
    IF NOT EXISTS (
        SELECT 1 FROM public.vw_vivienda_usuarios 
        WHERE vivienda_id = v_paquete.vivienda_id AND usuario_id = p_actor_id
    ) THEN
        RAISE EXCEPTION 'El actor no cuenta con permisos sobre los paquetes de esta vivienda.' USING ERRCODE = 'PQ002';
    END IF;

    UPDATE public.paquetes
    SET 
        empresa_reparto = COALESCE(NULLIF(TRIM(p_empresa_reparto), ''), empresa_reparto),
        destinatario_id = COALESCE(p_destinatario_id, destinatario_id),
        destinatario_nombre = COALESCE(NULLIF(TRIM(p_destinatario_nombre), ''), destinatario_nombre),
        codigo_rastreo = COALESCE(NULLIF(TRIM(p_codigo_rastreo), ''), codigo_rastreo),
        descripcion = COALESCE(NULLIF(TRIM(p_descripcion), ''), descripcion),
        fecha_esperada = COALESCE(p_fecha_esperada, fecha_esperada),
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_id;

    SELECT to_jsonb(vp.*) INTO v_resultado FROM public.vw_paquetes_residente vp WHERE vp.id = p_id;
    RETURN v_resultado;
END;
$$;

-- C) Cancelar paquete esperado
DROP FUNCTION IF EXISTS public.cancelar_paquete_esperado(UUID, UUID);
CREATE OR REPLACE FUNCTION public.cancelar_paquete_esperado(
    p_id UUID,
    p_actor_id UUID
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_paquete RECORD;
BEGIN
    SELECT * INTO v_paquete FROM public.paquetes WHERE id = p_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El paquete no existe.' USING ERRCODE = 'PQ001';
    END IF;

    IF v_paquete.estado != 'esperado' THEN
        RAISE EXCEPTION 'Solo se pueden cancelar paquetes en estado esperado.' USING ERRCODE = 'PQ003';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.vw_vivienda_usuarios 
        WHERE vivienda_id = v_paquete.vivienda_id AND usuario_id = p_actor_id
    ) THEN
        RAISE EXCEPTION 'El actor no cuenta con permisos sobre los paquetes de esta vivienda.' USING ERRCODE = 'PQ002';
    END IF;

    UPDATE public.paquetes
    SET 
        estado = 'cancelado',
        cierre_motivo = 'Cancelado por el residente',
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_id;

    RETURN true;
END;
$$;

-- ==============================================================================
-- 5. STORED PROCEDURES / RPCs: CASETA DE VIGILANCIA
-- ==============================================================================

-- A) Recepción de paquete en Caseta (Nuevo o vinculando pre-registro esperado)
DROP FUNCTION IF EXISTS public.rpc_recibir_paquete(INTEGER, VARCHAR, UUID, UUID, VARCHAR, VARCHAR, VARCHAR, VARCHAR, UUID);
CREATE OR REPLACE FUNCTION public.rpc_recibir_paquete(
    p_vivienda_id INTEGER,
    p_empresa_reparto VARCHAR(50),
    p_recibido_por UUID,
    p_destinatario_id UUID DEFAULT NULL,
    p_destinatario_nombre VARCHAR(100) DEFAULT NULL,
    p_codigo_rastreo VARCHAR(100) DEFAULT NULL,
    p_descripcion VARCHAR(200) DEFAULT NULL,
    p_notas VARCHAR(500) DEFAULT NULL,
    p_paquete_esperado_id UUID DEFAULT NULL
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_condominio_id UUID;
    v_id UUID;
    v_resultado JSONB;
    v_usuario_notificar RECORD;
BEGIN
    -- Validar existencia y condominio de la vivienda
    SELECT condominio_id INTO v_condominio_id FROM public.viviendas WHERE id = p_vivienda_id AND activo = true;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Vivienda no encontrada o inactiva.' USING ERRCODE = 'PQ001';
    END IF;

    -- Si se vincula a un paquete esperado preexistente
    IF p_paquete_esperado_id IS NOT NULL THEN
        SELECT id INTO v_id 
        FROM public.paquetes 
        WHERE id = p_paquete_esperado_id AND vivienda_id = p_vivienda_id AND estado = 'esperado';

        IF NOT FOUND THEN
            RAISE EXCEPTION 'El paquete esperado especificado no existe o ya no se encuentra pendiente.' USING ERRCODE = 'PQ003';
        END IF;

        UPDATE public.paquetes
        SET 
            estado = 'recibido',
            fecha_recepcion = timezone('utc'::text, now()),
            recibido_por = p_recibido_por,
            empresa_reparto = COALESCE(NULLIF(TRIM(p_empresa_reparto), ''), empresa_reparto),
            codigo_rastreo = COALESCE(NULLIF(TRIM(p_codigo_rastreo), ''), codigo_rastreo),
            descripcion = COALESCE(NULLIF(TRIM(p_descripcion), ''), descripcion),
            notas = COALESCE(NULLIF(TRIM(p_notas), ''), notas),
            actualizado_en = timezone('utc'::text, now())
        WHERE id = v_id;
    ELSE
        -- Alta directa en caseta
        INSERT INTO public.paquetes (
            condominio_id,
            vivienda_id,
            destinatario_id,
            destinatario_nombre,
            empresa_reparto,
            codigo_rastreo,
            descripcion,
            estado,
            fecha_recepcion,
            recibido_por,
            notas,
            creado_por
        ) VALUES (
            v_condominio_id,
            p_vivienda_id,
            p_destinatario_id,
            NULLIF(TRIM(p_destinatario_nombre), ''),
            TRIM(p_empresa_reparto),
            NULLIF(TRIM(p_codigo_rastreo), ''),
            NULLIF(TRIM(p_descripcion), ''),
            'recibido',
            timezone('utc'::text, now()),
            p_recibido_por,
            NULLIF(TRIM(p_notas), ''),
            p_recibido_por
        ) RETURNING id INTO v_id;
    END IF;

    -- Emisión de notificaciones internas a residentes vinculados a la vivienda
    FOR v_usuario_notificar IN 
        SELECT usuario_id FROM public.vw_vivienda_usuarios WHERE vivienda_id = p_vivienda_id
    LOOP
        BEGIN
            PERFORM public.alta_notificacion(
                v_usuario_notificar.usuario_id,
                'paquete_llegada',
                'Paquete recibido en caseta',
                'Ha llegado un paquete de ' || TRIM(p_empresa_reparto) || ' a caseta para tu vivienda.',
                '/panel/paqueteria'
            );
        EXCEPTION WHEN OTHERS THEN
            -- Continuar si el módulo de notificaciones no estuviera disponible
        END;
    END LOOP;

    SELECT to_jsonb(vc.*) INTO v_resultado FROM public.vw_paquetes_caseta vc WHERE vc.id = v_id;
    RETURN v_resultado;
END;
$$;

-- B) Entrega de paquete en Caseta (Con cierre de motivo)
DROP FUNCTION IF EXISTS public.rpc_entregar_paquete(UUID, UUID, UUID, VARCHAR, VARCHAR, VARCHAR);
CREATE OR REPLACE FUNCTION public.rpc_entregar_paquete(
    p_id UUID,
    p_entregado_por UUID,
    p_entregado_a UUID DEFAULT NULL,
    p_entregado_a_nombre VARCHAR(100) DEFAULT NULL,
    p_cierre_motivo VARCHAR(200) DEFAULT 'Entregado a residente',
    p_notas VARCHAR(500) DEFAULT NULL
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_paquete RECORD;
    v_resultado JSONB;
BEGIN
    SELECT * INTO v_paquete FROM public.paquetes WHERE id = p_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El paquete no existe.' USING ERRCODE = 'PQ001';
    END IF;

    IF v_paquete.estado != 'recibido' THEN
        RAISE EXCEPTION 'Solo se pueden entregar paquetes que se encuentren en estado recibido.' USING ERRCODE = 'PQ003';
    END IF;

    UPDATE public.paquetes
    SET 
        estado = 'entregado',
        fecha_entrega = timezone('utc'::text, now()),
        entregado_por = p_entregado_por,
        entregado_a = p_entregado_a,
        entregado_a_nombre = COALESCE(NULLIF(TRIM(p_entregado_a_nombre), ''), v_paquete.destinatario_nombre),
        cierre_motivo = COALESCE(NULLIF(TRIM(p_cierre_motivo), ''), 'Entregado a residente'),
        notas = COALESCE(NULLIF(TRIM(p_notas), ''), notas),
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_id;

    SELECT to_jsonb(vh.*) INTO v_resultado FROM public.vw_paquetes_historico vh WHERE vh.id = p_id;
    RETURN v_resultado;
END;
$$;

-- C) Cierre extraordinario / devolución de paquete
DROP FUNCTION IF EXISTS public.rpc_cerrar_paquete_no_entregado(UUID, UUID, VARCHAR, VARCHAR, VARCHAR);
CREATE OR REPLACE FUNCTION public.rpc_cerrar_paquete_no_entregado(
    p_id UUID,
    p_actor_id UUID,
    p_estado VARCHAR(20),
    p_cierre_motivo VARCHAR(200),
    p_notas VARCHAR(500) DEFAULT NULL
)
RETURNS JSONB
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_resultado JSONB;
    v_estado_limpio VARCHAR(20);
BEGIN
    v_estado_limpio := LOWER(TRIM(p_estado));
    IF v_estado_limpio NOT IN ('devuelto', 'cancelado') THEN
        RAISE EXCEPTION 'El estado de cierre extraordinario debe ser devuelto o cancelado.' USING ERRCODE = '22023';
    END IF;

    IF NULLIF(TRIM(p_cierre_motivo), '') IS NULL THEN
        RAISE EXCEPTION 'Es obligatorio especificar el motivo de cierre.' USING ERRCODE = '22023';
    END IF;

    UPDATE public.paquetes
    SET 
        estado = v_estado_limpio,
        cierre_motivo = TRIM(p_cierre_motivo),
        notas = COALESCE(NULLIF(TRIM(p_notas), ''), notas),
        actualizado_en = timezone('utc'::text, now())
    WHERE id = p_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El paquete no existe.' USING ERRCODE = 'PQ001';
    END IF;

    SELECT to_jsonb(vh.*) INTO v_resultado FROM public.vw_paquetes_historico vh WHERE vh.id = p_id;
    RETURN v_resultado;
END;
$$;

-- ==============================================================================
-- 6. PERMISOS Y SEGURIDAD POSTGREST
-- ==============================================================================
REVOKE ALL ON public.paquetes FROM authenticated, anon, service_role;

GRANT SELECT ON public.vw_vivienda_usuarios TO authenticated, service_role;
GRANT SELECT ON public.vw_paquetes_caseta TO authenticated, service_role;
GRANT SELECT ON public.vw_paquetes_residente TO authenticated, service_role;
GRANT SELECT ON public.vw_paquetes_historico TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.alta_paquete_esperado(INTEGER, VARCHAR, UUID, VARCHAR, VARCHAR, VARCHAR, DATE, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cambio_paquete_esperado(UUID, UUID, VARCHAR, UUID, VARCHAR, VARCHAR, VARCHAR, DATE) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.cancelar_paquete_esperado(UUID, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_recibir_paquete(INTEGER, VARCHAR, UUID, UUID, VARCHAR, VARCHAR, VARCHAR, VARCHAR, UUID) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_entregar_paquete(UUID, UUID, UUID, VARCHAR, VARCHAR, VARCHAR) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_cerrar_paquete_no_entregado(UUID, UUID, VARCHAR, VARCHAR, VARCHAR) TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';