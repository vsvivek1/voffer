import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../format.dart';
import '../../models/offer.dart';
import '../../models/order.dart';
import '../../widgets/offer_card.dart';
import 'create_offer_screen.dart';

class FirmHome extends StatefulWidget {
  const FirmHome({super.key});

  @override
  State<FirmHome> createState() => _FirmHomeState();
}

class _FirmHomeState extends State<FirmHome> {
  int _tab = 0;
  late Future<List<Offer>> _offers;
  late Future<List<Order>> _orders;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  void _load() {
    final app = AppScope.read(context);
    _offers = app.repository.fetchFirmOffers(app.user!.id);
    _orders = app.repository.fetchFirmOrders(app.user!.id);
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([_offers, _orders]);
  }

  Future<void> _newOffer() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CreateOfferScreen()));
    if (created == true) {
      setState(() => _tab = 0);
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(app.user?.displayName ?? ''),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: app.signOut,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _tab == 0 ? _buildOffers() : _buildOrders(),
      ),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: _newOffer,
              icon: const Icon(Icons.add),
              label: const Text('New offer'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          setState(() => _tab = i);
          _refresh();
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.campaign_outlined),
            selectedIcon: Icon(Icons.campaign),
            label: 'My offers',
          ),
          NavigationDestination(
            icon: Icon(Icons.inbox_outlined),
            selectedIcon: Icon(Icons.inbox),
            label: 'Orders',
          ),
        ],
      ),
    );
  }

  Widget _buildOffers() => FutureBuilder<List<Offer>>(
    future: _offers,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final offers = snap.data ?? const <Offer>[];
      if (offers.isEmpty) {
        return const _Empty(
          'No offers yet. Tap "New offer" to publish your first one.',
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: offers.length,
        itemBuilder: (context, i) {
          final offer = offers[i];
          return OfferCard(
            offer: offer,
            trailing: Switch(
              value: offer.isActive,
              onChanged: (v) async {
                await AppScope.read(context).repository
                    .setOfferActive(offer.id, v);
                _refresh();
              },
            ),
          );
        },
      );
    },
  );

  Widget _buildOrders() => FutureBuilder<List<Order>>(
    future: _orders,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      final orders = snap.data ?? const <Order>[];
      if (orders.isEmpty) {
        return const _Empty('Orders from customers will appear here.');
      }
      return ListView.separated(
        itemCount: orders.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final o = orders[i];
          return ListTile(
            title: Text('${o.code} · ${o.offerTitle}'),
            subtitle: Text(
              '${o.customerName} · ${o.quantity} × '
              '${formatMoney(o.unitPrice)} = ${formatMoney(o.total)}\n'
              '${formatDate(o.createdAt)}',
            ),
            isThreeLine: true,
            trailing: o.status == OrderStatus.reserved
                ? FilledButton.tonal(
                    onPressed: () async {
                      await AppScope.read(context).repository
                          .updateOrderStatus(o.id, OrderStatus.fulfilled);
                      _refresh();
                    },
                    child: const Text('Redeem'),
                  )
                : Text(o.status.name),
          );
        },
      );
    },
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => ListView(
    children: [
      Padding(
        padding: const EdgeInsets.all(48),
        child: Text(text, textAlign: TextAlign.center),
      ),
    ],
  );
}
