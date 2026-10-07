import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../format.dart';
import '../../models/offer.dart';
import '../../models/order.dart';
import '../../models/shop.dart';
import '../../widgets/account_menu.dart';
import '../../widgets/offer_card.dart';
import '../shop/shop_form_screen.dart';
import 'create_offer_screen.dart';
import 'redeem_screen.dart';

class FirmHome extends StatefulWidget {
  const FirmHome({super.key});

  @override
  State<FirmHome> createState() => _FirmHomeState();
}

class _FirmHomeState extends State<FirmHome> {
  int _tab = 0;
  Shop? _shop;
  bool _shopLoaded = false;
  Object? _shopError;
  late Future<List<Offer>> _offers;
  late Future<List<Order>> _orders;
  late Future<int> _followers;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_shopLoaded && _shopError == null) _loadShop();
    _load();
  }

  Future<void> _loadShop() async {
    final app = AppScope.read(context);
    try {
      final shop = await app.repository.fetchShop(app.user!.id);
      if (mounted) setState(() => _shop = shop);
    } catch (e) {
      if (mounted) setState(() => _shopError = e);
    } finally {
      if (mounted) setState(() => _shopLoaded = true);
    }
  }

  void _load() {
    final app = AppScope.read(context);
    _offers = app.repository.fetchFirmOffers(app.user!.id);
    _orders = app.repository.fetchFirmOrders(app.user!.id);
    _followers = app.repository.followerCount(app.user!.id);
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

  Future<void> _openRedeem() async {
    final redeemed = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => const RedeemScreen()));
    if (redeemed == true) _refresh();
  }

  Future<void> _redeem(Order order) async {
    final app = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final redeemed = await app.repository.redeemOrder(app.user!, order.code);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Redeemed ${redeemed.code}. Collect ${formatMoney(redeemed.total, redeemed.currency)}.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
    _refresh();
  }

  Future<void> _editShop(Shop shop) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ShopFormScreen(
          shop: shop,
          onSaved: (saved) {
            Navigator.of(context).pop();
            setState(() => _shop = saved);
          },
        ),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    AppScope.of(context);
    if (_shopError != null) {
      return Scaffold(
        appBar: AppBar(),
        body: _Empty('Could not load your shop.\n$_shopError'),
      );
    }
    if (!_shopLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final shop = _shop;
    if (shop == null) {
      return ShopFormScreen(onSaved: (saved) => setState(() => _shop = saved));
    }
    return _buildDashboard(shop);
  }

  Widget _buildDashboard(Shop shop) {
    return Scaffold(
      appBar: AppBar(
        title: Text(shop.name),
        actions: [
          IconButton(
            tooltip: 'Redeem an order',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _openRedeem,
          ),
          IconButton(
            tooltip: 'Edit shop',
            icon: const Icon(Icons.storefront),
            onPressed: () => _editShop(shop),
          ),
          const AccountMenu(),
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
          : FloatingActionButton.extended(
              onPressed: _openRedeem,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan to redeem'),
            ),
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
        itemCount: offers.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) return _FollowerNote(_followers);
          final offer = offers[i - 1];
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
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final o = orders[i];
          return ListTile(
            title: Text('${o.code} · ${o.offerTitle}'),
            subtitle: Text(
              '${o.customerName} · ${o.quantity} × '
              '${formatMoney(o.unitPrice, o.currency)} = ${formatMoney(o.total, o.currency)}\n'
              '${formatDate(o.createdAt)}',
            ),
            isThreeLine: true,
            trailing: o.status == OrderStatus.reserved
                ? FilledButton.tonal(
                    onPressed: () => _redeem(o),
                    child: const Text('Redeem'),
                  )
                : Text(o.status.name),
          );
        },
      );
    },
  );
}

/// Tells the firm how many customers hear about its new offers.
class _FollowerNote extends StatelessWidget {
  const _FollowerNote(this.followers);
  final Future<int> followers;

  @override
  Widget build(BuildContext context) => FutureBuilder<int>(
    future: followers,
    builder: (context, snap) {
      final n = snap.data;
      if (n == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text(
          n == 0
              ? 'No followers yet. Customers who follow your shop get an '
                    'alert when you publish.'
              : '$n ${n == 1 ? 'follower gets' : 'followers get'} an alert '
                    'when you publish.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
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
