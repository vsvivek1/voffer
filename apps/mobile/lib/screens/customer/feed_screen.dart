import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../models/offer.dart';
import '../../widgets/offer_card.dart';
import 'offer_detail_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String? _category;
  String _query = '';
  late Future<List<Offer>> _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future = _load();
  }

  Future<List<Offer>> _load() =>
      AppScope.read(context).repository
          .fetchFeed(category: _category, query: _query);

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
        title: const Text('Offers'),
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
            if (offers.isEmpty) {
              return const _Message('No offers right now. Pull to refresh.');
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: offers.length,
              itemBuilder: (context, i) => OfferCard(
                offer: offers[i],
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => OfferDetailScreen(offer: offers[i]),
                    ),
                  );
                  _refresh();
                },
              ),
            );
          },
        ),
      ),
    );
  }
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
