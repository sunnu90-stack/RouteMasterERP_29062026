// ============================================================
// config.dart  —  part of liquid_logistics main library
// Auto-extracted from main_v23_8.dart (original lines 76-262)
// DO NOT add imports here — all imports live in main.dart
// ============================================================
part of 'package:liquid_logistics/main.dart';

// ================================================================
// CONFIG
// ================================================================
class AppConfig {
  // Developer master PIN — change before going live.
  static const String _adminPin =
      String.fromEnvironment('ADMIN_PIN', defaultValue: '');
  // Two ways to set this (either works):
  //   1. Build with:  flutter run --dart-define=MAPS_KEY=YOUR_KEY
  //   2. OR paste your key between the quotes on the line below.
  static const String _mapsKeyHardcoded =
      ''; // <-- paste Google Maps key here as a fallback (optional)
  static const String _mapsKeyFromBuild =
      String.fromEnvironment('MAPS_KEY', defaultValue: '');
  static String get googleMapsApiKey =>
      _mapsKeyFromBuild.isNotEmpty ? _mapsKeyFromBuild : _mapsKeyHardcoded;
  // ── Gemini AI key (FREE — get from aistudio.google.com, no card needed) ──
  // ══════════════════════════════════════════════════════════
  // AI API KEYS
  // ══════════════════════════════════════════════════════════
  static const String geminiApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String groqApiKey =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  static const String sarvamApiKey =
      String.fromEnvironment('SARVAM_API_KEY', defaultValue: '');
  static const String openRouterApiKey =
      String.fromEnvironment('OPENROUTER_API_KEY', defaultValue: '');
  // ══════════════════════════════════════════════════════════
  // ── LOCAL on-device AI (no internet needed) ──────────────────
  // Download the Gemma 2B GGUF model (~1.5 GB) from:
  // https://huggingface.co/google/gemma-2-2b-it-GGUF/resolve/main/gemma-2-2b-it-Q4_K_M.gguf
  // Put it at /data/user/0/<packageName>/files/gemma.gguf on the device
  // Then set useLocalModel = true. Requires flutter_llm_inference package (add to pubspec).
  // For now this flag is false — app uses Gemini → OpenRouter → local analysis chain.
  static const bool useLocalModel = false;
  // ── MSG91 WhatsApp OTP ─────────────────────────────────────────────────
  // Step 1: Sign up free at msg91.com
  // Step 2: Dashboard → API → copy Auth Key
  // Step 3: WhatsApp → Templates → create OTP template → get Template ID
  // Step 4: WhatsApp → Sender → register your WhatsApp Business number
  // Cost: Rs.0.30 per OTP. Recharge Rs.100 to start (~333 OTPs).
  static const String msg91AuthKey = ''; // paste your MSG91 auth key here
  static const String msg91TemplateId = ''; // paste OTP template ID here
  static const String msg91SenderId =
      ''; // your WhatsApp Business number e.g. 919876543210
  // Set true once MSG91 is configured — makes WhatsApp the default OTP method
  static const bool whatsAppOtpEnabled =
      false; // flip to true after MSG91 setup
  static const String appVersion = "5.0.0";
  // ── OWNER PHONES — demo data shows for these numbers, others start clean ──
  static const List<String> ownerPhones = ['9723627621', '7490027621'];
  static bool get isOwnerDevice {
    final user = FirebaseService.currentUser;
    if (user == null) return false;
    final phone = user.phoneNumber ?? '';
    return ownerPhones.any((p) => phone.endsWith(p));
  }

  static const int adminTapCount = 1;
  static const int adminTapWindowMs = 3000;
  static const double defaultDieselPrice = 93.0;
  static const int paymentAlertDays = 5;
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'hi': 'हिंदी (Hindi)',
    'gu': 'ગુજરાતી (Gujarati)',
    'pa': 'ਪੰਜਾਬੀ (Punjabi)',
    'mr': 'मराठी (Marathi)',
    'ta': 'தமிழ் (Tamil)',
    'te': 'తెలుగు (Telugu)',
    'kn': 'ಕನ್ನಡ (Kannada)',
    'ra': 'राजस्थानी (Rajasthani)',
    'bh': 'भोजपुरी (Bhojpuri)',
  };
  static bool validatePin(String p) => p == _adminPin;
  static bool get hasGoogleMaps =>
      googleMapsApiKey.isNotEmpty && googleMapsApiKey.length > 20;
  static bool get hasMsg91 =>
      msg91AuthKey.isNotEmpty &&
      msg91TemplateId.isNotEmpty &&
      whatsAppOtpEnabled;
}

// ══════════════════════════════════════════════════════════════════
// AI USAGE LIMITS — caps AI provider spend per subscription plan.
// ══════════════════════════════════════════════════════════════════
// Every AI call (Copilot chat, executive-summary report, LR photo read)
// costs real money against Gemini/Groq/Sarvam/OpenRouter. This caps how
// many "tokens" each plan can spend per calendar month so AI cost can
// never exceed what that plan is paying for.
//
// The per-call numbers below are deliberately generous over-estimates
// (not the exact number a provider bills) because providers don't all
// report usage the same way — over-counting is the safe direction,
// since it means real spend stays UNDER the cap, never over it.
//
// Tune monthlyTokenCap once you have real per-plan pricing decided —
// these are placeholder starting points sized so:
//   Free:  ~15 copilot questions/month, no photo reads
//   Pro:   ~120 copilot questions/month, or a mix incl. some photos
//   Business / Enterprise: scaled up for higher usage
// ══════════════════════════════════════════════════════════════════
class AiUsageLimits {
  // Tier name -> monthly token budget. Keys are lowercase; lookups are
  // case-insensitive (see capFor). Add/rename tiers here to match
  // whatever your subscription plans file actually calls them.
  static const Map<String, int> monthlyTokenCap = {
    'free': 20000,
    'pro': 150000,
    'business': 500000,
    'enterprise': 2000000,
  };

  // Estimated token cost charged per AI call type.
  static const int copilotChatCostTokens = 1200; // one Copilot question
  static const int copilotReportCostTokens = 1500; // PDF executive summary
  static const int photoExtractCostTokens = 2500; // LR/photo vision read

  /// Looks up the monthly cap for [tier], case-insensitively.
  /// Unknown/blank tiers fall back to the Free cap (fail-safe, not
  /// fail-open on cost) so a missing tier field never grants unlimited AI.
  static int capFor(String tier) =>
      monthlyTokenCap[tier.toLowerCase().trim()] ?? monthlyTokenCap['free']!;
}

// ================================================================
// FIREBASE SERVICE wraps all Firebase calls
// ================================================================

// ══════════════════════════════════════════════════════════════════
// TRANSLATION SYSTEM
// Covers all visible UI strings. Add more keys to extend.
// ══════════════════════════════════════════════════════════════════
const Map<String, Map<String, String>> _translations = {
  'en': {
    'home': 'Home',
    'find_load': 'Find Load',
    'post_load': 'Post Load',
    'ledger': 'Ledger',
    'fleet': 'Fleet',
    'drivers': 'Drivers',
    'new_trip': 'New Trip',
    'track': 'Track',
    'export': 'Export',
    'quick_actions': 'Quick Actions',
    'in_transit': 'In Transit',
    'pending': 'Pending',
    'overdue': 'Overdue',
    'settled': 'Settled',
    'due_soon': 'Due Soon',
    'all': 'All',
    'party': 'Party',
    'vehicle': 'Vehicle',
    'good_morning': 'Good Morning',
    'good_afternoon': 'Good Afternoon',
    'good_evening': 'Good Evening',
    'total_revenue': 'Total Revenue',
    'profit': 'Profit',
    'expenses': 'Expenses',
    'collect_now': 'Collect now',
    'all_clear': 'All clear ✓',
    'add_vehicle': 'Add vehicle',
    'none_active': 'None active',
    'view': 'View →',
    'see_all': 'See All →',
    'new_entry': 'New Trip',
    'save': 'Save',
    'cancel': 'Cancel',
    'freight': 'Freight',
    'amount_due': 'Amount Due',
    'balance_due': 'Balance Due',
    'dispatch': 'Mark as Dispatched',
    'booked': 'Booked',
    'load_board': 'Load Board',
    'post_a_load': 'Post a Load',
    'maintenance': 'Maintenance',
    'ai_copilot': 'AI Copilot',
    'finance': 'Finance',
    'reconcile': 'Reconcile',
    'routes': 'Routes',
    'tap_collect': 'Tap to collect now',
    'days_due': 'Due in {n} days',
  },
  'hi': {
    'home': 'होम',
    'find_load': 'लोड खोजें',
    'post_load': 'लोड पोस्ट',
    'ledger': 'खाता',
    'fleet': 'वाहन बेड़ा',
    'drivers': 'चालक',
    'new_trip': 'नई यात्रा',
    'track': 'ट्रैक करें',
    'export': 'निर्यात',
    'quick_actions': 'त्वरित कार्य',
    'in_transit': 'रास्ते में',
    'pending': 'बकाया',
    'overdue': 'अतिदेय',
    'settled': 'चुकाया',
    'due_soon': 'जल्द देय',
    'all': 'सभी',
    'party': 'पार्टी',
    'vehicle': 'वाहन',
    'good_morning': 'सुप्रभात',
    'good_afternoon': 'नमस्ते',
    'good_evening': 'शुभ संध्या',
    'total_revenue': 'कुल आमदनी',
    'profit': 'मुनाफा',
    'expenses': 'खर्च',
    'collect_now': 'अभी लो',
    'all_clear': 'सब साफ ✓',
    'add_vehicle': 'वाहन जोड़ें',
    'none_active': 'कोई नहीं',
    'view': 'देखें →',
    'see_all': 'सभी देखें →',
    'new_entry': 'नई यात्रा',
    'save': 'सेव करें',
    'cancel': 'रद्द करें',
    'freight': 'भाड़ा',
    'amount_due': 'बकाया रकम',
    'balance_due': 'शेष राशि',
    'dispatch': 'रवाना करें',
    'booked': 'बुक हुआ',
    'load_board': 'लोड बोर्ड',
    'post_a_load': 'लोड डालें',
    'maintenance': 'रखरखाव',
    'ai_copilot': 'AI सहायक',
    'finance': 'वित्त',
    'reconcile': 'मिलान',
    'routes': 'रूट',
    'tap_collect': 'अभी कलेक्ट करें',
    'days_due': '{n} दिन में देय',
  },
  'gu': {
    'home': 'હોમ',
    'find_load': 'ભાર શોધો',
    'post_load': 'ભાર પોસ્ટ',
    'ledger': 'ખાતું',
    'fleet': 'વાહન કાફલો',
    'drivers': 'ડ્રાઇવર',
    'new_trip': 'નવી મુસાફરી',
    'track': 'ટ્રેક',
    'export': 'નિકાસ',
    'quick_actions': 'ઝડપી કામ',
    'in_transit': 'રસ્તામાં',
    'pending': 'બાકી',
    'overdue': 'મોડું',
    'settled': 'ચૂકવ્યું',
    'due_soon': 'જલ્દી બાકી',
    'all': 'બધા',
    'party': 'પક્ષ',
    'vehicle': 'વાહન',
    'good_morning': 'શુભ સવાર',
    'good_afternoon': 'શુભ બપોર',
    'good_evening': 'શુભ સાંજ',
    'total_revenue': 'કુલ આવક',
    'profit': 'નફો',
    'expenses': 'ખર્ચ',
    'collect_now': 'અત્યારે લો',
    'all_clear': 'બધું ઠીક ✓',
    'add_vehicle': 'વાહન ઉમેરો',
    'none_active': 'કોઈ નહીં',
    'view': 'જુઓ →',
    'see_all': 'બધા જુઓ →',
    'new_entry': 'નવી મુસાફરી',
    'save': 'સેવ',
    'cancel': 'રદ',
    'freight': 'ભાડું',
    'amount_due': 'બાકી રકમ',
    'balance_due': 'બાકી',
    'dispatch': 'રવાના કરો',
    'booked': 'બુક',
    'load_board': 'ભાર બોર્ડ',
    'post_a_load': 'ભાર નાખો',
    'maintenance': 'જાળવણી',
    'ai_copilot': 'AI સહાયક',
    'finance': 'નાણા',
    'reconcile': 'મેળ',
    'routes': 'રૂટ',
    'tap_collect': 'અત્યારે કલેક્ટ કરો',
    'days_due': '{n} દિવસમાં',
  },
  'pa': {
    'home': 'ਹੋਮ',
    'find_load': 'ਲੋਡ ਲੱਭੋ',
    'post_load': 'ਲੋਡ ਪੋਸਟ',
    'ledger': 'ਖਾਤਾ',
    'fleet': 'ਵਾਹਨ ਬੇੜਾ',
    'drivers': 'ਡਰਾਈਵਰ',
    'new_trip': 'ਨਵੀਂ ਯਾਤਰਾ',
    'track': 'ਟ੍ਰੈਕ',
    'export': 'ਨਿਰਯਾਤ',
    'quick_actions': 'ਤੇਜ਼ ਕੰਮ',
    'in_transit': 'ਰਾਹ ਵਿੱਚ',
    'pending': 'ਬਕਾਇਆ',
    'overdue': 'ਦੇਰੀ',
    'settled': 'ਅਦਾ',
    'due_soon': 'ਜਲਦ ਦੇਣਾ',
    'all': 'ਸਭ',
    'party': 'ਧਿਰ',
    'vehicle': 'ਵਾਹਨ',
    'good_morning': 'ਸਤ ਸ੍ਰੀ ਅਕਾਲ',
    'good_afternoon': 'ਸਤ ਸ੍ਰੀ ਅਕਾਲ',
    'good_evening': 'ਸਤ ਸ੍ਰੀ ਅਕਾਲ',
    'total_revenue': 'ਕੁੱਲ ਆਮਦਨ',
    'profit': 'ਮੁਨਾਫ਼ਾ',
    'expenses': 'ਖਰਚ',
    'collect_now': 'ਹੁਣੇ ਲਓ',
    'all_clear': 'ਸਭ ਠੀਕ ✓',
    'add_vehicle': 'ਵਾਹਨ ਜੋੜੋ',
    'none_active': 'ਕੋਈ ਨਹੀਂ',
    'view': 'ਵੇਖੋ →',
    'see_all': 'ਸਭ ਵੇਖੋ →',
    'new_entry': 'ਨਵੀਂ ਯਾਤਰਾ',
    'save': 'ਸੇਵ',
    'cancel': 'ਰੱਦ',
    'freight': 'ਭਾੜਾ',
    'amount_due': 'ਬਕਾਇਆ',
    'balance_due': 'ਬਕਾਇਆ',
    'dispatch': 'ਰਵਾਨਾ ਕਰੋ',
    'booked': 'ਬੁੱਕ',
    'load_board': 'ਲੋਡ ਬੋਰਡ',
    'post_a_load': 'ਲੋਡ ਪਾਓ',
    'maintenance': 'ਰੱਖ-ਰਖਾਅ',
    'ai_copilot': 'AI ਸਹਾਇਕ',
    'finance': 'ਵਿੱਤ',
    'reconcile': 'ਮਿਲਾਨ',
    'routes': 'ਰੂਟ',
    'tap_collect': 'ਹੁਣੇ ਕਲੈਕਟ ਕਰੋ',
    'days_due': '{n} ਦਿਨਾਂ ਵਿੱਚ',
  },
  'mr': {
    'home': 'होम',
    'find_load': 'भार शोधा',
    'post_load': 'भार टाका',
    'ledger': 'खाते',
    'fleet': 'वाहन ताफा',
    'drivers': 'चालक',
    'new_trip': 'नवी सफर',
    'track': 'ट्रॅक',
    'export': 'निर्यात',
    'quick_actions': 'जलद कामे',
    'in_transit': 'प्रवासात',
    'pending': 'बाकी',
    'overdue': 'थकीत',
    'settled': 'भरले',
    'due_soon': 'लवकरच देणे',
    'all': 'सर्व',
    'party': 'पक्ष',
    'vehicle': 'वाहन',
    'good_morning': 'शुभ प्रभात',
    'good_afternoon': 'शुभ दुपार',
    'good_evening': 'शुभ संध्याकाळ',
    'total_revenue': 'एकूण उत्पन्न',
    'profit': 'नफा',
    'expenses': 'खर्च',
    'collect_now': 'आत्ता घ्या',
    'all_clear': 'सर्व ठीक ✓',
    'add_vehicle': 'वाहन जोडा',
    'none_active': 'कोणी नाही',
    'view': 'पहा →',
    'see_all': 'सर्व पहा →',
    'new_entry': 'नवी सफर',
    'save': 'सेव्ह',
    'cancel': 'रद्द',
    'freight': 'भाडे',
    'amount_due': 'बाकी रक्कम',
    'balance_due': 'शिल्लक',
    'dispatch': 'रवाना करा',
    'booked': 'बुक',
    'load_board': 'भार बोर्ड',
    'post_a_load': 'भार टाका',
    'maintenance': 'देखभाल',
    'ai_copilot': 'AI सहाय्यक',
    'finance': 'वित्त',
    'reconcile': 'जुळवणी',
    'routes': 'मार्ग',
    'tap_collect': 'आत्ता कलेक्ट करा',
    'days_due': '{n} दिवसांत',
  },
};

/// Returns the translated string for [key] based on the current app locale.
/// Falls back to English if the language or key is not found.
String t(String key, {String n = ''}) {
  final lang = appLocale.value.languageCode;
  final map = _translations[lang] ?? _translations['en']!;
  String result = map[key] ?? _translations['en']![key] ?? key;
  if (n.isNotEmpty) result = result.replaceAll('{n}', n);
  return result;
}
