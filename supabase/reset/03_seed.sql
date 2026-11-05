-- ==============================================================================
-- HAVEN - Paso 3 de 3: datos semilla y cuentas
-- ------------------------------------------------------------------------------
-- Carga las cuentas de auth y los datos de todos los modulos, y garantiza la
-- cuenta de administrador:  admin@haven.com / AdminPassword1
-- Requiere haber ejecutado antes 01_tirar.sql y 02_recrear.sql.
--
-- Orden de ejecucion: 01_tirar.sql -> 02_recrear.sql -> 03_seed.sql
-- Cada archivo corre en su propia transaccion: si algo falla, ese paso no se aplica.
-- Ejecutar desde el SQL Editor de Supabase o con:
--   psql "<connection string session pooler>" -v ON_ERROR_STOP=1 -f supabase/reset/<archivo>
-- ==============================================================================

BEGIN;

-- 3.1 Carga de datos (triggers y llaves foraneas en pausa durante la carga)
SET session_replication_role = replica;

-- Cuentas de autenticacion
--
-- PostgreSQL database dump
--


-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.11 (Debian 17.11-1.pgdg13+2)


--
-- Data for Name: users; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, invited_at, confirmation_token, confirmation_sent_at, recovery_token, recovery_sent_at, email_change_token_new, email_change, email_change_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at, phone, phone_confirmed_at, phone_change, phone_change_token, phone_change_sent_at, email_change_token_current, email_change_confirm_status, banned_until, reauthentication_token, reauthentication_sent_at, is_sso_user, deleted_at, is_anonymous) VALUES ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000005', 'authenticated', 'authenticated', 'invitado@haven.com', '$2a$06$qrLmuX02HPiw9PxkDZ5.wOTSbDjzn4MYc9C1RCLlMZGy1/D.Estu2', '2026-11-05 20:00:51.617216+00', NULL, '', NULL, '', NULL, '', '', NULL, NULL, '{"rol": "Residente", "rol_id": 2, "provider": "email", "providers": ["email"], "condominio_id": "a0000000-0000-0000-0000-000000000001"}', '{"nombre": "Sofía", "telefono": "5550000005", "apellidos": "Invitada"}', NULL, '2026-11-05 20:00:51.617216+00', '2026-11-05 20:00:51.617216+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false);
INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, invited_at, confirmation_token, confirmation_sent_at, recovery_token, recovery_sent_at, email_change_token_new, email_change, email_change_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at, phone, phone_confirmed_at, phone_change, phone_change_token, phone_change_sent_at, email_change_token_current, email_change_confirm_status, banned_until, reauthentication_token, reauthentication_sent_at, is_sso_user, deleted_at, is_anonymous) VALUES ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000001', 'authenticated', 'authenticated', 'admin@haven.com', '$2a$06$kWorGt0tHGdnoHu7eOcY/OPMptz9n/HI7.cn5Ubb7k6H8HMBpadJ6', '2026-11-05 20:00:51.617216+00', NULL, '', NULL, '', NULL, '', '', NULL, '2026-11-05 21:26:32.33781+00', '{"rol": "Administrador", "rol_id": 1, "provider": "email", "providers": ["email"], "condominio_id": "a0000000-0000-0000-0000-000000000001"}', '{"nombre": "Carlos", "telefono": "5550000001", "apellidos": "Administrador"}', NULL, '2026-11-05 20:00:51.617216+00', '2026-11-05 21:26:32.360165+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false);
INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, invited_at, confirmation_token, confirmation_sent_at, recovery_token, recovery_sent_at, email_change_token_new, email_change, email_change_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at, phone, phone_confirmed_at, phone_change, phone_change_token, phone_change_sent_at, email_change_token_current, email_change_confirm_status, banned_until, reauthentication_token, reauthentication_sent_at, is_sso_user, deleted_at, is_anonymous) VALUES ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000003', 'authenticated', 'authenticated', 'residente@haven.com', '$2a$06$qrLmuX02HPiw9PxkDZ5.wOTSbDjzn4MYc9C1RCLlMZGy1/D.Estu2', '2026-11-05 20:00:51.617216+00', NULL, '', NULL, '', NULL, '', '', NULL, '2026-11-05 21:26:33.004133+00', '{"rol": "Residente", "rol_id": 2, "provider": "email", "providers": ["email"], "condominio_id": "a0000000-0000-0000-0000-000000000001"}', '{"nombre": "Ana", "telefono": "5550000003", "apellidos": "Titular"}', NULL, '2026-11-05 20:00:51.617216+00', '2026-11-05 21:26:33.00673+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false);
INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, invited_at, confirmation_token, confirmation_sent_at, recovery_token, recovery_sent_at, email_change_token_new, email_change, email_change_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at, phone, phone_confirmed_at, phone_change, phone_change_token, phone_change_sent_at, email_change_token_current, email_change_confirm_status, banned_until, reauthentication_token, reauthentication_sent_at, is_sso_user, deleted_at, is_anonymous) VALUES ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000004', 'authenticated', 'authenticated', 'subusuario@haven.com', '$2a$06$qrLmuX02HPiw9PxkDZ5.wOTSbDjzn4MYc9C1RCLlMZGy1/D.Estu2', '2026-11-05 20:00:51.617216+00', NULL, '', NULL, '', NULL, '', '', NULL, '2026-11-05 21:26:33.527959+00', '{"rol": "Residente", "rol_id": 2, "provider": "email", "providers": ["email"], "condominio_id": "a0000000-0000-0000-0000-000000000001"}', '{"nombre": "Luis", "telefono": "5550000004", "apellidos": "Familiar"}', NULL, '2026-11-05 20:00:51.617216+00', '2026-11-05 21:26:33.530493+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false);
INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, invited_at, confirmation_token, confirmation_sent_at, recovery_token, recovery_sent_at, email_change_token_new, email_change, email_change_sent_at, last_sign_in_at, raw_app_meta_data, raw_user_meta_data, is_super_admin, created_at, updated_at, phone, phone_confirmed_at, phone_change, phone_change_token, phone_change_sent_at, email_change_token_current, email_change_confirm_status, banned_until, reauthentication_token, reauthentication_sent_at, is_sso_user, deleted_at, is_anonymous) VALUES ('00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000002', 'authenticated', 'authenticated', 'vigilante@haven.com', '$2a$06$qrLmuX02HPiw9PxkDZ5.wOTSbDjzn4MYc9C1RCLlMZGy1/D.Estu2', '2026-11-05 20:00:51.617216+00', NULL, '', NULL, '', NULL, '', '', NULL, '2026-11-05 21:26:34.013927+00', '{"rol": "Vigilancia", "rol_id": 3, "provider": "email", "providers": ["email"], "condominio_id": "a0000000-0000-0000-0000-000000000001"}', '{"nombre": "Roberto", "telefono": "5550000002", "apellidos": "Guardia"}', NULL, '2026-11-05 20:00:51.617216+00', '2026-11-05 21:26:34.016252+00', NULL, NULL, '', '', NULL, '', 0, NULL, '', NULL, false, NULL, false);


--
-- Data for Name: identities; Type: TABLE DATA; Schema: auth; Owner: supabase_auth_admin
--

INSERT INTO auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, id) VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '{"sub": "00000000-0000-0000-0000-000000000001", "email": "admin@haven.com", "email_verified": true}', 'email', '2026-11-05 20:00:51.617216+00', '2026-11-05 20:00:51.617216+00', '2026-11-05 20:00:51.617216+00', '00000000-0000-0000-0000-000000000001');
INSERT INTO auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, id) VALUES ('00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', '{"sub": "00000000-0000-0000-0000-000000000002", "email": "vigilante@haven.com", "email_verified": true}', 'email', '2026-11-05 20:00:51.617216+00', '2026-11-05 20:00:51.617216+00', '2026-11-05 20:00:51.617216+00', '00000000-0000-0000-0000-000000000002');
INSERT INTO auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, id) VALUES ('00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003', '{"sub": "00000000-0000-0000-0000-000000000003", "email": "residente@haven.com", "email_verified": true}', 'email', '2026-11-05 20:00:51.617216+00', '2026-11-05 20:00:51.617216+00', '2026-11-05 20:00:51.617216+00', '00000000-0000-0000-0000-000000000003');
INSERT INTO auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, id) VALUES ('00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000004', '{"sub": "00000000-0000-0000-0000-000000000004", "email": "subusuario@haven.com", "email_verified": true}', 'email', '2026-11-05 20:00:51.617216+00', '2026-11-05 20:00:51.617216+00', '2026-11-05 20:00:51.617216+00', '00000000-0000-0000-0000-000000000004');
INSERT INTO auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at, id) VALUES ('00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000005', '{"sub": "00000000-0000-0000-0000-000000000005", "email": "invitado@haven.com", "email_verified": true}', 'email', '2026-11-05 20:00:51.617216+00', '2026-11-05 20:00:51.617216+00', '2026-11-05 20:00:51.617216+00', '00000000-0000-0000-0000-000000000005');


--
-- PostgreSQL database dump complete
--



-- Datos de public
--
-- PostgreSQL database dump
--


-- Dumped from database version 17.6
-- Dumped by pg_dump version 17.11 (Debian 17.11-1.pgdg13+2)


--
-- Data for Name: condominios; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.condominios (id, nombre, direccion, zona_horaria, activo, creado_en) VALUES ('a0000000-0000-0000-0000-000000000001', 'Residencial Los Pinos', 'Av. Paseo de los Pinos 100, CDMX', 'America/Mexico_City', true, '2026-11-05 20:00:51.617216+00');


--
-- Data for Name: areas_comunes; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.areas_comunes (id, condominio_id, nombre, descripcion, hora_apertura, hora_cierre, activo, creado_en) VALUES ('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'Salón de Eventos', 'Salón climatizado con capacidad para 60 personas y cocina equipada.', '09:00:00', '23:00:00', true, '2026-11-05 20:00:51.617216+00');
INSERT INTO public.areas_comunes (id, condominio_id, nombre, descripcion, hora_apertura, hora_cierre, activo, creado_en) VALUES ('b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 'Terraza Grill', 'Terraza al aire libre con asador de gas, barra y mesas.', '10:00:00', '22:00:00', true, '2026-11-05 20:00:51.617216+00');
INSERT INTO public.areas_comunes (id, condominio_id, nombre, descripcion, hora_apertura, hora_cierre, activo, creado_en) VALUES ('b0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000001', 'Alberca Climatizada', 'Carril de nado y área recreativa familiar.', '07:00:00', '21:00:00', true, '2026-11-05 20:00:51.617216+00');
INSERT INTO public.areas_comunes (id, condominio_id, nombre, descripcion, hora_apertura, hora_cierre, activo, creado_en) VALUES ('b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000001', 'Cancha de Pádel', 'Cancha reglamentaria con iluminación nocturna.', '08:00:00', '22:00:00', true, '2026-11-05 20:00:51.617216+00');


--
-- Data for Name: areas_comunes_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.areas_comunes_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (1, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "b0000000-0000-0000-0000-000000000001", "activo": true, "nombre": "Salón de Eventos", "creado_en": "2026-11-05T20:00:51.617216+00:00", "descripcion": "Salón climatizado con capacidad para 60 personas y cocina equipada.", "hora_cierre": "23:00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "hora_apertura": "09:00:00"}');
INSERT INTO public.areas_comunes_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (2, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "b0000000-0000-0000-0000-000000000002", "activo": true, "nombre": "Terraza Grill", "creado_en": "2026-11-05T20:00:51.617216+00:00", "descripcion": "Terraza al aire libre con asador de gas, barra y mesas.", "hora_cierre": "22:00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "hora_apertura": "10:00:00"}');
INSERT INTO public.areas_comunes_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (3, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "b0000000-0000-0000-0000-000000000003", "activo": true, "nombre": "Alberca Climatizada", "creado_en": "2026-11-05T20:00:51.617216+00:00", "descripcion": "Carril de nado y área recreativa familiar.", "hora_cierre": "21:00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "hora_apertura": "07:00:00"}');
INSERT INTO public.areas_comunes_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (4, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "b0000000-0000-0000-0000-000000000004", "activo": true, "nombre": "Cancha de Pádel", "creado_en": "2026-11-05T20:00:51.617216+00:00", "descripcion": "Cancha reglamentaria con iluminación nocturna.", "hora_cierre": "22:00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "hora_apertura": "08:00:00"}');


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.roles (id, nombre, descripcion) VALUES (1, 'Administrador', 'Control total del sistema y condominio');
INSERT INTO public.roles (id, nombre, descripcion) VALUES (2, 'Residente', 'Usuario estándar que habita en el condominio');
INSERT INTO public.roles (id, nombre, descripcion) VALUES (3, 'Vigilancia', 'Personal de seguridad y control de accesos en caseta');
INSERT INTO public.roles (id, nombre, descripcion) VALUES (4, 'Mantenimiento', 'Personal encargado de reparaciones y áreas comunes');


--
-- Data for Name: usuarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.usuarios (id, rol_id, condominio_id, email, nombre, apellidos, telefono, activo, debe_cambiar_password, creado_en) VALUES ('00000000-0000-0000-0000-000000000002', 3, 'a0000000-0000-0000-0000-000000000001', 'vigilante@haven.com', 'Roberto', 'Guardia', '5550000002', true, false, '2026-11-05 20:00:51.617216+00');
INSERT INTO public.usuarios (id, rol_id, condominio_id, email, nombre, apellidos, telefono, activo, debe_cambiar_password, creado_en) VALUES ('00000000-0000-0000-0000-000000000003', 2, 'a0000000-0000-0000-0000-000000000001', 'residente@haven.com', 'Ana', 'Titular', '5550000003', true, false, '2026-11-05 20:00:51.617216+00');
INSERT INTO public.usuarios (id, rol_id, condominio_id, email, nombre, apellidos, telefono, activo, debe_cambiar_password, creado_en) VALUES ('00000000-0000-0000-0000-000000000004', 2, 'a0000000-0000-0000-0000-000000000001', 'subusuario@haven.com', 'Luis', 'Familiar', '5550000004', true, false, '2026-11-05 20:00:51.617216+00');
INSERT INTO public.usuarios (id, rol_id, condominio_id, email, nombre, apellidos, telefono, activo, debe_cambiar_password, creado_en) VALUES ('00000000-0000-0000-0000-000000000005', 2, 'a0000000-0000-0000-0000-000000000001', 'invitado@haven.com', 'Sofía', 'Invitada', '5550000005', true, false, '2026-11-05 20:00:51.617216+00');
INSERT INTO public.usuarios (id, rol_id, condominio_id, email, nombre, apellidos, telefono, activo, debe_cambiar_password, creado_en) VALUES ('00000000-0000-0000-0000-000000000001', 1, 'a0000000-0000-0000-0000-000000000001', 'admin@haven.com', 'Carlos', 'Administrador', '5550000001', true, false, '2026-11-05 20:00:51.617216+00');


--
-- Data for Name: avisos; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.avisos (id, condominio_id, titulo, contenido, prioridad, duracion_dias, fecha_expiracion_manual, fecha_publicacion, activo, creado_por, creado_en) VALUES ('083bda78-e816-4266-9b63-88b7f3712c25', 'a0000000-0000-0000-0000-000000000001', 'Mantenimiento de alberca y áreas comunes', 'Se informa a todos los residentes que este jueves se realizará limpieza profunda en el área común.', 'alta', 7, NULL, '2026-11-05 20:00:51.617216+00', true, '00000000-0000-0000-0000-000000000001', '2026-11-05 20:00:51.617216+00');
INSERT INTO public.avisos (id, condominio_id, titulo, contenido, prioridad, duracion_dias, fecha_expiracion_manual, fecha_publicacion, activo, creado_por, creado_en) VALUES ('1a6606e3-4fa4-4f25-b413-474918be3e5f', 'a0000000-0000-0000-0000-000000000001', 'Actualización de reglamento de visitas y paquetería', 'Recuerden registrar sus visitas y paquetes esperados desde la app para agilizar el acceso en caseta.', 'normal', 15, NULL, '2026-11-05 20:00:51.617216+00', true, '00000000-0000-0000-0000-000000000001', '2026-11-05 20:00:51.617216+00');


--
-- Data for Name: avisos_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.avisos_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (1, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "083bda78-e816-4266-9b63-88b7f3712c25", "activo": true, "titulo": "Mantenimiento de alberca y áreas comunes", "contenido": "Se informa a todos los residentes que este jueves se realizará limpieza profunda en el área común.", "creado_en": "2026-11-05T20:00:51.617216+00:00", "prioridad": "alta", "creado_por": "00000000-0000-0000-0000-000000000001", "condominio_id": "a0000000-0000-0000-0000-000000000001", "duracion_dias": 7, "fecha_publicacion": "2026-11-05T20:00:51.617216+00:00", "fecha_expiracion_manual": null}');
INSERT INTO public.avisos_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (2, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "1a6606e3-4fa4-4f25-b413-474918be3e5f", "activo": true, "titulo": "Actualización de reglamento de visitas y paquetería", "contenido": "Recuerden registrar sus visitas y paquetes esperados desde la app para agilizar el acceso en caseta.", "creado_en": "2026-11-05T20:00:51.617216+00:00", "prioridad": "normal", "creado_por": "00000000-0000-0000-0000-000000000001", "condominio_id": "a0000000-0000-0000-0000-000000000001", "duracion_dias": 15, "fecha_publicacion": "2026-11-05T20:00:51.617216+00:00", "fecha_expiracion_manual": null}');


--
-- Data for Name: viviendas; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.viviendas (id, condominio_id, numero_casa, tipo, activo, creado_en) VALUES (1, 'a0000000-0000-0000-0000-000000000001', '101', 'Casa', true, '2026-11-05 20:00:51.617216+00');
INSERT INTO public.viviendas (id, condominio_id, numero_casa, tipo, activo, creado_en) VALUES (2, 'a0000000-0000-0000-0000-000000000001', '102', 'Departamento', true, '2026-11-05 20:00:51.617216+00');
INSERT INTO public.viviendas (id, condominio_id, numero_casa, tipo, activo, creado_en) VALUES (3, 'a0000000-0000-0000-0000-000000000001', '103', 'Casa', true, '2026-11-05 20:00:51.617216+00');


--
-- Data for Name: plantillas_cargo; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.plantillas_cargo (id, condominio_id, vivienda_id, tipo, concepto, monto, dia_vencimiento, vigencia_inicio, vigencia_fin, responsable_pago, activa, creado_por, creado_en, modificado_por, modificado_en) VALUES ('c0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 1, 'Mantenimiento', 'Cuota de Mantenimiento Mensual', 1800.00, 10, '2026-11-01', NULL, 'Residente', true, '00000000-0000-0000-0000-000000000001', '2026-11-05 20:00:51.617216+00', NULL, NULL);


--
-- Data for Name: cargos; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.cargos (id, condominio_id, vivienda_id, plantilla_id, tipo, concepto, monto, periodo, fecha_vencimiento, estado, responsable_pago, motivo_cancelacion, cancelado_por, cancelado_en, creado_por, creado_en) VALUES ('d0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', 1, NULL, 'Otro', 'Aportación para modernización de portón eléctrico', 950.00, NULL, '2026-11-20', 'Pendiente', 'Residente', NULL, NULL, NULL, '00000000-0000-0000-0000-000000000001', '2026-11-05 20:00:51.617216+00');
INSERT INTO public.cargos (id, condominio_id, vivienda_id, plantilla_id, tipo, concepto, monto, periodo, fecha_vencimiento, estado, responsable_pago, motivo_cancelacion, cancelado_por, cancelado_en, creado_por, creado_en) VALUES ('d0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 1, 'c0000000-0000-0000-0000-000000000001', 'Mantenimiento', 'Cuota de Mantenimiento Mensual', 1800.00, '2026-11-01', '2026-11-10', 'Pagado', 'Residente', NULL, NULL, NULL, '00000000-0000-0000-0000-000000000001', '2026-11-05 20:00:51.617216+00');


--
-- Data for Name: cargos_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.cargos_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (1, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "d0000000-0000-0000-0000-000000000001", "tipo": "Mantenimiento", "monto": 1800.00, "estado": "Pendiente", "periodo": "2026-11-01", "concepto": "Cuota de Mantenimiento Mensual", "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000001", "vivienda_id": 1, "cancelado_en": null, "plantilla_id": "c0000000-0000-0000-0000-000000000001", "cancelado_por": null, "condominio_id": "a0000000-0000-0000-0000-000000000001", "saldo_pendiente": 1800.00, "responsable_pago": "Residente", "fecha_vencimiento": "2026-11-10", "motivo_cancelacion": null, "monto_pagado_confirmado": 0.00}');
INSERT INTO public.cargos_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (2, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "d0000000-0000-0000-0000-000000000002", "tipo": "Extraordinario", "monto": 950.00, "estado": "Pendiente", "periodo": null, "concepto": "Aportación para modernización de portón eléctrico", "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000001", "vivienda_id": 1, "cancelado_en": null, "plantilla_id": null, "cancelado_por": null, "condominio_id": "a0000000-0000-0000-0000-000000000001", "saldo_pendiente": 950.00, "responsable_pago": "Residente", "fecha_vencimiento": "2026-11-20", "motivo_cancelacion": null, "monto_pagado_confirmado": 0.00}');
INSERT INTO public.cargos_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (3, 'UPDATE', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, '{"id": "d0000000-0000-0000-0000-000000000001", "tipo": "Mantenimiento", "monto": 1800.00, "estado": "Pendiente", "periodo": "2026-11-01", "concepto": "Cuota de Mantenimiento Mensual", "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000001", "vivienda_id": 1, "cancelado_en": null, "plantilla_id": "c0000000-0000-0000-0000-000000000001", "cancelado_por": null, "condominio_id": "a0000000-0000-0000-0000-000000000001", "saldo_pendiente": 1800.00, "responsable_pago": "Residente", "fecha_vencimiento": "2026-11-10", "motivo_cancelacion": null, "monto_pagado_confirmado": 0.00}', '{"id": "d0000000-0000-0000-0000-000000000001", "tipo": "Mantenimiento", "monto": 1800.00, "estado": "Pagado", "periodo": "2026-11-01", "concepto": "Cuota de Mantenimiento Mensual", "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000001", "vivienda_id": 1, "cancelado_en": null, "plantilla_id": "c0000000-0000-0000-0000-000000000001", "cancelado_por": null, "condominio_id": "a0000000-0000-0000-0000-000000000001", "saldo_pendiente": 0.00, "responsable_pago": "Residente", "fecha_vencimiento": "2026-11-10", "motivo_cancelacion": null, "monto_pagado_confirmado": 1800.00}');


--
-- Data for Name: codigos_condominio; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: codigos_condominio_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: codigos_vivienda; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: codigos_vivienda_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: condominios_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.condominios_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (1, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "a0000000-0000-0000-0000-000000000001", "activo": true, "nombre": "Residencial Los Pinos", "creado_en": "2026-11-05T20:00:51.617216+00:00", "direccion": "Av. Paseo de los Pinos 100, CDMX", "zona_horaria": "America/Mexico_City"}');


--
-- Data for Name: invitaciones_subusuarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.invitaciones_subusuarios (id, vivienda_id, creado_por, email_invitado, codigo_invitacion, estado, usuario_id, expira_en, respondido_en, creado_en, parentesco, invitado_id, titular_id) VALUES ('93f8113b-4428-482d-a06e-67a2ee5ce694', 1, '00000000-0000-0000-0000-000000000003', 'invitado@haven.com', '7D557EF4', 'PENDIENTE', '00000000-0000-0000-0000-000000000005', '2026-12-05 20:00:51.617216+00', NULL, '2026-11-05 20:00:51.617216+00', 'Pareja', '00000000-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000003');


--
-- Data for Name: invitaciones_subusuarios_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.invitaciones_subusuarios_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (1, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "93f8113b-4428-482d-a06e-67a2ee5ce694", "estado": "PENDIENTE", "creado_en": "2026-11-05T20:00:51.617216+00:00", "parentesco": "Pareja", "titular_id": "00000000-0000-0000-0000-000000000003", "invitado_id": "00000000-0000-0000-0000-000000000005", "vivienda_id": 1, "actualizado_en": "2026-11-05T20:00:51.617216+00:00"}');


--
-- Data for Name: pagos; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.pagos (id, cargo_id, monto, monto_cubierto, monto_excedente, fecha_pago, metodo, referencia, banco_origen, estado, origen, comprobante_ruta, comprobante_hash, es_reversa, pago_original_id, motivo_rechazo, motivo_anulacion, registrado_por, creado_en, confirmado_por, confirmado_en, rechazado_por, rechazado_en, anulado_por, anulado_en) VALUES ('2d62e14d-2f1f-47be-bcaf-0691bed1013a', 'd0000000-0000-0000-0000-000000000001', 1800.00, 1800.00, 0.00, '2026-11-05', 'Transferencia', 'SPEI-101-001', 'BBVA', 'Confirmado', 'Inquilino', NULL, NULL, false, NULL, NULL, NULL, '00000000-0000-0000-0000-000000000003', '2026-11-05 20:00:51.617216+00', '00000000-0000-0000-0000-000000000001', '2026-11-05 20:00:51.617216+00', NULL, NULL, NULL, NULL);


--
-- Data for Name: movimientos_saldo_favor; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: movimientos_saldo_favor_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--



--
-- Data for Name: notificaciones; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.notificaciones (id, usuario_id, tipo_evento, titulo, mensaje, url_redireccion, leida, reserva_id, push_enviado, push_reclamado_en, creado_en) VALUES ('d0b357e8-73e6-4140-82ff-d53a13171680', '00000000-0000-0000-0000-000000000003', 'llegada_visita', 'Tu visita ha llegado', 'Jorge Plomero ha ingresado al condominio hacia la vivienda 101.', '/mis-visitas', false, NULL, false, NULL, '2026-11-05 20:00:51.617216+00');
INSERT INTO public.notificaciones (id, usuario_id, tipo_evento, titulo, mensaje, url_redireccion, leida, reserva_id, push_enviado, push_reclamado_en, creado_en) VALUES ('1e818c75-d609-48fe-851f-c37a2b31cccf', '00000000-0000-0000-0000-000000000004', 'llegada_visita', 'Tu visita ha llegado', 'Laura Gómez ha ingresado al condominio hacia la vivienda 101.', '/mis-visitas', false, NULL, false, NULL, '2026-11-05 20:00:51.617216+00');
INSERT INTO public.notificaciones (id, usuario_id, tipo_evento, titulo, mensaje, url_redireccion, leida, reserva_id, push_enviado, push_reclamado_en, creado_en) VALUES ('e4e44f9c-50ef-4801-b2d0-e4867dbd503c', '00000000-0000-0000-0000-000000000004', 'paquete_entregado', 'Paquete entregado', 'El paquete de DHL para Luis Familiar ha sido entregado a Luis Familiar.', '/paqueteria', false, NULL, false, NULL, '2026-11-05 20:00:51.617216+00');


--
-- Data for Name: notificaciones_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.notificaciones_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (1, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "d0b357e8-73e6-4140-82ff-d53a13171680", "leida": false, "titulo": "Tu visita ha llegado", "mensaje": "Jorge Plomero ha ingresado al condominio hacia la vivienda 101.", "creado_en": "2026-11-05T20:00:51.617216+00:00", "reserva_id": null, "usuario_id": "00000000-0000-0000-0000-000000000003", "tipo_evento": "llegada_visita", "push_enviado": false, "url_redireccion": "/mis-visitas", "push_reclamado_en": null}');
INSERT INTO public.notificaciones_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (2, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "1e818c75-d609-48fe-851f-c37a2b31cccf", "leida": false, "titulo": "Tu visita ha llegado", "mensaje": "Laura Gómez ha ingresado al condominio hacia la vivienda 101.", "creado_en": "2026-11-05T20:00:51.617216+00:00", "reserva_id": null, "usuario_id": "00000000-0000-0000-0000-000000000004", "tipo_evento": "llegada_visita", "push_enviado": false, "url_redireccion": "/mis-visitas", "push_reclamado_en": null}');
INSERT INTO public.notificaciones_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (3, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "e4e44f9c-50ef-4801-b2d0-e4867dbd503c", "leida": false, "titulo": "Paquete entregado", "mensaje": "El paquete de DHL para Luis Familiar ha sido entregado a Luis Familiar.", "creado_en": "2026-11-05T20:00:51.617216+00:00", "reserva_id": null, "usuario_id": "00000000-0000-0000-0000-000000000004", "tipo_evento": "paquete_entregado", "push_enviado": false, "url_redireccion": "/paqueteria", "push_reclamado_en": null}');


--
-- Data for Name: pagos_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.pagos_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (1, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "2d62e14d-2f1f-47be-bcaf-0691bed1013a", "monto": 1800.00, "estado": "PendienteConfirmacion", "metodo": "Transferencia", "origen": "Residente", "cargo_id": "d0000000-0000-0000-0000-000000000001", "creado_en": "2026-11-05T20:00:51.617216+00:00", "anulado_en": null, "es_reversa": false, "fecha_pago": "2026-11-05", "referencia": "SPEI-101-001", "anulado_por": null, "vivienda_id": 1, "banco_origen": "BBVA", "rechazado_en": null, "condominio_id": "a0000000-0000-0000-0000-000000000001", "confirmado_en": null, "rechazado_por": null, "confirmado_por": null, "monto_cubierto": 1800.00, "motivo_rechazo": null, "registrado_por": "00000000-0000-0000-0000-000000000003", "monto_excedente": 0.00, "comprobante_hash": null, "comprobante_ruta": null, "motivo_anulacion": null, "pago_original_id": null}');
INSERT INTO public.pagos_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (2, 'UPDATE', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, '{"id": "2d62e14d-2f1f-47be-bcaf-0691bed1013a", "monto": 1800.00, "estado": "PendienteConfirmacion", "metodo": "Transferencia", "origen": "Residente", "cargo_id": "d0000000-0000-0000-0000-000000000001", "creado_en": "2026-11-05T20:00:51.617216+00:00", "anulado_en": null, "es_reversa": false, "fecha_pago": "2026-11-05", "referencia": "SPEI-101-001", "anulado_por": null, "vivienda_id": 1, "banco_origen": "BBVA", "rechazado_en": null, "condominio_id": "a0000000-0000-0000-0000-000000000001", "confirmado_en": null, "rechazado_por": null, "confirmado_por": null, "monto_cubierto": 1800.00, "motivo_rechazo": null, "registrado_por": "00000000-0000-0000-0000-000000000003", "monto_excedente": 0.00, "comprobante_hash": null, "comprobante_ruta": null, "motivo_anulacion": null, "pago_original_id": null}', '{"id": "2d62e14d-2f1f-47be-bcaf-0691bed1013a", "monto": 1800.00, "estado": "Confirmado", "metodo": "Transferencia", "origen": "Residente", "cargo_id": "d0000000-0000-0000-0000-000000000001", "creado_en": "2026-11-05T20:00:51.617216+00:00", "anulado_en": null, "es_reversa": false, "fecha_pago": "2026-11-05", "referencia": "SPEI-101-001", "anulado_por": null, "vivienda_id": 1, "banco_origen": "BBVA", "rechazado_en": null, "condominio_id": "a0000000-0000-0000-0000-000000000001", "confirmado_en": "2026-11-05T20:00:51.617216+00:00", "rechazado_por": null, "confirmado_por": "00000000-0000-0000-0000-000000000001", "monto_cubierto": 1800.00, "motivo_rechazo": null, "registrado_por": "00000000-0000-0000-0000-000000000003", "monto_excedente": 0.00, "comprobante_hash": null, "comprobante_ruta": null, "motivo_anulacion": null, "pago_original_id": null}');


--
-- Data for Name: servicios_paqueteria; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.servicios_paqueteria (id, condominio_id, nombre, icono_url, es_sistema, activo, creado_por, creado_en) VALUES (1, NULL, 'Amazon', NULL, true, true, NULL, '2026-11-05 20:00:51.617216+00');
INSERT INTO public.servicios_paqueteria (id, condominio_id, nombre, icono_url, es_sistema, activo, creado_por, creado_en) VALUES (2, NULL, 'Mercado Libre', NULL, true, true, NULL, '2026-11-05 20:00:51.617216+00');
INSERT INTO public.servicios_paqueteria (id, condominio_id, nombre, icono_url, es_sistema, activo, creado_por, creado_en) VALUES (3, NULL, 'DHL', NULL, true, true, NULL, '2026-11-05 20:00:51.617216+00');
INSERT INTO public.servicios_paqueteria (id, condominio_id, nombre, icono_url, es_sistema, activo, creado_por, creado_en) VALUES (4, NULL, 'FedEx', NULL, true, true, NULL, '2026-11-05 20:00:51.617216+00');
INSERT INTO public.servicios_paqueteria (id, condominio_id, nombre, icono_url, es_sistema, activo, creado_por, creado_en) VALUES (5, NULL, 'Estafeta', NULL, true, true, NULL, '2026-11-05 20:00:51.617216+00');
INSERT INTO public.servicios_paqueteria (id, condominio_id, nombre, icono_url, es_sistema, activo, creado_por, creado_en) VALUES (6, NULL, 'UPS', NULL, true, true, NULL, '2026-11-05 20:00:51.617216+00');
INSERT INTO public.servicios_paqueteria (id, condominio_id, nombre, icono_url, es_sistema, activo, creado_por, creado_en) VALUES (7, NULL, 'Paquetexpress', NULL, true, true, NULL, '2026-11-05 20:00:51.617216+00');
INSERT INTO public.servicios_paqueteria (id, condominio_id, nombre, icono_url, es_sistema, activo, creado_por, creado_en) VALUES (8, NULL, 'Correos de México', NULL, true, true, NULL, '2026-11-05 20:00:51.617216+00');
INSERT INTO public.servicios_paqueteria (id, condominio_id, nombre, icono_url, es_sistema, activo, creado_por, creado_en) VALUES (9, NULL, 'Otro', NULL, true, true, NULL, '2026-11-05 20:00:51.617216+00');


--
-- Data for Name: paquetes; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.paquetes (id, condominio_id, vivienda_id, servicio_id, servicio_nombre, empresa_paqueteria, destinatario_nombre, numero_guia, descripcion, notas, fecha_esperada, fecha_esperada_desde, fecha_esperada_hasta, estado, es_inesperado, ubicacion_almacen, recibido_en, recibido_por, entregado_en, entregado_por, entregado_a, entregado_a_nombre, foto_url, motivo_cancelacion, creado_por, creado_en, actualizado_en) VALUES ('48f992a0-d705-4c6e-a263-a70c6315ef20', 'a0000000-0000-0000-0000-000000000001', 1, 1, 'Amazon', 'Amazon', 'Ana Titular', 'AMZ-900100', 'Caja mediana con artículos de oficina', 'Dejar en caseta principal', '2026-11-05', '2026-11-05 20:00:51.617216+00', '2026-11-10 20:00:51.617216+00', 'esperado', false, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '00000000-0000-0000-0000-000000000003', '2026-11-05 20:00:51.617216+00', '2026-11-05 20:00:51.617216+00');
INSERT INTO public.paquetes (id, condominio_id, vivienda_id, servicio_id, servicio_nombre, empresa_paqueteria, destinatario_nombre, numero_guia, descripcion, notas, fecha_esperada, fecha_esperada_desde, fecha_esperada_hasta, estado, es_inesperado, ubicacion_almacen, recibido_en, recibido_por, entregado_en, entregado_por, entregado_a, entregado_a_nombre, foto_url, motivo_cancelacion, creado_por, creado_en, actualizado_en) VALUES ('7f193fe7-e45f-4849-b56c-99830c68e43b', 'a0000000-0000-0000-0000-000000000001', 1, 2, 'Mercado Libre', 'Mercado Libre', 'Ana Titular', 'MELI-800200', 'Sobre amarillo acolchado', 'Frágil', '2026-11-04', '2026-11-04 20:00:51.617216+00', '2026-11-08 20:00:51.617216+00', 'recibido', false, 'Estante A-2', '2026-11-05 20:00:51.617216+00', '00000000-0000-0000-0000-000000000002', NULL, NULL, NULL, NULL, NULL, NULL, '00000000-0000-0000-0000-000000000003', '2026-11-05 20:00:51.617216+00', '2026-11-05 20:00:51.617216+00');
INSERT INTO public.paquetes (id, condominio_id, vivienda_id, servicio_id, servicio_nombre, empresa_paqueteria, destinatario_nombre, numero_guia, descripcion, notas, fecha_esperada, fecha_esperada_desde, fecha_esperada_hasta, estado, es_inesperado, ubicacion_almacen, recibido_en, recibido_por, entregado_en, entregado_por, entregado_a, entregado_a_nombre, foto_url, motivo_cancelacion, creado_por, creado_en, actualizado_en) VALUES ('a7a6b371-da0a-4c78-bfba-2f6226ebb565', 'a0000000-0000-0000-0000-000000000001', 1, 3, 'DHL', 'DHL', 'Luis Familiar', 'DHL-700300', 'Paquete internacional', NULL, '2026-11-03', '2026-11-03 20:00:51.617216+00', '2026-11-07 20:00:51.617216+00', 'entregado', false, 'Estante B-1', '2026-11-05 20:00:51.617216+00', '00000000-0000-0000-0000-000000000002', '2026-11-05 20:00:51.617216+00', '00000000-0000-0000-0000-000000000002', NULL, 'Luis Familiar', 'https://placehold.co/600x400?text=Evidencia+Entrega', NULL, '00000000-0000-0000-0000-000000000004', '2026-11-05 20:00:51.617216+00', '2026-11-05 20:00:51.617216+00');


--
-- Data for Name: paquetes_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.paquetes_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (1, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "48f992a0-d705-4c6e-a263-a70c6315ef20", "notas": "Dejar en caseta principal", "estado": "esperado", "foto_url": null, "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000003", "descripcion": "Caja mediana con artículos de oficina", "entregado_a": null, "numero_guia": "AMZ-900100", "recibido_en": null, "servicio_id": 1, "vivienda_id": 1, "entregado_en": null, "recibido_por": null, "condominio_id": "a0000000-0000-0000-0000-000000000001", "entregado_por": null, "es_inesperado": false, "actualizado_en": "2026-11-05T20:00:51.617216+00:00", "fecha_esperada": "2026-11-05", "servicio_nombre": "Amazon", "ubicacion_almacen": null, "empresa_paqueteria": "Amazon", "entregado_a_nombre": null, "motivo_cancelacion": null, "destinatario_nombre": "Ana Titular", "fecha_esperada_desde": "2026-11-05T20:00:51.617216+00:00", "fecha_esperada_hasta": "2026-11-10T20:00:51.617216+00:00"}');
INSERT INTO public.paquetes_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (2, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "7f193fe7-e45f-4849-b56c-99830c68e43b", "notas": "Frágil", "estado": "esperado", "foto_url": null, "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000003", "descripcion": "Sobre amarillo acolchado", "entregado_a": null, "numero_guia": "MELI-800200", "recibido_en": null, "servicio_id": 2, "vivienda_id": 1, "entregado_en": null, "recibido_por": null, "condominio_id": "a0000000-0000-0000-0000-000000000001", "entregado_por": null, "es_inesperado": false, "actualizado_en": "2026-11-05T20:00:51.617216+00:00", "fecha_esperada": "2026-11-04", "servicio_nombre": "Mercado Libre", "ubicacion_almacen": null, "empresa_paqueteria": "Mercado Libre", "entregado_a_nombre": null, "motivo_cancelacion": null, "destinatario_nombre": "Ana Titular", "fecha_esperada_desde": "2026-11-04T20:00:51.617216+00:00", "fecha_esperada_hasta": "2026-11-08T20:00:51.617216+00:00"}');
INSERT INTO public.paquetes_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (3, 'UPDATE', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, '{"id": "7f193fe7-e45f-4849-b56c-99830c68e43b", "notas": "Frágil", "estado": "esperado", "foto_url": null, "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000003", "descripcion": "Sobre amarillo acolchado", "entregado_a": null, "numero_guia": "MELI-800200", "recibido_en": null, "servicio_id": 2, "vivienda_id": 1, "entregado_en": null, "recibido_por": null, "condominio_id": "a0000000-0000-0000-0000-000000000001", "entregado_por": null, "es_inesperado": false, "actualizado_en": "2026-11-05T20:00:51.617216+00:00", "fecha_esperada": "2026-11-04", "servicio_nombre": "Mercado Libre", "ubicacion_almacen": null, "empresa_paqueteria": "Mercado Libre", "entregado_a_nombre": null, "motivo_cancelacion": null, "destinatario_nombre": "Ana Titular", "fecha_esperada_desde": "2026-11-04T20:00:51.617216+00:00", "fecha_esperada_hasta": "2026-11-08T20:00:51.617216+00:00"}', '{"id": "7f193fe7-e45f-4849-b56c-99830c68e43b", "notas": "Frágil", "estado": "recibido", "foto_url": null, "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000003", "descripcion": "Sobre amarillo acolchado", "entregado_a": null, "numero_guia": "MELI-800200", "recibido_en": "2026-11-05T20:00:51.617216+00:00", "servicio_id": 2, "vivienda_id": 1, "entregado_en": null, "recibido_por": "00000000-0000-0000-0000-000000000002", "condominio_id": "a0000000-0000-0000-0000-000000000001", "entregado_por": null, "es_inesperado": false, "actualizado_en": "2026-11-05T20:00:51.617216+00:00", "fecha_esperada": "2026-11-04", "servicio_nombre": "Mercado Libre", "ubicacion_almacen": "Estante A-2", "empresa_paqueteria": "Mercado Libre", "entregado_a_nombre": null, "motivo_cancelacion": null, "destinatario_nombre": "Ana Titular", "fecha_esperada_desde": "2026-11-04T20:00:51.617216+00:00", "fecha_esperada_hasta": "2026-11-08T20:00:51.617216+00:00"}');
INSERT INTO public.paquetes_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (4, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "a7a6b371-da0a-4c78-bfba-2f6226ebb565", "notas": null, "estado": "esperado", "foto_url": null, "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000004", "descripcion": "Paquete internacional", "entregado_a": null, "numero_guia": "DHL-700300", "recibido_en": null, "servicio_id": 3, "vivienda_id": 1, "entregado_en": null, "recibido_por": null, "condominio_id": "a0000000-0000-0000-0000-000000000001", "entregado_por": null, "es_inesperado": false, "actualizado_en": "2026-11-05T20:00:51.617216+00:00", "fecha_esperada": "2026-11-03", "servicio_nombre": "DHL", "ubicacion_almacen": null, "empresa_paqueteria": "DHL", "entregado_a_nombre": null, "motivo_cancelacion": null, "destinatario_nombre": "Luis Familiar", "fecha_esperada_desde": "2026-11-03T20:00:51.617216+00:00", "fecha_esperada_hasta": "2026-11-07T20:00:51.617216+00:00"}');
INSERT INTO public.paquetes_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (5, 'UPDATE', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, '{"id": "a7a6b371-da0a-4c78-bfba-2f6226ebb565", "notas": null, "estado": "esperado", "foto_url": null, "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000004", "descripcion": "Paquete internacional", "entregado_a": null, "numero_guia": "DHL-700300", "recibido_en": null, "servicio_id": 3, "vivienda_id": 1, "entregado_en": null, "recibido_por": null, "condominio_id": "a0000000-0000-0000-0000-000000000001", "entregado_por": null, "es_inesperado": false, "actualizado_en": "2026-11-05T20:00:51.617216+00:00", "fecha_esperada": "2026-11-03", "servicio_nombre": "DHL", "ubicacion_almacen": null, "empresa_paqueteria": "DHL", "entregado_a_nombre": null, "motivo_cancelacion": null, "destinatario_nombre": "Luis Familiar", "fecha_esperada_desde": "2026-11-03T20:00:51.617216+00:00", "fecha_esperada_hasta": "2026-11-07T20:00:51.617216+00:00"}', '{"id": "a7a6b371-da0a-4c78-bfba-2f6226ebb565", "notas": null, "estado": "recibido", "foto_url": null, "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000004", "descripcion": "Paquete internacional", "entregado_a": null, "numero_guia": "DHL-700300", "recibido_en": "2026-11-05T20:00:51.617216+00:00", "servicio_id": 3, "vivienda_id": 1, "entregado_en": null, "recibido_por": "00000000-0000-0000-0000-000000000002", "condominio_id": "a0000000-0000-0000-0000-000000000001", "entregado_por": null, "es_inesperado": false, "actualizado_en": "2026-11-05T20:00:51.617216+00:00", "fecha_esperada": "2026-11-03", "servicio_nombre": "DHL", "ubicacion_almacen": "Estante B-1", "empresa_paqueteria": "DHL", "entregado_a_nombre": null, "motivo_cancelacion": null, "destinatario_nombre": "Luis Familiar", "fecha_esperada_desde": "2026-11-03T20:00:51.617216+00:00", "fecha_esperada_hasta": "2026-11-07T20:00:51.617216+00:00"}');
INSERT INTO public.paquetes_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (6, 'UPDATE', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, '{"id": "a7a6b371-da0a-4c78-bfba-2f6226ebb565", "notas": null, "estado": "recibido", "foto_url": null, "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000004", "descripcion": "Paquete internacional", "entregado_a": null, "numero_guia": "DHL-700300", "recibido_en": "2026-11-05T20:00:51.617216+00:00", "servicio_id": 3, "vivienda_id": 1, "entregado_en": null, "recibido_por": "00000000-0000-0000-0000-000000000002", "condominio_id": "a0000000-0000-0000-0000-000000000001", "entregado_por": null, "es_inesperado": false, "actualizado_en": "2026-11-05T20:00:51.617216+00:00", "fecha_esperada": "2026-11-03", "servicio_nombre": "DHL", "ubicacion_almacen": "Estante B-1", "empresa_paqueteria": "DHL", "entregado_a_nombre": null, "motivo_cancelacion": null, "destinatario_nombre": "Luis Familiar", "fecha_esperada_desde": "2026-11-03T20:00:51.617216+00:00", "fecha_esperada_hasta": "2026-11-07T20:00:51.617216+00:00"}', '{"id": "a7a6b371-da0a-4c78-bfba-2f6226ebb565", "notas": null, "estado": "entregado", "foto_url": "https://placehold.co/600x400?text=Evidencia+Entrega", "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000004", "descripcion": "Paquete internacional", "entregado_a": null, "numero_guia": "DHL-700300", "recibido_en": "2026-11-05T20:00:51.617216+00:00", "servicio_id": 3, "vivienda_id": 1, "entregado_en": "2026-11-05T20:00:51.617216+00:00", "recibido_por": "00000000-0000-0000-0000-000000000002", "condominio_id": "a0000000-0000-0000-0000-000000000001", "entregado_por": "00000000-0000-0000-0000-000000000002", "es_inesperado": false, "actualizado_en": "2026-11-05T20:00:51.617216+00:00", "fecha_esperada": "2026-11-03", "servicio_nombre": "DHL", "ubicacion_almacen": "Estante B-1", "empresa_paqueteria": "DHL", "entregado_a_nombre": "Luis Familiar", "motivo_cancelacion": null, "destinatario_nombre": "Luis Familiar", "fecha_esperada_desde": "2026-11-03T20:00:51.617216+00:00", "fecha_esperada_hasta": "2026-11-07T20:00:51.617216+00:00"}');


--
-- Data for Name: plantillas_cargo_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.plantillas_cargo_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (1, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "c0000000-0000-0000-0000-000000000001", "tipo": "Mantenimiento", "monto": 1800.00, "activa": true, "concepto": "Cuota de Mantenimiento Mensual", "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000001", "vivienda_id": 1, "vigencia_fin": null, "condominio_id": "a0000000-0000-0000-0000-000000000001", "modificado_en": null, "modificado_por": null, "dia_vencimiento": 10, "vigencia_inicio": "2026-11-01", "responsable_pago": "Residente"}');


--
-- Data for Name: reservas; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.reservas (id, area_id, condominio_id, titular_id, vivienda_id, solicitante_id, aprobador_id, tipo, inicio, fin, estado, motivo, confirmada_en, recordatorio_24h_enviado, creado_en, actualizado_en) VALUES ('b288f9ca-2ee8-450b-b720-83ceb26f44f1', 'b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000003', 1, '00000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'RESERVA', '2026-11-08 20:00:00+00', '2026-11-09 00:00:00+00', 'CONFIRMADA', NULL, '2026-11-05 20:00:51.617216+00', false, '2026-11-05 20:00:51.617216+00', '2026-11-05 20:00:51.617216+00');


--
-- Data for Name: reservas_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.reservas_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (1, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "b288f9ca-2ee8-450b-b720-83ceb26f44f1", "fin": "2026-11-09T00:00:00+00:00", "tipo": "RESERVA", "estado": "CONFIRMADA", "inicio": "2026-11-08T20:00:00+00:00", "motivo": null, "area_id": "b0000000-0000-0000-0000-000000000002", "creado_en": "2026-11-05T20:00:51.617216+00:00", "titular_id": "00000000-0000-0000-0000-000000000003", "vivienda_id": 1, "aprobador_id": "00000000-0000-0000-0000-000000000001", "condominio_id": "a0000000-0000-0000-0000-000000000001", "confirmada_en": "2026-11-05T20:00:51.617216+00:00", "actualizado_en": "2026-11-05T20:00:51.617216+00:00", "solicitante_id": "00000000-0000-0000-0000-000000000003", "recordatorio_24h_enviado": false}');


--
-- Data for Name: roles_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.roles_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (1, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": 1, "nombre": "Administrador", "descripcion": "Control total del sistema y condominio"}');
INSERT INTO public.roles_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (2, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": 2, "nombre": "Residente", "descripcion": "Usuario estándar que habita en el condominio"}');
INSERT INTO public.roles_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (3, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": 3, "nombre": "Vigilancia", "descripcion": "Personal de seguridad y control de accesos en caseta"}');
INSERT INTO public.roles_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (4, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": 4, "nombre": "Mantenimiento", "descripcion": "Personal encargado de reparaciones y áreas comunes"}');


--
-- Data for Name: servicios_paqueteria_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.servicios_paqueteria_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (1, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": 1, "activo": true, "nombre": "Amazon", "creado_en": "2026-11-05T20:00:51.617216+00:00", "icono_url": null, "creado_por": null, "es_sistema": true, "condominio_id": null}');
INSERT INTO public.servicios_paqueteria_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (2, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": 2, "activo": true, "nombre": "Mercado Libre", "creado_en": "2026-11-05T20:00:51.617216+00:00", "icono_url": null, "creado_por": null, "es_sistema": true, "condominio_id": null}');
INSERT INTO public.servicios_paqueteria_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (3, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": 3, "activo": true, "nombre": "DHL", "creado_en": "2026-11-05T20:00:51.617216+00:00", "icono_url": null, "creado_por": null, "es_sistema": true, "condominio_id": null}');
INSERT INTO public.servicios_paqueteria_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (4, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": 4, "activo": true, "nombre": "FedEx", "creado_en": "2026-11-05T20:00:51.617216+00:00", "icono_url": null, "creado_por": null, "es_sistema": true, "condominio_id": null}');
INSERT INTO public.servicios_paqueteria_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (5, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": 5, "activo": true, "nombre": "Estafeta", "creado_en": "2026-11-05T20:00:51.617216+00:00", "icono_url": null, "creado_por": null, "es_sistema": true, "condominio_id": null}');
INSERT INTO public.servicios_paqueteria_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (6, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": 6, "activo": true, "nombre": "UPS", "creado_en": "2026-11-05T20:00:51.617216+00:00", "icono_url": null, "creado_por": null, "es_sistema": true, "condominio_id": null}');
INSERT INTO public.servicios_paqueteria_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (7, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": 7, "activo": true, "nombre": "Paquetexpress", "creado_en": "2026-11-05T20:00:51.617216+00:00", "icono_url": null, "creado_por": null, "es_sistema": true, "condominio_id": null}');
INSERT INTO public.servicios_paqueteria_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (8, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": 8, "activo": true, "nombre": "Correos de México", "creado_en": "2026-11-05T20:00:51.617216+00:00", "icono_url": null, "creado_por": null, "es_sistema": true, "condominio_id": null}');
INSERT INTO public.servicios_paqueteria_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (9, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": 9, "activo": true, "nombre": "Otro", "creado_en": "2026-11-05T20:00:51.617216+00:00", "icono_url": null, "creado_por": null, "es_sistema": true, "condominio_id": null}');


--
-- Data for Name: usuarios_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.usuarios_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (1, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "00000000-0000-0000-0000-000000000001", "email": "admin@haven.com", "activo": true, "nombre": "Carlos", "rol_id": 1, "telefono": "5550000001", "apellidos": "Administrador", "creado_en": "2026-11-05T20:00:51.617216+00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "debe_cambiar_password": false}');
INSERT INTO public.usuarios_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (2, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "00000000-0000-0000-0000-000000000002", "email": "vigilante@haven.com", "activo": true, "nombre": "Roberto", "rol_id": 3, "telefono": "5550000002", "apellidos": "Guardia", "creado_en": "2026-11-05T20:00:51.617216+00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "debe_cambiar_password": false}');
INSERT INTO public.usuarios_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (3, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "00000000-0000-0000-0000-000000000003", "email": "residente@haven.com", "activo": true, "nombre": "Ana", "rol_id": 2, "telefono": "5550000003", "apellidos": "Titular", "creado_en": "2026-11-05T20:00:51.617216+00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "debe_cambiar_password": false}');
INSERT INTO public.usuarios_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (4, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "00000000-0000-0000-0000-000000000004", "email": "subusuario@haven.com", "activo": true, "nombre": "Luis", "rol_id": 2, "telefono": "5550000004", "apellidos": "Familiar", "creado_en": "2026-11-05T20:00:51.617216+00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "debe_cambiar_password": false}');
INSERT INTO public.usuarios_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (5, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "00000000-0000-0000-0000-000000000005", "email": "invitado@haven.com", "activo": true, "nombre": "Sofía", "rol_id": 2, "telefono": "5550000005", "apellidos": "Invitada", "creado_en": "2026-11-05T20:00:51.617216+00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "debe_cambiar_password": false}');
INSERT INTO public.usuarios_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (7, 'UPDATE', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, '{"id": "00000000-0000-0000-0000-000000000001", "email": "admin@haven.com", "activo": true, "nombre": "Carlos", "rol_id": 1, "telefono": "5550000001", "apellidos": "Administrador", "creado_en": "2026-11-05T20:00:51.617216+00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "debe_cambiar_password": false}', '{"id": "00000000-0000-0000-0000-000000000001", "email": "admin@haven.com", "activo": true, "nombre": "Carlos", "rol_id": 1, "telefono": "5550000001", "apellidos": "Administrador", "creado_en": "2026-11-05T20:00:51.617216+00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "debe_cambiar_password": false}');
INSERT INTO public.usuarios_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (8, 'UPDATE', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, '{"id": "00000000-0000-0000-0000-000000000002", "email": "vigilante@haven.com", "activo": true, "nombre": "Roberto", "rol_id": 3, "telefono": "5550000002", "apellidos": "Guardia", "creado_en": "2026-11-05T20:00:51.617216+00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "debe_cambiar_password": false}', '{"id": "00000000-0000-0000-0000-000000000002", "email": "vigilante@haven.com", "activo": true, "nombre": "Roberto", "rol_id": 3, "telefono": "5550000002", "apellidos": "Guardia", "creado_en": "2026-11-05T20:00:51.617216+00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "debe_cambiar_password": false}');
INSERT INTO public.usuarios_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (9, 'UPDATE', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, '{"id": "00000000-0000-0000-0000-000000000003", "email": "residente@haven.com", "activo": true, "nombre": "Ana", "rol_id": 2, "telefono": "5550000003", "apellidos": "Titular", "creado_en": "2026-11-05T20:00:51.617216+00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "debe_cambiar_password": false}', '{"id": "00000000-0000-0000-0000-000000000003", "email": "residente@haven.com", "activo": true, "nombre": "Ana", "rol_id": 2, "telefono": "5550000003", "apellidos": "Titular", "creado_en": "2026-11-05T20:00:51.617216+00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "debe_cambiar_password": false}');
INSERT INTO public.usuarios_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (10, 'UPDATE', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, '{"id": "00000000-0000-0000-0000-000000000004", "email": "subusuario@haven.com", "activo": true, "nombre": "Luis", "rol_id": 2, "telefono": "5550000004", "apellidos": "Familiar", "creado_en": "2026-11-05T20:00:51.617216+00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "debe_cambiar_password": false}', '{"id": "00000000-0000-0000-0000-000000000004", "email": "subusuario@haven.com", "activo": true, "nombre": "Luis", "rol_id": 2, "telefono": "5550000004", "apellidos": "Familiar", "creado_en": "2026-11-05T20:00:51.617216+00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "debe_cambiar_password": false}');
INSERT INTO public.usuarios_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (11, 'UPDATE', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, '{"id": "00000000-0000-0000-0000-000000000005", "email": "invitado@haven.com", "activo": true, "nombre": "Sofía", "rol_id": 2, "telefono": "5550000005", "apellidos": "Invitada", "creado_en": "2026-11-05T20:00:51.617216+00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "debe_cambiar_password": false}', '{"id": "00000000-0000-0000-0000-000000000005", "email": "invitado@haven.com", "activo": true, "nombre": "Sofía", "rol_id": 2, "telefono": "5550000005", "apellidos": "Invitada", "creado_en": "2026-11-05T20:00:51.617216+00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "debe_cambiar_password": false}');
INSERT INTO public.usuarios_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (13, 'UPDATE', '2026-11-05 20:43:36.972139+00', 'postgres', NULL, '{"id": "00000000-0000-0000-0000-000000000001", "email": "admin@haven.com", "activo": true, "nombre": "Carlos", "rol_id": 1, "telefono": "5550000001", "apellidos": "Administrador", "creado_en": "2026-11-05T20:00:51.617216+00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "debe_cambiar_password": false}', '{"id": "00000000-0000-0000-0000-000000000001", "email": "admin@haven.com", "activo": true, "nombre": "Carlos", "rol_id": 1, "telefono": "5550000001", "apellidos": "Administrador", "creado_en": "2026-11-05T20:00:51.617216+00:00", "condominio_id": "a0000000-0000-0000-0000-000000000001", "debe_cambiar_password": false}');


--
-- Data for Name: version; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.version (id, numero_version, descripcion, aplicado_en) VALUES (1, '2.0.0', 'Esquema reconstruido completo con todos los módulos HAVEN', '2026-11-05 20:00:51.617216+00');


--
-- Data for Name: version_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.version_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (1, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": 1, "aplicado_en": "2026-11-05T20:00:51.617216+00:00", "descripcion": "Esquema reconstruido completo con todos los módulos HAVEN", "numero_version": "2.0.0"}');


--
-- Data for Name: visitas; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.visitas (id, vivienda_id, condominio_id, nombre_visitante, apellidos_visitante, telefono_visitante, motivo, num_acompanantes, vehiculo_placas, notas, fecha_llegada_esperada, fecha_expiracion, codigo_acceso, estado, hora_entrada, hora_salida, registrado_entrada_por, registrado_salida_por, creado_por, creado_en) VALUES ('023b8074-042d-4e15-9b8a-5878aa0e216c', 1, 'a0000000-0000-0000-0000-000000000001', 'Miguel', 'Hernández', '5559990001', 'familiar', 2, 'ABC-123-A', 'Viene a cenar con la familia', '2026-11-05 22:00:51.617216+00', '2026-11-06 22:00:51.617216+00', 'VIS-2E9522', 'programada', NULL, NULL, NULL, NULL, '00000000-0000-0000-0000-000000000003', '2026-11-05 20:00:51.617216+00');
INSERT INTO public.visitas (id, vivienda_id, condominio_id, nombre_visitante, apellidos_visitante, telefono_visitante, motivo, num_acompanantes, vehiculo_placas, notas, fecha_llegada_esperada, fecha_expiracion, codigo_acceso, estado, hora_entrada, hora_salida, registrado_entrada_por, registrado_salida_por, creado_por, creado_en) VALUES ('56c1f633-94ed-4e91-8128-226b798616aa', 1, 'a0000000-0000-0000-0000-000000000001', 'Jorge', 'Plomero', '5559990002', 'servicio', 1, 'SRV-998-B', 'Reparación de tubería en cocina', '2026-11-05 19:00:51.617216+00', '2026-11-06 07:00:51.617216+00', 'VIS-286D9F', 'en_curso', '2026-11-05 20:00:51.617216+00', NULL, '00000000-0000-0000-0000-000000000002', NULL, '00000000-0000-0000-0000-000000000003', '2026-11-05 20:00:51.617216+00');
INSERT INTO public.visitas (id, vivienda_id, condominio_id, nombre_visitante, apellidos_visitante, telefono_visitante, motivo, num_acompanantes, vehiculo_placas, notas, fecha_llegada_esperada, fecha_expiracion, codigo_acceso, estado, hora_entrada, hora_salida, registrado_entrada_por, registrado_salida_por, creado_por, creado_en) VALUES ('e1643e0a-b362-40a5-aa77-3677ca43ad4f', 1, 'a0000000-0000-0000-0000-000000000001', 'Laura', 'Gómez', '5559990003', 'personal', 0, NULL, 'Visita rápida', '2026-11-05 16:00:51.617216+00', '2026-11-06 04:00:51.617216+00', 'VIS-9DFDC5', 'finalizada', '2026-11-05 20:00:51.617216+00', '2026-11-05 20:00:51.617216+00', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000004', '2026-11-05 20:00:51.617216+00');


--
-- Data for Name: visitas_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.visitas_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (1, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "023b8074-042d-4e15-9b8a-5878aa0e216c", "notas": "Viene a cenar con la familia", "estado": "programada", "motivo": "familiar", "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000003", "hora_salida": null, "vivienda_id": 1, "hora_entrada": null, "codigo_acceso": "VIS-2E9522", "condominio_id": "a0000000-0000-0000-0000-000000000001", "vehiculo_placas": "ABC-123-A", "fecha_expiracion": "2026-11-06T22:00:51.617216+00:00", "nombre_visitante": "Miguel", "num_acompanantes": 2, "telefono_visitante": "5559990001", "apellidos_visitante": "Hernández", "registrado_salida_por": null, "fecha_llegada_esperada": "2026-11-05T22:00:51.617216+00:00", "registrado_entrada_por": null}');
INSERT INTO public.visitas_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (2, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "56c1f633-94ed-4e91-8128-226b798616aa", "notas": "Reparación de tubería en cocina", "estado": "programada", "motivo": "servicio", "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000003", "hora_salida": null, "vivienda_id": 1, "hora_entrada": null, "codigo_acceso": "VIS-286D9F", "condominio_id": "a0000000-0000-0000-0000-000000000001", "vehiculo_placas": "SRV-998-B", "fecha_expiracion": "2026-11-06T07:00:51.617216+00:00", "nombre_visitante": "Jorge", "num_acompanantes": 1, "telefono_visitante": "5559990002", "apellidos_visitante": "Plomero", "registrado_salida_por": null, "fecha_llegada_esperada": "2026-11-05T19:00:51.617216+00:00", "registrado_entrada_por": null}');
INSERT INTO public.visitas_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (3, 'UPDATE', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, '{"id": "56c1f633-94ed-4e91-8128-226b798616aa", "notas": "Reparación de tubería en cocina", "estado": "programada", "motivo": "servicio", "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000003", "hora_salida": null, "vivienda_id": 1, "hora_entrada": null, "codigo_acceso": "VIS-286D9F", "condominio_id": "a0000000-0000-0000-0000-000000000001", "vehiculo_placas": "SRV-998-B", "fecha_expiracion": "2026-11-06T07:00:51.617216+00:00", "nombre_visitante": "Jorge", "num_acompanantes": 1, "telefono_visitante": "5559990002", "apellidos_visitante": "Plomero", "registrado_salida_por": null, "fecha_llegada_esperada": "2026-11-05T19:00:51.617216+00:00", "registrado_entrada_por": null}', '{"id": "56c1f633-94ed-4e91-8128-226b798616aa", "notas": "Reparación de tubería en cocina", "estado": "en_curso", "motivo": "servicio", "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000003", "hora_salida": null, "vivienda_id": 1, "hora_entrada": "2026-11-05T20:00:51.617216+00:00", "codigo_acceso": "VIS-286D9F", "condominio_id": "a0000000-0000-0000-0000-000000000001", "vehiculo_placas": "SRV-998-B", "fecha_expiracion": "2026-11-06T07:00:51.617216+00:00", "nombre_visitante": "Jorge", "num_acompanantes": 1, "telefono_visitante": "5559990002", "apellidos_visitante": "Plomero", "registrado_salida_por": null, "fecha_llegada_esperada": "2026-11-05T19:00:51.617216+00:00", "registrado_entrada_por": "00000000-0000-0000-0000-000000000002"}');
INSERT INTO public.visitas_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (4, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "e1643e0a-b362-40a5-aa77-3677ca43ad4f", "notas": "Visita rápida", "estado": "programada", "motivo": "personal", "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000004", "hora_salida": null, "vivienda_id": 1, "hora_entrada": null, "codigo_acceso": "VIS-9DFDC5", "condominio_id": "a0000000-0000-0000-0000-000000000001", "vehiculo_placas": null, "fecha_expiracion": "2026-11-06T04:00:51.617216+00:00", "nombre_visitante": "Laura", "num_acompanantes": 0, "telefono_visitante": "5559990003", "apellidos_visitante": "Gómez", "registrado_salida_por": null, "fecha_llegada_esperada": "2026-11-05T16:00:51.617216+00:00", "registrado_entrada_por": null}');
INSERT INTO public.visitas_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (5, 'UPDATE', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, '{"id": "e1643e0a-b362-40a5-aa77-3677ca43ad4f", "notas": "Visita rápida", "estado": "programada", "motivo": "personal", "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000004", "hora_salida": null, "vivienda_id": 1, "hora_entrada": null, "codigo_acceso": "VIS-9DFDC5", "condominio_id": "a0000000-0000-0000-0000-000000000001", "vehiculo_placas": null, "fecha_expiracion": "2026-11-06T04:00:51.617216+00:00", "nombre_visitante": "Laura", "num_acompanantes": 0, "telefono_visitante": "5559990003", "apellidos_visitante": "Gómez", "registrado_salida_por": null, "fecha_llegada_esperada": "2026-11-05T16:00:51.617216+00:00", "registrado_entrada_por": null}', '{"id": "e1643e0a-b362-40a5-aa77-3677ca43ad4f", "notas": "Visita rápida", "estado": "en_curso", "motivo": "personal", "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000004", "hora_salida": null, "vivienda_id": 1, "hora_entrada": "2026-11-05T20:00:51.617216+00:00", "codigo_acceso": "VIS-9DFDC5", "condominio_id": "a0000000-0000-0000-0000-000000000001", "vehiculo_placas": null, "fecha_expiracion": "2026-11-06T04:00:51.617216+00:00", "nombre_visitante": "Laura", "num_acompanantes": 0, "telefono_visitante": "5559990003", "apellidos_visitante": "Gómez", "registrado_salida_por": null, "fecha_llegada_esperada": "2026-11-05T16:00:51.617216+00:00", "registrado_entrada_por": "00000000-0000-0000-0000-000000000002"}');
INSERT INTO public.visitas_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (6, 'UPDATE', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, '{"id": "e1643e0a-b362-40a5-aa77-3677ca43ad4f", "notas": "Visita rápida", "estado": "en_curso", "motivo": "personal", "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000004", "hora_salida": null, "vivienda_id": 1, "hora_entrada": "2026-11-05T20:00:51.617216+00:00", "codigo_acceso": "VIS-9DFDC5", "condominio_id": "a0000000-0000-0000-0000-000000000001", "vehiculo_placas": null, "fecha_expiracion": "2026-11-06T04:00:51.617216+00:00", "nombre_visitante": "Laura", "num_acompanantes": 0, "telefono_visitante": "5559990003", "apellidos_visitante": "Gómez", "registrado_salida_por": null, "fecha_llegada_esperada": "2026-11-05T16:00:51.617216+00:00", "registrado_entrada_por": "00000000-0000-0000-0000-000000000002"}', '{"id": "e1643e0a-b362-40a5-aa77-3677ca43ad4f", "notas": "Visita rápida", "estado": "finalizada", "motivo": "personal", "creado_en": "2026-11-05T20:00:51.617216+00:00", "creado_por": "00000000-0000-0000-0000-000000000004", "hora_salida": "2026-11-05T20:00:51.617216+00:00", "vivienda_id": 1, "hora_entrada": "2026-11-05T20:00:51.617216+00:00", "codigo_acceso": "VIS-9DFDC5", "condominio_id": "a0000000-0000-0000-0000-000000000001", "vehiculo_placas": null, "fecha_expiracion": "2026-11-06T04:00:51.617216+00:00", "nombre_visitante": "Laura", "num_acompanantes": 0, "telefono_visitante": "5559990003", "apellidos_visitante": "Gómez", "registrado_salida_por": "00000000-0000-0000-0000-000000000002", "fecha_llegada_esperada": "2026-11-05T16:00:51.617216+00:00", "registrado_entrada_por": "00000000-0000-0000-0000-000000000002"}');


--
-- Data for Name: vivienda_residente; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.vivienda_residente (id, vivienda_id, usuario_id, es_propietario, fecha_ingreso) VALUES (1, 1, '00000000-0000-0000-0000-000000000003', true, '2026-11-05 20:00:51.617216+00');


--
-- Data for Name: vivienda_residente_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.vivienda_residente_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (1, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": 1, "usuario_id": "00000000-0000-0000-0000-000000000003", "vivienda_id": 1, "fecha_ingreso": "2026-11-05T20:00:51.617216+00:00", "es_propietario": true}');


--
-- Data for Name: vivienda_subusuarios; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.vivienda_subusuarios (id, vivienda_id, usuario_id, titular_id, parentesco, activo, creado_en, actualizado_en) VALUES ('2a33f6e6-83f7-4bd7-9fea-1a346d978633', 1, '00000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000003', 'Hermano', true, '2026-11-05 20:00:51.617216+00', '2026-11-05 20:00:51.617216+00');


--
-- Data for Name: vivienda_subusuarios_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.vivienda_subusuarios_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (1, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": "2a33f6e6-83f7-4bd7-9fea-1a346d978633", "activo": true, "creado_en": "2026-11-05T20:00:51.617216+00:00", "parentesco": "Hermano", "titular_id": "00000000-0000-0000-0000-000000000003", "usuario_id": "00000000-0000-0000-0000-000000000004", "vivienda_id": 1, "actualizado_en": "2026-11-05T20:00:51.617216+00:00"}');


--
-- Data for Name: viviendas_bitacora; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.viviendas_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (1, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": 1, "tipo": "Casa", "activo": true, "creado_en": "2026-11-05T20:00:51.617216+00:00", "numero_casa": "101", "condominio_id": "a0000000-0000-0000-0000-000000000001"}');
INSERT INTO public.viviendas_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (2, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": 2, "tipo": "Departamento", "activo": true, "creado_en": "2026-11-05T20:00:51.617216+00:00", "numero_casa": "102", "condominio_id": "a0000000-0000-0000-0000-000000000001"}');
INSERT INTO public.viviendas_bitacora (id, operacion, fecha_hora, usuario_bd, usuario_id, datos_anteriores, datos_nuevos) VALUES (3, 'INSERT', '2026-11-05 20:00:51.617216+00', 'postgres', NULL, NULL, '{"id": 3, "tipo": "Casa", "activo": true, "creado_en": "2026-11-05T20:00:51.617216+00:00", "numero_casa": "103", "condominio_id": "a0000000-0000-0000-0000-000000000001"}');


--
-- Name: areas_comunes_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.areas_comunes_bitacora_id_seq', 4, true);


--
-- Name: avisos_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.avisos_bitacora_id_seq', 2, true);


--
-- Name: cargos_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.cargos_bitacora_id_seq', 5, true);


--
-- Name: codigos_condominio_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.codigos_condominio_bitacora_id_seq', 1, false);


--
-- Name: codigos_vivienda_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.codigos_vivienda_bitacora_id_seq', 1, false);


--
-- Name: condominios_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.condominios_bitacora_id_seq', 2, true);


--
-- Name: invitaciones_subusuarios_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.invitaciones_subusuarios_bitacora_id_seq', 4, true);


--
-- Name: movimientos_saldo_favor_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.movimientos_saldo_favor_bitacora_id_seq', 1, false);


--
-- Name: notificaciones_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notificaciones_bitacora_id_seq', 7, true);


--
-- Name: pagos_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.pagos_bitacora_id_seq', 4, true);


--
-- Name: paquetes_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.paquetes_bitacora_id_seq', 6, true);


--
-- Name: plantillas_cargo_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.plantillas_cargo_bitacora_id_seq', 1, true);


--
-- Name: reservas_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.reservas_bitacora_id_seq', 1, true);


--
-- Name: roles_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.roles_bitacora_id_seq', 4, true);


--
-- Name: servicios_paqueteria_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.servicios_paqueteria_bitacora_id_seq', 9, true);


--
-- Name: servicios_paqueteria_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.servicios_paqueteria_id_seq', 9, true);


--
-- Name: usuarios_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.usuarios_bitacora_id_seq', 16, true);


--
-- Name: version_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.version_bitacora_id_seq', 1, true);


--
-- Name: version_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.version_id_seq', 1, true);


--
-- Name: visitas_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.visitas_bitacora_id_seq', 6, true);


--
-- Name: vivienda_residente_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.vivienda_residente_bitacora_id_seq', 3, true);


--
-- Name: vivienda_residente_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.vivienda_residente_id_seq', 2, true);


--
-- Name: vivienda_subusuarios_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.vivienda_subusuarios_bitacora_id_seq', 3, true);


--
-- Name: viviendas_bitacora_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.viviendas_bitacora_id_seq', 3, true);


--
-- Name: viviendas_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.viviendas_id_seq', 3, true);


--
-- PostgreSQL database dump complete
--



SET session_replication_role = origin;

-- 3.2 Cuenta de administrador garantizada: admin@haven.com / AdminPassword1
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new,
  email_change_token_current, phone_change, phone_change_token, reauthentication_token
) VALUES (
  '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-000000000001',
  'authenticated', 'authenticated', 'admin@haven.com',
  extensions.crypt('AdminPassword1', extensions.gen_salt('bf')), now(),
  '{"provider":"email","providers":["email"]}', '{}', now(), now(),
  '', '', '', '', '', '', '', ''
)
ON CONFLICT (id) DO UPDATE
SET email              = EXCLUDED.email,
    encrypted_password = EXCLUDED.encrypted_password,
    email_confirmed_at = COALESCE(auth.users.email_confirmed_at, now()),
    banned_until       = NULL,
    deleted_at         = NULL,
    updated_at         = now()
-- Solo se toca si algo no cuadra, para no generar cambios ni bitacora en cada corrida
WHERE auth.users.email IS DISTINCT FROM EXCLUDED.email
   OR auth.users.encrypted_password IS DISTINCT FROM extensions.crypt('AdminPassword1', auth.users.encrypted_password)
   OR auth.users.email_confirmed_at IS NULL
   OR auth.users.banned_until IS NOT NULL
   OR auth.users.deleted_at IS NOT NULL;

INSERT INTO auth.identities (provider_id, user_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
SELECT u.id::text, u.id,
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true, 'phone_verified', false),
       'email', now(), now(), now()
FROM auth.users u
WHERE u.id = '00000000-0000-0000-0000-000000000001'
  AND NOT EXISTS (SELECT 1 FROM auth.identities i WHERE i.user_id = u.id AND i.provider = 'email');

UPDATE public.usuarios
SET rol_id = 1, activo = true
WHERE id = '00000000-0000-0000-0000-000000000001'
  AND (rol_id IS DISTINCT FROM 1 OR activo IS DISTINCT FROM true);

-- 3.3 Verificacion final (si algo no cuadra, se revierte este paso)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM auth.users a
    JOIN public.usuarios u ON u.id = a.id
    WHERE a.email = 'admin@haven.com'
      AND a.encrypted_password = extensions.crypt('AdminPassword1', a.encrypted_password)
      AND a.email_confirmed_at IS NOT NULL
      AND u.rol_id = 1 AND u.activo
  ) THEN
    RAISE EXCEPTION 'seed: la cuenta admin@haven.com no quedo lista';
  END IF;
END
$$;

COMMIT;

-- Resumen de lo que quedo construido
SELECT
  (SELECT count(*) FROM pg_tables WHERE schemaname = 'public')                           AS tablas,
  (SELECT count(*) FROM pg_views  WHERE schemaname = 'public')                           AS vistas,
  (SELECT count(*) FROM pg_proc p WHERE p.pronamespace = 'public'::regnamespace
     AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.objid = p.oid AND d.deptype = 'e')) AS funciones,
  (SELECT count(*) FROM pg_policies WHERE schemaname IN ('public', 'storage'))            AS politicas_rls,
  (SELECT count(*) FROM auth.users)                                                      AS cuentas,
  (SELECT count(*) FROM cron.job)                                                        AS cron_jobs,
  (SELECT string_agg(email, ', ' ORDER BY email) FROM auth.users)                        AS correos;
