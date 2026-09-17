import { Routes } from '@angular/router';
import { authGuard } from './core/guards/auth.guard';
import { roleGuard } from './core/guards/role.guard';
import { LoginComponent } from './features/auth/login/login.component';
import { DashboardComponent } from './features/dashboard/dashboard.component';

export const routes: Routes = [
  {
    path: 'login',
    component: LoginComponent
  },
  {
    path: 'registro',
    loadComponent: () =>
      import('./features/auth/registro/registro.component')
        .then(m => m.RegistroComponent)
  },
  {
    path: 'auth/callback',
    loadComponent: () =>
      import('./features/auth/callback/auth-callback.component')
        .then(m => m.AuthCallbackComponent)
  },
  {
    path: 'dashboard',
    canActivate: [authGuard],
    component: DashboardComponent
  },
  {
    path: 'perfil',
    canActivate: [authGuard],
    loadComponent: () =>
      import('./features/perfil/perfil.component')
        .then(m => m.PerfilComponent)
  },
  {
    path: 'dashboard/admin',
    canActivate: [authGuard, roleGuard(['administrador'])],
    loadComponent: () =>
      import('./features/dashboard/admin-layout/admin-layout.component')
        .then(m => m.AdminLayoutComponent),
    children: [
      {
        path: '',
        loadComponent: () =>
          import('./features/dashboard/admin-dashboard/admin-dashboard.component')
            .then(m => m.AdminDashboardComponent)
      },
      {
        path: 'residentes',
        loadComponent: () =>
          import('./features/residentes/residentes-list/residentes-list.component')
            .then(m => m.ResidentesListComponent)
      },
      {
        path: 'viviendas',
        loadComponent: () =>
          import('./features/viviendas/viviendas-list/viviendas-list.component')
            .then(m => m.ViviendasListComponent)
      },
      {
        path: 'avisos',
        loadComponent: () =>
          import('./features/avisos/avisos-list/avisos-list.component')
            .then(m => m.AvisosListComponent)
      }
    ]
  },
  {
    path: 'dashboard/residente',
    canActivate: [authGuard, roleGuard(['residente'])],
    loadComponent: () =>
      import('./features/dashboard/residente-dashboard/residente-dashboard.component')
        .then(m => m.ResidenteDashboardComponent)
  },
  {
    path: 'dashboard/residente/notificaciones',
    canActivate: [authGuard, roleGuard(['residente'])],
    loadComponent: () =>
      import('./features/notificaciones/notificaciones.component')
        .then(m => m.NotificacionesComponent)
  },
  {
    path: 'dashboard/vigilante',
    canActivate: [authGuard, roleGuard(['vigilante'])],
    loadComponent: () =>
      import('./features/dashboard/vigilante-dashboard/vigilante-dashboard.component')
        .then(m => m.VigilanteDashboardComponent)
  },
  {
    path: '',
    redirectTo: '/login',
    pathMatch: 'full'
  },
  {
    path: '**',
    redirectTo: '/login'
  }
];
