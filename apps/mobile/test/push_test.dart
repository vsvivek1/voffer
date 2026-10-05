import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:voffer/app_state.dart';
import 'package:voffer/data/mock_repository.dart';
import 'package:voffer/push/push_service.dart';

class FakePushService extends PushService {
  final refresh = StreamController<String>.broadcast();
  final arrivals = StreamController<void>.broadcast();
  String? token = 'token-1';

  @override
  Future<String?> register() async => token;

  @override
  Stream<String> get tokenRefresh => refresh.stream;

  @override
  Stream<void> get received => arrivals.stream;
}

void main() {
  late MockVofferRepository repo;
  late FakePushService push;
  late AppState state;

  setUp(() async {
    repo = MockVofferRepository();
    push = FakePushService();
    state = AppState(repo, push: push);
    await state.restore();
  });

  Future<void> signIn(String name) async {
    state.setUser(
      await repo.signIn(email: '$name@demo.voffer', password: 'demo1234'),
    );
    await pumpEventQueue();
  }

  test('signing in registers the phone for push', () async {
    await signIn('customer');
    expect(repo.deviceTokens, {'token-1': state.user!.id});
  });

  test('signing out stops pushes to the phone', () async {
    await signIn('customer');
    await state.signOut();
    expect(repo.deviceTokens, isEmpty);
  });

  test('a refreshed token replaces the old one', () async {
    await signIn('customer');
    push.refresh.add('token-2');
    await pumpEventQueue();
    expect(repo.deviceTokens['token-2'], state.user!.id);
  });

  test('no token is saved when the user declines notifications', () async {
    push.token = null;
    await signIn('customer');
    expect(repo.deviceTokens, isEmpty);
  });

  test('an arriving push tells screens to reload alerts', () async {
    await signIn('customer');
    final before = state.alertsChanged;
    push.arrivals.add(null);
    await pumpEventQueue();
    expect(state.alertsChanged, before + 1);
  });
}
