class CodigoHelper {
  /// Extrae un código limpio y válido desde cualquier formato de respuesta del backend.
  /// Retorna `null` si la respuesta contiene un error, es nula o solo contiene un marcador de posición ('—', '-').
  static String? extractCodigo(dynamic res) {
    if (res == null) return null;

    if (res is String) {
      final trimmed = res.trim();
      if (trimmed.isNotEmpty && trimmed != '—' && trimmed != '-' && trimmed != 'null') {
        return trimmed;
      }
      return null;
    }

    if (res is Map) {
      // Si la respuesta indica un error, no hay código válido
      if (res['error'] != null && res['error'].toString().trim().isNotEmpty) {
        return null;
      }

      final candidates = [
        res['codigo'],
        res['Codigo'],
        res['code'],
        res['Code'],
        res['codigoAcceso'],
        res['codigo_acceso'],
        res['token'],
        res['tokenAcceso'],
        res['invitacionCodigo'],
        if (res['data'] is Map) ...[
          res['data']['codigo'],
          res['data']['Codigo'],
          res['data']['code'],
          res['data']['Code'],
        ],
        if (res['data'] is String) res['data'],
        if (res['result'] is Map) ...[
          res['result']['codigo'],
          res['result']['Codigo'],
        ],
        if (res['result'] is String) res['result'],
        if (res['item'] is Map) ...[
          res['item']['codigo'],
          res['item']['Codigo'],
        ],
      ];

      for (final candidate in candidates) {
        if (candidate != null) {
          final str = candidate.toString().trim();
          if (str.isNotEmpty && str != '—' && str != '-' && str != 'null') {
            return str;
          }
        }
      }
    }

    return null;
  }
}
