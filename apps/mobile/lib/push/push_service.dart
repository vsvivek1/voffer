import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// Phone notifications. The server pushes a notification for each new alert
/// to every device token a user has registered. Swapped for a fake in tests.
abstract class PushService {
  const PushService();

  /// Asks permission to notify and returns this device's token, or null when
  /// push is unavailable or the user said no.
  Future<String?> register();

  /// New tokens when Firebase rotates this device's token.
  Stream<String> get tokenRefresh;

  /// Fires when a notification arrives while the app is open, or the user
  /// opens the app from one.
  Stream<void> get received;
}

class NoPushService extends PushService {
  const NoPushService();

  @override
  Future<String?> register() async => null;

  @override
  Stream<String> get tokenRefresh => const Stream.empty();

  @override
  Stream<void> get received => const Stream.empty();
}

/// Firebase Cloud Messaging. Android only until iOS is added to the Firebase
/// project.
class FirebasePushService extends PushService {
  FirebasePushService._();

  /// Sets up Firebase, or returns [NoPushService] on platforms without it.
  static Future<PushService> create() async {
    final options = VofferFirebaseOptions.currentPlatform;
    if (options == null) return const NoPushService();
    try {
      await Firebase.initializeApp(options: options);
      return FirebasePushService._();
    } catch (e) {
      debugPrint('Push disabled: $e');
      return const NoPushService();
    }
  }

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  Future<String?> register() async {
    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('Push registration failed: $e');
      return null;
    }
  }

  @override
  Stream<String> get tokenRefresh => _messaging.onTokenRefresh;

  @override
  Stream<void> get received {
    final controller = StreamController<void>();
    final subscriptions = [
      FirebaseMessaging.onMessage.listen((_) => controller.add(null)),
      FirebaseMessaging.onMessageOpenedApp.listen((_) => controller.add(null)),
    ];
    controller.onCancel = () async {
      for (final s in subscriptions) {
        await s.cancel();
      }
    };
    return controller.stream;
  }
}
