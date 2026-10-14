import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:haven/Services/biometric_service.dart';

class MockLocalAuthentication extends Mock implements LocalAuthentication {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockLocalAuthentication mockLocalAuth;
  late BiometricService biometricService;

  setUp(() {
    mockLocalAuth = MockLocalAuthentication();
    SharedPreferences.setMockInitialValues({});
  });

  group('BiometricService Tests', () {
    test('isDeviceSupported returns true when localAuth confirms support', () async {
      when(() => mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
      biometricService = BiometricService(localAuth: mockLocalAuth);

      final supported = await biometricService.isDeviceSupported();
      expect(supported, isTrue);
    });

    test('canCheckBiometrics returns true when supported and can check', () async {
      when(() => mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
      when(() => mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
      biometricService = BiometricService(localAuth: mockLocalAuth);

      final canCheck = await biometricService.canCheckBiometrics();
      expect(canCheck, isTrue);
    });

    test('hasEnrolledBiometrics returns true when list is not empty', () async {
      when(() => mockLocalAuth.getAvailableBiometrics())
          .thenAnswer((_) async => [BiometricType.fingerprint]);
      biometricService = BiometricService(localAuth: mockLocalAuth);

      final enrolled = await biometricService.hasEnrolledBiometrics();
      expect(enrolled, isTrue);
    });

    test('isBiometricEnabled and setBiometricEnabled persist preference', () async {
      final prefs = await SharedPreferences.getInstance();
      biometricService = BiometricService(localAuth: mockLocalAuth, prefs: prefs);

      expect(await biometricService.isBiometricEnabled(), isFalse);

      await biometricService.setBiometricEnabled(true);
      expect(await biometricService.isBiometricEnabled(), isTrue);

      await biometricService.setBiometricEnabled(false);
      expect(await biometricService.isBiometricEnabled(), isFalse);
    });

    test('authenticate delegates to localAuth and returns result', () async {
      when(() => mockLocalAuth.isDeviceSupported()).thenAnswer((_) async => true);
      when(() => mockLocalAuth.canCheckBiometrics).thenAnswer((_) async => true);
      when(() => mockLocalAuth.authenticate(
            localizedReason: any(named: 'localizedReason'),
            biometricOnly: any(named: 'biometricOnly'),
            persistAcrossBackgrounding: any(named: 'persistAcrossBackgrounding'),
            sensitiveTransaction: any(named: 'sensitiveTransaction'),
          )).thenAnswer((_) async => true);

      biometricService = BiometricService(localAuth: mockLocalAuth);

      final result = await biometricService.authenticate(localizedReason: 'Test reason');
      expect(result, isTrue);
    });
  });
}
