-- ============================================================================
-- 1. VERSIÓN DEL SISTEMA
-- ============================================================================
INSERT INTO public.version (numero_version, updated_at)
SELECT '1.0.0', now()
WHERE NOT EXISTS (SELECT 1 FROM public.version);

-- ============================================================================
-- 2. CATÁLOGO BASE DE ROLES
-- ============================================================================
INSERT INTO public.roles (id, nombre, descripcion) VALUES
  (1, 'Administrador', 'Control total del sistema residencial'),
  (2, 'Residente', 'Acceso a pagos, reservaciones y avisos'),
  (3, 'Vigilancia', 'Control de accesos y registro de visitas'),
  (4, 'Mantenimiento', 'Atención y resolución de reportes e incidencias')
ON CONFLICT (id) DO UPDATE 
SET nombre = EXCLUDED.nombre,
    descripcion = EXCLUDED.descripcion;

SELECT setval('public.roles_id_seq', (SELECT MAX(id) FROM public.roles));

-- ============================================================================
-- 3. CONDOMINIO MAESTRO (Requerido antes de usuarios y viviendas)
-- ============================================================================
INSERT INTO public.condominios (id, nombre, activo) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'Condominio Residencial Principal', true)
ON CONFLICT (id) DO UPDATE 
SET nombre = EXCLUDED.nombre,
    activo = EXCLUDED.activo;

-- ============================================================================
-- 4. USUARIO EN AUTH.USERS (Satisface la llave foránea usuarios_id_fkey)
-- ============================================================================
INSERT INTO auth.users (id, email, raw_user_meta_data, raw_app_meta_data, aud, role)
VALUES (
  '6754a566-e529-40fb-8610-bd136ec77fd5',
  'admin@haven.com',
  '{"nombre": "Admin", "apellidos": "Principal"}'::jsonb,
  '{"provider": "email", "providers": ["email"]}'::jsonb,
  'authenticated',
  'authenticated'
)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 5. PERFIL DE USUARIO ADMINISTRADOR
-- ============================================================================
INSERT INTO public.usuarios (id, rol_id, email, nombre, apellidos, telefono, condominio_id)
VALUES (
  '6754a566-e529-40fb-8610-bd136ec77fd5',
  1,
  'admin@haven.com',
  'Admin',
  'Principal',
  '4420000000',
  'a0000000-0000-0000-0000-000000000001'
)
ON CONFLICT (id) DO UPDATE 
SET rol_id = EXCLUDED.rol_id,
    email = EXCLUDED.email,
    nombre = EXCLUDED.nombre,
    apellidos = EXCLUDED.apellidos,
    telefono = EXCLUDED.telefono,
    condominio_id = EXCLUDED.condominio_id;

-- ===========================================================================
-- 6. INSERTAR VIVIENDAS CON VÍNCULO A CONDOMINIO
-- ===========================================================================
INSERT INTO public.viviendas (condominio_id, numero_casa, tipo) VALUES
  ('a0000000-0000-0000-0000-000000000001', 'Casa 101', 'Grande'),
  ('a0000000-0000-0000-0000-000000000001', 'Casa 102', 'Mediana'),
  ('a0000000-0000-0000-0000-000000000001', 'Depto 201', 'Chico')
ON CONFLICT (condominio_id, numero_casa) DO NOTHING;

-- ============================================================================
-- 7. ASIGNAR VIVIENDA AL ADMINISTRADOR
-- ============================================================================
INSERT INTO public.vivienda_residente (vivienda_id, usuario_id) VALUES
  (1, '6754a566-e529-40fb-8610-bd136ec77fd5')
ON CONFLICT (vivienda_id, usuario_id) DO NOTHING;
-- ============================================================================
-- 8. AVISOS DE PRUEBA (Vigentes e Históricos)
-- ============================================================================
INSERT INTO public.avisos (
    id,
    condominio_id,
    titulo,
    contenido,
    duracion_dias,
    fecha_expiracion_manual,
    fecha_publicacion,
    activo,
    creado_por,
    creado_en
) VALUES
  -- 1. Vigente estándar (7 días de vigencia por defecto)
  (
    'b0000000-0000-0000-0000-000000000001',
    'a0000000-0000-0000-0000-000000000001',
    'Mantenimiento en alberca y áreas verdes',
    'Se informa que el día viernes las amenidades estarán cerradas por trabajos de limpieza profunda.',
    7,
    NULL,
    timezone('utc'::text, now()),
    true,
    '6754a566-e529-40fb-8610-bd136ec77fd5',
    timezone('utc'::text, now())
  ),

  -- 2. Vigente con fecha manual futura (15 días)
  (
    'b0000000-0000-0000-0000-000000000002',
    'a0000000-0000-0000-0000-000000000001',
    'Asamblea General Ordinaria',
    'Reunión anual de condóminos en el salón de eventos. Favor de confirmar asistencia y revisar orden del día.',
    NULL,
    timezone('utc'::text, now() + interval '15 days'),
    timezone('utc'::text, now()),
    true,
    '6754a566-e529-40fb-8610-bd136ec77fd5',
    timezone('utc'::text, now())
  ),

  -- 3. Histórico: Expirado naturalmente (Publicado hace 10 días, duró 3)
  (
    'b0000000-0000-0000-0000-000000000003',
    'a0000000-0000-0000-0000-000000000001',
    'Corte temporal de suministro de agua',
    'Corte programado por reparación de tubería general en el sector poniente.',
    3,
    NULL,
    timezone('utc'::text, now() - interval '10 days'),
    true,
    '6754a566-e529-40fb-8610-bd136ec77fd5',
    timezone('utc'::text, now() - interval '10 days')
  ),

  -- 4. Histórico: Eliminado lógicamente (activo = false)
  (
    'b0000000-0000-0000-0000-000000000004',
    'a0000000-0000-0000-0000-000000000001',
    'Aviso cancelado por error tipográfico',
    'Este comunicado fue revocado administrativamente tras detectarse un error en los horarios.',
    5,
    NULL,
    timezone('utc'::text, now() - interval '2 days'),
    false,
    '6754a566-e529-40fb-8610-bd136ec77fd5',
    timezone('utc'::text, now() - interval '2 days')
  )
ON CONFLICT (id) DO UPDATE 
SET titulo = EXCLUDED.titulo,
    contenido = EXCLUDED.contenido,
    duracion_dias = EXCLUDED.duracion_dias,
    fecha_expiracion_manual = EXCLUDED.fecha_expiracion_manual,
    activo = EXCLUDED.activo;