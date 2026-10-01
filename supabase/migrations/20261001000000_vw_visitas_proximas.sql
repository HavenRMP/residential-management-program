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