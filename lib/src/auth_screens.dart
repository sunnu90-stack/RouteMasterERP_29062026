// ============================================================
// auth_screens.dart  —  part of liquid_logistics main library
// Auto-extracted from main_v23_8.dart (original lines 6814-8348)
// DO NOT add imports here — all imports live in main.dart
// ============================================================
part of 'package:liquid_logistics/main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _ambient;
  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..forward();
    _ambient = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600))
      ..repeat();
    Timer(const Duration(seconds: 3), () async {
      if (!mounted) return;
      // Primary: check Firebase auth state (handles token expiry correctly)
      final firebaseUser = FirebaseService.currentUser;
      final prefs = await SharedPreferences.getInstance();
      final sessionActive = prefs.getBool('rm_session_active') ?? false;
      // Logged in if Firebase says so OR if session was active and Firebase not initialized
      // Firebase auth token is persistent - if currentUser != null, user is logged in
      // sessionActive is a backup for when Firebase isn't initialized
      final isLoggedIn =
          (firebaseUser != null) || (sessionActive && !FirebaseService.isReady);
      // If session was marked active but Firebase says no user, clear stale session
      if (!isLoggedIn && sessionActive) {
        await prefs.setBool('rm_session_active', false);
      }
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (_) =>
                  isLoggedIn ? const ConsentGate() : const LoginScreen()));
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UniversalScaffold(
      body: Stack(children: [
        Positioned.fill(
            child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF070B11), Color(0xFF0A131D), Color(0xFF14212D)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        )),
        AnimatedBuilder(
          animation: _ambient,
          builder: (context, child) {
            final progress = _ambient.value;
            return Stack(children: [
              Positioned(
                top: -100 + 24 * math.sin(progress * 2 * math.pi),
                right: -90 + 28 * math.cos(progress * 2 * math.pi),
                child: _splashGlow(const Color(0xFF58C9BF), 310),
              ),
              Positioned(
                bottom: -110 + 18 * math.cos(progress * 2 * math.pi),
                left: -70 + 24 * math.sin(progress * 2 * math.pi),
                child: _splashGlow(const Color(0xFFC9A66B), 260),
              ),
            ]);
          },
        ),
        Center(
            child: FadeTransition(
          opacity: CurvedAnimation(parent: _intro, curve: Curves.easeOut),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            ScaleTransition(
              scale: CurvedAnimation(parent: _intro, curve: Curves.elasticOut),
              child: _buildLogo(),
            ),
            const SizedBox(height: 32),
            const Text("NAVGATI",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 7)),
            const SizedBox(height: 6),
            const Text("TRANSPORT ERP",
                style: TextStyle(
                    color: Color(0xFF0EA5E9),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4)),
            const SizedBox(height: 4),
            const Text("India's Intelligent Fleet Platform",
                style: TextStyle(
                    color: Color(0xFFB7C7D9),
                    fontSize: 11,
                    letterSpacing: 0.3)),
            const SizedBox(height: 48),
            SizedBox(
              width: 220,
              height: 34,
              child: AnimatedBuilder(
                animation: _ambient,
                builder: (context, _) => Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: const Color(0xFF9BB2C9).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Align(
                      alignment: Alignment(-1 + 2 * _ambient.value, 0),
                      child: Container(
                        width: 38,
                        height: 30,
                        decoration: BoxDecoration(
                          color: const Color(0xFF102943),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0EA5E9)
                                  .withValues(alpha: 0.38),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_shipping_rounded,
                          size: 19,
                          color: Color(0xFF38BDF8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text("MOVING YOUR BUSINESS FORWARD",
                style: TextStyle(
                    color: Color(0xFFB7C7D9),
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2)),
          ]),
        )),
        Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _intro, curve: Curves.easeIn),
              child: const Column(children: [
                Text("Powered by Route Master Technologies",
                    style: TextStyle(
                        color: Color(0xFFB7C7D9),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5)),
              ]),
            )),
      ]),
    );
  }

  Widget _splashGlow(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            color.withValues(alpha: 0.24),
            color.withValues(alpha: 0.07),
            Colors.transparent,
          ]),
        ),
      );

  Widget _buildLogo() => AnimatedBuilder(
        animation: _ambient,
        builder: (context, _) {
          final phase = _ambient.value * 2 * math.pi;
          return SizedBox(
            width: 138,
            height: 138,
            child: Stack(alignment: Alignment.center, children: [
              Transform.rotate(
                angle: phase * 0.08,
                child: Container(
                  width: 132,
                  height: 132,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF58C9BF).withValues(alpha: 0.3),
                        width: 1),
                  ),
                ),
              ),
              Transform.rotate(
                angle: -phase * 0.12,
                child: Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFFC9A66B).withValues(alpha: 0.55),
                        width: 1.5),
                  ),
                ),
              ),
              Transform.scale(
                scale: 1 + math.sin(phase) * 0.025,
                child: Container(
                  width: 94,
                  height: 94,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF102943),
                    border: Border.all(
                        color: const Color(0xFF58C9BF).withValues(alpha: 0.45),
                        width: 2),
                    boxShadow: [
                      BoxShadow(
                          color:
                              const Color(0xFFC9A66B).withValues(alpha: 0.16),
                          blurRadius: 30,
                          spreadRadius: 4),
                      BoxShadow(
                          color: const Color(0xFF58C9BF).withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 2),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _NavgatiMarkPainter(progress: _ambient.value),
                    size: const Size(54, 54),
                  ),
                ),
              ),
              Positioned(
                bottom: 14,
                right: 9,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9A66B),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFFC9A66B).withValues(alpha: 0.4),
                          blurRadius: 10)
                    ],
                  ),
                  child: const Text("NG",
                      style: TextStyle(
                          color: Color(0xFF071426),
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1)),
                ),
              ),
            ]),
          );
        },
      );
}

// ================================================================
// LOGIN
// ================================================================

// ================================================================
// REGISTRATION / KYC SCREEN - first-time onboarding
// ================================================================
// Helper widget for registration type tags
class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip(this.label);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF0EA5E9),
              fontWeight: FontWeight.w600)));
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  int _step = 0; // 0=userType, 1=company, 2=docs, 3=bank
  bool _saving = false;
  AppUserType _userType = AppUserType.fleetOwner;

  // Company info
  final _company = TextEditingController();
  final _ownerName = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _gst = TextEditingController();
  final _pan = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  String _fleetType = 'Tanker';
  String _fleetSize = '1-5';
  // Google Places derived address
  String _selectedCity = '', _selectedState = '';

  // Bank
  final _bankName = TextEditingController();
  final _accNo = TextEditingController();
  final _ifsc = TextEditingController();
  final _branch = TextEditingController();

  // Docs uploaded flags
  bool _gstUploaded = false,
      _panUploaded = false,
      _rcUploaded = false,
      _udyamUploaded = false,
      _cancelledChequeUploaded = false;

  Widget _field(TextEditingController ctrl, String label,
          {TextInputType? kb, String? hint, bool required = true}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: ctrl,
          keyboardType: kb,
          style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 15,
              fontWeight: FontWeight.w500),
          cursorColor: const Color(0xFF0F172A),
          decoration: InputDecoration(
            labelText: required ? "$label *" : label,
            labelStyle: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 14,
                fontWeight: FontWeight.w500),
            floatingLabelStyle: const TextStyle(
                color: Color(0xFF0EA5E9),
                fontWeight: FontWeight.w800,
                fontSize: 12),
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF6FAFF),
            contentPadding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0EA5E9))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF0EA5E9))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF0EA5E9), width: 2)),
          ),
        ),
      );

  Widget _docTile(
          String name, String desc, bool uploaded, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: uploaded
                ? Colors.green.withValues(alpha: 0.1)
                : const Color(0xFFF6FAFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: uploaded
                    ? Colors.green.withValues(alpha: 0.4)
                    : const Color(0xFF0EA5E9)),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: uploaded
                    ? Colors.green.withValues(alpha: 0.18)
                    : const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                  uploaded ? Icons.check_circle : Icons.upload_file_rounded,
                  color: uploaded ? Colors.green : const Color(0xFF0EA5E9),
                  size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: uploaded
                              ? const Color(0xFF0F172A)
                              : const Color(0xFF0F172A))),
                  Text(desc,
                      style: const TextStyle(
                          color: Color(0xFF334155), fontSize: 11)),
                ])),
            Text(uploaded ? "Uploaded OK" : "Tap to upload",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: uploaded ? Colors.green : const Color(0xFF0EA5E9))),
          ]),
        ),
      );

  Future<void> _uploadDoc(String docName, Function(bool) onDone) async {
    try {
      final img = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (img != null) {
        onDone(true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            content: Text("$docName uploaded successfully")));
      }
    } catch (_) {
      try {
        final file = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
        if (file != null) {
          onDone(true);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              content: Text("$docName uploaded successfully")));
        }
      } catch (_) {
        onDone(true); // simulate for demo
      }
    }
  }

  Future<void> _saveAndContinue() async {
    // Step 0=userType, 1=company, 2=docs, 3=bank
    if (_step < 3) {
      setState(() => _step++);
      return;
    }
    setState(() => _saving = true);
    try {
      final profile = UserProfile(
        companyName: _company.text.isEmpty ? "My Company" : _company.text,
        phone: _phone.text,
        email: _email.text,
        gstin: _gst.text,
        panNumber: _pan.text,
        address:
            '${_address.text}, ${_selectedCity.isNotEmpty ? _selectedCity : _city.text}, ${_selectedState.isNotEmpty ? _selectedState : _state.text} ${_pincode.text}'
                .trim(),
        bankName: _bankName.text,
        bankAccount: _accNo.text,
        bankIfsc: _ifsc.text,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fm_profile', jsonEncode(profile.toJson()));
      await prefs.setBool('rm_registration_done', true);
      await prefs.setString('rm_user_type',
          _userType == AppUserType.fleetOwner ? 'fleetOwner' : 'consignor');
      // Save to Firestore so the profile is available on all devices
      FirebaseService.saveProfile(profile.toJson()).ignore();
      if (!mounted) return;
      // If registration was opened on top of another screen (e.g. from the
      // booking flow), return to it. Otherwise (opened at login) go forward.
      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      } else {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const ConsentGate()));
      }
    } catch (_) {
      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context, true);
        } else {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const ConsentGate()));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = ["Who Are You?", "Company Info", "Documents", "Bank Details"];
    return UniversalScaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0EA5E9),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Complete Your Profile",
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: Color(0xFF0F172A))),
          Text("Step ${_step + 1} of 4 - ${steps[_step]}",
              style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushReplacement(context,
                MaterialPageRoute(builder: (_) => const ConsentGate())),
            child: const Text("Skip for now",
                style: TextStyle(color: Color(0xFF334155), fontSize: 12)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: (_step + 1) / 4,
            backgroundColor: const Color(0xFFFFF0D5),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0EA5E9)),
          ),
        ),
      ),
      body: SafeArea(
          child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_step == 0) ...[
            const SizedBox(height: 10),
            const Text("I am a...",
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 6),
            const Text("Select your role to customise your experience",
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            const SizedBox(height: 32),
            // Fleet Owner card
            GestureDetector(
              onTap: () => setState(() => _userType = AppUserType.fleetOwner),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: _userType == AppUserType.fleetOwner
                        ? const Color(0xFF0EA5E9).withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: _userType == AppUserType.fleetOwner
                            ? const Color(0xFF0EA5E9)
                            : const Color(0xFFCBD5E1),
                        width:
                            _userType == AppUserType.fleetOwner ? 2.5 : 1.5)),
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: _userType == AppUserType.fleetOwner
                              ? const Color(0xFF0EA5E9)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.local_shipping_rounded,
                          color: _userType == AppUserType.fleetOwner
                              ? Colors.white
                              : const Color(0xFF64748B),
                          size: 30)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text("Fleet Owner",
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: Color(0xFF0F172A))),
                        const Text(
                            "I own trucks / tankers and manage transport operations",
                            style: TextStyle(
                                color: Color(0xFF64748B), fontSize: 12)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, children: const [
                          _TagChip("Fleet Management"),
                          _TagChip("Dispatch LR"),
                          _TagChip("Driver Payroll"),
                        ]),
                      ])),
                  if (_userType == AppUserType.fleetOwner)
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF0EA5E9), size: 28),
                ]),
              ),
            ),
            // Consignor card
            GestureDetector(
              onTap: () => setState(() => _userType = AppUserType.consignor),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: _userType == AppUserType.consignor
                        ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: _userType == AppUserType.consignor
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFCBD5E1),
                        width: _userType == AppUserType.consignor ? 2.5 : 1.5)),
                child: Row(children: [
                  Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          color: _userType == AppUserType.consignor
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14)),
                      child: Icon(Icons.business_rounded,
                          color: _userType == AppUserType.consignor
                              ? Colors.white
                              : const Color(0xFF64748B),
                          size: 30)),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text("Consignor / Shipper",
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: Color(0xFF0F172A))),
                        const Text(
                            "I ship goods and need to track loads & consignments",
                            style: TextStyle(
                                color: Color(0xFF64748B), fontSize: 12)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, children: const [
                          _TagChip("Post Loads"),
                          _TagChip("Track Shipments"),
                          _TagChip("Invoice Tracking"),
                        ]),
                      ])),
                  if (_userType == AppUserType.consignor)
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFFF59E0B), size: 28),
                ]),
              ),
            ),
          ] else if (_step == 1) ...[
            const Text("Company & Owner Details",
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF0F172A))),
            const Text("Used on LR, Invoice, and all official documents",
                style: TextStyle(color: Color(0xFF334155), fontSize: 12)),
            const SizedBox(height: 20),
            _field(_company, "Company / Firm Name",
                hint: "e.g. Mahek Logistics Pvt. Ltd."),
            _field(_ownerName, "Owner / Proprietor Name"),
            _field(_phone, "Mobile Number",
                kb: TextInputType.phone, hint: "+91 XXXXX XXXXX"),
            _field(_email, "Email Address",
                kb: TextInputType.emailAddress, required: false),
            _field(_gst, "GSTIN", hint: "27AAAAA0000A1Z5", required: false),
            _field(_pan, "PAN Number", hint: "AAAAA0000A", required: false),
            _field(_address, "Street / Building / Area"),
            const Text("City & State",
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 6),
            CitySearchField(
              label: "Search City",
              icon: Icons.location_city,
              iconColor: const Color(0xFF0EA5E9),
              onCitySelected: (city, state, pid) => setState(() {
                _selectedCity = city;
                _selectedState = state;
                _city.text = city;
                _state.text = state;
              }),
            ),
            if (_selectedCity.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6, left: 4, bottom: 8),
                child: Row(children: [
                  const Icon(Icons.check_circle,
                      color: Color(0xFF10B981), size: 14),
                  const SizedBox(width: 6),
                  Text("$_selectedCity, $_selectedState",
                      style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            _field(_pincode, "Pincode",
                kb: TextInputType.number, required: false),

            // Fleet type & size — only for fleet owners, not consignors
            if (_userType == AppUserType.fleetOwner) ...[
              const SizedBox(height: 8),
              const Text("Fleet Type",
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 8),
              Wrap(
                  spacing: 8,
                  children: ['Tanker', 'Container', 'Truck', 'Trailer', 'Mixed']
                      .map((t) => GestureDetector(
                            onTap: () => setState(() => _fleetType = t),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: _fleetType == t
                                    ? const Color(0xFF0EA5E9)
                                    : const Color(0xFFF6FAFF),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: _fleetType == t
                                        ? const Color(0xFF0EA5E9)
                                        : const Color(0xFF0EA5E9)),
                              ),
                              child: Text(t,
                                  style: TextStyle(
                                      color: _fleetType == t
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFF334155),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                            ),
                          ))
                      .toList()),
              const SizedBox(height: 8),
              const Text("Fleet Size",
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 8),
              Wrap(
                  spacing: 8,
                  children: ['1-5', '6-15', '16-50', '50+']
                      .map((s) => GestureDetector(
                            onTap: () => setState(() => _fleetSize = s),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: _fleetSize == s
                                    ? const Color(0xFF0EA5E9)
                                    : const Color(0xFFF6FAFF),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: _fleetSize == s
                                        ? const Color(0xFF0EA5E9)
                                        : const Color(0xFF0EA5E9)),
                              ),
                              child: Text(s,
                                  style: TextStyle(
                                      color: _fleetSize == s
                                          ? const Color(0xFF0F172A)
                                          : const Color(0xFF334155),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                            ),
                          ))
                      .toList()),
            ], // end fleet owner only section
          ] else if (_step == 2) ...[
            const Text("Business Documents",
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF0F172A))),
            const Text("Required for KredX financing and platform verification",
                style: TextStyle(color: Color(0xFF334155), fontSize: 12)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: const Color(0xFFF6FAFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF0EA5E9).withValues(alpha: 0.3))),
              child: Row(children: [
                Icon(Icons.info_outline,
                    color: const Color(0xFF0EA5E9), size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        "All documents are stored securely. JPG, PNG and PDF accepted. Max 10MB per file.",
                        style: TextStyle(
                            color: const Color(0xFF334155), fontSize: 11)))
              ]),
            ),
            _docTile(
                "GST Certificate",
                "Business registration proof",
                _gstUploaded,
                () => _uploadDoc("GST Certificate",
                    (v) => setState(() => _gstUploaded = v))),
            _docTile(
                "PAN Card",
                "Company or proprietor PAN",
                _panUploaded,
                () => _uploadDoc(
                    "PAN Card", (v) => setState(() => _panUploaded = v))),
            _docTile(
                "RC Book (Sample)",
                "Any one vehicle RC for verification",
                _rcUploaded,
                () => _uploadDoc(
                    "RC Book", (v) => setState(() => _rcUploaded = v))),
            _docTile(
                "Udyam / MSME Certificate",
                "If registered (optional)",
                _udyamUploaded,
                () => _uploadDoc("Udyam Certificate",
                    (v) => setState(() => _udyamUploaded = v))),
            _docTile(
                "Cancelled Cheque",
                "For bank account verification",
                _cancelledChequeUploaded,
                () => _uploadDoc("Cancelled Cheque",
                    (v) => setState(() => _cancelledChequeUploaded = v))),
          ] else if (_step == 3) ...[
            const Text("Bank Account Details",
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF0F172A))),
            const Text("For KredX disbursements and invoice payments",
                style: TextStyle(color: Color(0xFF334155), fontSize: 12)),
            const SizedBox(height: 20),
            _field(_bankName, "Bank Name", hint: "e.g. State Bank of India"),
            _field(_accNo, "Account Number", kb: TextInputType.number),
            _field(_ifsc, "IFSC Code", hint: "SBIN0001234"),
            _field(_branch, "Branch Name", required: false),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9),
                foregroundColor: const Color(0xFFFFFFFF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _saving ? null : _saveAndContinue,
              child: _saving
                  ? const CircularProgressIndicator(
                      color: Color(0xFF0F172A), strokeWidth: 2)
                  : Text(_step < 3 ? "Continue" : "Complete Setup ->",
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A))),
            ),
          ),
        ]),
      )),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  bool _sent = false;
  bool _loading = false;
  bool _useEmail = false;
  static bool _googleSignInInitialized = false;
  String? _verificationId;
  String? _errorMsg;
  String _statusMsg = '';
  // WhatsApp OTP toggle — true = MSG91 WhatsApp, false = Firebase SMS
  bool _useWhatsApp = AppConfig.whatsAppOtpEnabled;
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  late final AnimationController _ambient;
  late final AnimationController _entrance;
  late final Animation<Offset> _entranceOffset;

  @override
  void dispose() {
    _ambient.dispose();
    _entrance.dispose();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _entranceOffset = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entrance,
      curve: Curves.easeOutCubic,
    ));
    // Robust phone number cleaning — handles autofill pasting full "+91XXXXXXXXXX"
    _phone.addListener(() {
      final t = _phone.text;
      // Strip country code, spaces, dashes, brackets — keep only digits
      String cleaned = t
          .replaceAll(RegExp(r'[\s\-()]'), '') // remove spaces/dashes
          .replaceAll(RegExp(r'^\+?91'), '') // strip leading +91 or 91
          .replaceAll(RegExp(r'[^0-9]'), ''); // keep only digits
      // Truncate to 10 digits max
      if (cleaned.length > 10) cleaned = cleaned.substring(cleaned.length - 10);
      if (cleaned != t) {
        _phone.value = TextEditingValue(
          text: cleaned,
          selection: TextSelection.collapsed(offset: cleaned.length),
        );
      }
    });
  }

  Future<void> _sendOTP() async {
    final raw =
        _phone.text.trim().replaceAll(RegExp(r'\s+'), '').replaceAll('+91', '');
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final ten =
        digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    if (ten.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(ten)) {
      setState(() => _errorMsg = 'Enter a valid 10-digit Indian mobile number');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
      _statusMsg =
          _useWhatsApp ? 'Sending WhatsApp OTP...' : 'Sending SMS OTP...';
    });

    if (_useWhatsApp && AppConfig.hasMsg91) {
      // ── MSG91 WhatsApp OTP ─────────────────────────────────
      final result = await Msg91OtpService.sendOtp(ten);
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          _sent = true;
          _loading = false;
          _statusMsg = '';
        });
      } else {
        setState(() {
          _loading = false;
          _statusMsg = '';
          _errorMsg =
              "${result['error']}\n\nFalling back to SMS — tap Send OTP via SMS below.";
          _useWhatsApp = false; // auto-fall back to SMS
        });
      }
    } else {
      // ── Firebase SMS OTP ───────────────────────────────────
      await FirebaseService.sendOTP(
        phone: '+91$ten',
        onCodeSent: (vid) {
          if (mounted) {
            if (vid == 'AUTO_VERIFIED') {
              _handleSuccessfulLogin();
              return;
            }
            setState(() {
              _verificationId = vid;
              _sent = true;
              _loading = false;
              _statusMsg = '';
            });
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _loading = false;
              _statusMsg = '';
              _errorMsg =
                  'OTP failed: ${e.toString().replaceAll(RegExp(r'\[.*?\]'), '').trim()}';
            });
          }
        },
      );
    }
  }

  Future<void> _handleSuccessfulLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('rm_session_active', true);
    final uid = FirebaseService.currentUser?.uid;
    if (uid != null) await prefs.setString('rm_uid', uid);
    bool isNew = true;
    if (uid != null) {
      final profileKey = '${uid}_fm_profile';
      if (prefs.getString(profileKey) != null) {
        isNew = false;
      } else {
        try {
          final doc = await FirebaseService.loadProfile();
          isNew = doc == null || (doc['companyName'] as String? ?? '').isEmpty;
        } catch (_) {
          isNew = false;
        }
      }
    }
    if (!mounted) return;
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (_) =>
                isNew ? const RegistrationScreen() : const ConsentGate()));
  }

  Future<void> _authenticateWithGoogle() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      if (!FirebaseService.isReady) {
        throw StateError(
            'Authentication service is unavailable. Try again later.');
      }
      final googleSignIn = GoogleSignIn.instance;
      if (!_googleSignInInitialized) {
        await googleSignIn.initialize();
        _googleSignInInitialized = true;
      }
      final account = await googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw StateError(
            'Google sign-in is not configured for this app. Enable Google sign-in in Firebase and configure the Android OAuth client.');
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await FirebaseService.auth.signInWithCredential(credential);
      await _handleSuccessfulLogin();
    } on GoogleSignInException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMsg = switch (e.code) {
          GoogleSignInExceptionCode.canceled => null,
          GoogleSignInExceptionCode.clientConfigurationError ||
          GoogleSignInExceptionCode.providerConfigurationError =>
            'Google sign-in is not configured for this app. Check the Firebase and Google OAuth setup.',
          _ => e.description ?? 'Could not choose a Google account.',
        };
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMsg = switch (e.code) {
          'operation-not-allowed' =>
            'Google sign-in is not enabled in Firebase Authentication.',
          'account-exists-with-different-credential' =>
            'This email already uses another sign-in method. Sign in with that method instead.',
          'network-request-failed' => 'Network error. Check your connection.',
          'too-many-requests' =>
            'Too many attempts. Please wait and try again.',
          _ => e.message ?? 'Could not sign in with Google. Please try again.',
        };
      });
    } on StateError catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMsg = e.message;
      });
    } catch (e) {
      debugPrint('Google authentication failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMsg =
            'Could not sign in with Google. Check your connection and try again.';
      });
    }
  }

  Future<void> _verifyOTP() async {
    if (_otp.text.trim().length < 6) {
      setState(() => _errorMsg = 'Enter the 6-digit OTP');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    if (_useWhatsApp && AppConfig.hasMsg91) {
      // ── Verify MSG91 WhatsApp OTP ──────────────────────────
      final raw = _phone.text.trim().replaceAll(RegExp(r'[^0-9]'), '');
      final ten = raw.length > 10 ? raw.substring(raw.length - 10) : raw;
      final result = await Msg91OtpService.verifyOtp(
          tenDigitPhone: ten, enteredOtp: _otp.text.trim());
      if (!mounted) return;
      if (result['success'] == true) {
        await _handleSuccessfulLogin();
      } else {
        setState(() {
          _loading = false;
          _errorMsg = result['error'] ?? 'Verification failed';
        });
      }
    } else {
      // ── Verify Firebase SMS OTP ────────────────────────────
      if (_verificationId == null) {
        setState(() {
          _loading = false;
          _errorMsg = 'Request OTP first';
        });
        return;
      }
      try {
        final ok = await FirebaseService.verifyOTP(
            verificationId: _verificationId!, otp: _otp.text.trim());
        if (!mounted) return;
        if (ok) {
          await _handleSuccessfulLogin();
        } else {
          setState(() {
            _loading = false;
            _errorMsg = 'Incorrect OTP. Check the code and try again.\n'
                'If the problem persists:\n'
                '• Make sure Phone Auth is enabled in Firebase Console\n'
                '• Check SHA-1 fingerprint is added for this device';
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _errorMsg = 'Verification error. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Color(0xFF070B11),
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: UniversalScaffold(
            body: Stack(children: [
          Container(
              decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [
            Color(0xFF060A10),
            Color(0xFF0A131D),
            Color(0xFF14212D),
            Color(0xFF070B11)
          ], stops: [
            0.0,
            0.28,
            0.72,
            1.0
          ], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
          AnimatedBuilder(
            animation: _ambient,
            builder: (context, _) => CustomPaint(
              painter: _LoginRoutePainter(progress: _ambient.value),
              size: Size.infinite,
            ),
          ),
          AnimatedBuilder(
            animation: _ambient,
            builder: (context, _) {
              final phase = _ambient.value * 2 * math.pi;
              return Stack(children: [
                Positioned(
                  top: -110 + 28 * math.sin(phase),
                  left: -100 + 22 * math.cos(phase),
                  child: _loginGlow(const Color(0xFF58C9BF), 330, 0.24),
                ),
                Positioned(
                  bottom: -100 + 20 * math.cos(phase),
                  right: -80 + 25 * math.sin(phase),
                  child: _loginGlow(const Color(0xFFC9A66B), 280, 0.17),
                ),
                Positioned(
                  top: MediaQuery.sizeOf(context).height * 0.38,
                  right: -175 + 18 * math.sin(phase + 1),
                  child: _loginGlow(const Color(0xFF5C8290), 300, 0.10),
                ),
              ]);
            },
          ),
          FadeTransition(
              opacity: _entrance,
              child: SlideTransition(
                  position: _entranceOffset,
                  child: SafeArea(
                      child: Center(
                          child: SingleChildScrollView(
                              padding: const EdgeInsets.all(28),
                              child: Column(children: [
                                Row(children: [
                                  _buildLoginLogo(),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text("NAVGATI",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 23,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 3.2)),
                                        SizedBox(height: 4),
                                        Text("TRANSPORT OPERATING SYSTEM",
                                            style: TextStyle(
                                                color: Color(0xFF91A9C3),
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: 1.4)),
                                      ])),
                                ]),
                                const SizedBox(height: 26),
                                const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text("FLEET. FINANCE. FORWARD.",
                                        style: TextStyle(
                                            color: Color(0xFF82D8CE),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 2.2))),
                                const SizedBox(height: 8),
                                const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                        "Your entire operation,\nin sync.",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 32,
                                            height: 1.05,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.8))),
                                const SizedBox(height: 10),
                                const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                        "A sharper view of every load, vehicle and rupee.",
                                        style: TextStyle(
                                            color: Color(0xFF9EB0C5),
                                            fontSize: 13,
                                            height: 1.4))),
                                const SizedBox(height: 22),
                                Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFF8FBFF),
                                        borderRadius: BorderRadius.circular(28),
                                        border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.75),
                                            width: 1.2),
                                        boxShadow: [
                                          BoxShadow(
                                              color: const Color(0xFF020817)
                                                  .withValues(alpha: 0.40),
                                              blurRadius: 48,
                                              offset: const Offset(0, 24)),
                                          BoxShadow(
                                              color: const Color(0xFF38BDF8)
                                                  .withValues(alpha: 0.08),
                                              blurRadius: 30,
                                              spreadRadius: 1),
                                        ]),
                                    child: Column(children: [
                                      Row(children: [
                                        Container(
                                          width: 3,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0EA5E9),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                        const SizedBox(width: 11),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _sent
                                                    ? 'VERIFY YOUR ACCESS'
                                                    : 'WELCOME TO YOUR COMMAND CENTER',
                                                style: const TextStyle(
                                                  color: Color(0xFF10253A),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 1.15,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                _sent
                                                    ? 'Enter the one-time code to continue.'
                                                    : 'Secure sign-in for your operation.',
                                                style: const TextStyle(
                                                  color: Color(0xFF61758A),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.verified_user_rounded,
                                            color: Color(0xFF0EA5E9), size: 19),
                                      ]),
                                      const SizedBox(height: 18),
                                      if (!_sent) ...[
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE2E8F0),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            children: [
                                              _loginMethodButton(
                                                label: 'Phone OTP',
                                                icon:
                                                    Icons.phone_iphone_rounded,
                                                selected: !_useEmail,
                                                onTap: () => setState(() {
                                                  _useEmail = false;
                                                  _errorMsg = null;
                                                }),
                                              ),
                                              _loginMethodButton(
                                                label: 'Email',
                                                icon: Icons.email_outlined,
                                                selected: _useEmail,
                                                onTap: () => setState(() {
                                                  _useEmail = true;
                                                  _errorMsg = null;
                                                }),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 18),
                                        if (!_useEmail) ...[
                                          const Text(
                                              "Fleet Owner / Consignor Login",
                                              style: TextStyle(
                                                  color: Color(0xFF64748B),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 12),
                                          TextField(
                                              style: const TextStyle(
                                                  color: Color(0xFF0F172A),
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 1),
                                              controller: _phone,
                                              keyboardType: TextInputType.phone,
                                              autofillHints: const [
                                                AutofillHints.telephoneNumber
                                              ],
                                              maxLength: 14,
                                              decoration: InputDecoration(
                                                  counterText: "",
                                                  labelText: "Mobile Number",
                                                  hintText: "98765 43210",
                                                  prefixText: "+91  ",
                                                  prefixStyle: const TextStyle(
                                                      color: Color(0xFF0EA5E9),
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 16),
                                                  prefixIcon: const Icon(Icons.phone,
                                                      color: Color(0xFF0EA5E9)),
                                                  filled: true,
                                                  fillColor:
                                                      const Color(0xFFF6FAFF),
                                                  labelStyle: const TextStyle(
                                                      color: Color(0xFF0F172A),
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w500),
                                                  floatingLabelStyle: const TextStyle(
                                                      color: Color(0xFF0EA5E9),
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 12),
                                                  border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      borderSide: const BorderSide(
                                                          color: Color(
                                                              0xFF0EA5E9))),
                                                  enabledBorder: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(12),
                                                      borderSide: const BorderSide(color: Color(0xFF0EA5E9))),
                                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 2)))),
                                          if (_errorMsg != null && !_sent) ...[
                                            const SizedBox(height: 8),
                                            Container(
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                    color: Colors.red
                                                        .withValues(
                                                            alpha: 0.08),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8)),
                                                child: Row(children: [
                                                  const Icon(
                                                      Icons.error_outline,
                                                      color: Colors.red,
                                                      size: 14),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                      child: Text(_errorMsg!,
                                                          style: const TextStyle(
                                                              color: Colors.red,
                                                              fontSize: 11,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600))),
                                                ])),
                                          ],
                                          const SizedBox(height: 20),
                                          // ── OTP Method Toggle ──────────────────────────────
                                          if (!_sent) ...[
                                            Container(
                                              margin: const EdgeInsets.only(
                                                  bottom: 14),
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Row(children: [
                                                Expanded(
                                                    child: GestureDetector(
                                                  onTap: () => setState(() =>
                                                      _useWhatsApp = false),
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                        milliseconds: 200),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 10),
                                                    decoration: BoxDecoration(
                                                      color: !_useWhatsApp
                                                          ? Colors.white
                                                          : Colors.transparent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      boxShadow: !_useWhatsApp
                                                          ? [
                                                              BoxShadow(
                                                                  color: Colors
                                                                      .black
                                                                      .withValues(
                                                                          alpha:
                                                                              0.08),
                                                                  blurRadius: 4)
                                                            ]
                                                          : [],
                                                    ),
                                                    child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                              Icons.sms_rounded,
                                                              size: 16,
                                                              color: !_useWhatsApp
                                                                  ? const Color(
                                                                      0xFF0EA5E9)
                                                                  : const Color(
                                                                      0xFF94A3B8)),
                                                          const SizedBox(
                                                              width: 6),
                                                          Text('SMS OTP',
                                                              style: TextStyle(
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: !_useWhatsApp
                                                                      ? const Color(
                                                                          0xFF0F172A)
                                                                      : const Color(
                                                                          0xFF94A3B8))),
                                                        ]),
                                                  ),
                                                )),
                                                Expanded(
                                                    child: GestureDetector(
                                                  onTap: () => setState(() =>
                                                      _useWhatsApp = true),
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                        milliseconds: 200),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 10),
                                                    decoration: BoxDecoration(
                                                      color: _useWhatsApp
                                                          ? Colors.white
                                                          : Colors.transparent,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                      boxShadow: _useWhatsApp
                                                          ? [
                                                              BoxShadow(
                                                                  color: Colors
                                                                      .black
                                                                      .withValues(
                                                                          alpha:
                                                                              0.08),
                                                                  blurRadius: 4)
                                                            ]
                                                          : [],
                                                    ),
                                                    child: Row(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                              Icons
                                                                  .chat_rounded,
                                                              size: 16,
                                                              color: _useWhatsApp
                                                                  ? const Color(
                                                                      0xFF25D366)
                                                                  : const Color(
                                                                      0xFF94A3B8)),
                                                          const SizedBox(
                                                              width: 6),
                                                          Text('WhatsApp OTP',
                                                              style: TextStyle(
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: _useWhatsApp
                                                                      ? const Color(
                                                                          0xFF25D366)
                                                                      : const Color(
                                                                          0xFF94A3B8))),
                                                          if (_useWhatsApp &&
                                                              AppConfig
                                                                  .hasMsg91) ...[
                                                            const SizedBox(
                                                                width: 4),
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          4,
                                                                      vertical:
                                                                          1),
                                                              decoration: BoxDecoration(
                                                                  color: const Color(
                                                                      0xFF25D366),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              4)),
                                                              child: const Text(
                                                                  'LIVE',
                                                                  style: TextStyle(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          8,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w900)),
                                                            ),
                                                          ],
                                                        ]),
                                                  ),
                                                )),
                                              ]),
                                            ),
                                            if (_useWhatsApp &&
                                                !AppConfig.hasMsg91)
                                              Container(
                                                margin: const EdgeInsets.only(
                                                    bottom: 10),
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFFFFFBEB),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                      color: const Color(
                                                              0xFFF59E0B)
                                                          .withValues(
                                                              alpha: 0.5)),
                                                ),
                                                child: Row(children: [
                                                  Icon(
                                                      Icons
                                                          .info_outline_rounded,
                                                      size: 14,
                                                      color: Color(0xFFB45309)),
                                                  SizedBox(width: 8),
                                                  Flexible(
                                                      child: Text(
                                                          'MSG91 not configured yet. Add keys to AppConfig to enable WhatsApp OTP. Using SMS for now.',
                                                          style: TextStyle(
                                                              fontSize: 11,
                                                              color: Color(
                                                                  0xFFB45309)))),
                                                ]),
                                              ),
                                          ],
                                          // ── Main Send Button ────────────────────────────────
                                          SizedBox(
                                            width: double.infinity,
                                            height: 55,
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _useWhatsApp &&
                                                        AppConfig.hasMsg91
                                                    ? const Color(0xFF25D366)
                                                    : const Color(0xFF0EA5E9),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12)),
                                                elevation: 0,
                                              ),
                                              onPressed:
                                                  _loading ? null : _sendOTP,
                                              icon: _loading
                                                  ? const SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  Colors.white))
                                                  : Icon(
                                                      _useWhatsApp &&
                                                              AppConfig.hasMsg91
                                                          ? Icons.chat_rounded
                                                          : Icons.sms_rounded,
                                                      color: Colors.white,
                                                      size: 20),
                                              label: Text(
                                                  _loading
                                                      ? 'Sending...'
                                                      : _useWhatsApp &&
                                                              AppConfig.hasMsg91
                                                          ? 'Send OTP via WhatsApp'
                                                          : 'Send OTP via SMS',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                          ),
                                          if (_loading &&
                                              _statusMsg.isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(_statusMsg,
                                                style: const TextStyle(
                                                    color: Color(0xFF0EA5E9),
                                                    fontSize: 12),
                                                textAlign: TextAlign.center),
                                            const SizedBox(height: 4),
                                            const Text(
                                                'OTP can auto-fill from SMS. If browser verification appears, add SHA-1/SHA-256 and Play Integrity in Firebase to keep verification inside the app.',
                                                style: TextStyle(
                                                    color: Color(0xFF64748B),
                                                    fontSize: 11),
                                                textAlign: TextAlign.center),
                                          ],
                                        ] else ...[
                                          const Text(
                                            'Choose a Google account already on this device. No password is needed.',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Color(0xFF64748B),
                                              fontSize: 12,
                                              height: 1.5,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          if (_errorMsg != null) ...[
                                            _loginError(_errorMsg!),
                                            const SizedBox(height: 12),
                                          ],
                                          SizedBox(
                                            width: double.infinity,
                                            height: 55,
                                            child: ElevatedButton.icon(
                                              onPressed: _loading
                                                  ? null
                                                  : _authenticateWithGoogle,
                                              icon: _loading
                                                  ? const SizedBox(
                                                      width: 18,
                                                      height: 18,
                                                      child:
                                                          CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white,
                                                      ),
                                                    )
                                                  : const Icon(Icons
                                                      .account_circle_rounded),
                                              label: Text(
                                                _loading
                                                    ? 'Opening accounts...'
                                                    : 'Choose Google account',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF0EA5E9),
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ),
                                          if (!FirebaseService.isReady)
                                            const Padding(
                                              padding: EdgeInsets.only(top: 12),
                                              child: Text(
                                                'Google sign-in requires Firebase Authentication to be configured.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: Color(0xFFB45309),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ] else ...[
                                        Text(
                                            "OTP sent to +91 ${_phone.text.replaceAll(RegExp(r"^\+?91"), "").trim()}",
                                            style: const TextStyle(
                                                color: Color(0xFF0EA5E9),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 15),
                                        // Auto-read OTP from SMS hint
                                        TextField(
                                            controller: _otp,
                                            keyboardType: TextInputType.number,
                                            autofillHints: const [
                                              AutofillHints.oneTimeCode
                                            ],
                                            enableSuggestions: true,
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                                fontSize: 28,
                                                letterSpacing: 12,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF0F172A)),
                                            maxLength: 6,
                                            onChanged: (v) {
                                              // Auto-submit when 6 digits entered (SMS auto-fill)
                                              if (v.length == 6 && !_loading) {
                                                _verifyOTP();
                                              }
                                            },
                                            decoration: InputDecoration(
                                                counterText: "",
                                                labelText: "6-Digit OTP",
                                                filled: true,
                                                fillColor:
                                                    const Color(0xFFF6FAFF),
                                                labelStyle: const TextStyle(
                                                    color: Color(0xFF0F172A),
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w500),
                                                floatingLabelStyle: const TextStyle(
                                                    color: Color(0xFF0EA5E9),
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 12),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    borderSide: const BorderSide(
                                                        color:
                                                            Color(0xFF0EA5E9))),
                                                enabledBorder: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                    borderSide: const BorderSide(
                                                        color:
                                                            Color(0xFF0EA5E9))),
                                                focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                    borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 2)))),
                                        const SizedBox(height: 8),
                                        // Paste from clipboard button
                                        TextButton.icon(
                                          onPressed: () async {
                                            final data =
                                                await Clipboard.getData(
                                                    'text/plain');
                                            final text =
                                                data?.text?.trim() ?? '';
                                            final digits = text.replaceAll(
                                                RegExp(r'[^0-9]'), '');
                                            if (digits.length >= 6) {
                                              _otp.text =
                                                  digits.substring(0, 6);
                                              _verifyOTP();
                                            }
                                          },
                                          icon: const Icon(Icons.paste_rounded,
                                              size: 15,
                                              color: Color(0xFF0EA5E9)),
                                          label: const Text(
                                              'Paste OTP from SMS',
                                              style: TextStyle(
                                                  color: Color(0xFF0EA5E9),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700)),
                                        ),
                                        if (_errorMsg != null) ...[
                                          const SizedBox(height: 8),
                                          Text(_errorMsg!,
                                              style: const TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500),
                                              textAlign: TextAlign.center),
                                          const SizedBox(height: 4)
                                        ],
                                        const SizedBox(height: 12),
                                        SizedBox(
                                            width: double.infinity,
                                            height: 55,
                                            child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFF0EA5E9),
                                                    foregroundColor:
                                                        const Color(0xFFFFFFFF),
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                12))),
                                                onPressed: _loading
                                                    ? null
                                                    : _verifyOTP,
                                                child: _loading
                                                    ? const SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child:
                                                            CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                color: Color(
                                                                    0xFF0F172A)))
                                                    : const Text(
                                                        "Verify & Login",
                                                        style: TextStyle(
                                                            color:
                                                                Color(0xFF0F172A),
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.bold)))),
                                      ],
                                    ])),
                                const SizedBox(height: 20),
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const DriverQuickLoginScreen())),
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFF6FAFF),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                            color: const Color(0xFF10B981)
                                                .withValues(alpha: 0.4)),
                                        boxShadow: [
                                          BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.04),
                                              blurRadius: 10)
                                        ]),
                                    child: Row(children: [
                                      Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                              color: const Color(0xFF10B981)
                                                  .withValues(alpha: 0.12),
                                              shape: BoxShape.circle),
                                          child: const Icon(
                                              Icons.drive_eta_rounded,
                                              color: Color(0xFF10B981),
                                              size: 22)),
                                      const SizedBox(width: 12),
                                      const Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text("Driver Login",
                                                style: TextStyle(
                                                    color: Color(0xFF0F172A),
                                                    fontSize: 15,
                                                    fontWeight:
                                                        FontWeight.w900)),
                                            Text(
                                                "Quick access for drivers on-trip",
                                                style: TextStyle(
                                                    color: Color(0xFF64748B),
                                                    fontSize: 11)),
                                          ])),
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 7),
                                          decoration: BoxDecoration(
                                              color: const Color(0xFF10B981),
                                              borderRadius:
                                                  BorderRadius.circular(10)),
                                          child: const Text("Enter",
                                              style: TextStyle(
                                                  color: Color(0xFF0F172A),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12))),
                                    ]),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                    "New? Registration completes after first login.",
                                    style: TextStyle(
                                        color: Color(0xFF94A3B8), fontSize: 11),
                                    textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                // Language selector on login page
                                ValueListenableBuilder<Locale>(
                                    valueListenable: appLocale,
                                    builder: (_, locale, __) => Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          alignment: WrapAlignment.center,
                                          children: AppConfig
                                              .supportedLanguages.entries
                                              .map((e) {
                                            final isSelected =
                                                locale.languageCode == e.key;
                                            return GestureDetector(
                                                onTap: () async {
                                                  final localeMap = {
                                                    'en': const Locale('en'),
                                                    'hi': const Locale('hi'),
                                                    'gu': const Locale('gu'),
                                                    'pa': const Locale('pa'),
                                                    'mr': const Locale('mr'),
                                                    'ta': const Locale('ta'),
                                                    'te': const Locale('te'),
                                                    'kn': const Locale('kn'),
                                                    'bn': const Locale('bn'),
                                                  };
                                                  appLocale.value =
                                                      localeMap[e.key] ??
                                                          const Locale('en');
                                                  final p =
                                                      await SharedPreferences
                                                          .getInstance();
                                                  await p.setString(
                                                      'rm_language', e.key);
                                                },
                                                child: AnimatedContainer(
                                                    duration: const Duration(
                                                        milliseconds: 150),
                                                    padding: const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 5),
                                                    decoration: BoxDecoration(
                                                        color: isSelected
                                                            ? const Color(0xFF0EA5E9)
                                                                .withValues(
                                                                    alpha: 0.15)
                                                            : Colors.white
                                                                .withValues(
                                                                    alpha: 0.8),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                20),
                                                        border: Border.all(
                                                            color: isSelected
                                                                ? const Color(
                                                                    0xFF0EA5E9)
                                                                : Colors.grey.shade300)),
                                                    child: Text(e.value, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500, color: isSelected ? const Color(0xFF0EA5E9) : const Color(0xFF64748B)))));
                                          }).toList(),
                                        )),
                                const SizedBox(height: 8),
                              ]))))))
        ])),
      );

  Widget _loginGlow(Color color, double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.25),
            Colors.transparent,
          ]),
        ),
      );

  Widget _buildLoginLogo() => AnimatedBuilder(
        animation: _ambient,
        builder: (context, _) {
          final phase = _ambient.value * 2 * math.pi;
          return SizedBox(
            width: 80,
            height: 80,
            child: Stack(alignment: Alignment.center, children: [
              Transform.rotate(
                angle: phase * 0.11,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFF58C9BF).withValues(alpha: 0.45),
                        width: 1.2),
                  ),
                ),
              ),
              Transform.rotate(
                angle: -phase * 0.16,
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: const Color(0xFFC9A66B).withValues(alpha: 0.7),
                        width: 1.5),
                  ),
                ),
              ),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF162633), Color(0xFF0A111A)],
                  ),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14), width: 1),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF58C9BF).withValues(alpha: 0.28),
                        blurRadius: 22,
                        spreadRadius: 2),
                  ],
                ),
                child: CustomPaint(
                  painter: _NavgatiMarkPainter(progress: _ambient.value),
                  size: const Size(38, 38),
                ),
              ),
              Positioned(
                right: 4,
                bottom: 7,
                child: Container(
                  width: 19,
                  height: 19,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9A66B),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFF0A111A), width: 2),
                  ),
                  child: const Text('N',
                      style: TextStyle(
                          color: Color(0xFF071426),
                          fontSize: 9,
                          fontWeight: FontWeight.w900)),
                ),
              ),
            ]),
          );
        },
      );

  Widget _loginMethodButton({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                      )
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 16,
                    color: selected
                        ? const Color(0xFF0284C7)
                        : const Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF64748B),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _loginError(String message) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

class _LoginRoutePainter extends CustomPainter {
  final double progress;

  const _LoginRoutePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final gridPaint = Paint()
      ..color = const Color(0xFF9BC7E8).withValues(alpha: 0.045);
    for (double x = 18; x < width; x += 34) {
      for (double y = 18; y < height; y += 34) {
        canvas.drawCircle(Offset(x, y), 0.8, gridPaint);
      }
    }

    final route = Path()
      ..moveTo(-width * 0.12, height * 0.28)
      ..cubicTo(width * 0.28, height * 0.18, width * 0.34, height * 0.53,
          width * 0.62, height * 0.48)
      ..cubicTo(width * 0.82, height * 0.44, width * 0.9, height * 0.7,
          width * 1.12, height * 0.62);
    canvas.drawPath(
        route,
        Paint()
          ..color = const Color(0xFF58C9BF).withValues(alpha: 0.055)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawPath(
        route,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x2258C9BF), Color(0x6658C9BF), Color(0x33C9A66B)],
          ).createShader(Offset.zero & size)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2);

    for (final metric in route.computeMetrics()) {
      final tangent = metric.getTangentForOffset(metric.length * progress);
      if (tangent == null) continue;
      canvas.drawCircle(
          tangent.position,
          12,
          Paint()
            ..color = const Color(0xFF58C9BF).withValues(alpha: 0.1)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawCircle(tangent.position, 2.8,
          Paint()..color = const Color(0xFFD4F0E9).withValues(alpha: 0.85));
    }
  }

  @override
  bool shouldRepaint(_LoginRoutePainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _NavgatiMarkPainter extends CustomPainter {
  final double progress;

  const _NavgatiMarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final mark = Path()
      ..moveTo(size.width * 0.24, size.height * 0.76)
      ..lineTo(size.width * 0.24, size.height * 0.24)
      ..lineTo(size.width * 0.76, size.height * 0.76)
      ..lineTo(size.width * 0.76, size.height * 0.24);
    canvas.drawPath(
        mark,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFC9A66B), Color(0xFF58C9BF), Color(0xFFF2F0EA)],
          ).createShader(Offset.zero & size)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.09
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);

    final route = Path()
      ..moveTo(size.width * 0.18, size.height * 0.88)
      ..quadraticBezierTo(size.width * 0.48, size.height * 0.72,
          size.width * 0.82, size.height * 0.88);
    canvas.drawPath(
        route,
        Paint()
          ..color = const Color(0xFFC9A66B).withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * 0.035
          ..strokeCap = StrokeCap.round);
    for (final metric in route.computeMetrics()) {
      final tangent = metric.getTangentForOffset(metric.length * progress);
      if (tangent != null) {
        canvas.drawCircle(
            tangent.position,
            size.width * 0.07,
            Paint()
              ..color = const Color(0xFFF3DFB9)
              ..maskFilter =
                  MaskFilter.blur(BlurStyle.normal, size.width * 0.06));
      }
    }
  }

  @override
  bool shouldRepaint(_NavgatiMarkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ================================================================
// DRIVER QUICK LOGIN SCREEN
// ================================================================
class DriverQuickLoginScreen extends StatefulWidget {
  const DriverQuickLoginScreen({super.key});
  @override
  State<DriverQuickLoginScreen> createState() => _DriverQuickLoginScreenState();
}

class _DriverQuickLoginScreenState extends State<DriverQuickLoginScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  bool _sent = false, _loading = false;
  String? _errorMsg, _verificationId;

  @override
  void initState() {
    super.initState();
    _phone.addListener(() {
      final t = _phone.text;
      String cleaned = t
          .replaceAll(RegExp(r'[\s\-()]'), '')
          .replaceAll(RegExp(r'^\+?91'), '')
          .replaceAll(RegExp(r'[^0-9]'), '');
      if (cleaned.length > 10) cleaned = cleaned.substring(cleaned.length - 10);
      if (cleaned != t) {
        _phone.value = TextEditingValue(
          text: cleaned,
          selection: TextSelection.collapsed(offset: cleaned.length),
        );
      }
    });
  }

  Future<void> _sendOTP() async {
    final raw = _phone.text
        .trim()
        .replaceAll(RegExp(r'\D'), '')
        .replaceAll(RegExp(r'^91'), '');
    final digits = raw.length > 10 ? raw.substring(raw.length - 10) : raw;
    if (digits.length != 10) {
      setState(() => _errorMsg = 'Enter 10-digit number');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    await FirebaseService.sendOTP(
      phone: '+91$digits',
      onCodeSent: (vid) {
        if (mounted) {
          setState(() {
            _verificationId = vid;
            _sent = true;
            _loading = false;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _loading = false;
            _errorMsg = e;
          });
        }
      },
    );
  }

  Future<void> _verify() async {
    if (_verificationId == null || _otp.text.length < 6) return;
    setState(() => _loading = true);
    final ok = await FirebaseService.verifyOTP(
        verificationId: _verificationId!, otp: _otp.text.trim());
    if (!mounted) return;
    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rm_session_active', true);
      await prefs.setString('rm_user_type', 'driver');
      // Try to find which fleet owner registered this driver
      try {
        final phone = _phone.text.trim().replaceAll(RegExp(r'\D'), '');
        final lastTen =
            phone.length >= 10 ? phone.substring(phone.length - 10) : phone;
        // Look up in publicDrivers collection (fleet owners write drivers here)
        final snap = await FirebaseFirestore.instance
            .collection('publicDrivers')
            .where('phone', isEqualTo: lastTen)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final driverData = snap.docs.first.data();
          await prefs.setString('rm_driver_name', driverData['name'] ?? '');
          await prefs.setString(
              'rm_fleet_owner_uid', driverData['fleetOwnerUid'] ?? '');
        }
      } catch (_) {}
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const ConsentGate()), (_) => false);
    } else {
      setState(() {
        _loading = false;
        _errorMsg = 'Incorrect OTP — please try again';
      });
    }
  }

  @override
  Widget build(BuildContext context) => UniversalScaffold(
        appBar: AppBar(
            backgroundColor: const Color(0xFF10B981),
            iconTheme: const IconThemeData(color: Colors.white),
            title: const Text("Driver Login",
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900))),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            const SizedBox(height: 20),
            Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                    shape: BoxShape.circle),
                child: const Icon(Icons.drive_eta_rounded,
                    color: Color(0xFF10B981), size: 60)),
            const SizedBox(height: 20),
            const Text("Driver Access",
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A))),
            const Text("Login with your registered mobile number",
                style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 32),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 14,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: InputDecoration(
                  counterText: "",
                  labelText: "Mobile Number",
                  prefixText: "+91  ",
                  prefixStyle: const TextStyle(
                      color: Color(0xFF10B981), fontWeight: FontWeight.w800),
                  prefixIcon: const Icon(Icons.phone, color: Color(0xFF10B981)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF10B981))),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF10B981), width: 2))),
            ),
            if (_sent) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _otp,
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofillHints: const [AutofillHints.oneTimeCode],
                enableSuggestions: false,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 26,
                    letterSpacing: 10,
                    fontWeight: FontWeight.w900),
                decoration: InputDecoration(
                    counterText: "",
                    labelText: "Enter OTP",
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF10B981))),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: Color(0xFF10B981), width: 2))),
              ),
            ],
            if (_errorMsg != null) ...[
              const SizedBox(height: 8),
              Text(_errorMsg!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                  textAlign: TextAlign.center),
            ],
            const SizedBox(height: 20),
            SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  onPressed: _loading ? null : (_sent ? _verify : _sendOTP),
                  child: _loading
                      ? const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2)
                      : Text(_sent ? "Verify & Enter" : "Send OTP",
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A))),
                )),
            const SizedBox(height: 20),
            Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12)),
                child: const Text(
                    "Drivers don't need full registration. Your fleet owner has already added you to the system.",
                    style: TextStyle(color: Color(0xFF334155), fontSize: 12),
                    textAlign: TextAlign.center)),
          ]),
        ),
      );
}

// ================================================================
// MAIN SHELL
// ================================================================
