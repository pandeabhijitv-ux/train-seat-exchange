import 'package:firebase_core/firebase_core.dart';

import '../config/firebase_config.dart';

class FirebaseBootstrapService {
  static Future<void> ensureInitialized() async {
    if (Firebase.apps.isNotEmpty) {
      return;
    }

    if (!FirebaseConfig.isConfigured) {
      throw StateError(
        'Firebase Phone Auth is not configured. '
        'Build with FIREBASE_API_KEY, FIREBASE_APP_ID, '
        'FIREBASE_MESSAGING_SENDER_ID, FIREBASE_PROJECT_ID, '
        'and optionally FIREBASE_STORAGE_BUCKET.',
      );
    }

    await Firebase.initializeApp(options: FirebaseConfig.options);
  }
}