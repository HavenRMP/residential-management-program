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