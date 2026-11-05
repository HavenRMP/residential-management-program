-- ==============================================================================
-- Archivo: supabase/migrations/20261019000000_modulo_pagos.sql
-- Proyecto: HAVEN
-- Descripción: Módulo completo de Pagos, Cargos, Plantillas, Saldo a Favor,
--              Comprobantes en Storage y Operaciones Atómicas (RPCs).
-- ==============================================================================

-- ==============================================================================
-- 1. TABLA: plantillas_cargo
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.plantillas_cargo (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    condominio_id UUID NOT NULL REFERENCES public.condominios(id) ON DELETE RESTRICT,
    vivienda_id INTEGER NOT NULL REFERENCES public.viviendas(id) ON DELETE RESTRICT,
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('Renta', 'Mantenimiento', 'Servicio', 'Multa', 'Otro')),
    concepto VARCHAR(200) NOT NULL,
    monto NUMERIC(12,2) NOT NULL CHECK (monto > 0),
    dia_vencimiento INTEGER NOT NULL CHECK (dia_vencimiento >= 1 AND dia_vencimiento <= 31),
    vigencia_inicio DATE NOT NULL,
    vigencia_fin DATE,
    responsable_pago VARCHAR(20) NOT NULL DEFAULT 'Residente' CHECK (responsable_pago IN ('Propietario', 'Residente')),
    activa BOOLEAN NOT NULL DEFAULT true,
    creado_por UUID REFERENCES auth.users(id),
    creado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    modificado_por UUID REFERENCES auth.users(id),
    modificado_en TIMESTAMPTZ,
    CONSTRAINT chk_plantilla_vigencia CHECK (vigencia_fin IS NULL OR vigencia_fin >= vigencia_inicio)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_plantillas_vivienda_tipo_concepto_activa 
ON public.plantillas_cargo (vivienda_id, tipo, concepto) 
WHERE activa = true;

CREATE INDEX IF NOT EXISTS idx_plantillas_vivienda ON public.plantillas_cargo (vivienda_id);
CREATE INDEX IF NOT EXISTS idx_plantillas_condominio ON public.plantillas_cargo (condominio_id);

-- ==============================================================================
-- 2. TABLA: cargos
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.cargos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    condominio_id UUID NOT NULL REFERENCES public.condominios(id) ON DELETE RESTRICT,
    vivienda_id INTEGER NOT NULL REFERENCES public.viviendas(id) ON DELETE RESTRICT,
    plantilla_id UUID REFERENCES public.plantillas_cargo(id) ON DELETE SET NULL,
    tipo VARCHAR(20) NOT NULL CHECK (tipo IN ('Renta', 'Mantenimiento', 'Servicio', 'Multa', 'Otro')),
    concepto VARCHAR(200) NOT NULL,
    monto NUMERIC(12,2) NOT NULL CHECK (monto > 0),
    periodo DATE,
    fecha_vencimiento DATE NOT NULL,
    estado VARCHAR(20) NOT NULL DEFAULT 'Pendiente' CHECK (estado IN ('Pendiente', 'Parcial', 'Pagado', 'Cancelado')),
    responsable_pago VARCHAR(20) NOT NULL DEFAULT 'Residente' CHECK (responsable_pago IN ('Propietario', 'Residente')),
    motivo_cancelacion TEXT,
    cancelado_por UUID REFERENCES auth.users(id),
    cancelado_en TIMESTAMPTZ,
    creado_por UUID REFERENCES auth.users(id),
    creado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),

    CONSTRAINT uq_cargos_plantilla_periodo UNIQUE (plantilla_id, periodo),
    CONSTRAINT chk_cargo_periodo_mes CHECK (periodo IS NULL OR periodo = date_trunc('month', periodo)::date),
    CONSTRAINT chk_cargo_periodo_requerido CHECK (
        (tipo IN ('Renta', 'Mantenimiento') AND periodo IS NOT NULL) OR 
        (tipo NOT IN ('Renta', 'Mantenimiento'))
    )
);

CREATE INDEX IF NOT EXISTS idx_cargos_vivienda_estado ON public.cargos (vivienda_id, estado);
CREATE INDEX IF NOT EXISTS idx_cargos_condominio_vencimiento ON public.cargos (condominio_id, fecha_vencimiento);
CREATE INDEX IF NOT EXISTS idx_cargos_periodo ON public.cargos (periodo);

-- ==============================================================================
-- 3. TABLA: pagos
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.pagos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cargo_id UUID NOT NULL REFERENCES public.cargos(id) ON DELETE RESTRICT,
    monto NUMERIC(12,2) NOT NULL CHECK (monto > 0),
    monto_cubierto NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    monto_excedente NUMERIC(12,2) NOT NULL DEFAULT 0.00,
    fecha_pago DATE NOT NULL DEFAULT (timezone('America/Mexico_City', now()))::date,
    metodo VARCHAR(20) NOT NULL CHECK (metodo IN ('Efectivo', 'Transferencia', 'Deposito', 'Otro')),
    referencia VARCHAR(100),
    banco_origen VARCHAR(100),
    estado VARCHAR(30) NOT NULL CHECK (estado IN ('PendienteConfirmacion', 'Confirmado', 'Rechazado', 'Anulado')),
    origen VARCHAR(20) NOT NULL CHECK (origen IN ('Admin', 'Inquilino')),
    comprobante_ruta TEXT,
    comprobante_hash VARCHAR(64),
    es_reversa BOOLEAN NOT NULL DEFAULT false,
    pago_original_id UUID REFERENCES public.pagos(id),
    motivo_rechazo TEXT,
    motivo_anulacion TEXT,
    registrado_por UUID REFERENCES auth.users(id),
    creado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    confirmado_por UUID REFERENCES auth.users(id),
    confirmado_en TIMESTAMPTZ,
    rechazado_por UUID REFERENCES auth.users(id),
    rechazado_en TIMESTAMPTZ,
    anulado_por UUID REFERENCES auth.users(id),
    anulado_en TIMESTAMPTZ
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_pagos_anti_duplicado_ref 
ON public.pagos (referencia, monto, fecha_pago) 
WHERE estado NOT IN ('Rechazado', 'Anulado') AND referencia IS NOT NULL AND trim(referencia) <> '';

CREATE UNIQUE INDEX IF NOT EXISTS idx_pagos_anti_duplicado_hash 
ON public.pagos (comprobante_hash) 
WHERE estado NOT IN ('Rechazado', 'Anulado') AND comprobante_hash IS NOT NULL AND trim(comprobante_hash) <> '';

CREATE INDEX IF NOT EXISTS idx_pagos_cargo ON public.pagos (cargo_id);
CREATE INDEX IF NOT EXISTS idx_pagos_estado ON public.pagos (estado);
CREATE INDEX IF NOT EXISTS idx_pagos_fecha ON public.pagos (fecha_pago);

-- ==============================================================================
-- 4. TABLA: movimientos_saldo_favor
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.movimientos_saldo_favor (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    condominio_id UUID NOT NULL REFERENCES public.condominios(id) ON DELETE RESTRICT,
    vivienda_id INTEGER NOT NULL REFERENCES public.viviendas(id) ON DELETE RESTRICT,
    tipo VARCHAR(25) NOT NULL CHECK (tipo IN ('Abono', 'Aplicacion', 'ReversoAbono', 'ReversoAplicacion')),
    monto NUMERIC(12,2) NOT NULL CHECK (monto > 0),
    pago_id UUID REFERENCES public.pagos(id) ON DELETE SET NULL,
    cargo_id UUID REFERENCES public.cargos(id) ON DELETE SET NULL,
    movimiento_origen_id UUID REFERENCES public.movimientos_saldo_favor(id) ON DELETE RESTRICT,
    motivo TEXT,
    creado_por UUID REFERENCES auth.users(id),
    creado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE INDEX IF NOT EXISTS idx_mov_saldo_vivienda ON public.movimientos_saldo_favor (vivienda_id);
CREATE INDEX IF NOT EXISTS idx_mov_saldo_cargo ON public.movimientos_saldo_favor (cargo_id);
CREATE INDEX IF NOT EXISTS idx_mov_saldo_pago ON public.movimientos_saldo_favor (pago_id);

-- ==============================================================================
-- 5. AUDITORÍA FORENSE Y TRIGGERS
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.plantillas_cargo_bitacora (
    id BIGSERIAL PRIMARY KEY,
    registro_id TEXT NOT NULL,
    operacion VARCHAR(10) NOT NULL CHECK (operacion IN ('INSERT','UPDATE','DELETE')),
    datos_anteriores JSONB,
    datos_nuevos JSONB,
    modificado_por TEXT,
    modificado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.cargos_bitacora (
    id BIGSERIAL PRIMARY KEY,
    registro_id TEXT NOT NULL,
    operacion VARCHAR(10) NOT NULL CHECK (operacion IN ('INSERT','UPDATE','DELETE')),
    datos_anteriores JSONB,
    datos_nuevos JSONB,
    modificado_por TEXT,
    modificado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.pagos_bitacora (
    id BIGSERIAL PRIMARY KEY,
    registro_id TEXT NOT NULL,
    operacion VARCHAR(10) NOT NULL CHECK (operacion IN ('INSERT','UPDATE','DELETE')),
    datos_anteriores JSONB,
    datos_nuevos JSONB,
    modificado_por TEXT,
    modificado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

CREATE TABLE IF NOT EXISTS public.movimientos_saldo_favor_bitacora (
    id BIGSERIAL PRIMARY KEY,
    registro_id TEXT NOT NULL,
    operacion VARCHAR(10) NOT NULL CHECK (operacion IN ('INSERT','UPDATE','DELETE')),
    datos_anteriores JSONB,
    datos_nuevos JSONB,
    modificado_por TEXT,
    modificado_en TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

REVOKE ALL ON public.plantillas_cargo_bitacora FROM authenticated, anon, service_role;
REVOKE ALL ON public.cargos_bitacora FROM authenticated, anon, service_role;
REVOKE ALL ON public.pagos_bitacora FROM authenticated, anon, service_role;
REVOKE ALL ON public.movimientos_saldo_favor_bitacora FROM authenticated, anon, service_role;

DROP TRIGGER IF EXISTS trg_auditoria_plantillas_cargo_ins ON public.plantillas_cargo;
DROP TRIGGER IF EXISTS trg_auditoria_plantillas_cargo_upd ON public.plantillas_cargo;
DROP TRIGGER IF EXISTS trg_auditoria_plantillas_cargo_del ON public.plantillas_cargo;
CREATE TRIGGER trg_auditoria_plantillas_cargo_ins AFTER INSERT ON public.plantillas_cargo FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();
CREATE TRIGGER trg_auditoria_plantillas_cargo_upd BEFORE UPDATE ON public.plantillas_cargo FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();
CREATE TRIGGER trg_auditoria_plantillas_cargo_del BEFORE DELETE ON public.plantillas_cargo FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

DROP TRIGGER IF EXISTS trg_auditoria_cargos_ins ON public.cargos;
DROP TRIGGER IF EXISTS trg_auditoria_cargos_upd ON public.cargos;
DROP TRIGGER IF EXISTS trg_auditoria_cargos_del ON public.cargos;
CREATE TRIGGER trg_auditoria_cargos_ins AFTER INSERT ON public.cargos FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();
CREATE TRIGGER trg_auditoria_cargos_upd BEFORE UPDATE ON public.cargos FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();
CREATE TRIGGER trg_auditoria_cargos_del BEFORE DELETE ON public.cargos FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

DROP TRIGGER IF EXISTS trg_auditoria_pagos_ins ON public.pagos;
DROP TRIGGER IF EXISTS trg_auditoria_pagos_upd ON public.pagos;
DROP TRIGGER IF EXISTS trg_auditoria_pagos_del ON public.pagos;
CREATE TRIGGER trg_auditoria_pagos_ins AFTER INSERT ON public.pagos FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();
CREATE TRIGGER trg_auditoria_pagos_upd BEFORE UPDATE ON public.pagos FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();
CREATE TRIGGER trg_auditoria_pagos_del BEFORE DELETE ON public.pagos FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

DROP TRIGGER IF EXISTS trg_auditoria_mov_saldo_ins ON public.movimientos_saldo_favor;
DROP TRIGGER IF EXISTS trg_auditoria_mov_saldo_upd ON public.movimientos_saldo_favor;
DROP TRIGGER IF EXISTS trg_auditoria_mov_saldo_del ON public.movimientos_saldo_favor;
CREATE TRIGGER trg_auditoria_mov_saldo_ins AFTER INSERT ON public.movimientos_saldo_favor FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();
CREATE TRIGGER trg_auditoria_mov_saldo_upd BEFORE UPDATE ON public.movimientos_saldo_favor FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();
CREATE TRIGGER trg_auditoria_mov_saldo_del BEFORE DELETE ON public.movimientos_saldo_favor FOR EACH ROW EXECUTE FUNCTION public.fn_auditoria();

-- ==============================================================================
-- 6. FUNCIÓN AUXILIAR DE RECÁLCULO DE ESTADO DE CARGO
-- ==============================================================================
CREATE OR REPLACE FUNCTION public._recalcular_estado_cargo(p_cargo_id UUID)
RETURNS VARCHAR(20)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_monto_cargo NUMERIC(12,2);
    v_total_pagos NUMERIC(12,2);
    v_total_saldo NUMERIC(12,2);
    v_total_cubierto NUMERIC(12,2);
    v_nuevo_estado VARCHAR(20);
    v_estado_actual VARCHAR(20);
BEGIN
    SELECT monto, estado INTO v_monto_cargo, v_estado_actual 
    FROM public.cargos 
    WHERE id = p_cargo_id 
    FOR UPDATE;

    IF v_estado_actual = 'Cancelado' THEN
        RETURN 'Cancelado';
    END IF;

    -- Suma de amortizaciones de pagos confirmados no revertidos
    SELECT COALESCE(SUM(monto_cubierto), 0.00) INTO v_total_pagos
    FROM public.pagos
    WHERE cargo_id = p_cargo_id 
      AND estado = 'Confirmado' 
      AND es_reversa = false;

    -- Suma neta de saldo a favor aplicado al cargo (Aplicacion - ReversoAplicacion)
    SELECT COALESCE(
        SUM(
            CASE 
                WHEN tipo = 'Aplicacion' THEN monto 
                WHEN tipo = 'ReversoAplicacion' THEN -monto 
                ELSE 0.00 
            END
        ), 0.00) INTO v_total_saldo
    FROM public.movimientos_saldo_favor
    WHERE cargo_id = p_cargo_id;

    v_total_cubierto := v_total_pagos + v_total_saldo;

    IF v_total_cubierto <= 0 THEN
        v_nuevo_estado := 'Pendiente';
    ELSIF v_total_cubierto < v_monto_cargo THEN
        v_nuevo_estado := 'Parcial';
    ELSE
        v_nuevo_estado := 'Pagado';
    END IF;

    UPDATE public.cargos 
    SET estado = v_nuevo_estado 
    WHERE id = p_cargo_id;

    RETURN v_nuevo_estado;
END;
$$;

-- ==============================================================================
-- 7. VISTAS DE LECTURA
-- ==============================================================================
DROP VIEW IF EXISTS public.vw_cargos CASCADE;
CREATE VIEW public.vw_cargos AS
SELECT 
    c.id,
    c.condominio_id,
    co.nombre AS condominio_nombre,
    c.vivienda_id,
    v.numero_casa,
    c.plantilla_id,
    c.periodo,
    c.tipo,
    c.concepto,
    c.monto,
    (
        COALESCE(pagos_agg.monto_pagado, 0.00) + COALESCE(saldo_agg.saldo_aplicado, 0.00)
    )::NUMERIC(12,2) AS monto_pagado_confirmado,
    CASE 
        WHEN c.estado = 'Cancelado' THEN 0.00
        ELSE GREATEST(
            c.monto - (COALESCE(pagos_agg.monto_pagado, 0.00) + COALESCE(saldo_agg.saldo_aplicado, 0.00)), 
            0.00
        )::NUMERIC(12,2)
    END AS saldo_pendiente,
    c.estado,
    c.fecha_vencimiento,
    (c.fecha_vencimiento < (timezone('America/Mexico_City', now()))::date AND c.estado IN ('Pendiente', 'Parcial')) AS esta_vencido,
    c.responsable_pago,
    c.motivo_cancelacion,
    c.cancelado_por,
    c.cancelado_en,
    c.creado_por,
    c.creado_en
FROM public.cargos c
JOIN public.condominios co ON co.id = c.condominio_id
JOIN public.viviendas v ON v.id = c.vivienda_id
LEFT JOIN (
    SELECT 
        cargo_id,
        SUM(monto_cubierto) AS monto_pagado
    FROM public.pagos
    WHERE estado = 'Confirmado' AND es_reversa = false
    GROUP BY cargo_id
) pagos_agg ON pagos_agg.cargo_id = c.id
LEFT JOIN (
    SELECT 
        cargo_id,
        SUM(
            CASE 
                WHEN tipo = 'Aplicacion' THEN monto 
                WHEN tipo = 'ReversoAplicacion' THEN -monto 
                ELSE 0.00 
            END
        ) AS saldo_aplicado
    FROM public.movimientos_saldo_favor
    WHERE cargo_id IS NOT NULL
    GROUP BY cargo_id
) saldo_agg ON saldo_agg.cargo_id = c.id;

DROP VIEW IF EXISTS public.vw_pagos CASCADE;
CREATE VIEW public.vw_pagos AS
SELECT 
    p.id,
    p.cargo_id,
    c.condominio_id,
    c.vivienda_id,
    v.numero_casa,
    c.tipo AS cargo_tipo,
    c.concepto AS cargo_concepto,
    p.monto,
    p.monto_cubierto,
    p.monto_excedente,
    p.fecha_pago,
    p.metodo,
    p.referencia,
    p.banco_origen,
    p.estado,
    p.origen,
    (p.comprobante_ruta IS NOT NULL AND trim(p.comprobante_ruta) <> '') AS tiene_comprobante,
    p.comprobante_ruta,
    p.comprobante_hash,
    p.es_reversa,
    p.pago_original_id,
    p.motivo_rechazo,
    p.motivo_anulacion,
    p.registrado_por,
    p.creado_en,
    p.confirmado_por,
    p.confirmado_en,
    p.rechazado_por,
    p.rechazado_en,
    p.anulado_por,
    p.anulado_en
FROM public.pagos p
JOIN public.cargos c ON c.id = p.cargo_id
JOIN public.viviendas v ON v.id = c.vivienda_id;

DROP VIEW IF EXISTS public.vw_plantillas_cargo CASCADE;
CREATE VIEW public.vw_plantillas_cargo AS
SELECT 
    pc.id,
    pc.condominio_id,
    co.nombre AS condominio_nombre,
    pc.vivienda_id,
    v.numero_casa,
    pc.tipo,
    pc.concepto,
    pc.monto,
    pc.monto AS monto_base,
    pc.dia_vencimiento,
    pc.vigencia_inicio,
    pc.vigencia_fin,
    pc.responsable_pago,
    pc.activa,
    pc.creado_por,
    pc.creado_en,
    pc.modificado_por,
    pc.modificado_en
FROM public.plantillas_cargo pc
JOIN public.condominios co ON co.id = pc.condominio_id
JOIN public.viviendas v ON v.id = pc.vivienda_id;

DROP VIEW IF EXISTS public.vw_movimientos_saldo_favor CASCADE;
CREATE VIEW public.vw_movimientos_saldo_favor AS
SELECT 
    m.id,
    m.condominio_id,
    m.vivienda_id,
    m.tipo,
    m.monto,
    CASE 
        WHEN m.tipo IN ('Abono', 'ReversoAplicacion') THEN m.monto
        ELSE -m.monto
    END AS monto_con_signo,
    m.pago_id,
    m.cargo_id,
    m.movimiento_origen_id,
    m.motivo,
    m.creado_por,
    m.creado_en
FROM public.movimientos_saldo_favor m;

DROP VIEW IF EXISTS public.v_saldo_vivienda CASCADE;
CREATE VIEW public.v_saldo_vivienda AS
SELECT 
    v.id AS vivienda_id,
    v.condominio_id,
    v.numero_casa,
    COALESCE(SUM(c.saldo_pendiente) FILTER (WHERE c.estado IN ('Pendiente', 'Parcial')), 0.00)::NUMERIC(12,2) AS total_pendiente,
    COALESCE(SUM(c.saldo_pendiente) FILTER (WHERE c.estado IN ('Pendiente', 'Parcial') AND c.esta_vencido = true), 0.00)::NUMERIC(12,2) AS total_vencido,
    COUNT(c.id) FILTER (WHERE c.estado IN ('Pendiente', 'Parcial'))::INTEGER AS total_cargos_abiertos,
    COALESCE((
        SELECT SUM(
            CASE 
                WHEN tipo IN ('Abono', 'ReversoAplicacion') THEN monto 
                ELSE -monto 
            END
        )
        FROM public.movimientos_saldo_favor ms
        WHERE ms.vivienda_id = v.id
    ), 0.00)::NUMERIC(12,2) AS saldo_a_favor
FROM public.viviendas v
LEFT JOIN public.vw_cargos c ON c.vivienda_id = v.id
WHERE v.activo = true
GROUP BY v.id, v.condominio_id, v.numero_casa;

-- ==============================================================================
-- 8. OPERACIONES ATÓMICAS (RPCs)
-- ==============================================================================

-- A) rpc_registrar_pago
CREATE OR REPLACE FUNCTION public.rpc_registrar_pago(
    p_cargo_id UUID,
    p_monto NUMERIC,
    p_fecha_pago DATE,
    p_metodo TEXT,
    p_origen TEXT,
    p_estado TEXT,
    p_referencia TEXT DEFAULT NULL,
    p_banco_origen TEXT DEFAULT NULL,
    p_comprobante_ruta TEXT DEFAULT NULL,
    p_comprobante_hash TEXT DEFAULT NULL,
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_cargo RECORD;
    v_pago RECORD;
    v_mov_saldo RECORD;
    v_estado_inicial VARCHAR(30);
    v_actor UUID;
    v_saldo_pendiente NUMERIC(12,2);
    v_cubierto NUMERIC(12,2) := 0.00;
    v_excedente NUMERIC(12,2) := 0.00;
    v_saldo_favor_actual NUMERIC(12,2);
    v_resultado JSONB;
BEGIN
    v_actor := COALESCE(p_actor_id, auth.uid());

    SELECT * INTO v_cargo FROM public.cargos WHERE id = p_cargo_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El cargo especificado no existe' USING ERRCODE = 'PG000';
    END IF;

    IF v_cargo.estado = 'Cancelado' THEN
        RAISE EXCEPTION 'No se puede registrar un pago en un cargo cancelado' USING ERRCODE = 'PG001';
    END IF;

    v_estado_inicial := p_estado;
    IF v_estado_inicial NOT IN ('Confirmado', 'PendienteConfirmacion') THEN
        RAISE EXCEPTION 'Estado inicial inválido para registro de pago' USING ERRCODE = 'PG001';
    END IF;

    -- Calcular cobertura y excedente
    SELECT saldo_pendiente INTO v_saldo_pendiente FROM public.vw_cargos WHERE id = p_cargo_id;

    IF v_estado_inicial = 'Confirmado' THEN
        IF p_monto <= v_saldo_pendiente THEN
            v_cubierto := p_monto;
            v_excedente := 0.00;
        ELSE
            v_cubierto := v_saldo_pendiente;
            v_excedente := p_monto - v_saldo_pendiente;
        END IF;
    ELSE
        -- Si queda pendiente de confirmación, el monto cubierto se asienta al confirmar
        v_cubierto := LEAST(p_monto, v_saldo_pendiente);
        v_excedente := GREATEST(p_monto - v_saldo_pendiente, 0.00);
    END IF;

    INSERT INTO public.pagos (
        cargo_id,
        monto,
        monto_cubierto,
        monto_excedente,
        fecha_pago,
        metodo,
        referencia,
        banco_origen,
        estado,
        origen,
        comprobante_ruta,
        comprobante_hash,
        es_reversa,
        registrado_por,
        confirmado_por,
        confirmado_en
    ) VALUES (
        p_cargo_id,
        p_monto,
        v_cubierto,
        v_excedente,
        p_fecha_pago,
        p_metodo,
        p_referencia,
        p_banco_origen,
        v_estado_inicial,
        p_origen,
        p_comprobante_ruta,
        p_comprobante_hash,
        false,
        v_actor,
        CASE WHEN v_estado_inicial = 'Confirmado' THEN v_actor ELSE NULL END,
        CASE WHEN v_estado_inicial = 'Confirmado' THEN timezone('utc'::text, now()) ELSE NULL END
    ) RETURNING * INTO v_pago;

    -- Si fue confirmado y hay excedente, acreditar a saldo a favor
    IF v_estado_inicial = 'Confirmado' THEN
        IF v_excedente > 0 THEN
            INSERT INTO public.movimientos_saldo_favor (
                condominio_id, vivienda_id, tipo, monto, pago_id, cargo_id, motivo, creado_por
            ) VALUES (
                v_cargo.condominio_id, v_cargo.vivienda_id, 'Abono', v_excedente, v_pago.id, v_cargo.id,
                'Excedente acreditado automáticamente de pago confirmado', v_actor
            ) RETURNING * INTO v_mov_saldo;
        END IF;

        PERFORM public._recalcular_estado_cargo(p_cargo_id);
    END IF;

    SELECT saldo_a_favor INTO v_saldo_favor_actual 
    FROM public.v_saldo_vivienda 
    WHERE vivienda_id = v_cargo.vivienda_id;

    SELECT jsonb_build_object(
        'pago', to_jsonb(v_pago),
        'cargo', (SELECT to_jsonb(vc) FROM public.vw_cargos vc WHERE vc.id = p_cargo_id),
        'movimiento_saldo', CASE WHEN v_mov_saldo.id IS NOT NULL THEN to_jsonb(v_mov_saldo) ELSE NULL END,
        'saldo_a_favor', COALESCE(v_saldo_favor_actual, 0.00)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$$;

-- B) rpc_confirmar_pago
CREATE OR REPLACE FUNCTION public.rpc_confirmar_pago(
    p_pago_id UUID,
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_pago RECORD;
    v_cargo RECORD;
    v_mov_saldo RECORD;
    v_actor UUID;
    v_saldo_pendiente NUMERIC(12,2);
    v_cubierto NUMERIC(12,2);
    v_excedente NUMERIC(12,2);
    v_saldo_favor_actual NUMERIC(12,2);
    v_resultado JSONB;
BEGIN
    v_actor := COALESCE(p_actor_id, auth.uid());

    SELECT * INTO v_pago FROM public.pagos WHERE id = p_pago_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El pago especificado no existe' USING ERRCODE = 'PG000';
    END IF;

    IF v_pago.estado <> 'PendienteConfirmacion' THEN
        RAISE EXCEPTION 'Solo se pueden confirmar pagos en estado PendienteConfirmacion' USING ERRCODE = 'PG002';
    END IF;

    SELECT * INTO v_cargo FROM public.cargos WHERE id = v_pago.cargo_id FOR UPDATE;
    IF v_cargo.estado = 'Cancelado' THEN
        RAISE EXCEPTION 'No se puede confirmar un pago sobre un cargo cancelado' USING ERRCODE = 'PG001';
    END IF;

    SELECT saldo_pendiente INTO v_saldo_pendiente FROM public.vw_cargos WHERE id = v_cargo.id;

    IF v_pago.monto <= v_saldo_pendiente THEN
        v_cubierto := v_pago.monto;
        v_excedente := 0.00;
    ELSE
        v_cubierto := v_saldo_pendiente;
        v_excedente := v_pago.monto - v_saldo_pendiente;
    END IF;

    UPDATE public.pagos 
    SET estado = 'Confirmado',
        monto_cubierto = v_cubierto,
        monto_excedente = v_excedente,
        confirmado_por = v_actor,
        confirmado_en = timezone('utc'::text, now())
    WHERE id = p_pago_id
    RETURNING * INTO v_pago;

    IF v_excedente > 0 THEN
        INSERT INTO public.movimientos_saldo_favor (
            condominio_id, vivienda_id, tipo, monto, pago_id, cargo_id, motivo, creado_por
        ) VALUES (
            v_cargo.condominio_id, v_cargo.vivienda_id, 'Abono', v_excedente, v_pago.id, v_cargo.id,
            'Excedente acreditado automáticamente de pago confirmado', v_actor
        ) RETURNING * INTO v_mov_saldo;
    END IF;

    PERFORM public._recalcular_estado_cargo(v_cargo.id);

    SELECT saldo_a_favor INTO v_saldo_favor_actual 
    FROM public.v_saldo_vivienda 
    WHERE vivienda_id = v_cargo.vivienda_id;

    SELECT jsonb_build_object(
        'pago', to_jsonb(v_pago),
        'cargo', (SELECT to_jsonb(vc) FROM public.vw_cargos vc WHERE vc.id = v_cargo.id),
        'movimiento_saldo', CASE WHEN v_mov_saldo.id IS NOT NULL THEN to_jsonb(v_mov_saldo) ELSE NULL END,
        'saldo_a_favor', COALESCE(v_saldo_favor_actual, 0.00)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$$;

-- C) rpc_rechazar_pago
CREATE OR REPLACE FUNCTION public.rpc_rechazar_pago(
    p_pago_id UUID,
    p_motivo TEXT,
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_pago RECORD;
    v_actor UUID;
BEGIN
    v_actor := COALESCE(p_actor_id, auth.uid());

    SELECT * INTO v_pago FROM public.pagos WHERE id = p_pago_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El pago especificado no existe' USING ERRCODE = 'PG000';
    END IF;

    IF v_pago.estado <> 'PendienteConfirmacion' THEN
        RAISE EXCEPTION 'Solo se pueden rechazar pagos en estado PendienteConfirmacion' USING ERRCODE = 'PG003';
    END IF;

    UPDATE public.pagos 
    SET estado = 'Rechazado',
        motivo_rechazo = p_motivo,
        rechazado_por = v_actor,
        rechazado_en = timezone('utc'::text, now())
    WHERE id = p_pago_id
    RETURNING * INTO v_pago;

    RETURN jsonb_build_object('pago', to_jsonb(v_pago));
END;
$$;

-- D) rpc_anular_pago
CREATE OR REPLACE FUNCTION public.rpc_anular_pago(
    p_pago_id UUID,
    p_motivo TEXT,
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_pago_orig RECORD;
    v_pago_reversa RECORD;
    v_cargo RECORD;
    v_mov_abono RECORD;
    v_mov_saldo_reverso RECORD;
    v_actor UUID;
    v_saldo_favor_actual NUMERIC(12,2);
    v_resultado JSONB;
BEGIN
    v_actor := COALESCE(p_actor_id, auth.uid());

    SELECT * INTO v_pago_orig FROM public.pagos WHERE id = p_pago_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El pago especificado no existe' USING ERRCODE = 'PG000';
    END IF;

    IF v_pago_orig.estado <> 'Confirmado' THEN
        RAISE EXCEPTION 'Solo se pueden anular pagos en estado Confirmado' USING ERRCODE = 'PG004';
    END IF;

    SELECT * INTO v_cargo FROM public.cargos WHERE id = v_pago_orig.cargo_id FOR UPDATE;

    -- Validar si el pago generó un abono que ya fue consumido
    SELECT * INTO v_mov_abono 
    FROM public.movimientos_saldo_favor 
    WHERE pago_id = p_pago_id AND tipo = 'Abono';

    IF FOUND THEN
        SELECT saldo_a_favor INTO v_saldo_favor_actual 
        FROM public.v_saldo_vivienda 
        WHERE vivienda_id = v_cargo.vivienda_id;

        IF v_saldo_favor_actual < v_mov_abono.monto THEN
            RAISE EXCEPTION 'Saldo a favor insuficiente para anular el pago (el excedente ya fue utilizado)' USING ERRCODE = 'PG007';
        END IF;

        INSERT INTO public.movimientos_saldo_favor (
            condominio_id, vivienda_id, tipo, monto, pago_id, cargo_id, movimiento_origen_id, motivo, creado_por
        ) VALUES (
            v_cargo.condominio_id, v_cargo.vivienda_id, 'ReversoAbono', v_mov_abono.monto, p_pago_id, v_cargo.id,
            v_mov_abono.id, 'Reverso de abono por anulación de pago: ' || TRIM(p_motivo), v_actor
        ) RETURNING * INTO v_mov_saldo_reverso;
    END IF;

    -- 1. Marcar pago original como Anulado
    UPDATE public.pagos 
    SET estado = 'Anulado',
        motivo_anulacion = p_motivo,
        anulado_por = v_actor,
        anulado_en = timezone('utc'::text, now())
    WHERE id = p_pago_id
    RETURNING * INTO v_pago_orig;

    -- 2. Crear fila inmutable de reversa contable
    INSERT INTO public.pagos (
        cargo_id,
        monto,
        monto_cubierto,
        monto_excedente,
        fecha_pago,
        metodo,
        referencia,
        banco_origen,
        estado,
        origen,
        es_reversa,
        pago_original_id,
        motivo_anulacion,
        registrado_por,
        creado_en,
        confirmado_por,
        confirmado_en
    ) VALUES (
        v_pago_orig.cargo_id,
        v_pago_orig.monto,
        v_pago_orig.monto_cubierto,
        v_pago_orig.monto_excedente,
        (timezone('America/Mexico_City', now()))::date,
        v_pago_orig.metodo,
        CONCAT('REV-', COALESCE(v_pago_orig.referencia, substr(v_pago_orig.id::text, 1, 8))),
        v_pago_orig.banco_origen,
        'Confirmado',
        'Admin',
        true,
        v_pago_orig.id,
        p_motivo,
        v_actor,
        timezone('utc'::text, now()),
        v_actor,
        timezone('utc'::text, now())
    ) RETURNING * INTO v_pago_reversa;

    -- 3. Recalcular estado del cargo
    PERFORM public._recalcular_estado_cargo(v_cargo.id);

    SELECT saldo_a_favor INTO v_saldo_favor_actual 
    FROM public.v_saldo_vivienda 
    WHERE vivienda_id = v_cargo.vivienda_id;

    SELECT jsonb_build_object(
        'pago_anulado', to_jsonb(v_pago_orig),
        'pago_reversa', to_jsonb(v_pago_reversa),
        'cargo', (SELECT to_jsonb(vc) FROM public.vw_cargos vc WHERE vc.id = v_cargo.id),
        'movimiento_saldo', CASE WHEN v_mov_saldo_reverso.id IS NOT NULL THEN to_jsonb(v_mov_saldo_reverso) ELSE NULL END,
        'saldo_a_favor', COALESCE(v_saldo_favor_actual, 0.00)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$$;

-- E) rpc_cancelar_cargo
CREATE OR REPLACE FUNCTION public.rpc_cancelar_cargo(
    p_cargo_id UUID,
    p_motivo TEXT,
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_cargo RECORD;
    v_tiene_pagos BOOLEAN;
    v_tiene_saldo BOOLEAN;
    v_actor UUID;
BEGIN
    v_actor := COALESCE(p_actor_id, auth.uid());

    SELECT * INTO v_cargo FROM public.cargos WHERE id = p_cargo_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El cargo especificado no existe' USING ERRCODE = 'PG000';
    END IF;

    IF v_cargo.estado = 'Cancelado' THEN
        RAISE EXCEPTION 'El cargo ya se encuentra cancelado' USING ERRCODE = 'PG005';
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM public.pagos 
        WHERE cargo_id = p_cargo_id 
          AND estado IN ('Confirmado', 'PendienteConfirmacion')
    ) INTO v_tiene_pagos;

    SELECT EXISTS (
        SELECT 1 FROM public.movimientos_saldo_favor 
        WHERE cargo_id = p_cargo_id AND tipo = 'Aplicacion'
    ) INTO v_tiene_saldo;

    IF v_tiene_pagos OR v_tiene_saldo THEN
        RAISE EXCEPTION 'No se puede cancelar un cargo con pagos o aplicaciones de saldo vigentes' USING ERRCODE = 'PG006';
    END IF;

    UPDATE public.cargos 
    SET estado = 'Cancelado',
        motivo_cancelacion = p_motivo,
        cancelado_por = v_actor,
        cancelado_en = timezone('utc'::text, now())
    WHERE id = p_cargo_id
    RETURNING * INTO v_cargo;

    RETURN jsonb_build_object('cargo', to_jsonb(v_cargo));
END;
$$;

-- F) rpc_aplicar_saldo_favor
CREATE OR REPLACE FUNCTION public.rpc_aplicar_saldo_favor(
    p_cargo_id UUID,
    p_monto NUMERIC,
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_cargo RECORD;
    v_saldo_vivienda RECORD;
    v_mov RECORD;
    v_actor UUID;
    v_saldo_pendiente NUMERIC(12,2);
    v_saldo_favor_final NUMERIC(12,2);
    v_resultado JSONB;
BEGIN
    v_actor := COALESCE(p_actor_id, auth.uid());

    IF p_monto <= 0 THEN
        RAISE EXCEPTION 'El monto a aplicar debe ser mayor a 0' USING ERRCODE = 'PG008';
    END IF;

    SELECT * INTO v_cargo FROM public.cargos WHERE id = p_cargo_id FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'El cargo especificado no existe' USING ERRCODE = 'PG000';
    END IF;

    IF v_cargo.estado = 'Cancelado' THEN
        RAISE EXCEPTION 'No se puede aplicar saldo a un cargo cancelado' USING ERRCODE = 'PG001';
    END IF;

    IF v_cargo.estado = 'Pagado' THEN
        RAISE EXCEPTION 'El cargo ya se encuentra totalmente pagado' USING ERRCODE = 'PG010';
    END IF;

    -- Bloqueo a nivel vivienda para evitar concurrencia
    SELECT * INTO v_saldo_vivienda 
    FROM public.v_saldo_vivienda 
    WHERE vivienda_id = v_cargo.vivienda_id;

    IF v_saldo_vivienda.saldo_a_favor < p_monto THEN
        RAISE EXCEPTION 'Saldo a favor insuficiente para cubrir el monto especificado' USING ERRCODE = 'PG007';
    END IF;

    SELECT saldo_pendiente INTO v_saldo_pendiente 
    FROM public.vw_cargos 
    WHERE id = p_cargo_id;

    IF p_monto > v_saldo_pendiente THEN
        RAISE EXCEPTION 'El monto a aplicar excede el saldo pendiente del cargo' USING ERRCODE = 'PG008';
    END IF;

    INSERT INTO public.movimientos_saldo_favor (
        condominio_id, vivienda_id, tipo, monto, cargo_id, motivo, creado_por
    ) VALUES (
        v_cargo.condominio_id, v_cargo.vivienda_id, 'Aplicacion', p_monto, p_cargo_id,
        'Aplicación manual de saldo a favor', v_actor
    ) RETURNING * INTO v_mov;

    PERFORM public._recalcular_estado_cargo(p_cargo_id);

    SELECT saldo_a_favor INTO v_saldo_favor_final 
    FROM public.v_saldo_vivienda 
    WHERE vivienda_id = v_cargo.vivienda_id;

    SELECT jsonb_build_object(
        'movimiento', to_jsonb(v_mov),
        'cargo', (SELECT to_jsonb(vc) FROM public.vw_cargos vc WHERE vc.id = p_cargo_id),
        'saldo_a_favor', COALESCE(v_saldo_favor_final, 0.00)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$$;

-- G) rpc_revertir_aplicacion_saldo
CREATE OR REPLACE FUNCTION public.rpc_revertir_aplicacion_saldo(
    p_movimiento_id UUID,
    p_motivo TEXT,
    p_actor_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_mov_orig RECORD;
    v_mov_reverso RECORD;
    v_cargo RECORD;
    v_actor UUID;
    v_saldo_favor_final NUMERIC(12,2);
    v_resultado JSONB;
BEGIN
    v_actor := COALESCE(p_actor_id, auth.uid());

    IF NULLIF(TRIM(p_motivo), '') IS NULL THEN
        RAISE EXCEPTION 'El motivo de reversión es obligatorio' USING ERRCODE = 'PG009';
    END IF;

    SELECT * INTO v_mov_orig 
    FROM public.movimientos_saldo_favor 
    WHERE id = p_movimiento_id FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'El movimiento especificado no existe' USING ERRCODE = 'PG000';
    END IF;

    IF v_mov_orig.tipo <> 'Aplicacion' THEN
        RAISE EXCEPTION 'Solo se pueden revertir movimientos de tipo Aplicacion' USING ERRCODE = 'PG009';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.movimientos_saldo_favor 
        WHERE movimiento_origen_id = p_movimiento_id AND tipo = 'ReversoAplicacion'
    ) THEN
        RAISE EXCEPTION 'El movimiento ya fue revertido con anterioridad' USING ERRCODE = 'PG009';
    END IF;

    SELECT * INTO v_cargo FROM public.cargos WHERE id = v_mov_orig.cargo_id FOR UPDATE;

    INSERT INTO public.movimientos_saldo_favor (
        condominio_id, vivienda_id, tipo, monto, cargo_id, movimiento_origen_id, motivo, creado_por
    ) VALUES (
        v_mov_orig.condominio_id, v_mov_orig.vivienda_id, 'ReversoAplicacion', v_mov_orig.monto,
        v_mov_orig.cargo_id, p_movimiento_id, TRIM(p_motivo), v_actor
    ) RETURNING * INTO v_mov_reverso;

    IF v_cargo.id IS NOT NULL THEN
        PERFORM public._recalcular_estado_cargo(v_cargo.id);
    END IF;

    SELECT saldo_a_favor INTO v_saldo_favor_final 
    FROM public.v_saldo_vivienda 
    WHERE vivienda_id = v_mov_orig.vivienda_id;

    SELECT jsonb_build_object(
        'movimiento', to_jsonb(v_mov_reverso),
        'cargo', CASE WHEN v_cargo.id IS NOT NULL THEN (SELECT to_jsonb(vc) FROM public.vw_cargos vc WHERE vc.id = v_cargo.id) ELSE NULL END,
        'saldo_a_favor', COALESCE(v_saldo_favor_final, 0.00)
    ) INTO v_resultado;

    RETURN v_resultado;
END;
$$;

-- ==============================================================================
-- 9. PERMISOS Y SEGURIDAD POSTGREST
-- ==============================================================================
ALTER TABLE public.plantillas_cargo ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cargos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pagos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.movimientos_saldo_favor ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.plantillas_cargo FROM anon, authenticated;
REVOKE ALL ON TABLE public.cargos FROM anon, authenticated;
REVOKE ALL ON TABLE public.pagos FROM anon, authenticated;
REVOKE ALL ON TABLE public.movimientos_saldo_favor FROM anon, authenticated;

GRANT SELECT ON public.vw_cargos TO authenticated, service_role;
GRANT SELECT ON public.vw_pagos TO authenticated, service_role;
GRANT SELECT ON public.vw_plantillas_cargo TO authenticated, service_role;
GRANT SELECT ON public.vw_movimientos_saldo_favor TO authenticated, service_role;
GRANT SELECT ON public.v_saldo_vivienda TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.rpc_registrar_pago TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_confirmar_pago TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_rechazar_pago TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_anular_pago TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_cancelar_cargo TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_aplicar_saldo_favor TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.rpc_revertir_aplicacion_saldo TO authenticated, service_role;

-- ==============================================================================
-- 10. STORAGE BUCKET: comprobantes
-- ==============================================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'comprobantes',
    'comprobantes',
    false,
    5242880,
    ARRAY['image/jpeg', 'image/png', 'application/pdf']
)
ON CONFLICT (id) DO UPDATE SET
    public = false,
    file_size_limit = 5242880,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'application/pdf'];

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE schemaname = 'storage' 
          AND tablename = 'objects' 
          AND policyname = 'Acceso administrativo a comprobantes'
    ) THEN
        CREATE POLICY "Acceso administrativo a comprobantes" ON storage.objects
        FOR ALL TO authenticated
        USING (
            bucket_id = 'comprobantes' AND 
            EXISTS (SELECT 1 FROM public.usuarios WHERE id = auth.uid() AND rol_id = 1)
        );
    END IF;
END $$;

NOTIFY pgrst, 'reload schema';