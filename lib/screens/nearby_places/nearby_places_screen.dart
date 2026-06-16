import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:pocket_plan/core/services/location_service.dart';

class NearbyPlacesScreen extends StatefulWidget {
  const NearbyPlacesScreen({super.key});

  @override
  State<NearbyPlacesScreen> createState() => _NearbyPlacesScreenState();
}

class _NearbyPlacesScreenState extends State<NearbyPlacesScreen>
    with TickerProviderStateMixin {
  Position? _currentPosition;
  List<PlaceModel> _places = [];
  bool _isLoadingLocation = true;
  bool _isLoadingPlaces = false;
  String _errorMessage = '';
  String _selectedFilter = 'All';
  final MapController _mapController = MapController();

  late AnimationController _entryController;
  late Animation<double> _fadeAnimation;

  final List<String> _filters = [
    'All',
    'Restaurant',
    'Cafe',
    'Fast Food',
    'Food Court',
  ];

  // Increased to 5km for better Malaysian coverage
  static const int _radius = 5000;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _entryController,
      curve: Curves.easeIn,
    );
    _entryController.forward();
    _initLocation();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _initLocation() async {
    if (!mounted) return;
    setState(() {
      _isLoadingLocation = true;
      _errorMessage = '';
      _places = [];
    });

    final position = await LocationService.getCurrentPosition();

    if (!mounted) return;

    if (position == null) {
      setState(() {
        _isLoadingLocation = false;
        _errorMessage =
            'Could not get your location.\nPlease enable location services and try again.';
      });
      return;
    }

    setState(() {
      _currentPosition = position;
      _isLoadingLocation = false;
    });

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      try {
        _mapController.move(
          LatLng(position.latitude, position.longitude),
          14.0,
        );
      } catch (_) {}
    }

    await _fetchNearbyPlaces(position);
  }

  Future<void> _fetchNearbyPlaces(Position position) async {
    if (!mounted) return;
    setState(() {
      _isLoadingPlaces = true;
      _places = [];
    });

    try {
      // Broader query covering more Malaysian food place types
      // including way elements for larger establishments
      final query =
          '''
[out:json][timeout:30];
(
  node["amenity"="restaurant"](around:$_radius,${position.latitude},${position.longitude});
  node["amenity"="cafe"](around:$_radius,${position.latitude},${position.longitude});
  node["amenity"="fast_food"](around:$_radius,${position.latitude},${position.longitude});
  node["amenity"="food_court"](around:$_radius,${position.latitude},${position.longitude});
  node["amenity"="bar"](around:$_radius,${position.latitude},${position.longitude});
  node["amenity"="ice_cream"](around:$_radius,${position.latitude},${position.longitude});
  node["amenity"="canteen"](around:$_radius,${position.latitude},${position.longitude});
  node["shop"="bakery"](around:$_radius,${position.latitude},${position.longitude});
  node["shop"="convenience"](around:$_radius,${position.latitude},${position.longitude});
  node["shop"="supermarket"](around:$_radius,${position.latitude},${position.longitude});
  way["amenity"="restaurant"](around:$_radius,${position.latitude},${position.longitude});
  way["amenity"="cafe"](around:$_radius,${position.latitude},${position.longitude});
  way["amenity"="fast_food"](around:$_radius,${position.latitude},${position.longitude});
  way["amenity"="food_court"](around:$_radius,${position.latitude},${position.longitude});
);
out center;
''';

      final response = await http
          .post(
            Uri.parse('https://overpass-api.de/api/interpreter'),
            body: {'data': query},
          )
          .timeout(const Duration(seconds: 30));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final elements = data['elements'] as List;

        final List<PlaceModel> places = [];

        for (final e in elements) {
          if (e['tags'] == null) continue;

          final tags = e['tags'] as Map<String, dynamic>;

          // Handle both node (direct lat/lon) and way (center lat/lon)
          double lat;
          double lon;
          if (e['type'] == 'way' && e['center'] != null) {
            lat = (e['center']['lat'] as num).toDouble();
            lon = (e['center']['lon'] as num).toDouble();
          } else if (e['lat'] != null && e['lon'] != null) {
            lat = (e['lat'] as num).toDouble();
            lon = (e['lon'] as num).toDouble();
          } else {
            continue; // skip if no coordinates
          }

          final distance = LocationService.distanceBetween(
            position.latitude,
            position.longitude,
            lat,
            lon,
          );

          final name =
              tags['name'] ??
              tags['brand'] ??
              _amenityLabelStatic(tags['amenity'] ?? tags['shop'] ?? 'place');

          places.add(
            PlaceModel(
              name: name,
              amenity: tags['amenity'] ?? tags['shop'] ?? 'restaurant',
              cuisine: tags['cuisine'] ?? '',
              lat: lat,
              lon: lon,
              distance: distance,
              openingHours: tags['opening_hours'] ?? '',
              phone: tags['phone'] ?? tags['contact:phone'] ?? '',
              priceRange:
                  tags['price_range'] ??
                  _estimatePriceRange(tags['amenity'] ?? tags['shop'] ?? ''),
            ),
          );
        }

        // Sort by distance
        places.sort((a, b) => a.distance.compareTo(b.distance));

        if (mounted) {
          setState(() {
            _places = places;
            _isLoadingPlaces = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingPlaces = false;
            _errorMessage =
                'Failed to fetch places (${response.statusCode}). Try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPlaces = false;
        });
      }
    }
  }

  String _estimatePriceRange(String amenity) {
    switch (amenity) {
      case 'fast_food':
        return 'RM 5 – RM 15';
      case 'cafe':
        return 'RM 8 – RM 20';
      case 'food_court':
        return 'RM 5 – RM 12';
      case 'restaurant':
        return 'RM 10 – RM 30';
      case 'bakery':
        return 'RM 3 – RM 10';
      case 'canteen':
        return 'RM 3 – RM 10';
      case 'convenience':
        return 'RM 2 – RM 15';
      case 'supermarket':
        return 'RM 5 – RM 50';
      default:
        return 'RM 5 – RM 20';
    }
  }

  static String _amenityLabelStatic(String amenity) {
    switch (amenity) {
      case 'cafe':
        return 'Cafe';
      case 'fast_food':
        return 'Fast Food';
      case 'food_court':
        return 'Food Court';
      case 'bar':
        return 'Bar';
      case 'bakery':
        return 'Bakery';
      case 'convenience':
        return 'Convenience Store';
      case 'supermarket':
        return 'Supermarket';
      case 'canteen':
        return 'Canteen';
      case 'ice_cream':
        return 'Ice Cream';
      default:
        return 'Restaurant';
    }
  }

  List<PlaceModel> get _filteredPlaces {
    if (_selectedFilter == 'All') return _places;
    return _places.where((p) {
      switch (_selectedFilter) {
        case 'Restaurant':
          return p.amenity == 'restaurant';
        case 'Cafe':
          return p.amenity == 'cafe';
        case 'Fast Food':
          return p.amenity == 'fast_food';
        case 'Food Court':
          return p.amenity == 'food_court';
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              _buildHeader(),
              if (_errorMessage.isNotEmpty && _currentPosition == null)
                _buildErrorBanner()
              else if (_isLoadingLocation)
                _buildLoadingState()
              else
                Expanded(
                  child: Column(
                    children: [
                      _buildMap(),
                      _buildStatsBar(),
                      _buildFilterChips(),
                      _buildPlacesList(),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nearby Food Places',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Affordable options near you',
                  style: TextStyle(color: Color(0xFF9E9FBF), fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _currentPosition != null
                ? () => _fetchNearbyPlaces(_currentPosition!)
                : _initLocation,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF6C63FF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                ),
              ),
              child: _isLoadingPlaces
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF6C63FF),
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFF6C63FF),
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    if (_currentPosition == null) return const SizedBox();
    final userLatLng = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: userLatLng,
            initialZoom: 14.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.pocket_plan',
            ),
            MarkerLayer(
              markers: [
                // Current location marker
                Marker(
                  point: userLatLng,
                  width: 44,
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF6C63FF),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withOpacity(0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_pin_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
                // Place markers
                ..._filteredPlaces.take(50).map((place) {
                  final color = _amenityColor(place.amenity);
                  return Marker(
                    point: LatLng(place.lat, place.lon),
                    width: 36,
                    height: 36,
                    child: GestureDetector(
                      onTap: () => _showPlaceBottomSheet(place),
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.4),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Icon(
                          _amenityIcon(place.amenity),
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          const Icon(Icons.place_outlined, color: Color(0xFF00D4AA), size: 16),
          const SizedBox(width: 6),
          Text(
            _isLoadingPlaces
                ? 'Searching nearby places...'
                : _places.isEmpty
                ? 'Limited OSM data in this area — try refreshing'
                : '${_filteredPlaces.length} places found within ${_radius ~/ 1000}km',
            style: const TextStyle(color: Color(0xFF9E9FBF), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          const color = Color(0xFF6C63FF);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? color.withOpacity(0.5)
                        : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? color : const Color(0xFF4A4A6A),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlacesList() {
    if (_isLoadingPlaces) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF6C63FF)),
              const SizedBox(height: 12),
              Text(
                'Searching nearby places...',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'This may take a few seconds',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.3),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filteredPlaces;

    if (filtered.isEmpty) {
      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.restaurant_outlined,
                  size: 48,
                  color: Colors.white.withOpacity(0.2),
                ),
                const SizedBox(height: 12),
                Text(
                  'No places found nearby',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                // Honest message about OSM limitation
                Text(
                  'OpenStreetMap data coverage varies in Malaysia.\nMany local restaurants and mamak stalls may not be listed yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _fetchNearbyPlaces(_currentPosition!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF6C63FF).withOpacity(0.3),
                      ),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(
                        color: Color(0xFF6C63FF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        itemCount: filtered.length,
        itemBuilder: (context, i) => _buildPlaceCard(filtered[i]),
      ),
    );
  }

  Widget _buildPlaceCard(PlaceModel place) {
    final color = _amenityColor(place.amenity);
    final icon = _amenityIcon(place.amenity);

    return GestureDetector(
      onTap: () {
        try {
          _mapController.move(LatLng(place.lat, place.lon), 17.0);
        } catch (_) {}
        _showPlaceBottomSheet(place);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _amenityLabelStatic(place.amenity),
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (place.cuisine.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          place.cuisine,
                          style: const TextStyle(
                            color: Color(0xFF4A4A6A),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (place.priceRange.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.payments_outlined,
                          color: Color(0xFF00D4AA),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          place.priceRange,
                          style: const TextStyle(
                            color: Color(0xFF00D4AA),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFF9E9FBF),
                    size: 12,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    LocationService.formatDistance(place.distance),
                    style: const TextStyle(
                      color: Color(0xFF9E9FBF),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPlaceBottomSheet(PlaceModel place) {
    final color = _amenityColor(place.amenity);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _amenityIcon(place.amenity),
                    color: color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        _amenityLabelStatic(place.amenity),
                        style: TextStyle(color: color, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _detailRow(
              Icons.location_on_outlined,
              '${LocationService.formatDistance(place.distance)} away',
            ),
            if (place.priceRange.isNotEmpty) ...[
              const SizedBox(height: 10),
              _detailRow(
                Icons.payments_outlined,
                'Est. price: ${place.priceRange}',
              ),
            ],
            if (place.cuisine.isNotEmpty) ...[
              const SizedBox(height: 10),
              _detailRow(Icons.restaurant_menu_outlined, place.cuisine),
            ],
            if (place.openingHours.isNotEmpty) ...[
              const SizedBox(height: 10),
              _detailRow(Icons.access_time_rounded, place.openingHours),
            ],
            if (place.phone.isNotEmpty) ...[
              const SizedBox(height: 10),
              _detailRow(Icons.phone_outlined, place.phone),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF9E9FBF), size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF9E9FBF), fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF6C63FF)),
            const SizedBox(height: 16),
            const Text(
              'Getting your location...',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Please allow location access',
              style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.location_off_outlined,
                color: Color(0xFFFF6B6B),
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF9E9FBF), fontSize: 14),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: _initLocation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF6C63FF).withOpacity(0.3),
                    ),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                      color: Color(0xFF6C63FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _amenityColor(String amenity) {
    switch (amenity) {
      case 'cafe':
        return const Color(0xFFFFB347);
      case 'fast_food':
        return const Color(0xFFFF6B6B);
      case 'food_court':
        return const Color(0xFF00D4AA);
      case 'bar':
        return const Color(0xFF9C8DFF);
      case 'bakery':
        return const Color(0xFFFFB347);
      case 'canteen':
        return const Color(0xFF00D4AA);
      case 'convenience':
      case 'supermarket':
        return const Color(0xFF4FC3F7);
      default:
        return const Color(0xFF6C63FF);
    }
  }

  IconData _amenityIcon(String amenity) {
    switch (amenity) {
      case 'cafe':
        return Icons.local_cafe_outlined;
      case 'fast_food':
        return Icons.fastfood_outlined;
      case 'food_court':
        return Icons.food_bank_outlined;
      case 'bar':
        return Icons.local_bar_outlined;
      case 'bakery':
        return Icons.bakery_dining_outlined;
      case 'canteen':
        return Icons.dinner_dining_outlined;
      case 'convenience':
        return Icons.store_outlined;
      case 'supermarket':
        return Icons.shopping_cart_outlined;
      default:
        return Icons.restaurant_outlined;
    }
  }
}

// ─────────────────────────────────────────
// PLACE MODEL
// ─────────────────────────────────────────
class PlaceModel {
  final String name;
  final String amenity;
  final String cuisine;
  final double lat;
  final double lon;
  final double distance;
  final String openingHours;
  final String phone;
  final String priceRange;

  PlaceModel({
    required this.name,
    required this.amenity,
    required this.cuisine,
    required this.lat,
    required this.lon,
    required this.distance,
    required this.openingHours,
    required this.phone,
    required this.priceRange,
  });
}
