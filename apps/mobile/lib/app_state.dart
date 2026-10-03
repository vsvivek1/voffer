import 'package:flutter/widgets.dart';

import 'data/voffer_repository.dart';
import 'location/location_service.dart';
import 'models/app_user.dart';

/// Holds the backend, location provider and the signed-in user for the widget tree.
class AppState extends ChangeNotifier {
  AppState(this.repository, {this.location = const NoLocationService()});

  final VofferRepository repository;
  final LocationService location;
  AppUser? _user;
  bool _restoring = true;

  AppUser? get user => _user;
  bool get restoring => _restoring;

  Future<void> restore() async {
    try {
      _user = await repository.currentUser();
    } catch (_) {
      _user = null;
    }
    _restoring = false;
    notifyListeners();
  }

  void setUser(AppUser? user) {
    _user = user;
    notifyListeners();
  }

  Future<void> signOut() async {
    await repository.signOut();
    setUser(null);
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
