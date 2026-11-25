// ============================================================
// app.dart  —  part of liquid_logistics main library
// Auto-extracted from main_v23_8.dart (original lines 6611-6813)
// DO NOT add imports here — all imports live in main.dart
// ============================================================
part of 'package:liquid_logistics/main.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFFF6FAFF),
      statusBarIconBrightness: Brightness.dark));
  // Initialize Firebase - requires google-services.json (Android) / GoogleService-Info.plist (iOS)
  try {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
    // App Check: blocks stolen API keys from being used outside this real app.
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.playIntegrity,
    );
    await FirebaseService.init();
    debugPrint('OK Firebase ready - cloud sync active');
    // FCM: request notification permissions and subscribe to topics
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.subscribeToTopic('all_users');
    // Handle FCM messages when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM foreground: ${message.notification?.title}');
      // In-app notification is handled by broadcastsStream in _MainShellState
    });
    // Get FCM token for targeted notifications (optional - log for debugging)
    final token = await messaging.getToken();
    debugPrint('FCM Token: $token');
  } catch (e) {
    debugPrint(
        'Warning Firebase not configured - using local storage only: $e');
  }
  // Restore saved language preference
  final prefs = await SharedPreferences.getInstance();
  final savedLang = prefs.getString('rm_language') ?? 'en';
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
  appLocale.value = localeMap[savedLang] ?? const Locale('en');
  runApp(const ProviderScope(child: RouteMasterApp()));
}

// Global language notifier — language change rebuilds the whole app
final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('en'));

class RouteMasterApp extends ConsumerWidget {
  const RouteMasterApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTheme = ref.watch(appThemeProvider);
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (_, locale, __) => MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en'),
          Locale('hi'),
          Locale('gu'),
          Locale('pa'),
          Locale('mr'),
          Locale('ta'),
          Locale('te'),
          Locale('kn'),
          Locale('bn'),
        ],
        title: 'NavGati ERP',
        theme: ThemeHelper.materialTheme(AppThemeType.light),
        darkTheme: ThemeHelper.materialTheme(AppThemeType.dark),
        themeMode: ThemeHelper.themeMode(activeTheme),
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: ThemeHelper.systemOverlayFor(activeTheme),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const SplashScreen(),
        debugShowCheckedModeBanner: false,
      ), // MaterialApp
    ); // ValueListenableBuilder
  }
}

// ================================================================
// SPLASH
// ================================================================
