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
  int? _followers;
  bool _following = false;
  bool _followBusy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<(Shop?, List<Offer>)> _load() async {
    final app = AppScope.read(context);
    final repo = app.repository;
    final user = app.user;
    final results = await Future.wait([
      repo.fetchShop(widget.shopId),
      repo.fetchShopOffers(widget.shopId),
      repo.followerCount(widget.shopId),
      if (user != null && !user.isFirm) repo.isFollowing(user, widget.shopId),
    ]);
    if (mounted) {
      setState(() {
        _followers = results[2] as int;
        _following = results.length > 3 && results[3] as bool;
      });
    }
    return (results[0] as Shop?, results[1] as List<Offer>);
  }

  Future<void> _toggleFollow() async {
    final app = AppScope.read(context);
    final follow = !_following;
    setState(() => _followBusy = true);
    try {
      await app.repository.setFollowing(app.user!, widget.shopId, follow);
      if (!mounted) return;
      setState(() {
        _following = follow;
        _followers = (_followers ?? 0) + (follow ? 1 : -1);
      });
      if (follow) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You'll get an alert when they post an offer."),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
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
    final user = AppScope.read(context).user;
    final followers = _followers;
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
                  subtitle: Text(
                    followers == null
                        ? shop.category
                        : '${shop.category} · $followers '
                              '${followers == 1 ? 'follower' : 'followers'}',
                  ),
                  trailing: user == null || user.isFirm
                      ? null
                      : _following
                      ? OutlinedButton.icon(
                          onPressed: _followBusy ? null : _toggleFollow,
                          icon: const Icon(Icons.check),
                          label: const Text('Following'),
                        )
                      : FilledButton.icon(
                          onPressed: _followBusy ? null : _toggleFollow,
                          icon: const Icon(Icons.add),
                          label: const Text('Follow'),
                        ),
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
