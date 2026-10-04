import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../models/offer.dart';
import '../../models/shop.dart';
import '../../widgets/offer_card.dart';
import 'offer_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

/// Where the feed is centred: the device's position or a chosen city.
typedef _Place = ({String label, GeoPoint point});

const _radiusOptions = [2.0, 5.0, 10.0, 25.0];

class _FeedScreenState extends State<FeedScreen> {
  String? _category;
  String _query = '';
  _Place? _place;
  double _radiusKm = 10;
  bool _triedDevice = false;
  late Future<List<Offer>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<List<Offer>> _load() async {
    final app = AppScope.read(context);
    if (!_triedDevice) {
      _triedDevice = true;
      await _locateDevice(quiet: true);
    }
    final place = _place;
    if (place == null) {
      return app.repository.fetchFeed(category: _category, query: _query);
    }
    return app.repository.fetchNearby(
      near: place.point,
      radiusKm: _radiusKm,
      category: _category,
      query: _query,
    );
  }

  /// Centres the feed on the device. With [quiet], a refusal just leaves the
  /// feed showing offers from everywhere.
  Future<void> _locateDevice({bool quiet = false}) async {
    final location = AppScope.read(context).location;
    try {
      final point = await location.current();
      if (mounted) setState(() => _place = (label: 'Near you', point: point));
    } catch (e) {
      if (!quiet && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _chooseLocation() async {
    final choice = await showModalBottomSheet<_LocationChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _LocationSheet(radiusKm: _radiusKm),
    );
    if (choice == null || !mounted) return;
    setState(() {
      _radiusKm = choice.radiusKm;
      if (choice.city != null) {
        _place = (label: choice.city!, point: cities[choice.city]!);
      }
    });
    if (choice.useDevice) await _locateDevice();
    _refresh();
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() {
      _future = next;
    });
    await next;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_place == null ? 'Offers' : 'Nearby'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: app.signOut,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(112),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: SearchBar(
                  hintText: 'Search offers or firms',
                  leading: const Icon(Icons.search),
                  onSubmitted: (v) {
                    _query = v;
                    _refresh();
                  },
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ActionChip(
                        avatar: const Icon(Icons.place_outlined),
                        label: Text(
                          _place == null
                              ? 'Choose location'
                              : '${_place!.label} · ${_radiusKm.round()} km',
                        ),
                        onPressed: _chooseLocation,
                      ),
                    ),
                    for (final c in [null, ...offerCategories])
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(c ?? 'All'),
                          selected: _category == c,
                          onSelected: (_) {
                            _category = c;
                            _refresh();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Offer>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _Message('Could not load offers.\n${snap.error}');
            }
            final offers = snap.data!;
            final banner = _place == null
                ? _Banner(
                    text:
                        'Showing offers from everywhere. Share your location '
                        "or pick a city to see what's near you.",
                    action: 'Choose location',
                    onPressed: _chooseLocation,
                  )
                : null;
            if (offers.isEmpty) {
              final wider = _radiusOptions.where((r) => r > _radiusKm);
              return ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  ?banner,
                  if (_place != null && wider.isNotEmpty)
                    _Banner(
                      text:
                          'No offers within ${_radiusKm.round()} km right '
                          'now.',
                      action: 'Search ${wider.first.round()} km',
                      onPressed: () {
                        _radiusKm = wider.first;
                        _refresh();
                      },
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(36),
                      child: Text(
                        'No offers right now. Pull to refresh.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              );
            }
            final start = banner == null ? 0 : 1;
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: offers.length + start,
              itemBuilder: (context, index) {
                if (index < start) return banner!;
                final i = index - start;
                return OfferCard(
                  offer: offers[i],
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OfferDetailScreen(offer: offers[i]),
                      ),
                    );
                    _refresh();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

typedef _LocationChoice = ({String? city, bool useDevice, double radiusKm});

class _LocationSheet extends StatefulWidget {
  const _LocationSheet({required this.radiusKm});
  final double radiusKm;

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  late double _radiusKm = widget.radiusKm;

  void _done({String? city, bool useDevice = false}) => Navigator.of(context)
      .pop<_LocationChoice>((
        city: city,
        useDevice: useDevice,
        radiusKm: _radiusKm,
      ));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Distance', style: theme.textTheme.titleSmall),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<double>(
                segments: [
                  for (final r in _radiusOptions)
                    ButtonSegment(value: r, label: Text('${r.round()} km')),
                ],
                selected: {_radiusKm},
                onSelectionChanged: (v) => setState(() => _radiusKm = v.first),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.my_location),
              title: const Text('Use my current location'),
              onTap: () => _done(useDevice: true),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('Or pick a city', style: theme.textTheme.titleSmall),
            ),
            for (final city in cities.keys)
              ListTile(
                leading: const Icon(Icons.location_city),
                title: Text(city),
                onTap: () => _done(city: city),
              ),
            ListTile(
              leading: const Icon(Icons.check),
              title: const Text('Just change the distance'),
              onTap: () => _done(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.text,
    required this.action,
    required this.onPressed,
  });

  final String text;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.secondaryContainer,
    margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onPressed, child: Text(action)),
          ),
        ],
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.text);
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
