import 'package:flutter_test/flutter_test.dart';
import 'package:haven/Utils/sound_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SoundHelper Tests', () {
    test('playScannerBeep executes safely without unhandled exceptions', () async {
      await expectLater(SoundHelper.playScannerBeep(), completes);
    });

    test('playSuccessBeep executes safely without unhandled exceptions', () async {
      await expectLater(SoundHelper.playSuccessBeep(), completes);
    });

    test('playErrorBeep executes safely without unhandled exceptions', () async {
      await expectLater(SoundHelper.playErrorBeep(), completes);
    });

    test('dispose cleans up resources', () async {
      await expectLater(SoundHelper.dispose(), completes);
    });
  });
}
