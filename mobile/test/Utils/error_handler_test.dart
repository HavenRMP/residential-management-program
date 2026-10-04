import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:haven/Utils/error_handler.dart';

void main() {
  group('ErrorHandler.extractErrorMessage Tests', () {
    test('Extrae mensaje de campo "error"', () {
      final jsonStr = '{"error": "El número de casa ya existe en este condominio"}';
      final msg = ErrorHandler.extractErrorMessage(jsonStr, statusCode: 400);
      expect(msg, 'El número de casa ya existe en este condominio');
    });

    test('Extrae mensaje de campo "message"', () {
      final jsonStr = '{"message": "La visita ha sido cancelada previamente"}';
      final msg = ErrorHandler.extractErrorMessage(jsonStr, statusCode: 400);
      expect(msg, 'La visita ha sido cancelada previamente');
    });

    test('Extrae mensaje de campo "detail" (RFC 7807 Problem Details)', () {
      final jsonStr = '{"title": "Bad Request", "status": 400, "detail": "La fecha de llegada no puede ser en el pasado"}';
      final msg = ErrorHandler.extractErrorMessage(jsonStr, statusCode: 400);
      expect(msg, 'La fecha de llegada no puede ser en el pasado');
    });

    test('Extrae y combina errores de validación de ASP.NET Core {"errors": {...}}', () {
      final jsonStr = '{"errors": {"Nombre": ["El campo es obligatorio."], "Email": ["Formato de correo no válido."]}}';
      final msg = ErrorHandler.extractErrorMessage(jsonStr, statusCode: 400);
      expect(msg, 'El campo es obligatorio. Formato de correo no válido.');
    });

    test('Maneja páginas de error HTML (e.g. Render 502 Bad Gateway) mapeando al código de estado sin volcar HTML', () {
      final html = '<!DOCTYPE html><html><head><title>502 Bad Gateway</title></head><body><h1>Bad Gateway</h1></body></html>';
      final msg = ErrorHandler.extractErrorMessage(html, statusCode: 502);
      expect(msg, contains('El servidor está temporalmente fuera de servicio'));
      expect(msg.contains('<html'), isFalse);
    });

    test('Mapea correctamente status codes cuando no hay body específico', () {
      expect(ErrorHandler.extractErrorMessage('', statusCode: 401), contains('sesión'));
      expect(ErrorHandler.extractErrorMessage('', statusCode: 403), contains('permisos'));
      expect(ErrorHandler.extractErrorMessage('', statusCode: 404), contains('no fue encontrado'));
      expect(ErrorHandler.extractErrorMessage('', statusCode: 409), contains('Conflicto'));
      expect(ErrorHandler.extractErrorMessage('', statusCode: 429), contains('demasiadas solicitudes'));
      expect(ErrorHandler.extractErrorMessage('', statusCode: 500), contains('error interno'));
      expect(ErrorHandler.extractErrorMessage('', statusCode: 503), contains('no se encuentra disponible'));
      expect(ErrorHandler.extractErrorMessage('', statusCode: 504), contains('Tiempo de espera'));
    });

    test('No expone stack traces técnicos si vienen en el body', () {
      final stackBody = 'Internal Server Error: at System.Runtime.ExceptionServices.ExceptionDispatchInfo.Throw()';
      final msg = ErrorHandler.extractErrorMessage(stackBody, statusCode: 500);
      expect(msg.contains('System.Runtime'), isFalse);
      expect(msg, contains('error interno'));
    });
  });

  group('ErrorHandler.parseException Tests', () {
    test('Parsea TimeoutException con mensaje descriptivo', () {
      final msg = ErrorHandler.parseException(TimeoutException('Request timed out'));
      expect(msg, contains('Conexión débil o lenta. Tiempo de espera agotado.'));
    });

    test('Parsea SocketException con mensaje descriptivo de sin conexión', () {
      final msg = ErrorHandler.parseException(const SocketException('Failed host lookup'));
      expect(msg, contains('Sin conexión a internet'));
    });

    test('Parsea FormatException sin crasheos', () {
      final msg = ErrorHandler.parseException(const FormatException('Unexpected character'));
      expect(msg, contains('formato inesperado'));
    });

    test('Traduce AuthException de Supabase a mensajes amigables en español', () {
      final errCreds = const AuthException('Invalid login credentials');
      expect(ErrorHandler.parseException(errCreds), 'Correo o contraseña incorrectos. Verifica tus credenciales.');

      final errReg = const AuthException('User already registered');
      expect(ErrorHandler.parseException(errReg), 'El correo electrónico ya se encuentra registrado.');

      final errPass = const AuthException('Password should be at least 6 characters');
      expect(ErrorHandler.parseException(errPass), 'La contraseña debe tener al menos 6 caracteres.');
    });

    test('Parsea códigos de error de negocio de subusuarios (CD001, SU001, SU003)', () {
      expect(
        ErrorHandler.parseException(Exception('Error CD001: El código de invitación no existe')),
        contains('código de invitación no existe'),
      );
      expect(
        ErrorHandler.parseException(Exception('Error SU001: Límite alcanzado')),
        contains('Límite máximo de 2 sub-usuarios'),
      );
      expect(
        ErrorHandler.parseException(Exception('Error SU003: ya está vinculado a la vivienda')),
        contains('Ya te encuentras vinculado'),
      );
    });

    test('Limpia prefijos de excepciones técnicas y nunca crashea con null', () {
      expect(ErrorHandler.parseException(null), isNotEmpty);
      expect(ErrorHandler.parseException(Exception('El residente ya no habita aquí')), 'El residente ya no habita aquí');
    });
  });
}
