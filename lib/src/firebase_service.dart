// ============================================================
// firebase_service.dart  —  part of liquid_logistics main library
// Auto-extracted from main_v23_8.dart (original lines 263-1069)
// DO NOT add imports here — all imports live in main.dart
// ============================================================
part of 'package:liquid_logistics/main.dart';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static FirebaseAuth get auth => _auth;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static bool _ready = false;

  static bool get isReady => _ready;
  static User? get currentUser => _auth.currentUser;

  static Future<void> init() async {
    try {
      _ready = Firebase.apps.isNotEmpty;
    } catch (_) {
      _ready = false;
    }
  }

  // OTP PHONE AUTH
  static Future<void> sendOTP({
    required String phone,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    if (!_ready) {
      onError(
          "Firebase not initialized. Check google-services.json is in android/app/");
      return;
    }
    // verifyPhoneNumber returns immediately on Android; callbacks fire async.
    // We use a Completer so we can properly await codeSent or verificationFailed.
    bool callbackFired = false;
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 120),
        // forceResendingToken allows resending without waiting
        forceResendingToken: null,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android auto-verify (SMS retrieval or Play Integrity): sign in silently
          callbackFired = true;
          try {
            await _auth.signInWithCredential(credential);
            // Signal to login screen that auto-verification completed
            onCodeSent('AUTO_VERIFIED');
          } catch (_) {}
        },
        verificationFailed: (FirebaseAuthException e) {
          String msg = e.message ?? 'OTP failed';
          if (e.code == 'invalid-phone-number') {
            msg = 'Invalid phone number. Use +91XXXXXXXXXX format.';
          } else if (e.code == 'too-many-requests') {
            msg = 'Too many OTP requests. Wait 1 hour and try again.';
          } else if (e.code == 'app-not-authorized') {
            msg =
                'App not authorized. Add SHA-1 fingerprint to Firebase Console:\n'
                '1. Run: keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android\n'
                '2. Copy SHA-1 → Firebase Console → Project Settings → Your Android App → Add fingerprint';
          } else if (e.code == 'network-request-failed') {
            msg = 'Network error. Check internet connection.';
          } else if (e.code == 'quota-exceeded') {
            msg =
                'SMS quota exceeded for today. Try tomorrow or use test numbers in Firebase Console.';
          } else if (e.code == 'missing-client-identifier') {
            msg =
                'SHA-1 fingerprint missing. Add it in Firebase Console → Project Settings → Android App.';
          }
          onError(msg);
        },
        codeSent: (String verificationId, int? resendToken) {
          callbackFired = true;
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Auto-retrieval timed out - user needs to type OTP manually
          // Only fire onCodeSent if it hasn't been called yet
          if (!callbackFired) {
            callbackFired = true;
            onCodeSent(verificationId);
          }
        },
        // For web: reCAPTCHA v2 is used automatically by Firebase SDK.
        // Ensure your Firebase project has the web app's domain in Authorized Domains.
      );
    } catch (e) {
      onError('OTP failed: ${e.toString().replaceAll('Exception: ', '')}');
    }
  }

  static Future<bool> verifyOTP(
      {required String verificationId, required String otp}) async {
    try {
      final cred = PhoneAuthProvider.credential(
          verificationId: verificationId, smsCode: otp.trim());
      await _auth.signInWithCredential(cred);
      return true;
    } on FirebaseAuthException catch (e) {
      debugPrint("OTP verify error: ${e.code} - ${e.message}");
      return false;
    } catch (_) {
      return false;
    }
  }

  //  FIRESTORE sync ledgers, fleet, drivers
  static String get _uid => currentUser?.uid ?? 'local';
  static String? _dataOwnerUidOverride;
  static String get dataOwnerUid => (_dataOwnerUidOverride?.isNotEmpty ?? false)
      ? _dataOwnerUidOverride!
      : _uid;

  static void setDataOwnerUid(String? uid) {
    final cleaned = uid?.trim() ?? '';
    _dataOwnerUidOverride = cleaned.isEmpty ? null : cleaned;
  }

  static Future<void> saveLedgers(List<TripLedger> ledgers) async {
    if (!_ready || currentUser == null) return;
    try {
      final batch = _db.batch();
      final col = _db.collection('users/$dataOwnerUid/ledgers');
      for (final l in ledgers) {
        batch.set(col.doc(l.id), l.toJson());
      }
      await batch.commit();
    } catch (e) {
      debugPrint('saveLedgers error: $e');
    }
  }

  static Future<List<TripLedger>> loadLedgers() async {
    if (!_ready || currentUser == null) return [];
    try {
      final snap = await _db
          .collection('users/$dataOwnerUid/ledgers')
          .orderBy('date', descending: true)
          .get();
      return snap.docs.map((d) => TripLedger.fromJson(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveDrivers(List<Driver> drivers) async {
    if (!_ready || currentUser == null) return;
    try {
      final batch = _db.batch();
      final col = _db.collection('users/$dataOwnerUid/drivers');
      for (final d in drivers) {
        batch.set(col.doc(d.id), d.toJson());
      }
      await batch.commit();
    } catch (_) {}
  }

  // ── DELETE A DRIVER (retention / DPDP: remove data no longer needed) ──
  // Removes the driver's private record AND their public lookup entries
  // (phone-keyed and DL-keyed) so no personal data lingers after removal.
  static Future<bool> deleteDriver(Driver driver) async {
    if (!_ready || currentUser == null) return false;
    try {
      // 1. Private record under the owner's account.
      await _db
          .collection('users/$dataOwnerUid/drivers')
          .doc(driver.id)
          .delete();
      // 2. Public phone-keyed lookup entry.
      if (driver.phone.isNotEmpty) {
        final phoneKey = driver.phone.replaceAll(RegExp(r'[^0-9]'), '');
        if (phoneKey.isNotEmpty) {
          await _db.collection('publicDrivers').doc(phoneKey).delete();
        }
      }
      // 3. Public DL-keyed lookup entry.
      if (driver.dlNum.isNotEmpty) {
        final dlKey =
            driver.dlNum.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
        await _db.collection('publicDrivers').doc('DL_$dlKey').delete();
      }
      // 4. Any uploaded KYC files for this driver (if cloud upload is enabled).
      try {
        final folder = _storage.ref('$dataOwnerUid/${driver.id}');
        final items = await folder.listAll();
        for (final ref in items.items) {
          await ref.delete();
        }
      } catch (_) {}
      return true;
    } catch (e) {
      debugPrint('deleteDriver error: $e');
      return false;
    }
  }

  static Future<void> saveFleet(List<Asset> fleet) async {
    if (!_ready || currentUser == null) return;
    try {
      final batch = _db.batch();
      final col = _db.collection('users/$dataOwnerUid/fleet');
      for (final a in fleet) {
        batch.set(col.doc(a.id), a.toJson());
      }
      await batch.commit();
    } catch (_) {}
  }

  // ── PROFILE SYNC ──────────────────────────────────────────────
  static Future<void> saveProfile(Map<String, dynamic> profileJson) async {
    if (!_ready || currentUser == null) return;
    try {
      await _db.collection('users').doc(_uid).set(
          {...profileJson, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> loadProfile() async {
    if (!_ready || currentUser == null) return null;
    try {
      final doc = await _db.collection('users').doc(_uid).get();
      return doc.exists ? doc.data() : null;
    } catch (_) {
      return null;
    }
  }

  // ── REAL-TIME STREAMS ─────────────────────────────────────────
  static Stream<List<TripLedger>> ledgersStream() {
    if (!_ready || currentUser == null) return const Stream.empty();
    return _db
        .collection('users/$dataOwnerUid/ledgers')
        .snapshots()
        .handleError((e) {
      debugPrint('ledgersStream error: $e');
    }).map((s) {
      final list = s.docs.map((d) => TripLedger.fromJson(d.data())).toList();
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  static Stream<List<Driver>> driversStream() {
    if (!_ready || currentUser == null) return const Stream.empty();
    return _db
        .collection('users/$dataOwnerUid/drivers')
        .snapshots()
        .map((s) => s.docs.map((d) => Driver.fromJson(d.data())).toList());
  }

  static Stream<List<Asset>> fleetStream() {
    if (!_ready || currentUser == null) return const Stream.empty();
    return _db
        .collection('users/$dataOwnerUid/fleet')
        .snapshots()
        .map((s) => s.docs.map((d) => Asset.fromJson(d.data())).toList());
  }

  // ── SUBSCRIPTION SYNC ─────────────────────────────────────────
  static Future<void> saveSubscription(Map<String, dynamic> subJson) async {
    if (!_ready || currentUser == null) return;
    try {
      await _db.collection('users').doc(_uid).set(
          {'subscription': subJson, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true));
    } catch (_) {}
  }

  static Stream<DocumentSnapshot?> subscriptionStream() {
    if (!_ready || currentUser == null) return const Stream.empty();
    return _db
        .collection('users')
        .doc(_uid)
        .snapshots()
        .map((d) => d.exists ? d : null);
  }

  // ── KREDX SYNC ────────────────────────────────────────────────
  static Future<void> saveKredXApp(KredXApplication app) async {
    if (!_ready || currentUser == null) return;
    try {
      await _db.collection('kredxApplications').doc(app.id).set({
        ...app.toJson(),
        'uid': _uid,
        'updatedAt': FieldValue.serverTimestamp()
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static Stream<List<KredXApplication>> kredxStream() {
    if (!_ready || currentUser == null) return const Stream.empty();
    return _db
        .collection('kredxApplications')
        .where('uid', isEqualTo: _uid)
        .snapshots()
        .map((s) =>
            s.docs.map((d) => KredXApplication.fromJson(d.data())).toList());
  }

  // ── ADMIN: FCM BROADCAST NOTIFICATION ─────────────────────────
  // Writes to 'adminNotifications' collection; Cloud Functions or server
  // should pick this up and send via FCM. As a direct fallback, we also
  // write the notification to every user's 'notifications' subcollection
  // so the app can poll/stream it without Cloud Functions.
  static Future<bool> adminBroadcastNotification({
    required String title,
    required String body,
    String target = 'all_users', // 'all_users' | 'paid_tier' | specific topic
    Map<String, dynamic> data = const {},
  }) async {
    if (!_ready) return false;
    try {
      final notif = {
        'title': title,
        'body': body,
        'target': target,
        'data': data,
        'sentAt': FieldValue.serverTimestamp(),
        'sentBy': _uid,
        'status': 'queued',
      };
      final broadcastRef = _db.collection('broadcasts').doc();
      final batch = _db.batch();
      batch.set(_db.collection('adminNotifications').doc(broadcastRef.id), {
        ...notif,
        'broadcastId': broadcastRef.id,
      });
      batch.set(broadcastRef, {
        ...notif,
        'broadcastId': broadcastRef.id,
        'isRead': false,
      });
      await batch.commit();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Stream<QuerySnapshot> broadcastsStream({DateTime? sinceTime}) {
    if (!_ready) return const Stream.empty();
    var q = _db
        .collection('broadcasts')
        .orderBy('sentAt', descending: true)
        .limit(20);
    // Only show broadcasts sent after the app opened — prevents flooding on login
    if (sinceTime != null) {
      q = q.where('sentAt', isGreaterThan: Timestamp.fromDate(sinceTime));
    }
    return q.snapshots();
  }

  // ── ADMIN: KREDX APPROVE/REJECT/DISBURSE (admin writes to shared collection) ──
  static Future<void> adminUpdateKredX(String appId, KredXStatus status) async {
    if (!_ready) return;
    try {
      await _db.collection('kredxApplications').doc(appId).update({
        'status': status.index,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _uid,
      });
    } catch (_) {}
  }

  // ── PARTY TRUST / BLACKLIST SYSTEM ──────────────────────────
  static Future<void> savePartyTrust({
    required String uid,
    required String partyName,
    required int trustPoints,
    required bool isBlacklisted,
    String blacklistReason = '',
    String phone = '',
    String gstin = '',
    List<Map<String, dynamic>> violations = const [],
    bool isVerified = false,
  }) async {
    if (!_ready) return;
    final safeKey = partyName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    // Private: per-user record
    await _db.collection('partyTrust').doc('${uid}_$safeKey').set({
      'uid': uid,
      'partyName': partyName,
      'trustPoints': trustPoints,
      'isBlacklisted': isBlacklisted,
      'blacklistReason': blacklistReason,
      'violations': violations,
      'isVerified': isVerified,
      'phone': phone,
      'gstin': gstin,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    // PUBLIC: GSTIN (business id) ONLY. No phone, name, or accusation text.
    // Limits DPDP exposure + defamation risk. Personal notes stay private above.
    final publicKey = gstin.isNotEmpty
        ? gstin.toUpperCase().replaceAll(RegExp(r'\s'), '')
        : '';
    if (publicKey.isNotEmpty) {
      await _db.collection('publicConsignors').doc(publicKey).set({
        'gstin': gstin,
        'trustPoints': trustPoints,
        'flagged': trustPoints <= 40 || isBlacklisted,
        'isVerified': isVerified,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    // name-keyed / phone-keyed public docs removed on purpose (were leaking PII).
  }

  // PUBLIC: look up a consignor by phone, GSTIN, or name
  static Future<Map<String, dynamic>?> lookupPublicConsignor(
      String query) async {
    if (!_ready || query.isEmpty) return null;
    try {
      // Public lookup is now GSTIN-only (no phone/name search — that data is
      // no longer public). Returns { gstin, trustPoints, flagged, isVerified }.
      final q = query.trim().toUpperCase().replaceAll(RegExp(r'\s'), '');
      final exact = await _db.collection('publicConsignors').doc(q).get();
      if (exact.exists) return exact.data();
    } catch (e) {
      debugPrint('lookupPublicConsignor error: $e');
    }
    return null;
  }

  static Stream<QuerySnapshot> partyTrustStream(String uid) {
    if (!_ready) return const Stream.empty();
    return _db
        .collection('partyTrust')
        .where('uid', isEqualTo: uid)
        .snapshots();
  }

  // ── COMPLAINTS / MERIT-DEMERIT SYSTEM ────────────────────────
  static Future<void> submitComplaint({
    required String reporterUid,
    required String reporterName,
    required String targetName, // driver name or party/consignor name
    required String targetType, // 'driver' | 'consignor' | 'fleet_owner'
    required String targetId, // driver id or uid
    required String reason,
    required int suggestedPoints, // negative = demerit, positive = merit
    String? tripId,
    String? vehicleNo,
  }) async {
    if (!_ready) return;
    await _db.collection('complaints').add({
      'reporterUid': reporterUid,
      'reporterName': reporterName,
      'targetName': targetName,
      'targetType': targetType,
      'targetId': targetId,
      'reason': reason,
      'suggestedPoints': suggestedPoints,
      'tripId': tripId ?? '',
      'vehicleNo': vehicleNo ?? '',
      'status': 'pending', // pending | approved | rejected
      'adminNote': '',
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  static Stream<QuerySnapshot> complaintsStream() {
    if (!_ready) return const Stream.empty();
    return _db
        .collection('complaints')
        .orderBy('submittedAt', descending: true)
        .limit(50)
        .snapshots();
  }

  static Future<void> resolveComplaint(
    String complaintId,
    bool approve,
    String adminNote, {
    String? driverUid,
    String? driverId,
    int? pointsToApply,
  }) async {
    if (!_ready) return;
    final complaintDoc =
        await _db.collection('complaints').doc(complaintId).get();
    final complaint = complaintDoc.data() ?? {};
    final targetType = (complaint['targetType'] as String? ?? '').toLowerCase();
    final targetName = complaint['targetName'] as String? ?? '';
    final targetId = complaint['targetId'] as String? ?? '';
    final reason = complaint['reason'] as String? ?? adminNote;
    final points = pointsToApply ?? (complaint['suggestedPoints'] as int? ?? 0);
    await _db.collection('complaints').doc(complaintId).update({
      'status': approve ? 'approved' : 'rejected',
      'adminNote': adminNote,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    // If approved and it's a driver complaint, apply points
    if (approve && driverUid != null && driverId != null) {
      final doc =
          await _db.collection('users/$driverUid/drivers').doc(driverId).get();
      if (doc.exists) {
        final current = doc.data()!['trustPoints'] as int? ?? 100;
        final currentViolations =
            (doc.data()!['violations'] as List<dynamic>? ?? [])
                .whereType<Map<String, dynamic>>()
                .toList();
        final nextViolations = points < 0
            ? [
                ...currentViolations,
                {
                  'reason': reason,
                  'points': points.abs(),
                  'date': DateTime.now().toIso8601String()
                }
              ]
            : currentViolations;
        final newPts = (current + points).clamp(0, 100).toInt();
        final blacklist = newPts <= 0 || nextViolations.length >= 3;
        await _db.collection('users/$driverUid/drivers').doc(driverId).update({
          'trustPoints': newPts,
          'violations': nextViolations,
          'isBlacklisted': blacklist,
          'blacklistReason': blacklist
              ? (newPts <= 0
                  ? 'Auto-blacklisted: trust score reached 0'
                  : 'Auto-blacklisted: 3 admin-approved demerits')
              : (doc.data()!['blacklistReason'] ?? ''),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    if (approve && targetType == 'consignor' && targetName.isNotEmpty) {
      final uid = targetId.isNotEmpty ? targetId : 'global';
      final safeKey = targetName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final ref = _db.collection('partyTrust').doc('${uid}_$safeKey');
      final doc = await ref.get();
      final data = doc.data() ?? {};
      final current = data['trustPoints'] as int? ?? 100;
      final currentViolations = (data['violations'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .toList();
      final nextViolations = points < 0
          ? [
              ...currentViolations,
              {
                'reason': reason,
                'points': points.abs(),
                'date': DateTime.now().toIso8601String()
              }
            ]
          : currentViolations;
      final newPts = (current + points).clamp(0, 100).toInt();
      final blacklist = newPts <= 0 || nextViolations.length >= 3;
      await ref.set({
        'uid': uid,
        'partyName': targetName,
        'trustPoints': newPts,
        'violations': nextViolations,
        'isBlacklisted': blacklist,
        'blacklistReason': blacklist
            ? (newPts <= 0
                ? 'Auto-blacklisted: trust score reached 0'
                : 'Auto-blacklisted: 3 admin-approved demerits')
            : '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // ── DRIVER BLACKLIST ──────────────────────────────────────────
  static Future<void> saveDriverTrust(String uid, Driver driver) async {
    if (!_ready) return;
    // Private: update this fleet owner's driver record
    await _db.collection('users/$uid/drivers').doc(driver.id).update({
      'isBlacklisted': driver.isBlacklisted,
      'blacklistReason': driver.blacklistReason,
      'trustPoints': driver.trustPoints,
      'isVerifiedBadge': driver.isVerifiedBadge,
      'violations': driver.violations,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // PUBLIC: write to shared collection so any fleet owner can look up this driver
    // Keyed by phone number (primary) and DL number (secondary) for searchability
    if (driver.phone.isNotEmpty) {
      final publicKey = driver.phone.replaceAll(RegExp(r'[^0-9]'), '');
      await _db.collection('publicDrivers').doc(publicKey).set({
        'name': driver.name,
        'phone': driver.phone,
        'dlNum': driver.dlNum,
        'isBlacklisted': driver.isBlacklisted,
        'blacklistReason': driver.blacklistReason,
        'trustPoints': driver.trustPoints,
        'isVerifiedBadge': driver.isVerifiedBadge,
        'violations': driver.violations,
        'reportedByUid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    if (driver.dlNum.isNotEmpty) {
      final dlKey = driver.dlNum.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
      await _db.collection('publicDrivers').doc('DL_$dlKey').set({
        'name': driver.name,
        'phone': driver.phone,
        'dlNum': driver.dlNum,
        'isBlacklisted': driver.isBlacklisted,
        'blacklistReason': driver.blacklistReason,
        'trustPoints': driver.trustPoints,
        'isVerifiedBadge': driver.isVerifiedBadge,
        'violations': driver.violations,
        'reportedByUid': uid,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  // PUBLIC: search driver by phone or DL number
  static Future<Map<String, dynamic>?> lookupPublicDriver(String query) async {
    if (!_ready || query.isEmpty) return null;
    try {
      final q = query.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
      // Try phone first
      final byPhone = await _db.collection('publicDrivers').doc(q).get();
      if (byPhone.exists) return byPhone.data();
      // Try DL number
      final byDl = await _db.collection('publicDrivers').doc('DL_$q').get();
      if (byDl.exists) return byDl.data();
      // Try name search (partial, case-insensitive not native in Firestore — search by prefix)
      final byName = await _db
          .collection('publicDrivers')
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThan: '${query}z')
          .limit(5)
          .get();
      if (byName.docs.isNotEmpty) return byName.docs.first.data();
    } catch (e) {
      debugPrint('lookupPublicDriver error: $e');
    }
    return null;
  }

  // PUBLIC: search ALL reports for a driver (multiple fleet owners may have reported)
  static Future<List<Map<String, dynamic>>> lookupAllDriverReports(
      String phone) async {
    if (!_ready || phone.isEmpty) return [];
    try {
      final q = phone.replaceAll(RegExp(r'[^0-9]'), '');
      final snap = await _db
          .collection('publicDrivers')
          .where('phone', isEqualTo: q)
          .get();
      return snap.docs.map((d) => d.data()).toList();
    } catch (e) {
      return [];
    }
  }

  // ── ADMIN: SIMPLE RESOLVE (used by new admin dashboard) ──────
  static Future<void> resolveComplaintByAdmin(
      String complaintId, String resolution) async {
    try {
      await _db.collection('complaints').doc(complaintId).update({
        'isResolved': true,
        'resolution': resolution,
        'resolvedAt': FieldValue.serverTimestamp(),
        'resolvedBy': _uid,
      });
    } catch (e) {
      debugPrint('resolveComplaintByAdmin error: $e');
    }
  }

  // ── ADMIN: GET ALL USERS ──────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final snap = await _db.collection('users').get();
      return snap.docs.map((d) {
        final data = d.data();
        data['uid'] = d.id;
        return data;
      }).toList();
    } catch (e) {
      debugPrint('getAllUsers error: $e');
      return [];
    }
  }

  // ── ADMIN: CHANGE USER SUBSCRIPTION TIER ─────────────────────
  // Version A — called by old in-app places (SubscriptionTier enum)
  static Future<void> adminSetUserTierEnum(
      String targetUid, SubscriptionTier tier) async {
    if (!_ready) return;
    try {
      await _db.collection('users').doc(targetUid).set({
        'subscription': {'tier': tier.index},
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  // Version B — called by new admin dashboard (int index + expiry date string)
  static Future<void> adminSetUserTier(
      String targetUid, int tierIndex, String expiryDate) async {
    try {
      await _db.collection('users').doc(targetUid).set({
        'subscription': {
          'tier': tierIndex,
          'expiryDate': expiryDate,
          'tripsUsedThisMonth': 0,
          'updatedAt': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('adminSetUserTier error: $e');
    }
  }

  //
  static Future<String?> uploadDocument(
      String localPath, String docName, String vehicleOrDriver) async {
    if (!_ready || currentUser == null) return null;
    if (kIsWeb) return null; // File upload not supported on web
    try {
      final file = File(localPath);
      final ext = localPath.split('.').last;
      // Encrypt bytes on-device before they ever leave the phone (DPDP/H1).
      final plain = await file.readAsBytes();
      final encrypted = await AppCrypto.encryptBytes(plain);
      final ref = _storage.ref(
          '$_uid/$vehicleOrDriver/${docName.replaceAll(' ', '_')}.$ext.enc');
      final task = await ref.putData(
          encrypted, SettableMetadata(contentType: 'application/octet-stream'));
      return await task.ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  //
  static Future<Map<String, dynamic>> getAdminStats() async {
    if (!_ready) return {};
    try {
      final users = await _db.collection('users').get();
      int totalTrips = 0;
      int totalFleet = 0;
      for (final u in users.docs) {
        final trips =
            await _db.collection('users/${u.id}/ledgers').count().get();
        final fleet = await _db.collection('users/${u.id}/fleet').count().get();
        totalTrips += trips.count ?? 0;
        totalFleet += fleet.count ?? 0;
      }
      return {
        'totalUsers': users.docs.length,
        'totalTrips': totalTrips,
        'totalFleet': totalFleet
      };
    } catch (_) {
      return {};
    }
  }

  //
  // Uses same API key as Maps (no extra setup needed)
  static Future<Map<String, String>> extractDocumentText(
      String imagePath) async {
    final result = <String, String>{};
    try {
      // Read image as base64
      if (kIsWeb) return result; // OCR not supported on web
      final bytes = await File(imagePath).readAsBytes();
      final b64 = base64Encode(bytes);

      // Call Google Cloud Vision API - TEXT_DETECTION
      final url =
          'https://vision.googleapis.com/v1/images:annotate?key=${AppConfig.googleMapsApiKey}';
      final body = jsonEncode({
        'requests': [
          {
            'image': {'content': b64},
            'features': [
              {'type': 'TEXT_DETECTION', 'maxResults': 1}
            ]
          }
        ]
      });
      final res = await http
          .post(Uri.parse(url),
              headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        result['error'] = 'Vision API error ${res.statusCode}';
        return result;
      }
      final data = jsonDecode(res.body);
      final textAnnotations =
          data['responses']?[0]?['textAnnotations'] as List?;
      if (textAnnotations == null || textAnnotations.isEmpty) return result;

      final fullText =
          (textAnnotations[0]['description'] as String? ?? '').toUpperCase();
      final lines = fullText
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();

      // Engine Number
      for (final p in [
        RegExp(r'ENGINE\s*(?:NO|NUMBER|NUM|#)[\s:.]*([A-Z0-9]{6,20})'),
        RegExp(r'ENG\.?\s*NO[\s:.]*([A-Z0-9]{6,20})'),
      ]) {
        final m = p.firstMatch(fullText);
        if (m?.group(1) != null) {
          result['engineNo'] = m!.group(1)!.trim();
          break;
        }
      }

      // Chassis / VIN
      for (final p in [
        RegExp(r'CHASSIS\s*(?:NO|NUMBER|NUM)[\s:.]*([A-Z0-9]{10,20})'),
        RegExp(r'(?:VIN|FRAME\s*NO)[\s:.]*([A-Z0-9]{10,20})'),
      ]) {
        final m = p.firstMatch(fullText);
        if (m?.group(1) != null) {
          result['chassisNo'] = m!.group(1)!.trim();
          break;
        }
      }

      // Registration Number
      final regM = RegExp(
              r'([A-Z]{2}[\s\-]?[0-9]{1,2}[\s\-]?[A-Z]{1,3}[\s\-]?[0-9]{1,4})')
          .firstMatch(fullText);
      if (regM != null) result['regNo'] = regM.group(0)!.replaceAll(' ', '-');

      // Expiry date
      for (final p in [
        RegExp(
            r'(?:VALID\s*UPTO?|EXPIR\w*\s*DATE?|UPTO)[\s:.]*([0-9]{1,2}[/\-][0-9]{1,2}[/\-][0-9]{2,4})'),
        RegExp(r'([0-9]{2}[/\-][0-9]{2}[/\-][0-9]{4})'),
      ]) {
        final m = p.firstMatch(fullText);
        if (m?.group(1) != null) {
          result['expiryDate'] = m!.group(1)!.trim();
          break;
        }
      }

      // Insurance company
      final insurerM = RegExp(
              r'(NEW INDIA|NATIONAL INSURANCE|UNITED INDIA|ORIENTAL|BAJAJ ALLIANZ|HDFC ERGO|ICICI LOMBARD|RELIANCE GENERAL|TATA AIG|ROYAL SUNDARAM|SBI GENERAL|IFFCO TOKIO|CHOLA MS)')
          .firstMatch(fullText);
      if (insurerM != null) result['insurer'] = insurerM.group(0)!;

      // Aadhaar - 12 digits in groups of 4
      final aadhaarM =
          RegExp(r'([0-9]{4}\s[0-9]{4}\s[0-9]{4})').firstMatch(fullText);
      if (aadhaarM != null) {
        result['aadhaarNo'] = aadhaarM.group(0)!.replaceAll(' ', '');
      }

      // DL number
      final dlM =
          RegExp(r'([A-Z]{2}[0-9]{2}\s?[0-9]{11})').firstMatch(fullText);
      if (dlM != null) result['dlNo'] = dlM.group(0)!.replaceAll(' ', '');

      // Owner name - line after OWNER/NAME
      for (int i = 0; i < lines.length - 1; i++) {
        if (lines[i].contains('OWNER') || lines[i].contains('NAME OF')) {
          final name = lines[i + 1].replaceAll(RegExp(r'[^A-Z\s]'), '').trim();
          if (name.length > 3) {
            result['ownerName'] = name;
            break;
          }
        }
      }
    } catch (e) {
      result['error'] = e.toString();
    }
    return result;
  }

  //
  static Stream<List<MarketLoad>> marketLoadsStream() {
    if (!_ready) return const Stream.empty();
    // NOTE: No orderBy here — combining whereIn + orderBy requires a Firestore
    // composite index. We sort in Dart instead to avoid silent empty results.
    return _db
        .collection('marketLoads')
        .where('status', whereIn: [0, 1]) // 0=pending, 1=booked
        .limit(60)
        .snapshots()
        .map((s) {
          final list =
              s.docs.map((d) => MarketLoad.fromJson(d.data())).toList();
          list.sort((a, b) => b.postedDate.compareTo(a.postedDate));
          return list;
        });
  }

  static Future<void> postMarketLoad(MarketLoad load) async {
    if (!_ready) return;
    try {
      await _db.collection('marketLoads').doc(load.id).set({
        ...load.toJson(), // toJson() already saves status as int index
        'postedBy': _uid,
        // status is already set as int by toJson() — do NOT override with string
      });
    } catch (_) {}
  }
}

// ================================================================
// ENUMS
// ================================================================
