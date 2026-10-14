import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haven/Widgets/qr_scanner_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('QrScannerView renders camera overlay and control buttons', (tester) async {
    String? scannedValue;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QrScannerView(
            onScanned: (val) {
              scannedValue = val;
            },
            titulo: 'Escanear Pase',
            instrucciones: 'Apunta la cámara al código QR',
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Apunta la cámara al código QR'), findsOneWidget);
    expect(find.byIcon(Icons.flash_on_rounded), findsOneWidget);
    expect(find.byIcon(Icons.flip_camera_ios_rounded), findsOneWidget);
    expect(scannedValue, isNull);
  });
}
