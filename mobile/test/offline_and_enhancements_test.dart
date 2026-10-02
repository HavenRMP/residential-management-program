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

  }
