import 'package:flutter/material.dart';

import '../format.dart';
import '../models/offer.dart';

class OfferCard extends StatelessWidget {
  const OfferCard({super.key, required this.offer, this.onTap, this.trailing});

  final Offer offer;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final discount = offer.discountPercent;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (offer.imageUrl != null && offer.imageUrl!.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  offer.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          offer.distanceKm == null
                              ? offer.firmName
                              : '${offer.firmName} · '
                                    '${formatDistance(offer.distanceKm!)}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      if (discount != null)
                        Chip(
                          label: Text('$discount% off'),
                          visualDensity: VisualDensity.compact,
                          backgroundColor: theme.colorScheme.tertiaryContainer,
                        ),
                      ?trailing,
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(offer.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        formatMoney(offer.price),
                        style: theme.textTheme.titleLarge,
                      ),
                      if (offer.originalPrice != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          formatMoney(offer.originalPrice!),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Text(_statusText(), style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _statusText() {
    if (!offer.isActive) return 'Paused';
    if (offer.isScheduled) return 'Starts ${formatDate(offer.startsAt)}';
    if (offer.isSoldOut) return 'Sold out';
    final left = formatTimeLeft(offer.expiresAt);
    final stock = offer.quantityAvailable;
    return stock == null ? left : '$stock left · $left';
  }
}
