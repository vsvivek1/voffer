import 'package:flutter/material.dart';

import '../../app_state.dart';
import 'alerts_screen.dart';
import 'feed_screen.dart';
import 'my_orders_screen.dart';

class CustomerHome extends StatefulWidget {
  const CustomerHome({super.key});

  @override
  State<CustomerHome> createState() => _CustomerHomeState();
}

class _CustomerHomeState extends State<CustomerHome> {
  int _tab = 0;
  int _unread = 0;
  final _ordersKey = GlobalKey<MyOrdersScreenState>();
  final _alertsKey = GlobalKey<AlertsScreenState>();
  int? _alertsChanged;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Count on first build and again whenever a push arrives.
    final changed = AppScope.of(context).alertsChanged;
    if (changed != _alertsChanged) {
      _alertsChanged = changed;
      _countUnread();
      if (_tab == 2) _alertsKey.currentState?.reload();
    }
  }

  Future<void> _countUnread() async {
    final app = AppScope.read(context);
    try {
      final alerts = await app.repository.fetchAlerts(app.user!);
      if (mounted) {
        setState(() => _unread = alerts.where((a) => !a.isRead).length);
      }
    } catch (_) {
      // The badge is a nicety; the Alerts tab shows any error.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          const FeedScreen(),
          MyOrdersScreen(key: _ordersKey),
          AlertsScreen(
            key: _alertsKey,
            onRead: () => setState(() => _unread = 0),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          if (i == 0) _countUnread();
          if (i == 1) _ordersKey.currentState?.reload();
          if (i == 2) _alertsKey.currentState?.reload();
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.local_offer_outlined),
            selectedIcon: Icon(Icons.local_offer),
            label: 'Offers',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'My orders',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _unread > 0,
              label: Text('$_unread'),
              child: const Icon(Icons.notifications_none),
            ),
            selectedIcon: const Icon(Icons.notifications),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}
