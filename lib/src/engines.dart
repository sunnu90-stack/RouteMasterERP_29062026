// ============================================================
// engines.dart  —  part of liquid_logistics main library
// Auto-extracted from main_v23_8.dart (original lines 3058-3898)
// DO NOT add imports here — all imports live in main.dart
// ============================================================
part of 'package:liquid_logistics/main.dart';

class RoutingEngine {
  // ════════════════════════════════════════════════════════════════
  //  PRECISE DISTANCE ENGINE  —  works exactly like Uber / Zomato
  //
  //  Priority order:
  //   1. Google Directions API  (placeId or address → real roads,
  //                              live traffic, multiple routes)
  //   2. Distance Matrix API    (fallback, also real roads)
  //   No hardcoded tables. No guessing. Every km from Google.
  // ════════════════════════════════════════════════════════════════

  /// Result returned to the caller
  static Map<String, dynamic> _result({
    required int km,
    required String source,
    required int axles,
    required double fuelEconomy,
    double dieselPrice = AppConfig.defaultDieselPrice,
    double? preciseKm,
    String routeSummary = '',
    int durationMinutes = 0,
    int durationInTrafficMinutes = 0,
    List<Map<String, dynamic>> alternatives = const [],
    Map<String, dynamic>? defaultRoute,
    List<LatLng> routePolyline = const [],
  }) {
    if (km <= 0) {
      return {
        'km': 0,
        'distanceKm': 0.0,
        'diesel': 0,
        'toll': 0,
        'axles': axles,
        'source': source,
        'routeSummary': '',
        'durationMinutes': 0,
        'durationInTrafficMinutes': 0,
        'alternatives': [],
        'defaultRoute': null,
        'routePolyline': <LatLng>[],
      };
    }
    final distanceKm = preciseKm ?? km.toDouble();
    final diesel = (distanceKm / fuelEconomy) * dieselPrice;
    return {
      'km': km,
      'distanceKm': distanceKm,
      'diesel': diesel.round(),
      'toll': estimateToll(distanceKm, axles).round(),
      'axles': axles,
      'source': source,
      'routeSummary': routeSummary,
      'durationMinutes': durationMinutes,
      'durationInTrafficMinutes': durationInTrafficMinutes,
      'alternatives': alternatives,
      'defaultRoute': defaultRoute,
      'routePolyline': routePolyline,
    };
  }

  // ── Build an origin/destination parameter for Google APIs ───────
  // If we have a placeId → use place_id:xxx  (most precise)
  // Otherwise → use the address text with ", India" appended
  static String _param(String placeId, String text) {
    if (placeId.trim().isNotEmpty) return 'place_id:${placeId.trim()}';
    final value = text.trim();
    if (value.isEmpty) return '';
    if (RegExp(r'^-?\d+(?:\.\d+)?\s*,\s*-?\d+(?:\.\d+)?$').hasMatch(value)) {
      return value;
    }
    return '$value, India';
  }

  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;

    while (index < encoded.length) {
      int decodeValue() {
        var result = 0;
        var shift = 0;
        var byte = 0;
        do {
          if (index >= encoded.length) return 0;
          byte = encoded.codeUnitAt(index++) - 63;
          result |= (byte & 0x1f) << shift;
          shift += 5;
        } while (byte >= 0x20);
        return (result & 1) == 1 ? ~(result >> 1) : result >> 1;
      }

      latitude += decodeValue();
      longitude += decodeValue();
      points.add(LatLng(latitude / 1e5, longitude / 1e5));
    }
    return points;
  }

  // ── Google Directions API  ──────────────────────────────────────
  //   Returns multiple route options with live traffic.
  //   Uses departure_time=now so traffic is real-time.
  //   alternatives=true gets up to 3 routes.
  static Future<Map<String, dynamic>?> _directions({
    required String originParam,
    required String destParam,
  }) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${Uri.encodeComponent(originParam)}'
        '&destination=${Uri.encodeComponent(destParam)}'
        '&mode=driving'
        '&alternatives=true'
        '&departure_time=now'
        '&traffic_model=best_guess'
        '&region=in'
        '&language=en'
        '&key=${AppConfig.googleMapsApiKey}',
      );
      debugPrint('Directions API: "$originParam" → "$destParam"');
      final res = await http.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        debugPrint(
            'Directions ${res.statusCode}: ${res.body.substring(0, res.body.length.clamp(0, 200))}');
        return null;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = data['routes'];
      if (data['status'] != 'OK' || routes is! List || routes.isEmpty) {
        debugPrint(
            'Directions status: ${data['status']} | message: ${data['error_message'] ?? ""}');
        return null;
      }

      final parsed = <Map<String, dynamic>>[];
      for (final r in routes) {
        if (r is! Map<String, dynamic> || r['legs'] is! List) continue;
        int distM = 0, durSec = 0, durTrafficSec = 0;
        for (final leg in r['legs'] as List) {
          if (leg is! Map<String, dynamic>) continue;
          final legDuration = leg['duration'] is Map<String, dynamic>
              ? (leg['duration']['value'] as int? ?? 0)
              : 0;
          final legTrafficDuration =
              leg['duration_in_traffic'] is Map<String, dynamic>
                  ? (leg['duration_in_traffic']['value'] as int? ?? legDuration)
                  : legDuration;
          final distance = leg['distance'] is Map<String, dynamic>
              ? (leg['distance']['value'] as int? ?? 0)
              : 0;
          distM += distance;
          durSec += legDuration;
          durTrafficSec += legTrafficDuration;
        }
        if (distM <= 0) continue;
        parsed.add({
          'km': (distM / 1000).round(),
          'distanceKm': distM / 1000,
          'routePolyline': _decodePolyline(
            (r['overview_polyline'] as Map<String, dynamic>?)?['points']
                    as String? ??
                '',
          ),
          'durationMin': (durSec / 60).round(),
          'durationTrafficMin': (durTrafficSec / 60).round(),
          'summary': r['summary'] as String? ?? '',
          'warnings': (r['warnings'] as List?)?.join(', ') ?? '',
        });
      }
      if (parsed.isEmpty) return null;
      final defaultRoute = parsed.first;
      parsed.sort((a, b) {
        final timeOrder = (a['durationTrafficMin'] as int)
            .compareTo(b['durationTrafficMin'] as int);
        return timeOrder != 0
            ? timeOrder
            : (a['km'] as int).compareTo(b['km'] as int);
      });
      debugPrint(
          'Directions: ${parsed.length} routes. Fastest: ${parsed.first['km']} km via ${parsed.first['summary']}');
      return {
        'best': parsed.first,
        'alternatives': parsed.skip(1).toList(),
        'defaultRoute': defaultRoute,
      };
    } catch (e) {
      debugPrint('Directions API error: $e');
      return null;
    }
  }

  // ── Distance Matrix API (fallback) ─────────────────────────────
  static Future<int> _matrixKm(String originParam, String destParam) async {
    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/distancematrix/json'
        '?origins=${Uri.encodeComponent(originParam)}'
        '&destinations=${Uri.encodeComponent(destParam)}'
        '&mode=driving&departure_time=now&region=in&units=metric'
        '&key=${AppConfig.googleMapsApiKey}',
      );
      debugPrint('Matrix API: "$originParam" → "$destParam"');
      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'OK') {
          final el = data['rows']?[0]?['elements']?[0];
          if (el?['status'] == 'OK') {
            final km = ((el['distance']['value'] as int) / 1000).round();
            debugPrint('Matrix result: $km km');
            return km;
          }
        }
      }
    } catch (e) {
      debugPrint('Matrix error: $e');
    }
    return 0;
  }

  // ── PUBLIC: Main calculate entry ───────────────────────────────
  static Future<Map<String, dynamic>> calculate({
    required String origin,
    required String destination,
    int axles = 6,
    double fuelEconomy = 3.5,
    double dieselPrice = AppConfig.defaultDieselPrice,
    String originPlaceId = '',
    String destPlaceId = '',
    String originCity = '',
    String destCity = '',
  }) async {
    if (!AppConfig.hasGoogleMaps) {
      return _result(
          km: 0, source: 'no_api_key', axles: axles, fuelEconomy: fuelEconomy);
    }

    if (!fuelEconomy.isFinite || fuelEconomy <= 0) {
      return _result(
          km: 0,
          source: 'invalid_fuel_economy',
          axles: axles,
          fuelEconomy: fuelEconomy);
    }
    if (!dieselPrice.isFinite || dieselPrice <= 0) {
      return _result(
          km: 0,
          source: 'invalid_diesel_price',
          axles: axles,
          fuelEconomy: fuelEconomy);
    }

    final oParam =
        _param(originPlaceId, origin.trim().isNotEmpty ? origin : originCity);
    final dParam = _param(
        destPlaceId, destination.trim().isNotEmpty ? destination : destCity);

    if (oParam.isEmpty || dParam.isEmpty) {
      return _result(
          km: 0,
          source: 'missing_locations',
          axles: axles,
          fuelEconomy: fuelEconomy);
    }

    // ── Try Directions API first (live traffic + alternatives) ──
    final dir = await _directions(originParam: oParam, destParam: dParam);
    if (dir != null) {
      final best = dir['best'] as Map<String, dynamic>;
      final alts = (dir['alternatives'] as List).cast<Map<String, dynamic>>();
      final km = best['km'] as int;
      if (km > 0) {
        return _result(
          km: km,
          source: originPlaceId.isNotEmpty && destPlaceId.isNotEmpty
              ? 'google_directions_precise'
              : 'google_directions',
          axles: axles,
          fuelEconomy: fuelEconomy,
          dieselPrice: dieselPrice,
          preciseKm: (best['distanceKm'] as num?)?.toDouble(),
          routeSummary: best['summary'] as String,
          durationMinutes: best['durationMin'] as int,
          durationInTrafficMinutes: best['durationTrafficMin'] as int,
          alternatives: alts,
          defaultRoute: dir['defaultRoute'] as Map<String, dynamic>?,
          routePolyline:
              (best['routePolyline'] as List?)?.whereType<LatLng>().toList() ??
                  const [],
        );
      }
    }

    // ── Fallback: Distance Matrix API ──────────────────────────
    final km = await _matrixKm(oParam, dParam);
    if (km > 0) {
      return _result(
          km: km,
          source: 'google_matrix',
          axles: axles,
          fuelEconomy: fuelEconomy,
          dieselPrice: dieselPrice);
    }

    // Nothing worked
    debugPrint('Distance calc failed: "$oParam" → "$dParam"');
    return _result(
        km: 0,
        source: 'not_found',
        axles: axles,
        fuelEconomy: fuelEconomy,
        dieselPrice: dieselPrice);
  }

  // ── Public helpers ──────────────────────────────────────────────
  static String extractCityFromAddress(String address) {
    if (address.isEmpty) return '';
    final parts = address
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    const states = {
      'gujarat',
      'maharashtra',
      'rajasthan',
      'punjab',
      'haryana',
      'karnataka',
      'tamil nadu',
      'andhra pradesh',
      'telangana',
      'west bengal',
      'uttar pradesh',
      'madhya pradesh',
      'odisha',
      'assam',
      'kerala',
      'goa',
      'delhi',
      'india'
    };
    for (final part in parts) {
      if (!states.contains(part.toLowerCase())) {
        if (kKnownCities.any((c) => c.toLowerCase() == part.toLowerCase())) {
          return part;
        }
      }
    }
    for (final part in parts) {
      for (final city in kKnownCities) {
        if (part.toLowerCase().contains(city.toLowerCase())) return city;
      }
    }
    final filtered =
        parts.where((p) => !states.contains(p.toLowerCase())).toList();
    if (filtered.length >= 2) return filtered[1];
    return filtered.isNotEmpty
        ? filtered.first
        : (parts.isNotEmpty ? parts.first : '');
  }

  // Removed unused _extractCity method

  static const List<String> kKnownCities = [
    'Ahmedabad',
    'Gandhinagar',
    'Surat',
    'Vadodara',
    'Rajkot',
    'Bharuch',
    'Ankleshwar',
    'Anand',
    'Nadiad',
    'Mehsana',
    'Morbi',
    'Jamnagar',
    'Mundra',
    'Kandla',
    'Dahej',
    'Hazira',
    'Vapi',
    'Valsad',
    'Navsari',
    'Khambhat',
    'Sanand',
    'Bavla',
    'Dholka',
    'Viramgam',
    'Mumbai',
    'Pune',
    'Nagpur',
    'Nashik',
    'Thane',
    'Navi Mumbai',
    'Aurangabad',
    'Kolhapur',
    'Solapur',
    'Amravati',
    'Latur',
    'Nanded',
    'Satara',
    'Sangli',
    'Delhi',
    'Gurgaon',
    'Noida',
    'Faridabad',
    'Ghaziabad',
    'Meerut',
    'Agra',
    'Bangalore',
    'Mysuru',
    'Hubli',
    'Mangaluru',
    'Hosur',
    'Belgaum',
    'Tumkur',
    'Hyderabad',
    'Secunderabad',
    'Vijayawada',
    'Visakhapatnam',
    'Kakinada',
    'Guntur',
    'Chennai',
    'Coimbatore',
    'Madurai',
    'Trichy',
    'Salem',
    'Tirunelveli',
    'Kolkata',
    'Howrah',
    'Haldia',
    'Durgapur',
    'Asansol',
    'Siliguri',
    'Chandigarh',
    'Amritsar',
    'Ludhiana',
    'Jalandhar',
    'Bathinda',
    'Patiala',
    'Jaipur',
    'Jodhpur',
    'Udaipur',
    'Ajmer',
    'Kota',
    'Bikaner',
    'Alwar',
    'Lucknow',
    'Kanpur',
    'Varanasi',
    'Allahabad',
    'Agra',
    'Meerut',
    'Ghaziabad',
    'Indore',
    'Bhopal',
    'Ujjain',
    'Jabalpur',
    'Gwalior',
    'Ratlam',
    'Raipur',
    'Bhilai',
    'Bilaspur',
    'Korba',
    'Patna',
    'Ranchi',
    'Jamshedpur',
    'Dhanbad',
    'Bokaro',
    'Bhubaneswar',
    'Cuttack',
    'Rourkela',
    'Sambalpur',
    'Guwahati',
    'Silchar',
    'Dibrugarh',
    'Kochi',
    'Thiruvananthapuram',
    'Kozhikode',
    'Thrissur',
    'Palakkad',
    'Panaji',
    'Vasco',
    'Margao',
    'Mapusa',
    'Dehradun',
    'Haridwar',
    'Roorkee',
    'Jammu',
    'Srinagar',
    'Panipat',
    'Sonipat',
    'Rohtak',
    'Hisar',
    'Karnal',
    'Ambala',
    'Shimla',
    'Manali',
    'Dharamshala',
    'Mangaluru',
    'Udupi',
    'Hassan',
    'Vizag',
    'Rajahmundry',
    'Nellore',
    'Tirupati',
    'Kurnool',
    'Tirupur',
    'Erode',
    'Vellore',
    'Pondicherry',
    'Bhavnagar',
    'Junagadh',
    'Porbandar',
    'Dwarka',
    'Surendranagar',
    'Bathinda',
    'Moga',
    'Firozpur',
    'Hoshiarpur',
    'Moradabad',
    'Bareilly',
    'Saharanpur',
    'Muzaffarnagar',
    'Mathura',
    'Vrindavan',
    'Srinagar',
    'Katra',
    'Pathankot',
    'Jammu',
    'Udhampur',
  ];

  // Get place suggestions for companies/establishments - every business on Google Maps
  static Future<List<Map<String, String>>> getCompanySuggestions(
      String query) async {
    if (query.length < 2) return [];
    if (AppConfig.googleMapsApiKey.isEmpty) return [];
    try {
      // Use both establishment type for companies AND geocode for areas
      final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=${Uri.encodeComponent(query)}'
          '&components=country:in'
          '&types=establishment'
          '&language=en'
          '&key=${AppConfig.googleMapsApiKey}';
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final preds = data['predictions'] as List? ?? [];
        return preds.take(10).map((p) {
          final desc = p['description'] as String? ?? '';
          final terms = p['terms'] as List? ?? [];
          // First term = company name, rest = address
          final name = terms.isNotEmpty
              ? (terms[0]['value'] as String? ?? desc.split(',').first.trim())
              : desc.split(',').first.trim();
          final location = terms.length > 1
              ? terms
                  .skip(1)
                  .map((t) => t['value'] as String? ?? '')
                  .where((s) => s.isNotEmpty)
                  .join(', ')
              : '';
          final placeId = p['place_id'] as String? ?? '';
          return {
            'name': name,
            'full': desc,
            'location': location,
            'placeId': placeId
          };
        }).toList();
      }
    } catch (_) {}
    return [];
  }

  // Removed unused _fallback method

  static Future<List<Map<String, String>>> getCitySuggestions(
      String query) async {
    if (query.length < 2) return [];
    // Always try Google Places first if API key is present
    if (AppConfig.googleMapsApiKey.isNotEmpty) {
      try {
        final url =
            'https://maps.googleapis.com/maps/api/place/autocomplete/json'
            '?input=${Uri.encodeComponent(query)}'
            '&components=country:in'
            '&types=(cities)'
            '&key=${AppConfig.googleMapsApiKey}';
        final res =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final preds = data['predictions'] as List? ?? [];
          if (preds.isNotEmpty) {
            return preds.take(8).map((p) {
              final desc = p['description'] as String? ?? '';
              final terms = p['terms'] as List? ?? [];
              final city = terms.isNotEmpty
                  ? (terms[0]['value'] as String? ?? '')
                  : desc.split(',').first.trim();
              // State is usually the 2nd-to-last term (before 'India')
              final state = terms.length >= 2
                  ? (terms[terms.length >= 3 ? terms.length - 2 : 1]['value']
                          as String? ??
                      '')
                  : '';
              final full = state.isNotEmpty ? '$city, $state' : city;
              return {
                'city': city,
                'state': state,
                'full': full,
                'placeId': p['place_id'] as String? ?? ''
              };
            }).toList();
          }
        }
      } catch (_) {}
    }
    // Local fallback - fast, always works
    final q = query.toLowerCase().trim();
    final matches = kIndianCities
        .where((c) =>
            c['city']!.toLowerCase().startsWith(q) ||
            c['city']!.toLowerCase().contains(q) ||
            (c['state'] ?? '').toLowerCase().contains(q))
        .toList();
    // Prioritize starts-with matches
    matches.sort((a, b) {
      final aStarts = a['city']!.toLowerCase().startsWith(q) ? 0 : 1;
      final bStarts = b['city']!.toLowerCase().startsWith(q) ? 0 : 1;
      return aStarts - bStarts;
    });
    return matches
        .take(8)
        .map((c) => {
              'city': c['city']!,
              'state': c['state']!,
              'full': c['full']!,
              'placeId': ''
            })
        .toList();
  }

  // Get place details (lat/lng) for distance matrix calls
  static Future<Map<String, double>?> getPlaceLatLng(String placeId) async {
    if (AppConfig.googleMapsApiKey.isEmpty || placeId.isEmpty) return null;
    try {
      final url = 'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=geometry'
          '&key=${AppConfig.googleMapsApiKey}';
      final res =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final loc = data['result']?['geometry']?['location'];
        if (loc != null) {
          return {
            'lat': (loc['lat'] as num).toDouble(),
            'lng': (loc['lng'] as num).toDouble()
          };
        }
      }
    } catch (_) {}
    return null;
  }
}

// ================================================================
// MATERIAL TYPES BY VEHICLE
// ================================================================
const Map<String, List<String>> kMaterialsByVehicleType = {
  'SS Tanker': [
    'Ethanol',
    'Methanol',
    'Acetic Acid',
    'Nitric Acid',
    'Sulphuric Acid',
    'Hydrochloric Acid',
    'Caustic Soda',
    'Chemical Solvents',
    'Acetone',
    'Toluene',
    'Xylene',
    'Liquid Nitrogen',
    'Ammonia Solution',
    'Hydrogen Peroxide',
    'Specialty Chemicals',
    'Refrigerant Gas R-22',
  ],
  'MS Tanker': [
    'HSD/Diesel',
    'Petrol/MS',
    'Furnace Oil',
    'LDO',
    'Palm Oil',
    'Crude Oil',
    'Bitumen/Tar',
    'Lubricating Oil',
    'Edible Oil (Bulk)',
    'Cashew/Vegetable Oil',
    'Glycerin',
    'Phenol',
  ],
  'Container': [
    'Automotive Parts',
    'Textiles & Garments',
    'Electronics & Components',
    'FMCG Goods',
    'Pharma Products (Packed)',
    'Machine Parts',
    'Export Cargo (General)',
    'Tractor Parts',
    'Auto Parts',
    'Tea / Coffee',
    'Cashew Nuts',
  ],
  'Open Truck': [
    'Steel/Iron Scrap',
    'TMT Bars',
    'Cement Bags',
    'Sand & Gravel',
    'Coal',
    'Agricultural Produce',
    'Marble / Granite Tiles',
    'Construction Material',
    'Fertilizers',
    'Iron Ore',
    'Wood / Timber',
    'Salt',
    'Bricks',
  ],
  'Trailer': [
    'Heavy Machinery',
    'Power Transformers',
    'Steel Coils',
    'Industrial Boilers',
    'Wind Turbine Blades',
    'Pre-cast Concrete',
    'Large Fabrications',
    'Reactor Vessels',
    'ODC / Abnormal Cargo',
  ],
  'LCV': [
    'Packages & Parcels',
    'Small Cargo',
    'Retail Goods',
    'E-commerce Parcels',
    'Office Supplies',
    'Spare Parts (Small)',
  ],
  'Reefer': [
    'Frozen Seafood',
    'Fresh Fruits & Vegetables',
    'Dairy Products',
    'Temperature-sensitive Pharma',
    'Ice Cream',
    'Meat & Poultry',
    'Flowers & Perishables',
  ],
};

List<String> getMaterialsForVehicle(String vehicleType) {
  for (final key in kMaterialsByVehicleType.keys) {
    if (vehicleType.toLowerCase().contains(key.toLowerCase().split(' ')[0])) {
      return kMaterialsByVehicleType[key]!;
    }
  }
  return kMaterialsByVehicleType.values.expand((e) => e).toList();
}

// ================================================================
// CROSS-USER SHARING SERVICE
// ================================================================
class CrossUserSharingService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Called when a fleet owner or driver creates/updates an LR.
  /// Pushes the load event to the consignor and fleet owner feeds.
  static Future<void> pushLoadEvent({
    required String ledgerId,
    required String vehicleNo,
    required String route,
    required String driverName,
    required String consignorPhone,
    required String
        status, // 'dispatched', 'in_transit', 'delivered', 'lr_posted'
    String? lrImageUrl,
    double freightAmount = 0,
    String materialName = '',
  }) async {
    if (!FirebaseService.isReady) return;
    try {
      final event = {
        'ledgerId': ledgerId,
        'vehicleNo': vehicleNo,
        'route': route,
        'driverName': driverName,
        'consignorPhone': consignorPhone,
        'status': status,
        'lrImageUrl': lrImageUrl ?? '',
        'freightAmount': freightAmount,
        'materialName': materialName,
        'timestamp': FieldValue.serverTimestamp(),
        'postedBy': FirebaseService.currentUser?.uid ?? 'local',
        'isRead': false,
      };
      await _db.collection('loadEvents').add(event);
      await _db
          .collection('vehicleStatus')
          .doc(vehicleNo.replaceAll(RegExp(r'[^A-Za-z0-9]'), ''))
          .set({
        'vehicleNo': vehicleNo,
        'status': status,
        'isLoaded': status == 'dispatched' || status == 'in_transit',
        'route': route,
        'driverName': driverName,
        'lastUpdated': FieldValue.serverTimestamp(),
        'ledgerId': ledgerId,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('CrossUserSharing error: $e');
    }
  }

  static Stream<QuerySnapshot> loadEventsStream(String consignorPhone) {
    if (!FirebaseService.isReady) return const Stream.empty();
    return _db
        .collection('loadEvents')
        .where('consignorPhone', isEqualTo: consignorPhone)
        .orderBy('timestamp', descending: true)
        .limit(30)
        .snapshots();
  }

  static Stream<DocumentSnapshot?> vehicleStatusStream(String vehicleNo) {
    if (!FirebaseService.isReady) return const Stream.empty();
    return _db
        .collection('vehicleStatus')
        .doc(vehicleNo.replaceAll(RegExp(r'[^A-Za-z0-9]'), ''))
        .snapshots()
        .map((e) => e.exists ? e : null);
  }
}

// ================================================================
// AI ENGINE - ALL 5 MODULES
// ================================================================

// ── AI Data Models ──────────────────────────────────────────────
