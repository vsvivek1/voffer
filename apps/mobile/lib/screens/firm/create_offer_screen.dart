import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../format.dart';
import '../../models/offer.dart';

class CreateOfferScreen extends StatefulWidget {
  const CreateOfferScreen({super.key});

  @override
  State<CreateOfferScreen> createState() => _CreateOfferScreenState();
}

class _CreateOfferScreenState extends State<CreateOfferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _originalPrice = TextEditingController();
  final _quantity = TextEditingController();
  final _imageUrl = TextEditingController();
  String _category = offerCategories.first;
  DateTime _expiresAt = DateTime.now().add(const Duration(days: 7));
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _price,
      _originalPrice,
      _quantity,
      _imageUrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _expiresAt,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_expiresAt),
    );
    if (!mounted) return;
    setState(
      () => _expiresAt = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 23,
        time?.minute ?? 59,
      ),
    );
  }

  Future<void> _publish() async {
    if (!_formKey.currentState!.validate()) return;
    final app = AppScope.read(context);
    setState(() => _busy = true);
    try {
      await app.repository.publishOffer(
        app.user!,
        NewOffer(
          title: _title.text.trim(),
          description: _description.text.trim(),
          price: double.parse(_price.text),
          originalPrice: double.tryParse(_originalPrice.text),
          category: _category,
          imageUrl: _imageUrl.text.trim().isEmpty
              ? null
              : _imageUrl.text.trim(),
          quantityAvailable: int.tryParse(_quantity.text),
          expiresAt: _expiresAt,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
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
    return Scaffold(
      appBar: AppBar(title: const Text('New offer')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              validator: _required,
            ),
            TextFormField(
              controller: _description,
              decoration: const InputDecoration(labelText: 'Description'),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 4,
              minLines: 2,
            ),
            gap,
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _price,
                    decoration: const InputDecoration(labelText: 'Offer price'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      final p = double.tryParse(v ?? '');
                      return (p == null || p < 0) ? 'Enter a price' : null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _originalPrice,
                    decoration: const InputDecoration(
                      labelText: 'Usual price (optional)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final o = double.tryParse(v);
                      final p = double.tryParse(_price.text);
                      if (o == null) return 'Not a number';
                      if (p != null && o < p) return 'Below offer price';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            gap,
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
              controller: _quantity,
              decoration: const InputDecoration(
                labelText: 'Quantity available',
                helperText: 'Leave empty for unlimited',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return null;
                final q = int.tryParse(v);
                return (q == null || q < 1) ? 'Enter a whole number' : null;
              },
            ),
            gap,
            TextFormField(
              controller: _imageUrl,
              decoration: const InputDecoration(
                labelText: 'Image URL (optional)',
              ),
              keyboardType: TextInputType.url,
            ),
            gap,
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('Expires'),
              subtitle: Text(formatDate(_expiresAt)),
              trailing: const Icon(Icons.edit),
              onTap: _pickExpiry,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _publish,
              icon: const Icon(Icons.campaign),
              label: const Text('Publish offer'),
            ),
          ],
        ),
      ),
    );
  }
}
