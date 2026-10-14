import 'package:flutter/material.dart';
import '../Themes/animation_constants.dart';

/// Un [PageTransitionsBuilder] personalizado para Haven que produce
/// una transición fluida y de alta gama estilo Shared Axis Horizontal con
/// paralaje inverso y desvanecimiento temprano.
///
/// Características premium:
/// 1. Deslizamiento con curva cúbica suave (alta inercia inicial y parada orgánica).
/// 2. Entrada combinada con desvanecimiento temprano y micro-escala (0.96 a 1.0).
/// 3. Efecto de paralaje sutil (-12%) en la pantalla que queda detrás.
/// 4. Desvanecimiento suave en la pantalla secundaria para guiar el foco visual.
/// 5. Soporte completo para RTL (derecha a izquierda).
class HavenPageTransitionsBuilder extends PageTransitionsBuilder {
  const HavenPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return buildHavenTransition(
      context: context,
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }

  /// Función estática reusable para construir la transición en cualquier contexto.
  static Widget buildHavenTransition({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
    bool enableSecondaryParallax = true,
  }) {
    final isRtl = Directionality.maybeOf(context) == TextDirection.rtl;
    final directionMultiplier = isRtl ? -1.0 : 1.0;

    // --- Curvas para la pantalla entrante (Primaria) ---
    final isReversing = animation.status == AnimationStatus.reverse;
    final primaryCurve = isReversing
        ? HavenAnimationCurves.pageReverseCurve
        : HavenAnimationCurves.pageEnterCurve;

    final primaryCurvedAnimation = CurvedAnimation(
      parent: animation,
      curve: primaryCurve,
      reverseCurve: HavenAnimationCurves.pageReverseCurve,
    );

    // Animación de traslación horizontal
    final slideTween = Tween<Offset>(
      begin: Offset(
        HavenAnimationOffsets.slideRightToLeft.dx * directionMultiplier,
        0.0,
      ),
      end: Offset.zero,
    );

    // Animación de opacidad rápida
    final fadeCurvedAnimation = CurvedAnimation(
      parent: animation,
      curve: HavenAnimationCurves.fadeEnterCurve,
      reverseCurve: HavenAnimationCurves.fadeExitCurve,
    );

    // Micro-escala (0.96 -> 1.0)
    final scaleCurvedAnimation = CurvedAnimation(
      parent: animation,
      curve: HavenAnimationCurves.scaleEnterCurve,
      reverseCurve: Curves.easeInCubic,
    );

    final scaleTween = Tween<double>(
      begin: 0.96,
      end: 1.0,
    );

    Widget result = SlideTransition(
      position: slideTween.animate(primaryCurvedAnimation),
      child: FadeTransition(
        opacity: fadeCurvedAnimation,
        child: ScaleTransition(
          scale: scaleTween.animate(scaleCurvedAnimation),
          child: child,
        ),
      ),
    );

    // --- Efecto de paralaje para la pantalla que queda atrás (Secundaria) ---
    if (enableSecondaryParallax) {
      final secondaryCurvedAnimation = CurvedAnimation(
        parent: secondaryAnimation,
        curve: HavenAnimationCurves.pageExitCurve,
        reverseCurve: HavenAnimationCurves.pageReverseCurve,
      );

      final secondarySlideTween = Tween<Offset>(
        begin: Offset.zero,
        end: Offset(
          HavenAnimationOffsets.secondarySlideBack.dx * directionMultiplier,
          0.0,
        ),
      );

      final secondaryOpacityTween = Tween<double>(
        begin: 1.0,
        end: HavenAnimationOffsets.secondaryMinOpacity,
      );

      result = SlideTransition(
        position: secondarySlideTween.animate(secondaryCurvedAnimation),
        child: FadeTransition(
          opacity: secondaryOpacityTween.animate(secondaryCurvedAnimation),
          child: result,
        ),
      );
    }

    return result;
  }
}
