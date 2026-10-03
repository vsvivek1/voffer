import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../models/offer.dart';
import '../../models/shop.dart';
import '../../widgets/shop_map.dart';

/// Sets up a firm's shop on first sign-in, or edits it later.
class ShopFormScreen extends StatefulWidget {
  const ShopFormScreen({super.key, this.shop, required this.onSaved});

  /// The shop being edited, or null when setting one up.
  final Shop? shop;
  final ValueChanged<Shop> onSaved;

  @override
  State<ShopFormScreen> createState() => _ShopFormScreenState();
}

class _ShopFormScreenState extends State<ShopFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.shop?.name ?? AppScope.read(context).user?.displayName,
  );
  late final _address = TextEditingController(text: widget.shop?.address);
  late final _phone = TextEditingController(text: widget.shop?.phone);
  late final _hours = TextEditingController(text: widget.shop?.hours);
  late String _category = widget.shop?.category ?? offerCategories.first;
  late GeoPoint? _location = widget.shop?.location;
  String? _locationError;
  bool _locating = false;
  bool _busy = false;

  bool get _isNew => widget.shop == null;

  @override
  void dispose() {
    for (final c in [_name, _address, _phone, _hours]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final point = await AppScope.read(context).location.current();
      if (mounted) setState(() => _location = point);
    } catch (e) {
      if (mounted) setState(() => _locationError = e.toString());
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _pickOnMap() async {
    final picked = await Navigator.of(context).push<GeoPoint>(
      MaterialPageRoute(
        builder: (_) =>
            PickLocationScreen(initial: _location ?? cities['Kochi']!),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _location = picked;
        _locationError = null;
      });
    }
  }

  Future<void> _save() async {
    final formOk = _formKey.currentState!.validate();
    if (_location == null) {
      setState(() => _locationError = 'Set where your shop is.');
    }
    if (!formOk || _location == null) return;
    final app = AppScope.read(context);
    setState(() => _busy = true);
    try {
      final shop = await app.repository.saveShop(
        app.user!,
        ShopDetails(
          name: _name.text.trim(),
          category: _category,
          address: _address.text.trim(),
          location: _location!,
          phone: _phone.text.trim(),
          hours: _hours.text.trim(),
        ),
      );
      app.setUser(app.user!.copyWith(displayName: shop.name));
      widget.onSaved(shop);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 12);
    final theme = Theme.of(context);
    final location = _location;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Set up your shop' : 'Edit shop'),
        actions: [
          if (_isNew)
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
              onPressed: AppScope.read(context).signOut,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isNew) ...[
              Text(
                'Customers find offers by distance, so tell them where you '
                'are before you publish.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Shop name'),
              textCapitalization: TextCapitalization.words,
              maxLength: 120,
              validator: _required,
            ),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final c in offerCategories)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
            gap,
            TextFormField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Address',
                helperText: 'Street, area and city',
              ),
              textCapitalization: TextCapitalization.words,
              maxLines: 2,
              minLines: 1,
              maxLength: 300,
              validator: _required,
            ),
            TextFormField(
              controller: _phone,
              decoration: const InputDecoration(labelText: 'Phone (optional)'),
              keyboardType: TextInputType.phone,
              maxLength: 30,
            ),
            TextFormField(
              controller: _hours,
              decoration: const InputDecoration(
                labelText: 'Opening hours (optional)',
                hintText: 'Mon–Sat, 9am–9pm',
              ),
              maxLength: 120,
            ),
            gap,
            Text('Location on the map', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              location == null
                  ? 'Not set'
                  : 'Pinned at ${location.lat.toStringAsFixed(5)}, '
                        '${location.lng.toStringAsFixed(5)}',
              style: theme.textTheme.bodyMedium,
            ),
            if (_locationError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _locationError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _locating ? null : _useCurrentLocation,
                  icon: _locating
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location),
                  label: const Text("I'm at the shop"),
                ),
                OutlinedButton.icon(
                  onPressed: _pickOnMap,
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Pick on map'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: const Icon(Icons.storefront),
              label: Text(_isNew ? 'Save and continue' : 'Save shop'),
            ),
          ],
        ),
      ),
    );
  }
}
