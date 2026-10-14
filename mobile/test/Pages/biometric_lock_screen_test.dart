import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:haven/Models/auth_user.dart';
import 'package:haven/Pages/biometric_lock_screen.dart';
import 'package:haven/Services/app_controller.dart';
import 'package:haven/Services/biometric_service.dart';

class MockAppController extends Mock implements AppController {}
class MockBiometricService extends Mock implements BiometricService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAppController mockController;
  late MockBiometricService mockBiometricService;

  setUp(() {
    mockController = MockAppController();
    mockBiometricService = MockBiometricService();

    when(() => mockController.currentUser).thenReturn(
      const AuthUser(
        id: 'user-123',
        email: 'residente@haven.com',
        nombre: 'Carlos',
        apellidos: 'Santana',
        rol: 'Residente',
      ),
    );

    when(() => mockBiometricService.authenticate(
          localizedReason: any(named: 'localizedReason'),
        )).thenAnswer((_) async => true);
  });

  testWidgets('BiometricLockScreen renders lock UI and unlock button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BiometricLockScreen(
          controller: mockController,
          biometricService: mockBiometricService,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Aplicación Bloqueada'), findsOneWidget);
    expect(find.byKey(const Key('btn_desbloquear_biometria')), findsOneWidget);
    expect(find.byKey(const Key('btn_cerrar_sesion_lock')), findsOneWidget);
  });

  testWidgets('Automatic authentication on mount triggers unlockBiometric on success', (tester) async {
    when(() => mockController.unlockBiometric()).thenReturn(null);

    await tester.pumpWidget(
      MaterialApp(
        home: BiometricLockScreen(
          controller: mockController,
          biometricService: mockBiometricService,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    verify(() => mockBiometricService.authenticate(localizedReason: any(named: 'localizedReason'))).called(1);
    verify(() => mockController.unlockBiometric()).called(1);
  });

  testWidgets('Cerrar sesion button calls controller logout', (tester) async {
    when(() => mockController.logout()).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        home: BiometricLockScreen(
          controller: mockController,
          biometricService: mockBiometricService,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('btn_cerrar_sesion_lock')));
    await tester.pump();

    verify(() => mockController.logout()).called(1);
  });
}
