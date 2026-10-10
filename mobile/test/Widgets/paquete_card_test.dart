import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haven/Models/paquete_model.dart';
import 'package:haven/Widgets/paquete_card.dart';

void main() {
  group('PaqueteCard Widget Tests', () {
    testWidgets('Renderiza correctamente datos del paquete esperado', (tester) async {
      final paquete = PaqueteModel(
        id: 'pkg-1',
        viviendaId: 10,
        numeroCasa: '15A',
        destinatarioNombre: 'Carlos Santana',
        servicioNombre: 'Amazon',
        numeroGuia: 'AMZ-123456',
        estado: 'esperado',
      );

      bool cancelCalled = false;
      bool editCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaqueteCard(
              paquete: paquete,
              onCancel: () => cancelCalled = true,
              onEdit: () => editCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Amazon'), findsOneWidget);
      expect(find.text('Destinatario: Carlos Santana'), findsOneWidget);
      expect(find.text('Casa #15A'), findsOneWidget);
      expect(find.text('AMZ-123456'), findsOneWidget);
      expect(find.text('Esperado'), findsOneWidget);

      final editBtn = find.text('Modificar');
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      expect(editCalled, isTrue);

      final cancelBtn = find.text('Cancelar');
      expect(cancelBtn, findsOneWidget);
      await tester.tap(cancelBtn);
      expect(cancelCalled, isTrue);
    });

    testWidgets('Renderiza acciones de caseta cuando showCasetaActions es true', (tester) async {
      final paqueteRecibido = PaqueteModel(
        id: 'pkg-2',
        viviendaId: 8,
        numeroCasa: '42',
        destinatarioNombre: 'Luisa Gomez',
        servicioNombre: 'DHL',
        estado: 'recibido',
        ubicacionAlmacen: 'Gaveta 5',
      );

      bool deliverCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PaqueteCard(
              paquete: paqueteRecibido,
              showCasetaActions: true,
              onDeliver: () => deliverCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('En Caseta'), findsOneWidget);
      expect(find.text('Ubicación en caseta: Gaveta 5'), findsOneWidget);

      final deliverBtn = find.text('Entregar a Residente');
      expect(deliverBtn, findsOneWidget);
      await tester.tap(deliverBtn);
      expect(deliverCalled, isTrue);
    });
  });
}
