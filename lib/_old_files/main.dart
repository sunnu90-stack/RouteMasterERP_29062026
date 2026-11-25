// ================================================================
// ROUTE MASTER ERP v5.0 - SINGLE MASTER FILE
// ================================================================
// ignore_for_file: dead_code, unused_field, unused_local_variable, unused_element, unnecessary_brace_in_string_interps, deprecated_member_use, use_build_context_synchronously, uri_does_not_exist, import_of_non_library
// pubspec.yaml dependencies (EXACT VERSIONS — do not change):
//   http: ^1.6.0
//   intl: ^0.20.2
//   shared_preferences: ^2.5.5
//   pdf: ^3.12.0
//   printing: ^5.14.3
//   image_picker: ^1.0.7          (camera / gallery)
//   file_picker: ^11.0.2          (document upload)
//   url_launcher: ^6.3.2          (open external links)
//   path_provider: ^2.1.5         (temp file storage)
//   share_plus: ^12.0.2           (share files - v12 uses SharePlus.instance API)
//   fl_chart: ^1.2.0              (charts - available if needed)
//   csv: ^8.0.0                   (CSV export helper)
//   firebase_core: ^4.6.0
//   firebase_auth: ^6.3.0
//   cloud_firestore: ^6.1.3
//   firebase_storage: ^13.1.0
//   firebase_messaging: ^16.1.3   (FCM push notifications)
//   google_maps_flutter: ^2.16.0  (real GPS map in tracking screen)
// ================================================================
// ADMIN ACCESS: Tap "ROUTE MASTER" in AppBar 7x within 3 seconds
// DEV PIN: RM@Dev#2025! (change before going live)
// OCR: Uses Google Cloud Vision API - enable it in Google Cloud Console
// ================================================================
// MULTI-DEVICE SYNC: v5.0 now streams ledgers, drivers, fleet, subscriptions,
//   KredX status, and admin notifications in real-time via Firestore.
//   Any change on Phone A appears instantly on Phone B without refresh.
//   Admin broadcast notifications appear as in-app banners on all devices.
//   For true FCM push (app closed), add firebase_messaging and a Cloud Function.
// ================================================================

import 'package:liquid_logistics/erp_features.dart';
// Firebase
import 'firebase_options.dart';
import 'theme_provider.dart';
import 'universal_scaffold.dart';

import 'theme_picker.dart';
// OCR via Google Cloud Vision API (uses existing Maps API key billing)

// ============================================================
// PART FILES -- split from original monolith by feature area
// All files share this library's imports and private scope.
// ============================================================
part 'src/config.dart';
part 'src/firebase_service.dart';
part 'src/enums.dart';
part 'src/models.dart';
part 'src/engines.dart';
part 'src/ai.dart';
part 'src/app.dart';
part 'src/auth_screens.dart';
part 'src/main_shell.dart';
part 'src/search_fields.dart';
part 'src/feature_screens.dart';
part 'src/painters.dart';
