import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../format.dart';
import '../../models/order.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => MyOrdersScreenState();
}

class MyOrdersScreenState extends State<MyOrdersScreen> {
  late Future<List<Order>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<List<Order>> _load() {
    final app = AppScope.read(context);
    return app.repository.fetchCustomerOrders(app.user!.id);
  }

  Future<void> reload() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My orders')),
      body: RefreshIndicator(
        onRefresh: reload,
        child: FutureBuilder<List<Order>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final orders = snap.data ?? const <Order>[];
            if (orders.isEmpty) {
              return ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(48),
                    child: Text(
                      'Offers you buy will show up here.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: orders.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final o = orders[i];
                return ListTile(
                  title: Text(o.offerTitle),
                  subtitle: Text(
                    '${o.firmName} · ${o.quantity} × '
                    '${formatMoney(o.unitPrice)} · ${formatDate(o.createdAt)}',
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        o.code,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(o.status.name),
                    ],
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
