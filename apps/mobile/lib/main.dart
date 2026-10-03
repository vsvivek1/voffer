import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'config.dart';
import 'data/mock_repository.dart';
import 'data/supabase_repository.dart';
import 'data/voffer_repository.dart';
import 'location/location_service.dart';
import 'screens/customer/customer_home.dart';
import 'screens/firm/firm_home.dart';
import 'screens/sign_in_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final VofferRepository repository;
  if (AppConfig.useSupabase) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabasePublishableKey,
    );
    repository = SupabaseVofferRepository(Supabase.instance.client);
  } else {
    repository = MockVofferRepository();
  }
  runApp(
    VofferApp(
      state: AppState(repository, location: const DeviceLocationService())
        ..restore(),
    ),
  );
}

class VofferApp extends StatelessWidget {
  const VofferApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFE4572E),
        brightness: b,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
    return AppScope(
      state: state,
      child: MaterialApp(
        title: 'Voffer',
        debugShowCheckedModeBanner: false,
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (app.restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = app.user;
    if (user == null) return const SignInScreen();
    // Keyed by user so switching accounts rebuilds the home state.
    return user.isFirm
        ? FirmHome(key: ValueKey(user.id))
        : CustomerHome(key: ValueKey(user.id));
  }
}
