import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../format.dart';
import '../../models/order.dart';

/// Shops scan a customer's QR code, or type the code, to redeem an order.
/// Pops with true when at least one order was redeemed.
class RedeemScreen extends StatefulWidget {
  const RedeemScreen({super.key});

  @override
  State<RedeemScreen> createState() => _RedeemScreenState();
}

class _RedeemScreenState extends State<RedeemScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  bool _redeemedAny = false;
  String? _lastScanned;
  Order? _redeemed;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _onScanned(String text) {
    // The camera reports the same code many times a second.
    if (_busy || text == _lastScanned) return;
    _lastScanned = text;
    _redeem(text);
  }

  Future<void> _redeem(String text) async {
    final code = parseOrderCode(text);
    if (code == null) {
      setState(() {
        _redeemed = null;
        _error = 'That is not a Voffer order code.';
      });
      return;
    }
    final app = AppScope.read(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final order = await app.repository.redeemOrder(app.user!, code);
      if (!mounted) return;
      _code.clear();
      setState(() {
        _redeemed = order;
        _redeemedAny = true;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _redeemed = null;
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scanner = AppScope.read(context).scanner;
    return PopScope<bool>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_redeemedAny);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Redeem an order')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (scanner.available) ...[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: scanner.buildView(_onScanned),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Point the camera at the customer's QR code.",
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
            if (_busy) const LinearProgressIndicator(),
            if (_redeemed != null) _Result.success(_redeemed!),
            if (_error != null) _Result.failure(_error!),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              decoration: InputDecoration(
                labelText: scanner.available
                    ? 'Or type the order code'
                    : 'Order code',
              ),
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: _busy ? null : _redeem,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : () => _redeem(_code.text),
              icon: const Icon(Icons.check),
              label: const Text('Redeem'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result.success(Order this.order) : error = null;
  const _Result.failure(String this.error) : order = null;

  final Order? order;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final o = order;
    return Card(
      color: o != null ? scheme.primaryContainer : scheme.errorContainer,
      child: ListTile(
        leading: Icon(
          o != null ? Icons.check_circle : Icons.error_outline,
          color: o != null
              ? scheme.onPrimaryContainer
              : scheme.onErrorContainer,
          size: 36,
        ),
        title: Text(o != null ? 'Redeemed ${o.code}' : error!),
        subtitle: o == null
            ? null
            : Text(
                '${o.offerTitle}\n'
                '${o.customerName} · ${o.quantity} × '
                '${formatMoney(o.unitPrice)}\n'
                'Collect ${formatMoney(o.total)}',
              ),
        isThreeLine: o != null,
      ),
    );
  }
}
