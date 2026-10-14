import 'package:flutter/material.dart';

/// Constantes y curvas de animación diseñadas para una experiencia
/// fluida, consistente y premium en la aplicación Haven.
///
/// Inspiradas en las pautas de Material Motion (Shared Axis) y la física
/// de desaceleración fluida de iOS / Android 14.
class HavenAnimationDurations {
  HavenAnimationDurations._();

  /// Duración estándar para transiciones de pantalla hacia adelante (320ms).
  static const Duration pageTransition = Duration(milliseconds: 320);

  /// Duración estándar para transiciones de pantalla en reverso/pop (280ms),
  /// proporcionando una sensación de respuesta ágil e inmediata.
  static const Duration pageTransitionReverse = Duration(milliseconds: 280);

  /// Duración rápida para micro-transiciones o diálogos ligeros (200ms).
  static const Duration pageTransitionFast = Duration(milliseconds: 200);

  /// Duración extendida para flujos ceremoniales o modales complejos (450ms).
  static const Duration pageTransitionSlow = Duration(milliseconds: 450);

  /// Duración para cambios de tabs o switches de estado en dashboard (250ms).
  static const Duration stateSwitch = Duration(milliseconds: 250);

  /// Micro-interacción de botones o feedback háptico/visual (150ms).
  static const Duration microInteraction = Duration(milliseconds: 150);
}

/// Curvas de animación con aceleración/desaceleración natural tipo spring.
class HavenAnimationCurves {
  HavenAnimationCurves._();

  /// Curva premium de entrada: desaceleración suave con inercia inicial.
  /// Cubic(0.05, 0.7, 0.1, 1.0)
  static const Curve pageEnterCurve = Cubic(0.05, 0.7, 0.1, 1.0);

  /// Curva de salida cuando una página pasa al fondo: aceleración sutil.
  /// Cubic(0.3, 0.0, 0.8, 0.15)
  static const Curve pageExitCurve = Cubic(0.3, 0.0, 0.8, 0.15);

  /// Curva suave de retorno cuando se descarta una pantalla.
  /// Cubic(0.15, 0.9, 0.2, 1.0)
  static const Curve pageReverseCurve = Cubic(0.15, 0.9, 0.2, 1.0);

  /// Intervalo rápido de opacidad para que el contenido sea visible temprano
  /// mientras viaja en la pantalla.
  static const Curve fadeEnterCurve = Interval(
    0.0,
    0.65,
    curve: Curves.easeOutQuad,
  );

  /// Desvanecimiento en salida hacia atrás.
  static const Curve fadeExitCurve = Interval(
    0.3,
    1.0,
    curve: Curves.easeInQuad,
  );

  /// Curva elástica suave para micro-escalas de 0.96 a 1.0.
  static const Curve scaleEnterCurve = Curves.easeOutCubic;
}

/// Offsets geométricos y valores de escala para transiciones de Haven.
class HavenAnimationOffsets {
  HavenAnimationOffsets._();

  /// Desplazamiento inicial para transiciones horizontales (derecha a izquierda).
  static const Offset slideRightToLeft = Offset(1.0, 0.0);

  /// Desplazamiento inicial para transiciones verticales (abajo hacia arriba).
  static const Offset slideBottomToTop = Offset(0.0, 0.18);

  /// Efecto de paralaje sutil hacia atrás (-12%) de la pantalla saliente.
  static const Offset secondarySlideBack = Offset(-0.12, 0.0);

  /// Escala mínima para transiciones de zoom compartido o diálogo (0.95).
  static const double scaleStart = 0.95;

  /// Opacidad mínima de la pantalla anterior al retroceder.
  static const double secondaryMinOpacity = 0.85;
}
