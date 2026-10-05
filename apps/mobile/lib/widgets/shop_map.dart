import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/shop.dart';

LatLng _latLng(GeoPoint p) => LatLng(p.lat, p.lng);

/// OpenStreetMap tiles. Their usage policy requires [_attribution] on top.
Widget _tiles() => TileLayer(
  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  userAgentPackageName: 'com.calecutech.voffer',
);

const _attribution = SimpleAttributionWidget(
  source: Text('OpenStreetMap contributors'),
);

Marker _pin(GeoPoint p, Color color) => Marker(
  point: _latLng(p),
  width: 48,
  height: 48,
  alignment: Alignment.topCenter,
  child: Icon(Icons.location_on, size: 48, color: color),
);

/// Full-screen map showing where a shop is.
class ShopMapScreen extends StatelessWidget {
  const ShopMapScreen({super.key, required this.shop});

  final Shop shop;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(shop.name)),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: _latLng(shop.location),
          initialZoom: 16,
        ),
        children: [
          _tiles(),
          MarkerLayer(
            markers: [
              _pin(shop.location, Theme.of(context).colorScheme.primary),
            ],
          ),
          _attribution,
        ],
      ),
    );
  }
}

/// Lets a firm drop a pin where its shop is. Pops with the chosen
/// [GeoPoint].
class PickLocationScreen extends StatefulWidget {
  const PickLocationScreen({super.key, required this.initial});

  final GeoPoint initial;

  @override
  State<PickLocationScreen> createState() => _PickLocationScreenState();
}

class _PickLocationScreenState extends State<PickLocationScreen> {
  late GeoPoint _point = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shop location')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: _latLng(_point),
              initialZoom: 16,
              onTap: (_, latLng) => setState(
                () => _point = GeoPoint(latLng.latitude, latLng.longitude),
              ),
            ),
            children: [
              _tiles(),
              MarkerLayer(
                markers: [_pin(_point, Theme.of(context).colorScheme.primary)],
              ),
              _attribution,
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Tap the map where your shop is.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(_point),
            icon: const Icon(Icons.check),
            label: const Text('Use this location'),
          ),
        ),
      ),
    );
  }
}
