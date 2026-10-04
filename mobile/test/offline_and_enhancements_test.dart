import 'dart:async';
import 'dart:io';
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

    test('isStrictlyOfflineError correctly distinguishes no connection vs weak connection', () {
      // Conexión débil: timeouts o strings de timeout -> NO es sin conexión
      expect(OfflineSyncService.isStrictlyOfflineError(TimeoutException('Request timed out')), isFalse);
      expect(OfflineSyncService.isStrictlyOfflineError(Exception('Connection timed out after 30s')), isFalse);
      expect(OfflineSyncService.isStrictlyOfflineError(Exception('deadline exceeded')), isFalse);

      // Desconexión absoluta: SocketException o interfaces caídas
      expect(OfflineSyncService.isStrictlyOfflineError(const SocketException('Failed host lookup')), isTrue);
      expect(OfflineSyncService.isStrictlyOfflineError(const SocketException('Network is unreachable')), isTrue);
      expect(OfflineSyncService.isStrictlyOfflineError(Exception('No address associated with hostname')), isTrue);
      expect(OfflineSyncService.isStrictlyOfflineError(Exception('ClientException with SocketException: OS Error: network error')), isTrue);
    });

    test('cacheVisitasAdmin and getCachedVisitasAdmin round-trip', () async {
      final testVisita = VisitaModel(
        id: 'vis-admin-1',
        viviendaId: 20,
        numeroCasa: '50C',
        nombreVisitante: 'Arturo',
        apellidosVisitante: 'Mendoza',
        motivo: 'Mantenimiento',
        numAcompanantes: 1,
        fechaLlegadaEsperada: DateTime(2026, 10, 3, 10, 0),
        vigenciaHasta: DateTime(2026, 10, 3, 18, 0),
        estado: 'completada',
      );

      await OfflineSyncService.cacheVisitasAdmin([testVisita]);
      final cached = await OfflineSyncService.getCachedVisitasAdmin();

      expect(cached.length, equals(1));
      expect(cached.first.id, equals('vis-admin-1'));
      expect(cached.first.nombreCompletoVisitante, equals('Arturo Mendoza'));
    });

    test('Avisos endpoints cache round-trip', () async {
      final avisos = [
        {'id': 'av-1', 'titulo': 'Corte de agua', 'contenido': 'Mantenimiento preventivo'},
      ];
      final historico = [
        {'id': 'av-hist-1', 'titulo': 'Aviso pasado', 'contenido': 'Contenido histórico'},
      ];

      await OfflineSyncService.cacheAvisosVigentes(avisos);
      await OfflineSyncService.cacheAvisosHistorico(historico);

      final cachedVigentes = await OfflineSyncService.getCachedAvisosVigentes();
      final cachedHistorico = await OfflineSyncService.getCachedAvisosHistorico();

      expect(cachedVigentes.length, equals(1));
      expect(cachedVigentes.first['titulo'], equals('Corte de agua'));
      expect(cachedHistorico.length, equals(1));
      expect(cachedHistorico.first['titulo'], equals('Aviso pasado'));
    });

    test('Viviendas endpoints cache round-trip', () async {
      final viviendas = [
        {'id': 10, 'numeroCasa': '101', 'tipo': 'casa'},
      ];
      final misViviendas = [
        {'id': 10, 'numeroCasa': '101', 'tipo': 'casa', 'activo': true},
      ];

      await OfflineSyncService.cacheViviendas(viviendas);
      await OfflineSyncService.cacheViviendasConResidentes(viviendas);
      await OfflineSyncService.cacheMisViviendas(misViviendas);

      final cachedV = await OfflineSyncService.getCachedViviendas();
      final cachedConRes = await OfflineSyncService.getCachedViviendasConResidentes();
      final cachedMis = await OfflineSyncService.getCachedMisViviendas();

      expect(cachedV.length, equals(1));
      expect(cachedConRes.length, equals(1));
      expect(cachedMis.length, equals(1));
      expect(cachedMis.first['numeroCasa'], equals('101'));
    });

    test('Subusuarios and MisInvitaciones cache round-trip', () async {
      final subusuarios = [
        {'id': 'sub-1', 'email': 'familiar@haven.com', 'parentesco': 'Hermano'},
      ];
      final invitaciones = [
        {'id': 'inv-1', 'codigoInvitacion': 'HAV-INV-99', 'estado': 'pendiente'},
      ];

      await OfflineSyncService.cacheSubusuarios(10, subusuarios);
      await OfflineSyncService.cacheMisInvitaciones(invitaciones);

      final cachedSub = await OfflineSyncService.getCachedSubusuarios(10);
      final cachedInv = await OfflineSyncService.getCachedMisInvitaciones();

      expect(cachedSub.length, equals(1));
      expect(cachedSub.first['email'], equals('familiar@haven.com'));
      expect(cachedInv.length, equals(1));
      expect(cachedInv.first['codigoInvitacion'], equals('HAV-INV-99'));
    });

    test('Notificaciones cache round-trip', () async {
      final notifs = [
        {
          'id': 'notif-1',
          'titulo': 'Acceso autorizado',
          'mensaje': 'Tu visita ha entrado',
          'leida': false,
          'creado_en': DateTime(2026, 10, 3).toIso8601String(),
        }
      ];

      await OfflineSyncService.cacheNotificaciones(notifs);
      final cached = await OfflineSyncService.getCachedNotificaciones();

      expect(cached.length, equals(1));
      expect(cached.first['titulo'], equals('Acceso autorizado'));
    });

    test('canApproveOffline permits ONLY downloaded expected non-expired visits', () async {
      final esperada = VisitaModel(
        id: 'vis-esperada-1',
        viviendaId: 10,
        numeroCasa: '12A',
        nombreVisitante: 'Mario',
        apellidosVisitante: 'Bros',
        motivo: 'Fontanería',
        numAcompanantes: 0,
        fechaLlegadaEsperada: DateTime.now().add(const Duration(hours: 1)),
        vigenciaHasta: DateTime.now().add(const Duration(hours: 6)),
        estado: 'programada',
      );

      final yaIngresada = VisitaModel(
        id: 'vis-ingresada-2',
        viviendaId: 10,
        numeroCasa: '12A',
        nombreVisitante: 'Luigi',
        apellidosVisitante: 'Bros',
        motivo: 'Visita',
        numAcompanantes: 0,
        fechaLlegadaEsperada: DateTime.now().subtract(const Duration(hours: 2)),
        vigenciaHasta: DateTime.now().add(const Duration(hours: 4)),
        estado: 'ingresada',
      );

      final expirada = VisitaModel(
        id: 'vis-expirada-3',
        viviendaId: 10,
        numeroCasa: '12A',
        nombreVisitante: 'Bowser',
        apellidosVisitante: 'Koopa',
        motivo: 'Evento',
        numAcompanantes: 0,
        fechaLlegadaEsperada: DateTime.now().subtract(const Duration(hours: 5)),
        vigenciaHasta: DateTime.now().subtract(const Duration(hours: 1)),
        estado: 'programada',
      );

      await OfflineSyncService.cacheVisitasProximas([esperada, yaIngresada, expirada]);

      // 1. Visita que no fue descargada previamente
      final notDownloaded = await OfflineSyncService.canApproveOffline('vis-no-descargada-999');
      expect(notDownloaded['allowed'], isFalse);
      expect(notDownloaded['reason'], contains('no fue descargada'));

      // 2. Visita descargada pero que NO está en estado esperada (ej. ya ingresada)
      final notExpected = await OfflineSyncService.canApproveOffline('vis-ingresada-2');
      expect(notExpected['allowed'], isFalse);
      expect(notExpected['reason'], contains('no está en estado "esperada"'));

      // 3. Visita descargada y esperada pero EXPIRADA
      final expiredResult = await OfflineSyncService.canApproveOffline('vis-expirada-3');
      expect(expiredResult['allowed'], isFalse);
      expect(expiredResult['reason'], contains('ha expirado'));

      // 4. Visita descargada, esperada y vigente -> ÉXITO
      final allowed = await OfflineSyncService.canApproveOffline('vis-esperada-1');
      expect(allowed['allowed'], isTrue);
      expect(allowed['visita'], isNotNull);
    });

    test('clearAllCache removes all cached endpoints and queue from SharedPreferences', () async {
      final testVisita = VisitaModel(
        id: 'vis-test-clear',
        viviendaId: 1,
        numeroCasa: '1',
        nombreVisitante: 'Test',
        apellidosVisitante: 'User',
        motivo: 'Prueba',
        numAcompanantes: 0,
        fechaLlegadaEsperada: DateTime.now(),
        vigenciaHasta: DateTime.now().add(const Duration(hours: 4)),
        estado: 'programada',
      );

      await OfflineSyncService.cacheVisitasResidente([testVisita]);
      await OfflineSyncService.cacheVisitasProximas([testVisita]);
      await OfflineSyncService.cacheAvisosVigentes([{'id': 1}]);
      await OfflineSyncService.cacheViviendas([{'id': 1}]);
      await OfflineSyncService.cacheNotificaciones([{'id': 'n1'}]);
      await OfflineSyncService.queueOfflineApproval(visitaId: 'vis-test-clear', tipo: 'entrada');

      expect((await OfflineSyncService.getCachedVisitasResidente()).isNotEmpty, isTrue);
      expect((await OfflineSyncService.getCachedVisitasProximas()).isNotEmpty, isTrue);
      expect((await OfflineSyncService.getPendingApprovals()).isNotEmpty, isTrue);

      await OfflineSyncService.clearAllCache();

      expect((await OfflineSyncService.getCachedVisitasResidente()).isEmpty, isTrue);
      expect((await OfflineSyncService.getCachedVisitasProximas()).isEmpty, isTrue);
      expect((await OfflineSyncService.getCachedAvisosVigentes()).isEmpty, isTrue);
      expect((await OfflineSyncService.getCachedViviendas()).isEmpty, isTrue);
      expect((await OfflineSyncService.getCachedNotificaciones()).isEmpty, isTrue);
      expect((await OfflineSyncService.getPendingApprovals()).isEmpty, isTrue);
    });
  });

  group('Global Offline Mode Controller Tests', () {
    test('AppController setOffline toggles state and notifies listeners', () {
      final controller = AppController(null);
      expect(controller.isOffline, isFalse);

      bool notified = false;
      controller.addListener(() {
        notified = true;
      });

      controller.setOffline(true);
      expect(controller.isOffline, isTrue);
      expect(notified, isTrue);

      controller.setOffline(false);
      expect(controller.isOffline, isFalse);
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
