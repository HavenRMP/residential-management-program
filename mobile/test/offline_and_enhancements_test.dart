import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:haven/Models/visita_model.dart';
import 'package:haven/Services/offline_sync_service.dart';
import 'package:haven/Services/app_controller.dart';
import 'package:haven/Pages/login_screen.dart';
import 'package:haven/Utils/haptic_helper.dart';
import 'package:haven/Widgets/digital_pass_card.dart';
import 'package:haven/Widgets/offline_banner.dart';
import 'package:haven/Widgets/skeleton_loading.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HapticHelper Tests', () {
    test('Haptic methods execute without error', () async {
      await HapticHelper.light();
      await HapticHelper.selection();
      await HapticHelper.success();
      await HapticHelper.error();
      expect(true, isTrue);
    });
  });

  group('OfflineSyncService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('generateIdempotencyKey generates unique, well-formed key', () {
      final key1 = OfflineSyncService.generateIdempotencyKey('entrada', 'visita-101');
      final key2 = OfflineSyncService.generateIdempotencyKey('entrada', 'visita-101');

      expect(key1.startsWith('idemp_entrada_visita-101_'), isTrue);
      expect(key2.startsWith('idemp_entrada_visita-101_'), isTrue);
      expect(key1 != key2, isTrue); // Timestamp / random entropy makes each unique
    });

    test('queueOfflineApproval queues item and persists to SharedPreferences', () async {
      final action = await OfflineSyncService.queueOfflineApproval(
        visitaId: 'visita-999',
        tipo: 'entrada',
        nombreVisitante: 'Carlos Santana',
        numeroCasa: '42B',
      );

      expect(action.visitaId, equals('visita-999'));
      expect(action.tipo, equals('entrada'));
      expect(action.nombreVisitante, equals('Carlos Santana'));
      expect(action.numeroCasa, equals('42B'));
      expect(action.idempotencyKey.isNotEmpty, isTrue);

      final pending = await OfflineSyncService.getPendingApprovals();
      expect(pending.length, equals(1));
      expect(pending.first.visitaId, equals('visita-999'));
      expect(pending.first.idempotencyKey, equals(action.idempotencyKey));
    });

    test('cacheVisitasProximas and getCachedVisitasProximas round-trip', () async {
      final testVisita = VisitaModel(
        id: 'vis-1',
        viviendaId: 10,
        numeroCasa: '12A',
        nombreVisitante: 'Laura',
        apellidosVisitante: 'Gómez',
        motivo: 'Familiar',
        numAcompanantes: 2,
        fechaLlegadaEsperada: DateTime(2026, 10, 2, 14, 0),
        vigenciaHasta: DateTime(2026, 10, 2, 20, 0),
        estado: 'programada',
        codigo: 'HAV-1234',
      );

      await OfflineSyncService.cacheVisitasProximas([testVisita]);
      final cached = await OfflineSyncService.getCachedVisitasProximas();

      expect(cached.length, equals(1));
      expect(cached.first.id, equals('vis-1'));
      expect(cached.first.nombreCompletoVisitante, equals('Laura Gómez'));
      expect(cached.first.codigo, equals('HAV-1234'));
    });

    test('cacheVisitasResidente and getCachedVisitasResidente round-trip', () async {
      final testVisita = VisitaModel(
        id: 'vis-2',
        viviendaId: 15,
        numeroCasa: '30B',
        nombreVisitante: 'Pedro',
        apellidosVisitante: 'Páramo',
        motivo: 'Entrega',
        numAcompanantes: 0,
        fechaLlegadaEsperada: DateTime(2026, 10, 2, 15, 0),
        vigenciaHasta: DateTime(2026, 10, 2, 18, 0),
        estado: 'en_curso',
        codigo: 'HAV-5678',
      );

      await OfflineSyncService.cacheVisitasResidente([testVisita]);
      final cached = await OfflineSyncService.getCachedVisitasResidente();

      expect(cached.length, equals(1));
      expect(cached.first.id, equals('vis-2'));
      expect(cached.first.nombreCompletoVisitante, equals('Pedro Páramo'));
      expect(cached.first.estado, equals('en_curso'));
    });
  });

  group('SkeletonLoading Widgets Tests', () {
    testWidgets('SkeletonBox renders with specified dimensions', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SkeletonBox(width: 120, height: 40, borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );

      final box = find.byType(SkeletonBox);
      expect(box, findsOneWidget);
    });

    testWidgets('SkeletonCard renders layout elements', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonCard(),
          ),
        ),
      );

      expect(find.byType(SkeletonCard), findsOneWidget);
    });

    testWidgets('SkeletonVisitasList renders requested number of cards', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SkeletonVisitasList(itemCount: 3),
            ),
          ),
        ),
      );

      expect(find.byType(SkeletonVisitasList), findsOneWidget);
      expect(find.byType(SkeletonCard), findsNWidgets(3));
    });
  });

  group('OfflineBanner Tests', () {
    testWidgets('Renders message and triggers onSyncPressed', (tester) async {
      bool syncTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OfflineBanner(
              mensaje: 'Modo sin internet',
              pendingSyncCount: 2,
              onSyncPressed: () {
                syncTriggered = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Modo sin internet (2 pendientes)'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

      final retryButton = find.text('Reintentar');
      expect(retryButton, findsOneWidget);

      await tester.tap(retryButton);
      await tester.pump();

      expect(syncTriggered, isTrue);
    });
  });

  group('DigitalPassCard Tests', () {
    testWidgets('Renders access code, title, and visitor name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DigitalPassCard(
                codigo: 'HAV-ABC123',
                titulo: 'Pase Exclusivo',
                nombreVisitante: 'Mariana Robles',
                tipoEtiqueta: 'Casa 102',
              ),
            ),
          ),
        ),
      );

      expect(find.text('HAV-ABC123'), findsOneWidget);
      expect(find.text('Pase Exclusivo'), findsOneWidget);
      expect(find.text('Para: Mariana Robles'), findsOneWidget);
      expect(find.text('Casa 102'), findsOneWidget);
    });
  });

  group('LoginScreen Remember Email Tests', () {
    testWidgets('Renders remember email checkbox and toggles', (tester) async {
      SharedPreferences.setMockInitialValues({'saved_login_email': 'test@haven.com', 'remember_login_email': true});
      final controller = AppController(null);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Recordar mi correo'), findsOneWidget);
      expect(find.byType(Checkbox), findsOneWidget);

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);

      // Tap on the text label to toggle
      await tester.tap(find.text('Recordar mi correo'));
      await tester.pumpAndSettle();

      final updatedCheckbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(updatedCheckbox.value, isFalse);
    });
  });
}
