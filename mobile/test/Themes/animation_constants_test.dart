import 'package:flutter_test/flutter_test.dart';
import 'package:haven/Themes/animation_constants.dart';

void main() {
  group('HavenAnimationDurations Tests', () {
    test('pageTransition y pageTransitionReverse tienen duraciones balanceadas', () {
      expect(HavenAnimationDurations.pageTransition.inMilliseconds, equals(320));
      expect(HavenAnimationDurations.pageTransitionReverse.inMilliseconds, equals(280));
      expect(
        HavenAnimationDurations.pageTransitionReverse <
            HavenAnimationDurations.pageTransition,
        isTrue,
      );
    });

    test('duraciones complementarias mantienen coherencia temporal', () {
      expect(HavenAnimationDurations.pageTransitionFast.inMilliseconds, equals(200));
      expect(HavenAnimationDurations.pageTransitionSlow.inMilliseconds, equals(450));
      expect(HavenAnimationDurations.stateSwitch.inMilliseconds, equals(250));
      expect(HavenAnimationDurations.microInteraction.inMilliseconds, equals(150));
    });
  });

  group('HavenAnimationCurves Tests', () {
    test('curvas se evalúan dentro del rango 0.0 a 1.0', () {
      expect(HavenAnimationCurves.pageEnterCurve.transform(0.0), closeTo(0.0, 0.001));
      expect(HavenAnimationCurves.pageEnterCurve.transform(1.0), closeTo(1.0, 0.001));

      expect(HavenAnimationCurves.pageExitCurve.transform(0.0), closeTo(0.0, 0.001));
      expect(HavenAnimationCurves.pageExitCurve.transform(1.0), closeTo(1.0, 0.001));

      expect(HavenAnimationCurves.pageReverseCurve.transform(0.0), closeTo(0.0, 0.001));
      expect(HavenAnimationCurves.pageReverseCurve.transform(1.0), closeTo(1.0, 0.001));
    });

    test('curva de fade temprano alcanza 1.0 antes del final del ciclo', () {
      expect(HavenAnimationCurves.fadeEnterCurve.transform(0.0), equals(0.0));
      expect(HavenAnimationCurves.fadeEnterCurve.transform(0.65), closeTo(1.0, 0.01));
      expect(HavenAnimationCurves.fadeEnterCurve.transform(1.0), equals(1.0));
    });
  });

  group('HavenAnimationOffsets Tests', () {
    test('offsets geométricos tienen valores ergonómicos', () {
      expect(HavenAnimationOffsets.slideRightToLeft, equals(const Offset(1.0, 0.0)));
      expect(HavenAnimationOffsets.slideBottomToTop.dy, greaterThan(0.0));
      expect(HavenAnimationOffsets.secondarySlideBack.dx, lessThan(0.0));
      expect(HavenAnimationOffsets.scaleStart, equals(0.95));
      expect(HavenAnimationOffsets.secondaryMinOpacity, equals(0.85));
    });
  });
}
