import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../models/offer.dart';
import '../../models/shop.dart';
import '../../widgets/offer_card.dart';
import '../../widgets/shop_map.dart';
import '../../widgets/voffer_image.dart';
import '../customer/offer_detail_screen.dart';

/// A shop's details and its live offers, as customers see them.
class ShopProfileScreen extends StatefulWidget {
  const ShopProfileScreen({super.key, required this.shopId, this.title});

  final String shopId;

  /// Shown in the app bar while the shop loads.
  final String? title;

  @override
  State<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends State<ShopProfileScreen> {
  late Future<(Shop?, List<Offer>)> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<(Shop?, List<Offer>)> _load() async {
    final repo = AppScope.read(context).repository;
    final results = await Future.wait([
      repo.fetchShop(widget.shopId),
      repo.fetchShopOffers(widget.shopId),
    ]);
    return (results[0] as Shop?, results[1] as List<Offer>);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(Shop?, List<Offer>)>(
      future: _future,
      builder: (context, snap) {
        final shop = snap.data?.$1;
        return Scaffold(
          appBar: AppBar(title: Text(shop?.name ?? widget.title ?? 'Shop')),
          body: switch (snap) {
            AsyncSnapshot(connectionState: != ConnectionState.done) =>
              const Center(child: CircularProgressIndicator()),
            AsyncSnapshot(:final error?) => _Message(
              'Could not load this shop.\n$error',
            ),
            _ when shop == null => const _Message(
              'This shop has not finished setting up yet.',
            ),
            _ => RefreshIndicator(
              onRefresh: _refresh,
              child: _buildBody(shop, snap.data!.$2),
            ),
          },
        );
      },
    );
  }

  Widget _buildBody(Shop shop, List<Offer> offers) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                ListTile(
                  leading: shop.logoUrl == null
                      ? const Icon(Icons.storefront)
                      : ClipOval(
                          child: SizedBox.square(
                            dimension: 48,
                            child: VofferImage(shop.logoUrl!),
                          ),
                        ),
                  title: Text(shop.name, style: theme.textTheme.titleLarge),
                  subtitle: Text(shop.category),
                ),
                ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(shop.address),
                  trailing: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ShopMapScreen(shop: shop),
                      ),
                    ),
                    child: const Text('Map'),
                  ),
                ),
                if (shop.hours != null)
                  ListTile(
                    leading: const Icon(Icons.schedule),
                    title: Text(shop.hours!),
                  ),
                if (shop.phone != null)
                  ListTile(
                    leading: const Icon(Icons.call_outlined),
                    title: SelectableText(shop.phone!),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(
            offers.isEmpty ? 'No live offers right now' : 'Live offers',
            style: theme.textTheme.titleMedium,
          ),
        ),
        for (final offer in offers)
          OfferCard(
            offer: offer,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      OfferDetailScreen(offer: offer, showShopLink: false),
                ),
              );
              _refresh();
            },
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(48),
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
}
