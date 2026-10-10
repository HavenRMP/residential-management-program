# Sistema de Transiciones de Página Fluidas (Haven Mobile)

Este documento detalla el sistema de animación y transición entre páginas de Haven Mobile, diseñado bajo principios de Material Motion (Shared Axis Horizontal) y física de desaceleración tipo iOS/Android 14.

---

## 1. Principios de Diseño y Física

Para lograr una sensación **"premium pero fluida"** sin entorpecer la interacción del usuario:

1. **Curvas Asimétricas con Alta Inercia Inicial**:
   - `HavenAnimationCurves.pageEnterCurve` (`Cubic(0.05, 0.7, 0.1, 1.0)`): Desaceleración suave y progresiva.
   - `HavenAnimationCurves.pageReverseCurve` (`Cubic(0.15, 0.9, 0.2, 1.0)`): Regreso orgánico y ágil.
2. **Desvanecimiento Temprano (`fadeEnterCurve`)**:
   - En lugar de cortar el borde bruscamente, el contenido alcanza su opacidad total en el primer 65% de la trayectoria, evitando distracciones visuales.
3. **Efecto de Paralaje Inverso**:
   - La pantalla que queda detrás se desplaza un -12% y atenúa ligeramente su opacidad (hasta 85%), otorgando profundidad 3D/Z-axis.
4. **Micro-Escala (0.96 -> 1.0)**:
   - Proporciona una sutil sensación de aterrizaje visual en pantallas secundarias.

---

## 2. Tokens de Duración

Definidos en `lib/Themes/animation_constants.dart`:

| Token | Duración | Uso |
|---|---|---|
| `HavenAnimationDurations.pageTransition` | `320ms` | Transición de empuje hacia adelante |
| `HavenAnimationDurations.pageTransitionReverse` | `280ms` | Retorno ágil (pop) |
| `HavenAnimationDurations.pageTransitionFast` | `200ms` | Diálogos o transiciones compactas |
| `HavenAnimationDurations.pageTransitionSlow` | `450ms` | Flujos de onboarding o bienvenida |
| `HavenAnimationDurations.stateSwitch` | `250ms` | Cambios de estado en AppRouter |

---

## 3. Integración Global Automática

Cualquier pantalla que utilice `MaterialPageRoute` adopta automáticamente estas transiciones porque `AppTheme.lightTheme` tiene configurado:

```dart
pageTransitionsTheme: const PageTransitionsTheme(
  builders: {
    TargetPlatform.android: HavenPageTransitionsBuilder(),
    TargetPlatform.iOS: HavenPageTransitionsBuilder(),
    ...
  },
)
```

---

## 4. Uso Declarativo y Variantes con `HavenPageRoute`

Para casos específicos (modales que suben desde abajo o desvanecimientos con micro-zoom), se proporciona `HavenPageRoute`:

### A. Deslizamiento Horizontal Estándar
```dart
Navigator.of(context).push(
  HavenPageRoute.slideHorizontal(
    builder: (_) => DetalleScreen(),
  ),
);
```

### B. Presentación Modal (Slide Up)
```dart
HavenPageRoute.push(
  context,
  const RegistroModalScreen(),
  type: HavenTransitionType.slideUp,
);
```

### C. Vía Extensión de BuildContext
```dart
// Empujar con animación fluida
context.pushHaven(const DetalleScreen());

// Reemplazar ruta
context.pushReplacementHaven(const DashboardScreen());
```

---

## 5. Transición en `AppRouter`

El enrutador principal en `lib/Routes/app_router.dart` envuelve las pantallas raíz (Splash, Login, Onboarding, Dashboards por rol) en un `AnimatedSwitcher` con curvas calibradas y claves `ValueKey`, eliminando los cortes bruscos al autenticarse o cargar la app.
