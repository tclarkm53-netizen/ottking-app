import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'data/repositories/live_tv_repository.dart';
import 'data/services/device_mode_service.dart';
import 'data/services/encryption_service.dart';
import 'data/services/secure_api_client.dart';
import 'data/services/secure_storage_service.dart';
import 'presentation/providers/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final secureStorage = SecureStorageService();
  final encryptionService = EncryptionService();
  final apiClient = SecureApiClient(
    encryptionService: encryptionService,
    secureStorage: secureStorage,
  );

  final repository = LiveTvRepository(apiClient: apiClient);
  final appState = AppState(
    repository: repository,
    prefs: prefs,
    secureStorage: secureStorage,
    deviceModeService: const DeviceModeService(),
  );

  await appState.bootstrap();

  runApp(
    ChangeNotifierProvider.value(
      value: appState,
      child: const OttKingApp(),
    ),
  );
}
