# 🏢 Haven — Sistema de Gestión Residencial

**Haven** es una plataforma para la administración de fraccionamientos, condominios y residencias. Busca mejorar la comunicación entre administradores y residentes, gestionar el cobro de cuotas, controlar el acceso de visitantes y facilitar la reserva de áreas comunes.

---

## 👥 Equipo y Roles Técnicos

| Integrante | Rol Técnico Principal |
| :--- | :--- |
| **Emiliano Hernández** | Database & Cloud Developer |
| **Javier Puebla** | Backend Developer |
| **César Gómez** | Web Developer |
| **Ángel Raimond** | Mobile Developer |

Los roles transversales (Scrum Master, Security Champion, QA Lead, DevOps/Release Lead) rotan por sprint — ver `docs/roles.md` para el detalle completo por sprint.

---

## 🧱 Stack Técnico

| Capa | Tecnología | Detalle |
| :--- | :--- | :--- |
| **Base de datos** | PostgreSQL (Supabase) | Row Level Security, vistas `vw_*` y Stored Procedures (`rpc`) como único contrato de acceso — ver `SP_USUARIOS.md` |
| **Auth** | Supabase Auth | JWT validado en backend vía OIDC Discovery |
| **Backend** | C# / .NET 10 — ASP.NET Core + EF Core | `EF Core InMemory`; despliegue vía Docker (Render) |
| **Web (Admin)** | Angular (standalone components + signals) | Login, guards y dashboard funcionales; desplegado en Vercel |
| **Mobile (Residentes y Admin)| Flutter + Dart |

---

## 📌 Alcance del MVP (Must-have, Sprint 1 en adelante)

* 👤 **Gestión de usuarios:** Autenticación y asignación de roles (Administrador / Residente / Vigilancia / Mantenimiento).
* 💳 **Control de mantenimiento:** Registro manual de pagos y estado de cuenta por vivienda.
* 🔑 **Gestión de visitas:** Bitácora digital con pre-registro desde app móvil.
* 📢 **Tablón de avisos:** Comunicados de la administración visibles al iniciar sesión.

---

## 📁 Estructura del Repositorio

```text
residential-management-program/
├── Backend/              # API .NET (ASP.NET Core + EF Core), Auth vía Supabase JWT
│   ├── Controllers/
│   ├── DTOs/
│   ├── Services/
│   └── Data/
├── web/                  # Panel de administración (Angular)
│   └── src/app/
│       ├── core/         # auth.service, guards, api.service
│       └── features/     # login, dashboard
├── mobile/                # App Movil para administradores y residentes 
├── supabase/              # Migraciones SQL, seed y config de Supabase CLI
│   └── migrations/
├── docs/
│   ├── product/          # Visión de producto, MVP, flujo principal
│   ├── scrum/             # Historias de usuario iniciales
│   ├── roles.md           # Rotación de roles transversales por sprint
│   ├── resumen_cambios_login.md
│   └── solucion_parpadeo_vercel.md
├── SP_USUARIOS.md         # Contrato de BD: vistas (vw_*) y Stored Procedures (RPC)
├── haven-stack-comercial.html
└── README.md
```
