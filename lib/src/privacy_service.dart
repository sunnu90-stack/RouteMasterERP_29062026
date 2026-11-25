// ============================================================
// privacy_service.dart  —  part of liquid_logistics main library
// Add as NEW file at:  lib/src/privacy_service.dart
// Register in main.dart with:  part 'src/privacy_service.dart';
// ------------------------------------------------------------
// Implements the DPDP Act 2023 data-principal duties you owe users:
//   • Consent capture + versioned consent ledger
//   • Right to access   (export my data)
//   • Right to erasure  (delete my account & data)
// ============================================================
part of 'package:liquid_logistics/main.dart';

class PrivacyService {
  // Bump this when your privacy notice text changes; re-prompts users.
  static const String currentPolicyVersion = '2026-08-v1';

  static String _locationConsentKey(String? uid) =>
      'consent_location_${uid ?? 'local'}';

  // ── CONSENT ────────────────────────────────────────────────
  static Future<bool> hasValidConsent() async {
    final v = await SecureStore.read('consent_version');
    return v == currentPolicyVersion;
  }

  static Future<void> recordConsent({
    required bool location,
    required bool documents,
    required bool notifications,
  }) async {
    await SecureStore.write('consent_version', currentPolicyVersion);
    final uid = FirebaseService.currentUser?.uid;
    await SecureStore.write(_locationConsentKey(uid), location.toString());
    if (uid == null) return;
    // Store an auditable consent record (required to demonstrate consent).
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('consents')
          .doc(currentPolicyVersion)
          .set({
        'policyVersion': currentPolicyVersion,
        'purposes': {
          'location': location,
          'documents': documents,
          'notifications': notifications,
        },
        'grantedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Future<bool> hasLocationConsent() async {
    final uid = FirebaseService.currentUser?.uid;
    final savedConsent = await SecureStore.read(_locationConsentKey(uid));
    if (savedConsent != null) return savedConsent == 'true';
    if (uid == null) return false;
    try {
      final consent = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('consents')
          .doc(currentPolicyVersion)
          .get();
      final purposes = consent.data()?['purposes'];
      final allowed = purposes is Map && purposes['location'] == true;
      await SecureStore.write(_locationConsentKey(uid), allowed.toString());
      return allowed;
    } catch (e) {
      debugPrint('Could not read saved location consent: $e');
      return false;
    }
  }

  // ── RIGHT TO ACCESS: export everything we hold about this user ──
  static Future<Map<String, dynamic>> exportMyData() async {
    final uid = FirebaseService.currentUser?.uid;
    if (uid == null) return {};
    final db = FirebaseFirestore.instance;
    final out = <String, dynamic>{
      'exportedAt': DateTime.now().toIso8601String(),
      'uid': uid,
    };
    try {
      final profile = await db.collection('users').doc(uid).get();
      out['profile'] = profile.data();
      for (final sub in ['ledgers', 'drivers', 'fleet', 'consents']) {
        final snap = await db.collection('users/$uid/$sub').get();
        out[sub] = snap.docs.map((d) => d.data()).toList();
      }
    } catch (e) {
      out['error'] = 'partial export: $e';
    }
    return out;
  }

  // ── RIGHT TO ERASURE: delete account + all data + storage files ──
  static Future<bool> deleteMyAccountAndData() async {
    final user = FirebaseService.currentUser;
    if (user == null) return false;
    final uid = user.uid;
    final db = FirebaseFirestore.instance;
    try {
      // 1. Delete Firestore subcollections.
      for (final sub in ['ledgers', 'drivers', 'fleet', 'consents']) {
        final snap = await db.collection('users/$uid/$sub').get();
        for (final d in snap.docs) {
          await d.reference.delete();
        }
      }
      // 2. Delete the profile document.
      await db.collection('users').doc(uid).delete();
      // 3. Delete this user's Storage folder (KYC docs etc.).
      try {
        final folder = FirebaseStorage.instance.ref(uid);
        final items = await folder.listAll();
        for (final ref in items.items) {
          await ref.delete();
        }
        for (final prefix in items.prefixes) {
          final sub = await prefix.listAll();
          for (final ref in sub.items) {
            await ref.delete();
          }
        }
      } catch (_) {}
      // 4. Wipe on-device secrets (keys, PIN hash, consent).
      await SecureStore.wipeAll();
      // 5. Finally delete the auth account itself.
      await user.delete();
      return true;
    } catch (e) {
      debugPrint('deleteMyAccountAndData error: $e');
      return false;
    }
  }
}
