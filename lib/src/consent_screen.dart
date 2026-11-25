// ============================================================
// consent_screen.dart  —  part of liquid_logistics main library
// Add as NEW file at:  lib/src/consent_screen.dart
// Register in main.dart with:  part 'src/consent_screen.dart';
// ------------------------------------------------------------
// A DPDP-style first-run consent gate. Shows once (per policy version).
// If consent already given, it forwards straight to MainShell.
// ============================================================
part of 'package:liquid_logistics/main.dart';

class ConsentGate extends StatefulWidget {
  const ConsentGate({super.key});
  @override
  State<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends State<ConsentGate> {
  bool _checking = true;
  bool _agreeCore = false; // required: account + ledger data
  bool _agreeLocation = false; // optional: live tracking / routing
  bool _agreeDocuments = false; // optional: KYC document storage
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final ok = await PrivacyService.hasValidConsent();
    if (!mounted) return;
    if (ok) {
      final locationConsent = await PrivacyService.hasLocationConsent();
      if (!mounted) return;
      // Already consented — complete the one-time location setup if needed.
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) => FirstLoginLocationGate(
                  locationConsentGranted: locationConsent)));
    } else {
      setState(() => _checking = false);
    }
  }

  Future<void> _accept() async {
    if (!_agreeCore) return;
    setState(() => _saving = true);
    await PrivacyService.recordConsent(
      location: _agreeLocation,
      documents: _agreeDocuments,
      notifications: true,
    );
    if (!mounted) return;
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) => FirstLoginLocationGate(
                locationConsentGranted: _agreeLocation)));
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF6FAFF),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              const Text('Your Privacy',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'NavGati processes your data to run your transport '
                'business. Please review and choose what you agree to. '
                'You can change these later in Settings.',
                style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    _tile(
                      title: 'Account & business data (required)',
                      subtitle:
                          'Your profile, ledgers, drivers and fleet records, '
                          'stored securely to operate the app.',
                      value: _agreeCore,
                      onChanged: (v) => setState(() => _agreeCore = v),
                    ),
                    _tile(
                      title: 'Location & routing (optional)',
                      subtitle:
                          'Live tracking and automatic route calculation. '
                          'If enabled, you will be asked once to confirm your '
                          'current location during setup. Turn off to skip GPS.',
                      value: _agreeLocation,
                      onChanged: (v) => setState(() => _agreeLocation = v),
                    ),
                    _tile(
                      title: 'KYC documents (optional)',
                      subtitle: 'Store driver ID documents (Aadhaar, licence). '
                          'These are encrypted before upload.',
                      value: _agreeDocuments,
                      onChanged: (v) => setState(() => _agreeDocuments = v),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'You have the right to access or delete your data at '
                      'any time from Settings. Required data is the minimum '
                      'needed to provide the service.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_agreeCore && !_saving) ? _accept : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Agree & Continue',
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 6),
              if (!_agreeCore)
                const Center(
                  child: Text(
                    'Account & business data consent is required to continue.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
                  ),
                ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class FirstLoginLocationGate extends StatefulWidget {
  final bool locationConsentGranted;

  const FirstLoginLocationGate({
    super.key,
    required this.locationConsentGranted,
  });

  @override
  State<FirstLoginLocationGate> createState() => _FirstLoginLocationGateState();
}

class _FirstLoginLocationGateState extends State<FirstLoginLocationGate> {
  bool _checking = true;
  bool _loading = false;
  ({double latitude, double longitude})? _position;
  String? _locationName;
  String? _errorMessage;
  String? _setupKey;

  @override
  void initState() {
    super.initState();
    _checkFirstLogin();
  }

  Future<void> _checkFirstLogin() async {
    if (!widget.locationConsentGranted) {
      _openApp();
      return;
    }
    final uid = FirebaseService.currentUser?.uid;
    if (uid == null) {
      _openApp();
      return;
    }
    _setupKey = 'ng_location_setup_$uid';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_setupKey!) != null) {
      _openApp();
      return;
    }
    if (mounted) setState(() => _checking = false);
  }

  Future<void> _captureLocation() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _position = null;
      _locationName = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const _LocationSetupException(
            'Turn on your device location services, then try again.');
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const _LocationSetupException(
            'Location permission was denied. Allow it to confirm your current location.');
      }
      if (permission == LocationPermission.deniedForever) {
        throw const _LocationSetupException(
            'Location permission is blocked. Enable it in app settings or continue without confirming.');
      }

      final fix = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final position = (
        latitude: double.parse(fix.latitude.toStringAsFixed(2)),
        longitude: double.parse(fix.longitude.toStringAsFixed(2)),
      );
      String? placeName;
      try {
        final places = await Geocoding().placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (places.isNotEmpty) {
          final place = places.first;
          final parts = [
            place.name,
            place.subLocality,
            place.locality,
            place.administrativeArea,
            place.country,
          ]
              .whereType<String>()
              .map((part) => part.trim())
              .where((part) => part.isNotEmpty)
              .toSet();
          if (parts.isNotEmpty) placeName = parts.join(', ');
        }
      } catch (e) {
        debugPrint(
            'Reverse geocoding unavailable for first-login location: $e');
      }
      if (!mounted) return;
      setState(() {
        _position = position;
        _locationName = placeName;
        _loading = false;
      });
    } on _LocationSetupException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.message;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage =
            'Location lookup timed out. Check your signal and try again.';
      });
    } catch (e) {
      debugPrint('First-login location lookup failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage =
            'Could not confirm your location. Check device permissions and try again.';
      });
    }
  }

  Future<void> _confirmLocation() async {
    final position = _position;
    final setupKey = _setupKey;
    if (position == null || setupKey == null) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await SecureStore.write(
          'ng_location_lat_$setupKey', position.latitude.toString());
      await SecureStore.write(
          'ng_location_lon_$setupKey', position.longitude.toString());
      await SecureStore.write(
          'ng_location_name_$setupKey', _locationName ?? 'Current location');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(setupKey, 'confirmed');
      _openApp();
    } catch (e) {
      debugPrint('Could not securely save the confirmed location: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage =
            'Could not save your confirmed location securely. Try again or continue without saving it.';
      });
    }
  }

  Future<void> _continueWithoutLocation() async {
    final setupKey = _setupKey;
    if (setupKey != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(setupKey, 'skipped');
    }
    _openApp();
  }

  void _openApp() {
    if (!mounted) return;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const MainShell()));
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF071426),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF071426),
      body: Stack(
        children: [
          Positioned(
            top: -110,
            right: -100,
            child: _locationGlow(const Color(0xFF0EA5E9), 300),
          ),
          Positioned(
            bottom: -130,
            left: -100,
            child: _locationGlow(const Color(0xFFF59E0B), 270),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF102943).withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.24),
                          blurRadius: 36,
                          offset: const Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                const Color(0xFF38BDF8).withValues(alpha: 0.14),
                          ),
                          child: const Icon(Icons.location_on_rounded,
                              color: Color(0xFF38BDF8), size: 34),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Confirm your location',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'On your first sign-in, NavGati can use a low-accuracy location to confirm your approximate area. Coordinates are rounded to roughly 1 km before display, lookup, or on-device storage. You can skip this step.',
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Color(0xFFB7C7D9), height: 1.5),
                        ),
                        if (_position != null) ...[
                          const SizedBox(height: 22),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF071426)
                                  .withValues(alpha: 0.62),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: const Color(0xFF38BDF8)
                                      .withValues(alpha: 0.35)),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.my_location_rounded,
                                    color: Color(0xFF38BDF8)),
                                const SizedBox(height: 8),
                                Text(
                                  _locationName ?? 'Current device location',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Approximate area only · about 1 km',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFFB7C7D9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Color(0xFFFCA5A5), height: 1.4),
                          ),
                          if (awaitingLocationSettings)
                            TextButton(
                              onPressed: Geolocator.openAppSettings,
                              child: const Text('Open app settings'),
                            ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _loading
                                ? null
                                : _position == null
                                    ? _captureLocation
                                    : _confirmLocation,
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : Icon(_position == null
                                    ? Icons.gps_fixed_rounded
                                    : Icons.check_rounded),
                            label: Text(_loading
                                ? 'Checking location...'
                                : _position == null
                                    ? 'Use current location'
                                    : 'Confirm this location'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loading ? null : _continueWithoutLocation,
                          child: const Text(
                            'Continue without confirming',
                            style: TextStyle(color: Color(0xFFB7C7D9)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get awaitingLocationSettings =>
      _errorMessage?.contains('blocked') ?? false;

  Widget _locationGlow(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.2), Colors.transparent],
          ),
        ),
      );
}

class _LocationSetupException implements Exception {
  final String message;

  const _LocationSetupException(this.message);
}

// ============================================================
// PrivacySettingsScreen — user-facing data rights (DPDP Section 9)
// Reached from Settings → "Privacy & Your Data".
// Lets the user export their data or delete their account.
// ============================================================
class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});
  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    final data = await PrivacyService.exportMyData();
    setState(() => _busy = false);
    if (!mounted) return;
    final pretty = const JsonEncoder.withIndent('  ').convert(data);
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Your Data'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(pretty,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: pretty));
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')));
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
          SizedBox(width: 10),
          Text('Delete Account'),
        ]),
        content: const Text(
          'This permanently deletes your account and personal data. '
          'Financial records we are legally required to keep may be retained. '
          'This cannot be undone. Are you sure?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    final done = await PrivacyService.deleteMyAccountAndData();
    if (!mounted) return;
    setState(() => _busy = false);
    if (done) {
      Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not delete account. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & Your Data')),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'You control your personal data. Under the Digital Personal '
                  'Data Protection Act, you may access a copy of your data or '
                  'delete your account at any time.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 24),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Export my data'),
                  subtitle:
                      const Text('See and copy a copy of the data we hold.'),
                  onTap: _export,
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded,
                      color: Color(0xFFDC2626)),
                  title: const Text('Delete my account & data',
                      style: TextStyle(color: Color(0xFFDC2626))),
                  subtitle: const Text('Permanently remove your account.'),
                  onTap: _confirmDelete,
                ),
              ],
            ),
    );
  }
}
