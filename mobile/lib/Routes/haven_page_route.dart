import 'package:flutter/material.dart';
import '../Themes/animation_constants.dart';
import 'haven_page_transitions_builder.dart';

/// Tipos de transición disponibles para [HavenPageRoute].
enum HavenTransitionType {
  /// Deslizamiento horizontal premium con paralaje y micro-escala.
  slideHorizontal,

  /// Presentación modal desde abajo hacia arriba con sutil escala de fondo.
  slideUp,

  /// Zoom y desvanecimiento suave estilo Shared Axis / Fade-Through.
  fadeScale,
}

/// [PageRouteBuilder] especializado con transiciones de alta gama,
/// duraciones refinadas y control ergonómico por tipo de pantalla.
class HavenPageRoute<T> extends PageRouteBuilder<T> {
  final HavenTransitionType transitionType;
  final bool enableParallax;

  HavenPageRoute({
    required WidgetBuilder builder,
    this.transitionType = HavenTransitionType.slideHorizontal,
    this.enableParallax = true,
    super.settings,
    super.maintainState = true,
    super.fullscreenDialog = false,
    Duration? transitionDuration,
    Duration? reverseTransitionDuration,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration:
              transitionDuration ?? HavenAnimationDurations.pageTransition,
          reverseTransitionDuration: reverseTransitionDuration ??
              HavenAnimationDurations.pageTransitionReverse,
          transitionsBuilder: (
            context,
            animation,
            secondaryAnimation,
            child,
          ) {
            switch (transitionType) {
              case HavenTransitionType.slideHorizontal:
                return HavenPageTransitionsBuilder.buildHavenTransition(
                  context: context,
                  animation: animation,
                  secondaryAnimation: secondaryAnimation,
                  child: child,
                  enableSecondaryParallax: enableParallax,
                );

              case HavenTransitionType.slideUp:
                return _buildSlideUpTransition(
                  context: context,
                  animation: animation,
                  secondaryAnimation: secondaryAnimation,
                  child: child,
                  enableSecondaryParallax: enableParallax,
                );

              case HavenTransitionType.fadeScale:
                return _buildFadeScaleTransition(
                  context: context,
                  animation: animation,
                  secondaryAnimation: secondaryAnimation,
                  child: child,
                );
            }
          },
        );

  /// Constructor con estilo de deslizamiento horizontal (por defecto).
  factory HavenPageRoute.slideHorizontal({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool enableParallax = true,
    Duration? transitionDuration,
    Duration? reverseTransitionDuration,
  }) {
    return HavenPageRoute<T>(
      builder: builder,
      transitionType: HavenTransitionType.slideHorizontal,
      settings: settings,
      enableParallax: enableParallax,
      transitionDuration: transitionDuration,
      reverseTransitionDuration: reverseTransitionDuration,
    );
  }

  /// Constructor con estilo modal / subida desde abajo (fullscreen dialogs o modales clave).
  factory HavenPageRoute.slideUp({
    required WidgetBuilder builder,
    RouteSettings? settings,
    bool fullscreenDialog = true,
    bool enableParallax = true,
    Duration? transitionDuration,
    Duration? reverseTransitionDuration,
  }) {
    return HavenPageRoute<T>(
      builder: builder,
      transitionType: HavenTransitionType.slideUp,
      fullscreenDialog: fullscreenDialog,
      settings: settings,
      enableParallax: enableParallax,
      transitionDuration: transitionDuration,
      reverseTransitionDuration: reverseTransitionDuration,
    );
  }

  /// Constructor con estilo de desvanecimiento y micro-zoom (dashboards y cambios de contexto).
  factory HavenPageRoute.fadeScale({
    required WidgetBuilder builder,
    RouteSettings? settings,
    Duration? transitionDuration,
    Duration? reverseTransitionDuration,
  }) {
    return HavenPageRoute<T>(
      builder: builder,
      transitionType: HavenTransitionType.fadeScale,
      settings: settings,
      transitionDuration: transitionDuration,
      reverseTransitionDuration: reverseTransitionDuration,
    );
  }

  /// Atajo para navegar hacia una nueva página con HavenPageRoute.
  static Future<T?> push<T>(
    BuildContext context,
    Widget page, {
    HavenTransitionType type = HavenTransitionType.slideHorizontal,
    bool fullscreenDialog = false,
  }) {
    return Navigator.of(context).push<T>(
      HavenPageRoute<T>(
        builder: (_) => page,
        transitionType: type,
        fullscreenDialog: fullscreenDialog,
      ),
    );
  }

  /// Atajo para reemplazar la pantalla actual con HavenPageRoute.
  static Future<T?> pushReplacement<T, TO>(
    BuildContext context,
    Widget page, {
    HavenTransitionType type = HavenTransitionType.slideHorizontal,
  }) {
    return Navigator.of(context).pushReplacement<T, TO>(
      HavenPageRoute<T>(
        builder: (_) => page,
        transitionType: type,
      ),
    );
  }

  // --- Transiciones internas ---

  static Widget _buildSlideUpTransition({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
    required bool enableSecondaryParallax,
  }) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: HavenAnimationCurves.pageEnterCurve,
      reverseCurve: HavenAnimationCurves.pageReverseCurve,
    );

    final slideAnimation = Tween<Offset>(
      begin: HavenAnimationOffsets.slideBottomToTop,
      end: Offset.zero,
    ).animate(curvedAnimation);

    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: HavenAnimationCurves.fadeEnterCurve,
        reverseCurve: HavenAnimationCurves.fadeExitCurve,
      ),
    );

    Widget result = SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: child,
      ),
    );

    if (enableSecondaryParallax) {
      final secondaryScale = Tween<double>(
        begin: 1.0,
        end: 0.96,
      ).animate(
        CurvedAnimation(
          parent: secondaryAnimation,
          curve: HavenAnimationCurves.pageExitCurve,
          reverseCurve: HavenAnimationCurves.pageReverseCurve,
        ),
      );

      final secondaryFade = Tween<double>(
        begin: 1.0,
        end: HavenAnimationOffsets.secondaryMinOpacity,
      ).animate(secondaryAnimation);

      result = ScaleTransition(
        scale: secondaryScale,
        child: FadeTransition(
          opacity: secondaryFade,
          child: result,
        ),
      );
    }

    return result;
  }

  static Widget _buildFadeScaleTransition({
    required BuildContext context,
    required Animation<double> animation,
    required Animation<double> secondaryAnimation,
    required Widget child,
  }) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: HavenAnimationCurves.pageEnterCurve,
      reverseCurve: HavenAnimationCurves.pageReverseCurve,
    );

    final scaleAnimation = Tween<double>(
      begin: HavenAnimationOffsets.scaleStart,
      end: 1.0,
    ).animate(curvedAnimation);

    final fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: HavenAnimationCurves.fadeEnterCurve,
        reverseCurve: HavenAnimationCurves.fadeExitCurve,
      ),
    );

    return ScaleTransition(
      scale: scaleAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: child,
      ),
    );
  }
}
