import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:haven/Models/auth_user.dart';
import 'package:haven/Pages/perfil_screen.dart';
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
        telefono: '4421234567',
      ),
    );
    when(() => mockController.isProfileIncomplete).thenReturn(false);
    when(() => mockController.isLoading).thenReturn(false);

    when(() => mockBiometricService.canCheckBiometrics()).thenAnswer((_) async => true);
    when(() => mockBiometricService.isBiometricEnabled()).thenAnswer((_) async => true);
  });

  testWidgets('PerfilScreen renders biometric security switch tile', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PerfilScreen(
          controller: mockController,
          biometricService: mockBiometricService,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('ACCESO CON BIOMÉTRICOS'), findsOneWidget);
    expect(find.byKey(const Key('switch_biometria_perfil')), findsOneWidget);
    expect(find.text('Desbloquear app con huella o rostro'), findsOneWidget);

    final switchFinder = find.byKey(const Key('switch_biometria_perfil'));
    final switchWidget = tester.widget<Switch>(switchFinder);
    expect(switchWidget.value, isTrue);
  });
}
