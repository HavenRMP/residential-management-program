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

-- ==============================================================================
-- 6. TABLA RELACIONAL Y VISTAS DE SUB-USUARIOS ACTIVOS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.vivienda_subusuarios (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vivienda_id INTEGER NOT NULL REFERENCES public.viviendas(id) ON DELETE CASCADE,
    usuario_id UUID NOT NULL REFERENCES public.usuarios(id) ON DELETE CASCADE,
    titular_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL,
    parentesco VARCHAR(50) NOT NULL DEFAULT 'Familiar',
    activo BOOLEAN NOT NULL DEFAULT true,
    creado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    CONSTRAINT uq_vivienda_subusuarios UNIQUE (vivienda_id, usuario_id)
);

-- Asegurar columnas en caso de existencia previa
ALTER TABLE public.vivienda_subusuarios ADD COLUMN IF NOT EXISTS titular_id UUID REFERENCES public.usuarios(id) ON DELETE SET NULL;
ALTER TABLE public.vivienda_subusuarios ADD COLUMN IF NOT EXISTS parentesco VARCHAR(50) DEFAULT 'Familiar';
ALTER TABLE public.vivienda_subusuarios ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT true;

-- Índices de consulta y rendimiento
CREATE INDEX IF NOT EXISTS idx_vivienda_subusuarios_vivienda ON public.vivienda_subusuarios(vivienda_id);
CREATE INDEX IF NOT EXISTS idx_vivienda_subusuarios_usuario ON public.vivienda_subusuarios(usuario_id);

-- Vista desacoplada para consultas de residentes y backend (VwViviendaSubusuarioDto)
DROP VIEW IF EXISTS public.vw_subusuarios_vivienda CASCADE;
DROP VIEW IF EXISTS public.vw_vivienda_subusuarios CASCADE;

CREATE VIEW public.vw_vivienda_subusuarios AS
SELECT 
    vs.id,
    vs.vivienda_id,
    v.numero_casa,
    v.condominio_id,
    c.nombre AS condominio_nombre,
    vs.titular_id,
    TRIM(u_titular.nombre || ' ' || COALESCE(u_titular.apellidos, '')) AS titular_nombre,
    vs.usuario_id,
    TRIM(u.nombre || ' ' || COALESCE(u.apellidos, '')) AS usuario_nombre,
    u.email AS usuario_email,
    u.telefono AS usuario_telefono,
    vs.parentesco,
    vs.activo,
    vs.creado_en
FROM public.vivienda_subusuarios vs
JOIN public.viviendas v ON v.id = vs.vivienda_id
LEFT JOIN public.condominios c ON c.id = v.condominio_id
JOIN public.usuarios u ON u.id = vs.usuario_id
LEFT JOIN public.usuarios u_titular ON u_titular.id = vs.titular_id;

-- Vista sinónima para total compatibilidad
CREATE OR REPLACE VIEW public.vw_subusuarios_vivienda AS
SELECT * FROM public.vw_vivienda_subusuarios;

-- ==============================================================================
-- 7. STORED PROCEDURE: invitar_subusuario / invitar_subusuario_por_email
-- ==============================================================================
DROP FUNCTION IF EXISTS public.invitar_subusuario(INTEGER, VARCHAR, VARCHAR, UUID);
DROP FUNCTION IF EXISTS public.invitar_subusuario_por_email(INTEGER, VARCHAR, VARCHAR, UUID);

CREATE OR REPLACE FUNCTION public.invitar_subusuario(
    p_vivienda_id INTEGER,
    p_email VARCHAR,
    p_parentesco VARCHAR DEFAULT 'Familiar',
    p_creado_por UUID DEFAULT NULL
)
RETURNS public.vw_invitaciones_subusuarios
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_actor_id UUID;
    v_invitado_id UUID;
    v_subusuarios_activos INTEGER := 0;
    v_invitaciones_pendientes INTEGER := 0;
    v_codigo VARCHAR(8);
    v_invitacion_id UUID;
    v_resultado public.vw_invitaciones_subusuarios;
BEGIN
    -- 1. Resolver ejecutor (parámetro explícito o contexto de sesión)
    v_actor_id := COALESCE(p_creado_por, auth.uid());
    IF v_actor_id IS NULL THEN
        RAISE EXCEPTION 'No se proporcionó un ID de usuario creador válido'
            USING ERRCODE = '42501';
    END IF;

    -- 2. Validar existencia del usuario por correo electrónico
    SELECT id INTO v_invitado_id 
    FROM public.usuarios 
    WHERE LOWER(TRIM(email)) = LOWER(TRIM(p_email));

    IF v_invitado_id IS NULL THEN
        RAISE EXCEPTION 'Usuario con email % no encontrado en el sistema', p_email
            USING ERRCODE = 'P0002';
    END IF;

    -- Validar que no sea auto-invitación
    IF v_invitado_id = v_actor_id THEN
        RAISE EXCEPTION 'No puedes invitarte a ti mismo como sub-usuario'
            USING ERRCODE = 'SU003';
    END IF;

    -- 3. Validar que el invitado no sea el residente titular de esta casa
    IF EXISTS (
        SELECT 1 FROM public.vivienda_residente 
        WHERE vivienda_id = p_vivienda_id AND usuario_id = v_invitado_id
    ) THEN
        RAISE EXCEPTION 'El usuario ya es el residente titular de esta vivienda'
            USING ERRCODE = 'SU002';
    END IF;

    -- 4. Validar que el usuario no sea ya sub-usuario activo
    IF EXISTS (
        SELECT 1 FROM public.vivienda_subusuarios
        WHERE vivienda_id = p_vivienda_id 
          AND usuario_id = v_invitado_id 
          AND activo = true
    ) THEN
        RAISE EXCEPTION 'El usuario ya es sub-usuario activo de esta vivienda'
            USING ERRCODE = '23505';
    END IF;

    -- 5. REGLA ESTRICTA DE CUPO: Máximo 2 entre residentes secundarios activos e invitaciones vigentes
    SELECT COUNT(*) INTO v_subusuarios_activos
    FROM public.vivienda_subusuarios
    WHERE vivienda_id = p_vivienda_id AND activo = true;

    SELECT COUNT(*) INTO v_invitaciones_pendientes
    FROM public.invitaciones_subusuarios
    WHERE vivienda_id = p_vivienda_id 
      AND LOWER(estado) = 'pendiente'
      AND expira_en > now();

    IF (v_subusuarios_activos + v_invitaciones_pendientes) >= 2 THEN
        RAISE EXCEPTION 'Límite de sub-usuarios excedido para esta vivienda (máximo 2 entre residentes activos e invitaciones pendientes)'
            USING ERRCODE = 'SU001';
    END IF;

    -- 6. Validar que no exista ya una invitación pendiente vigente para este mismo usuario
    IF EXISTS (
        SELECT 1 FROM public.invitaciones_subusuarios
        WHERE vivienda_id = p_vivienda_id 
          AND (usuario_id = v_invitado_id OR LOWER(email_invitado) = LOWER(TRIM(p_email)))
          AND LOWER(estado) = 'pendiente'
          AND expira_en > now()
    ) THEN
        RAISE EXCEPTION 'Ya existe una invitación pendiente vigente para este usuario en esta vivienda'
            USING ERRCODE = 'SU002';
    END IF;

    -- 7. Generar código alfanumérico único con resolución de colisiones
    LOOP
        v_codigo := public.fn_generar_codigo_invitacion_subusuario();
        BEGIN
            INSERT INTO public.invitaciones_subusuarios (
                vivienda_id,
                creado_por,
                email_invitado,
                codigo_invitacion,
                estado,
                usuario_id,
                parentesco,
                expira_en
            ) VALUES (
                p_vivienda_id,
                v_actor_id,
                LOWER(TRIM(p_email)),
                v_codigo,
                'pendiente',
                v_invitado_id,
                COALESCE(NULLIF(TRIM(p_parentesco), ''), 'Familiar'),
                timezone('utc'::text, now()) + INTERVAL '24 hours'
            ) RETURNING id INTO v_invitacion_id;

            EXIT;
        EXCEPTION WHEN unique_violation THEN
            -- Reintenta generar otro código si choca con uno pendiente activo
        END;
    END LOOP;

    -- 8. Disparar notificación interna al usuario invitado
    BEGIN
        PERFORM public.alta_notificacion(
            v_invitado_id, 
            'INVITACION', 
            'Invitación a vivienda', 
            'Has recibido una invitación para unirte a una vivienda como co-habitante.', 
            '/panel/invitaciones'
        );
    EXCEPTION WHEN OTHERS THEN
        -- Silenciar si la notificación opcional no está en el entorno
    END;

    -- 9. Retornar fila formateada desde la vista
    SELECT * INTO v_resultado 
    FROM public.vw_invitaciones_subusuarios 
    WHERE id = v_invitacion_id;

    RETURN v_resultado;
END;
$$;

-- Wrapper para compatibilidad retroactiva con la firma anterior del backend
CREATE OR REPLACE FUNCTION public.invitar_subusuario_por_email(
    p_vivienda_id INTEGER,
    p_email VARCHAR,
    p_parentesco VARCHAR,
    p_creado_por UUID
)
RETURNS public.vw_invitaciones_subusuarios
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN public.invitar_subusuario(p_vivienda_id, p_email, p_parentesco, p_creado_por);
END;
$$;
-- ==============================================================================
-- 8. STORED PROCEDURES: responder_invitacion_subusuario Y CANJE
-- ==============================================================================
-- Asegurar que la restricción CHECK admita estados en mayúsculas/minúsculas
ALTER TABLE public.invitaciones_subusuarios DROP CONSTRAINT IF EXISTS invitaciones_subusuarios_estado_check;
ALTER TABLE public.invitaciones_subusuarios ADD CONSTRAINT invitaciones_subusuarios_estado_check 
    CHECK (UPPER(estado) IN ('PENDIENTE', 'ACEPTADA', 'RECHAZADA', 'EXPIRADA', 'CANCELADA', 'REVOCADA'));

-- Soportar ambas columnas de referencia para total compatibilidad
ALTER TABLE public.invitaciones_subusuarios ADD COLUMN IF NOT EXISTS usuario_id UUID REFERENCES public.usuarios(id);
ALTER TABLE public.invitaciones_subusuarios ADD COLUMN IF NOT EXISTS invitado_id UUID REFERENCES public.usuarios(id);

DROP FUNCTION IF EXISTS public.responder_invitacion_subusuario(UUID, UUID, VARCHAR);

CREATE OR REPLACE FUNCTION public.responder_invitacion_subusuario(
    p_invitacion_id UUID,
    p_usuario_id UUID DEFAULT NULL,
    p_respuesta VARCHAR DEFAULT 'ACEPTADA'
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_invitacion public.invitaciones_subusuarios%ROWTYPE;
    v_condominio_id UUID;
    v_respuesta_limpia VARCHAR;
    v_actor_id UUID;
    v_invitado_esperado UUID;
BEGIN
    -- 1. Resolver usuario ejecutor (parámetro explícito o contexto de auth)
    v_actor_id := COALESCE(p_usuario_id, auth.uid());
    IF v_actor_id IS NULL THEN
        RAISE EXCEPTION 'No se proporcionó un ID de usuario válido ni existe una sesión activa'
            USING ERRCODE = '42501';
    END IF;

    -- 2. Limpiar y validar respuesta permitida
    v_respuesta_limpia := UPPER(TRIM(COALESCE(p_respuesta, 'ACEPTADA')));
    IF v_respuesta_limpia NOT IN ('ACEPTADA', 'RECHAZADA') THEN
        RAISE EXCEPTION 'Respuesta no válida. Los valores permitidos son ACEPTADA o RECHAZADA'
            USING ERRCODE = '22023';
    END IF;

    -- 3. Validar existencia de la invitación
    SELECT * INTO v_invitacion
    FROM public.invitaciones_subusuarios
    WHERE id = p_invitacion_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Invitación con ID % no encontrada', p_invitacion_id
            USING ERRCODE = 'P0002';
    END IF;

    -- 4. Validar estado PENDIENTE
    IF UPPER(v_invitacion.estado) <> 'PENDIENTE' THEN
        RAISE EXCEPTION 'La invitación no se encuentra en estado PENDIENTE (estado actual: %)', v_invitacion.estado
            USING ERRCODE = 'SU004';
    END IF;

    -- 5. Validar que quien responde sea el invitado destinatario
    v_invitado_esperado := COALESCE(v_invitacion.usuario_id, v_invitacion.invitado_id);
    IF v_invitado_esperado IS NULL THEN
        SELECT id INTO v_invitado_esperado 
        FROM public.usuarios 
        WHERE LOWER(email) = LOWER(v_invitacion.email_invitado);
    END IF;

    IF v_invitado_esperado IS NOT NULL AND v_invitado_esperado <> v_actor_id THEN
        RAISE EXCEPTION 'El usuario no tiene autorización para responder esta invitación. [invitado esperado: %, recibido: %]', 
            v_invitado_esperado, v_actor_id
            USING ERRCODE = '42501';
    END IF;

    -- 6. Actualizar estado y fecha de respuesta
    UPDATE public.invitaciones_subusuarios
    SET estado = v_respuesta_limpia,
        respondido_en = timezone('utc'::text, now()),
        usuario_id = COALESCE(usuario_id, v_actor_id)
    WHERE id = p_invitacion_id;

    -- 7. Si fue ACEPTADA: registrar en vivienda_subusuarios (sin titular_id) y sincronizar condominio_id
    IF v_respuesta_limpia = 'ACEPTADA' THEN
        INSERT INTO public.vivienda_subusuarios (
            vivienda_id, 
            usuario_id, 
            parentesco, 
            activo
        )
        VALUES (
            v_invitacion.vivienda_id, 
            v_actor_id, 
            COALESCE(v_invitacion.parentesco, 'Familiar'), 
            true
        )
        ON CONFLICT (vivienda_id, usuario_id) DO UPDATE
        SET activo = true,
            parentesco = EXCLUDED.parentesco;

        -- Obtener condominio_id de la casa asignada
        SELECT condominio_id INTO v_condominio_id
        FROM public.viviendas
        WHERE id = v_invitacion.vivienda_id;

        -- Sincronizar condominio_id en el perfil del usuario
        UPDATE public.usuarios
        SET condominio_id = v_condominio_id
        WHERE id = v_actor_id;
    END IF;

    RETURN TRUE;
END;
$$;

-- Stored procedure para redimir/canjear mediante código alfanumérico
DROP FUNCTION IF EXISTS public.redimir_codigo_subusuario(VARCHAR, UUID);
CREATE OR REPLACE FUNCTION public.redimir_codigo_subusuario(
    p_codigo VARCHAR,
    p_usuario_id UUID DEFAULT NULL
)
RETURNS BOOLEAN
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_invitacion_id UUID;
    v_actor_id UUID;
BEGIN
    v_actor_id := COALESCE(p_usuario_id, auth.uid());
    IF v_actor_id IS NULL THEN
        RAISE EXCEPTION 'No se proporcionó un ID de usuario válido ni existe una sesión activa'
            USING ERRCODE = '42501';
    END IF;

    SELECT id INTO v_invitacion_id
    FROM public.invitaciones_subusuarios
    WHERE codigo_invitacion = UPPER(TRIM(p_codigo))
      AND UPPER(estado) = 'PENDIENTE'
      AND expira_en > now();

    IF v_invitacion_id IS NULL THEN
        RAISE EXCEPTION 'El código de invitación no existe, ya fue utilizado o ha expirado'
            USING ERRCODE = 'CD001';
    END IF;

    RETURN public.responder_invitacion_subusuario(v_invitacion_id, v_actor_id, 'ACEPTADA');
END;
$$;