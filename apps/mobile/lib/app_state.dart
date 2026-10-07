import 'dart:async';

import 'package:flutter/widgets.dart';

import 'data/voffer_repository.dart';
import 'location/location_service.dart';
import 'models/app_user.dart';
import 'photos/photo_picker.dart';
import 'push/push_service.dart';
import 'scanning/qr_scanner.dart';

/// Holds the backend, device services and the signed-in user for the widget tree.
class AppState extends ChangeNotifier {
  AppState(
    this.repository, {
    this.location = const NoLocationService(),
    this.photos = const NoPhotoPicker(),
    this.scanner = const NoQrScanner(),
    this.push = const NoPushService(),
  }) {
    _subscriptions = [
      push.tokenRefresh.listen(_saveToken),
      push.received.listen((_) {
        _alertsChanged++;
        notifyListeners();
      }),
    ];
  }

  final VofferRepository repository;
  final LocationService location;
  final PhotoPicker photos;
  final QrScanner scanner;
  final PushService push;
  AppUser? _user;
  bool _restoring = true;
  String? _pushToken;
  int _alertsChanged = 0;
  late final List<StreamSubscription<Object?>> _subscriptions;

  AppUser? get user => _user;
  bool get restoring => _restoring;

  /// Goes up each time a push notification arrives, so screens showing
  /// alerts know to reload.
  int get alertsChanged => _alertsChanged;

  Future<void> restore() async {
    try {
      _user = await repository.currentUser();
    } catch (_) {
      _user = null;
    }
    _restoring = false;
    notifyListeners();
    if (_user != null) unawaited(_registerPush());
  }

  void setUser(AppUser? user) {
    final signedIn = user != null && user.id != _user?.id;
    _user = user;
    notifyListeners();
    if (signedIn) unawaited(_registerPush());
  }

  Future<void> signOut() async {
    final token = _pushToken;
    _pushToken = null;
    if (token != null) {
      // Otherwise this phone keeps getting the signed-out user's alerts.
      try {
        await repository.deleteDeviceToken(token);
      } catch (e) {
        debugPrint('Could not remove push token: $e');
      }
    }
    await repository.signOut();
    setUser(null);
  }

  /// Permanently deletes the signed-in account, then signs out. Throws a
  /// [RepositoryException] and stays signed in if the deletion fails.
  Future<void> deleteAccount() async {
    await repository.deleteAccount();
    // The server already removed this phone's push token with the account.
    _pushToken = null;
    try {
      await repository.signOut();
    } catch (e) {
      debugPrint('Sign out after account deletion failed: $e');
    }
    setUser(null);
  }

  Future<void> _registerPush() async {
    final token = await push.register();
    if (token != null) await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final user = _user;
    if (user == null) return;
    try {
      await repository.saveDeviceToken(user, token);
      _pushToken = token;
    } catch (e) {
      debugPrint('Could not save push token: $e');
    }
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
