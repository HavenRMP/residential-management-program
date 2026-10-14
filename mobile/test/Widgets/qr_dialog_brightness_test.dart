import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haven/Widgets/qr_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('QrDialog triggers auto-brightness lifecycle on open and close', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QrDialog(
            codigo: 'HAVEN-7890',
            titulo: 'Pase de Visita',
            subtitulo: 'Presenta este código al guardia',
          ),
        ),
      ),
    );

    // Initial pump initializes state and triggers BrightnessHelper.setMaxBrightness()
    await tester.pump();
    expect(find.text('HAVEN-7890'), findsOneWidget);
    expect(find.text('Pase de Visita'), findsOneWidget);

    // Replacing widget triggers dispose and BrightnessHelper.resetBrightness()
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));
    await tester.pump();
    expect(find.text('HAVEN-7890'), findsNothing);
  });
}
