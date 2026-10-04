import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../Services/offline_sync_service.dart';

/// Centralized, standardized error handling utility for the Haven Mobile application.
/// Ensures all API responses, exceptions, and network errors are translated into
/// clear, descriptive, user-friendly messages without crashing or exposing raw technical dumps.
class ErrorHandler {
  const ErrorHandler._();

  /// Extracts a human-readable, descriptive error message from an API response body
  /// or HTTP status code, ensuring no raw HTML, JSON dumps, or technical stack traces are shown.
  static String extractErrorMessage(
    dynamic responseBody, {
    int? statusCode,
    String? defaultMessage,
    String? context,
  }) {
    String? extracted;

    if (responseBody != null) {
      if (responseBody is Map) {
        extracted = _extractFromMap(responseBody.cast<String, dynamic>());
      } else if (responseBody is String && responseBody.trim().isNotEmpty) {
        final trimmed = responseBody.trim();
        // Detect HTML error pages (e.g., Render 502/504, Cloudflare, IIS)
        if (_isHtml(trimmed)) {
          extracted = null; // Fall through to status code mapping
        } else {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is Map) {
              extracted = _extractFromMap(decoded.cast<String, dynamic>());
            } else if (decoded is List && decoded.isNotEmpty) {
              extracted = _extractFromList(decoded);
            } else if (decoded is String && !_isTechnicalString(decoded)) {
              extracted = decoded;
            }
          } catch (_) {
            // Not valid JSON, check if it's plain readable text without stack traces
            if (!_isTechnicalString(trimmed) && trimmed.length < 250) {
              extracted = trimmed;
            }
          }
        }
      }
    }

    // Clean up extracted message if available
    if (extracted != null && extracted.trim().isNotEmpty && !_isGenericPlaceholder(extracted)) {
      return _cleanMessage(extracted.trim());
    }

    // If no specific message was found or it was generic, map the HTTP status code
    if (statusCode != null && statusCode != 200 && statusCode != 201 && statusCode != 204) {
      return _messageForStatusCode(statusCode, context: context, fallback: defaultMessage);
    }

    if (defaultMessage != null && defaultMessage.trim().isNotEmpty) {
      return defaultMessage.trim();
    }

    return 'Ocurrió un inconveniente al procesar la solicitud. Por favor intenta nuevamente.';
  }

  /// Parses any thrown Dart exception or error into a clear, descriptive message in Spanish.
  /// Eliminates `e.toString()`, raw stack traces, and unhandled exception strings.
  static String parseException(
    dynamic error, {
    String? defaultMessage,
    String? context,
  }) {
    if (error == null) {
      return defaultMessage ?? 'Ocurrió un error inesperado. Por favor intenta nuevamente.';
    }

    // 1. Timeout & Latency errors
    if (error is TimeoutException) {
      return 'Conexión débil o lenta. Tiempo de espera agotado. Intenta de nuevo.';
    }

    // 2. Strict offline detection or SocketException
    if (OfflineSyncService.isStrictlyOfflineError(error) || error is SocketException) {
      return 'Sin conexión a internet. Verifica tu red Wi-Fi o datos móviles.';
    }

    // 3. Supabase Auth Exceptions
    if (error is AuthException) {
      return mapAuthException(error);
    }

    // 4. Format / Parsing exceptions (e.g. backend sent HTML or malformed JSON)
    if (error is FormatException) {
      return 'El servidor devolvió una respuesta con formato inesperado. Intenta de nuevo.';
    }

    final raw = error.toString();

    // 5. PostgREST / Supabase known RPC domain codes
    if (raw.contains('CD001') || raw.contains('no existe') || raw.contains('expirado')) {
      return 'El código de invitación no existe, ya fue utilizado o ha expirado.';
    }
    if (raw.contains('SU001') || raw.contains('Límite') || raw.contains('limite')) {
      return 'Límite máximo de 2 sub-usuarios alcanzado en la vivienda.';
    }
    if (raw.contains('SU003') || raw.contains('ya está vinculado') || raw.contains('ya es')) {
      return 'Ya te encuentras vinculado como residente o titular de esta vivienda.';
    }

    // 6. Network & Client exceptions
    final lower = raw.toLowerCase();
    if (lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('network is unreachable') ||
        lower.contains('clientexception')) {
      return 'No se pudo conectar con el servidor. Verifica tu conexión a internet.';
    }
    if (lower.contains('connection reset') || lower.contains('broken pipe')) {
      return 'La conexión con el servidor se interrumpió inesperadamente. Intenta nuevamente.';
    }
    if (lower.contains('handshake') || lower.contains('certificate')) {
      return 'Error de seguridad al conectar con el servidor. Verifica la hora y fecha de tu dispositivo.';
    }

    // 7. General cleanup of raw Dart prefixes
    String cleaned = raw;
    if (cleaned.startsWith('Exception: ')) {
      cleaned = cleaned.substring('Exception: '.length);
    } else if (cleaned.startsWith('HttpException: ')) {
      cleaned = cleaned.substring('HttpException: '.length);
    }

    if (!_isTechnicalString(cleaned) && cleaned.length < 200 && cleaned.trim().isNotEmpty) {
      return _cleanMessage(cleaned.trim());
    }

    if (defaultMessage != null && defaultMessage.trim().isNotEmpty) {
      return defaultMessage.trim();
    }

    return 'No fue posible completar la operación debido a un error de comunicación.';
  }

  /// Maps Supabase [AuthException] to user-friendly Spanish explanations.
  static String mapAuthException(AuthException error) {
    final msg = error.message.toLowerCase();

    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid_credentials') ||
        msg.contains('invalid grant') ||
        msg.contains('correo o contraseña')) {
      return 'Correo o contraseña incorrectos. Verifica tus credenciales.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already been registered') ||
        msg.contains('email address is already registered')) {
      return 'El correo electrónico ya se encuentra registrado.';
    }
    if (msg.contains('password should be at least')) {
      return 'La contraseña debe tener al menos 6 caracteres.';
    }
    if (msg.contains('email not confirmed') || msg.contains('not confirmed')) {
      return 'Debes confirmar tu correo electrónico antes de ingresar.';
    }
    if (msg.contains('user not found')) {
      return 'No se encontró ningún usuario registrado con este correo.';
    }
    if (msg.contains('rate limit') || msg.contains('over email send')) {
      return 'Se han realizado demasiados intentos. Por favor espera unos minutos antes de reintentar.';
    }
    if (msg.contains('token has expired') || msg.contains('jwt expired')) {
      return 'Tu sesión o enlace ha expirado. Por favor inicia sesión nuevamente.';
    }
    if (msg.contains('signup disabled')) {
      return 'El registro de nuevos usuarios está deshabilitado temporalmente.';
    }
    if (msg.contains('network request failed')) {
      return 'Error de red al conectar con el servicio de autenticación.';
    }

    final cleaned = _cleanMessage(error.message);
    if (!_isTechnicalString(cleaned) && cleaned.isNotEmpty) {
      return cleaned;
    }
    return 'Error en la autenticación. Por favor verifica tus datos.';
  }

  /// Helper to extract error message from standard JSON formats (ASP.NET ProblemDetails, REST, etc.)
  static String? _extractFromMap(Map<String, dynamic> map) {
    // 1. Validation errors array: ASP.NET Core {"errors": {"Field": ["Msg 1", "Msg 2"]}}
    if (map.containsKey('errors')) {
      final errorsObj = map['errors'];
      if (errorsObj is Map) {
        final messages = <String>[];
        for (final entry in errorsObj.entries) {
          final val = entry.value;
          if (val is List) {
            for (final item in val) {
              if (item != null && item.toString().trim().isNotEmpty) {
                messages.add(item.toString().trim());
              }
            }
          } else if (val != null && val.toString().trim().isNotEmpty) {
            messages.add(val.toString().trim());
          }
        }
        if (messages.isNotEmpty) {
          return messages.join(' ');
        }
      } else if (errorsObj is List && errorsObj.isNotEmpty) {
        return _extractFromList(errorsObj);
      }
    }

    // 2. Direct error fields: error, message, detail, title, msg, motivo, razon
    const candidateKeys = ['error', 'message', 'detail', 'msg', 'motivo', 'razon', 'title', 'error_description'];
    for (final key in candidateKeys) {
      if (map.containsKey(key)) {
        final val = map[key];
        if (val is String && val.trim().isNotEmpty && !_isGenericPlaceholder(val)) {
          return val.trim();
        } else if (val is Map) {
          final nested = _extractFromMap(val.cast<String, dynamic>());
          if (nested != null && nested.isNotEmpty) return nested;
        } else if (val is List && val.isNotEmpty) {
          final nestedList = _extractFromList(val);
          if (nestedList != null && nestedList.isNotEmpty) return nestedList;
        }
      }
    }

    return null;
  }

  static String? _extractFromList(List<dynamic> list) {
    final messages = <String>[];
    for (final item in list) {
      if (item is String && item.trim().isNotEmpty && !_isGenericPlaceholder(item)) {
        messages.add(item.trim());
      } else if (item is Map) {
        final nested = _extractFromMap(item.cast<String, dynamic>());
        if (nested != null && nested.isNotEmpty) messages.add(nested);
      }
    }
    return messages.isNotEmpty ? messages.join(' ') : null;
  }

  static String _messageForStatusCode(int statusCode, {String? context, String? fallback}) {
    switch (statusCode) {
      case 400:
        return 'Los datos proporcionados no son válidos. Por favor revísalos e intenta de nuevo.';
      case 401:
        return 'Tu sesión ha expirado o no tienes autorización. Por favor inicia sesión nuevamente.';
      case 403:
        return 'No tienes los permisos necesarios para realizar esta acción.';
      case 404:
        return 'El recurso solicitado no fue encontrado o ya no está disponible.';
      case 408:
        return 'El servidor tardó demasiado tiempo en responder. Intenta nuevamente.';
      case 409:
        return 'Conflicto con el registro actual o ya existe un registro duplicado.';
      case 422:
        return 'No se pudo procesar la solicitud debido a datos de entrada incorrectos.';
      case 429:
        return 'Has realizado demasiadas solicitudes en poco tiempo. Espera un momento antes de reintentar.';
      case 500:
        return 'El servidor encontró un error interno. Intenta nuevamente más tarde.';
      case 502:
        return 'El servidor está temporalmente fuera de servicio o iniciando. Intenta en un momento.';
      case 503:
        return 'El servicio no se encuentra disponible en este momento. Intenta más tarde.';
      case 504:
        return 'Tiempo de espera de la pasarela agotado. El servidor tardó en responder.';
      default:
        if (fallback != null && fallback.trim().isNotEmpty) {
          return fallback.trim();
        }
        if (statusCode >= 400 && statusCode < 500) {
          return 'No se pudo completar la solicitud (error $statusCode).';
        }
        return 'Error en el servidor ($statusCode). Por favor intenta más tarde.';
    }
  }

  static bool _isHtml(String str) {
    final lower = str.toLowerCase();
    return lower.startsWith('<!doctype html') ||
        lower.startsWith('<html') ||
        lower.contains('<head>') ||
        lower.contains('<body>');
  }

  static bool _isTechnicalString(String str) {
    final lower = str.toLowerCase();
    return lower.contains('stack trace:') ||
        lower.contains('at system.') ||
        lower.contains('microsoft.aspnetcore') ||
        lower.contains('syntaxerror:') ||
        lower.contains('nullreferenceexception') ||
        lower.contains('internal server error') ||
        lower.contains('traceback (most recent call last)');
  }

  static bool _isGenericPlaceholder(String str) {
    final lower = str.trim().toLowerCase();
    return lower == 'error' ||
        lower == 'failed' ||
        lower == 'an error occurred' ||
        lower == 'bad request' ||
        lower == 'internal server error' ||
        lower == 'ocurrió un error' ||
        lower == 'ocurrió un error inesperado' ||
        lower == 'error inesperado';
  }

  static String _cleanMessage(String str) {
    var res = str;
    if (res.startsWith('Exception: ')) {
      res = res.substring('Exception: '.length);
    }
    // Remove enclosing quotes if any
    if (res.startsWith('"') && res.endsWith('"') && res.length > 2) {
      res = res.substring(1, res.length - 1);
    }
    return res.trim();
  }
}
