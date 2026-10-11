# Pruebas de punta a punta (Playwright)

Recorren la web como lo haría cada rol —administrador, residente, vigilante y sub-usuario— contra el **entorno real**
(servicios en Render y Supabase). Complementan a las pruebas unitarias de `ng test`, que no ven fallos de integración
con el backend.

## Qué cubren

| Archivo | Recorrido |
| --- | --- |
| `tests/roles.spec.ts` | Cada rol entra a su panel; las rutas de otros roles y sin sesión redirigen |
| `tests/visitas-residente.spec.ts` | Programar una visita, recibir su código, editarla y cancelarla; validación del formulario |
| `tests/caseta.spec.ts` | Validar un código registra la entrada solo; salida; historial; código inexistente; visita a más de 24 h |
| `tests/ocupacion-viviendas.spec.ts` | El dashboard calcula la ocupación sin una petición por vivienda y coincide con la real y con el directorio |
| `tests/subusuarios.spec.ts` | Vista del titular (invitar, revocar) y vista de solo consulta del sub-usuario |
| `tests/paqueteria.spec.ts` | Avisar, corregir y cancelar un paquete; validaciones; recorrido de caseta (opcional) |

## Cómo correrlas

Requiere Node 22 o superior (el mismo que la app).

```bash
cd web
npm ci
npx playwright install chromium     # o define E2E_BROWSER_CHANNEL=chrome para usar tu Chrome
cp .env.e2e.example .env.e2e        # y llénalo con las cuentas de PRUEBA
npm run e2e                         # levanta la app local en el puerto 4300 y corre todo
npm run e2e:ui                      # modo interactivo
npm run e2e:report                  # abre el último reporte HTML
```

Un solo archivo: `npx playwright test e2e/tests/caseta.spec.ts`.

Para probar un despliegue en vez de la app local, define `E2E_BASE_URL` (por ejemplo la URL de una vista previa de Vercel).

## Cuentas y variables

Las credenciales **nunca se guardan en el repositorio**: `.env.e2e` está en `.gitignore` y en CI se usan secretos.
Si falta la cuenta de un rol, los tests de ese rol se **omiten** (no fallan).

| Variable | Para qué |
| --- | --- |
| `E2E_ADMIN_EMAIL`, `E2E_ADMIN_PASSWORD` | Administrador del condominio de pruebas |
| `E2E_RESIDENTE_EMAIL`, `E2E_RESIDENTE_PASSWORD` | Residente titular con una vivienda |
| `E2E_VIGILANTE_EMAIL`, `E2E_VIGILANTE_PASSWORD` | Vigilante del mismo condominio |
| `E2E_SUBUSUARIO_EMAIL`, `E2E_SUBUSUARIO_PASSWORD` | Persona con acceso activo como sub-usuario de esa vivienda |
| `E2E_BASE_URL` | Opcional: web a probar. Vacío: app local |
| `E2E_BROWSER_CHANNEL` | Opcional: `chrome` para usar el Chrome instalado |
| `E2E_DATOS_PERMANENTES` | Opcional: `1` activa el recorrido de caseta de paquetería (ver abajo) |

Las URL de Supabase y de los microservicios traen los mismos valores públicos que `src/environments/environment.ts`;
se pueden sustituir con `E2E_SUPABASE_URL`, `E2E_SUPABASE_KEY`, `E2E_VISITAS_API_URL`, `E2E_VIVIENDAS_API_URL` y `E2E_USUARIOS_API_URL`.

## Datos de prueba y limpieza

- Todo se hace en el condominio **Maderas**, con cuentas de prueba. No uses cuentas ni condominios reales.
- Todo lo que crea un test lleva un marcador `E2E…` único en el apellido de la visita o en la guía del paquete.
- Al terminar, `limpiar()` cancela lo que haya quedado vigente con ese marcador, **también de ejecuciones anteriores que
  hayan terminado a medias**.
- Hay datos que el backend no permite borrar: una visita **finalizada** (el recorrido de caseta la deja así a propósito)
  y un paquete **recibido o entregado**. Por eso el recorrido de caseta de paquetería solo corre con
  `E2E_DATOS_PERMANENTES=1`; sin esa variable se omite y no deja nada.

## Servicios dormidos

Los servicios en Render se duermen. La primera petición tras un rato puede tardar más de un minuto, así que los tiempos
son largos (`playwright.config.ts`: 5 min por test, 60 s por aserción) y cada prueba tiene un reintento.
El inicio de sesión se hace una sola vez por rol y la sesión se reutiliza (`auth.setup.ts`, carpeta `.auth/` ignorada).

## Escribir un test nuevo

1. Usa `test.skip(!cuenta('rol'), …)` y `test.use({ storageState: sesionDe('rol') })` al inicio del `describe`.
2. Todo dato que crees debe llevar `MARCADOR` (de `support/datos.ts`), con una etiqueta propia si buscas el elemento en pantalla.
3. Prefiere crear datos por API (`support/api.ts`) y probar por la interfaz lo que se está verificando.
4. Si el test deja algo que no se puede borrar, protégelo con una variable como `E2E_DATOS_PERMANENTES`.
