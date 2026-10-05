import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase settings for the `voffer-185f0` project, from its
/// google-services.json. These identify the app to Firebase and are safe to
/// ship; they grant no server access.
class VofferFirebaseOptions {
  /// Null on platforms Firebase is not set up for yet (iOS, web).
  static FirebaseOptions? get currentPlatform =>
      switch (defaultTargetPlatform) {
        TargetPlatform.android when !kIsWeb => android,
        _ => null,
      };

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyD5BMAuvamaBsT0sJNUJlS9BgU9w-Luqws',
    appId: '1:251131754606:android:60fb47dcd749de43f1ce7f',
    messagingSenderId: '251131754606',
    projectId: 'voffer-185f0',
    storageBucket: 'voffer-185f0.firebasestorage.app',
  );
}
