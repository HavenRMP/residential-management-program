import 'package:flutter_test/flutter_test.dart';
import 'package:haven/Utils/brightness_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BrightnessHelper Tests', () {
    test('setMaxBrightness and resetBrightness execute safely without exceptions', () async {
      await expectLater(BrightnessHelper.setMaxBrightness(), completes);
      await expectLater(BrightnessHelper.resetBrightness(), completes);
    });
  });
}
