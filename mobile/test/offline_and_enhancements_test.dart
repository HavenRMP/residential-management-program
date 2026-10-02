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

  }
