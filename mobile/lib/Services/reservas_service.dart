import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app_controller.dart';
import '../Models/area_comun_model.dart';
import '../Models/reserva_model.dart';
import '../Models/bloqueo_model.dart';
import '../Utils/error_handler.dart';

class ReservasService {
  final AppController controller;

  ReservasService(this.controller);

  String get baseUrl {
    final envUrl = dotenv.env['API_BASE_URL_RESERVAS'];
    if (envUrl != null &&
        envUrl.trim().isNotEmpty &&
        !envUrl.contains('haven.app')) {
      return envUrl.trim();
    }
    return 'https://reservas-api.onrender.com';
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await controller.getValidAccessToken();
    return {
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };
  }
}
