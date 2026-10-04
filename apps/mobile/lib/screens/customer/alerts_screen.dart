import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../format.dart';
import '../../models/alert.dart';
import '../shop/shop_profile_screen.dart';

/// New offers from shops the customer follows.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, required this.onRead});

  /// Called once the shown alerts are marked read.
  final VoidCallback onRead;

  @override
  State<AlertsScreen> createState() => AlertsScreenState();
}

class AlertsScreenState extends State<AlertsScreen> {
  late Future<List<Alert>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<List<Alert>> _load() async {
    final app = AppScope.read(context);
    return app.repository.fetchAlerts(app.user!);
  }

  /// Reloads, then marks everything shown as read. The list keeps showing
  /// which ones were new until the next reload.
  Future<void> reload() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    final alerts = await next;
    if (alerts.any((a) => !a.isRead) && mounted) {
      final app = AppScope.read(context);
      await app.repository.markAlertsRead(app.user!);
      widget.onRead();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Alerts')),
      body: RefreshIndicator(
        onRefresh: reload,
        child: FutureBuilder<List<Alert>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final alerts = snap.data ?? const <Alert>[];
            if (alerts.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(48),
                    child: Text(
                      'Follow shops you like and their new offers will show '
                      'up here.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: alerts.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final a = alerts[i];
                return ListTile(
                  leading: Icon(
                    a.isRead
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                    color: a.isRead
                        ? null
                        : Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    a.title,
                    style: a.isRead
                        ? null
                        : const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('${a.body}\n${formatDate(a.at)}'),
                  isThreeLine: true,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ShopProfileScreen(shopId: a.shopId),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
