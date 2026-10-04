import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../format.dart';
import '../../models/offer.dart';
import '../../widgets/order_qr.dart';
import '../../widgets/voffer_image.dart';
import '../shop/shop_profile_screen.dart';

class OfferDetailScreen extends StatefulWidget {
  const OfferDetailScreen({
    super.key,
    required this.offer,
    this.showShopLink = true,
  });

  final Offer offer;

  /// False when opened from the shop's own profile.
  final bool showShopLink;

  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen> {
  int _quantity = 1;
  bool _busy = false;

  int get _maxQuantity => (widget.offer.quantityAvailable ?? 10).clamp(1, 10);

  Future<void> _buy() async {
    final app = AppScope.read(context);
    setState(() => _busy = true);
    try {
      final order = await app.repository.placeOrder(
        app.user!,
        widget.offer,
        _quantity,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle_outline, size: 48),
          title: const Text('Reserved!'),
          content: OrderQrCard(order: order),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = widget.offer;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(offer.firmName)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (offer.imageUrl != null && offer.imageUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: VofferImage(offer.imageUrl!),
                ),
              ),
            ),
          Text(offer.title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text(offer.category)),
              Chip(label: Text(formatTimeLeft(offer.expiresAt))),
              if (offer.quantityAvailable != null)
                Chip(label: Text('${offer.quantityAvailable} left')),
            ],
          ),
          if (widget.showShopLink)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.storefront),
              title: Text(offer.firmName),
              subtitle: Text(
                [
                  ?offer.shopAddress,
                  if (offer.distanceKm != null)
                    '${formatDistance(offer.distanceKm!)} away',
                ].join(' · ').ifEmpty('See shop details'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ShopProfileScreen(
                    shopId: offer.firmId,
                    title: offer.firmName,
                  ),
                ),
              ),
            )
          else
            const SizedBox(height: 16),
          Text(offer.description, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                formatMoney(offer.price, offer.currency),
                style: theme.textTheme.headlineMedium,
              ),
              if (offer.originalPrice != null) ...[
                const SizedBox(width: 12),
                Text(
                  formatMoney(offer.originalPrice!, offer.currency),
                  style: theme.textTheme.titleMedium?.copyWith(
                    decoration: TextDecoration.lineThrough,
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ],
          ),
          Text(
            'Expires ${formatDate(offer.expiresAt)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              IconButton.outlined(
                tooltip: 'Fewer',
                onPressed: _quantity > 1
                    ? () => setState(() => _quantity--)
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('$_quantity', style: theme.textTheme.titleLarge),
              ),
              IconButton.outlined(
                tooltip: 'More',
                onPressed: _quantity < _maxQuantity
                    ? () => setState(() => _quantity++)
                    : null,
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: FilledButton(
                  onPressed: offer.isBuyable && !_busy ? _buy : null,
                  child: Text(
                    offer.isBuyable
                        ? 'Buy for ${formatMoney(offer.price * _quantity, offer.currency)}'
                        : 'Unavailable',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
