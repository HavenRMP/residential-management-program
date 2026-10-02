import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerView extends StatefulWidget {
  const QrScannerView({
    super.key,
    required this.onScanned,
    this.titulo = 'Escanear Código QR',
    this.instrucciones = 'Apunta la cámara hacia el código QR de acceso',
    this.isEmbedded = false,
  });

  final ValueChanged<String> onScanned;
  final String titulo;
  final String instrucciones;
  final bool isEmbedded;

  static Future<String?> openScanner(
    BuildContext context, {
    String titulo = 'Escanear Código QR',
    String instrucciones = 'Apunta la cámara hacia el código QR de acceso',
  }) {
    return Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(
            title: Text(titulo),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          backgroundColor: Colors.black,
          body: QrScannerView(
            onScanned: (code) {
              Navigator.pop(ctx, code);
            },
            titulo: titulo,
            instrucciones: instrucciones,
            isEmbedded: false,
          ),
        ),
      ),
    );
  }

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView> with WidgetsBindingObserver {
  late final MobileScannerController _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final val = barcode.rawValue?.trim();
      if (val != null && val.isNotEmpty) {
        _isProcessing = true;
        widget.onScanned(val);
        // Desbloquear tras 2 segundos si la pantalla sigue montada
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            _isProcessing = false;
          }
        });
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Visor de Cámara
        MobileScanner(
          controller: _controller,
          onDetect: _handleBarcode,
          errorBuilder: (context, error) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.videocam_off_outlined, color: Colors.white70, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'No se pudo acceder a la cámara (${error.errorCode.name}).\nVerifica los permisos en ajustes.',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // Marco del escáner (Overlay)
        Center(
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              children: [
                // Esquinas destacadas
                Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFF38BDF8), width: 4),
                        left: BorderSide(color: Color(0xFF38BDF8), width: 4),
                      ),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(18)),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFF38BDF8), width: 4),
                        right: BorderSide(color: Color(0xFF38BDF8), width: 4),
                      ),
                      borderRadius: BorderRadius.only(topRight: Radius.circular(18)),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomLeft,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF38BDF8), width: 4),
                        left: BorderSide(color: Color(0xFF38BDF8), width: 4),
                      ),
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(18)),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFF38BDF8), width: 4),
                        right: BorderSide(color: Color(0xFF38BDF8), width: 4),
                      ),
                      borderRadius: BorderRadius.only(bottomRight: Radius.circular(18)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Textos y Controles Superiores / Inferiores
        SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Barra superior de instrucciones
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.instrucciones,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),

              // Botones de acción inferiores (Flash y Cambiar Cámara)
              Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Botón Linterna
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(14),
                      ),
                      onPressed: () => _controller.toggleTorch(),
                      icon: const Icon(Icons.flash_on_rounded, size: 24),
                      tooltip: 'Linterna',
                    ),
                    const SizedBox(width: 24),
                    // Botón Voltear Cámara
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.25),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(14),
                      ),
                      onPressed: () => _controller.switchCamera(),
                      icon: const Icon(Icons.flip_camera_ios_rounded, size: 24),
                      tooltip: 'Cambiar cámara',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
