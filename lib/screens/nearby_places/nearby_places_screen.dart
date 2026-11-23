import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:pocket_plan/core/layout/desktop_shell.dart';
import 'package:pocket_plan/core/services/database_service.dart';
import 'package:pocket_plan/core/services/dish_tip_service.dart';
import 'package:pocket_plan/core/services/location_service.dart';
import 'package:pocket_plan/core/themes/app_colors.dart';
import 'package:pocket_plan/core/utils/amount_input.dart';
import 'package:pocket_plan/core/utils/budget_cycle.dart';
import 'package:pocket_plan/core/utils/currency_formatter.dart';
import 'package:pocket_plan/models/budget_model.dart';
import 'package:pocket_plan/models/dish_tip_model.dart';
import 'package:pocket_plan/models/transaction_model.dart';
import 'package:pocket_plan/providers/currency_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class NearbyPlacesScreen extends ConsumerStatefulWidget {
  const NearbyPlacesScreen({super.key});

  @override
  ConsumerState<NearbyPlacesScreen> createState() =>
      _NearbyPlacesScreenState();
}

class _NearbyPlacesScreenState extends ConsumerState<NearbyPlacesScreen>
    with TickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final DishTipService _dishTipService = DishTipService();
  StreamSubscription<BudgetModel?>? _budgetSub;
  BudgetModel? _budget;
  List<DishTipModel> _tips = [];

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
    'Fits Budget',
    'Restaurant',
    'Food Court',
    'Fast Food',
    'Cafe',
    'Bakery',
    'Grocery',
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
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isNotEmpty) {
      _budgetSub = _db.budgetStream(uid).listen((b) {
        if (mounted) setState(() => _budget = b);
      });
    }
    _initLocation();
  }

  @override
  void dispose() {
    _budgetSub?.cancel();
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
      _errorMessage = '';
      _places = [];
    });

    try {
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

      final tipsFuture = _dishTipService.fetchNearbyTips(
        lat: position.latitude,
        lon: position.longitude,
      );

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

          double lat;
          double lon;
          if (e['type'] == 'way' && e['center'] != null) {
            lat = (e['center']['lat'] as num).toDouble();
            lon = (e['center']['lon'] as num).toDouble();
          } else if (e['lat'] != null && e['lon'] != null) {
            lat = (e['lat'] as num).toDouble();
            lon = (e['lon'] as num).toDouble();
          } else {
            continue;
          }

          final distance = LocationService.distanceBetween(
            position.latitude,
            position.longitude,
            lat,
            lon,
          );

          final amenity = tags['amenity'] ?? tags['shop'] ?? 'restaurant';
          final name =
              tags['name'] ??
              tags['brand'] ??
              _amenityLabelStatic(amenity);
          final placeId = '${e['type'] ?? 'node'}_${e['id'] ?? '${lat}_$lon'}';

          final currency = ref.read(currencyProvider);
          places.add(
            PlaceModel(
              placeId: placeId,
              name: name,
              amenity: amenity,
              cuisine: tags['cuisine'] ?? '',
              lat: lat,
              lon: lon,
              distance: distance,
              openingHours: tags['opening_hours'] ?? '',
              phone: tags['phone'] ?? tags['contact:phone'] ?? '',
              priceRange:
                  tags['price_range'] ??
                  _estimatePriceRange(amenity, currency),
              estimatedMaxPrice: _estimateMaxPrice(amenity, currency),
            ),
          );
        }

        places.sort((a, b) => a.distance.compareTo(b.distance));
        final tips = await tipsFuture;

        if (mounted) {
          setState(() {
            _places = places;
            _tips = tips;
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
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingPlaces = false;
          _errorMessage =
              'Could not load nearby places. Check your connection and try again.';
        });
      }
    }
  }

  String _estimatePriceRange(String amenity, String currency) {
    if (currency.toUpperCase() == 'MYR') {
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

    switch (amenity) {
      case 'bakery':
      case 'canteen':
      case 'food_court':
      case 'fast_food':
        return 'Budget-Friendly (\$)';
      case 'convenience':
      case 'supermarket':
        return 'Groceries & Essentials';
      case 'cafe':
      case 'restaurant':
        return 'Moderate (\$\$)';
      default:
        return 'Budget-Friendly (\$)';
    }
  }

  int get _daysLeftInCycle {
    final b = _budget;
    if (b == null) return 30;
    final cycle = BudgetCycle.forDate(
      DateTime.now(),
      startDay: b.budgetStartDay,
    );
    return cycle.daysRemaining(DateTime.now()).clamp(1, 31);
  }

  double? get _dailyLifestyleBudget {
    final b = _budget;
    if (b == null || b.spendings.limit <= 0) return null;
    final remaining = (b.spendings.limit - b.spendings.spent).clamp(
      0.0,
      double.infinity,
    );
    return remaining / _daysLeftInCycle;
  }

  double? _estimateMaxPrice(String amenity, String currency) {
    final baseMyr = switch (amenity) {
      'bakery' || 'canteen' => 10.0,
      'food_court' => 12.0,
      'fast_food' || 'convenience' => 15.0,
      'cafe' => 20.0,
      'restaurant' => 30.0,
      'supermarket' => 50.0,
      _ => 20.0,
    };
    final factor = switch (currency.toUpperCase()) {
      'MYR' => 1.0,
      'SGD' || 'AUD' => 0.65,
      'USD' || 'EUR' => 0.55,
      'GBP' => 0.45,
      'THB' => 7.5,
      'PHP' => 12.0,
      'IDR' => 3500.0,
      'JPY' => 80.0,
      _ => 1.0,
    };
    return (baseMyr * factor).roundToDouble();
  }

  bool _fitsDailyBudget(PlaceModel place) {
    final daily = _dailyLifestyleBudget;
    if (daily == null) return false;
    final cheapest = DishTipModel.cheapestForPlace(_tips, place.placeId);
    final cost = cheapest != null ? cheapest.price : place.estimatedMaxPrice;
    return cost != null && DishTipModel.fitsDailyBudget(cost, daily);
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
        case 'Fits Budget':
          return _fitsDailyBudget(p);
        case 'Restaurant':
          return p.amenity == 'restaurant';
        case 'Food Court':
          return p.amenity == 'food_court' || p.amenity == 'canteen';
        case 'Fast Food':
          return p.amenity == 'fast_food';
        case 'Cafe':
          return p.amenity == 'cafe';
        case 'Bakery':
          return p.amenity == 'bakery';
        case 'Grocery':
          return p.amenity == 'supermarket' || p.amenity == 'convenience';
        default:
          return true;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      backgroundColor: colors.background,
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
                  child: isDesktopLayout(context)
                      // Desktop: list + filters on the left, big map on the right.
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 440,
                              child: Column(
                                children: [
                                  _buildDailyBudgetBanner(),
                                  _buildStatsBar(),
                                  _buildFilterChips(),
                                  _buildPlacesList(),
                                ],
                              ),
                            ),
                            Expanded(child: _buildMap(height: double.infinity)),
                          ],
                        )
                      : Column(
                          children: [
                            _buildMap(),
                            _buildDailyBudgetBanner(),
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
    final colors = context.colors;
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
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: colors.textPrimary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nearby Food Places',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Budget-friendly food & groceries near you',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12),
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
                color: colors.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.accent.withOpacity(0.3)),
              ),
              child: _isLoadingPlaces
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.accent,
                      ),
                    )
                  : Icon(Icons.refresh_rounded, color: colors.accent, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap({double? height}) {
    final colors = context.colors;
    if (_currentPosition == null) return const SizedBox();
    final userLatLng = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      height: height ?? 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
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
              userAgentPackageName: 'com.kymee.pocketplan',
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
                      color: colors.accent,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: colors.accent.withOpacity(0.5),
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
            SimpleAttributionWidget(
              source: Text(
                'OpenStreetMap contributors',
                style: TextStyle(color: colors.textSecondary, fontSize: 10),
              ),
              backgroundColor: colors.surface.withOpacity(0.85),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyBudgetBanner() {
    final colors = context.colors;
    final currency = ref.watch(currencyProvider);
    final daily = _dailyLifestyleBudget;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: (daily != null && daily > 0 ? colors.success : colors.surface)
              .withValues(alpha: daily != null && daily > 0 ? 0.12 : 1.0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: daily != null && daily > 0
                ? colors.success.withValues(alpha: 0.35)
                : colors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              color: daily != null && daily > 0
                  ? colors.success
                  : colors.textSecondary,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                daily == null
                    ? 'Set your monthly budget to track your daily meal allowance'
                    : 'Daily lifestyle budget: ${CurrencyFormatter.format(daily, code: currency)}/day ($_daysLeftInCycle d left)',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (daily != null && daily > 0 && _selectedFilter != 'Fits Budget')
              TextButton(
                onPressed: () => setState(() => _selectedFilter = 'Fits Budget'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 28),
                ),
                child: Text(
                  'Filter',
                  style: TextStyle(
                    color: colors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    final colors = context.colors;
    final hasFetchError = _errorMessage.isNotEmpty && _places.isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Icon(
            hasFetchError ? Icons.error_outline : Icons.place_outlined,
            color: hasFetchError ? colors.danger : colors.success,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _isLoadingPlaces
                  ? 'Searching nearby places...'
                  : hasFetchError
                  ? _errorMessage
                  : _places.isEmpty
                  ? 'Limited OSM data in this area — try refreshing'
                  : '${_filteredPlaces.length} places found within ${_radius ~/ 1000}km',
              style: TextStyle(
                color: hasFetchError ? colors.danger : colors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final colors = context.colors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          final color = colors.accent;
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
                    color: isSelected ? color.withOpacity(0.5) : colors.border,
                  ),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: isSelected ? color : colors.textTertiary,
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
    final colors = context.colors;
    if (_isLoadingPlaces) {
      return Expanded(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: colors.accent),
              const SizedBox(height: 12),
              Text(
                'Searching nearby places...',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'This may take a few seconds',
                style: TextStyle(color: colors.textTertiary, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage.isNotEmpty && _places.isEmpty) {
      return Expanded(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_rounded, size: 48, color: colors.danger),
                const SizedBox(height: 12),
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _currentPosition != null
                      ? _fetchNearbyPlaces(_currentPosition!)
                      : _initLocation(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.accent.withOpacity(0.3)),
                    ),
                    child: Text(
                      'Retry',
                      style: TextStyle(
                        color: colors.accent,
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

    final filtered = _filteredPlaces;

    if (filtered.isEmpty) {
      final isBudgetFilter = _selectedFilter == 'Fits Budget';
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
                  color: colors.textTertiary,
                ),
                const SizedBox(height: 12),
                Text(
                  isBudgetFilter
                      ? 'No spots match your daily budget'
                      : 'No places found nearby',
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isBudgetFilter
                      ? 'Try viewing all nearby spots or tag an affordable dish you discover.'
                      : 'OpenStreetMap coverage varies by area.\nSome local stalls may not be listed yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textTertiary,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: isBudgetFilter
                      ? () => setState(() => _selectedFilter = 'All')
                      : () => _fetchNearbyPlaces(_currentPosition!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      isBudgetFilter ? 'Show All Places' : 'Retry',
                      style: TextStyle(
                        color: colors.accent,
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
    final colors = context.colors;
    final color = _amenityColor(place.amenity);
    final icon = _amenityIcon(place.amenity);
    final cheapest = DishTipModel.cheapestForPlace(_tips, place.placeId);
    final fits = _fitsDailyBudget(place);

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
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
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
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
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
                      if (fits)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colors.success.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Fits Budget',
                            style: TextStyle(
                              color: colors.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (place.cuisine.isNotEmpty)
                        Text(
                          place.cuisine,
                          style: TextStyle(
                            color: colors.textTertiary,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  if (cheapest != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.local_offer_outlined,
                          color: colors.accent,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Tip: ${cheapest.dishName} (${CurrencyFormatter.format(cheapest.price, code: cheapest.currency)})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (place.priceRange.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          color: colors.success,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          place.priceRange,
                          style: TextStyle(
                            color: colors.success,
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
                color: colors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: colors.textSecondary,
                    size: 12,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    LocationService.formatDistance(place.distance),
                    style: TextStyle(
                      color: colors.textSecondary,
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
    final colors = context.colors;
    final color = _amenityColor(place.amenity);
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final placeTips = _tips
              .where((t) => t.placeId == place.placeId)
              .toList();
          final cheapest = DishTipModel.cheapestForPlace(_tips, place.placeId);
          final fits = _fitsDailyBudget(place);

          return SafeArea(
            child: SingleChildScrollView(
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
                        color: colors.border,
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
                          color: color.withValues(alpha: 0.15),
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
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  _amenityLabelStatic(place.amenity),
                                  style: TextStyle(color: color, fontSize: 13),
                                ),
                                if (fits) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colors.success.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Fits Daily Budget',
                                      style: TextStyle(
                                        color: colors.success,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
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
                    InkWell(
                      onTap: () => _launchTel(place.phone),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              Icons.phone_outlined,
                              color: colors.accent,
                              size: 16,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                place.phone,
                                style: TextStyle(
                                  color: colors.accent,
                                  fontSize: 13,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _launchDirections(place),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.accent,
                            side: BorderSide(color: colors.accent),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.directions_rounded, size: 18),
                          label: const Text('Directions'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _logMeal(place, cheapest);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.accent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.receipt_long_rounded,
                            size: 18,
                          ),
                          label: const Text('Log Meal'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Community Cheap Dishes',
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showAddDishTipDialog(
                          place,
                          () => setSheetState(() {}),
                        ),
                        icon: Icon(
                          Icons.add_circle_outline_rounded,
                          size: 16,
                          color: colors.success,
                        ),
                        label: Text(
                          '+ Tag Cheap Dish',
                          style: TextStyle(
                            color: colors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (placeTips.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'No community dish prices yet. Know a value meal here? Tag it to help others!',
                        style: TextStyle(
                          color: colors.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    )
                  else
                    ...placeTips.map(
                      (tip) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surfaceAlt,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    tip.dishName,
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Shared by ${tip.authorName}',
                                    style: TextStyle(
                                      color: colors.textTertiary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              CurrencyFormatter.format(
                                tip.price,
                                code: tip.currency,
                              ),
                              style: TextStyle(
                                color: colors.success,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              tooltip: 'Log this meal',
                              icon: Icon(
                                Icons.add_shopping_cart_rounded,
                                size: 18,
                                color: colors.accent,
                              ),
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _logMeal(place, tip);
                              },
                            ),
                            if (currentUid.isNotEmpty && tip.userId == currentUid)
                              IconButton(
                                tooltip: 'Delete tip',
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: colors.danger,
                                ),
                                onPressed: () async {
                                  await _dishTipService.deleteTip(tip.id);
                                  if (!mounted) return;
                                  setState(() {
                                    _tips.removeWhere((t) => t.id == tip.id);
                                  });
                                  setSheetState(() {});
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _launchDirections(PlaceModel place) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=${place.lat},${place.lon}',
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open maps application.')),
      );
    }
  }

  Future<void> _launchTel(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'\s+'), '');
    final uri = Uri(scheme: 'tel', path: cleaned);
    await launchUrl(uri);
  }

  void _logMeal(PlaceModel place, DishTipModel? tip) {
    Navigator.of(context).pushNamed(
      '/add-transaction',
      arguments: TransactionPrefill(
        type: TransactionType.expense,
        budgetCategory: BudgetCategory.spending,
        category: 'Dining Out & Cafes',
        amount: tip?.price,
        description: tip != null ? '${tip.dishName} @ ${place.name}' : place.name,
      ),
    );
  }

  Future<void> _showAddDishTipDialog(
    PlaceModel place,
    VoidCallback onAdded,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to share a dish price.')),
      );
      return;
    }

    final dishCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final currency = ref.read(currencyProvider);
    final symbol = CurrencyFormatter.symbol(currency);
    final colors = context.colors;

    final savedTip = await showDialog<DishTipModel>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'Tag Cheap Dish',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              place.name,
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dishCtrl,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Dish / Meal Name',
                hintText: 'e.g. Economy Mixed Rice',
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [AmountInputFormatter()],
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Price ($symbol)',
                prefixText: '$symbol ',
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final dish = dishCtrl.text.trim();
              final price = parseCents(priceCtrl.text) / 100.0;
              if (dish.isEmpty || price <= 0) return;

              final profile = await _db.getUser(user.uid);
              final author = (profile?.name.trim().isNotEmpty ?? false)
                  ? profile!.name.trim()
                  : (user.displayName?.trim().isNotEmpty ?? false)
                  ? user.displayName!.trim()
                  : 'PocketPlan User';

              final created = await _dishTipService.addTip(
                DishTipModel(
                  id: '',
                  userId: user.uid,
                  authorName: author,
                  placeId: place.placeId,
                  placeName: place.name,
                  dishName: dish,
                  price: price,
                  currency: currency,
                  lat: place.lat,
                  lon: place.lon,
                  createdAt: DateTime.now(),
                ),
              );
              if (dlgCtx.mounted) Navigator.of(dlgCtx).pop(created);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Share Tip'),
          ),
        ],
      ),
    );

    dishCtrl.dispose();
    priceCtrl.dispose();

    if (savedTip != null && mounted) {
      setState(() {
        _tips.add(savedTip);
        _tips.sort((a, b) => a.price.compareTo(b.price));
      });
      onAdded();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Shared "${savedTip.dishName}" at ${place.name}!'),
          backgroundColor: colors.success,
        ),
      );
    }
  }

  Widget _detailRow(IconData icon, String text) {
    final colors = context.colors;
    return Row(
      children: [
        Icon(icon, color: colors.textSecondary, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: colors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    final colors = context.colors;
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: colors.accent),
            const SizedBox(height: 16),
            Text(
              'Getting your location...',
              style: TextStyle(color: colors.textPrimary, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Please allow location access',
              style: TextStyle(color: colors.textTertiary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner() {
    final colors = context.colors;
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_off_outlined, color: colors.danger, size: 56),
              const SizedBox(height: 16),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
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
                    color: colors.accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.accent.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Try Again',
                    style: TextStyle(
                      color: colors.accent,
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
    final colors = context.colors;
    switch (amenity) {
      case 'cafe':
        return colors.warning;
      case 'fast_food':
        return colors.danger;
      case 'food_court':
        return colors.success;
      case 'bar':
        return const Color(0xFF9C8DFF);
      case 'bakery':
        return colors.warning;
      case 'canteen':
        return colors.success;
      case 'convenience':
      case 'supermarket':
        return colors.info;
      default:
        return colors.accent;
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
  final String placeId;
  final String name;
  final String amenity;
  final String cuisine;
  final double lat;
  final double lon;
  final double distance;
  final String openingHours;
  final String phone;
  final String priceRange;
  final double? estimatedMaxPrice;

  PlaceModel({
    required this.placeId,
    required this.name,
    required this.amenity,
    required this.cuisine,
    required this.lat,
    required this.lon,
    required this.distance,
    required this.openingHours,
    required this.phone,
    required this.priceRange,
    this.estimatedMaxPrice,
  });
}
