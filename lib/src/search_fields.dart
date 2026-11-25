// ============================================================
// search_fields.dart  —  part of liquid_logistics main library
// Auto-extracted from main_v23_8.dart (original lines 19788-20309)
// DO NOT add imports here — all imports live in main.dart
// ============================================================
part of 'package:liquid_logistics/main.dart';

class FactorySearchField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final Color iconColor;
  final Function(String name, String placeId) onSelected;
  const FactorySearchField({
    super.key,
    this.controller,
    required this.label,
    required this.iconColor,
    required this.onSelected,
  });
  @override
  State<FactorySearchField> createState() => _FactorySearchFieldState();
}

class _FactorySearchFieldState extends State<FactorySearchField> {
  late TextEditingController _ctrl;
  final FocusNode _focus = FocusNode();
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlay;
  Timer? _deb;
  bool _selecting = false;
  bool _loading = false;
  List<_PlaceResult> _results = [];

  // ── Well-known Indian industrial facilities (offline fallback) ──
  static const List<Map<String, String>> _kFallback = [
    {'n': 'Reliance Industries – Jamnagar Refinery', 'a': 'Jamnagar, Gujarat'},
    {
      'n': 'Reliance Industries – Hazira Complex',
      'a': 'Hazira, Surat, Gujarat',
    },
    {'n': 'IOCL Koyali Refinery', 'a': 'Vadodara, Gujarat'},
    {'n': 'IOCL Mathura Refinery', 'a': 'Mathura, Uttar Pradesh'},
    {'n': 'IOCL Panipat Refinery', 'a': 'Panipat, Haryana'},
    {'n': 'BPCL Mahul Terminal', 'a': 'Mumbai, Maharashtra'},
    {'n': 'HPCL Vishakh Refinery', 'a': 'Visakhapatnam, Andhra Pradesh'},
    {'n': 'Nayara Energy Vadinar', 'a': 'Jamnagar, Gujarat'},
    {'n': 'ONGC Hazira Plant', 'a': 'Hazira, Gujarat'},
    {'n': 'Deepak Nitrite Ltd – Dahej', 'a': 'Dahej, Gujarat'},
    {'n': 'Deepak Fertilisers Taloja', 'a': 'Navi Mumbai, Maharashtra'},
    {'n': 'Gujarat Fluorochemicals Ltd', 'a': 'Vadodara, Gujarat'},
    {'n': 'Tata Chemicals Mithapur', 'a': 'Dwarka, Gujarat'},
    {'n': 'Aarti Industries Vapi', 'a': 'Vapi, Gujarat'},
    {'n': 'UPL Ltd Ankleshwar', 'a': 'Ankleshwar, Gujarat'},
    {'n': 'Adani Wilmar Mundra', 'a': 'Mundra Port, Gujarat'},
    {'n': 'Adani Ports Hazira', 'a': 'Hazira, Gujarat'},
    {'n': 'Mundra Port Container Terminal', 'a': 'Mundra Port, Gujarat'},
    {'n': 'Kandla Port Trust', 'a': 'Kandla, Gujarat'},
    {'n': 'Dahej Port Authority', 'a': 'Dahej, Gujarat'},
    {'n': 'JNPT (Nhava Sheva)', 'a': 'Navi Mumbai, Maharashtra'},
    {'n': 'Haldia Petrochemicals Ltd', 'a': 'Haldia Port, West Bengal'},
    {'n': 'Vizag Steel Plant', 'a': 'Visakhapatnam, Andhra Pradesh'},
    {'n': 'Bhilai Steel Plant', 'a': 'Durg, Chhattisgarh'},
    {'n': 'Tata Steel Jamshedpur', 'a': 'Jamshedpur, Jharkhand'},
    {'n': 'BPCL Bina Refinery', 'a': 'Sagar, Madhya Pradesh'},
    {'n': 'HMEL Bathinda Refinery', 'a': 'Bathinda, Punjab'},
    {'n': 'Mangalore Refinery MRPL', 'a': 'Mangaluru, Karnataka'},
    {'n': 'Chennai Petroleum CPCL', 'a': 'Chennai, Tamil Nadu'},
    {'n': 'BASF India Ltd – Dahej', 'a': 'Dahej, Gujarat'},
    {'n': 'Linde India Ltd – Hazira', 'a': 'Hazira, Gujarat'},
    {'n': 'Sun Pharma – Halol', 'a': 'Halol, Gujarat'},
    {'n': 'Torrent Pharma – Ahmedabad', 'a': 'Ahmedabad, Gujarat'},
    {'n': 'Gujarat Narmada Valley Fertilizers', 'a': 'Bharuch, Gujarat'},
    {'n': 'Hindustan Petroleum Terminal', 'a': 'Mahul, Mumbai'},
    {'n': 'UltraTech Cement – Nathdwara', 'a': 'Rajsamand, Rajasthan'},
    {'n': 'Dalmia Bharat Cement', 'a': 'Dalmiapuram, Tamil Nadu'},
    {'n': 'ACC Cement Gagal', 'a': 'Bilaspur, Himachal Pradesh'},
    {'n': 'Ambuja Cement Darlaghat', 'a': 'Solan, Himachal Pradesh'},
    {'n': 'Nagarjuna Fertilizers', 'a': 'Kakinada, Andhra Pradesh'},
    {'n': 'Coromandel International', 'a': 'Visakhapatnam, Andhra Pradesh'},
    {'n': 'NTPC Sipat Thermal Plant', 'a': 'Raipur, Chhattisgarh'},
    {'n': 'Lupin Ltd – Ankleshwar', 'a': 'Ankleshwar, Gujarat'},
    {'n': 'JK Cement Mangrol', 'a': 'Mangrol, Rajasthan'},
    {'n': 'Essar Oil Terminal Vadinar', 'a': 'Jamnagar, Gujarat'},
    {'n': 'Numaligarh Refinery', 'a': 'Golaghat, Assam'},
    {'n': 'Air Products India – Vadodara', 'a': 'Vadodara, Gujarat'},
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? TextEditingController();
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), _rmOverlay);
      }
    });
  }

  @override
  void dispose() {
    _rmOverlay();
    _deb?.cancel();
    _focus.dispose();
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (_selecting) return;
    if (q.length < 2) {
      _rmOverlay();
      setState(() {
        _results = [];
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    // ── 1. Google Places Autocomplete ──────────────────────────────
    List<_PlaceResult> apiResults = [];
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(q)}'
        '&components=country:in'
        '&types=establishment'
        '&language=en'
        '&key=${AppConfig.googleMapsApiKey}',
      );
      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if ((data['status'] as String?) == 'OK') {
          final preds = data['predictions'] as List;
          apiResults = preds.take(8).map((p) {
            final desc = p['description'] as String? ?? '';
            final terms = p['terms'] as List? ?? [];
            final name = terms.isNotEmpty
                ? (terms[0]['value'] as String? ?? desc.split(',').first.trim())
                : desc.split(',').first.trim();
            final addr = terms.length > 1
                ? terms
                      .skip(1)
                      .map((t) => t['value'] as String? ?? '')
                      .where((s) => s.isNotEmpty)
                      .join(', ')
                : '';
            return _PlaceResult(
              name: name,
              address: addr,
              placeId: p['place_id'] as String? ?? '',
              fromApi: true,
            );
          }).toList();
        }
      }
    } catch (_) {}
    // ── 2. Offline fallback ────────────────────────────────────────
    if (apiResults.isEmpty) {
      final ql = q.toLowerCase();
      apiResults = _kFallback
          .where(
            (f) =>
                (f['n']!.toLowerCase().contains(ql) ||
                (f['a'] ?? '').toLowerCase().contains(ql)),
          )
          .take(8)
          .map(
            (f) => _PlaceResult(
              name: f['n']!,
              address: f['a'] ?? '',
              placeId: '',
              fromApi: false,
            ),
          )
          .toList();
    }
    if (!mounted) return;
    _results = apiResults;
    setState(() => _loading = false);
    if (_results.isEmpty) {
      _rmOverlay();
      return;
    }
    _rmOverlay();
    _showOverlay();
  }

  void _onChange(String v) {
    if (_selecting) return;
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 380), () => _search(v.trim()));
    setState(() {}); // redraw suffix icon
  }

  void _showOverlay() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    _overlay = OverlayEntry(
      builder: (_) {
        return Positioned(
          width: box.size.width,
          child: CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            offset: Offset(0, box.size.height + 6),
            child: Material(
              elevation: 16,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 320),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.iconColor.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: widget.iconColor.withValues(alpha: 0.06),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.location_searching_rounded,
                            color: widget.iconColor,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_results.length} location${_results.length == 1 ? '' : 's'} found',
                            style: TextStyle(
                              color: widget.iconColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          if (!_results.first.fromApi)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Offline',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Google Maps Live',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Results list
                    Flexible(
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _results.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: Colors.grey.shade100),
                        itemBuilder: (_, i) {
                          final r = _results[i];
                          return InkWell(
                            borderRadius: i == _results.length - 1
                                ? const BorderRadius.vertical(
                                    bottom: Radius.circular(15),
                                  )
                                : BorderRadius.zero,
                            onTap: () {
                              _selecting = true;
                              _rmOverlay();
                              _deb?.cancel();
                              _ctrl.text = r.name;
                              widget.onSelected(r.name, r.placeId);
                              _focus.unfocus();
                              setState(() {});
                              Future.delayed(
                                const Duration(milliseconds: 500),
                                () {
                                  if (mounted) _selecting = false;
                                },
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 11,
                              ),
                              child: Row(
                                children: [
                                  // Pin icon
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: widget.iconColor.withValues(
                                        alpha: 0.09,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      Icons.factory_rounded,
                                      color: widget.iconColor,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          r.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                            color: Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (r.address.isNotEmpty)
                                          Text(
                                            r.address,
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: widget.iconColor.withValues(
                                      alpha: 0.5,
                                    ),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Footer
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(15),
                        ),
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade100),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.network(
                            'https://maps.gstatic.com/mapfiles/api-3/images/powered-by-google-on-white3.png',
                            height: 14,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _rmOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = _ctrl.text.isNotEmpty;
    return CompositedTransformTarget(
      link: _link,
      child: TextField(
        controller: _ctrl,
        focusNode: _focus,
        onChanged: _onChange,
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: 'Type to search any factory, plant, depot...',
          hintStyle: const TextStyle(color: Color(0xFFB0BEC5), fontSize: 13),
          prefixIcon: _loading
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      color: widget.iconColor,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : Icon(Icons.factory_rounded, color: widget.iconColor, size: 20),
          suffixIcon: hasValue
              ? IconButton(
                  icon: const Icon(
                    Icons.cancel_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                  onPressed: () {
                    _ctrl.clear();
                    _rmOverlay();
                    setState(() {
                      _results = [];
                    });
                    widget.onSelected('', '');
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFFF8FAFF),
          labelStyle: TextStyle(
            color: widget.iconColor.withValues(alpha: 0.8),
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          floatingLabelStyle: TextStyle(
            color: widget.iconColor,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: widget.iconColor.withValues(alpha: 0.3),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: widget.iconColor.withValues(alpha: 0.4),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: widget.iconColor, width: 2.5),
          ),
        ),
      ),
    );
  }
}

// Internal model for place autocomplete results
class _PlaceResult {
  final String name, address, placeId;
  final bool fromApi;
  const _PlaceResult({
    required this.name,
    required this.address,
    required this.placeId,
    required this.fromApi,
  });
}

class CitySearchField extends StatefulWidget {
  final TextEditingController? controller;
  final String label, initialValue;
  final IconData icon;
  final Color iconColor;
  final Function(String city, String state, String placeId) onCitySelected;
  const CitySearchField({
    super.key,
    this.controller,
    required this.label,
    required this.icon,
    required this.iconColor,
    this.initialValue = "",
    required this.onCitySelected,
  });
  @override
  State<CitySearchField> createState() => _CitySearchFieldState();
}

class _CitySearchFieldState extends State<CitySearchField> {
  late TextEditingController _ctrl;
  final FocusNode _focus = FocusNode();
  OverlayEntry? _overlay;
  List<Map<String, String>> _sugg = [];
  Timer? _deb;
  final LayerLink _link = LayerLink();
  @override
  void initState() {
    super.initState();
    _ctrl = widget.controller ?? TextEditingController();
    if (widget.initialValue.isNotEmpty && _ctrl.text.isEmpty) {
      _ctrl.text = widget.initialValue;
    }
    // NO addListener - use onChanged in TextField so only user-typing triggers it
    _focus.addListener(() {
      if (!_focus.hasFocus) _removeOverlay();
    });
  }

  void _onUserTyped(String value) {
    // Only called when USER types - not when we set _ctrl.text programmatically
    if (_deb?.isActive ?? false) _deb!.cancel();
    final q = value.trim();
    if (q.length < 2) {
      _removeOverlay();
      return;
    }
    // Immediate local results for instant feedback
    final localQ = q.toLowerCase();
    final local = kIndianCities
        .where(
          (c) =>
              c['city']!.toLowerCase().startsWith(localQ) ||
              c['city']!.toLowerCase().contains(localQ) ||
              c['state']!.toLowerCase().contains(localQ),
        )
        .toList();
    local.sort((a, b) {
      final aS = a['city']!.toLowerCase().startsWith(localQ) ? 0 : 1;
      final bS = b['city']!.toLowerCase().startsWith(localQ) ? 0 : 1;
      return aS - bS;
    });
    if (local.isNotEmpty) {
      _sugg = local
          .take(10)
          .map(
            (c) => {
              'city': c['city']!,
              'state': c['state']!,
              'full': c['full']!,
              'placeId': '',
            },
          )
          .toList();
      _removeOverlay();
      _showOverlay();
    }
    // Then fetch Google Places in background for more complete results
    _deb = Timer(const Duration(milliseconds: 400), () async {
      final results = await RoutingEngine.getCitySuggestions(_ctrl.text.trim());
      if (!mounted || _ctrl.text.trim().length < 2) return;
      // Only update if user hasn't selected yet (overlay still open)
      if (results.isNotEmpty && _overlay != null) {
        _sugg = results;
        _overlay?.markNeedsBuild();
      }
    });
  }

  void _showOverlay() {
    final ctx = context;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final size = box.size;
    _overlay = OverlayEntry(
      builder: (_) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 260),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: _sugg.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade100),
                itemBuilder: (_, i) {
                  final s = _sugg[i];
                  return ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.iconColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.iconColor,
                        size: 14,
                      ),
                    ),
                    title: Text(
                      s['city'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    subtitle: (s['state'] ?? '').isNotEmpty
                        ? Text(
                            '${s["state"]}, India',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          )
                        : null,
                    trailing: Text(
                      s['state'] ?? '',
                      style: TextStyle(
                        fontSize: 10,
                        color: widget.iconColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {
                      _deb?.cancel();
                      _removeOverlay();
                      setState(() {
                        _ctrl.text =
                            s['full'] ??
                            '${s["city"] ?? ""}, ${s["state"] ?? ""}';
                      });
                      _focus.unfocus();
                      widget.onCitySelected(
                        s['city'] ?? '',
                        s['state'] ?? '',
                        s['placeId'] ?? '',
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(ctx).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  void dispose() {
    _removeOverlay();
    _deb?.cancel();
    _focus.dispose();
    if (widget.controller == null) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _link,
    child: TextField(
      controller: _ctrl,
      focusNode: _focus,
      onChanged: _onUserTyped,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: Icon(widget.icon, color: widget.iconColor, size: 20),
        suffixIcon: _ctrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 16),
                onPressed: () {
                  _ctrl.clear();
                  _removeOverlay();
                },
              )
            : Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: widget.iconColor, width: 2),
        ),
      ),
    ),
  );
}

// ================================================================
// TRIP DETAIL SCREEN
// ================================================================
class _LanguageSelectorWidget extends StatefulWidget {
  final VoidCallback onUpdate;
  const _LanguageSelectorWidget({required this.onUpdate});
  @override State<_LanguageSelectorWidget> createState() => _LanguageSelectorWidgetState();
}

class _LanguageSelectorWidgetState extends State<_LanguageSelectorWidget> {
  String _selected = 'en';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _selected = p.getString('rm_language') ?? 'en');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: context.cardColor, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFBFE7FF))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Select your preferred language for the app interface.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12, height: 1.5)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: AppConfig.supportedLanguages.entries.map((e) {
          final isSelected = _selected == e.key;
          return GestureDetector(
            onTap: () async {
              setState(() => _selected = e.key);
              final p = await SharedPreferences.getInstance();
              await p.setString('rm_language', e.key);
              widget.onUpdate();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Language set to ${e.value}.'),
                backgroundColor: const Color(0xFF0EA5E9),
                behavior: SnackBarBehavior.floating));
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0EA5E9).withValues(alpha: 0.12) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFFBFE7FF), width: isSelected ? 1.5 : 1)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (isSelected) ...[const Icon(Icons.check_rounded, size: 13, color: Color(0xFF0EA5E9)), const SizedBox(width: 4)],
                Text(e.value, style: TextStyle(
                  color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFF334155),
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  fontSize: 12)),
              ]),
            ),
          );
        }).toList()),
      ]),
    );
  }
}
