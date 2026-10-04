import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Utils/haptic_helper.dart';

/// Fábrica interactiva de tinta que añade retroalimentación háptica automática
/// a todos los botones (Elevated, Text, Outlined, Icon, Chips, NavigationBar, InkWell)
/// de la aplicación Material.
class HapticSplashFactory extends InteractiveInkFeatureFactory {
  final InteractiveInkFeatureFactory parentFactory;

  const HapticSplashFactory([this.parentFactory = InkRipple.splashFactory]);

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    HapticHelper.light();
    return parentFactory.create(
      controller: controller,
      referenceBox: referenceBox,
      position: position,
      color: color,
      textDirection: textDirection,
      containedInkWell: containedInkWell,
      rectCallback: rectCallback,
      borderRadius: borderRadius,
      customBorder: customBorder,
      radius: radius,
      onRemoved: onRemoved,
    );
  }
}

class AppTheme {
  static const seed = Color(0xFF111C99);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: const Color(0xFFF7F7F7),
      fontFamily: GoogleFonts.openSans().fontFamily,
      splashFactory: const HapticSplashFactory(),
    );
  }

  static InputDecoration inputDecoration(
    String hintText, {
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFF87171)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFF87171), width: 1.5),
      ),
    );
  }
}
