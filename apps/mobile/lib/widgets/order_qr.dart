import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../format.dart';
import '../models/order.dart';

/// The QR code and short code a customer shows at the shop.
class OrderQrCard extends StatelessWidget {
  const OrderQrCard({super.key, required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final open = order.status == OrderStatus.reserved;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(
          opacity: open ? 1 : 0.25,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              // QR codes scan best dark on light, whatever the theme.
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            // Fixed size so dialogs can measure it without laying it out.
            child: SizedBox.square(
              dimension: 200,
              child: QrImageView(
                data: order.qrPayload,
                padding: EdgeInsets.zero,
                semanticsLabel: 'QR code for order ${order.code}',
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SelectableText(
          order.code,
          style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 4),
        ),
        const SizedBox(height: 4),
        Text(switch (order.status) {
          OrderStatus.reserved =>
            'Show this at ${order.firmName} and pay '
                '${formatMoney(order.total, order.currency)} there.',
          OrderStatus.fulfilled =>
            order.redeemedAt == null
                ? 'Redeemed'
                : 'Redeemed ${formatDate(order.redeemedAt!)}',
          OrderStatus.cancelled => 'Cancelled',
        }, textAlign: TextAlign.center),
      ],
    );
  }
}

/// Opens [order]'s QR code full screen, for showing at the counter.
Future<void> showOrderQr(BuildContext context, Order order) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(order.offerTitle)),
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: OrderQrCard(order: order),
            ),
          ),
        ),
      ),
    );
