// ============================================================
// main_shell.dart  —  part of liquid_logistics main library
// Auto-extracted from main_v23_8.dart (original lines 8349-19787)
// DO NOT add imports here — all imports live in main.dart
// ============================================================
part of 'package:liquid_logistics/main.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});
  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with TickerProviderStateMixin {
  int _idx = 0;
  bool _loading = true;
  int _adminTaps = 0;
  DateTime? _lastAdminTap;

  // Logged-in user type — drives which tabs/features are visible
  AppUserType _appUserType = AppUserType.fleetOwner;
  bool get _isDriver => _appUserType == AppUserType.driver;
  bool get _isConsignor => _appUserType == AppUserType.consignor;
  bool get _isFleetOwner => _appUserType == AppUserType.fleetOwner;

  UserProfile userProfile = UserProfile();
  SubscriptionInfo subscription = SubscriptionInfo();
  bool _notifsSeen = false; // tracks whether user has seen current alerts
  String _lastLoadedUid = ''; // tracks which user's data is currently loaded
  final DateTime _appOpenTime = DateTime.now(); // used to filter old broadcasts
  List<TripLedger> ledgers = [];
  List<Driver> drivers = [];
  List<Asset> fleet = [];
  List<MarketLoad> marketLoads = [];
  List<KredXApplication> kredxApps = [];
  List<Map<String, dynamic>> partyTrustList = [];
  RouteMasterModuleState moduleState = RouteMasterModuleState();
  Timer? _etaExpiryTimer;

  List<TripLedger> get _visibleLedgers {
    if (userProfile.role == UserRole.driver) {
      final name = FirebaseService.currentUser?.displayName ?? '';
      return ledgers
          .where((l) => l.driverName != null && l.driverName == name)
          .toList();
    }
    return ledgers;
  }

  // Post Load form state
  String _pVehicleType = "SS Tanker";
  String _addVehicleFuelType = "Diesel"; // persists during dialog
  final _pOriginCtrl = TextEditingController();
  final _pDestCtrl = TextEditingController();
  final _pFactoryOriginCtrl = TextEditingController();
  final _pFactoryDestCtrl = TextEditingController();
  final _pWeightCtrl = TextEditingController();
  final _pMaterialCtrl = TextEditingController(text: "Ethanol");
  final _pPriceCtrl = TextEditingController();
  String _pOriginState = '',
      _pDestState = '',
      _pOriginCity = '',
      _pDestCity = '';

  // Find Load filters
  String _fOriginState = 'All', _fDestState = 'All';
  String _fOriginCity = 'All', _fDestCity = 'All';
  double _fRadiusKm = 0; // 0 = no radius filter

  // Khata filters
  String _khataFilter = "All";
  String? _khataFilterVal;

  @override
  void initState() {
    super.initState();
    _load();
    _etaExpiryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      if (_expireTripsPastEta()) setState(() {});
    });
  }

  bool _expireTripsPastEta() {
    final now = DateTime.now();
    var changed = false;
    for (final ledger
        in _visibleLedgers.where((ledger) => ledger.isInTransit)) {
      if (ledger.estimatedArrival.isEmpty) continue;
      try {
        if (now.isAfter(DateTime.parse(ledger.estimatedArrival))) {
          ledger.isInTransit = false;
          changed = true;
        }
      } catch (_) {}
    }
    if (changed) _save();
    return changed;
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    // If a different user just logged in, wipe in-memory state first
    // If cache version changed, clear old caches so new fields (trustPoints, badges) load fresh
    final cacheVer = p.getString('rm_cache_ver') ?? '0';
    if (cacheVer != '5.2') {
      // Clear all cached data so new fields (trustPoints, isVerifiedBadge, badges) load fresh
      await p.remove(_k('fm_drivers'));
      // DO NOT remove fm_ledgers or fm_fleet — user data must survive updates
      await p.setString('rm_cache_ver', '5.2');
      debugPrint('🔄 Driver cache cleared for v5.2 schema update');
    }
    final currentUid = FirebaseService.currentUser?.uid ?? 'local';
    if (_lastLoadedUid.isNotEmpty && _lastLoadedUid != currentUid) {
      // User switched — clear ALL local data so no cross-contamination
      ledgers.clear();
      drivers.clear();
      fleet.clear();
      kredxApps.clear();
      marketLoads.clear();
      userProfile = UserProfile();
      subscription = SubscriptionInfo();
      // Clear the previous user's cached market loads
      // Market loads come from Firestore real-time, so cache can be safely cleared
      final p2 = await SharedPreferences.getInstance();
      // _k() uses current uid, but we want to clear the PREVIOUS user's cache
      // Use the stored _lastLoadedUid to build the old key
      await p2.remove('${_lastLoadedUid}_fm_market');
      debugPrint(
          '🔄 User switched $_lastLoadedUid → $currentUid: cleared market cache');
    }
    _lastLoadedUid = currentUid;
    try {
      if (p.getString(_k('fm_profile')) != null) {
        userProfile =
            UserProfile.fromJson(jsonDecode(p.getString(_k('fm_profile'))!));
      }
      if (p.getString(_k('fm_sub')) != null) {
        subscription =
            SubscriptionInfo.fromJson(jsonDecode(p.getString(_k('fm_sub'))!));
      }
      if (p.getString(_k('fm_ledgers')) != null) {
        ledgers = (jsonDecode(p.getString(_k('fm_ledgers'))!) as List)
            .map((e) => TripLedger.fromJson(e))
            .toList();
      }
      if (p.getString(_k('fm_fleet')) != null) {
        fleet = (jsonDecode(p.getString(_k('fm_fleet'))!) as List)
            .map((e) => Asset.fromJson(e))
            .toList();
      }
      // fleet stays empty for non-owner new users — they add their own vehicles
      if (p.getString(_k('fm_drivers')) != null) {
        drivers = (jsonDecode(p.getString(_k('fm_drivers'))!) as List)
            .map((e) => Driver.fromJson(e))
            .toList();
      }
      if (p.getString(_k('fm_market')) != null) {
        marketLoads = (jsonDecode(p.getString(_k('fm_market'))!) as List)
            .map((e) => MarketLoad.fromJson(e))
            .toList();
      }
      // marketLoads stays empty — loads come from Firestore real-time stream
      if (p.getString(_k('fm_kredx')) != null) {
        kredxApps = (jsonDecode(p.getString(_k('fm_kredx'))!) as List)
            .map((e) => KredXApplication.fromJson(e))
            .toList();
      }
      if (p.getString(_k('rm_modules')) != null) {
        moduleState = RouteMasterModuleState.fromJson(
            jsonDecode(p.getString(_k('rm_modules'))!));
      }
    } catch (_) {}
    // Read user type saved at registration / driver login
    final userTypeStr = p.getString('rm_user_type') ?? 'fleetOwner';
    _appUserType = userTypeStr == 'driver'
        ? AppUserType.driver
        : userTypeStr == 'consignor'
            ? AppUserType.consignor
            : AppUserType.fleetOwner;
    // Inject demo data ONLY for the owner device (AppConfig.ownerUid)
    // All other users start with a completely clean, empty app
    // Show demo data ONLY for the two owner phone numbers
    final isOwner = AppConfig.isOwnerDevice;
    if (isOwner) {
      if (drivers.isEmpty && p.getString(_k('fm_drivers')) == null) {
        drivers = _demoDrivers();
      }
      if (ledgers.isEmpty && p.getString(_k('fm_ledgers')) == null) {
        ledgers = _demoLedgers();
      }
      if (fleet.isEmpty && p.getString(_k('fm_fleet')) == null) {
        fleet = List.generate(
            12,
            (i) => Asset(
                id: 'V${i + 1}',
                number: 'GJ-01-WT-${1000 + i}',
                type: 'SS Tanker',
                payload: '30 Ton',
                tyreCount: 14,
                axleCount: 6,
                tyreSerials: List.filled(14, ''),
                batteries: [],
                docs: VehicleDocConfig.getRequiredDocs('SS Tanker')
                    .map((d) => FleetDoc(name: d))
                    .toList()));
      }
      // Only inject demo market loads if none have been dispatched yet
      final dispatchedIds = p.getStringList('rm_dispatched_ids') ?? [];
      if (marketLoads.isEmpty && p.getString(_k('fm_market')) == null) {
        final ownerUid = FirebaseService.currentUser?.uid ?? '';
        final demos = _demoMarketLoads()
            .where((l) => !dispatchedIds.contains(l.id))
            .map((l) => l
              ..postedByUid =
                  ownerUid) // set real uid so Firestore migration works
            .toList();
        marketLoads = demos;
      }
      if (moduleState.maintenanceTickets.length < 3) {
        moduleState.maintenanceTickets = _demoMaintenanceTickets();
      }
      if (moduleState.complianceVault.length < 5) {
        moduleState.complianceVault = _demoComplianceVault();
      }
    }
    // Print UID to console so owner can copy it into AppConfig.ownerUid
    debugPrint(
        '🔑 Current Firebase UID: ${FirebaseService.currentUser?.uid ?? "not logged in"}');
    setState(() => _loading = false);
    _checkPaymentAlerts();
    _startFirebaseSync();
    // Load profile from Firestore (authoritative cloud version overrides local cache)
    _syncProfileFromCloud();
    // Subscribe to paid FCM topic if on paid plan
    _updateFcmTopics();
  }

  StreamSubscription? _marketLoadSub;
  // IDs of loads dispatched this session — kept to prevent listener re-adding them
  final Set<String> _dispatchedLoadIds = {};

  // Push local-only market loads to Firestore so all users can see them
  Future<void> _migrateLocalLoadsToFirestore() async {
    if (!FirebaseService.isReady) return;
    try {
      for (final load in marketLoads) {
        // Skip truly anonymous loads (safety check)
        if (load.id.isEmpty) continue;
        // Check if this load exists in Firestore already
        final doc = await FirebaseFirestore.instance
            .collection('marketLoads')
            .doc(load.id)
            .get();
        if (!doc.exists) {
          // Push to Firestore
          await FirebaseFirestore.instance
              .collection('marketLoads')
              .doc(load.id)
              .set({
            ...load.toJson(),
            'status': load.status.index,
            'postedBy': load.postedByUid,
            'postedAt': FieldValue.serverTimestamp(),
            'migratedAt': FieldValue.serverTimestamp(),
          });
          debugPrint('📤 Migrated load ${load.id} to Firestore');
        }
      }
    } catch (e) {
      debugPrint('Migration error: $e');
    }
  }

  StreamSubscription? _ledgerSub;

  Future<void> _updateFcmTopics() async {
    try {
      final msg = FirebaseMessaging.instance;
      if (subscription.tier != SubscriptionTier.free) {
        await msg.subscribeToTopic('paid_tier');
      } else {
        await msg.unsubscribeFromTopic('paid_tier');
      }
    } catch (_) {}
  }

  Future<void> _syncProfileFromCloud() async {
    try {
      final cloudProfile = await FirebaseService.loadProfile();
      if (cloudProfile != null && mounted) {
        final merged = UserProfile.fromJson({
          ...userProfile.toJson(),
          ...cloudProfile, // cloud wins on conflicts
        });
        setState(() => userProfile = merged);
        // Also update local cache
        final p = await SharedPreferences.getInstance();
        await p.setString(_k('fm_profile'), jsonEncode(merged.toJson()));
      }
    } catch (_) {}
  }

  StreamSubscription? _driverSub;
  StreamSubscription? _fleetSub;
  StreamSubscription? _broadcastSub;

  void _startFirebaseSync() {
    if (!FirebaseService.isReady || FirebaseService.currentUser == null) return;

    // ── One-time migration: push any local loads to Firestore ────
    // Delay so demo loads are populated before we try to migrate
    Future.delayed(const Duration(seconds: 2), _migrateLocalLoadsToFirestore);
    // ── Restore persisted dispatched IDs so they stay gone after restart ──
    SharedPreferences.getInstance().then((p) {
      final saved = p.getStringList('rm_dispatched_ids') ?? [];
      if (mounted) setState(() => _dispatchedLoadIds.addAll(saved));
    });

    // 1. Market loads — shared across ALL users (the load board)
    _marketLoadSub?.cancel();
    _marketLoadSub = FirebaseFirestore.instance
        .collection('marketLoads')
        .where('status', whereIn: [
          BidStatus.pending.index, // 0 = pending
          BidStatus.booked.index // 1 = booked (not yet dispatched)
        ])
        // No orderBy — combining whereIn + orderBy needs composite index
        // Sort in Dart to avoid silent empty results on new devices
        .limit(100) // raised from 60 so large fleets see all loads
        .snapshots()
        .listen((snap) async {
          if (!mounted) return;
          // Convert all Firestore docs to MarketLoad objects
          final remote = snap.docs
              .map((d) => _marketLoadFromFirestore(d.data()))
              .where((l) => !_dispatchedLoadIds
                  .contains(l.id)) // exclude locally dispatched
              .toList();
          final currentUid = FirebaseService.currentUser?.uid ?? '';
          final bookedLoadsForCurrentUser = remote.where((load) =>
              load.status == BidStatus.booked &&
              (load.bookedByUid == currentUid ||
                  (load.postedByUid == currentUid &&
                      load.bookedByUid != currentUid)));
          final remoteIds = remote.map((l) => l.id).toSet();
          setState(() {
            // REPLACE strategy: Firestore is the source of truth for the load board.
            // Keep only locally-created loads that haven't been pushed yet
            // (identified by missing from Firestore) + everything from Firestore.
            // This ensures:
            //   1. Dispatched loads disappear for ALL users immediately
            //   2. New users see ALL loads, not just the 3 most recent
            //   3. No stale local loads linger after dispatch
            final localOnly = marketLoads
                .where((l) =>
                    !remoteIds.contains(l.id) &&
                    l.status == BidStatus.pending &&
                    l.postedByUid == (FirebaseService.currentUser?.uid ?? ''))
                .toList();
            marketLoads
              ..clear()
              ..addAll(remote)
              ..addAll(localOnly)
              ..sort((a, b) => b.postedDate.compareTo(a.postedDate));
          });
          for (final load in bookedLoadsForCurrentUser) {
            try {
              await _syncBookedLoadToKhata(
                load,
                forPoster: load.bookedByUid != currentUid,
              );
            } catch (e) {
              debugPrint('Could not sync booked load ${load.id} to Khata: $e');
            }
          }
        }, onError: (e) => debugPrint('Market-load stream failed: $e'));

    // 2. Ledgers — real-time sync so Phone B sees Phone A's trips instantly
    _ledgerSub?.cancel();
    _ledgerSub = FirebaseService.ledgersStream().listen((remote) {
      if (!mounted) return;
      final prevAlertCount = ledgers
          .where(
              (l) => (l.isPaymentOverdue || l.isDueSoon) && l.partyPending > 0)
          .length;
      setState(() {
        for (final r in remote) {
          final idx = ledgers.indexWhere((l) => l.id == r.id);
          if (idx >= 0) {
            ledgers[idx] = r;
          } else {
            ledgers.insert(0, r);
          }
        }
        // If new alerts appeared, reset seen state so dot shows again
        final newAlertCount = ledgers
            .where((l) =>
                (l.isPaymentOverdue || l.isDueSoon) && l.partyPending > 0)
            .length;
        if (newAlertCount > prevAlertCount) _notifsSeen = false;
      });
    }, onError: (_) {});

    // 3. Drivers — real-time sync
    _driverSub?.cancel();
    if (_isDriver) {
      SharedPreferences.getInstance().then((p) {
        final foUid = p.getString('rm_fleet_owner_uid') ?? '';
        if (foUid.isEmpty) return;
        _driverSub = FirebaseFirestore.instance
            .collection('users')
            .doc(foUid)
            .collection('drivers')
            .snapshots()
            .map((s) => s.docs.map((d) => Driver.fromJson(d.data())).toList())
            .listen((remote) {
          if (!mounted) return;
          final myPhone = userProfile.phone.replaceAll(RegExp(r'\D'), '');
          final my10 = myPhone.length >= 10
              ? myPhone.substring(myPhone.length - 10)
              : myPhone;
          setState(() {
            for (final r in remote.where((d) {
              final dp = d.phone.replaceAll(RegExp(r'\D'), '');
              final dp10 = dp.length >= 10 ? dp.substring(dp.length - 10) : dp;
              return dp10 == my10;
            })) {
              final idx = drivers.indexWhere((d) => d.id == r.id);
              if (idx >= 0) {
                drivers[idx] = r;
              } else {
                drivers.add(r);
              }
            }
          });
        }, onError: (_) {});
      });
    } else {
      _driverSub = FirebaseService.driversStream().listen((remote) {
        if (!mounted || remote.isEmpty) return;
        setState(() {
          for (final r in remote) {
            final idx = drivers.indexWhere((d) => d.id == r.id);
            if (idx >= 0) {
              drivers[idx] = r;
            } else {
              drivers.add(r);
            }
          }
        });
      }, onError: (_) {});
    }

    // 4. Fleet — real-time sync
    _fleetSub?.cancel();
    _fleetSub = FirebaseService.fleetStream().listen((remote) {
      if (!mounted || remote.isEmpty) return;
      setState(() {
        for (final r in remote) {
          final idx = fleet.indexWhere((a) => a.id == r.id);
          if (idx >= 0) {
            fleet[idx] = r;
          } else {
            fleet.add(r);
          }
        }
      });
    }, onError: (_) {});

    // 5. Admin broadcasts — show a banner when admin sends a notification
    _broadcastSub?.cancel();
    _broadcastSub = FirebaseService.broadcastsStream(sinceTime: _appOpenTime)
        .listen((snap) {
      if (!mounted) return;
      for (final doc in snap.docChanges) {
        if (doc.type == DocumentChangeType.added) {
          final d = doc.doc.data() as Map<String, dynamic>?;
          if (d == null) continue;
          final target = d['target'] as String? ?? 'all_users';
          if (target != 'all_users' &&
              !(target == 'paid_tier' &&
                  subscription.tier != SubscriptionTier.free)) {
            continue;
          }
          final title = d['title'] as String? ?? 'NavGati ERP';
          final body = d['body'] as String? ?? '';
          if (body.isEmpty) continue;
          // Show as a SnackBar notification in the app
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              duration: const Duration(seconds: 6),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF0D1F14),
              content: Row(children: [
                const Icon(Icons.notifications_active_rounded,
                    color: Color(0xFF52A06A), size: 20),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Color(0xFFF2EDE4),
                            fontWeight: FontWeight.w800,
                            fontSize: 13)),
                    Text(body,
                        style: const TextStyle(
                            color: Color(0xFF8FBC8F), fontSize: 12)),
                  ],
                )),
              ]),
            ));
          });
        }
      }
    }, onError: (_) {});

    // 6b. Party trust list — for blacklist checks on load posting
    if (FirebaseService.isReady) {
      FirebaseService.partyTrustStream(FirebaseService.currentUser?.uid ?? '')
          .listen((snap) {
        if (!mounted) return;
        final list =
            snap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
        setState(() => partyTrustList = list);
      }, onError: (_) {});
    }

    // 6. Subscription changes from admin — sync tier updates instantly
    FirebaseService.subscriptionStream().listen((docSnap) {
      if (!mounted || docSnap == null) return;
      final d = (docSnap).data() as Map<String, dynamic>?;
      if (d == null) return;
      final subData = d['subscription'] as Map<String, dynamic>?;
      if (subData != null) {
        final tierIdx = subData['tier'] as int? ?? 0;
        if (tierIdx != subscription.tier.index) {
          setState(() {
            subscription = SubscriptionInfo.fromJson({
              ...subscription.toJson(),
              'tier': tierIdx,
            });
          });
        }
      }
    }, onError: (_) {});
  }

  MarketLoad _marketLoadFromFirestore(Map<String, dynamic> d) => MarketLoad(
        id: d['id'] ?? '',
        route: d['route'] ?? '',
        details: d['details'] ?? '',
        vehicleType: d['vehicleType'] ?? '',
        targetPrice: (d['targetPrice'] as num? ?? 0).toDouble(),
        status: BidStatus.values[d['status'] as int? ?? 0],
        materialType: d['materialType'] ?? '',
        postedDate: d['postedDate'] ?? '',
        originCity: d['originCity'] ?? '',
        originState: d['originState'] ?? '',
        destCity: d['destCity'] ?? '',
        destState: d['destState'] ?? '',
        originFactory: d['originFactory'] ?? '',
        destFactory: d['destFactory'] ?? '',
        weightTons: (d['weightTons'] as num? ?? 0).toDouble(),
        postedByUid: d['postedByUid'] ?? d['postedBy'] ?? '',
        postedByName: d['postedByName'] ?? '',
        isVerifiedPoster: d['isVerifiedPoster'] as bool? ?? false,
        isBulk: d['isBulk'] as bool? ?? false,
        bids: (d['bids'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>(),
        bookedByUid: d['bookedByUid'] ?? '',
        bookedByName: d['bookedByName'] ?? '',
        bookedVehicleNo: d['bookedVehicleNo'] ?? '',
        bookedDriverName: d['bookedDriverName'] ?? '',
      );

  @override
  void dispose() {
    _etaExpiryTimer?.cancel();
    _marketLoadSub?.cancel();
    _ledgerSub?.cancel();
    _driverSub?.cancel();
    _fleetSub?.cancel();
    _broadcastSub?.cancel();
    super.dispose();
  }

  List<Driver> _demoDrivers() => [
        Driver(
            id: 'D1',
            name: 'Harpreet Singh',
            phone: '+91 98765 11001',
            balance: 12500,
            trustPoints: 92,
            isVerifiedBadge: true,
            transactions: [
              DriverTx(
                  date: '15/4',
                  type: DriverTxType.salary,
                  amount: 22000,
                  note: 'April salary'),
              DriverTx(
                  date: '10/4',
                  type: DriverTxType.advance,
                  amount: -5000,
                  note: 'Advance')
            ],
            monthlySalary: 22000,
            aadharNum: '1234',
            dlNum: 'PB-0120230012345'),
        Driver(
            id: 'D2',
            name: 'Raju Yadav',
            phone: '+91 98765 22002',
            balance: -3000,
            trustPoints: 58,
            violations: [
              {'reason': 'Late delivery', 'points': 20, 'date': '2025-04-10'},
              {'reason': 'Vehicle damage', 'points': 22, 'date': '2025-03-20'},
            ],
            transactions: [
              DriverTx(
                  date: '12/4',
                  type: DriverTxType.advance,
                  amount: -8000,
                  note: 'Advance taken'),
              DriverTx(
                  date: '1/4',
                  type: DriverTxType.salary,
                  amount: 20000,
                  note: 'Salary')
            ],
            monthlySalary: 20000,
            aadharNum: '5678',
            dlNum: 'UP-6520220056789'),
        Driver(
            id: 'D3',
            name: 'Sukhvinder Gill',
            phone: '+91 98765 33003',
            balance: 18000,
            transactions: [
              DriverTx(
                  date: '1/4',
                  type: DriverTxType.salary,
                  amount: 21000,
                  note: 'April salary')
            ],
            monthlySalary: 21000,
            dlNum: 'GJ-0120230099001'),
        Driver(
            id: 'D4',
            name: 'Mukesh Prajapati',
            phone: '+91 98765 44004',
            balance: 5000,
            transactions: [
              DriverTx(
                  date: '5/4',
                  type: DriverTxType.bonus,
                  amount: 3000,
                  note: 'On-time delivery bonus'),
              DriverTx(
                  date: '1/4',
                  type: DriverTxType.salary,
                  amount: 19500,
                  note: 'Salary')
            ],
            monthlySalary: 19500),
        Driver(
            id: 'D5',
            name: 'Ramesh Devasi',
            phone: '+91 98765 55005',
            balance: 22000,
            transactions: [
              DriverTx(
                  date: '1/4',
                  type: DriverTxType.salary,
                  amount: 22000,
                  note: 'April salary')
            ],
            monthlySalary: 22000,
            dlNum: 'GJ-0220230088776'),
        Driver(
            id: 'D6',
            name: 'Baldev Kumar',
            phone: '+91 98765 66006',
            balance: -1500,
            transactions: [
              DriverTx(
                  date: '8/4',
                  type: DriverTxType.penalty,
                  amount: -1500,
                  note: 'Late delivery penalty'),
              DriverTx(
                  date: '1/4',
                  type: DriverTxType.salary,
                  amount: 20000,
                  note: 'Salary')
            ],
            monthlySalary: 20000),
        Driver(
            id: 'D7',
            name: 'Dinesh Parmar',
            phone: '+91 98765 77007',
            balance: 15000,
            transactions: [
              DriverTx(
                  date: '1/4',
                  type: DriverTxType.salary,
                  amount: 21500,
                  note: 'Salary')
            ],
            monthlySalary: 21500,
            aadharNum: '9012',
            dlNum: 'GJ-1120230067432'),
        Driver(
            id: 'D8',
            name: 'Jagdish Solanki',
            phone: '+91 98765 88008',
            balance: 8500,
            transactions: [
              DriverTx(
                  date: '3/4',
                  type: DriverTxType.advance,
                  amount: -6000,
                  note: 'Medical advance'),
              DriverTx(
                  date: '1/4',
                  type: DriverTxType.salary,
                  amount: 20000,
                  note: 'Salary')
            ],
            monthlySalary: 20000),
        Driver(
            id: 'D9',
            name: 'Vikram Rathod',
            phone: '+91 98765 99009',
            balance: 24000,
            transactions: [
              DriverTx(
                  date: '1/4',
                  type: DriverTxType.salary,
                  amount: 24000,
                  note: 'Senior driver salary')
            ],
            monthlySalary: 24000,
            dlNum: 'GJ-0120220034567'),
        Driver(
            id: 'D10',
            name: 'Santosh Bind',
            phone: '+91 98765 10010',
            balance: 3000,
            transactions: [
              DriverTx(
                  date: '15/4',
                  type: DriverTxType.advance,
                  amount: -5000,
                  note: 'Advance'),
              DriverTx(
                  date: '1/4',
                  type: DriverTxType.salary,
                  amount: 19000,
                  note: 'Salary')
            ],
            monthlySalary: 19000),
        Driver(
            id: 'D11',
            name: 'Ajay Verma',
            phone: '+91 98765 11011',
            balance: 16000,
            transactions: [
              DriverTx(
                  date: '1/4',
                  type: DriverTxType.salary,
                  amount: 20000,
                  note: 'April salary')
            ],
            monthlySalary: 20000,
            aadharNum: '3456',
            dlNum: 'UP-4120220078901'),
        Driver(
            id: 'D12',
            name: 'Mohan Desai',
            phone: '+91 98765 12012',
            balance: 11000,
            transactions: [
              DriverTx(
                  date: '2/4',
                  type: DriverTxType.fuel,
                  amount: -2000,
                  note: 'Personal fuel draw'),
              DriverTx(
                  date: '1/4',
                  type: DriverTxType.salary,
                  amount: 21000,
                  note: 'Salary')
            ],
            monthlySalary: 21000,
            dlNum: 'GJ-0320230045612'),
      ];

  List<MarketLoad> _demoMarketLoads() => [
        MarketLoad(
            id: 'ML001',
            route: 'Hazira, Gujarat -> Panipat, Haryana',
            details: '28T | Ethanol',
            vehicleType: 'SS Tanker',
            targetPrice: 185000,
            status: BidStatus.pending,
            materialType: 'Ethanol',
            originCity: 'Hazira',
            originState: 'Gujarat',
            destCity: 'Panipat',
            destState: 'Haryana',
            originFactory: 'ONGC Hazira Plant',
            destFactory: 'IOCL Panipat Refinery',
            weightTons: 28,
            postedDate: '22/4/2026',
            postedByName: 'ONGC Chemicals',
            isVerifiedPoster: true,
            isBulk: true),
        MarketLoad(
            id: 'ML002',
            route: 'Bharuch, Gujarat -> Pune, Maharashtra',
            details: '24T | Acetic Acid',
            vehicleType: 'MS Tanker',
            targetPrice: 98000,
            status: BidStatus.pending,
            materialType: 'Acetic Acid',
            originCity: 'Bharuch',
            originState: 'Gujarat',
            destCity: 'Pune',
            destState: 'Maharashtra',
            originFactory: 'Deepak Nitrite Bharuch',
            weightTons: 24,
            postedDate: '22/4/2026',
            postedByName: 'Gujarat Chemicals Ltd'),
        MarketLoad(
            id: 'ML003',
            route: 'Dahej, Gujarat -> Nagpur, Maharashtra',
            details: '20T | Chlorine Gas',
            vehicleType: 'SS Tanker',
            targetPrice: 115000,
            status: BidStatus.pending,
            materialType: 'Chlorine Gas',
            originCity: 'Dahej',
            originState: 'Gujarat',
            destCity: 'Nagpur',
            destState: 'Maharashtra',
            originFactory: 'Dahej Port Authority',
            weightTons: 20,
            postedDate: '21/4/2026',
            postedByName: 'Deepak Fertilisers',
            isVerifiedPoster: true),
        MarketLoad(
            id: 'ML004',
            route: 'Mundra Port, Gujarat -> Delhi, NCR',
            details: '30T | Edible Oil',
            vehicleType: 'MS Tanker',
            targetPrice: 210000,
            status: BidStatus.pending,
            materialType: 'Edible Oil',
            originCity: 'Mundra Port',
            originState: 'Gujarat',
            destCity: 'Delhi',
            destState: 'Delhi',
            originFactory: 'Adani Wilmar Mundra',
            weightTons: 30,
            postedDate: '21/4/2026',
            postedByName: 'Reliance Logistics'),
        MarketLoad(
            id: 'ML005',
            route: 'Vapi, Gujarat -> Hyderabad, Telangana',
            details: '22T | Specialty Chemicals',
            vehicleType: 'SS Tanker',
            targetPrice: 155000,
            status: BidStatus.pending,
            materialType: 'Specialty Chemicals',
            originCity: 'Vapi',
            originState: 'Gujarat',
            destCity: 'Hyderabad',
            destState: 'Telangana',
            originFactory: 'Aarti Industries Vapi',
            weightTons: 22,
            postedDate: '20/4/2026',
            postedByName: 'TATA Freight'),
        MarketLoad(
            id: 'ML006',
            route: 'Kandla Port, Gujarat -> Lucknow, UP',
            details: '28T | Palm Oil',
            vehicleType: 'MS Tanker',
            targetPrice: 175000,
            status: BidStatus.pending,
            materialType: 'Palm Oil',
            originCity: 'Kandla Port',
            originState: 'Gujarat',
            destCity: 'Lucknow',
            destState: 'Uttar Pradesh',
            originFactory: 'Kandla Port Trust',
            weightTons: 28,
            postedDate: '20/4/2026',
            postedByName: 'Adani Logistics'),
        MarketLoad(
            id: 'ML007',
            route: 'Ahmedabad, Gujarat -> Mumbai, Maharashtra',
            details: '20T | HSD/Diesel',
            vehicleType: 'SS Tanker',
            targetPrice: 68000,
            status: BidStatus.pending,
            materialType: 'HSD/Diesel',
            originCity: 'Ahmedabad',
            originState: 'Gujarat',
            destCity: 'Mumbai',
            destState: 'Maharashtra',
            weightTons: 20,
            postedDate: '19/4/2026',
            postedByName: 'Punjab Agro'),
        MarketLoad(
            id: 'ML008',
            route: 'Vadodara, Gujarat -> Indore, MP',
            details: '18T | Refrigerant R-22',
            vehicleType: 'MS Tanker',
            targetPrice: 72000,
            status: BidStatus.pending,
            materialType: 'Refrigerant R-22',
            originCity: 'Vadodara',
            originState: 'Gujarat',
            destCity: 'Indore',
            destState: 'Madhya Pradesh',
            originFactory: 'Gujarat Fluorochemicals',
            weightTons: 18,
            postedDate: '19/4/2026'),
        // Cross-state loads for filter testing
        MarketLoad(
            id: 'ML009',
            route: 'Panipat, Haryana -> Mumbai, Maharashtra',
            details: '26T | Textile Yarn',
            vehicleType: 'Container',
            targetPrice: 145000,
            status: BidStatus.pending,
            materialType: 'Textile Yarn',
            originCity: 'Panipat',
            originState: 'Haryana',
            destCity: 'Mumbai',
            destState: 'Maharashtra',
            weightTons: 26,
            postedDate: '23/4/2026',
            postedByName: 'Maharashtra Industries'),
        MarketLoad(
            id: 'ML010',
            route: 'Ludhiana, Punjab -> Chennai, Tamil Nadu',
            details: '22T | Auto Parts',
            vehicleType: 'Container',
            targetPrice: 195000,
            status: BidStatus.pending,
            materialType: 'Auto Parts',
            originCity: 'Ludhiana',
            originState: 'Punjab',
            destCity: 'Chennai',
            destState: 'Tamil Nadu',
            weightTons: 22,
            postedDate: '23/4/2026',
            postedByName: 'Rajasthan Minerals'),
        MarketLoad(
            id: 'ML011',
            route: 'Kolkata, West Bengal -> Delhi, NCR',
            details: '30T | Steel Coils',
            vehicleType: 'Trailer',
            targetPrice: 125000,
            status: BidStatus.pending,
            materialType: 'Steel Coils',
            originCity: 'Kolkata',
            originState: 'West Bengal',
            destCity: 'Delhi',
            destState: 'Delhi',
            weightTons: 30,
            postedDate: '22/4/2026',
            postedByName: 'Karnataka Exports'),
        MarketLoad(
            id: 'ML012',
            route: 'Hyderabad, Telangana -> Bangalore, Karnataka',
            details: '18T | Pharma Raw Material',
            vehicleType: 'Reefer',
            targetPrice: 62000,
            status: BidStatus.pending,
            materialType: 'Pharma Raw Material',
            originCity: 'Hyderabad',
            originState: 'Telangana',
            destCity: 'Bangalore',
            destState: 'Karnataka',
            weightTons: 18,
            postedDate: '22/4/2026',
            postedByName: 'Tamil Nadu Textiles'),
        MarketLoad(
            id: 'ML013',
            route: 'Jaipur, Rajasthan -> Kolkata, West Bengal',
            details: '24T | Marble Tiles',
            vehicleType: 'Open Truck',
            targetPrice: 118000,
            status: BidStatus.pending,
            materialType: 'Marble Tiles',
            originCity: 'Jaipur',
            originState: 'Rajasthan',
            destCity: 'Kolkata',
            destState: 'West Bengal',
            weightTons: 24,
            postedDate: '21/4/2026'),
        MarketLoad(
            id: 'ML014',
            route: 'Pune, Maharashtra -> Amritsar, Punjab',
            details: '20T | Tractor Parts',
            vehicleType: 'Container',
            targetPrice: 132000,
            status: BidStatus.pending,
            materialType: 'Tractor Parts',
            originCity: 'Pune',
            originState: 'Maharashtra',
            destCity: 'Amritsar',
            destState: 'Punjab',
            weightTons: 20,
            postedDate: '21/4/2026'),
        MarketLoad(
            id: 'ML015',
            route: 'Haldia Port, West Bengal -> Indore, MP',
            details: '28T | Crude Palm Oil',
            vehicleType: 'MS Tanker',
            targetPrice: 155000,
            status: BidStatus.pending,
            materialType: 'Crude Palm Oil',
            originCity: 'Haldia Port',
            originState: 'West Bengal',
            destCity: 'Indore',
            destState: 'Madhya Pradesh',
            weightTons: 28,
            postedDate: '20/4/2026'),
        MarketLoad(
            id: 'ML016',
            route: 'Bathinda, Punjab -> Daman, Daman & Diu',
            details: '26T | Fertilizers',
            vehicleType: 'Open Truck',
            targetPrice: 138000,
            status: BidStatus.pending,
            materialType: 'Fertilizers',
            originCity: 'Bathinda',
            originState: 'Punjab',
            destCity: 'Daman',
            destState: 'Daman & Diu',
            weightTons: 26,
            postedDate: '20/4/2026'),
        MarketLoad(
            id: 'ML017',
            route: 'Raipur, Chhattisgarh -> Surat, Gujarat',
            details: '30T | Iron Ore',
            vehicleType: 'Open Truck',
            targetPrice: 108000,
            status: BidStatus.pending,
            materialType: 'Iron Ore',
            originCity: 'Raipur',
            originState: 'Chhattisgarh',
            destCity: 'Surat',
            destState: 'Gujarat',
            weightTons: 30,
            postedDate: '19/4/2026'),
        MarketLoad(
            id: 'ML018',
            route: 'Bhubaneswar, Odisha -> Nagpur, Maharashtra',
            details: '25T | Coal',
            vehicleType: 'Open Truck',
            targetPrice: 92000,
            status: BidStatus.pending,
            materialType: 'Coal',
            originCity: 'Bhubaneswar',
            originState: 'Odisha',
            destCity: 'Nagpur',
            destState: 'Maharashtra',
            weightTons: 25,
            postedDate: '19/4/2026'),
        MarketLoad(
            id: 'ML019',
            route: 'Kochi, Kerala -> Hyderabad, Telangana',
            details: '20T | Cashew Nuts',
            vehicleType: 'Container',
            targetPrice: 88000,
            status: BidStatus.pending,
            materialType: 'Cashew Nuts',
            originCity: 'Kochi',
            originState: 'Kerala',
            destCity: 'Hyderabad',
            destState: 'Telangana',
            weightTons: 20,
            postedDate: '18/4/2026'),
        MarketLoad(
            id: 'ML020',
            route: 'Guwahati, Assam -> Delhi, NCR',
            details: '18T | Tea',
            vehicleType: 'Container',
            targetPrice: 175000,
            status: BidStatus.pending,
            materialType: 'Tea',
            originCity: 'Guwahati',
            originState: 'Assam',
            destCity: 'Delhi',
            destState: 'Delhi',
            weightTons: 18,
            postedDate: '18/4/2026',
            postedByName: 'Demo Consignor'),
      ];

  List<TripLedger> _demoLedgers() => [
        TripLedger(
            id: 'TRP10001',
            date: '1/4/2026',
            partyName: 'Reliance Industries Ltd',
            vehicleNo: 'GJ-01-WT-1000',
            route: 'Hazira, Gujarat -> Panipat, Haryana',
            ownership: VehicleOwnership.self,
            materialName: 'Ethanol',
            freightBilled: 185000,
            paymentReceived: 100000,
            diesel: 42000,
            toll: 12800,
            driverExp: 8500,
            loadingPoint: 'Hazira',
            unloadingPoint: 'Panipat',
            loadingState: 'Gujarat',
            unloadingState: 'Haryana',
            eWayBillNo: 'EWB2410100001',
            paymentTermsDays: 30,
            distanceKm: 1380,
            driverName: 'Harpreet Singh',
            weightTons: 28,
            weightUnit: 'MT',
            gstType: GstType.igst,
            gstRate: 5.0),
        TripLedger(
            id: 'TRP10002',
            date: '3/4/2026',
            partyName: 'IOCL Mathura Refinery',
            vehicleNo: 'GJ-01-WT-1001',
            route: 'Kandla Port, Gujarat -> Mathura, UP',
            ownership: VehicleOwnership.self,
            materialName: 'Crude Chemical',
            freightBilled: 210000,
            paymentReceived: 210000,
            diesel: 38500,
            toll: 11200,
            driverExp: 9000,
            loadingPoint: 'Kandla Port',
            unloadingPoint: 'Mathura',
            loadingState: 'Gujarat',
            unloadingState: 'Uttar Pradesh',
            eWayBillNo: 'EWB2410100002',
            paymentTermsDays: 45,
            distanceKm: 1270,
            driverName: 'Raju Yadav',
            weightTons: 30,
            weightUnit: 'MT'),
        TripLedger(
            id: 'TRP10003',
            date: '5/4/2026',
            partyName: 'Deepak Nitrite Ltd',
            vehicleNo: 'GJ-01-WT-1002',
            route: 'Dahej, Gujarat -> Pune, Maharashtra',
            ownership: VehicleOwnership.self,
            materialName: 'Nitric Acid',
            freightBilled: 95000,
            paymentReceived: 50000,
            diesel: 22000,
            toll: 6400,
            driverExp: 5500,
            loadingPoint: 'Dahej',
            unloadingPoint: 'Pune',
            loadingState: 'Gujarat',
            unloadingState: 'Maharashtra',
            eWayBillNo: 'EWB2410100003',
            paymentTermsDays: 30,
            distanceKm: 590,
            driverName: 'Sukhvinder Gill',
            weightTons: 24,
            weightUnit: 'MT',
            gstType: GstType.cgstSgst,
            gstRate: 12.0),
        TripLedger(
            id: 'TRP10004',
            date: '7/4/2026',
            partyName: 'Tata Chemicals Mithapur',
            vehicleNo: 'GJ-01-WT-1003',
            route: 'Bharuch, Gujarat -> Nagpur, Maharashtra',
            ownership: VehicleOwnership.market,
            materialName: 'Soda Ash',
            freightBilled: 125000,
            paymentReceived: 125000,
            marketTruckFreight: 98000,
            marketAdvancePaid: 50000,
            loadingPoint: 'Bharuch',
            unloadingPoint: 'Nagpur',
            loadingState: 'Gujarat',
            unloadingState: 'Maharashtra',
            eWayBillNo: 'EWB2410100004',
            paymentTermsDays: 15,
            distanceKm: 720),
        TripLedger(
            id: 'TRP10005',
            date: '9/4/2026',
            partyName: 'BPCL Mahul Terminal',
            vehicleNo: 'GJ-01-WT-1004',
            route: 'Ahmedabad, Gujarat -> Mumbai, Maharashtra',
            ownership: VehicleOwnership.self,
            materialName: 'HSD/Diesel',
            freightBilled: 78000,
            paymentReceived: 78000,
            diesel: 18500,
            toll: 5400,
            driverExp: 4200,
            loadingPoint: 'Ahmedabad',
            unloadingPoint: 'Mumbai',
            loadingState: 'Gujarat',
            unloadingState: 'Maharashtra',
            eWayBillNo: 'EWB2410100005',
            paymentTermsDays: 30,
            distanceKm: 527,
            driverName: 'Mukesh Prajapati',
            weightTons: 26,
            weightUnit: 'MT'),
        TripLedger(
            id: 'TRP10006',
            date: '11/4/2026',
            partyName: 'Gujarat Fluorochemicals',
            vehicleNo: 'GJ-01-WT-1005',
            route: 'Vadodara, Gujarat -> Indore, MP',
            ownership: VehicleOwnership.self,
            materialName: 'Refrigerant Gas R-22',
            freightBilled: 68000,
            paymentReceived: 35000,
            diesel: 16800,
            toll: 4900,
            driverExp: 3800,
            loadingPoint: 'Vadodara',
            unloadingPoint: 'Indore',
            loadingState: 'Gujarat',
            unloadingState: 'Madhya Pradesh',
            eWayBillNo: 'EWB2410100006',
            paymentTermsDays: 30,
            distanceKm: 430,
            driverName: 'Ramesh Devasi',
            weightTons: 20,
            weightUnit: 'MT'),
        TripLedger(
            id: 'TRP10007',
            date: '13/4/2026',
            partyName: 'Aarti Industries Vapi',
            vehicleNo: 'GJ-01-WT-1006',
            route: 'Vapi, Gujarat -> Hyderabad, Telangana',
            ownership: VehicleOwnership.market,
            materialName: 'Specialty Chemicals',
            freightBilled: 155000,
            paymentReceived: 80000,
            marketTruckFreight: 122000,
            marketAdvancePaid: 60000,
            loadingPoint: 'Vapi',
            unloadingPoint: 'Hyderabad',
            loadingState: 'Gujarat',
            unloadingState: 'Telangana',
            eWayBillNo: 'EWB2410100007',
            paymentTermsDays: 45,
            distanceKm: 1310),
        TripLedger(
            id: 'TRP10008',
            date: '15/4/2026',
            partyName: 'Nayara Energy Vadinar',
            vehicleNo: 'GJ-01-WT-1007',
            route: 'Jamnagar, Gujarat -> Delhi, NCR',
            ownership: VehicleOwnership.self,
            materialName: 'Motor Spirit/Petrol',
            freightBilled: 235000,
            paymentReceived: 0,
            diesel: 48000,
            toll: 14500,
            driverExp: 10500,
            loadingPoint: 'Jamnagar',
            unloadingPoint: 'Delhi',
            loadingState: 'Gujarat',
            unloadingState: 'Delhi',
            eWayBillNo: 'EWB2410100008',
            paymentTermsDays: 30,
            distanceKm: 1125,
            driverName: 'Jagdish Solanki',
            weightTons: 30,
            weightUnit: 'MT',
            gstType: GstType.igst,
            gstRate: 5.0),
        TripLedger(
            id: 'TRP10009',
            date: '18/4/2026',
            partyName: 'UPL Ltd Ankleshwar',
            vehicleNo: 'GJ-01-WT-1008',
            route: 'Ankleshwar, Gujarat -> Bangalore, Karnataka',
            ownership: VehicleOwnership.self,
            materialName: 'Agrochemicals',
            freightBilled: 172000,
            paymentReceived: 90000,
            diesel: 36500,
            toll: 10800,
            driverExp: 8200,
            loadingPoint: 'Ankleshwar',
            unloadingPoint: 'Bangalore',
            loadingState: 'Gujarat',
            unloadingState: 'Karnataka',
            eWayBillNo: 'EWB2410100009',
            paymentTermsDays: 45,
            distanceKm: 1445,
            driverName: 'Vikram Rathod',
            weightTons: 25,
            weightUnit: 'MT'),
        TripLedger(
            id: 'TRP10010',
            date: '20/4/2026',
            partyName: 'Adani Wilmar Mundra',
            vehicleNo: 'GJ-01-WT-1009',
            route: 'Mundra Port, Gujarat -> Lucknow, UP',
            ownership: VehicleOwnership.self,
            materialName: 'Edible Oil',
            freightBilled: 142000,
            paymentReceived: 142000,
            diesel: 32000,
            toll: 9600,
            driverExp: 7500,
            loadingPoint: 'Mundra Port',
            unloadingPoint: 'Lucknow',
            loadingState: 'Gujarat',
            unloadingState: 'Uttar Pradesh',
            eWayBillNo: 'EWB2410100010',
            paymentTermsDays: 30,
            distanceKm: 1370,
            driverName: 'Ajay Verma',
            weightTons: 28,
            weightUnit: 'MT'),

        // ── BREAKDOWN TRIP — engine failure, penalty charged ────────
        TripLedger(
            id: 'TRP10011',
            date: '22/4/2026',
            partyName: 'Deepak Fertilisers Taloja',
            vehicleNo: 'GJ-01-WT-1007',
            route: 'Bharuch, Gujarat -> Mumbai, Maharashtra',
            ownership: VehicleOwnership.self,
            materialName: 'Sulphuric Acid',
            freightBilled: 82000,
            paymentReceived: 82000,
            diesel: 19500,
            toll: 5800,
            driverExp: 4500,
            // penalties field carries breakdown cost + customer penalty
            penalties: 53500,
            loadingPoint: 'Bharuch',
            unloadingPoint: 'Taloja, Navi Mumbai',
            loadingState: 'Gujarat',
            unloadingState: 'Maharashtra',
            eWayBillNo: 'EWB2410100011',
            paymentTermsDays: 30,
            distanceKm: 340,
            driverName: 'Sukhvinder Gill',
            weightTons: 22,
            weightUnit: 'MT',
            lrNotes:
                'ENGINE FAILURE near Surat. Recovery truck ₹23,500 + repairs ₹15,000. Customer penalty ₹15,000 for 3-day delay. Total loss on trip.'),

        // ── LOSS TRIP — tyre blowout, payment withheld ───────────────
        TripLedger(
            id: 'TRP10012',
            date: '24/4/2026',
            partyName: 'BASF India Ltd',
            vehicleNo: 'GJ-01-WT-1002',
            route: 'Dahej, Gujarat -> Pune, Maharashtra',
            ownership: VehicleOwnership.self,
            materialName: 'Acetic Acid',
            freightBilled: 76000,
            paymentReceived: 0,
            diesel: 18200,
            toll: 5200,
            driverExp: 4000,
            materialLoss: 12000,
            penalties: 65000,
            loadingPoint: 'Dahej Port',
            unloadingPoint: 'Pune',
            loadingState: 'Gujarat',
            unloadingState: 'Maharashtra',
            eWayBillNo: 'EWB2410100012',
            paymentTermsDays: 30,
            distanceKm: 590,
            driverName: 'Ramesh Devasi',
            weightTons: 20,
            weightUnit: 'MT',
            lrNotes:
                'TYRE BLOWOUT on Pune Expressway. Minor cargo spillage. Customer raised damage claim ₹65,000. Payment WITHHELD. Insurance surveyor visit pending.'),
      ];

  // ── Demo maintenance tickets (breakdowns + routine service) ────
  List<MaintenanceTicket> _demoMaintenanceTickets() => [
        MaintenanceTicket(
            id: 'MX001',
            vehicleNo: 'GJ-01-WT-1007',
            issue:
                'SOS: Engine Failure - Overheating near Surat. Recovery truck hired. Coolant leak, water pump replaced. Cost ₹28,500.',
            priority: BreakdownPriority.sos,
            status: 'closed',
            odometerKm: 142500,
            createdAt: DateTime.now()
                .subtract(const Duration(days: 8))
                .toIso8601String()),
        MaintenanceTicket(
            id: 'MX002',
            vehicleNo: 'GJ-01-WT-1002',
            issue:
                'SOS: Tyre Blowout - Front Left on Pune Expressway. Emergency replacement + crane. Cost ₹12,000.',
            priority: BreakdownPriority.sos,
            status: 'closed',
            odometerKm: 98200,
            createdAt: DateTime.now()
                .subtract(const Duration(days: 6))
                .toIso8601String()),
        MaintenanceTicket(
            id: 'MX003',
            vehicleNo: 'GJ-01-WT-1000',
            issue:
                'Engine Oil & Filter Change overdue. Odometer at 1,58,000 km (15,000 km since last service). Schedule ASAP.',
            priority: BreakdownPriority.urgent,
            status: 'open',
            odometerKm: 158000,
            dueAtKm: 145000,
            createdAt: DateTime.now()
                .subtract(const Duration(days: 2))
                .toIso8601String()),
        MaintenanceTicket(
            id: 'MX004',
            vehicleNo: 'GJ-01-WT-1004',
            issue:
                'URGENT: Brake Pad Wear - Rear Axle. Driver reported grinding noise. DO NOT DISPATCH. Est. repair ₹8,000-12,000.',
            priority: BreakdownPriority.urgent,
            status: 'open',
            odometerKm: 112000,
            createdAt: DateTime.now()
                .subtract(const Duration(days: 1))
                .toIso8601String()),
        MaintenanceTicket(
            id: 'MX005',
            vehicleNo: 'GJ-01-WT-1001',
            issue:
                'Routine 30,000 km service completed. Oil, filter, belt tensioner replaced. All clear.',
            priority: BreakdownPriority.service,
            status: 'closed',
            odometerKm: 30000,
            createdAt: DateTime.now()
                .subtract(const Duration(days: 15))
                .toIso8601String()),
      ];

  // ── Demo compliance vault (documents with expiry) ──────────────
  List<ComplianceVaultItem> _demoComplianceVault() => [
        ComplianceVaultItem(
            id: 'DOC_RC_1000',
            vehicleNo: 'GJ-01-WT-1000',
            documentName: 'Registration Certificate (RC)',
            expiryDate: '15/11/2026',
            filePath: ''),
        ComplianceVaultItem(
            id: 'DOC_INS_1000',
            vehicleNo: 'GJ-01-WT-1000',
            documentName: 'Insurance Policy',
            expiryDate: '30/06/2026',
            filePath: ''), // expiring in ~45 days
        ComplianceVaultItem(
            id: 'DOC_FIT_1001',
            vehicleNo: 'GJ-01-WT-1001',
            documentName: 'Fitness Certificate',
            expiryDate: '10/06/2026',
            filePath: ''), // expiring in ~25 days - URGENT
        ComplianceVaultItem(
            id: 'DOC_PUC_1002',
            vehicleNo: 'GJ-01-WT-1002',
            documentName: 'PUC Certificate',
            expiryDate: '01/06/2026',
            filePath: ''), // expiring in ~15 days - CRITICAL
        ComplianceVaultItem(
            id: 'DOC_PERM_1003',
            vehicleNo: 'GJ-01-WT-1003',
            documentName: 'National Permit',
            expiryDate: '22/05/2026',
            filePath: ''), // expiring in ~5 days - VERY URGENT
        ComplianceVaultItem(
            id: 'DOC_INS_1004',
            vehicleNo: 'GJ-01-WT-1004',
            documentName: 'Insurance Policy',
            expiryDate: '28/04/2025',
            filePath: ''), // ALREADY EXPIRED
        ComplianceVaultItem(
            id: 'DOC_RC_1005',
            vehicleNo: 'GJ-01-WT-1005',
            documentName: 'Registration Certificate (RC)',
            expiryDate: '20/12/2026',
            filePath: ''),
        ComplianceVaultItem(
            id: 'DOC_FIT_1006',
            vehicleNo: 'GJ-01-WT-1006',
            documentName: 'Fitness Certificate',
            expiryDate: '08/09/2026',
            filePath: ''),
        ComplianceVaultItem(
            id: 'DOC_PERM_1007',
            vehicleNo: 'GJ-01-WT-1007',
            documentName: 'Hazardous Goods Permit',
            expiryDate: '15/07/2026',
            filePath: ''),
        ComplianceVaultItem(
            id: 'DOC_DL_HARPREET',
            vehicleNo: 'GJ-01-WT-1000',
            documentName: 'Driver Licence - Harpreet Singh',
            expiryDate: '12/03/2027',
            filePath: ''),
        ComplianceVaultItem(
            id: 'DOC_DL_RAJU',
            vehicleNo: 'GJ-01-WT-1001',
            documentName: 'Driver Licence - Raju Yadav',
            expiryDate: '05/05/2026',
            filePath: ''), // expiring in ~10 days
      ];

  // Returns a UID-scoped key so different users on same device never share data
  String _k(String key) {
    final uid = FirebaseService.currentUser?.uid ?? 'local';
    return '${uid}_$key';
  }

  Future<void> _save() async {
    // Local cache (fast, offline-first) — keyed by UID for data isolation
    final p = await SharedPreferences.getInstance();
    await p.setString(_k('fm_profile'), jsonEncode(userProfile.toJson()));
    await p.setString(_k('fm_sub'), jsonEncode(subscription.toJson()));
    await p.setString(
        _k('fm_ledgers'), jsonEncode(ledgers.map((e) => e.toJson()).toList()));
    await p.setString(
        _k('fm_fleet'), jsonEncode(fleet.map((e) => e.toJson()).toList()));
    await p.setString(
        _k('fm_drivers'), jsonEncode(drivers.map((e) => e.toJson()).toList()));
    await p.setString(_k('fm_market'),
        jsonEncode(marketLoads.map((e) => e.toJson()).toList()));
    await p.setString(
        _k('fm_kredx'), jsonEncode(kredxApps.map((e) => e.toJson()).toList()));
    await p.setString(_k('rm_modules'), jsonEncode(moduleState.toJson()));
    // Cloud sync (multi-device real-time) — fire-and-forget
    if (FirebaseService.isReady && FirebaseService.currentUser != null) {
      FirebaseService.saveProfile(userProfile.toJson()).ignore();
      FirebaseService.saveSubscription(subscription.toJson()).ignore();
      FirebaseService.saveLedgers(ledgers).ignore();
      FirebaseService.saveFleet(fleet).ignore();
      FirebaseService.saveDrivers(drivers).ignore();
      // Write drivers to publicDrivers for phone-based lookup
      try {
        final uid = FirebaseService.currentUser?.uid ?? '';
        if (uid.isNotEmpty) {
          for (final d in drivers) {
            if (d.phone.isNotEmpty) {
              final cleanPhone = d.phone.replaceAll(RegExp(r'\D'), '');
              final lastTen = cleanPhone.length >= 10
                  ? cleanPhone.substring(cleanPhone.length - 10)
                  : cleanPhone;
              FirebaseFirestore.instance
                  .collection('publicDrivers')
                  .doc(lastTen)
                  .set({
                'phone': lastTen,
                'name': d.name,
                'fleetOwnerUid': uid,
                'license': d.dlNum,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true)).ignore();
            }
          }
        }
      } catch (_) {}
      for (final k in kredxApps) {
        FirebaseService.saveKredXApp(k).ignore();
      }
    }
  }

  void _upsertComplianceVaultItem(Asset asset, FleetDoc doc) {
    final item = ComplianceVaultItem(
        id: '${asset.id}_${doc.name}'.replaceAll(' ', '_'),
        vehicleNo: asset.number,
        documentName: doc.name,
        expiryDate: doc.expiryDate,
        filePath: doc.filePath);
    final idx = moduleState.complianceVault.indexWhere((e) => e.id == item.id);
    if (idx >= 0) {
      moduleState.complianceVault[idx] = item;
    } else {
      moduleState.complianceVault.add(item);
    }
  }

  // ignore: unused_element
  void _recordTripExpenseReceipt(TripExpenseReceipt receipt) {
    final matches = _visibleLedgers.where((l) => l.id == receipt.ledgerId);
    if (matches.isNotEmpty) {
      RouteMasterOps.syncExpenseToLedger(matches.first, receipt);
    }
    moduleState.expenseReceipts.insert(0, receipt);
    _save();
  }

  // ignore: unused_element
  PodBillingEvent? _recordPodAndCreateInvoice(
      TripLedger ledger, String podImagePath, String documentNo) {
    final event = RouteMasterOps.createPodInvoice(ledger,
        podImagePath: podImagePath, documentNo: documentNo);
    moduleState.podBilling.insert(0, event);
    _save();
    return event;
  }

  // Only alert when <=5 days away (not overdue yet)
  void _checkPaymentAlerts() {
    final dueSoon = _visibleLedgers
        .where((l) => l.isDueSoon && !l.isPaymentOverdue)
        .toList();
    if (dueSoon.isEmpty) return;
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      showDialog(
          context: context,
          builder: (c) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: Row(children: [
                  Icon(Icons.schedule, color: Colors.orange[700]),
                  const SizedBox(width: 10),
                  const Text("Payment Due Soon",
                      style: TextStyle(fontWeight: FontWeight.w900))
                ]),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          "Alert ${dueSoon.length} payment${dueSoon.length > 1 ? 's' : ''} due within ${AppConfig.paymentAlertDays} days",
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.orange)),
                      const SizedBox(height: 8),
                      ...dueSoon.take(4).map((l) {
                        final d = l.paymentDueDate;
                        return Text(
                            "- ${l.partyName} - Rs.${l.partyPending.toStringAsFixed(0)} (due ${d != null ? '${d.day}/${d.month}' : ''})",
                            style: const TextStyle(fontSize: 13));
                      }),
                    ]),
                actions: [
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF6FAFF)),
                      onPressed: () {
                        Navigator.pop(c);
                        setState(() => _idx = 3);
                      },
                      child: const Text("View Ledger",
                          style: TextStyle(color: Color(0xFF0F172A)))),
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text("Dismiss"))
                ],
              ));
    });
  }

  void openAiControlTower({
    required BuildContext context,
    required List<TripLedger> ledgers,
    required List<BankEntry> bankEntries,
    required List<MaintenanceTicket> maintenanceTickets,
    required List<Asset> fleet,
    required List<MarketLoad> marketLoads,
    required List<ComplianceVaultItem> complianceVault,
    required void Function(String id, double amount) onApplyReconciliation,
    VoidCallback? onImportCsv,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiControlTowerScreen(
          ledgers: ledgers,
          bankEntries: bankEntries,
          maintenanceTickets: maintenanceTickets,
          fleet: fleet,
          marketLoads: marketLoads,
          complianceVault: complianceVault,
          onApplyReconciliation: onApplyReconciliation,
          onImportCsv: onImportCsv,
          tier: subscription.tier,
        ),
      ),
    );
  }

  // Hidden admin: tap title 7x in 3 seconds
  // ignore: unused_element
  void _handleAdminTap() {
    final now = DateTime.now();
    if (_lastAdminTap == null ||
        now.difference(_lastAdminTap!).inMilliseconds >
            AppConfig.adminTapWindowMs) {
      _adminTaps = 1;
    } else {
      _adminTaps++;
    }
    _lastAdminTap = now;
    if (_adminTaps >= AppConfig.adminTapCount) {
      _adminTaps = 0;
      _promptAdminPin();
    }
  }

// duplicate AIControlTowerScreen removed; use existing AiControlTowerScreen defined earlier in file

  //
  void sendOTPToDriver(String phone, Function(bool verified) onResult) {
    String verId = '';
    final otpCtrl = TextEditingController();
    bool codeSent = false, loading = true;
    String err = '';
    final fmtPhone = phone.startsWith('+')
        ? phone
        : '+91${phone.replaceAll(RegExp(r'\D'), '')}';

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => StatefulBuilder(builder: (c2, ss) {
              if (loading && !codeSent && err.isEmpty) {
                FirebaseService.sendOTP(
                    phone: fmtPhone,
                    onCodeSent: (vid) => ss(() {
                          verId = vid;
                          codeSent = true;
                          loading = false;
                        }),
                    onError: (e) => ss(() {
                          err = e;
                          loading = false;
                        }));
              }
              return AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                title: const Row(children: [
                  Icon(Icons.sms, color: Color(0xFF0F172A)),
                  SizedBox(width: 8),
                  Text("OTP Verification",
                      style: TextStyle(fontWeight: FontWeight.w800))
                ]),
                content: loading
                    ? const SizedBox(
                        height: 70,
                        child: Center(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text("Sending OTP to number...",
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 13))
                            ])))
                    : err.isNotEmpty
                        ? Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 44),
                            const SizedBox(height: 10),
                            Text(err,
                                style: const TextStyle(color: Colors.red),
                                textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            const Text(
                                "Enable Phone Auth in Firebase Console -> Authentication -> Sign-in providers",
                                style:
                                    TextStyle(fontSize: 11, color: Colors.grey),
                                textAlign: TextAlign.center),
                          ])
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Row(children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.green, size: 16),
                                  const SizedBox(width: 8),
                                  Flexible(
                                      child: Text("OTP sent to $fmtPhone",
                                          style: const TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.w700)))
                                ])),
                            const SizedBox(height: 14),
                            TextField(
                                controller: otpCtrl,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                autofocus: true,
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 8),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                    labelText: "Enter 6-digit OTP",
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    counterText: '')),
                          ]),
                actions: [
                  TextButton(
                      onPressed: () {
                        Navigator.pop(c);
                        onResult(false);
                      },
                      child: const Text("Cancel")),
                  if (codeSent)
                    ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF6FAFF),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        icon: const Icon(Icons.verified,
                            color: Color(0xFF0F172A), size: 16),
                        label: const Text("Verify",
                            style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          if (otpCtrl.text.length < 6) return;
                          ss(() => loading = true);
                          final ok = await FirebaseService.verifyOTP(
                              verificationId: verId, otp: otpCtrl.text);
                          Navigator.pop(c);
                          onResult(ok);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              backgroundColor: ok ? Colors.green : Colors.red,
                              behavior: SnackBarBehavior.floating,
                              content: Text(ok
                                  ? "OK Phone verified!"
                                  : "Incorrect OTP. Try again.")));
                        }),
                ],
              );
            }));
  }

  void _promptAdminPin() {
    final pinCtrl = TextEditingController();
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: const Row(children: [
                Icon(Icons.admin_panel_settings_rounded,
                    color: Color(0xFF0EA5E9)),
                SizedBox(width: 10),
                Text('Admin Dashboard',
                    style: TextStyle(fontWeight: FontWeight.bold))
              ]),
              content: TextField(
                controller: pinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Enter Admin PIN',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onSubmitted: (v) {
                  if (AppConfig.validatePin(v)) {
                    Navigator.pop(c);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const AdvancedAdminScreen()));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Wrong PIN'),
                        backgroundColor: Colors.red));
                  }
                },
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Cancel')),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0EA5E9)),
                    onPressed: () {
                      if (AppConfig.validatePin(pinCtrl.text)) {
                        Navigator.pop(c);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AdvancedAdminScreen()));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Wrong PIN'),
                                backgroundColor: Colors.red));
                      }
                    },
                    child: const Text('Enter',
                        style: TextStyle(color: Colors.white))),
              ],
            ));
  }

  void _upgradeBanner(String feat) => showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.workspace_premium,
                      color: Colors.amber, size: 36)),
              const SizedBox(height: 16),
              Text("Unlock $feat",
                  style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 22,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text("Upgrade to access $feat.",
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: Color(0x66334155), fontSize: 14)),
              const SizedBox(height: 24),
              SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber[700],
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onPressed: () {
                        Navigator.pop(context);
                        _openSub();
                      },
                      child: const Text("View Plans & Upgrade",
                          style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                              fontSize: 16)))),
              const SizedBox(height: 12),
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Not now",
                      style: TextStyle(color: Color(0x33334155)))),
            ]),
          ));

  void _openSub() => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => SubscriptionScreen(
              current: subscription,
              onUpgrade: (t) {
                setState(() {
                  subscription.tier = t;
                  final exp = DateTime.now().add(const Duration(days: 30));
                  subscription.expiryDate =
                      "${exp.day}/${exp.month}/${exp.year}";
                });
                _save();
              },
              onAddOnsUpdate: (addOns, extraUsers, extraVehicleBlocks) {
                setState(() {
                  subscription.addOns = addOns;
                  subscription.extraUsers = extraUsers;
                  subscription.extraVehicleBlocks = extraVehicleBlocks;
                });
                _save();
              })));

  //
  // ignore: unused_element
  Widget _aiMiniKpi(String val, String label, Color c) => Expanded(
          child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        margin: const EdgeInsets.only(right: 6),
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8)),
        child: Column(children: [
          Text(val,
              style: TextStyle(
                  color: c, fontWeight: FontWeight.w900, fontSize: 15)),
          Text(label,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 9)),
        ]),
      ));

  Widget _buildDriverDash() {
    // Clean minimal driver dashboard
    final myTrips = _visibleLedgers
        .where((l) =>
            l.driverName == userProfile.companyName || l.vehicleNo.isNotEmpty)
        .toList();
    final pendingSalary = drivers
        .where((d) => d.phone == userProfile.phone)
        .fold(0.0, (s, d) => s + d.balance);
    final activeTrips = myTrips.where((l) => l.partyPending > 0).length;
    return ListView(padding: const EdgeInsets.all(20), children: [
      // Greeting
      Row(children: [
        Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.drive_eta_rounded,
                color: Color(0xFF10B981), size: 26)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Good Day, Driver',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          Text(
              userProfile.companyName.isNotEmpty
                  ? userProfile.companyName
                  : userProfile.phone,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A))),
        ]),
      ]),
      const SizedBox(height: 20),
      // Stats row
      Row(children: [
        Expanded(
            child: _driverStatCard('My Trips', '$activeTrips active',
                Icons.local_shipping_rounded, const Color(0xFF0EA5E9))),
        const SizedBox(width: 12),
        GestureDetector(
            onTap: () {
              final de = drivers.where((d) {
                final dp = d.phone.replaceAll(RegExp(r'\D'), '');
                final up = userProfile.phone.replaceAll(RegExp(r'\D'), '');
                if (dp.isEmpty || up.isEmpty) return false;
                final dp10 =
                    dp.length >= 10 ? dp.substring(dp.length - 10) : dp;
                final up10 =
                    up.length >= 10 ? up.substring(up.length - 10) : up;
                return dp10 == up10;
              }).firstOrNull;
              _showDriverSalarySheet(de);
            },
            child: Expanded(
                child: _driverStatCard(
                    'Salary ▶',
                    '₹${pendingSalary.toStringAsFixed(0)}',
                    Icons.payments_rounded,
                    pendingSalary >= 0
                        ? const Color(0xFF10B981)
                        : const Color(0xFFEF4444)))),
      ]),
      const SizedBox(height: 12),
      // Today's trip if any
      if (myTrips.isNotEmpty) ...[
        const Text('Recent Trips',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF0F172A))),
        const SizedBox(height: 10),
        ...myTrips.take(3).map((l) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              child: _themeCard(
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                  child: Text(l.route,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14),
                                      overflow: TextOverflow.ellipsis)),
                              Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                      color: l.partyPending > 0
                                          ? Colors.orange.withValues(alpha: 0.1)
                                          : Colors.green.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text(
                                      l.partyPending > 0
                                          ? 'Pending'
                                          : 'Settled',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: l.partyPending > 0
                                              ? Colors.orange
                                              : Colors.green))),
                            ]),
                        const SizedBox(height: 6),
                        Row(children: [
                          const Icon(Icons.directions_car_rounded,
                              size: 13, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(l.vehicleNo,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                          const SizedBox(width: 12),
                          const Icon(Icons.calendar_today_rounded,
                              size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(l.date,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 12)),
                        ]),
                      ]),
                  padding: const EdgeInsets.all(14)),
            )),
      ] else ...[
        _themeCard(
            const Column(children: [
              Icon(Icons.inbox_rounded, size: 40, color: Colors.grey),
              SizedBox(height: 8),
              Text('No trips assigned yet',
                  style: TextStyle(
                      color: Colors.grey, fontWeight: FontWeight.w600)),
            ]),
            padding: const EdgeInsets.all(24)),
      ],
    ]);
  }

  // ── Theme-aware card builder ────────────────────────────────────────────
  Widget _themeCard(
    Widget child, {
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    double radius = 14,
  }) {
    final config = ThemeHelper.getConfig(ref.watch(appThemeProvider));
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          padding: padding,
          decoration: BoxDecoration(
            color:
                config.cardColor.withValues(alpha: config.isDark ? 0.92 : 0.94),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: config.cardBorder, width: 1),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: config.isDark
                  ? const [Color(0xFF172A42), Color(0xFF101F32)]
                  : const [Color(0xFFFFFFFF), Color(0xFFF4F8FC)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: config.shadowOpacity),
                blurRadius: config.isDark ? 24 : 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: config.primaryTextColor),
            child: IconTheme.merge(
              data: IconThemeData(color: config.primaryTextColor),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  // Convenience getters using new cardBorder field
  Color get _cardBg =>
      ThemeHelper.getConfig(ref.read(appThemeProvider)).cardColor;
  // ignore: unused_element
  BoxDecoration _cardDeco({double radius = 14}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(radius),
      border:
          Border.all(color: Colors.white.withValues(alpha: 0.40), width: 1.5),
    );
  }

  Widget _driverStatCard(
          String title, String value, IconData icon, Color color) =>
      _themeCard(Row(children: [
        Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 15)),
        ])),
      ]));

  Widget _buildDash() {
    final themeConfig = ThemeHelper.getConfig(ref.watch(appThemeProvider));
    final v = _visibleLedgers;
    double rev = v.fold<double>(0, (s, l) => s + l.freightBilled);
    double exp = v.fold(
        0,
        (s, l) =>
            s +
            (l.ownership == VehicleOwnership.self
                ? l.selfExpenses
                : l.marketTruckFreight));
    double profit = v.fold<double>(0, (s, l) => s + l.tripProfit);
    double pending = v.fold<double>(
        0, (s, l) => s + (l.partyPending > 0 ? l.partyPending : 0));
    int dueSoon = v.where((l) => l.isDueSoon && !l.isPaymentOverdue).length;
    int overdue = v.where((l) => l.isPaymentOverdue).length;
    // Complete trips after ETA when unloading LR is not available yet.
    _expireTripsPastEta();
    // Include booked (not-yet-dispatched) loads as "active"
    final now = DateTime.now();
    final activeLedgers = v.where((l) {
      if (l.estimatedArrival.isNotEmpty) {
        try {
          if (!now.isBefore(DateTime.parse(l.estimatedArrival))) return false;
        } catch (_) {}
      }
      return l.isInTransit ||
          (l.lrNotes.contains('BOOKED_LOAD:') && l.dispatchedAt.isEmpty);
    }).toList();
    int activeN = activeLedgers.length;
    final hour = DateTime.now().hour;
    final greet = hour < 12
        ? t('good_morning')
        : hour < 17
            ? t('good_afternoon')
            : t('good_evening');

    return ListView(padding: EdgeInsets.zero, children: [
      // ── Compact dashboard summary ─────────────────────────────
      Container(
        decoration: BoxDecoration(
          color: themeConfig.isDark
              ? const Color(0xFF111C2D)
              : const Color(0xFF17324D),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  '$greet, ${(() {
                    final dn = FirebaseService.currentUser?.displayName ?? '';
                    return dn.isNotEmpty
                        ? dn.split(" ").first
                        : (userProfile.companyName.isNotEmpty
                            ? userProfile.companyName.split(" ").first
                            : "there");
                  })()} 👋',
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              const Text('NavGati',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      height: 1.1)),
            ]),
            GestureDetector(
                onTap: _openSub,
                child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.workspace_premium_rounded,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 5),
                      Text(subscription.tierName,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900)),
                    ]))),
          ]),
          const SizedBox(height: 20),
          // Revenue summary inline
          GestureDetector(
              onTap: () => setState(() {
                    _idx = 3;
                    _khataFilter = 'All';
                  }),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14))),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(t('total_revenue'),
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(_fmtAmt(rev),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900))),
                      ])),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    _heroBadge(
                        t('profit'),
                        profit,
                        profit >= 0
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFFCA5A5)),
                    const SizedBox(height: 6),
                    _heroBadge(t('expenses'), exp, const Color(0xFFFCA5A5)),
                  ]),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded,
                      color: Colors.white54, size: 20),
                ]),
              )),
        ]),
      ),

      // ── Overdue / Due Soon alert ──────────────────────────────
      if (overdue > 0 || dueSoon > 0)
        GestureDetector(
            onTap: () => setState(() {
                  _idx = 3;
                  _khataFilter = overdue > 0 ? 'Overdue' : 'Due Soon';
                  _khataFilterVal = null;
                }),
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                  color: overdue > 0
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: overdue > 0
                          ? const Color(0xFFFCA5A5)
                          : const Color(0xFFFDE68A)),
                  boxShadow: [
                    BoxShadow(
                        color: (overdue > 0 ? Colors.red : Colors.orange)
                            .withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ]),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: overdue > 0
                            ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                            : Colors.orange.withValues(alpha: 0.12),
                        shape: BoxShape.circle),
                    child: Icon(
                        overdue > 0
                            ? Icons.warning_amber_rounded
                            : Icons.schedule_rounded,
                        color: overdue > 0
                            ? const Color(0xFFEF4444)
                            : Colors.orange,
                        size: 20)),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                          overdue > 0
                              ? '$overdue Overdue Payment${overdue > 1 ? "s" : ""}'
                              : '$dueSoon Due Soon',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: overdue > 0
                                  ? const Color(0xFFB91C1C)
                                  : const Color(0xFF92400E))),
                      Text(
                          overdue > 0
                              ? t('tap_collect')
                              : 'Due in ${AppConfig.paymentAlertDays} days',
                          style: TextStyle(
                              fontSize: 11,
                              color: overdue > 0
                                  ? const Color(0xFFEF4444)
                                  : Colors.orange)),
                    ])),
                Text(t('view'),
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        color: overdue > 0
                            ? const Color(0xFFB91C1C)
                            : const Color(0xFF92400E))),
              ]),
            )),

      // ── 3 Big KPI tiles ──────────────────────────────────────
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(children: [
            Expanded(
                child: _kpiCard(
                    icon: Icons.local_shipping_rounded,
                    iconBg: const Color(0xFFEFF6FF),
                    iconColor: const Color(0xFF3B82F6),
                    label: t('in_transit'),
                    value: '$activeN',
                    sub: activeN == 0
                        ? 'None active'
                        : '$activeN trip${activeN > 1 ? "s" : ""} active',
                    onTap: () {
                      if (activeLedgers.isEmpty) {
                        _showNewEntry();
                        return;
                      }
                      showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => DraggableScrollableSheet(
                              initialChildSize: 0.65,
                              maxChildSize: 0.95,
                              minChildSize: 0.35,
                              builder: (_, sc) => Container(
                                  decoration: const BoxDecoration(
                                      color: Color(0xFFF6FAFF),
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(24))),
                                  child: Column(children: [
                                    Container(
                                        margin: const EdgeInsets.symmetric(
                                            vertical: 10),
                                        width: 40,
                                        height: 4,
                                        decoration: BoxDecoration(
                                            color: Colors.grey[300],
                                            borderRadius:
                                                BorderRadius.circular(4))),
                                    Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 20, vertical: 6),
                                        child: Row(children: [
                                          const Icon(
                                              Icons.local_shipping_rounded,
                                              color: Color(0xFF3B82F6)),
                                          const SizedBox(width: 10),
                                          Text(
                                              'In Transit (${activeLedgers.length})',
                                              style: const TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w900)),
                                        ])),
                                    const Divider(height: 1),
                                    Expanded(
                                        child: ListView.separated(
                                            controller: sc,
                                            padding: const EdgeInsets.all(14),
                                            itemCount: activeLedgers.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(height: 10),
                                            itemBuilder: (_, i) {
                                              final l = activeLedgers[i];
                                              final isBooked = l.lrNotes
                                                      .contains(
                                                          'BOOKED_LOAD:') &&
                                                  !l.isInTransit;
                                              final accentColor = isBooked
                                                  ? Colors.orange
                                                  : const Color(0xFF3B82F6);
                                              return ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  child: Stack(children: [
                                                    _themeCard(
                                                        Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceBetween,
                                                                  children: [
                                                                    Expanded(
                                                                        child: Text(
                                                                            l.partyName,
                                                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                                                                            overflow: TextOverflow.ellipsis)),
                                                                    Container(
                                                                        padding: const EdgeInsets
                                                                            .symmetric(
                                                                            horizontal:
                                                                                8,
                                                                            vertical:
                                                                                3),
                                                                        decoration: BoxDecoration(
                                                                            color: isBooked
                                                                                ? Colors.orange.withValues(alpha: 0.1)
                                                                                : Colors.blue.withValues(alpha: 0.1),
                                                                            borderRadius: BorderRadius.circular(6)),
                                                                        child: Text(isBooked ? 'BOOKED' : 'EN ROUTE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: isBooked ? Colors.orange : const Color(0xFF3B82F6)))),
                                                                  ]),
                                                              const SizedBox(
                                                                  height: 4),
                                                              Text(l.route,
                                                                  style: const TextStyle(
                                                                      color: Colors
                                                                          .grey,
                                                                      fontSize:
                                                                          11),
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  maxLines: 1),
                                                              const SizedBox(
                                                                  height: 6),
                                                              Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .spaceBetween,
                                                                  children: [
                                                                    Text(l.vehicleNo,
                                                                        style: const TextStyle(
                                                                            color:
                                                                                Color(0xFF3B82F6),
                                                                            fontWeight: FontWeight.w700,
                                                                            fontSize: 12)),
                                                                    Text(
                                                                        'Rs.${l.freightBilled.toStringAsFixed(0)}',
                                                                        style: const TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.w900,
                                                                            fontSize: 13)),
                                                                  ]),
                                                            ]),
                                                        padding:
                                                            const EdgeInsets
                                                                .all(14)),
                                                    // Left accent bar overlay
                                                    Positioned(
                                                        left: 0,
                                                        top: 0,
                                                        bottom: 0,
                                                        child: Container(
                                                            width: 4,
                                                            color:
                                                                accentColor)),
                                                  ]));
                                            })),
                                  ]))));
                    })),
            const SizedBox(width: 10),
            Expanded(
                child: _kpiCard(
                    icon: Icons.account_balance_wallet_rounded,
                    iconBg: const Color(0xFFFFF7ED),
                    iconColor: const Color(0xFFF97316),
                    label: t('pending'),
                    value: _fmtAmt(pending),
                    sub: pending > 0 ? t('collect_now') : t('all_clear'),
                    onTap: () => setState(() {
                          _idx = 3;
                          _khataFilter = 'Pending';
                          _khataFilterVal = null;
                        }))),
            const SizedBox(width: 10),
            Expanded(
                child: _kpiCard(
                    icon: Icons.local_shipping_outlined,
                    iconBg: const Color(0xFFF5F3FF),
                    iconColor: const Color(0xFF8B5CF6),
                    label: t('fleet'),
                    value: '${fleet.length}',
                    sub: fleet.isEmpty
                        ? 'Add vehicle'
                        : '${fleet.length} vehicle',
                    onTap: () => setState(() => _idx = _isFleetOwner ? 4 : 3))),
          ])),

      // ── Quick Actions ─────────────────────────────────────────
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Row(children: [
            Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                    color: const Color(0xFF0EA5E9),
                    borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Text(t('quick_actions'),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A))),
          ])),
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Row(children: [
            Expanded(
                child: _actBtn2(Icons.add_box_rounded, t('new_trip'),
                    const Color(0xFF0EA5E9), () => _showNewEntry())),
            const SizedBox(width: 8),
            Expanded(
                child: _actBtn2(Icons.gps_fixed_rounded, t('track'),
                    const Color(0xFF10B981), () {
              _trackDialog();
            })),
            const SizedBox(width: 8),
            Expanded(
                child: _actBtn2(
                    Icons.file_upload_outlined,
                    t('export'),
                    const Color(0xFF6366F1),
                    () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => TallyExportScreen(
                                ledgers: ledgers,
                                drivers: drivers,
                                userProfile: userProfile))))),
            const SizedBox(width: 8),
            Expanded(
                child: _actBtn2(Icons.account_balance_rounded, 'KredX',
                    const Color(0xFFF59E0B), () {
              if (!subscription.canUseKredX) {
                _upgradeBanner('KredX Invoice Financing');
                return;
              }
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => KredXScreen(
                          ledgers: ledgers,
                          kredxApps: kredxApps,
                          onApply: (a) {
                            setState(() => kredxApps.insert(0, a));
                            _save();
                          },
                          onUpdate: () {
                            setState(() {});
                            _save();
                          })));
            })),
          ])),

      const SizedBox(height: 24),
    ]);
  }

  // Compact badge for hero section
  Widget _heroBadge(String label, double amount, Color c) =>
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(label,
            style: TextStyle(
                color: c.withValues(alpha: 0.85),
                fontSize: 9,
                fontWeight: FontWeight.w600)),
        Text(_fmtAmt(amount),
            style:
                TextStyle(color: c, fontSize: 13, fontWeight: FontWeight.w900)),
      ]);

  // KPI card for home screen
  Widget _kpiCard(
          {required IconData icon,
          required Color iconBg,
          required Color iconColor,
          required String label,
          required String value,
          required String sub,
          required VoidCallback onTap}) =>
      GestureDetector(
          onTap: onTap,
          child: _themeCard(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: iconBg, borderRadius: BorderRadius.circular(10)),
                    child: Icon(icon, color: iconColor, size: 18)),
                const SizedBox(height: 8),
                Text(label,
                    style: const TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 17))),
                const SizedBox(height: 2),
                Text(sub,
                    style: const TextStyle(fontSize: 9),
                    overflow: TextOverflow.ellipsis),
              ]),
              padding: const EdgeInsets.all(12),
              radius: 16));

  Widget _chip(IconData icon, String label, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.withValues(alpha: 0.25))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: c),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: c, fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis)
        ]),
      );
  // ignore: unused_element
  Widget _statTile(String label, String val, IconData icon, Color c) =>
      Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border(left: BorderSide(color: c, width: 3)),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: c, size: 18),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(val,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A))),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ]));
  // ignore: unused_element
  Widget _actBtn(IconData icon, String label, Color c, VoidCallback onTap) =>
      InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                c.withValues(alpha: 0.12),
                c.withValues(alpha: 0.06)
              ], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: c, size: 18),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Color(0xFF0F172A)),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ));
  Widget _actBtn2(
          IconData icon, String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              color.withValues(alpha: 0.15),
              color.withValues(alpha: 0.08)
            ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
  // ignore: unused_element
  Widget _navIcon(IconData icon, int tabIdx) => Icon(icon,
      size: 24,
      color:
          _idx == tabIdx ? const Color(0xFF0EA5E9) : const Color(0xFF0F172A));
  String _fmtAmt(double v) => v >= 100000
      ? 'Rs.${(v / 100000).toStringAsFixed(1)}L'
      : v >= 1000
          ? 'Rs.${(v / 1000).toStringAsFixed(1)}K'
          : 'Rs.${v.toStringAsFixed(0)}';

  // ignore: unused_element
  Widget _statCard(String label, String value, IconData icon, Color color) =>
      _themeCard(
          Row(children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 20)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3)),
                  const SizedBox(height: 2),
                  FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(value,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: color))),
                ])),
          ]),
          padding: const EdgeInsets.all(14),
          radius: 16);
  // ignore: unused_element
  Widget _heroStat(String label, String value, Color c) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: TextStyle(
                    color: c, fontSize: 15, fontWeight: FontWeight.w900))),
        Text(label,
            style: const TextStyle(
                color: Color(0x55334155),
                fontSize: 10,
                fontWeight: FontWeight.w600)),
      ]);

  // ignore: unused_element
  Widget _miniCard(TripLedger l) {
    final c = l.isPaymentOverdue
        ? const Color(0xFFDC2626)
        : l.isDueSoon
            ? const Color(0xFF0EA5E9)
            : l.partyPending <= 0
                ? const Color(0xFF0EA5E9)
                : const Color(0xFF0EA5E9);
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFCBD5E1)),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFFFFFFFF).withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
            BoxShadow(
                color: c.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(children: [
          Container(
              width: 4,
              height: 44,
              decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: [c, c.withValues(alpha: 0.5)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(l.partyName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis),
                Text("${l.vehicleNo} - ${l.route}",
                    style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(
                        l.isPaymentOverdue
                            ? "OVERDUE"
                            : l.isDueSoon
                                ? "DUE SOON"
                                : l.partyPending <= 0
                                    ? "SETTLED"
                                    : "ACTIVE",
                        style: TextStyle(
                            color: c,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5))),
              ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            FittedBox(
                fit: BoxFit.scaleDown,
                child: Text("Rs.${l.freightBilled.toStringAsFixed(0)}",
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: Color(0xFF0F172A)))),
            Text(
                l.partyPending > 0
                    ? "Rs.${l.partyPending.toStringAsFixed(0)} due"
                    : "Paid",
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: c)),
          ]),
        ]));
  }

  // ignore: unused_element
  void _showExpenses() {
    final v = _visibleLedgers;
    double dsl = v.fold<double>(0, (s, l) => s + l.diesel);
    double tol = v.fold<double>(0, (s, l) => s + l.toll);
    double drv = v.fold<double>(0, (s, l) => s + l.driverExp);
    double los = v.fold<double>(0, (s, l) => s + l.materialLoss);
    double mkt = v
        .where((l) => l.ownership == VehicleOwnership.market)
        .fold<double>(0, (s, l) => s + l.marketTruckFreight);
    double pen = v.fold<double>(0, (s, l) => s + l.penalties);
    double tds = v.fold<double>(0, (s, l) => s + l.tdsDeduction);
    double rev = v.fold<double>(0, (s, l) => s + l.freightBilled);
    double out = dsl + tol + drv + los + mkt + pen + tds;
    showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (c) => Container(
              decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28))),
              padding: const EdgeInsets.all(28),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 20),
                const Text("Financial Breakdown",
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const Divider(height: 28, thickness: 1.5),
                _eRow("Diesel Fuel", dsl, Colors.orange),
                _eRow("Toll / FASTag", tol, Colors.blue),
                _eRow("Driver Expenses", drv, Colors.purple),
                _eRow("Material Loss", los, Colors.red[900]!),
                _eRow("Market Trucks", mkt, Colors.red),
                _eRow("Penalties", pen, Colors.deepOrange),
                _eRow("TDS Deducted", tds, Colors.brown),
                const Divider(height: 28, thickness: 1.5),
                _eRow("Total Outflow", out, Colors.black87, b: true),
                _eRow("Net Margin", rev - out, Colors.green, b: true),
              ]),
            ));
  }

  Widget _eRow(String l, double v, Color c, {bool b = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l,
            style: TextStyle(
                fontSize: 14,
                fontWeight: b ? FontWeight.w900 : FontWeight.w600)),
        Text("Rs.${v.toStringAsFixed(0)}",
            style:
                TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: c))
      ]));

  void _trackDialog() {
    final ctrl = TextEditingController();
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: const Text("Track Vehicle",
                    style: TextStyle(fontWeight: FontWeight.w900)),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 14,
                          fontWeight: FontWeight.w500),
                      controller: ctrl,
                      decoration: InputDecoration(
                          labelText: "Vehicle Number",
                          prefixIcon: const Icon(Icons.local_shipping),
                          filled: true,
                          fillColor: Colors.white,
                          labelStyle: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                          floatingLabelStyle: const TextStyle(
                              color: Color(0xFF0EA5E9),
                              fontWeight: FontWeight.w800,
                              fontSize: 12),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFF0EA5E9))),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Color(0xFF0EA5E9))),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                  color: Color(0xFF0EA5E9), width: 2)))),
                  if (fleet.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                        spacing: 8,
                        children: fleet.take(8).map<Widget>((a) {
                          final asset = a;
                          final isGreen = asset.fuelType != 'Diesel';
                          final fuelIcon = asset.fuelType == 'Electric'
                              ? '⚡'
                              : asset.fuelType == 'Hydrogen'
                                  ? '💧'
                                  : asset.fuelType == 'CNG'
                                      ? '🟢'
                                      : asset.fuelType == 'LNG'
                                          ? '🔵'
                                          : asset.fuelType == 'Hybrid'
                                              ? '🔋'
                                              : '';
                          return GestureDetector(
                              onTap: () => ctrl.text = asset.number,
                              child: Chip(
                                  label: Text(
                                      '${isGreen ? "$fuelIcon " : ""}${asset.number}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                  backgroundColor: isGreen
                                      ? Colors.green.withValues(alpha: 0.18)
                                      : Colors.blue.withValues(alpha: 0.18)));
                        }).toList())
                  ]
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel")),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF6FAFF),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      onPressed: () {
                        Navigator.pop(context);
                        final vno = ctrl.text.isEmpty && fleet.isNotEmpty
                            ? fleet.first.number
                            : ctrl.text.toUpperCase();
                        final matchLedger = _visibleLedgers
                            .where(
                                (l) => l.vehicleNo == vno && l.partyPending > 0)
                            .firstOrNull;
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => LiveTrackingScreen(
                                    route:
                                        matchLedger?.route ?? "Live Tracking",
                                    vehicleNo: vno,
                                    distanceKm: matchLedger?.distanceKm ?? 0,
                                    isLoaded: matchLedger?.isInTransit ?? false,
                                    materialName:
                                        matchLedger?.materialName ?? '',
                                    driverName: matchLedger?.driverName ?? '',
                                    tripId: matchLedger?.id ?? '',
                                    destination:
                                        matchLedger?.unloadingPoint ?? '',
                                    fuelEconomy:
                                        matchLedger?.fuelEconomy ?? 3.5,
                                    axles: fleet
                                            .where((v) =>
                                                v.number ==
                                                matchLedger?.vehicleNo)
                                            .firstOrNull
                                            ?.axleCount ??
                                        6)));
                      },
                      child: const Text("Track Now",
                          style: TextStyle(color: Color(0xFF0F172A))))
                ]));
  }

  //
  // Get trust score for a party from ledger payment history (0-100)
  // 100 = always paid on time, lower = late/missing payments
  int _partyTrustFromLedgers(String partyName) {
    final trips =
        _visibleLedgers.where((l) => l.partyName == partyName).toList();
    if (trips.isEmpty) return 100; // unknown = assume good
    final total = trips.length;
    final settled = trips.where((l) => l.partyPending <= 0).length;
    final overdue = trips.where((l) => l.isPaymentOverdue).length;
    // Formula: settled% - overdue penalty
    final score =
        ((settled / total) * 100 - (overdue / total) * 30).clamp(0, 100);
    return score.round();
  }

  // Haversine distance between two lat/lng points (in km)
  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  // Get approx lat/lng for a city name from kIndianCities (fallback: 0,0)
  // We store rough coords inline since this is offline-first
  static const Map<String, List<double>> _cityCoords = {
    'Ahmedabad': [23.03, 72.58],
    'Surat': [21.17, 72.83],
    'Vadodara': [22.30, 73.18],
    'Rajkot': [22.30, 70.80],
    'Bharuch': [21.72, 72.98],
    'Ankleshwar': [21.63, 73.00],
    'Hazira': [21.12, 72.65],
    'Dahej': [21.72, 72.55],
    'Mundra Port': [22.83, 69.72],
    'Kandla Port': [23.03, 70.22],
    'Vapi': [20.37, 72.90],
    'Morbi': [22.82, 70.83],
    'Jamnagar': [22.47, 70.07],
    'Mumbai': [19.08, 72.88],
    'Pune': [18.52, 73.86],
    'Nagpur': [21.15, 79.09],
    'Nashik': [19.99, 73.79],
    'Aurangabad': [19.88, 75.34],
    'Delhi': [28.61, 77.21],
    'Gurgaon': [28.46, 77.03],
    'Noida': [28.54, 77.39],
    'Panipat': [29.39, 76.97],
    'Ludhiana': [30.90, 75.85],
    'Amritsar': [31.63, 74.87],
    'Jaipur': [26.91, 75.79],
    'Jodhpur': [26.29, 73.02],
    'Udaipur': [24.58, 73.68],
    'Bhopal': [23.26, 77.41],
    'Indore': [22.72, 75.86],
    'Gwalior': [26.21, 78.18],
    'Hyderabad': [17.39, 78.49],
    'Visakhapatnam': [17.69, 83.22],
    'Vijayawada': [16.52, 80.62],
    'Chennai': [13.08, 80.27],
    'Coimbatore': [11.02, 76.96],
    'Madurai': [9.93, 78.12],
    'Bengaluru': [12.97, 77.59],
    'Mysore': [12.30, 76.64],
    'Mangalore': [12.87, 74.84],
    'Kolkata': [22.57, 88.36],
    'Haldia': [22.07, 88.09],
    'Siliguri': [26.71, 88.43],
    'Patna': [25.60, 85.13],
    'Ranchi': [23.35, 85.33],
    'Jamshedpur': [22.80, 86.19],
    'Lucknow': [26.85, 80.95],
    'Kanpur': [26.46, 80.33],
    'Agra': [27.18, 78.01],
    'Varanasi': [25.32, 83.01],
    'Prayagraj': [25.44, 81.84],
    'Chandigarh': [30.73, 76.78],
    'Bathinda': [30.21, 74.95],
    'Bhubaneswar': [20.30, 85.82],
    'Raipur': [21.25, 81.63],
    'Kochi': [9.93, 76.27],
    'Thiruvananthapuram': [8.52, 76.94],
  };

  List<double>? _coordsForCity(String city) => _cityCoords[city];

  Widget _buildFindLoad() {
    final allStates = [
      'All',
      ...kIndianCities.map((c) => c['state']!).toSet().toList()..sort()
    ];
    final originCities = _fOriginState == 'All'
        ? <String>['All']
        : [
            'All',
            ...kIndianCities
                .where((c) => c['state'] == _fOriginState)
                .map((c) => c['city']!)
                .toList()
              ..sort()
          ];
    final destCities = _fDestState == 'All'
        ? <String>['All']
        : [
            'All',
            ...kIndianCities
                .where((c) => c['state'] == _fDestState)
                .map((c) => c['city']!)
                .toList()
              ..sort()
          ];

    // Ensure selected city is valid for current state
    final validOriginCity =
        originCities.contains(_fOriginCity) ? _fOriginCity : 'All';
    final validDestCity = destCities.contains(_fDestCity) ? _fDestCity : 'All';

    final radiusOptions = [0.0, 50.0, 100.0, 200.0, 300.0, 500.0];

    final vis = marketLoads.where((l) {
      // Exclude dispatched, delivered, cancelled loads from board
      if (l.status == BidStatus.inTransit ||
          l.status == BidStatus.delivered ||
          l.status == BidStatus.cancelled) {
        return false;
      }
      // Booked but not yet dispatched: still show (with BOOKED badge) unless already in khata as inTransit
      if (l.status == BidStatus.booked) {
        // Check if corresponding ledger is now inTransit — if so, remove from board
        final marker = 'BOOKED_LOAD:${l.id}';
        final ledgerInTransit =
            ledgers.any((le) => le.lrNotes.contains(marker) && le.isInTransit);
        if (ledgerInTransit) return false;
      }
      if (l.status != BidStatus.pending && l.status != BidStatus.booked) {
        return false;
      }
      if (_fOriginState != 'All' && l.originState != _fOriginState) {
        return false;
      }
      if (_fDestState != 'All' && l.destState != _fDestState) return false;
      if (validOriginCity != 'All' && l.originCity != validOriginCity) {
        // If radius filter active, check distance
        if (_fRadiusKm > 0) {
          final refCoords = _coordsForCity(validOriginCity);
          final loadCoords = _coordsForCity(l.originCity);
          if (refCoords != null && loadCoords != null) {
            final dist = _haversineKm(
                refCoords[0], refCoords[1], loadCoords[0], loadCoords[1]);
            if (dist > _fRadiusKm) return false;
          } else {
            return false;
          }
        } else {
          return false;
        }
      }
      if (validDestCity != 'All' && l.destCity != validDestCity) {
        if (_fRadiusKm > 0) {
          final refCoords = _coordsForCity(validDestCity);
          final loadCoords = _coordsForCity(l.destCity);
          if (refCoords != null && loadCoords != null) {
            final dist = _haversineKm(
                refCoords[0], refCoords[1], loadCoords[0], loadCoords[1]);
            if (dist > _fRadiusKm) return false;
          } else {
            return false;
          }
        } else {
          return false;
        }
      }
      return true;
    }).toList();

    final hasFilters = _fOriginState != 'All' ||
        _fDestState != 'All' ||
        validOriginCity != 'All' ||
        validDestCity != 'All' ||
        _fRadiusKm > 0;

    return Column(children: [
      // Consignor notice
      if (_isConsignor)
        Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A))),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded,
                  color: Color(0xFF92400E), size: 16),
              SizedBox(width: 8),
              Expanded(
                  child: Text(
                      'You are a load poster. You can view loads here but cannot book them.',
                      style: TextStyle(
                          color: Color(0xFF92400E),
                          fontSize: 11,
                          fontWeight: FontWeight.w600))),
            ])),
      Container(
          color: const Color(0xFFF6FAFF),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Load Board",
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A))),
              Row(children: [
                if (hasFilters)
                  GestureDetector(
                      onTap: () => setState(() {
                            _fOriginState = 'All';
                            _fDestState = 'All';
                            _fOriginCity = 'All';
                            _fDestCity = 'All';
                            _fRadiusKm = 0;
                          }),
                      child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20)),
                          child: const Row(children: [
                            Icon(Icons.clear, size: 12, color: Colors.red),
                            SizedBox(width: 3),
                            Text("Clear",
                                style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ]))),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green[200]!)),
                    child: Text("${vis.length} Active",
                        style: TextStyle(
                            color: Colors.green[800],
                            fontSize: 11,
                            fontWeight: FontWeight.w800))),
              ]),
            ]),
            const SizedBox(height: 10),
            // Row 1: State filters
            Row(children: [
              Expanded(
                  child: DropdownButtonFormField<String>(
                      style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                      isExpanded: true,
                      initialValue: _fOriginState,
                      decoration: InputDecoration(
                          labelText: "From State",
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.trip_origin,
                              size: 14, color: Colors.green)),
                      items: allStates
                          .map((s) => DropdownMenuItem<String>(
                              value: s,
                              child: Text(s,
                                  style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (v) => setState(() {
                            _fOriginState = v!;
                            _fOriginCity = 'All';
                          }))),
              const SizedBox(width: 8),
              Expanded(
                  child: DropdownButtonFormField<String>(
                      style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                      isExpanded: true,
                      initialValue: _fDestState,
                      decoration: InputDecoration(
                          labelText: "To State",
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.location_on,
                              size: 14, color: Colors.red)),
                      items: allStates
                          .map((s) => DropdownMenuItem<String>(
                              value: s,
                              child: Text(s,
                                  style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (v) => setState(() {
                            _fDestState = v!;
                            _fDestCity = 'All';
                          }))),
            ]),
            // Row 2: City filters (visible only when state is selected)
            if (_fOriginState != 'All' || _fDestState != 'All') ...[
              const SizedBox(height: 8),
              Row(children: [
                if (_fOriginState != 'All')
                  Expanded(
                      child: DropdownButtonFormField<String>(
                          style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                          isExpanded: true,
                          initialValue: validOriginCity,
                          decoration: InputDecoration(
                              labelText: "From City",
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              prefixIcon: const Icon(Icons.location_city,
                                  size: 14, color: Colors.green)),
                          items: originCities
                              .map((c) => DropdownMenuItem<String>(
                                  value: c,
                                  child: Text(c,
                                      style: const TextStyle(fontSize: 12))))
                              .toList(),
                          onChanged: (v) => setState(() => _fOriginCity = v!))),
                if (_fOriginState != 'All' && _fDestState != 'All')
                  const SizedBox(width: 8),
                if (_fDestState != 'All')
                  Expanded(
                      child: DropdownButtonFormField<String>(
                          style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 13,
                              fontWeight: FontWeight.w500),
                          isExpanded: true,
                          initialValue: validDestCity,
                          decoration: InputDecoration(
                              labelText: "To City",
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              prefixIcon: const Icon(Icons.location_city,
                                  size: 14, color: Colors.red)),
                          items: destCities
                              .map((c) => DropdownMenuItem<String>(
                                  value: c,
                                  child: Text(c,
                                      style: const TextStyle(fontSize: 12))))
                              .toList(),
                          onChanged: (v) => setState(() => _fDestCity = v!))),
              ]),
            ],
            // Row 3: Radius filter (visible only when a city is selected)
            if (validOriginCity != 'All' || validDestCity != 'All') ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.radar, size: 15, color: Color(0xFF0EA5E9)),
                const SizedBox(width: 6),
                const Text("Radius around city:",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A))),
                const SizedBox(width: 8),
                Expanded(
                    child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                      children: radiusOptions.map((r) {
                    final selected = _fRadiusKm == r;
                    final label =
                        r == 0 ? "Exact" : "${r.toStringAsFixed(0)} km";
                    return GestureDetector(
                        onTap: () => setState(() => _fRadiusKm = r),
                        child: Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFF0EA5E9)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: selected
                                        ? const Color(0xFF0EA5E9)
                                        : Colors.grey[300]!)),
                            child: Text(label,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? Colors.white
                                        : Colors.grey[600]))));
                  }).toList()),
                )),
              ]),
            ],
          ])),
      vis.isEmpty
          ? Expanded(
              child: Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                  const Icon(Icons.search_off, size: 60, color: Colors.grey),
                  const SizedBox(height: 12),
                  const Text("No loads found",
                      style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  Text(
                      hasFilters
                          ? "Try wider filters or clear them"
                          : "No active loads posted yet",
                      style: const TextStyle(color: Colors.grey))
                ])))
          : Expanded(
              child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: vis.length,
                  itemBuilder: (ctx, i) {
                    final load = vis[i];
                    return Container(
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                            color: _cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF0EA5E9))),
                        child: Column(children: [
                          // Header with gradient
                          Container(
                              padding: const EdgeInsets.all(18),
                              decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                      colors: [
                                        Color(0xFFE0F2FE),
                                        Color(0xFFFFF7ED),
                                        Color(0xFFCCFBF1)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight),
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(20))),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Wrap(
                                                    spacing: 4,
                                                    runSpacing: 4,
                                                    children: [
                                                      Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 3),
                                                          decoration: BoxDecoration(
                                                              color: Colors.green.withValues(
                                                                  alpha: 0.2),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                      8),
                                                              border: Border.all(
                                                                  color: Colors
                                                                      .green
                                                                      .withValues(
                                                                          alpha:
                                                                              0.4))),
                                                          child: Text(load.originState.isNotEmpty ? load.originState : "Origin",
                                                              style: const TextStyle(
                                                                  fontSize: 10,
                                                                  color: Color(0xFF047857),
                                                                  fontWeight: FontWeight.bold))),
                                                      const Padding(
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                                  horizontal:
                                                                      4),
                                                          child: Icon(
                                                              Icons
                                                                  .arrow_forward,
                                                              color: Color(
                                                                  0x990F172A),
                                                              size: 12)),
                                                      Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 3),
                                                          decoration: BoxDecoration(
                                                              color: Colors.red.withValues(
                                                                  alpha: 0.2),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                      8),
                                                              border: Border.all(
                                                                  color: Colors
                                                                      .red
                                                                      .withValues(
                                                                          alpha:
                                                                              0.4))),
                                                          child: Text(load.destState.isNotEmpty ? load.destState : "Dest",
                                                              style: const TextStyle(
                                                                  fontSize: 10,
                                                                  color: Color(0xFFDC2626),
                                                                  fontWeight: FontWeight.bold))),
                                                    ]),
                                                const SizedBox(height: 8),
                                                Text(load.route,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 14,
                                                        color:
                                                            Color(0xFF0F172A)),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 2),
                                                // Posted by name + trust + badges — always show
                                                Builder(builder: (_) {
                                                  final posterName = load
                                                          .postedByName
                                                          .isNotEmpty
                                                      ? load.postedByName
                                                      : load.postedByUid
                                                              .isNotEmpty
                                                          ? 'User ${load.postedByUid.substring(0, math.min(6, load.postedByUid.length))}'
                                                          : '';
                                                  final pts =
                                                      _partyTrustFromLedgers(
                                                          posterName);
                                                  final ptColor = pts >= 80
                                                      ? const Color(0xFF10B981)
                                                      : pts >= 60
                                                          ? const Color(
                                                              0xFF3B82F6)
                                                          : pts >= 40
                                                              ? const Color(
                                                                  0xFFF59E0B)
                                                              : const Color(
                                                                  0xFFEF4444);
                                                  final ptLabel = pts >= 80
                                                      ? 'Trusted'
                                                      : pts >= 60
                                                          ? 'Good'
                                                          : pts >= 40
                                                              ? 'Fair'
                                                              : 'Risky';
                                                  return Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        if (load.postedByName
                                                            .isNotEmpty) ...[
                                                          const SizedBox(
                                                              height: 6),
                                                          Row(children: [
                                                            const Icon(
                                                                Icons
                                                                    .person_outline_rounded,
                                                                size: 11,
                                                                color: Color(
                                                                    0xFF64748B)),
                                                            const SizedBox(
                                                                width: 3),
                                                            Expanded(
                                                                child: Text(
                                                                    load
                                                                        .postedByName,
                                                                    style: const TextStyle(
                                                                        color: Color(
                                                                            0xFF64748B),
                                                                        fontSize:
                                                                            11,
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .w600),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis)),
                                                            // Trust score badge
                                                            Container(
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        5,
                                                                    vertical:
                                                                        2),
                                                                decoration: BoxDecoration(
                                                                    color: ptColor
                                                                        .withValues(
                                                                            alpha:
                                                                                0.1),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            5)),
                                                                child: Row(
                                                                    mainAxisSize:
                                                                        MainAxisSize
                                                                            .min,
                                                                    children: [
                                                                      Icon(
                                                                          Icons
                                                                              .shield_rounded,
                                                                          size:
                                                                              9,
                                                                          color:
                                                                              ptColor),
                                                                      const SizedBox(
                                                                          width:
                                                                              2),
                                                                      Text(
                                                                          '$pts pts · $ptLabel',
                                                                          style: TextStyle(
                                                                              color: ptColor,
                                                                              fontSize: 8,
                                                                              fontWeight: FontWeight.w800)),
                                                                    ])),
                                                          ]),
                                                        ],
                                                        const SizedBox(
                                                            height: 5),
                                                        Wrap(
                                                            spacing: 5,
                                                            runSpacing: 4,
                                                            children: [
                                                              if (load
                                                                  .isVerifiedPoster)
                                                                Container(
                                                                    padding: const EdgeInsets
                                                                        .symmetric(
                                                                        horizontal:
                                                                            8,
                                                                        vertical:
                                                                            3),
                                                                    decoration: BoxDecoration(
                                                                        gradient:
                                                                            const LinearGradient(
                                                                                colors: [
                                                                              Color(0xFF3B82F6),
                                                                              Color(0xFF1D4ED8)
                                                                            ]),
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                                8),
                                                                        boxShadow: [
                                                                          BoxShadow(
                                                                              color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                                                                              blurRadius: 4,
                                                                              offset: const Offset(0, 2))
                                                                        ]),
                                                                    child: const Row(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        children: [
                                                                          Icon(
                                                                              Icons.verified_rounded,
                                                                              size: 11,
                                                                              color: Colors.white),
                                                                          SizedBox(
                                                                              width: 3),
                                                                          Text(
                                                                              'VERIFIED',
                                                                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.3)),
                                                                        ])),
                                                              if (load.isBulk)
                                                                Container(
                                                                    padding: const EdgeInsets
                                                                        .symmetric(
                                                                        horizontal:
                                                                            6,
                                                                        vertical:
                                                                            2),
                                                                    decoration: BoxDecoration(
                                                                        color: const Color(0xFFD97706).withValues(
                                                                            alpha:
                                                                                0.1),
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                                5),
                                                                        border: Border.all(
                                                                            color: const Color(0xFFD97706).withValues(
                                                                                alpha:
                                                                                    0.4))),
                                                                    child: const Row(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        children: [
                                                                          Icon(
                                                                              Icons.local_shipping_rounded,
                                                                              size: 10,
                                                                              color: Color(0xFFD97706)),
                                                                          SizedBox(
                                                                              width: 3),
                                                                          Text(
                                                                              'BULK',
                                                                              style: TextStyle(color: Color(0xFFD97706), fontSize: 9, fontWeight: FontWeight.w800)),
                                                                        ])),
                                                              if (load.bids
                                                                  .isNotEmpty)
                                                                Container(
                                                                    padding: const EdgeInsets
                                                                        .symmetric(
                                                                        horizontal:
                                                                            6,
                                                                        vertical:
                                                                            2),
                                                                    decoration: BoxDecoration(
                                                                        color: const Color(0xFF6366F1).withValues(
                                                                            alpha:
                                                                                0.1),
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                                5)),
                                                                    child: Text(
                                                                        '${load.bids.length} bid${load.bids.length > 1 ? "s" : ""}',
                                                                        style: const TextStyle(
                                                                            color:
                                                                                Color(0xFF6366F1),
                                                                            fontSize: 9,
                                                                            fontWeight: FontWeight.w800))),
                                                            ]),
                                                      ]);
                                                }),
                                              ])),
                                          const SizedBox(width: 12),
                                          Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                    "Rs.${(load.targetPrice / 1000).toStringAsFixed(0)}K",
                                                    style: const TextStyle(
                                                        color:
                                                            Color(0xFFF97316),
                                                        fontWeight:
                                                            FontWeight.w900,
                                                        fontSize: 26)),
                                                const Text("target freight",
                                                    style: TextStyle(
                                                        color:
                                                            Color(0x33334155),
                                                        fontSize: 9)),
                                              ]),
                                        ]),
                                  ])),
                          // Body with details
                          Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Chips row
                                    Wrap(spacing: 8, runSpacing: 6, children: [
                                      _chip(Icons.local_shipping,
                                          load.vehicleType, Colors.blue),
                                      if (load.materialType.isNotEmpty)
                                        _chip(Icons.science, load.materialType,
                                            Colors.purple),
                                      if (load.weightTons > 0)
                                        _chip(Icons.scale,
                                            "${load.weightTons}T", Colors.teal),
                                      if (load.postedDate.isNotEmpty)
                                        _chip(Icons.calendar_today,
                                            load.postedDate, Colors.grey),
                                    ]),
                                    if (load.originFactory.isNotEmpty ||
                                        load.destFactory.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      if (load.originFactory.isNotEmpty)
                                        Row(children: [
                                          Container(
                                              width: 3,
                                              height: 14,
                                              color: Colors.green,
                                              margin: const EdgeInsets.only(
                                                  right: 8)),
                                          Expanded(
                                              child: Text(
                                                  "Loading: ${load.originFactory}",
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.indigo,
                                                      fontWeight:
                                                          FontWeight.w700),
                                                  overflow:
                                                      TextOverflow.ellipsis))
                                        ]),
                                      if (load.destFactory.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Row(children: [
                                          Container(
                                              width: 3,
                                              height: 14,
                                              color: Colors.red,
                                              margin: const EdgeInsets.only(
                                                  right: 8)),
                                          Expanded(
                                              child: Text(
                                                  "Unloading: ${load.destFactory}",
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.deepOrange,
                                                      fontWeight:
                                                          FontWeight.w700),
                                                  overflow:
                                                      TextOverflow.ellipsis))
                                        ])
                                      ],
                                    ],
                                    const SizedBox(height: 14),
                                    // Bulk booking badge
                                    if (load.isBulk)
                                      Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                                colors: [
                                                  Color(0xFFD97706),
                                                  Color(0xFFB45309)
                                                ]),
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.local_shipping_rounded,
                                                  color: Colors.white,
                                                  size: 12),
                                              SizedBox(width: 4),
                                              Text('BULK BOOKING',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      letterSpacing: 0.5)),
                                            ]),
                                      ),
                                    // Bid count badge
                                    if (load.bids.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Row(children: [
                                          const Icon(Icons.gavel_rounded,
                                              size: 12,
                                              color: Color(0xFF6366F1)),
                                          const SizedBox(width: 4),
                                          Text(
                                              '${load.bids.length} bid${load.bids.length > 1 ? "s" : ""} received',
                                              style: const TextStyle(
                                                  color: Color(0xFF6366F1),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700)),
                                        ]),
                                      ),
                                    if (load.isVerifiedPoster)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 6),
                                        child: Row(children: [
                                          const Icon(Icons.verified_rounded,
                                              size: 13,
                                              color: Color(0xFF3B82F6)),
                                          const SizedBox(width: 4),
                                          const Text('Verified Consignor',
                                              style: TextStyle(
                                                  color: Color(0xFF3B82F6),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700)),
                                        ]),
                                      ),
                                    if (load.status == BidStatus.booked)
                                      Column(children: [
                                        Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                            decoration: BoxDecoration(
                                                color: Colors.green
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                    color:
                                                        Colors.green.shade700)),
                                            child: const Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.check_circle,
                                                      color: Colors.green,
                                                      size: 16),
                                                  SizedBox(width: 6),
                                                  Text("BOOKED OK",
                                                      style: TextStyle(
                                                          color: Colors.green,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          fontSize: 13))
                                                ])),
                                        const SizedBox(height: 8),
                                        // Always show Fill Details button - user can reopen form anytime
                                        SizedBox(
                                            width: double.infinity,
                                            height: 44,
                                            child: OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(
                                                        color:
                                                            Color(0xFF16A34A)),
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                12))),
                                                onPressed: () => _showNewEntry(
                                                    prefillRoute: load.route,
                                                    prefillLoadId: load.id,
                                                    prefillFreight:
                                                        load.targetPrice,
                                                    prefillMaterial:
                                                        load.materialType,
                                                    prefillOriginCity:
                                                        load.originCity,
                                                    prefillOriginState:
                                                        load.originState,
                                                    prefillDestCity:
                                                        load.destCity,
                                                    prefillDestState:
                                                        load.destState,
                                                    skipRegistrationCheck: true,
                                                    prefillFactory:
                                                        load.originFactory,
                                                    prefillDestFactory: load.destFactory,
                                                    prefillWeight: load.weightTons,
                                                    prefillVehicleType: load.vehicleType),
                                                icon: const Icon(Icons.edit_note_rounded, size: 16, color: Color(0xFF0EA5E9)),
                                                label: const Text("Fill / Edit Dispatch Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0EA5E9))))),
                                        const SizedBox(height: 8),
                                        // Google Maps route share button
                                        SizedBox(
                                            width: double.infinity,
                                            height: 44,
                                            child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        const Color(0xFF1A73E8),
                                                    foregroundColor: Colors
                                                        .white,
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12))),
                                                onPressed: () async {
                                                  String oStr = load
                                                          .originFactory
                                                          .isNotEmpty
                                                      ? load.originFactory
                                                      : load.originCity
                                                              .isNotEmpty
                                                          ? '${load.originCity}, ${load.originState}, India'
                                                          : load.route
                                                              .split('->')
                                                              .first
                                                              .trim();
                                                  String dStr = load.destFactory
                                                          .isNotEmpty
                                                      ? load.destFactory
                                                      : load.destCity.isNotEmpty
                                                          ? '${load.destCity}, ${load.destState}, India'
                                                          : load.route
                                                              .split('->')
                                                              .last
                                                              .trim();
                                                  final mapUrl2 = Uri.parse(
                                                      'https://maps.google.com/?saddr=${Uri.encodeComponent(oStr)}&daddr=${Uri.encodeComponent(dStr)}&dirflg=d');
                                                  await launchUrl(mapUrl2,
                                                      mode: LaunchMode
                                                          .externalApplication);
                                                },
                                                icon: const Icon(
                                                    Icons.map_rounded,
                                                    size: 16),
                                                label: const Text(
                                                    'Open Route in Google Maps',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13)))),
                                        const SizedBox(height: 8),
                                        // Share route
                                        SizedBox(
                                            width: double.infinity,
                                            height: 40,
                                            child: OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(
                                                        color:
                                                            Color(0xFF1A73E8)),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12))),
                                                onPressed: () {
                                                  final origin = load
                                                          .originFactory
                                                          .isNotEmpty
                                                      ? load.originFactory
                                                      : '${load.originCity}, ${load.originState}';
                                                  final dest = load.destFactory
                                                          .isNotEmpty
                                                      ? load.destFactory
                                                      : '${load.destCity}, ${load.destState}';
                                                  final mapsUrl =
                                                      'https://www.google.com/maps/dir/${Uri.encodeComponent(origin)}/${Uri.encodeComponent(dest)}';
                                                  SharePlus.instance
                                                      .share(ShareParams(
                                                    text:
                                                        '🚛 NavGati ERP — Trip Route\n$origin → $dest\n$mapsUrl',
                                                    subject:
                                                        'Trip Route: ${load.originCity} → ${load.destCity}',
                                                  ));
                                                },
                                                icon: const Icon(
                                                    Icons.share_rounded,
                                                    size: 15,
                                                    color: Color(0xFF1A73E8)),
                                                label: const Text(
                                                    'Share Route Link',
                                                    style: TextStyle(
                                                        color:
                                                            Color(0xFF1A73E8),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 12)))),
                                        const SizedBox(height: 8),
                                        // Consignor verification status
                                        Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                                color: Colors.amber
                                                    .withValues(alpha: 0.08),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                    color: Colors.amber
                                                        .withValues(
                                                            alpha: 0.3))),
                                            child: const Row(children: [
                                              Icon(
                                                  Icons.pending_actions_rounded,
                                                  color: Colors.amber,
                                                  size: 14),
                                              SizedBox(width: 6),
                                              Flexible(
                                                  child: Text(
                                                      "Waiting for consignor to verify fleet & documents",
                                                      style: TextStyle(
                                                          color: Colors.amber,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600)))
                                            ])),
                                        const SizedBox(height: 8),
                                        SizedBox(
                                            width: double.infinity,
                                            height: 44,
                                            child: ElevatedButton.icon(
                                                style: ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        Colors.green,
                                                    foregroundColor:
                                                        const Color(0xFFF6FAFF),
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                12))),
                                                onPressed: (userProfile.role ==
                                                            UserRole.driver ||
                                                        (load.postedByUid.isNotEmpty &&
                                                            load.postedByUid !=
                                                                (FirebaseService
                                                                        .currentUser
                                                                        ?.uid ??
                                                                    '')))
                                                    ? null
                                                    : () {
                                                        setState(() {
                                                          // Track dispatched ID — persisted so load stays gone after restart
                                                          _dispatchedLoadIds
                                                              .add(load.id);
                                                          SharedPreferences
                                                                  .getInstance()
                                                              .then((p) {
                                                            p.setStringList(
                                                                'rm_dispatched_ids',
                                                                _dispatchedLoadIds
                                                                    .toList());
                                                          });
                                                          marketLoads
                                                              .removeWhere(
                                                                  (l) =>
                                                                      l.id ==
                                                                      load.id);
                                                          // Mark ledger as in transit
                                                          final marker =
                                                              "BOOKED_LOAD:${load.id}";
                                                          for (final l in ledgers
                                                              .where((l) => l
                                                                  .lrNotes
                                                                  .contains(
                                                                      marker))) {
                                                            l.isInTransit =
                                                                true;
                                                            l.dispatchedAt =
                                                                DateTime.now()
                                                                    .toIso8601String();
                                                            final hrs =
                                                                (l.distanceKm >
                                                                            0
                                                                        ? l.distanceKm
                                                                        : 600) /
                                                                    52.0;
                                                            l.estimatedArrival = DateTime
                                                                    .now()
                                                                .add(Duration(
                                                                    hours: hrs
                                                                        .ceil()))
                                                                .toIso8601String();
                                                          }
                                                        });
                                                        _save();
                                                        // Write to Firestore so other devices see the update
                                                        FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                                'marketLoads')
                                                            .doc(load.id)
                                                            .update({
                                                          'status': BidStatus
                                                              .inTransit.index,
                                                          'dispatchedAt': FieldValue
                                                              .serverTimestamp(),
                                                          'dispatchedByUid':
                                                              FirebaseService
                                                                      .currentUser
                                                                      ?.uid ??
                                                                  '',
                                                        }).catchError((e) {
                                                          debugPrint(
                                                              'Dispatch Firestore error: $e');
                                                          // If write fails, set local status so listener filter still excludes it
                                                          final idx = marketLoads
                                                              .indexWhere((l) =>
                                                                  l.id ==
                                                                  load.id);
                                                          if (idx >= 0) {
                                                            setState(() =>
                                                                marketLoads
                                                                    .removeAt(
                                                                        idx));
                                                          }
                                                        });
                                                        // Close dialog safely
                                                        if (Navigator.canPop(
                                                            context)) {
                                                          Navigator.pop(
                                                              context);
                                                        }
                                                        ScaffoldMessenger.of(
                                                                context)
                                                            .showSnackBar(const SnackBar(
                                                                backgroundColor:
                                                                    Colors
                                                                        .green,
                                                                behavior:
                                                                    SnackBarBehavior
                                                                        .floating,
                                                                content: Text(
                                                                    "✅ Dispatched! Load removed from board.")));
                                                      },
                                                icon: const Icon(Icons.local_shipping,
                                                    size: 16),
                                                label: const Text(
                                                    "Mark as Dispatched",
                                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))),
                                      ])
                                    else
                                      Row(children: [
                                        Expanded(
                                            child: SizedBox(
                                                height: 46,
                                                child: ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            const Color(
                                                                0xFFF97316),
                                                        foregroundColor:
                                                            Colors.white,
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                    12)),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                                vertical: 12)),
                                                    onPressed: (userProfile
                                                                    .role ==
                                                                UserRole.driver ||
                                                            _isConsignor)
                                                        ? null
                                                        : () => _bookLoad(load),
                                                    icon: const Icon(Icons.check_circle, size: 16),
                                                    label: const Text("Book & Dispatch", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))))),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: SizedBox(
                                                height: 46,
                                                child: ElevatedButton.icon(
                                                    style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            const Color(
                                                                0xFF6366F1),
                                                        foregroundColor:
                                                            Colors.white,
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                    12)),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                                vertical: 12)),
                                                    onPressed: (userProfile
                                                                    .role ==
                                                                UserRole.driver ||
                                                            _isConsignor)
                                                        ? null
                                                        : () => _placeBid(load),
                                                    icon: const Icon(Icons.gavel_rounded, size: 16),
                                                    label: const Text("Place Bid", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))))),
                                      ]),
                                    // Maps directions — always visible on all load cards
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      Expanded(
                                          child: SizedBox(
                                              height: 38,
                                              child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          const Color(
                                                              0xFF1A73E8),
                                                      foregroundColor:
                                                          Colors.white,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10))),
                                                  onPressed: () async {
                                                    String originStr = load
                                                            .originFactory
                                                            .isNotEmpty
                                                        ? load.originFactory
                                                        : load.originCity
                                                                .isNotEmpty
                                                            ? '${load.originCity}, ${load.originState}, India'
                                                            : load.route
                                                                .split('->')
                                                                .first
                                                                .trim();
                                                    String destStr = load
                                                            .destFactory
                                                            .isNotEmpty
                                                        ? load.destFactory
                                                        : load.destCity
                                                                .isNotEmpty
                                                            ? '${load.destCity}, ${load.destState}, India'
                                                            : load.route
                                                                .split('->')
                                                                .last
                                                                .trim();
                                                    // Try native Maps app first, fall back to browser
                                                    // saddr/daddr shows route between two fixed points (not from current location)
                                                    final mapUrl = Uri.parse(
                                                        'https://maps.google.com/?saddr=${Uri.encodeComponent(originStr)}&daddr=${Uri.encodeComponent(destStr)}&dirflg=d');
                                                    await launchUrl(mapUrl,
                                                        mode: LaunchMode
                                                            .externalApplication);
                                                  },
                                                  icon: const Icon(
                                                      Icons.map_rounded,
                                                      size: 14),
                                                  label: const Text(
                                                      'View Route',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight
                                                              .w800))))),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: SizedBox(
                                              height: 38,
                                              child: OutlinedButton.icon(
                                                  style: OutlinedButton.styleFrom(
                                                      side: const BorderSide(
                                                          color: Color(
                                                              0xFF1A73E8)),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          10))),
                                                  onPressed: () async {
                                                    final origin = load
                                                            .originFactory
                                                            .isNotEmpty
                                                        ? load.originFactory
                                                        : load.originCity
                                                                .isNotEmpty
                                                            ? '${load.originCity}, ${load.originState}'
                                                            : load.route
                                                                .split('->')
                                                                .first
                                                                .trim();
                                                    final dest = load
                                                            .destFactory
                                                            .isNotEmpty
                                                        ? load.destFactory
                                                        : load.destCity
                                                                .isNotEmpty
                                                            ? '${load.destCity}, ${load.destState}'
                                                            : load.route
                                                                .split('->')
                                                                .last
                                                                .trim();
                                                    final mapsUrl =
                                                        'https://www.google.com/maps/dir/${Uri.encodeComponent(origin)}/${Uri.encodeComponent(dest)}';
                                                    final msg = Uri.encodeComponent(
                                                        '🚛 Route: $origin → $dest\n$mapsUrl');
                                                    final waUrl = Uri.parse(
                                                        'whatsapp://send?text=$msg');
                                                    if (await canLaunchUrl(
                                                        waUrl)) {
                                                      await launchUrl(waUrl);
                                                    } else {
                                                      // WhatsApp not installed, share normally
                                                      SharePlus.instance.share(
                                                          ShareParams(
                                                              text:
                                                                  '🚛 Route: $origin → $dest\n$mapsUrl',
                                                              subject:
                                                                  'Trip Route'));
                                                    }
                                                  },
                                                  icon: const Icon(
                                                      Icons.share_rounded,
                                                      size: 14,
                                                      color: Color(0xFF1A73E8)),
                                                  label: const Text(
                                                      'Share via WhatsApp',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color:
                                                              Color(0xFF1A73E8)))))),
                                    ]),
                                    // Only show review option AFTER load has been dispatched
                                    if (load.status == BidStatus.booked ||
                                        load.status == BidStatus.inTransit ||
                                        load.status == BidStatus.delivered) ...[
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 38,
                                        child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                                side: const BorderSide(
                                                    color: Color(0xFF0EA5E9)),
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10))),
                                            onPressed: () =>
                                                _submitComplaintForConsignor(
                                                    load),
                                            icon: const Icon(
                                                Icons.rate_review_rounded,
                                                size: 14,
                                                color: Color(0xFF0EA5E9)),
                                            label: const Text(
                                                'Review Consignor',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w800,
                                                    color: Color(0xFF0EA5E9)))),
                                      ),
                                    ],
                                    // Driver rating for consignors
                                    if (_isConsignor &&
                                        (load.status == BidStatus.inTransit ||
                                            load.status ==
                                                BidStatus.delivered)) ...[
                                      const SizedBox(height: 6),
                                      SizedBox(
                                          width: double.infinity,
                                          height: 38,
                                          child: OutlinedButton.icon(
                                              style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(
                                                      color: Color(0xFF10B981)),
                                                  shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10))),
                                              onPressed: () =>
                                                  _submitDriverRatingFromLoad(
                                                      load),
                                              icon: const Icon(Icons.person_pin_circle_rounded,
                                                  size: 14,
                                                  color: Color(0xFF10B981)),
                                              label: const Text('Rate Driver',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      color:
                                                          Color(0xFF10B981))))),
                                    ],
                                  ])),
                        ]));
                  })),
    ]);
  }

  void _placeBid(MarketLoad load) {
    final amtCtrl =
        TextEditingController(text: load.targetPrice.toStringAsFixed(0));
    final noteCtrl = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.gavel_rounded,
                          color: Color(0xFF6366F1), size: 20),
                      const SizedBox(width: 8),
                      const Text('Place Bid',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 18)),
                    ]),
                    const SizedBox(height: 4),
                    Text('${load.originCity} → ${load.destCity}',
                        style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.normal)),
                  ]),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  const Icon(Icons.flag_rounded,
                      color: Colors.orange, size: 14),
                  const SizedBox(width: 6),
                  Text('Target Rate: ₹${load.targetPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ]),
                const SizedBox(height: 12),
                TextField(
                  controller: amtCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Your Bid Amount (₹)',
                    prefixIcon: const Icon(Icons.currency_rupee, size: 16),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFF6366F1), width: 2)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: 'Note to Consignor (optional)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: const Color(0xFFF0F4FF),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Text(
                      'Your bid will be visible to the consignor. They can accept or counter-bid. Once accepted, the load will be assigned to you.',
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey)),
                ),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    onPressed: () async {
                      final amt =
                          double.tryParse(amtCtrl.text) ?? load.targetPrice;
                      final bid = {
                        'uid': FirebaseService.currentUser?.uid ?? '',
                        'name': userProfile.companyName,
                        'phone': userProfile.phone,
                        'amount': amt,
                        'note': noteCtrl.text.trim(),
                        'time': DateTime.now().toIso8601String(),
                      };
                      // Save bid to Firestore
                      final updatedBids = [...load.bids, bid];
                      await FirebaseFirestore.instance
                          .collection('marketLoads')
                          .doc(load.id)
                          .update({'bids': updatedBids});
                      setState(() => load.bids.add(bid));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content:
                              Text('✅ Bid placed! Consignor will be notified.'),
                          backgroundColor: Color(0xFF6366F1),
                          behavior: SnackBarBehavior.floating));
                    },
                    icon: const Icon(Icons.gavel_rounded, size: 16),
                    label: const Text('Submit Bid',
                        style: TextStyle(fontWeight: FontWeight.w900))),
              ],
            ));
  }

  void _submitComplaintForConsignor(MarketLoad load) {
    final reasonCtrl = TextEditingController();
    int pts = -10;
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
              builder: (ctx, ss) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                title: Text('Review ${_postedConsignorName(load)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
                content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                          'Admin approval is required before points or blacklist status change.',
                          style: TextStyle(
                              color: Color(0xFF64748B), fontSize: 12)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: reasonCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                              labelText: 'Positive or negative review',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 10),
                      Row(children: [
                        const Text('Points',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        IconButton(
                            onPressed: () => ss(
                                () => pts = (pts - 5).clamp(-50, 50).toInt()),
                            icon: const Icon(Icons.remove_circle_outline,
                                color: Colors.red)),
                        Text('${pts > 0 ? "+" : ""}$pts',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: pts >= 0 ? Colors.green : Colors.red)),
                        IconButton(
                            onPressed: () => ss(
                                () => pts = (pts + 5).clamp(-50, 50).toInt()),
                            icon: const Icon(Icons.add_circle_outline,
                                color: Colors.green)),
                      ]),
                    ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          foregroundColor: Colors.white),
                      onPressed: () {
                        if (reasonCtrl.text.trim().isEmpty) return;
                        FirebaseService.submitComplaint(
                          reporterUid: FirebaseService.currentUser?.uid ?? '',
                          reporterName: userProfile.companyName.isNotEmpty
                              ? userProfile.companyName
                              : userProfile.phone,
                          targetName: _postedConsignorName(load),
                          targetType: 'consignor',
                          targetId: load.postedByUid,
                          reason: reasonCtrl.text.trim(),
                          suggestedPoints: pts,
                          tripId: load.id,
                        ).then((_) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Review sent to admin. Points apply only after approval.'),
                              backgroundColor: Color(0xFF0EA5E9),
                              behavior: SnackBarBehavior.floating));
                        });
                      },
                      child: const Text('Submit to Admin')),
                ],
              ),
            ));
  }

  void _submitDriverRatingFromLoad(MarketLoad load) {
    // Consignors can rate the driver assigned to their load
    final reasonCtrl = TextEditingController();
    int pts = -10;
    bool isMerit = false;
    final cats = [
      'Late delivery',
      'Vehicle damage',
      'Rash driving',
      'Dishonesty',
      'Absence without notice',
      'Good service ✓',
      'On-time delivery ✓',
      'Professional behaviour ✓'
    ];
    final driverName = load.route.isNotEmpty
        ? 'Driver for ${load.route.split("->").first.trim()}'
        : 'Assigned Driver';
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
              builder: (ctx, ss) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                title: Text(
                    'Rate Driver — ${load.originCity} → ${load.destCity}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 15)),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Points apply after admin approval.',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: GestureDetector(
                            onTap: () => ss(() {
                                  isMerit = false;
                                  pts = -10;
                                }),
                            child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                    color: !isMerit
                                        ? Colors.red.withValues(alpha: 0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: !isMerit
                                            ? Colors.red
                                            : Colors.grey.shade300)),
                                child: const Column(children: [
                                  Icon(Icons.thumb_down_rounded,
                                      color: Colors.red),
                                  SizedBox(height: 4),
                                  Text('Demerit',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: Colors.red))
                                ])))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: GestureDetector(
                            onTap: () => ss(() {
                                  isMerit = true;
                                  pts = 10;
                                }),
                            child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                    color: isMerit
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: isMerit
                                            ? Colors.green
                                            : Colors.grey.shade300)),
                                child: const Column(children: [
                                  Icon(Icons.thumb_up_rounded,
                                      color: Colors.green),
                                  SizedBox(height: 4),
                                  Text('Merit',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: Colors.green))
                                ])))),
                  ]),
                  const SizedBox(height: 10),
                  Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: cats
                          .map((cat) => GestureDetector(
                              onTap: () {
                                reasonCtrl.text = cat;
                                ss(() {});
                              },
                              child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                      color: reasonCtrl.text == cat
                                          ? const Color(0xFF0EA5E9)
                                              .withValues(alpha: 0.12)
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: reasonCtrl.text == cat
                                              ? const Color(0xFF0EA5E9)
                                              : Colors.transparent)),
                                  child: Text(cat,
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: reasonCtrl.text == cat
                                              ? const Color(0xFF0EA5E9)
                                              : const Color(0xFF334155))))))
                          .toList()),
                  const SizedBox(height: 10),
                  TextField(
                      controller: reasonCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                          labelText: 'Reason / description',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 10),
                  Row(children: [
                    const Text('Points: ',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    const SizedBox(width: 8),
                    GestureDetector(
                        onTap: () =>
                            ss(() => pts = (pts - 5).clamp(-50, 50).toInt()),
                        child: const Icon(Icons.remove_circle_outline,
                            color: Colors.red)),
                    const SizedBox(width: 8),
                    Text('${pts > 0 ? "+" : ""}$pts',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: pts >= 0 ? Colors.green : Colors.red)),
                    const SizedBox(width: 8),
                    GestureDetector(
                        onTap: () =>
                            ss(() => pts = (pts + 5).clamp(-50, 50).toInt()),
                        child: const Icon(Icons.add_circle_outline,
                            color: Colors.green)),
                  ]),
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      onPressed: () {
                        if (reasonCtrl.text.trim().isEmpty) return;
                        FirebaseService.submitComplaint(
                          reporterUid: FirebaseService.currentUser?.uid ?? '',
                          reporterName: userProfile.companyName.isNotEmpty
                              ? userProfile.companyName
                              : userProfile.phone,
                          targetName: driverName,
                          targetType: 'driver',
                          targetId: load.postedByUid,
                          reason: reasonCtrl.text.trim(),
                          suggestedPoints: pts,
                          tripId: load.id,
                        ).then((_) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  '✅ Rating submitted — admin will review and apply points'),
                              backgroundColor: Color(0xFF0EA5E9),
                              behavior: SnackBarBehavior.floating));
                        });
                      },
                      child: const Text('Submit to Admin',
                          style: TextStyle(fontWeight: FontWeight.w800))),
                ],
              ),
            ));
  }

  Future<void> _bookLoad(MarketLoad load) async {
    // ── Step 1: Registration gate — must complete profile before booking ──
    final prefs = await SharedPreferences.getInstance();
    final regDone = prefs.getBool('rm_registration_done') ?? false;
    if (!regDone) {
      if (!mounted) return;
      final wantToRegister = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
                backgroundColor: const Color(0xFFF6FAFF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                title: const Row(children: [
                  Icon(Icons.assignment_ind_rounded, color: Color(0xFF0EA5E9)),
                  SizedBox(width: 10),
                  Flexible(
                      child: Text('Registration Required',
                          style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w900,
                              fontSize: 16))),
                ]),
                content: const Text(
                    'Complete your company profile before booking a load.\n\n'
                    'This takes 2 minutes and is required only once.\n\n'
                    '• Company name & GST\n'
                    '• Bank details for payments\n'
                    '• Contact number',
                    style: TextStyle(fontSize: 13, height: 1.6)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Later',
                          style: TextStyle(color: Color(0xFF64748B)))),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Complete Now',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold))),
                ],
              ));
      if (wantToRegister != true || !mounted) return;
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => const RegistrationScreen()));
      if (!mounted) return;
      final prefs2 = await SharedPreferences.getInstance();
      if (!(prefs2.getBool('rm_registration_done') ?? false)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            content:
                Text('Please complete registration before booking a load.')));
        return;
      }
    }

    // ── Step 2: Vehicle type check ──────────────────────────────────────
    final hasVehicle = fleet.any((v) => v.type.toLowerCase().contains(
        load.vehicleType.toLowerCase().split(' ').first.toLowerCase()));
    if (!hasVehicle && fleet.isNotEmpty) {
      if (!mounted) return;
      showDialog(
          context: context,
          builder: (c) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
                title: const Row(children: [
                  Icon(Icons.warning_amber, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Vehicle Not Available',
                      style: TextStyle(fontWeight: FontWeight.bold))
                ]),
                content: Text('This load requires a ${load.vehicleType}.\n\n'
                    'You don\'t have this vehicle type in your fleet. '
                    'You can still proceed if you plan to hire a market truck.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('Go Back')),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange),
                      onPressed: () {
                        Navigator.pop(c);
                        _confirmBooking(load);
                      },
                      child: const Text('Proceed Anyway',
                          style: TextStyle(color: Color(0xFF0F172A)))),
                ],
              ));
      return;
    }
    _confirmBooking(load);
  }

  String _postedConsignorName(MarketLoad load) {
    final name = load.postedByName.trim();
    if (name.isNotEmpty) {
      return name
          .replaceFirst(RegExp(r'^Consignor:\s*', caseSensitive: false), '')
          .trim();
    }
    if (load.postedByUid.isNotEmpty) {
      return 'Consignor ${load.postedByUid.substring(0, math.min(6, load.postedByUid.length))}';
    }
    return 'Booked Load';
  }

  String _bookedFleetOwnerName(MarketLoad load) {
    final name = load.bookedByName.trim();
    if (name.isNotEmpty) return name;
    if (load.bookedByUid.isNotEmpty) {
      return 'Fleet owner ${load.bookedByUid.substring(0, math.min(6, load.bookedByUid.length))}';
    }
    return 'Booked Load';
  }

  TripLedger _ledgerFromBookedLoad(MarketLoad load,
      {required bool forPoster}) {
    final matchingFleet = fleet.where((v) {
      final need = load.vehicleType.toLowerCase().split(' ').first;
      return v.type.toLowerCase().contains(need);
    }).toList();
    final vehicleNo = forPoster
        ? load.bookedVehicleNo.isNotEmpty
            ? load.bookedVehicleNo
            : "Booked ${load.vehicleType}"
        : matchingFleet.isNotEmpty
            ? matchingFleet.first.number
            : "Booked ${load.vehicleType}";
    final now = DateTime.now();
    return TripLedger(
        id: "BL${forPoster ? 'P' : 'B'}_${Uri.encodeComponent(load.id)}",
        date: "${now.day}/${now.month}/${now.year}",
        partyName:
            forPoster ? _bookedFleetOwnerName(load) : _postedConsignorName(load),
        vehicleNo: vehicleNo,
        route: load.route,
        ownership: forPoster || matchingFleet.isNotEmpty
            ? VehicleOwnership.self
            : VehicleOwnership.market,
        materialName:
            load.materialType.isNotEmpty ? load.materialType : "General",
        loadingPoint: load.originFactory.isNotEmpty
            ? load.originFactory
            : load.originCity,
        unloadingPoint:
            load.destFactory.isNotEmpty ? load.destFactory : load.destCity,
        loadingState: load.originState,
        unloadingState: load.destState,
        freightBilled: load.targetPrice,
        paymentReceived: 0,
        marketTruckFreight:
            !forPoster && matchingFleet.isEmpty ? load.targetPrice * 0.88 : 0,
        distanceKm: 0,
        paymentTermsDays: 30,
        lrNotes: forPoster
            ? "BOOKED_LOAD:${load.id} Posted load booked by ${_bookedFleetOwnerName(load)}."
            : "BOOKED_LOAD:${load.id} Auto-created from Load Board booking. Fill dispatch details to finalize.",
        weightTons: load.weightTons,
        weightUnit: "MT",
        platformCommission: forPoster ? 0 : load.targetPrice * 0.02,
        consignorCommission: load.targetPrice * 0.02);
  }

  Future<void> _syncBookedLoadToKhata(MarketLoad load,
      {bool forPoster = false}) async {
    final marker = "BOOKED_LOAD:${load.id}";
    final existing = ledgers.where((l) => l.lrNotes.contains(marker)).toList();
    if (existing.any((l) => l.freightBilled > 0)) return;
    if (existing.isNotEmpty) {
      setState(() => ledgers.removeWhere((l) => l.lrNotes.contains(marker)));
    }
    final newLedger = _ledgerFromBookedLoad(load, forPoster: forPoster);
    setState(() {
      ledgers.insert(0, newLedger);
      subscription.tripsUsedThisMonth++;
    });
    await _save();
  }

  void _confirmBooking(MarketLoad load) {
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: const Text("Confirm Booking",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              content: StatefulBuilder(builder: (ctx2, setState2) {
                return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Posted by with verified badge
                      if (load.postedByName.isNotEmpty)
                        Row(children: [
                          const Icon(Icons.business_rounded,
                              size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 5),
                          Flexible(
                              child: Text(load.postedByName,
                                  style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis)),
                          if (load.isVerifiedPoster) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded,
                                size: 13, color: Color(0xFF3B82F6)),
                            const Text(' Verified',
                                style: TextStyle(
                                    color: Color(0xFF3B82F6),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ]),
                      const SizedBox(height: 6),
                      Text("Route: ${load.route}",
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text("Freight: Rs.${load.targetPrice.toStringAsFixed(0)}",
                          style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                      const SizedBox(height: 10),
                      // Platform commission disclosure
                      Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.amber.shade200)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(children: [
                                  Icon(Icons.info_outline,
                                      size: 14, color: Colors.amber),
                                  SizedBox(width: 6),
                                  Text("Platform Commission",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                          color: Colors.amber))
                                ]),
                                const SizedBox(height: 6),
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("Your commission (2%)",
                                          style: TextStyle(fontSize: 11)),
                                      Text(
                                          "Rs.${(load.targetPrice * 0.02).toStringAsFixed(0)}",
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.red))
                                    ]),
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("Consignor commission (2%)",
                                          style: TextStyle(fontSize: 11)),
                                      Text(
                                          "Rs.${(load.targetPrice * 0.02).toStringAsFixed(0)}",
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.red))
                                    ]),
                                const Divider(height: 10),
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("You receive (net)",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 11)),
                                      Text(
                                          "Rs.${(load.targetPrice * 0.98).toStringAsFixed(0)}",
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                              color: Colors.green))
                                    ]),
                              ])),
                      const SizedBox(height: 8),
                      Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8)),
                          child: const Text(
                              "Load stays on board until consignor verifies. Tap 'Mark Dispatched' after physical dispatch.",
                              style: TextStyle(
                                  fontSize: 11, color: Colors.blueGrey))),
                    ]);
              }),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text("Cancel")),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF6FAFF),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    onPressed: () async {
                      Navigator.pop(c);
                      final bookerUid = FirebaseService.currentUser?.uid ?? '';
                      final bookerName = userProfile.companyName.isNotEmpty
                          ? userProfile.companyName
                          : userProfile.phone;
                      final matchingFleet = fleet.where((v) {
                        final need =
                            load.vehicleType.toLowerCase().split(' ').first;
                        return v.type.toLowerCase().contains(need);
                      });
                      setState(() {
                        load.status = BidStatus.booked;
                        load.bookedByUid = bookerUid;
                        load.bookedByName = bookerName;
                        load.bookedVehicleNo = matchingFleet.isNotEmpty
                            ? matchingFleet.first.number
                            : '';
                      });
                      if (FirebaseService.isReady) {
                        try {
                          await FirebaseFirestore.instance
                              .collection('marketLoads')
                              .doc(load.id)
                              .update({
                            'status': BidStatus.booked.index,
                            'bookedByUid': bookerUid,
                            'bookedByName': bookerName,
                            'bookedVehicleNo': load.bookedVehicleNo,
                          });
                        } catch (e) {
                          debugPrint('Could not publish booking ${load.id}: $e');
                          setState(() {
                            load.status = BidStatus.pending;
                            load.bookedByUid = '';
                            load.bookedByName = '';
                            load.bookedVehicleNo = '';
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  content: Text(
                                      'Booking could not be shared. Check your connection and try again.')));
                          return;
                        }
                      }
                      await _syncBookedLoadToKhata(load);
                      if (load.postedByUid.isNotEmpty &&
                          load.postedByUid != bookerUid) {
                        try {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(load.postedByUid)
                              .collection('notifications')
                              .add({
                            'type': 'load_booked',
                            'loadId': load.id,
                            'route': load.route,
                            'freight': load.targetPrice,
                            'bookedByUid': bookerUid,
                            'bookedByName': bookerName,
                            'message':
                                'Your load ${load.route} has been booked by $bookerName.',
                            'timestamp': FieldValue.serverTimestamp(),
                            'isRead': false,
                          });
                        } catch (e) {
                          debugPrint('Notify consignor error: $e');
                        }
                      }
                      // Switch to Khata so user sees the entry immediately
                      setState(() {
                        _idx = 3;
                        _khataFilter = 'All';
                        _khataFilterVal = null;
                      });
                      final bookingMessage = !FirebaseService.isReady
                          ? 'Load saved locally. Connect to sync it with the consignor.'
                          : load.postedByUid.isNotEmpty &&
                                  load.postedByUid != bookerUid
                              ? 'Load booked! Both parties will see it in Khata.'
                              : 'Load booked! Entry added to your Khata.';
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor:
                              FirebaseService.isReady
                                  ? Colors.green
                                  : Colors.orange,
                          behavior: SnackBarBehavior.floating,
                          content: Text(bookingMessage)));
                      Future.delayed(const Duration(milliseconds: 400), () {
                        if (!mounted) return;
                        _showNewEntry(
                          prefillLoadId: load.id,
                          prefillFreight: load.targetPrice,
                          prefillMaterial: load.materialType.isNotEmpty
                              ? load.materialType
                              : 'General',
                          prefillOriginCity: load.originCity,
                          prefillOriginState: load.originState,
                          prefillDestCity: load.destCity,
                          prefillDestState: load.destState,
                          prefillFactory: load.originFactory,
                          prefillDestFactory: load.destFactory,
                          prefillWeight: load.weightTons,
                          prefillVehicleType: load.vehicleType,
                          prefillRoute: load.route,
                          prefillPartyName: _postedConsignorName(load),
                          skipRegistrationCheck: true,
                        );
                      });
                    },
                    child: const Text("Book & Fill Details",
                        style: TextStyle(color: Color(0xFF0F172A)))),
              ],
            ));
  }

  //
  Widget _buildPostLoad() {
    return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("Post a Requirement",
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          const Text("Broadcast to verified fleet operators",
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 20),
          Container(
              decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20)
                  ]),
              padding: const EdgeInsets.all(24),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Loading Point",
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    CitySearchField(
                        controller: _pOriginCtrl,
                        label: "Origin City",
                        icon: Icons.trip_origin,
                        iconColor: Colors.green,
                        onCitySelected: (city, state, pid) => setState(() {
                              _pOriginCity = city;
                              _pOriginState = state;
                            })),
                    if (_pOriginState.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 6, left: 4),
                          child: Row(children: [
                            Icon(Icons.location_on,
                                size: 12, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text(_pOriginState,
                                style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700))
                          ])),
                    const SizedBox(height: 10),
                    FactorySearchField(
                      controller: _pFactoryOriginCtrl,
                      label: "Loading Factory / Plant Name",
                      iconColor: Colors.green,
                      onSelected: (name, pid) => setState(() {
                        if (name.isNotEmpty) _pFactoryOriginCtrl.text = name;
                      }),
                    ),
                    const SizedBox(height: 16),
                    const Text("Unloading Point",
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Color(0xFF0F172A))),
                    const SizedBox(height: 8),
                    CitySearchField(
                        controller: _pDestCtrl,
                        label: "Destination City",
                        icon: Icons.location_on,
                        iconColor: Colors.red,
                        onCitySelected: (city, state, pid) => setState(() {
                              _pDestCity = city;
                              _pDestState = state;
                            })),
                    if (_pDestState.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 6, left: 4),
                          child: Row(children: [
                            Icon(Icons.location_on,
                                size: 12, color: Colors.red[700]),
                            const SizedBox(width: 4),
                            Text(_pDestState,
                                style: TextStyle(
                                    color: Colors.red[700],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700))
                          ])),
                    const SizedBox(height: 10),
                    FactorySearchField(
                      controller: _pFactoryDestCtrl,
                      label: "Unloading Factory / Depot Name",
                      iconColor: Colors.red,
                      onSelected: (name, pid) => setState(() {
                        if (name.isNotEmpty) _pFactoryDestCtrl.text = name;
                      }),
                    ),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                              controller: _pWeightCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                  labelText: "Weight (Tons)",
                                  filled: true,
                                  fillColor: Colors.white,
                                  labelStyle: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                  floatingLabelStyle: const TextStyle(
                                      color: Color(0xFF0EA5E9),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9),
                                          width: 2))))),
                      const SizedBox(width: 12),
                      Expanded(
                          child: DropdownButtonFormField<String>(
                              style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                              isExpanded: true,
                              initialValue: _pVehicleType,
                              decoration: InputDecoration(
                                  labelText: "Vehicle Type",
                                  filled: true,
                                  fillColor: const Color(0xFFF6FAFF),
                                  labelStyle: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                  floatingLabelStyle: const TextStyle(
                                      color: Color(0xFF0EA5E9),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9), width: 2))),
                              items: [
                                "SS Tanker",
                                "MS Tanker",
                                "Container",
                                "Open Truck",
                                "Trailer",
                                "LCV",
                                "Reefer"
                              ]
                                  .map((v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(v,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Color(0xFF0F172A)))))
                                  .toList(),
                              onChanged: (v) => setState(() => _pVehicleType = v!))),
                    ]),
                    const SizedBox(height: 16),
                    TextField(
                        style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                        controller: _pMaterialCtrl,
                        decoration: InputDecoration(
                            labelText:
                                "Material (e.g. Ethanol, Acid, Chemicals)",
                            prefixIcon: const Icon(Icons.science,
                                color: Colors.purple, size: 20),
                            filled: true,
                            fillColor: const Color(0xFFF6FAFF),
                            labelStyle: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                            floatingLabelStyle: const TextStyle(
                                color: Color(0xFF0EA5E9),
                                fontWeight: FontWeight.w800,
                                fontSize: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFF0EA5E9))),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFF0EA5E9))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF0EA5E9), width: 2)))),
                    const SizedBox(height: 16),
                    TextField(
                        style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                        controller: _pPriceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: "Target Freight (Rs.)",
                            prefixIcon: const Icon(Icons.currency_rupee,
                                color: Colors.green, size: 20),
                            filled: true,
                            fillColor: const Color(0xFFF6FAFF),
                            labelStyle: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                            floatingLabelStyle: const TextStyle(
                                color: Color(0xFF0EA5E9),
                                fontWeight: FontWeight.w800,
                                fontSize: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFF0EA5E9))),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    const BorderSide(color: Color(0xFF0EA5E9))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF0EA5E9), width: 2)))),
                    const SizedBox(height: 28),
                    SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[800],
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16))),
                          onPressed: () {
                            if (_pOriginCtrl.text.isEmpty ||
                                _pDestCtrl.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text("Enter origin and destination"),
                                      backgroundColor: Colors.red));
                              return;
                            }
                            // Check if this user/company is blacklisted in partyTrust
                            final myPhone = userProfile.phone;
                            final myCompany = userProfile.companyName;
                            final isBlocked = partyTrustList.any((pt) =>
                                (pt['phone'] == myPhone ||
                                    pt['partyName'] == myCompany) &&
                                (pt['isBlacklisted'] == true));
                            if (isBlocked) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                backgroundColor: const Color(0xFFEF4444),
                                behavior: SnackBarBehavior.floating,
                                duration: const Duration(seconds: 5),
                                content: Row(children: [
                                  const Icon(Icons.block_rounded,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                      child: Text(
                                    'Your account has been blacklisted and cannot post loads. Please contact support.',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  )),
                                ]),
                              ));
                              return;
                            }
                            setState(() {
                              marketLoads.insert(
                                  0,
                                  MarketLoad(
                                      id:
                                          "L${DateTime.now().millisecondsSinceEpoch}",
                                      route:
                                          "${_pOriginCtrl.text} -> ${_pDestCtrl.text}",
                                      details:
                                          "${_pWeightCtrl.text.isNotEmpty ? '${_pWeightCtrl.text}T | ' : ''}${_pMaterialCtrl.text}",
                                      vehicleType: _pVehicleType,
                                      targetPrice:
                                          double.tryParse(_pPriceCtrl.text) ??
                                              0,
                                      materialType: _pMaterialCtrl.text,
                                      originCity: _pOriginCity,
                                      originState: _pOriginState,
                                      destCity: _pDestCity,
                                      destState: _pDestState,
                                      originFactory: _pFactoryOriginCtrl.text,
                                      destFactory: _pFactoryDestCtrl.text,
                                      weightTons:
                                          double.tryParse(_pWeightCtrl.text) ??
                                              0,
                                      postedDate:
                                          "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                                      postedByUid:
                                          FirebaseService.currentUser?.uid ??
                                              '',
                                      postedByName:
                                          'Consignor: ${userProfile.companyName.isNotEmpty ? userProfile.companyName : userProfile.phone}',
                                      isVerifiedPoster: userProfile
                                              .gstin.isNotEmpty &&
                                          userProfile.bankAccount.isNotEmpty));
                              // Push to Firestore so ALL users see this load
                              if (FirebaseService.isReady) {
                                final newLoad = marketLoads.first;
                                FirebaseFirestore.instance
                                    .collection('marketLoads')
                                    .doc(newLoad.id)
                                    .set({
                                  ...newLoad.toJson(),
                                  'status': newLoad.status.index,
                                  'postedBy':
                                      FirebaseService.currentUser?.uid ??
                                          'local',
                                  'postedAt': FieldValue.serverTimestamp(),
                                }).catchError((_) {});
                              }
                              _idx = 1;
                            });
                            _pOriginCtrl.clear();
                            _pDestCtrl.clear();
                            _pFactoryOriginCtrl.clear();
                            _pFactoryDestCtrl.clear();
                            _pWeightCtrl.clear();
                            _pPriceCtrl.clear();
                            setState(() {
                              _pOriginState = '';
                              _pDestState = '';
                              _pOriginCity = '';
                              _pDestCity = '';
                            });
                            _save();
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    backgroundColor: Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    content: Text(
                                        "OK Load Posted to Market Board!")));
                          },
                          icon: const Icon(Icons.broadcast_on_personal,
                              color: Color(0xFF0F172A)),
                          label: const Text("Broadcast to Market",
                              style: TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold)),
                        )),
                  ])),
        ]));
  }

  //
  Widget _buildKhata() {
    final themeConfig = ThemeHelper.getConfig(ref.watch(appThemeProvider));
    List<TripLedger> fl = List.from(_visibleLedgers);
    bool isBookedLoad(TripLedger ledger) =>
        ledger.lrNotes.contains('BOOKED_LOAD:') && ledger.dispatchedAt.isEmpty;

    if (_khataFilter == "Party" && _khataFilterVal != null) {
      fl = fl.where((l) => l.partyName == _khataFilterVal).toList();
    } else if (_khataFilter == "Vehicle" && _khataFilterVal != null) {
      fl = fl.where((l) => l.vehicleNo == _khataFilterVal).toList();
    } else if (_khataFilter == "Overdue") {
      fl = fl.where((l) => l.isPaymentOverdue).toList();
    } else if (_khataFilter == "Due Soon") {
      fl = fl.where((l) => l.isDueSoon && !l.isPaymentOverdue).toList();
    } else if (_khataFilter == "Pending") {
      fl = fl.where((l) => l.partyPending > 0).toList();
    } else if (_khataFilter == "Settled") {
      fl = fl.where((l) => l.partyPending <= 0).toList();
    } else if (_khataFilter == "Booked") {
      fl = fl.where(isBookedLoad).toList();
    }
    // Sort: overdue first → due soon → in transit → pending → settled → by date
    // Safe date parser: never throws, returns epoch millis (0 if unparseable).
    int dateMillis(TripLedger l) {
      try {
        final p = l.date.split('/');
        if (p.length != 3) return 0;
        final d = int.tryParse(p[0].trim()) ?? 1;
        final m = int.tryParse(p[1].trim()) ?? 1;
        final y = int.tryParse(p[2].trim()) ?? 1970;
        return DateTime(y, m, d).millisecondsSinceEpoch;
      } catch (_) {
        return 0;
      }
    }

    int pri(TripLedger l) {
      if (l.isPaymentOverdue) return 0;
      if (l.isDueSoon) return 1;
      if (l.isInTransit) return 2;
      if (isBookedLoad(l)) return 3;
      if (l.partyPending > 0) return 4;
      return 5;
    }

    // Stable, consistent comparator — always returns a definite ordering.
    fl.sort((a, b) {
      final pd = pri(a) - pri(b);
      if (pd != 0) return pd;
      final md = dateMillis(b) - dateMillis(a); // most recent first
      if (md != 0) return md < 0 ? -1 : 1;
      return a.id.compareTo(b.id); // final tie-breaker keeps order stable
    });

    double totalPending = fl.fold<double>(
        0, (s, l) => s + (l.partyPending > 0 ? l.partyPending : 0));
    double totalBilled = fl.fold<double>(0, (s, l) => s + l.freightBilled);

    return UniversalScaffold(
      body: Column(children: [
        Container(
            color: themeConfig.cardColor,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text("Khata Ledger",
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: themeConfig.primaryTextColor)),
                Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text("${fl.length} entries",
                        style: TextStyle(
                            color: themeConfig.secondaryTextColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 11)),
                    if (totalPending > 0)
                      Text(
                          "Rs.${(totalPending / 1000).toStringAsFixed(0)}K pending",
                          style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w800,
                              fontSize: 11))
                  ]),
                  const SizedBox(width: 10),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        color: themeConfig.primaryTextColor),
                    onSelected: (v) {
                      if (v == 'excel') {
                        _exportKhataExcel(fl);
                      } else if (v == 'csv_import') {
                        _showCSVImport();
                      } else if (v == 'party_statement') {
                        _showPartyStatementSheet();
                      } else if (v == 'ai_tower') {
                        openAiControlTower(
                            context: context,
                            ledgers: _visibleLedgers,
                            bankEntries: moduleState.bankEntries,
                            maintenanceTickets: moduleState.maintenanceTickets,
                            fleet: fleet,
                            marketLoads: marketLoads,
                            complianceVault: moduleState.complianceVault,
                            onApplyReconciliation: (id, amt) {
                              final i = ledgers.indexWhere((l) => l.id == id);
                              if (i >= 0) {
                                setState(
                                    () => ledgers[i].paymentReceived += amt);
                                _save();
                              }
                            },
                            onImportCsv: _showCSVImport);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'party_statement',
                          child: Row(children: [
                            Icon(Icons.picture_as_pdf_rounded,
                                color: Colors.purple, size: 18),
                            SizedBox(width: 10),
                            Text("Party Statement PDF")
                          ])),
                      const PopupMenuItem(
                          value: 'ai_tower',
                          child: Row(children: [
                            Icon(Icons.auto_awesome_rounded,
                                color: Color(0xFF0EA5E9), size: 18),
                            SizedBox(width: 10),
                            Text("AI Finance Analysis")
                          ])),
                      const PopupMenuItem(
                          value: 'excel',
                          child: Row(children: [
                            Icon(Icons.table_chart,
                                color: Colors.green, size: 18),
                            SizedBox(width: 10),
                            Text("Export to Excel / CSV")
                          ])),
                      const PopupMenuItem(
                          value: 'csv_import',
                          child: Row(children: [
                            Icon(Icons.upload_file,
                                color: Colors.blue, size: 18),
                            SizedBox(width: 10),
                            Text("Import Bank CSV")
                          ])),
                    ],
                  ),
                ]),
              ]),
              if (totalBilled > 0)
                Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: themeConfig.highlightColor
                            .withValues(alpha: themeConfig.isDark ? 0.14 : 0.08),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(children: [
                            Text("Billed",
                                style: TextStyle(
                                    color: themeConfig.secondaryTextColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                            FittedBox(
                                child: Text(
                                    "Rs.${(totalBilled / 1000).toStringAsFixed(0)}K",
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        color: themeConfig.primaryTextColor)))
                          ]),
                          Column(children: [
                            Text("Pending",
                                style: TextStyle(
                                    color: themeConfig.secondaryTextColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                            FittedBox(
                                child: Text(
                                    "Rs.${(totalPending / 1000).toStringAsFixed(0)}K",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        color: Colors.orange)))
                          ]),
                          Column(children: [
                            Text("Collected",
                                style: TextStyle(
                                    color: themeConfig.secondaryTextColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                            FittedBox(
                                child: Text(
                                    "Rs.${((totalBilled - totalPending) / 1000).toStringAsFixed(0)}K",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        color: Colors.green)))
                          ]),
                        ])),
              const SizedBox(height: 12),
              SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                      children: [
                    "All",
                    "Overdue",
                    "Due Soon",
                    "Booked",
                    "Pending",
                    "Settled",
                    "Party",
                    "Vehicle"
                  ]
                          .map((t) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                  label: Text(t,
                                      style: TextStyle(
                                          color: _khataFilter == t
                                              ? Colors.white
                                              : themeConfig.primaryTextColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11)),
                                  selected: _khataFilter == t,
                                  selectedColor: themeConfig.highlightColor,
                                  backgroundColor: themeConfig.cardColor,
                                  side: BorderSide(
                                      color: _khataFilter == t
                                          ? themeConfig.highlightColor
                                          : themeConfig.cardBorder),
                                  onSelected: (_) => setState(() {
                                        _khataFilter = t;
                                        _khataFilterVal = null;
                                      }))))
                          .toList())),
              if (_khataFilter == "Party" && ledgers.isNotEmpty) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                    initialValue: _khataFilterVal,
                    isDense: true,
                    hint: const Text("Select Party"),
                    decoration: InputDecoration(
                        labelText: "Filter by Party",
                        filled: true,
                        fillColor: themeConfig.cardColor,
                        labelStyle: TextStyle(
                            color: themeConfig.primaryTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        floatingLabelStyle: TextStyle(
                            color: themeConfig.highlightColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: themeConfig.cardBorder)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: themeConfig.cardBorder)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: themeConfig.highlightColor, width: 2))),
                    items: ledgers
                        .map((e) => (e).partyName)
                        .toSet()
                        .map((p) => DropdownMenuItem<String>(
                            value: p,
                            child: Text(p, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _khataFilterVal = v))
              ],
              if (_khataFilter == "Vehicle" && ledgers.isNotEmpty) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                    initialValue: _khataFilterVal,
                    isDense: true,
                    hint: const Text("Select Vehicle"),
                    decoration: InputDecoration(
                        labelText: "Filter by Vehicle",
                        filled: true,
                        fillColor: themeConfig.cardColor,
                        labelStyle: TextStyle(
                            color: themeConfig.primaryTextColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        floatingLabelStyle: TextStyle(
                            color: themeConfig.highlightColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: themeConfig.cardBorder)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: themeConfig.cardBorder)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color: themeConfig.highlightColor, width: 2))),
                    items: ledgers
                        .map((e) => (e).vehicleNo)
                        .where((v) => (v).isNotEmpty)
                        .toSet()
                        .map((v) => DropdownMenuItem<String>(
                            value: v,
                            child: Text(v, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _khataFilterVal = v))
              ],
            ])),
        Expanded(
            child: fl.isEmpty
                ? Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        const Icon(Icons.menu_book,
                            size: 60, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text("No trips found",
                            style: TextStyle(
                                color: themeConfig.secondaryTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16))
                      ]))
                : ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: fl.length,
                    itemBuilder: (ctx, i) {
                      final l = fl[i];
                      final sc = l.isPaymentOverdue
                          ? Colors.red
                          : l.isDueSoon
                              ? Colors.orange
                              : isBookedLoad(l)
                                  ? themeConfig.accentColor
                              : l.partyPending <= 0
                                  ? Colors.green
                                  : Colors.blueGrey;
                      final st = l.partyPending <= 0
                          ? "✓ Settled"
                          : l.isPaymentOverdue
                              ? "⚠ Overdue"
                              : l.isDueSoon
                                  ? "Due Soon"
                                  : l.isInTransit
                                      ? "In Transit"
                                      : isBookedLoad(l)
                                          ? "Booked"
                                          : "Pending";
                      return GestureDetector(
                        onTap: () => Navigator.push(
                            ctx,
                            MaterialPageRoute(
                                builder: (_) => TripDetailScreen(
                                    ledger: l,
                                    userProfile: userProfile,
                                    subscription: subscription,
                                    drivers: drivers,
                                    onUpdateLedger: (upd) {
                                      final idx = ledgers
                                          .indexWhere((x) => x.id == l.id);
                                      if (idx >= 0) {
                                        setState(() => ledgers[idx] = upd);
                                        _save();
                                      }
                                    },
                                    onKredXApply: (a) {
                                      setState(() => kredxApps.insert(0, a));
                                      _save();
                                    }))),
                        child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                                color: _cardBg,
                                borderRadius: BorderRadius.circular(16),
                                border: Border(
                                    left: BorderSide(color: sc, width: 4)),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3))
                                ]),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(children: [
                                          Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                  color: sc,
                                                  shape: BoxShape.circle)),
                                          const SizedBox(width: 8),
                                          Text(l.vehicleNo,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 14,
                                                  color: themeConfig
                                                      .primaryTextColor))
                                        ]),
                                        Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                                color:
                                                    sc.withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            child: Text(st,
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: sc))),
                                      ]),
                                  const SizedBox(height: 6),
                                  Text(l.partyName,
                                      style: TextStyle(
                                          color:
                                              themeConfig.primaryTextColor,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 2),
                                  Text(
                                      "${l.loadingPoint.isNotEmpty ? '${l.loadingPoint} -> ${l.unloadingPoint}' : l.route} - ${l.date}",
                                      style: TextStyle(
                                          color:
                                              themeConfig.secondaryTextColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500)),
                                  if (l.materialName.isNotEmpty)
                                    Text(
                                        "${l.materialName}${l.weightTons > 0 ? ' - ${l.weightTons} ${l.weightUnit}' : ''}",
                                        style: TextStyle(
                                            color:
                                                themeConfig.secondaryTextColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  const Divider(height: 14),
                                  Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text("Freight",
                                                  style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              Text(
                                                  "Rs.${l.freightBilled.toStringAsFixed(0)}",
                                                  style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w900))
                                            ]),
                                        if (l.partyPending > 0)
                                          Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.center,
                                              children: [
                                                Text(
                                                    l.isPaymentOverdue
                                                        ? "Amount Due"
                                                        : "Balance Due",
                                                    style: const TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.grey,
                                                        fontWeight:
                                                            FontWeight.bold)),
                                                Text(
                                                    "Rs.${l.partyPending.toStringAsFixed(0)}",
                                                    style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight: FontWeight
                                                            .w900,
                                                        color:
                                                            l.isPaymentOverdue
                                                                ? Colors.red
                                                                : Colors
                                                                    .orange))
                                              ]),
                                        Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                  l.ownership ==
                                                          VehicleOwnership.self
                                                      ? "Profit"
                                                      : "Commission",
                                                  style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              Text(
                                                  "Rs.${l.tripProfit.toStringAsFixed(0)}",
                                                  style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: l.tripProfit >= 0
                                                          ? Colors.green
                                                          : Colors.red))
                                            ]),
                                      ]),
                                ])),
                      );
                    })),
      ]),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
              heroTag: 'quickCaptureFab',
              mini: true,
              backgroundColor: const Color(0xFF10B981),
              tooltip: 'Quick add from photo or voice note',
              onPressed: () => _showQuickCapture(),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Color(0xFFFFFFFF))),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
              heroTag: 'newTripFab',
              backgroundColor: const Color(0xFF0EA5E9),
              elevation: 6,
              icon: const Icon(Icons.add, color: Color(0xFFFFFFFF)),
              label: const Text("New Trip",
                  style: TextStyle(
                      color: Color(0xFFFFFFFF),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3)),
              onPressed: () => _showNewEntry()),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // QUICK CAPTURE — pick a photo or voice-note file, let AI read it,
  // then open the normal New Trip form pre-filled for review.
  // ══════════════════════════════════════════════════════════════
  Future<void> _showQuickCapture() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quick add trip',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                  'AI reads a photo or voice note and fills the trip form for you to check and save.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded,
                    color: Color(0xFF0EA5E9)),
                title: const Text('Photo of document'),
                subtitle: const Text('LR, invoice, delivery challan'),
                onTap: () => Navigator.pop(c, 'photo'),
              ),
              ListTile(
                leading:
                    const Icon(Icons.mic_rounded, color: Color(0xFF10B981)),
                title: const Text('Voice note file'),
                subtitle: const Text('Saved from WhatsApp to this device'),
                onTap: () => Navigator.pop(c, 'audio'),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    await _pickAndExtractTrip(choice);
  }

  String _audioMimeFromExt(String ext) {
    switch (ext.toLowerCase()) {
      case 'ogg':
      case 'opus':
        return 'audio/ogg';
      case 'mp3':
        return 'audio/mp3';
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'flac':
        return 'audio/flac';
      default:
        return 'audio/ogg'; // WhatsApp's default voice-note format
    }
  }

  Future<void> _pickAndExtractTrip(String kind) async {
    FilePickerResult? result;
    try {
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: kind == 'photo'
            ? ['jpg', 'jpeg', 'png']
            : ['ogg', 'opus', 'mp3', 'wav', 'm4a', 'aac', 'flac'],
        allowMultiple: false,
        withData: true,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not open file picker: $e'),
          backgroundColor: Colors.red));
      return;
    }
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final bytes = picked.bytes;
    if (bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not read that file. Please try again.'),
          backgroundColor: Colors.red));
      return;
    }
    final ext = (picked.extension ?? '').toLowerCase();
    final mimeType = kind == 'photo'
        ? (ext == 'png' ? 'image/png' : 'image/jpeg')
        : _audioMimeFromExt(ext);

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
          child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      )),
    );

    Map<String, dynamic>? extracted;
    try {
      extracted = await AiEngine.extractTripFromFile(
        fileBytes: bytes,
        mimeType: mimeType,
        tier: subscription.tier,
      );
    } catch (_) {
      extracted = null;
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close loading dialog

    if (extracted == null) {
      if (!mounted) return;
      final reason = AiEngine.lastCaptureError.isEmpty
          ? "Couldn't read that file."
          : AiEngine.lastCaptureError;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$reason Opening a blank form instead.'),
          backgroundColor: Color(0xFFF97316)));
      await _showNewEntry();
      return;
    }

    String? asText(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      return s.isEmpty ? null : s;
    }

    double? asNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    final freight = asNum(extracted['freightBilled']);
    final weight = asNum(extracted['weightTons']);
    final distance = asNum(extracted['distanceKm']);
    final notes = asText(extracted['notes']);

    // Show anything extra the AI understood *before* the form opens,
    // since a SnackBar shown after the form closes is too late to help
    // the person reviewing the pre-filled fields.
    if (notes != null && mounted) {
      await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('AI also noted'),
          content: Text(notes),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c), child: const Text('Got it')),
          ],
        ),
      );
    }

    if (!mounted) return;
    await _showNewEntry(
      prefillPartyName: asText(extracted['partyName']),
      prefillRoute: asText(extracted['route']),
      prefillMaterial: asText(extracted['materialName']),
      prefillFreight: (freight != null && freight > 0) ? freight : null,
      prefillWeight: (weight != null && weight > 0) ? weight : null,
      prefillVehicleNo: asText(extracted['vehicleNo']),
      prefillDriverName: asText(extracted['driverName']),
      prefillDistanceKm: (distance != null && distance > 0) ? distance : null,
    );
  }

  Future<void> _exportKhataExcel(List<TripLedger> list) async {
    final sb = StringBuffer();
    sb.writeln(
        "Trip ID,Date,Party Name,Vehicle No,Route,Loading Point,Unloading Point,Material,Weight,E-Way Bill,Driver,Freight Billed,Payment Received,TDS,Penalties,Net Pending,Diesel,Toll,Driver Exp,Material Loss,Market Freight,Trip Profit,GST Type,GST Amount,Payment Terms,LR Notes,Status");
    for (final l in list) {
      final status = l.partyPending <= 0
          ? "Settled"
          : l.isPaymentOverdue
              ? "OVERDUE"
              : l.isDueSoon
                  ? "DUE SOON"
                  : "Pending";
      sb.writeln([
        l.id,
        l.date,
        '"${l.partyName}"',
        l.vehicleNo,
        '"${l.route}"',
        '"${l.loadingPoint}"',
        '"${l.unloadingPoint}"',
        '"${l.materialName}"',
        "${l.weightTons} ${l.weightUnit}",
        l.eWayBillNo,
        l.driverName ?? '',
        l.freightBilled.toStringAsFixed(2),
        l.paymentReceived.toStringAsFixed(2),
        l.tdsDeduction.toStringAsFixed(2),
        l.penalties.toStringAsFixed(2),
        l.partyPending.toStringAsFixed(2),
        l.diesel.toStringAsFixed(2),
        l.toll.toStringAsFixed(2),
        l.driverExp.toStringAsFixed(2),
        l.materialLoss.toStringAsFixed(2),
        l.marketTruckFreight.toStringAsFixed(2),
        l.tripProfit.toStringAsFixed(2),
        l.gstType.name,
        l.gstAmount.toStringAsFixed(2),
        l.paymentTermsDays,
        '"${l.lrNotes}"',
        status
      ].join(','));
    }
    final csvText = sb.toString();
    Clipboard.setData(ClipboardData(text: csvText));
    // Also write to a temp file so user can share/open directly
    try {
      final dir = await getTemporaryDirectory();
      final fname =
          'RoutemasterExport_${DateTime.now().day}${DateTime.now().month}${DateTime.now().year}.csv';
      final file = File('${dir.path}/$fname');
      await file.writeAsString(csvText);
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'NavGati ERP — Khata Export',
        text: 'Khata export from NavGati ERP. Open in Excel or Google Sheets.',
      ));
    } catch (_) {
      // Fallback: clipboard only
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            content: Text(
                'CSV copied to clipboard. Paste in Excel or Google Sheets.')));
      }
    }
  }

  void _showPartyStatementSheet() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DraggableScrollableSheet(
              initialChildSize: 0.55,
              maxChildSize: 0.90,
              minChildSize: 0.40,
              builder: (_, sc) => Container(
                decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24))),
                child: Column(children: [
                  Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(children: [
                      Icon(Icons.picture_as_pdf_rounded,
                          color: Colors.purple, size: 20),
                      SizedBox(width: 10),
                      Text("Party Statement PDF",
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F172A))),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                      child: SingleChildScrollView(
                          controller: sc,
                          padding: const EdgeInsets.all(16),
                          child: _PartyStatementGenerator(
                            ledgers: _visibleLedgers,
                            cardColor: Colors.white,
                            card2Color: const Color(0xFFEFF6FF),
                            borderColor: const Color(0xFFBFE7FF),
                            accentColor: const Color(0xFF0EA5E9),
                            purpleColor: Colors.purple,
                            greenColor: const Color(0xFF10B981),
                            redColor: const Color(0xFFEF4444),
                          ))),
                ]),
              ),
            ));
  }

  void _showCSVImport() => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => BankImportScreen(
              ledgers: ledgers,
              onMatch: (id, amt) {
                final i = ledgers.indexWhere((l) => l.id == id);
                if (i >= 0) {
                  setState(() => ledgers[i].paymentReceived += amt);
                  _save();
                }
              },
              sharedEntries: moduleState.bankEntries,
              onEntriesUpdated: (entries) {
                setState(() => moduleState.bankEntries = entries);
              })));

  //
  // Route option tile used in the alternative routes dialog
  static Widget _routeOptionTile(BuildContext ctx, String label, double km,
          int durMin, String via, Color c,
          {bool isSelected = false, required VoidCallback onTap}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
              color: c.withValues(alpha: isSelected ? 0.1 : 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: c.withValues(alpha: isSelected ? 0.5 : 0.2))),
          child: Row(children: [
            Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: c,
                size: 20),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 13, color: c)),
                  if (via.isNotEmpty)
                    Text('via $via',
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 11)),
                ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${km.toStringAsFixed(1)} km',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 15, color: c)),
              if (durMin > 0)
                Text('~${durMin}min',
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 10)),
            ]),
          ]),
        ),
      );

  Future<void> _showNewEntry(
      {String? prefillRoute,
      String? prefillLoadId,
      double? prefillFreight,
      String? prefillPartyName,
      String? prefillMaterial,
      String? prefillOriginCity,
      String? prefillOriginState,
      String? prefillDestCity,
      String? prefillDestState,
      String? prefillFactory,
      String? prefillDestFactory,
      double? prefillWeight,
      String? prefillVehicleType,
      String? prefillVehicleNo,
      String? prefillDriverName,
      double? prefillDistanceKm,
      bool skipRegistrationCheck = false}) async {
    if (subscription.isTripsLimitReached) {
      _upgradeBanner("Unlimited Trips (Free: 10/month)");
      return;
    }
    // Check if registration is complete - block dispatch until KYC is done
    final prefs = await SharedPreferences.getInstance();
    var regDone = (prefs.getBool('rm_registration_done') ?? false) ||
        skipRegistrationCheck;
    if (!regDone) {
      if (!mounted) return;
      final wantToRegister = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
                backgroundColor: const Color(0xFFF6FAFF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: const Row(children: [
                  Icon(Icons.assignment_ind_rounded, color: Color(0xFF0EA5E9)),
                  SizedBox(width: 10),
                  Flexible(
                      child: Text("Registration Required",
                          style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w900,
                              fontSize: 16)))
                ]),
                content: const Text(
                    "Before posting or booking loads, please complete your company KYC profile. This is required for invoice generation, GST compliance, and consignor verification.",
                    style: TextStyle(color: Color(0xFF0F172A), fontSize: 13)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text("Cancel",
                          style: TextStyle(color: Color(0xFF0F172A)))),
                  GestureDetector(
                      onTap: () => Navigator.pop(c, true),
                      child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 8),
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFF0EA5E9),
                                Color(0xFF0EA5E9)
                              ]),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Text("Complete Now",
                              style: TextStyle(
                                  color: Color(0xFFF6FAFF),
                                  fontWeight: FontWeight.w800)))),
                ],
              ));
      if (wantToRegister != true) return;
      // Open registration screen and WAIT for it to complete
      if (!mounted) return;
      await Navigator.push(context,
          MaterialPageRoute(builder: (_) => const RegistrationScreen()));
      // Re-check registration status after returning
      final prefs2 = await SharedPreferences.getInstance();
      regDone = prefs2.getBool('rm_registration_done') ?? false;
      if (!regDone) {
        // User backed out of registration - block dispatch
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              backgroundColor: Color(0xFF0EA5E9),
              behavior: SnackBarBehavior.floating,
              content: Text(
                  "Registration must be completed to post/dispatch loads")));
        }
        return;
      }
    }
    // Start with self fleet always. Only switch to market if fleet has NO matching vehicle.
    final hasMatchingVehicle = prefillVehicleType == null ||
        prefillVehicleType.isEmpty ||
        fleet.any((v) => (v).type.toLowerCase().contains(
            prefillVehicleType.toLowerCase().split(' ').first.toLowerCase()));
    VehicleOwnership own =
        hasMatchingVehicle ? VehicleOwnership.self : VehicleOwnership.market;
    String? selVeh = fleet.isNotEmpty ? fleet.first.number : null;
    // If quick-capture extracted a vehicle number, prefer it when it
    // matches an existing fleet vehicle (keeps the self-fleet dropdown
    // in sync); otherwise it's left for the free-text market field below.
    if (prefillVehicleNo != null && prefillVehicleNo.trim().isNotEmpty) {
      final normalized = prefillVehicleNo.replaceAll(' ', '').toUpperCase();
      final match = fleet.where(
          (v) => v.number.replaceAll(' ', '').toUpperCase() == normalized);
      if (match.isNotEmpty) selVeh = match.first.number;
    }
    String? selDrv;
    final pCtrl = TextEditingController(text: prefillPartyName ?? "");
    final vCtrl = TextEditingController(text: prefillVehicleNo ?? selVeh ?? '');
    final rCtrl = TextEditingController(text: prefillRoute ?? "");
    final fCtrl =
        TextEditingController(text: prefillFreight?.toStringAsFixed(0) ?? "");
    final rcvdCtrl = TextEditingController();
    final dslCtrl = TextEditingController();
    final tolCtrl = TextEditingController();
    final drvCtrl = TextEditingController(text: prefillDriverName ?? "");
    final losCtrl = TextEditingController();
    final mfCtrl = TextEditingController();
    final maCtrl = TextEditingController();
    final tmCtrl = TextEditingController(text: "30");
    final ewCtrl = TextEditingController();
    final matCtrl =
        TextEditingController(text: prefillMaterial ?? "Chemical/Ethanol");
    final penCtrl = TextEditingController();
    final tdsCtrl = TextEditingController();
    final distCtrl = TextEditingController(
        text: (prefillDistanceKm != null && prefillDistanceKm > 0)
            ? prefillDistanceKm.toStringAsFixed(1)
            : "");
    final feCtrl = TextEditingController(text: "3.5");
    // Auto-calc diesel when km or mileage changes
    // Diesel rate - user-editable, defaults to AppConfig rate
    final dslRateCtrl = TextEditingController(
        text: AppConfig.defaultDieselPrice.toStringAsFixed(0));
    double currentFuelEconomy() =>
        double.tryParse(feCtrl.text.trim()) ?? double.nan;
    double currentDieselPrice() =>
        double.tryParse(dslRateCtrl.text.trim()) ?? double.nan;

    void autoCalc() {
      final km = double.tryParse(distCtrl.text.trim());
      final fe = currentFuelEconomy();
      final rate = currentDieselPrice();
      if (km != null && km.isFinite && km > 0) {
        if (fe.isFinite && fe > 0 && rate.isFinite && rate > 0) {
          final calcDsl = (km / fe * rate).round().toString();
          if (dslCtrl.text != calcDsl) dslCtrl.text = calcDsl;
        } else if (dslCtrl.text.isNotEmpty) {
          dslCtrl.clear();
        }
        int ax = 6;
        if (selVeh != null) {
          final selected = fleet.where((v) => v.number == selVeh);
          if (selected.isNotEmpty && selected.first.axleCount > 0) {
            ax = selected.first.axleCount;
          }
        }
        final calcToll = estimateToll(km, ax).round().toString();
        if (tolCtrl.text != calcToll) tolCtrl.text = calcToll;
      } else {
        if (dslCtrl.text.isNotEmpty) dslCtrl.clear();
        if (tolCtrl.text.isNotEmpty) tolCtrl.clear();
      }
    }

    distCtrl.addListener(autoCalc);
    feCtrl.addListener(autoCalc);
    dslRateCtrl.addListener(autoCalc);
    autoCalc();
    final wtCtrl = TextEditingController(
        text: prefillWeight != null && prefillWeight > 0
            ? prefillWeight.toStringAsFixed(1)
            : '');
    final cpCtrl = TextEditingController();
    final ceCtrl = TextEditingController();
    final cgCtrl = TextEditingController();
    final notCtrl = TextEditingController();
    String wUnit = "MT",
        lOCity = prefillOriginCity ?? '',
        lDCity = prefillDestCity ?? '';
    String lOState = prefillOriginState ?? '', lDState = prefillDestState ?? '';
    if (lOCity.isEmpty && (prefillFactory ?? '').isNotEmpty) {
      lOCity = RoutingEngine.extractCityFromAddress(prefillFactory!);
    }
    if (lDCity.isEmpty && (prefillDestFactory ?? '').isNotEmpty) {
      lDCity = RoutingEngine.extractCityFromAddress(prefillDestFactory!);
    }
    GstType gst = GstType.none;
    double gstRate = 5.0;
    bool gstInc = false;
    bool calcDone = false;
    int routeCalcRevision = 0;
    void resetRouteEstimate() {
      distCtrl.clear();
      dslCtrl.clear();
      tolCtrl.clear();
      calcDone = false;
    }

    void showRouteFailure(Map<String, dynamic> result) {
      if (!mounted) return;
      final source = result['source'] as String? ?? 'not_found';
      final message = switch (source) {
        'no_api_key' => 'Configure a valid Maps API key to calculate routes.',
        'invalid_fuel_economy' => 'Enter a valid mileage greater than zero.',
        'invalid_diesel_price' =>
          'Enter a valid diesel price greater than zero.',
        'missing_locations' => 'Select both origin and destination.',
        _ =>
          'Could not calculate this route. Check the locations and Maps API access.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        content: Text(message),
      ));
    }

    final invCtrl = TextEditingController(); // material invoice number
    final List<InvoiceItem> partItems = []; // part load items
    // Factory / plant fields - placeId gives precise coordinates for Google Maps routing
    final loFactCtrl = TextEditingController(text: prefillFactory ?? '');
    final ldFactCtrl = TextEditingController(text: prefillDestFactory ?? '');
    String loFactName = prefillFactory ?? '', loFactPlaceId = '';
    String ldFactName = prefillDestFactory ?? '', ldFactPlaceId = '';
    String lOCityPlaceId = '', lDCityPlaceId = '';
    // Override placeId for raw address strings
    if ((prefillFactory ?? '').contains(',')) loFactPlaceId = '';
    if ((prefillDestFactory ?? '').contains(',')) ldFactPlaceId = '';

    final outerSetState = setState;
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setS) => Container(
                  height: MediaQuery.of(ctx).size.height * 0.97,
                  decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28))),
                  padding: EdgeInsets.only(
                      top: 24,
                      left: 20,
                      right: 20,
                      bottom: MediaQuery.of(ctx).viewInsets.bottom),
                  child: SingleChildScrollView(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("New Dispatch Entry",
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A))),
                              IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Color(0xFF0F172A)),
                                  onPressed: () => Navigator.pop(ctx)),
                            ]),
                        const SizedBox(height: 16),
                        SegmentedButton<VehicleOwnership>(
                            style: SegmentedButton.styleFrom(
                                selectedBackgroundColor:
                                    const Color(0xFF0EA5E9),
                                selectedForegroundColor:
                                    const Color(0xFFF6FAFF),
                                backgroundColor: const Color(0xFFF6FAFF)),
                            segments: const [
                              ButtonSegment(
                                  value: VehicleOwnership.self,
                                  icon: Icon(Icons.local_shipping, size: 14),
                                  label: Text("Self Fleet")),
                              ButtonSegment(
                                  value: VehicleOwnership.market,
                                  icon: Icon(Icons.handshake, size: 14),
                                  label: Text("Market Truck"))
                            ],
                            selected: {own},
                            onSelectionChanged: (v) =>
                                setS(() => own = v.first)),
                        const SizedBox(height: 16),

                        // Party + Terms
                        Row(children: [
                          Expanded(
                              flex: 2,
                              child: TextField(
                                  style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                  controller: pCtrl,
                                  decoration: InputDecoration(
                                      labelText: "Party / Consignor Name *",
                                      filled: true,
                                      fillColor: const Color(0xFFF6FAFF),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9))),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9))),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9),
                                              width: 2))))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: TextField(
                                  style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                  controller: tmCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                      labelText: "Terms (Days)",
                                      filled: true,
                                      fillColor: const Color(0xFFF6FAFF),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9))),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9))),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9),
                                              width: 2))))),
                        ]),
                        const SizedBox(height: 12),
                        // Consignor details
                        ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text("Consignor Contact & GST",
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A))),
                            children: [
                              Row(children: [
                                Expanded(
                                    child: TextField(
                                        style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500),
                                        controller: cpCtrl,
                                        keyboardType: TextInputType.phone,
                                        decoration: InputDecoration(
                                            labelText: "Consignor Phone",
                                            filled: true,
                                            fillColor: const Color(0xFFF6FAFF),
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                    color: Color(0xFF0EA5E9))),
                                            enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                    color: Color(0xFF0EA5E9))),
                                            focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                    color: Color(0xFF0EA5E9),
                                                    width: 2))))),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: TextField(
                                        style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500),
                                        controller: cgCtrl,
                                        decoration: InputDecoration(
                                            labelText: "GSTIN",
                                            filled: true,
                                            fillColor: const Color(0xFFF6FAFF),
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                    color: Color(0xFF0EA5E9))),
                                            enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                    color: Color(0xFF0EA5E9))),
                                            focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                    color: Color(0xFF0EA5E9),
                                                    width: 2)))))
                              ]),
                              const SizedBox(height: 8),
                              TextField(
                                  style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                  controller: ceCtrl,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                      labelText:
                                          "Consignor Email (for auto-docs)",
                                      filled: true,
                                      fillColor: const Color(0xFFF6FAFF),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9))),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9))),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9),
                                              width: 2)))),
                              const SizedBox(height: 8),
                            ]),
                        const SizedBox(height: 10),

                        // Route
                        const Text("Route Details",
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                color: Color(0xFF0F172A))),
                        const SizedBox(height: 4),
                        // Origin
                        Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: _cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color:
                                        Colors.green.withValues(alpha: 0.4))),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.green)),
                                    const SizedBox(width: 8),
                                    const Text("LOADING / ORIGIN",
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF15803D),
                                            letterSpacing: 1))
                                  ]),
                                  const SizedBox(height: 8),
                                  FactorySearchField(
                                    controller: loFactCtrl,
                                    label: "Factory / Plant Name (Loading)",
                                    iconColor: Colors.green,
                                    onSelected: (name, pid) {
                                      final requestId = ++routeCalcRevision;
                                      setS(() {
                                        resetRouteEstimate();
                                        loFactName = name;
                                        loFactPlaceId = pid;
                                        // Auto-extract city from factory address
                                        // e.g. "Vatva GIDC, Ahmedabad, Gujarat" → "Ahmedabad"
                                        if (lOCity.isEmpty) {
                                          final extracted = RoutingEngine
                                              .extractCityFromAddress(name);
                                          if (extracted.isNotEmpty) {
                                            lOCity = extracted;
                                          }
                                        }
                                        if (rCtrl.text.isEmpty) {
                                          rCtrl.text =
                                              "$name -> ${ldFactName.isNotEmpty ? ldFactName : lDCity}";
                                        }
                                      });
                                      // Auto-calc against ANY destination (factory OR city)
                                      final destName = ldFactName.isNotEmpty
                                          ? ldFactName
                                          : lDCity;
                                      final destPid = ldFactPlaceId.isNotEmpty
                                          ? ldFactPlaceId
                                          : lDCityPlaceId;
                                      if (destName.isNotEmpty &&
                                          name.isNotEmpty) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  backgroundColor:
                                                      const Color(0xFF0EA5E9),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  duration: const Duration(
                                                      seconds: 2),
                                                  content: Row(children: const [
                                                    SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child:
                                                            CircularProgressIndicator(
                                                                color: Color(
                                                                    0xFFF6FAFF),
                                                                strokeWidth:
                                                                    2)),
                                                    SizedBox(width: 10),
                                                    Text(
                                                        " Calculating distance via Google Maps...")
                                                  ])));
                                        }
                                        Future.delayed(
                                            const Duration(milliseconds: 400),
                                            () async {
                                          int ax = 6;
                                          try {
                                            if (selVeh != null) {
                                              ax = fleet
                                                  .firstWhere(
                                                      (v) => v.number == selVeh)
                                                  .axleCount;
                                            }
                                          } catch (_) {}
                                          final res =
                                              await RoutingEngine.calculate(
                                                  origin: name,
                                                  destination: destName,
                                                  axles: ax,
                                                  fuelEconomy:
                                                      currentFuelEconomy(),
                                                  dieselPrice:
                                                      currentDieselPrice(),
                                                  originPlaceId: pid,
                                                  destPlaceId: destPid,
                                                  originCity: lOCity,
                                                  destCity: lDCity);
                                          if (requestId != routeCalcRevision ||
                                              !mounted) {
                                            return;
                                          }
                                          final km = res['km'] as int? ?? 0;
                                          final preciseKm =
                                              (res['distanceKm'] as num?)
                                                      ?.toDouble() ??
                                                  km.toDouble();
                                          if (km > 0 && mounted) {
                                            setS(() {
                                              distCtrl.text =
                                                  ((res['distanceKm'] as num?)
                                                              ?.toDouble() ??
                                                          km.toDouble())
                                                      .toStringAsFixed(1);
                                              tolCtrl.text =
                                                  res['toll'].toString();
                                              dslCtrl.text =
                                                  res['diesel'].toString();
                                              calcDone = true;
                                            });
                                            // Show rich result with traffic info
                                            final routeSummary =
                                                res['routeSummary']
                                                        as String? ??
                                                    '';
                                            final durMin =
                                                res['durationMinutes']
                                                        as int? ??
                                                    0;
                                            final durTraffic =
                                                res['durationInTrafficMinutes']
                                                        as int? ??
                                                    0;
                                            final alts =
                                                res['alternatives'] as List? ??
                                                    [];
                                            final trafficDelay =
                                                durTraffic - durMin;
                                            String trafficNote = '';
                                            if (durMin > 0) {
                                              if (trafficDelay >= 15) {
                                                trafficNote =
                                                    ' | ⚠️ +${trafficDelay}min traffic delay';
                                              } else if (trafficDelay >= 5)
                                                trafficNote =
                                                    ' | 🚦 +${trafficDelay}min traffic';
                                              else
                                                trafficNote =
                                                    ' | ✅ Clear roads';
                                            }
                                            final altNote = alts.isNotEmpty
                                                ? '  ${alts.length} alt route${alts.length > 1 ? "s" : ""} available'
                                                : '';
                                            final routeNote =
                                                routeSummary.isNotEmpty
                                                    ? ' via $routeSummary'
                                                    : '';
                                            ScaffoldMessenger.of(context)
                                                .hideCurrentSnackBar();
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    backgroundColor:
                                                        Colors.green.shade700,
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                    duration: const Duration(
                                                        seconds: 6),
                                                    content: Text(
                                                        "✅ ${preciseKm.toStringAsFixed(1)} km$routeNote$trafficNote  |  Rs.${res['diesel']} diesel  |  Rs.${res['toll']} toll$altNote")));
                                            // If there are alternatives, show them in a dialog
                                            if (alts.isNotEmpty && mounted) {
                                              Future.delayed(
                                                  const Duration(
                                                      milliseconds: 200), () {
                                                if (!mounted) return;
                                                showDialog(
                                                    context: context,
                                                    builder:
                                                        (ctx) => AlertDialog(
                                                              shape: RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              18)),
                                                              title: Row(
                                                                  children: const [
                                                                    Icon(
                                                                        Icons
                                                                            .alt_route_rounded,
                                                                        color: Color(
                                                                            0xFF0EA5E9)),
                                                                    SizedBox(
                                                                        width:
                                                                            8),
                                                                    Text(
                                                                        'Alternative Routes',
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.w900,
                                                                            fontSize: 16)),
                                                                  ]),
                                                              content: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    // Best route
                                                                    _routeOptionTile(
                                                                        ctx,
                                                                        'Fastest in Current Traffic (Selected)',
                                                                        preciseKm,
                                                                        durTraffic,
                                                                        routeSummary,
                                                                        const Color(
                                                                            0xFF10B981),
                                                                        isSelected:
                                                                            true,
                                                                        onTap: () =>
                                                                            Navigator.pop(ctx)),
                                                                    const Divider(),
                                                                    // Alternatives
                                                                    ...alts
                                                                        .take(2)
                                                                        .map(
                                                                            (alt) {
                                                                      final altKm = (alt['distanceKm'] as num?)
                                                                              ?.toDouble() ??
                                                                          (alt['km'] as int)
                                                                              .toDouble();
                                                                      final altDur = alt['durationTrafficMin']
                                                                              as int? ??
                                                                          alt['durationMin']
                                                                              as int? ??
                                                                          0;
                                                                      final altSummary =
                                                                          alt['summary'] as String? ??
                                                                              '';
                                                                      return _routeOptionTile(
                                                                          ctx,
                                                                          'Alternative',
                                                                          altKm,
                                                                          altDur,
                                                                          altSummary,
                                                                          const Color(
                                                                              0xFF0EA5E9),
                                                                          onTap:
                                                                              () {
                                                                        setS(
                                                                            () {
                                                                          distCtrl.text =
                                                                              altKm.toStringAsFixed(1);
                                                                          final altDiesel =
                                                                              ((altKm / currentFuelEconomy()) * currentDieselPrice()).round();
                                                                          dslCtrl.text =
                                                                              altDiesel.toString();
                                                                          tolCtrl
                                                                              .text = estimateToll(altKm,
                                                                                  ax)
                                                                              .round()
                                                                              .toString();
                                                                        });
                                                                        Navigator.pop(
                                                                            ctx);
                                                                      });
                                                                    }),
                                                                  ]),
                                                              actions: [
                                                                TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            ctx),
                                                                    child: const Text(
                                                                        'Keep Recommended'))
                                                              ],
                                                            ));
                                              });
                                            }
                                          } else if (mounted) {
                                            showRouteFailure(res);
                                          }
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  CitySearchField(
                                      label: "Loading City",
                                      icon: Icons.location_city,
                                      iconColor: Colors.green,
                                      initialValue: prefillOriginCity ?? '',
                                      onCitySelected: (city, state, pid) {
                                        final requestId = ++routeCalcRevision;
                                        setS(() {
                                          resetRouteEstimate();
                                          lOCity = city;
                                          lOState = state;
                                          lOCityPlaceId = pid;
                                        });
                                        // Auto-calc if destination is already known
                                        final dest = ldFactName.isNotEmpty
                                            ? ldFactName
                                            : lDCity;
                                        final dPid = ldFactPlaceId.isNotEmpty
                                            ? ldFactPlaceId
                                            : lDCityPlaceId;
                                        if (dest.isNotEmpty) {
                                          Future.delayed(
                                              const Duration(milliseconds: 300),
                                              () async {
                                            int ax = 6;
                                            try {
                                              if (selVeh != null) {
                                                ax = fleet
                                                    .firstWhere((v) =>
                                                        v.number == selVeh)
                                                    .axleCount;
                                              }
                                            } catch (_) {}
                                            final res =
                                                await RoutingEngine.calculate(
                                                    origin: city,
                                                    destination: dest,
                                                    axles: ax,
                                                    fuelEconomy:
                                                        currentFuelEconomy(),
                                                    dieselPrice:
                                                        currentDieselPrice(),
                                                    originPlaceId: pid,
                                                    destPlaceId: dPid,
                                                    originCity: city,
                                                    destCity: lDCity);
                                            if (requestId !=
                                                    routeCalcRevision ||
                                                !mounted) {
                                              return;
                                            }
                                            if ((res['km'] as int? ?? 0) > 0) {
                                              setS(() {
                                                distCtrl.text =
                                                    ((res['distanceKm'] as num?)
                                                                ?.toDouble() ??
                                                            (res['km'] as int)
                                                                .toDouble())
                                                        .toStringAsFixed(1);
                                                tolCtrl.text =
                                                    res['toll'].toString();
                                                dslCtrl.text =
                                                    res['diesel'].toString();
                                                calcDone = true;
                                              });
                                              if (mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                        backgroundColor: Colors
                                                            .green.shade700,
                                                        behavior:
                                                            SnackBarBehavior
                                                                .floating,
                                                        duration:
                                                            const Duration(
                                                                seconds: 3),
                                                        content: Text(
                                                            " ${((res['distanceKm'] as num?)?.toDouble() ?? (res['km'] as int).toDouble()).toStringAsFixed(1)} km  |  Rs.${res['diesel']} diesel  |  Rs.${res['toll']} toll")));
                                              }
                                            } else {
                                              showRouteFailure(res);
                                            }
                                          });
                                        }
                                      }),
                                  if (lOState.isNotEmpty)
                                    Padding(
                                        padding: const EdgeInsets.only(
                                            top: 4, left: 4),
                                        child: Text(lOState,
                                            style: TextStyle(
                                                color: Colors.green[700],
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700))),
                                ])),
                        const SizedBox(height: 6),
                        Center(
                            child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF0EA5E9),
                                    borderRadius: BorderRadius.circular(12)),
                                child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.arrow_downward,
                                          size: 12, color: Color(0xFFFFFFFF)),
                                      SizedBox(width: 4),
                                      Text("TO",
                                          style: TextStyle(
                                              color: Color(0xFF0F172A),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1))
                                    ]))),
                        const SizedBox(height: 6),
                        // Destination
                        Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: _cardBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: Colors.red.withValues(alpha: 0.4))),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                        width: 10,
                                        height: 10,
                                        decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.red)),
                                    const SizedBox(width: 8),
                                    const Text("UNLOADING / DESTINATION",
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFEF4444),
                                            letterSpacing: 1))
                                  ]),
                                  const SizedBox(height: 8),
                                  FactorySearchField(
                                    controller: ldFactCtrl,
                                    label: "Factory / Depot Name (Unloading)",
                                    iconColor: Colors.red,
                                    onSelected: (name, pid) {
                                      final requestId = ++routeCalcRevision;
                                      setS(() {
                                        resetRouteEstimate();
                                        ldFactName = name;
                                        ldFactPlaceId = pid;
                                        // Auto-extract city from factory address
                                        if (lDCity.isEmpty) {
                                          final extracted = RoutingEngine
                                              .extractCityFromAddress(name);
                                          if (extracted.isNotEmpty) {
                                            lDCity = extracted;
                                          }
                                        }
                                        rCtrl.text =
                                            "${loFactName.isNotEmpty ? loFactName : lOCity} -> $name";
                                      });
                                      // Auto-calc against ANY origin (factory OR city)
                                      final origName = loFactName.isNotEmpty
                                          ? loFactName
                                          : lOCity;
                                      final origPid = loFactPlaceId.isNotEmpty
                                          ? loFactPlaceId
                                          : lOCityPlaceId;
                                      if (origName.isNotEmpty &&
                                          name.isNotEmpty) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(SnackBar(
                                                  backgroundColor:
                                                      const Color(0xFF0EA5E9),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  duration: const Duration(
                                                      seconds: 2),
                                                  content: Row(children: const [
                                                    SizedBox(
                                                        width: 14,
                                                        height: 14,
                                                        child:
                                                            CircularProgressIndicator(
                                                                color: Color(
                                                                    0xFFF6FAFF),
                                                                strokeWidth:
                                                                    2)),
                                                    SizedBox(width: 10),
                                                    Text(
                                                        " Calculating distance via Google Maps...")
                                                  ])));
                                        }
                                        Future.delayed(
                                            const Duration(milliseconds: 400),
                                            () async {
                                          int ax = 6;
                                          try {
                                            if (selVeh != null) {
                                              ax = fleet
                                                  .firstWhere(
                                                      (v) => v.number == selVeh)
                                                  .axleCount;
                                            }
                                          } catch (_) {}
                                          final res =
                                              await RoutingEngine.calculate(
                                                  origin: origName,
                                                  destination: name,
                                                  axles: ax,
                                                  fuelEconomy:
                                                      currentFuelEconomy(),
                                                  dieselPrice:
                                                      currentDieselPrice(),
                                                  originPlaceId: origPid,
                                                  destPlaceId: pid,
                                                  originCity: lOCity,
                                                  destCity: lDCity);
                                          if (requestId != routeCalcRevision ||
                                              !mounted) {
                                            return;
                                          }
                                          final km = res['km'] as int? ?? 0;
                                          final preciseKm =
                                              (res['distanceKm'] as num?)
                                                      ?.toDouble() ??
                                                  km.toDouble();
                                          if (km > 0 && mounted) {
                                            setS(() {
                                              distCtrl.text =
                                                  ((res['distanceKm'] as num?)
                                                              ?.toDouble() ??
                                                          km.toDouble())
                                                      .toStringAsFixed(1);
                                              tolCtrl.text =
                                                  res['toll'].toString();
                                              dslCtrl.text =
                                                  res['diesel'].toString();
                                              calcDone = true;
                                            });
                                            // Show rich result with traffic info
                                            final routeSummary =
                                                res['routeSummary']
                                                        as String? ??
                                                    '';
                                            final durMin =
                                                res['durationMinutes']
                                                        as int? ??
                                                    0;
                                            final durTraffic =
                                                res['durationInTrafficMinutes']
                                                        as int? ??
                                                    0;
                                            final alts =
                                                res['alternatives'] as List? ??
                                                    [];
                                            final trafficDelay =
                                                durTraffic - durMin;
                                            String trafficNote = '';
                                            if (durMin > 0) {
                                              if (trafficDelay >= 15) {
                                                trafficNote =
                                                    ' | ⚠️ +${trafficDelay}min traffic delay';
                                              } else if (trafficDelay >= 5)
                                                trafficNote =
                                                    ' | 🚦 +${trafficDelay}min traffic';
                                              else
                                                trafficNote =
                                                    ' | ✅ Clear roads';
                                            }
                                            final altNote = alts.isNotEmpty
                                                ? '  ${alts.length} alt route${alts.length > 1 ? "s" : ""} available'
                                                : '';
                                            final routeNote =
                                                routeSummary.isNotEmpty
                                                    ? ' via $routeSummary'
                                                    : '';
                                            ScaffoldMessenger.of(context)
                                                .hideCurrentSnackBar();
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    backgroundColor:
                                                        Colors.green.shade700,
                                                    behavior: SnackBarBehavior
                                                        .floating,
                                                    duration: const Duration(
                                                        seconds: 6),
                                                    content: Text(
                                                        "✅ ${preciseKm.toStringAsFixed(1)} km$routeNote$trafficNote  |  Rs.${res['diesel']} diesel  |  Rs.${res['toll']} toll$altNote")));
                                            // If there are alternatives, show them in a dialog
                                            if (alts.isNotEmpty && mounted) {
                                              Future.delayed(
                                                  const Duration(
                                                      milliseconds: 200), () {
                                                if (!mounted) return;
                                                showDialog(
                                                    context: context,
                                                    builder:
                                                        (ctx) => AlertDialog(
                                                              shape: RoundedRectangleBorder(
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              18)),
                                                              title: Row(
                                                                  children: const [
                                                                    Icon(
                                                                        Icons
                                                                            .alt_route_rounded,
                                                                        color: Color(
                                                                            0xFF0EA5E9)),
                                                                    SizedBox(
                                                                        width:
                                                                            8),
                                                                    Text(
                                                                        'Alternative Routes',
                                                                        style: TextStyle(
                                                                            fontWeight:
                                                                                FontWeight.w900,
                                                                            fontSize: 16)),
                                                                  ]),
                                                              content: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    // Best route
                                                                    _routeOptionTile(
                                                                        ctx,
                                                                        'Fastest in Current Traffic (Selected)',
                                                                        preciseKm,
                                                                        durTraffic,
                                                                        routeSummary,
                                                                        const Color(
                                                                            0xFF10B981),
                                                                        isSelected:
                                                                            true,
                                                                        onTap: () =>
                                                                            Navigator.pop(ctx)),
                                                                    const Divider(),
                                                                    // Alternatives
                                                                    ...alts
                                                                        .take(2)
                                                                        .map(
                                                                            (alt) {
                                                                      final altKm = (alt['distanceKm'] as num?)
                                                                              ?.toDouble() ??
                                                                          (alt['km'] as int)
                                                                              .toDouble();
                                                                      final altDur = alt['durationTrafficMin']
                                                                              as int? ??
                                                                          alt['durationMin']
                                                                              as int? ??
                                                                          0;
                                                                      final altSummary =
                                                                          alt['summary'] as String? ??
                                                                              '';
                                                                      return _routeOptionTile(
                                                                          ctx,
                                                                          'Alternative',
                                                                          altKm,
                                                                          altDur,
                                                                          altSummary,
                                                                          const Color(
                                                                              0xFF0EA5E9),
                                                                          onTap:
                                                                              () {
                                                                        setS(
                                                                            () {
                                                                          distCtrl.text =
                                                                              altKm.toStringAsFixed(1);
                                                                          final altDiesel =
                                                                              ((altKm / currentFuelEconomy()) * currentDieselPrice()).round();
                                                                          dslCtrl.text =
                                                                              altDiesel.toString();
                                                                          tolCtrl
                                                                              .text = estimateToll(altKm,
                                                                                  ax)
                                                                              .round()
                                                                              .toString();
                                                                        });
                                                                        Navigator.pop(
                                                                            ctx);
                                                                      });
                                                                    }),
                                                                  ]),
                                                              actions: [
                                                                TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                            ctx),
                                                                    child: const Text(
                                                                        'Keep Recommended'))
                                                              ],
                                                            ));
                                              });
                                            }
                                          } else if (mounted) {
                                            showRouteFailure(res);
                                          }
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  CitySearchField(
                                      label: "Unloading City",
                                      icon: Icons.location_city,
                                      iconColor: Colors.red,
                                      initialValue: prefillDestCity ?? '',
                                      onCitySelected: (city, state, pid) {
                                        final requestId = ++routeCalcRevision;
                                        setS(() {
                                          resetRouteEstimate();
                                          lDCity = city;
                                          lDState = state;
                                          lDCityPlaceId = pid;
                                        });
                                        // Auto-calc if origin is already known
                                        final orig = loFactName.isNotEmpty
                                            ? loFactName
                                            : lOCity;
                                        final oPid = loFactPlaceId.isNotEmpty
                                            ? loFactPlaceId
                                            : lOCityPlaceId;
                                        if (orig.isNotEmpty) {
                                          Future.delayed(
                                              const Duration(milliseconds: 300),
                                              () async {
                                            int ax = 6;
                                            try {
                                              if (selVeh != null) {
                                                ax = fleet
                                                    .firstWhere((v) =>
                                                        v.number == selVeh)
                                                    .axleCount;
                                              }
                                            } catch (_) {}
                                            final res =
                                                await RoutingEngine.calculate(
                                                    origin: orig,
                                                    destination: city,
                                                    axles: ax,
                                                    fuelEconomy:
                                                        currentFuelEconomy(),
                                                    dieselPrice:
                                                        currentDieselPrice(),
                                                    originPlaceId: oPid,
                                                    destPlaceId: pid,
                                                    originCity: lOCity,
                                                    destCity: lDCity);
                                            if (requestId !=
                                                    routeCalcRevision ||
                                                !mounted) {
                                              return;
                                            }
                                            if ((res['km'] as int? ?? 0) > 0) {
                                              setS(() {
                                                distCtrl.text =
                                                    ((res['distanceKm'] as num?)
                                                                ?.toDouble() ??
                                                            (res['km'] as int)
                                                                .toDouble())
                                                        .toStringAsFixed(1);
                                                tolCtrl.text =
                                                    res['toll'].toString();
                                                dslCtrl.text =
                                                    res['diesel'].toString();
                                                calcDone = true;
                                              });
                                              if (mounted) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                        backgroundColor: Colors
                                                            .green.shade700,
                                                        behavior:
                                                            SnackBarBehavior
                                                                .floating,
                                                        duration:
                                                            const Duration(
                                                                seconds: 3),
                                                        content: Text(
                                                            " ${((res['distanceKm'] as num?)?.toDouble() ?? (res['km'] as int).toDouble()).toStringAsFixed(1)} km  |  Rs.${res['diesel']} diesel  |  Rs.${res['toll']} toll")));
                                              }
                                            } else {
                                              showRouteFailure(res);
                                            }
                                          });
                                        }
                                      }),
                                  if (lDState.isNotEmpty)
                                    Padding(
                                        padding: const EdgeInsets.only(
                                            top: 4, left: 4),
                                        child: Text(lDState,
                                            style: TextStyle(
                                                color: Colors.red[700],
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700))),
                                ])),
                        const SizedBox(height: 10),
                        TextField(
                            style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                            controller: rCtrl,
                            decoration: InputDecoration(
                                labelText: "Full Route Description",
                                prefixIcon: const Icon(Icons.route, size: 16),
                                filled: true,
                                fillColor: const Color(0xFFF6FAFF),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF0EA5E9))),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF0EA5E9))),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF0EA5E9), width: 2)))),
                        const SizedBox(height: 12),

                        // Vehicle + Driver
                        Row(children: [
                          // ── Vehicle field ──────────────────────────────
                          Expanded(
                              child: own == VehicleOwnership.self &&
                                      fleet.isNotEmpty
                                  ? DropdownButtonFormField<String>(
                                      style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500),
                                      isExpanded: true,
                                      initialValue: fleet
                                              .map((v) => v.number)
                                              .toSet()
                                              .contains(selVeh)
                                          ? selVeh
                                          : (fleet.isNotEmpty
                                              ? fleet.first.number
                                              : null),
                                      decoration: InputDecoration(
                                          labelText: "Fleet Vehicle",
                                          prefixIcon: const Icon(
                                              Icons.local_shipping_rounded,
                                              size: 18,
                                              color: Color(0xFF0EA5E9)),
                                          filled: true,
                                          fillColor: const Color(0xFFF6FAFF),
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                  color: Color(0xFF0EA5E9))),
                                          enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFF0EA5E9))),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2))),
                                      items: fleet.map((v) => v.number).toSet().map((n) => DropdownMenuItem<String>(value: n, child: Text(n, overflow: TextOverflow.ellipsis))).toList(),
                                      onChanged: (v) => setS(() {
                                            selVeh = v;
                                            vCtrl.text = v ?? '';
                                            autoCalc();
                                          }))
                                  : TextField(style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w500), controller: vCtrl, textCapitalization: TextCapitalization.characters, decoration: InputDecoration(labelText: own == VehicleOwnership.self ? "Vehicle No. (add fleet first)" : "Market Vehicle No.", prefixIcon: const Icon(Icons.local_shipping_rounded, size: 18, color: Color(0xFF0EA5E9)), filled: true, fillColor: const Color(0xFFF6FAFF), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0EA5E9))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0EA5E9))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2))))),
                          const SizedBox(width: 10),
                          // ── Driver field ───────────────────────────────
                          if (own == VehicleOwnership.self ||
                              own == VehicleOwnership.market)
                            Expanded(
                                child: drivers.isNotEmpty
                                    ? DropdownButtonFormField<String>(
                                        style: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500),
                                        isExpanded: true,
                                        initialValue: drivers
                                                .map((d) => d.name)
                                                .contains(selDrv)
                                            ? selDrv
                                            : null,
                                        hint: const Text("Assign Driver",
                                            style: TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF64748B))),
                                        decoration: InputDecoration(
                                            labelText: "Assign Driver",
                                            prefixIcon: const Icon(
                                                Icons.person_rounded,
                                                size: 18,
                                                color: Color(0xFF0EA5E9)),
                                            filled: true,
                                            fillColor: const Color(0xFFF6FAFF),
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                    color: Color(0xFF0EA5E9))),
                                            enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                borderSide: const BorderSide(
                                                    color: Color(0xFF0EA5E9))),
                                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2))),
                                        items: drivers
                                            .map((d) => DropdownMenuItem<String>(
                                                  value: d.name,
                                                  enabled: !d.isBlacklisted,
                                                  child: Row(children: [
                                                    if (d.isBlacklisted) ...[
                                                      const Icon(
                                                          Icons.block_rounded,
                                                          size: 14,
                                                          color: Color(
                                                              0xFFEF4444)),
                                                      const SizedBox(width: 4),
                                                    ],
                                                    Flexible(
                                                        child: Text(
                                                      d.isBlacklisted
                                                          ? '${d.name} (Blacklisted)'
                                                          : d.name,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: d.isBlacklisted
                                                            ? const Color(
                                                                0xFFEF4444)
                                                            : null,
                                                        fontStyle: d
                                                                .isBlacklisted
                                                            ? FontStyle.italic
                                                            : null,
                                                      ),
                                                    )),
                                                  ]),
                                                ))
                                            .toList(),
                                        onChanged: (v) {
                                          final driver = drivers.firstWhere(
                                              (d) => d.name == v,
                                              orElse: () => drivers.first);
                                          if (driver.isBlacklisted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                              backgroundColor:
                                                  const Color(0xFFEF4444),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              content: Text(
                                                  '${driver.name} is blacklisted. Cannot assign.',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12)),
                                            ));
                                            return;
                                          }
                                          setS(() {
                                            selDrv = v;
                                            drvCtrl.text = v ?? '';
                                          });
                                        })
                                    : TextField(style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w500), controller: drvCtrl, decoration: InputDecoration(labelText: "Driver Name", prefixIcon: const Icon(Icons.person_rounded, size: 18, color: Color(0xFF0EA5E9)), filled: true, fillColor: const Color(0xFFF6FAFF), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0EA5E9))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0EA5E9))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2))))),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: TextField(
                                  style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                  controller: ewCtrl,
                                  decoration: InputDecoration(
                                      labelText: "E-Way Bill No.",
                                      filled: true,
                                      fillColor: const Color(0xFFF6FAFF),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9))),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9))),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9),
                                              width: 2))))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: StatefulBuilder(builder: (ctx, setMat) {
                            final vehicleType = selVeh != null
                                ? (fleet
                                    .firstWhere((v) => v.number == selVeh,
                                        orElse: () => fleet.first)
                                    .type)
                                : (prefillVehicleType ?? 'SS Tanker');
                            final materials =
                                getMaterialsForVehicle(vehicleType);
                            final currentMat = matCtrl.text;
                            return DropdownButtonFormField<String>(
                                style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                                isExpanded: true,
                                initialValue: materials.contains(currentMat)
                                    ? currentMat
                                    : null,
                                hint: Text(currentMat.isNotEmpty ? currentMat : "Select Material",
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B))),
                                decoration: InputDecoration(
                                    labelText: "Material",
                                    prefixIcon: const Icon(Icons.science,
                                        color: Color(0xFF8B5CF6), size: 18),
                                    filled: true,
                                    fillColor: const Color(0xFFF6FAFF),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF0EA5E9))),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF0EA5E9))),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF0EA5E9),
                                            width: 2))),
                                items: materials
                                    .map((m) => DropdownMenuItem(
                                        value: m,
                                        child: Text(m,
                                            overflow: TextOverflow.ellipsis)))
                                    .toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    matCtrl.text = v;
                                    setMat(() {});
                                  }
                                });
                          })),
                        ]),
                        const SizedBox(height: 10),
                        // Material Invoice Number
                        TextField(
                            style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                            controller: invCtrl,
                            decoration: InputDecoration(
                                labelText: "Material Invoice Number (optional)",
                                prefixIcon: const Icon(Icons.receipt_outlined,
                                    size: 16),
                                filled: true,
                                fillColor: const Color(0xFFF6FAFF),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF0EA5E9))),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF0EA5E9))),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF0EA5E9), width: 2)))),
                        const SizedBox(height: 12),
                        // Part Load Section
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("Part Load Items",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: Color(0xFF0F172A))),
                              TextButton.icon(
                                onPressed: () {
                                  final nameC = TextEditingController();
                                  final invNoC = TextEditingController();
                                  final wtC = TextEditingController();
                                  String unit = "MT";
                                  showDialog(
                                      context: context,
                                      builder: (ctx2) => StatefulBuilder(
                                          builder: (ctx2, setD) => AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16)),
                                                title: const Text(
                                                    "Add Part Load Item",
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 15)),
                                                content: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      TextField(
                                                          style: const TextStyle(
                                                              color: Color(
                                                                  0xFFF6FAFF),
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500),
                                                          controller: nameC,
                                                          decoration: InputDecoration(
                                                              labelText:
                                                                  "Material Name *",
                                                              filled: true,
                                                              fillColor: const Color(
                                                                  0xFF115E59),
                                                              border: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                          10),
                                                                  borderSide:
                                                                      const BorderSide(
                                                                          color: Color(
                                                                              0xFF0F766E))),
                                                              enabledBorder: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                          10),
                                                                  borderSide:
                                                                      const BorderSide(
                                                                          color: Color(0xFF0EA5E9))),
                                                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2)))),
                                                      const SizedBox(
                                                          height: 10),
                                                      TextField(
                                                          style: const TextStyle(
                                                              color: Color(
                                                                  0xFFF6FAFF),
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500),
                                                          controller: invNoC,
                                                          decoration: InputDecoration(
                                                              labelText:
                                                                  "Invoice Number",
                                                              filled: true,
                                                              fillColor: const Color(
                                                                  0xFF115E59),
                                                              border: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                          10),
                                                                  borderSide:
                                                                      const BorderSide(
                                                                          color: Color(
                                                                              0xFF0F766E))),
                                                              enabledBorder: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                          10),
                                                                  borderSide:
                                                                      const BorderSide(
                                                                          color: Color(0xFF0EA5E9))),
                                                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2)))),
                                                      const SizedBox(
                                                          height: 10),
                                                      Row(children: [
                                                        Expanded(
                                                            child: TextField(
                                                                style: const TextStyle(
                                                                    color: Color(
                                                                        0xFFF6FAFF),
                                                                    fontSize:
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500),
                                                                controller: wtC,
                                                                keyboardType:
                                                                    TextInputType
                                                                        .number,
                                                                decoration: InputDecoration(
                                                                    labelText:
                                                                        "Weight *",
                                                                    filled:
                                                                        true,
                                                                    fillColor: const Color(
                                                                        0xFF115E59),
                                                                    border: OutlineInputBorder(
                                                                        borderRadius: BorderRadius.circular(
                                                                            10),
                                                                        borderSide: const BorderSide(
                                                                            color: Color(
                                                                                0xFF0F766E))),
                                                                    enabledBorder: OutlineInputBorder(
                                                                        borderRadius:
                                                                            BorderRadius.circular(10),
                                                                        borderSide: const BorderSide(color: Color(0xFF0EA5E9))),
                                                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2))))),
                                                        const SizedBox(
                                                            width: 8),
                                                        StatefulBuilder(
                                                            builder: (_, ss) => DropdownButton<
                                                                    String>(
                                                                value: unit,
                                                                items: [
                                                                  "MT",
                                                                  "KG",
                                                                  "L",
                                                                  "KL"
                                                                ]
                                                                    .map((u) => DropdownMenuItem(
                                                                        value:
                                                                            u,
                                                                        child: Text(
                                                                            u)))
                                                                    .toList(),
                                                                onChanged: (v) {
                                                                  ss(() =>
                                                                      unit =
                                                                          v!);
                                                                })),
                                                      ]),
                                                    ]),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(ctx2),
                                                      child:
                                                          const Text("Cancel")),
                                                  ElevatedButton(
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                              backgroundColor:
                                                                  const Color(
                                                                      0xFF0F172A)),
                                                      onPressed: () {
                                                        if (nameC
                                                                .text.isEmpty ||
                                                            wtC.text.isEmpty) {
                                                          return;
                                                        }
                                                        setS(() => partItems
                                                            .add(InvoiceItem(
                                                                materialName:
                                                                    nameC.text,
                                                                invoiceNo:
                                                                    invNoC.text,
                                                                weight: double
                                                                        .tryParse(wtC
                                                                            .text) ??
                                                                    0,
                                                                weightUnit:
                                                                    unit)));
                                                        Navigator.pop(ctx2);
                                                      },
                                                      child: const Text("Add",
                                                          style: TextStyle(
                                                              color: Color(
                                                                  0xFFF6FAFF)))),
                                                ],
                                              )));
                                },
                                icon: const Icon(Icons.add_circle_outline,
                                    size: 14),
                                label: const Text("Add Item",
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ]),
                        if (partItems.isNotEmpty)
                          ...partItems.asMap().entries.map((e) => Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.blue.shade100)),
                              child: Row(children: [
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(e.value.materialName,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: Color(0xFF0F172A))),
                                      Text(
                                          "${e.value.weight} ${e.value.weightUnit}${e.value.invoiceNo.isNotEmpty ? ' | Inv: ${e.value.invoiceNo}' : ''}",
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey)),
                                    ])),
                                IconButton(
                                    icon: const Icon(Icons.close,
                                        size: 16, color: Colors.red),
                                    onPressed: () =>
                                        setS(() => partItems.removeAt(e.key))),
                              ]))),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: StatefulBuilder(
                                  builder:
                                      (wCtx, wSt) => Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                TextField(
                                                    controller: wtCtrl,
                                                    keyboardType:
                                                        TextInputType.number,
                                                    onChanged: (_) =>
                                                        wSt(() {}),
                                                    decoration: InputDecoration(
                                                        labelText:
                                                            "Weight (Tons)",
                                                        prefixIcon: const Icon(
                                                            Icons.scale,
                                                            size: 18),
                                                        suffixIcon: prefillWeight !=
                                                                    null &&
                                                                prefillWeight >
                                                                    0 &&
                                                                (double.tryParse(wtCtrl.text) ??
                                                                        0) !=
                                                                    prefillWeight
                                                            ? const Tooltip(
                                                                message:
                                                                    "Weight differs from posted",
                                                                child: Icon(Icons.warning_amber,
                                                                    color: Colors
                                                                        .orange,
                                                                    size: 18))
                                                            : null,
                                                        filled: true,
                                                        fillColor:
                                                            const Color(0xFFF6FAFF),
                                                        labelStyle: const TextStyle(color: Color(0xFF22C55E), fontSize: 13, fontWeight: FontWeight.w500),
                                                        floatingLabelStyle: const TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.w800, fontSize: 12),
                                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0EA5E9))),
                                                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0EA5E9))),
                                                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2)))),
                                                if (prefillWeight != null &&
                                                    prefillWeight > 0)
                                                  Text(
                                                      "Posted: ${prefillWeight}T - edit if actual differs",
                                                      style: const TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.grey)),
                                              ]))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: DropdownButtonFormField<String>(
                                  style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                  initialValue: wUnit,
                                  decoration: InputDecoration(
                                      labelText: "Unit",
                                      filled: true,
                                      fillColor: const Color(0xFFF6FAFF),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9))),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9))),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9),
                                              width: 2))),
                                  items: ["MT", "KG", "LT", "TON"]
                                      .map((u) =>
                                          DropdownMenuItem(value: u, child: Text(u)))
                                      .toList(),
                                  onChanged: (v) => setS(() => wUnit = v!))),
                        ]),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                              child: TextField(
                                  style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                  controller: fCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                      labelText: "Total Freight Billed (Rs.) *",
                                      filled: true,
                                      fillColor: const Color(0xFFF6FAFF),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9))),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9))),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9),
                                              width: 2))))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: TextField(
                                  style: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500),
                                  controller: rcvdCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                      labelText: "Advance Received (Rs.)",
                                      filled: true,
                                      fillColor: const Color(0xFFF6FAFF),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9))),
                                      enabledBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9))),
                                      focusedBorder: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          borderSide: const BorderSide(
                                              color: Color(0xFF0EA5E9),
                                              width: 2))))),
                        ]),
                        const SizedBox(height: 12),

                        // GST
                        Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.indigo[50],
                                borderRadius: BorderRadius.circular(12)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("GST Configuration",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.indigo,
                                          fontSize: 13)),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Expanded(
                                        child: DropdownButtonFormField<GstType>(
                                            style: const TextStyle(
                                                color: Color(0xFF0F172A),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500),
                                            initialValue: gst,
                                            decoration: InputDecoration(
                                                labelText: "GST Type",
                                                isDense: true,
                                                filled: true,
                                                fillColor:
                                                    const Color(0xFFF6FAFF),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    borderSide: const BorderSide(
                                                        color:
                                                            Color(0xFF0EA5E9))),
                                                enabledBorder: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    borderSide: const BorderSide(
                                                        color:
                                                            Color(0xFF0EA5E9))),
                                                focusedBorder: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2))),
                                            items: const [
                                              DropdownMenuItem(
                                                  value: GstType.none,
                                                  child: Text("None")),
                                              DropdownMenuItem(
                                                  value: GstType.cgstSgst,
                                                  child: Text("CGST+SGST")),
                                              DropdownMenuItem(
                                                  value: GstType.igst,
                                                  child: Text("IGST"))
                                            ],
                                            onChanged: (v) => setS(() => gst = v!))),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: DropdownButtonFormField<double>(
                                            style: const TextStyle(
                                                color: Color(0xFF0F172A),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500),
                                            initialValue: gstRate,
                                            decoration: InputDecoration(
                                                labelText: "Rate %",
                                                isDense: true,
                                                filled: true,
                                                fillColor:
                                                    const Color(0xFFF6FAFF),
                                                border: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(
                                                        8),
                                                    borderSide: const BorderSide(
                                                        color:
                                                            Color(0xFF0EA5E9))),
                                                enabledBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(
                                                        8),
                                                    borderSide: const BorderSide(
                                                        color:
                                                            Color(0xFF0EA5E9))),
                                                focusedBorder: OutlineInputBorder(
                                                    borderRadius: BorderRadius.circular(8),
                                                    borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2))),
                                            items: [5.0, 12.0, 18.0, 28.0].map((r) => DropdownMenuItem(value: r, child: Text("$r%"))).toList(),
                                            onChanged: (v) => setS(() => gstRate = v!))),
                                  ]),
                                  SwitchListTile(
                                      dense: true,
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text(
                                          "Freight is GST-inclusive",
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600)),
                                      value: gstInc,
                                      activeThumbColor: Colors.indigo,
                                      onChanged: (v) => setS(() => gstInc = v)),
                                ])),
                        const SizedBox(height: 12),

                        // Deductions
                        Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Deductions",
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.red,
                                          fontSize: 13)),
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Expanded(child:
                                        StatefulBuilder(builder: (ctx, setTDS) {
                                      void recalcTDS() {
                                        setTDS(
                                            () {}); // trigger rebuild to show auto-amount
                                      }

                                      tdsCtrl.addListener(recalcTDS);
                                      final pct =
                                          double.tryParse(tdsCtrl.text) ?? 0;
                                      final freight =
                                          double.tryParse(fCtrl.text) ?? 0;
                                      final tdsAmt = freight * pct / 100;
                                      return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            TextField(
                                                controller: tdsCtrl,
                                                keyboardType:
                                                    const TextInputType
                                                        .numberWithOptions(
                                                        decimal: true),
                                                decoration: InputDecoration(
                                                    labelText: "TDS %",
                                                    hintText: "2 (for 2%)",
                                                    prefixIcon: const Icon(
                                                        Icons.percent,
                                                        size: 18),
                                                    filled: true,
                                                    fillColor:
                                                        const Color(0xFFF6FAFF),
                                                    border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8)))),
                                            if (tdsAmt > 0)
                                              Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 4, left: 4),
                                                  child: Text(
                                                      "TDS Amount: Rs.${tdsAmt.toStringAsFixed(0)}",
                                                      style: TextStyle(
                                                          fontSize: 11,
                                                          color:
                                                              Colors.red[700],
                                                          fontWeight: FontWeight
                                                              .w700))),
                                          ]);
                                    })),
                                    const SizedBox(width: 10),
                                    Expanded(
                                        child: TextField(
                                            style: const TextStyle(
                                                color: Color(0xFF0F172A),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500),
                                            controller: penCtrl,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                                labelText: "Penalties (Rs.)",
                                                filled: true,
                                                fillColor:
                                                    const Color(0xFFF6FAFF),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    borderSide: const BorderSide(
                                                        color:
                                                            Color(0xFF0EA5E9))),
                                                enabledBorder: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                    borderSide: const BorderSide(
                                                        color:
                                                            Color(0xFF0EA5E9))),
                                                focusedBorder: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                    borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2))))),
                                  ]),
                                ])),
                        const SizedBox(height: 12),

                        // Market payables
                        if (own == VehicleOwnership.market)
                          Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: Colors.purple.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Market Vehicle Payables",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.purple)),
                                    const SizedBox(height: 10),
                                    Row(children: [
                                      Expanded(
                                          child: TextField(
                                              style: const TextStyle(
                                                  color: Color(0xFF0F172A),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500),
                                              controller: mfCtrl,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                  labelText:
                                                      "Freight for Truck",
                                                  filled: true,
                                                  fillColor:
                                                      const Color(0xFFF6FAFF),
                                                  border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      borderSide:
                                                          const BorderSide(
                                                              color: Color(
                                                                  0xFF0F766E))),
                                                  enabledBorder: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      borderSide: const BorderSide(
                                                          color:
                                                              Color(0xFF0EA5E9))),
                                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2))))),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: TextField(
                                              style: const TextStyle(
                                                  color: Color(0xFF0F172A),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500),
                                              controller: maCtrl,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                  labelText: "Advance Paid",
                                                  filled: true,
                                                  fillColor:
                                                      const Color(0xFFF6FAFF),
                                                  border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      borderSide:
                                                          const BorderSide(
                                                              color: Color(
                                                                  0xFF0F766E))),
                                                  enabledBorder: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      borderSide: const BorderSide(
                                                          color:
                                                              Color(0xFF0EA5E9))),
                                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2)))))
                                    ]),
                                  ])),

                        // Self expenses
                        if (own == VehicleOwnership.self)
                          Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text("Self Vehicle Expenses",
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.orange,
                                                  fontSize: 14)),
                                          TextButton.icon(
                                            onPressed: () async {
                                              // Priority: factory placeId > factory name > city placeId > city name
                                              final origin =
                                                  loFactName.isNotEmpty
                                                      ? loFactName
                                                      : (lOCity.isNotEmpty
                                                          ? lOCity
                                                          : rCtrl.text
                                                              .split('->')
                                                              .first
                                                              .trim());
                                              final dest = ldFactName.isNotEmpty
                                                  ? ldFactName
                                                  : (lDCity.isNotEmpty
                                                      ? lDCity
                                                      : rCtrl.text
                                                          .split('->')
                                                          .last
                                                          .trim());
                                              final oPid =
                                                  loFactPlaceId.isNotEmpty
                                                      ? loFactPlaceId
                                                      : lOCityPlaceId;
                                              final dPid =
                                                  ldFactPlaceId.isNotEmpty
                                                      ? ldFactPlaceId
                                                      : lDCityPlaceId;
                                              if (origin.isEmpty) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(const SnackBar(
                                                        content: Text(
                                                            "Enter loading factory or city first")));
                                                return;
                                              }
                                              final srcHint = loFactPlaceId
                                                      .isNotEmpty
                                                  ? "factory GPS coordinates"
                                                  : lOCityPlaceId.isNotEmpty
                                                      ? "city coordinates"
                                                      : "name search";
                                              showDialog(
                                                  context: context,
                                                  barrierDismissible: false,
                                                  builder: (_) => Center(
                                                      child: Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(24),
                                                          decoration: BoxDecoration(
                                                              color: const Color(
                                                                  0xFFF6FAFF),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          16)),
                                                          child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                const CircularProgressIndicator(
                                                                    color: Color(
                                                                        0xFFF6FAFF)),
                                                                const SizedBox(
                                                                    height: 12),
                                                                Text(
                                                                    "Calculating via $srcHint...",
                                                                    style: const TextStyle(
                                                                        fontSize:
                                                                            13,
                                                                        fontWeight:
                                                                            FontWeight.w600))
                                                              ]))));
                                              int axles = 6;
                                              if (selVeh != null) {
                                                try {
                                                  axles = fleet
                                                      .firstWhere((v) =>
                                                          v.number == selVeh)
                                                      .axleCount;
                                                } catch (_) {}
                                              }
                                              final fe = currentFuelEconomy();
                                              final requestId =
                                                  ++routeCalcRevision;
                                              final res =
                                                  await RoutingEngine.calculate(
                                                      origin: origin,
                                                      destination: dest,
                                                      axles: axles,
                                                      fuelEconomy: fe,
                                                      dieselPrice:
                                                          currentDieselPrice(),
                                                      originPlaceId: oPid,
                                                      destPlaceId: dPid,
                                                      originCity: lOCity,
                                                      destCity: lDCity);
                                              if (!mounted ||
                                                  requestId !=
                                                      routeCalcRevision) {
                                                return;
                                              }
                                              if (mounted) {
                                                Navigator.pop(context);
                                              }
                                              final src =
                                                  res['source'] as String? ??
                                                      'offline';
                                              final km0 =
                                                  (res['km'] as int? ?? 0);
                                              if (km0 == 0) {
                                                setS(() => calcDone = false);
                                                final failureMessage = src ==
                                                        'no_api_key'
                                                    ? 'Configure a valid Maps API key to calculate routes.'
                                                    : src ==
                                                            'invalid_fuel_economy'
                                                        ? 'Enter a valid mileage greater than zero.'
                                                        : src ==
                                                                'invalid_diesel_price'
                                                            ? 'Enter a valid diesel price greater than zero.'
                                                            : src ==
                                                                    'missing_locations'
                                                                ? 'Select both origin and destination.'
                                                                : 'Could not calculate this route ($src). Check locations and Maps API access.';
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                        backgroundColor:
                                                            Colors.orange,
                                                        behavior:
                                                            SnackBarBehavior
                                                                .floating,
                                                        duration:
                                                            const Duration(
                                                                seconds: 5),
                                                        content: Text(
                                                            failureMessage)));
                                              } else {
                                                setS(() {
                                                  distCtrl.text =
                                                      (((res['distanceKm']
                                                                      as num?)
                                                                  ?.toDouble() ??
                                                              km0.toDouble()))
                                                          .toStringAsFixed(1);
                                                  tolCtrl.text =
                                                      res['toll'].toString();
                                                  dslCtrl.text =
                                                      res['diesel'].toString();
                                                  calcDone = true;
                                                });
                                                final srcLabel = src
                                                        .startsWith('google_')
                                                    ? 'Google Maps'
                                                    : src.startsWith('api_err')
                                                        ? 'API Error - $src'
                                                        : 'Smart Engine';
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                        backgroundColor:
                                                            Colors.green[800],
                                                        behavior:
                                                            SnackBarBehavior
                                                                .floating,
                                                        duration:
                                                            const Duration(
                                                                seconds: 4),
                                                        content: Text(
                                                            "${((res['distanceKm'] as num?)?.toDouble() ?? km0.toDouble()).toStringAsFixed(1)} km | Diesel: Rs.${res['diesel']} | $axles-axle FASTag Rs.${res['toll']} | $srcLabel")));
                                              }
                                            },
                                            icon: const Icon(
                                                Icons.auto_fix_high,
                                                size: 14,
                                                color: Colors.blueAccent),
                                            label: const Text(
                                                "Auto-calc from Maps",
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.blueAccent,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ),
                                        ]),
                                    const SizedBox(height: 8),
                                    if (calcDone)
                                      Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 6),
                                          margin:
                                              const EdgeInsets.only(bottom: 8),
                                          decoration: BoxDecoration(
                                              color: Colors.green
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: Colors.green[200]!)),
                                          child: Text(
                                              "OK Route calculated via ${AppConfig.googleMapsApiKey.isEmpty ? 'Smart Engine' : 'Google Maps'}",
                                              style: TextStyle(
                                                  color: Colors.green[800],
                                                  fontSize: 11,
                                                  fontWeight:
                                                      FontWeight.w700))),
                                    // ── Distance & Expenses ──────────────────────────────
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF0F9FF),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                            color: const Color(0xFF0EA5E9)
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: const [
                                              Icon(Icons.route_rounded,
                                                  size: 14,
                                                  color: Color(0xFF0EA5E9)),
                                              SizedBox(width: 6),
                                              Text('Distance & Expenses',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          Color(0xFF0EA5E9))),
                                              SizedBox(width: 6),
                                              Flexible(
                                                  child: Text(
                                                      'Enter km from Google Maps — open route before booking',
                                                      style: TextStyle(
                                                          fontSize: 10,
                                                          color: Color(
                                                              0xFF64748B)))),
                                            ]),
                                            const SizedBox(height: 10),
                                            Row(children: [
                                              Expanded(
                                                  child: TextField(
                                                controller: distCtrl,
                                                keyboardType:
                                                    TextInputType.number,
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w600),
                                                decoration: InputDecoration(
                                                    labelText: 'Distance (km)',
                                                    hintText: 'e.g. 420',
                                                    prefixIcon: const Icon(Icons.social_distance_rounded,
                                                        size: 16,
                                                        color:
                                                            Color(0xFF0EA5E9)),
                                                    filled: true,
                                                    fillColor: Colors.white,
                                                    border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(
                                                            8),
                                                        borderSide: const BorderSide(
                                                            color: Color(
                                                                0xFF0EA5E9))),
                                                    enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(
                                                            8),
                                                        borderSide: const BorderSide(
                                                            color: Color(
                                                                0xFF0EA5E9))),
                                                    focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2))),
                                              )),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                  child: TextField(
                                                controller: feCtrl,
                                                keyboardType:
                                                    TextInputType.number,
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w600),
                                                decoration: InputDecoration(
                                                    labelText: 'Mileage (km/L)',
                                                    hintText: 'e.g. 3.5',
                                                    prefixIcon: const Icon(Icons.local_gas_station_rounded,
                                                        size: 16,
                                                        color: Colors.orange),
                                                    filled: true,
                                                    fillColor: Colors.white,
                                                    border: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(
                                                            8),
                                                        borderSide: const BorderSide(
                                                            color: Color(
                                                                0xFF0EA5E9))),
                                                    enabledBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(
                                                            8),
                                                        borderSide: const BorderSide(
                                                            color: Color(
                                                                0xFF0EA5E9))),
                                                    focusedBorder: OutlineInputBorder(
                                                        borderRadius: BorderRadius.circular(8),
                                                        borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2))),
                                              )),
                                            ]),
                                            const SizedBox(height: 8),
                                            Row(children: [
                                              Expanded(
                                                  child: TextField(
                                                controller: dslRateCtrl,
                                                keyboardType:
                                                    TextInputType.number,
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w600),
                                                decoration: InputDecoration(
                                                    labelText:
                                                        'Diesel Rate (₹/L)',
                                                    hintText: '93',
                                                    prefixIcon: const Icon(
                                                        Icons.opacity_rounded,
                                                        size: 16,
                                                        color:
                                                            Colors.deepOrange),
                                                    filled: true,
                                                    fillColor: Colors.white,
                                                    border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                8),
                                                        borderSide:
                                                            const BorderSide(
                                                                color: Color(
                                                                    0xFF0EA5E9))),
                                                    enabledBorder: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                8),
                                                        borderSide:
                                                            const BorderSide(
                                                                color:
                                                                    Color(0xFF0EA5E9))),
                                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2))),
                                              )),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                  child: TextField(
                                                controller: dslCtrl,
                                                keyboardType:
                                                    TextInputType.number,
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w600),
                                                decoration: InputDecoration(
                                                    labelText:
                                                        'Diesel Cost (₹)',
                                                    hintText: 'Auto-calculated',
                                                    prefixIcon: const Icon(
                                                        Icons.calculate_rounded,
                                                        size: 16,
                                                        color:
                                                            Colors.deepOrange),
                                                    filled: true,
                                                    fillColor:
                                                        const Color(0xFFFFF7ED),
                                                    border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(8),
                                                        borderSide: BorderSide(
                                                            color: Colors
                                                                .deepOrange
                                                                .withValues(
                                                                    alpha:
                                                                        0.5))),
                                                    enabledBorder: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: Colors.deepOrange.withValues(alpha: 0.4))),
                                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.deepOrange, width: 2)),
                                                    helperText: '= Distance ÷ Mileage × Rate',
                                                    helperStyle: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                                              )),
                                            ]),
                                            const SizedBox(height: 8),
                                            Row(children: [
                                              Expanded(
                                                  child: TextField(
                                                controller: tolCtrl,
                                                keyboardType:
                                                    TextInputType.number,
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w600),
                                                decoration: InputDecoration(
                                                    labelText:
                                                        'FASTag / Toll (₹)',
                                                    hintText:
                                                        'Enter actual amount',
                                                    prefixIcon: const Icon(
                                                        Icons.toll_rounded,
                                                        size: 16,
                                                        color:
                                                            Color(0xFF7C3AED)),
                                                    filled: true,
                                                    fillColor: Colors.white,
                                                    border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                8),
                                                        borderSide: BorderSide(
                                                            color: const Color(
                                                                    0xFF7C3AED)
                                                                .withValues(
                                                                    alpha:
                                                                        0.5))),
                                                    enabledBorder: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(8),
                                                        borderSide: BorderSide(color: const Color(0xFF7C3AED).withValues(alpha: 0.5))),
                                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 2)),
                                                    helperText: 'Estimate auto-filled. Edit after trip.',
                                                    helperStyle: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                                              )),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                  child: TextField(
                                                controller: drvCtrl,
                                                keyboardType:
                                                    TextInputType.number,
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight:
                                                        FontWeight.w600),
                                                decoration: InputDecoration(
                                                    labelText:
                                                        'Driver Exp. (₹)',
                                                    hintText:
                                                        'Food, lodging...',
                                                    prefixIcon: const Icon(
                                                        Icons.person_rounded,
                                                        size: 16,
                                                        color:
                                                            Color(0xFF0F172A)),
                                                    filled: true,
                                                    fillColor: Colors.white,
                                                    border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                8),
                                                        borderSide:
                                                            const BorderSide(
                                                                color: Color(
                                                                    0xFF0EA5E9))),
                                                    enabledBorder: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                                8),
                                                        borderSide:
                                                            const BorderSide(
                                                                color:
                                                                    Color(0xFF0EA5E9))),
                                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0EA5E9), width: 2))),
                                              )),
                                            ]),
                                          ]),
                                    ),
                                  ])),
                        const SizedBox(height: 12),
                        TextField(
                            style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                            controller: notCtrl,
                            maxLines: 2,
                            decoration: InputDecoration(
                                labelText: "LR Notes / Remarks",
                                filled: true,
                                fillColor: const Color(0xFFF6FAFF),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF0EA5E9))),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF0EA5E9))),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF0EA5E9), width: 2)))),
                        const SizedBox(height: 22),
                        SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0EA5E9),
                                  foregroundColor: const Color(0xFFF6FAFF),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14)),
                              onPressed: userProfile.role == UserRole.driver
                                  ? null
                                  : () async {
                                      double f =
                                          double.tryParse(fCtrl.text) ?? 0;
                                      if (f <= 0) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    "Enter freight amount"),
                                                backgroundColor: Colors.red));
                                        return;
                                      }
                                      final vehCheck =
                                          own == VehicleOwnership.self
                                              ? (selVeh ?? '').trim()
                                              : vCtrl.text.trim();
                                      if (vehCheck.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    "Enter vehicle number — required for all trips"),
                                                backgroundColor: Colors.red));
                                        return;
                                      }
                                      if (drvCtrl.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    "Enter driver name — required for all trips"),
                                                backgroundColor: Colors.red));
                                        return;
                                      }
                                      double rc =
                                          double.tryParse(rcvdCtrl.text) ?? 0;
                                      double pen =
                                          double.tryParse(penCtrl.text) ?? 0;
                                      final tdsPct =
                                          double.tryParse(tdsCtrl.text) ?? 0;
                                      final double tds =
                                          (double.tryParse(fCtrl.text) ?? 0) *
                                              tdsPct /
                                              100;
                                      final parsedDist =
                                          double.tryParse(distCtrl.text.trim());
                                      if (distCtrl.text.trim().isNotEmpty &&
                                          (parsedDist == null ||
                                              !parsedDist.isFinite ||
                                              parsedDist < 0)) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    "Enter a valid non-negative route distance."),
                                                backgroundColor: Colors.red));
                                        return;
                                      }
                                      final parsedFe =
                                          double.tryParse(feCtrl.text.trim());
                                      if (own == VehicleOwnership.self &&
                                          (parsedDist ?? 0) > 0 &&
                                          (parsedFe == null ||
                                              !parsedFe.isFinite ||
                                              parsedFe <= 0)) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    "Enter a valid mileage greater than zero."),
                                                backgroundColor: Colors.red));
                                        return;
                                      }
                                      final parsedRate = double.tryParse(
                                          dslRateCtrl.text.trim());
                                      if (own == VehicleOwnership.self &&
                                          (parsedDist ?? 0) > 0 &&
                                          (parsedRate == null ||
                                              !parsedRate.isFinite ||
                                              parsedRate <= 0)) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    "Enter a valid diesel price greater than zero."),
                                                backgroundColor: Colors.red));
                                        return;
                                      }
                                      double dist = parsedDist ?? 0;
                                      double fe = parsedFe ?? 3.5;
                                      double wt =
                                          double.tryParse(wtCtrl.text) ?? 0;
                                      double dsl = 0,
                                          tol = 0,
                                          drv = 0,
                                          los = 0,
                                          mfr = 0,
                                          ma = 0;
                                      String finalVeh =
                                          own == VehicleOwnership.self
                                              ? (selVeh ?? "Unassigned")
                                              : vCtrl.text;
                                      if (own == VehicleOwnership.self) {
                                        dsl =
                                            double.tryParse(dslCtrl.text) ?? 0;
                                        if (dsl == 0 && dist > 0 && fe > 0) {
                                          dsl = (dist / fe) * (parsedRate ?? 0);
                                        }
                                        tol =
                                            double.tryParse(tolCtrl.text) ?? 0;
                                        drv =
                                            double.tryParse(drvCtrl.text) ?? 0;
                                        los =
                                            double.tryParse(losCtrl.text) ?? 0;
                                      } else {
                                        mfr = double.tryParse(mfCtrl.text) ?? 0;
                                        ma = double.tryParse(maCtrl.text) ?? 0;
                                      }

                                      final newL = TripLedger(
                                          id:
                                              "TRP${math.Random().nextInt(99999)}",
                                          date:
                                              "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
                                          partyName: pCtrl.text.isEmpty
                                              ? "Unknown Party"
                                              : pCtrl.text,
                                          vehicleNo: finalVeh,
                                          route: rCtrl.text.isNotEmpty
                                              ? rCtrl.text
                                              : "${loFactName.isNotEmpty ? loFactName : lOCity} -> ${ldFactName.isNotEmpty ? ldFactName : lDCity}",
                                          ownership: own,
                                          eWayBillNo: ewCtrl.text.isNotEmpty
                                              ? ewCtrl.text
                                              : "PENDING",
                                          materialName: matCtrl.text.isNotEmpty
                                              ? matCtrl.text
                                              : "General",
                                          loadingPoint: loFactName.isNotEmpty
                                              ? loFactName
                                              : lOCity,
                                          unloadingPoint: ldFactName.isNotEmpty
                                              ? ldFactName
                                              : lDCity,
                                          loadingState: lOState,
                                          unloadingState: lDState,
                                          consignorPhone: cpCtrl.text,
                                          consignorEmail: ceCtrl.text,
                                          consignorGstin: cgCtrl.text,
                                          freightBilled: f,
                                          paymentReceived: rc,
                                          diesel: dsl,
                                          toll: tol,
                                          driverExp: drv,
                                          materialLoss: los,
                                          marketTruckFreight: mfr,
                                          marketAdvancePaid: ma,
                                          penalties: pen,
                                          tdsDeduction: tds,
                                          distanceKm: dist,
                                          fuelEconomy: fe,
                                          driverName: selDrv,
                                          paymentTermsDays:
                                              int.tryParse(tmCtrl.text) ?? 30,
                                          lrNotes: prefillLoadId == null
                                              ? notCtrl.text
                                              : "BOOKED_LOAD:$prefillLoadId ${notCtrl.text}"
                                                  .trim(),
                                          gstType: gst,
                                          gstRate: gstRate,
                                          isGstInclusive: gstInc,
                                          weightTons: wt,
                                          weightUnit: wUnit,
                                          platformCommission: f * 0.02,
                                          consignorCommission: f * 0.02,
                                          materialInvoiceNo:
                                              invCtrl.text.trim(),
                                          invoiceItems: List<InvoiceItem>.from(
                                              partItems));

                                      outerSetState(() {
                                        final existingIdx = prefillLoadId ==
                                                null
                                            ? -1
                                            : ledgers.indexWhere((l) =>
                                                l.lrNotes.contains(
                                                    "BOOKED_LOAD:$prefillLoadId"));
                                        if (existingIdx >= 0) {
                                          ledgers[existingIdx] = TripLedger(
                                              id: ledgers[existingIdx].id,
                                              date: newL.date,
                                              partyName: newL.partyName,
                                              vehicleNo: newL.vehicleNo,
                                              route: newL.route,
                                              ownership: newL.ownership,
                                              eWayBillNo: newL.eWayBillNo,
                                              materialName: newL.materialName,
                                              loadingPoint: newL.loadingPoint,
                                              unloadingPoint:
                                                  newL.unloadingPoint,
                                              loadingState: newL.loadingState,
                                              unloadingState:
                                                  newL.unloadingState,
                                              consignorPhone:
                                                  newL.consignorPhone,
                                              consignorEmail:
                                                  newL.consignorEmail,
                                              consignorGstin:
                                                  newL.consignorGstin,
                                              freightBilled: newL.freightBilled,
                                              paymentReceived:
                                                  newL.paymentReceived,
                                              diesel: newL.diesel,
                                              toll: newL.toll,
                                              driverExp: newL.driverExp,
                                              materialLoss: newL.materialLoss,
                                              marketTruckFreight:
                                                  newL.marketTruckFreight,
                                              marketAdvancePaid:
                                                  newL.marketAdvancePaid,
                                              penalties: newL.penalties,
                                              tdsDeduction: newL.tdsDeduction,
                                              distanceKm: newL.distanceKm,
                                              fuelEconomy: newL.fuelEconomy,
                                              driverName: newL.driverName,
                                              paymentTermsDays:
                                                  newL.paymentTermsDays,
                                              lrNotes: newL.lrNotes,
                                              gstType: newL.gstType,
                                              gstRate: newL.gstRate,
                                              isGstInclusive:
                                                  newL.isGstInclusive,
                                              weightTons: newL.weightTons,
                                              weightUnit: newL.weightUnit,
                                              dispatchedAt: newL.dispatchedAt,
                                              estimatedArrival:
                                                  newL.estimatedArrival,
                                              isInTransit: newL.isInTransit,
                                              platformCommission:
                                                  newL.platformCommission,
                                              consignorCommission:
                                                  newL.consignorCommission,
                                              materialInvoiceNo:
                                                  newL.materialInvoiceNo,
                                              invoiceItems: newL.invoiceItems);
                                        } else {
                                          ledgers.insert(0, newL);
                                          subscription.tripsUsedThisMonth++;
                                        }
                                      });
                                      await _save();
                                      // Push cross-user sharing event to Firestore
                                      CrossUserSharingService.pushLoadEvent(
                                        ledgerId: newL.id,
                                        vehicleNo: newL.vehicleNo,
                                        route: newL.route,
                                        driverName:
                                            newL.driverName ?? selDrv ?? '',
                                        consignorPhone: newL.consignorPhone,
                                        status: 'dispatched',
                                        freightAmount: newL.freightBilled,
                                        materialName: newL.materialName,
                                      );
                                      Navigator.pop(ctx);
                                      // Auto-share docs if consignor email provided
                                      if (ceCtrl.text.isNotEmpty &&
                                          own == VehicleOwnership.self &&
                                          selVeh != null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                backgroundColor: Colors.blue,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                content: Text(
                                                    "OK Ledger saved! Vehicle docs auto-compiled for ${ceCtrl.text}")));
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                backgroundColor: Colors.green,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                content: Text(
                                                    "OK Ledger entry saved!")));
                                      }
                                    },
                              child: const Text("Save Dispatch Ledger",
                                  style: TextStyle(
                                      color: Color(0xFFFFFFFF),
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold)),
                            )),
                        const SizedBox(height: 30),
                      ])),
                )));
  }

  // Helper for TextDecoration in forms (avoiding typo)

  //
  Widget _buildFleet() =>
      ListView(padding: const EdgeInsets.all(16), children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Fleet Assets",
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A))),
          ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF6FAFF),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: _addVehicle,
              icon: const Icon(Icons.add, color: Color(0xFF0F172A), size: 16),
              label: const Text("Add Vehicle",
                  style: TextStyle(color: Color(0xFF0F172A), fontSize: 12)))
        ]),
        const SizedBox(height: 20),
        ...fleet.map((a) => Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 15)
                ]),
            child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ExpansionTile(
                    tilePadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                            color: Color(0xFF0EA5E9), shape: BoxShape.circle),
                        child: const Icon(Icons.local_shipping,
                            color: Color(0xFFFFFFFF), size: 22)),
                    title: Text(a.number,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: Color(0xFF0F172A),
                            letterSpacing: 0.5)),
                    subtitle: Wrap(spacing: 4, runSpacing: 4, children: [
                      _chip(Icons.directions_car_outlined, a.type,
                          const Color(0xFF0EA5E9)),
                      _chip(Icons.settings_outlined, "${a.axleCount}ax",
                          const Color(0xFF0EA5E9)),
                      _chip(
                          Icons.scale_outlined,
                          a.payload.length > 6
                              ? a.payload.substring(0, 6)
                              : a.payload,
                          const Color(0xFF0EA5E9)),
                    ]),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      GestureDetector(
                          onTap: () {
                            final activeLedger = _visibleLedgers
                                .where((l) =>
                                    l.vehicleNo == a.number &&
                                    l.partyPending > 0)
                                .firstOrNull;
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => LiveTrackingScreen(
                                        route: activeLedger?.route ??
                                            "Active Route",
                                        vehicleNo: a.number,
                                        distanceKm:
                                            activeLedger?.distanceKm ?? 0,
                                        isLoaded:
                                            activeLedger?.isInTransit ?? false,
                                        materialName:
                                            activeLedger?.materialName ?? '',
                                        driverName:
                                            activeLedger?.driverName ?? '',
                                        tripId: activeLedger?.id ?? '',
                                        destination:
                                            activeLedger?.unloadingPoint ?? '',
                                        fuelEconomy:
                                            activeLedger?.fuelEconomy ?? 3.5,
                                        axles: fleet
                                                .where((v) =>
                                                    v.number ==
                                                    activeLedger?.vehicleNo)
                                                .firstOrNull
                                                ?.axleCount ??
                                            6)));
                          },
                          child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border:
                                      Border.all(color: Colors.green[200]!)),
                              child: Row(children: [
                                Icon(Icons.gps_fixed_rounded,
                                    size: 12, color: Colors.green[700]),
                                const SizedBox(width: 4),
                                Text("Track",
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.green[700],
                                        fontWeight: FontWeight.bold))
                              ]))),
                      const SizedBox(width: 6),
                      const Icon(Icons.expand_more),
                    ]),
                    children: [
                      Container(
                          padding: const EdgeInsets.all(20),
                          color: _cardBg,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Compliance vault
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("Compliance Vault",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF0F172A),
                                              fontSize: 13)),
                                      Text(
                                          "${a.docs.where((d) => d.isUploaded).length}/${a.docs.length} uploaded",
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: a.docs.every(
                                                      (d) => d.isUploaded)
                                                  ? Colors.green
                                                  : Colors.orange,
                                              fontWeight: FontWeight.bold))
                                    ]),
                                const SizedBox(height: 12),
                                ...a.docs.map((d) => Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                            color: d.isUploaded
                                                ? Colors.green[50]
                                                : Colors.orange[50],
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color: d.isUploaded
                                                    ? Colors.green[200]!
                                                    : Colors.orange[200]!)),
                                        child: Row(children: [
                                          Icon(
                                              d.isUploaded
                                                  ? Icons.check_circle
                                                  : Icons.warning_amber,
                                              color: d.isUploaded
                                                  ? Colors.green
                                                  : Colors.orange,
                                              size: 18),
                                          const SizedBox(width: 10),
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Text(d.name,
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 13)),
                                                Text(
                                                    d.isUploaded
                                                        ? "Expires: ${d.expiryDate}"
                                                        : "Not Uploaded",
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: d.isUploaded
                                                            ? Colors.grey
                                                            : Colors.orange))
                                              ])),
                                          Row(children: [
                                            if (d.isUploaded &&
                                                d.filePath.isNotEmpty)
                                              IconButton(
                                                  icon: const Icon(
                                                      Icons.visibility,
                                                      size: 18,
                                                      color: Colors.teal),
                                                  tooltip: "View Document",
                                                  onPressed: () =>
                                                      _viewFleetDoc(d)),
                                            IconButton(
                                                icon: const Icon(
                                                    Icons.camera_alt,
                                                    size: 18,
                                                    color: Colors.blue),
                                                tooltip: "Camera",
                                                onPressed: () =>
                                                    _uploadDocWithMethod(
                                                        d,
                                                        a,
                                                        DocUploadMethod
                                                            .camera)),
                                            IconButton(
                                                icon: const Icon(
                                                    Icons.upload_file,
                                                    size: 18,
                                                    color: Colors.indigo),
                                                tooltip: "Upload File",
                                                onPressed: () =>
                                                    _uploadDocWithMethod(d, a,
                                                        DocUploadMethod.file)),
                                          ]),
                                        ])))),

                                // Batteries
                                Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text("Battery Records",
                                          style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF0F172A),
                                              fontSize: 13)),
                                      TextButton.icon(
                                          icon: const Icon(Icons.add, size: 14),
                                          label: const Text("Add Battery"),
                                          onPressed: () => _addBattery(a))
                                    ]),
                                if (a.batteries.isEmpty)
                                  const Text("No battery records",
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 12)),
                                ...a.batteries.map((b) => Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                        color: Colors.yellow[50],
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.yellow[300]!)),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Text("${b.make} ${b.model}",
                                                    style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 13)),
                                                Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                    decoration: BoxDecoration(
                                                        color:
                                                            Colors.green[100],
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6)),
                                                    child: Text(
                                                        "${b.warrantyYears}yr Warranty",
                                                        style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors
                                                                .green[800],
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)))
                                              ]),
                                          const SizedBox(height: 4),
                                          Text("Serial: ${b.serialNo}",
                                              style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 11)),
                                          Text(
                                              "Bill No: ${b.billNo.isNotEmpty ? b.billNo : 'N/A'}",
                                              style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 11)),
                                          Text(
                                              "Purchase: ${b.purchaseDate} | Warranty till: ${b.warrantyExpiry}",
                                              style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 11)),
                                        ]))),

                                const SizedBox(height: 8),
                                Row(children: [
                                  Expanded(
                                      child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                              side: const BorderSide(
                                                  color: Color(0xFF0F172A))),
                                          onPressed: () => _editAsset(a),
                                          icon: const Icon(Icons.build,
                                              size: 16,
                                              color: Color(0xFF0F172A)),
                                          label: const Text("Edit Tyres",
                                              style: TextStyle(
                                                  color: Color(0xFF0F172A),
                                                  fontSize: 12)))),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.teal,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10))),
                                          onPressed: () => _sendVehicleDocs(a),
                                          icon: const Icon(Icons.send,
                                              size: 14,
                                              color: Color(0xFF0F172A)),
                                          label: const Text("Send Docs Bundle",
                                              style: TextStyle(
                                                  color: Color(0xFF0F172A),
                                                  fontSize: 12)))),
                                ]),
                              ]))
                    ])))),
      ]);

  // Simple upload confirmation dialog (no external package required)
  // ignore: unused_element
  void _showDocUploadDialog(BuildContext ctx, String docName) {
    final dateCtrl = TextEditingController();
    showDialog(
        context: ctx,
        builder: (c) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(children: [
                const Icon(Icons.check_circle_outline, color: Colors.green),
                const SizedBox(width: 8),
                Flexible(
                    child: Text("Upload $docName",
                        overflow: TextOverflow.ellipsis))
              ]),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Row(children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      SizedBox(width: 8),
                      Flexible(
                          child: Text(
                              "Document marked as uploaded. Enter expiry date below.",
                              style:
                                  TextStyle(fontSize: 12, color: Colors.green)))
                    ])),
                const SizedBox(height: 12),
                TextField(
                    style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    controller: dateCtrl,
                    decoration: InputDecoration(
                        labelText: "Expiry Date (DD/MM/YYYY)",
                        hintText: "e.g. 31/12/2026",
                        prefixIcon: const Icon(Icons.calendar_today, size: 18),
                        filled: true,
                        fillColor: const Color(0xFFF6FAFF),
                        labelStyle: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        floatingLabelStyle: const TextStyle(
                            color: Color(0xFF0EA5E9),
                            fontWeight: FontWeight.w800,
                            fontSize: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFF0EA5E9))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xFF0EA5E9))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Color(0xFF0EA5E9), width: 2)))),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text("Cancel")),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF6FAFF),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    onPressed: () {
                      Navigator.pop(c);
                      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          content: Text(
                              "OK $docName uploaded${dateCtrl.text.isNotEmpty ? ' - Expiry: ${dateCtrl.text}' : ''}!")));
                    },
                    child: const Text("Confirm",
                        style: TextStyle(color: Color(0xFF0F172A)))),
              ],
            ));
  }

  Future<void> _uploadDocWithMethod(
      FleetDoc doc, Asset asset, DocUploadMethod method) async {
    String? pickedPath;
    String? pickedName;
    String pickedMime = 'image/jpeg';
    Map<String, String> extracted = {};

    try {
      if (method == DocUploadMethod.camera) {
        final img = await ImagePicker().pickImage(
            source: ImageSource.camera,
            imageQuality: 95,
            maxWidth: 2048,
            maxHeight: 2048);
        if (img != null) {
          pickedPath = img.path;
          pickedName = img.name;
          pickedMime = 'image/jpeg';
        }
      } else {
        final res = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
            withData: false);
        if (res != null && res.files.isNotEmpty) {
          pickedPath = res.files.single.path;
          pickedName = res.files.single.name;
          pickedMime =
              pickedName.endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
        }
      }
    } catch (_) {}

    // Run OCR on picked image before showing dialog
    if (pickedPath != null && pickedMime.startsWith('image')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Row(children: [
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF0F172A))),
              SizedBox(width: 12),
              Text("Reading document...")
            ]),
            backgroundColor: Colors.indigo,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 8)));
      }
      extracted = await FirebaseService.extractDocumentText(pickedPath);
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }

    if (!mounted) return;

    // Pre-fill from OCR extraction, fall back to existing stored values
    final dateCtrl = TextEditingController(
        text: extracted['expiryDate'] ??
            (doc.expiryDate == 'Pending' ? '' : doc.expiryDate));
    final engineCtrl =
        TextEditingController(text: extracted['engineNo'] ?? doc.engineNo);
    final chassisCtrl =
        TextEditingController(text: extracted['chassisNo'] ?? doc.chassisNo);
    final regCtrl =
        TextEditingController(text: extracted['regNo'] ?? doc.regNo);
    final insurerCtrl =
        TextEditingController(text: extracted['insurer'] ?? doc.insurer);
    final remarksCtrl = TextEditingController(text: doc.remarks);
    final ownerCtrl =
        TextEditingController(text: extracted['ownerName'] ?? doc.ownerName);
    final wasOCRed = extracted.isNotEmpty && !extracted.containsKey('error');

    // Determine which extra fields to show based on doc type
    final isRC = doc.name.toLowerCase().contains('rc') ||
        doc.name.toLowerCase().contains('registration');
    final isIns = doc.name.toLowerCase().contains('insurance');

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              title: Row(children: [
                Icon(
                    pickedPath != null
                        ? Icons.check_circle
                        : Icons.edit_document,
                    color: pickedPath != null
                        ? Colors.green
                        : const Color(0xFFF6FAFF)),
                const SizedBox(width: 8),
                Flexible(
                    child: Text(doc.name,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis)),
              ]),
              content: SizedBox(
                  width: double.maxFinite,
                  child: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        // File chip
                        if (pickedPath != null)
                          Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.green.shade200)),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Icon(
                                          pickedMime == 'application/pdf'
                                              ? Icons.picture_as_pdf
                                              : Icons.image,
                                          color: Colors.green,
                                          size: 18),
                                      const SizedBox(width: 8),
                                      Flexible(
                                          child: Text(
                                              pickedName ?? 'File selected',
                                              style: const TextStyle(
                                                  color: Colors.green,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12),
                                              overflow: TextOverflow.ellipsis)),
                                    ]),
                                    if (wasOCRed)
                                      Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Row(children: [
                                            const Icon(Icons.auto_awesome,
                                                color: Colors.indigo, size: 13),
                                            const SizedBox(width: 4),
                                            Text(
                                                "${extracted.length} fields auto-read from document",
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.indigo,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                          ])),
                                  ]))
                        else
                          Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Text(
                                  "No file - fill details manually",
                                  style: TextStyle(
                                      color: Colors.amber, fontSize: 12))),
                        // Expiry date (always)
                        TextField(
                            style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                            controller: dateCtrl,
                            decoration: InputDecoration(
                                labelText: "Expiry Date (DD/MM/YYYY)",
                                hintText: "31/12/2026",
                                prefixIcon:
                                    const Icon(Icons.calendar_today, size: 18),
                                filled: true,
                                fillColor: const Color(0xFFF6FAFF),
                                labelStyle: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                                floatingLabelStyle: const TextStyle(
                                    color: Color(0xFF0EA5E9),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF0EA5E9))),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF0EA5E9))),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF0EA5E9), width: 2)))),
                        // RC-specific fields
                        if (isRC) ...[
                          const SizedBox(height: 10),
                          TextField(
                              style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                              controller: regCtrl,
                              decoration: InputDecoration(
                                  labelText: "Registration Number",
                                  hintText: "GJ-01-WT-1000",
                                  prefixIcon: const Icon(
                                      Icons.confirmation_number,
                                      size: 18),
                                  filled: true,
                                  fillColor: const Color(0xFFF6FAFF),
                                  labelStyle: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                  floatingLabelStyle: const TextStyle(
                                      color: Color(0xFF0EA5E9),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9),
                                          width: 2)))),
                          const SizedBox(height: 10),
                          TextField(
                              style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                              controller: engineCtrl,
                              decoration: InputDecoration(
                                  labelText: "Engine Number",
                                  hintText: "e.g. WO6EATG12345",
                                  prefixIcon:
                                      const Icon(Icons.settings, size: 18),
                                  filled: true,
                                  fillColor: const Color(0xFFF6FAFF),
                                  labelStyle: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                  floatingLabelStyle: const TextStyle(
                                      color: Color(0xFF0EA5E9),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9),
                                          width: 2)))),
                          const SizedBox(height: 10),
                          TextField(
                              style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                              controller: chassisCtrl,
                              decoration: InputDecoration(
                                  labelText: "Chassis / VIN Number",
                                  hintText: "17-char VIN",
                                  prefixIcon: const Icon(Icons.tag, size: 18),
                                  filled: true,
                                  fillColor: const Color(0xFFF6FAFF),
                                  labelStyle: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                  floatingLabelStyle: const TextStyle(
                                      color: Color(0xFF0EA5E9),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9),
                                          width: 2)))),
                          const SizedBox(height: 10),
                          TextField(
                              style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                              controller: ownerCtrl,
                              decoration: InputDecoration(
                                  labelText: "Owner Name",
                                  hintText: "As per RC",
                                  prefixIcon:
                                      const Icon(Icons.person, size: 18),
                                  filled: true,
                                  fillColor: const Color(0xFFF6FAFF),
                                  labelStyle: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                  floatingLabelStyle: const TextStyle(
                                      color: Color(0xFF0EA5E9),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9),
                                          width: 2)))),
                        ],
                        // Insurance-specific fields
                        if (isIns) ...[
                          const SizedBox(height: 10),
                          TextField(
                              style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                              controller: insurerCtrl,
                              decoration: InputDecoration(
                                  labelText: "Insurance Company",
                                  hintText: "e.g. New India Assurance",
                                  prefixIcon:
                                      const Icon(Icons.business, size: 18),
                                  filled: true,
                                  fillColor: const Color(0xFFF6FAFF),
                                  labelStyle: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                  floatingLabelStyle: const TextStyle(
                                      color: Color(0xFF0EA5E9),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9),
                                          width: 2)))),
                        ],
                        const SizedBox(height: 10),
                        TextField(
                            style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                            controller: remarksCtrl,
                            decoration: InputDecoration(
                                labelText: "Remarks (optional)",
                                hintText: "Policy no., notes...",
                                filled: true,
                                fillColor: const Color(0xFFF6FAFF),
                                labelStyle: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                                floatingLabelStyle: const TextStyle(
                                    color: Color(0xFF0EA5E9),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF0EA5E9))),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF0EA5E9))),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF0EA5E9), width: 2)))),
                      ]))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text("Cancel")),
                ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF6FAFF),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10)),
                    icon: const Icon(Icons.save,
                        color: Color(0xFF0F172A), size: 16),
                    label: const Text("Save",
                        style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.bold)),
                    onPressed: () {
                      setState(() {
                        doc.isUploaded = true;
                        doc.expiryDate =
                            dateCtrl.text.isEmpty ? "Valid" : dateCtrl.text;
                        if (pickedPath != null) {
                          doc.filePath = pickedPath;
                          doc.mimeType = pickedMime;
                        }
                        if (pickedName != null) doc.fileData = pickedName;
                        if (engineCtrl.text.isNotEmpty) {
                          doc.engineNo = engineCtrl.text;
                        }
                        if (chassisCtrl.text.isNotEmpty) {
                          doc.chassisNo = chassisCtrl.text;
                        }
                        if (regCtrl.text.isNotEmpty) doc.regNo = regCtrl.text;
                        if (insurerCtrl.text.isNotEmpty) {
                          doc.insurer = insurerCtrl.text;
                        }
                        if (ownerCtrl.text.isNotEmpty) {
                          doc.ownerName = ownerCtrl.text;
                        }
                        doc.remarks = remarksCtrl.text;
                        _upsertComplianceVaultItem(asset, doc);
                      });
                      _save();
                      Navigator.pop(c);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: Colors.green,
                          behavior: SnackBarBehavior.floating,
                          content: Text(
                              "OK ${doc.name} saved${pickedPath != null ? ' with file' : ''}!")));
                    }),
              ],
            ));
  }

  void _viewFleetDoc(FleetDoc doc) {
    if (doc.filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text("No file stored. Re-upload with camera or file picker."),
          behavior: SnackBarBehavior.floating));
      return;
    }
    final file = File(doc.filePath);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("File not found on device. Please re-upload."),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating));
      return;
    }
    showDialog(
        context: context,
        builder: (c) => Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: Text(doc.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15),
                                  overflow: TextOverflow.ellipsis)),
                          IconButton(
                              onPressed: () => Navigator.pop(c),
                              icon: const Icon(Icons.close)),
                        ])),
                const Divider(height: 1),
                if (doc.mimeType.startsWith('image'))
                  Container(
                      constraints: const BoxConstraints(maxHeight: 400),
                      child: InteractiveViewer(
                          child: Image.file(file, fit: BoxFit.contain)))
                else
                  Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(children: [
                        const Icon(Icons.picture_as_pdf,
                            size: 60, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(doc.fileData,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF6FAFF)),
                            onPressed: () async {
                              try {
                                await SharePlus.instance.share(ShareParams(
                                    files: [XFile(doc.filePath)],
                                    subject: doc.name));
                              } catch (_) {}
                            },
                            icon: const Icon(Icons.share,
                                color: Color(0xFF0F172A), size: 16),
                            label: const Text("Share / Open",
                                style: TextStyle(color: Color(0xFF0F172A)))),
                      ])),
                // Show extracted fields if any
                if (doc.engineNo.isNotEmpty ||
                    doc.chassisNo.isNotEmpty ||
                    doc.regNo.isNotEmpty ||
                    doc.insurer.isNotEmpty)
                  Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Extracted Info",
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    fontSize: 12)),
                            const SizedBox(height: 6),
                            if (doc.engineNo.isNotEmpty)
                              _infoRow("Engine No", doc.engineNo),
                            if (doc.chassisNo.isNotEmpty)
                              _infoRow("Chassis No (VIN)", doc.chassisNo),
                            if (doc.regNo.isNotEmpty)
                              _infoRow("Reg No", doc.regNo),
                            if (doc.insurer.isNotEmpty)
                              _infoRow("Insurer", doc.insurer),
                            if (doc.remarks.isNotEmpty)
                              _infoRow("Remarks", doc.remarks),
                          ])),
              ]),
            ));
  }

  Widget _infoRow(String label, String val) => Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 110,
            child: Text("$label:",
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600))),
        Expanded(
            child: Text(val,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A)))),
      ]));

  void _viewDriverDoc(DriverDoc doc) {
    if (doc.filePath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text("No file stored. Re-upload with camera or file picker."),
          behavior: SnackBarBehavior.floating));
      return;
    }
    final file = File(doc.filePath);
    showDialog(
        context: context,
        builder: (c) => Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(doc.label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, fontSize: 15)),
                          IconButton(
                              onPressed: () => Navigator.pop(c),
                              icon: const Icon(Icons.close)),
                        ])),
                const Divider(height: 1),
                if (doc.mimeType.startsWith('image') && file.existsSync())
                  Container(
                      constraints: const BoxConstraints(maxHeight: 350),
                      child: InteractiveViewer(
                          child: Image.file(file, fit: BoxFit.contain)))
                else
                  Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        Icon(
                            doc.mimeType == 'application/pdf'
                                ? Icons.picture_as_pdf
                                : Icons.image_not_supported,
                            size: 60,
                            color: Colors.red),
                        const SizedBox(height: 10),
                        Text(doc.fileName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF6FAFF)),
                            onPressed: () async {
                              try {
                                await SharePlus.instance.share(ShareParams(
                                    files: [XFile(doc.filePath)],
                                    subject: doc.label));
                              } catch (_) {}
                            },
                            icon: const Icon(Icons.share,
                                color: Color(0xFF0F172A), size: 16),
                            label: const Text("Share / Open",
                                style: TextStyle(color: Color(0xFF0F172A)))),
                      ])),
                if (doc.docNumber.isNotEmpty || doc.expiryDate.isNotEmpty)
                  Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10)),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (doc.docNumber.isNotEmpty)
                              _infoRow("ID Number", doc.docNumber),
                            if (doc.expiryDate.isNotEmpty)
                              _infoRow("Expiry", doc.expiryDate),
                            if (doc.uploadDate.isNotEmpty)
                              _infoRow("Uploaded", doc.uploadDate),
                          ])),
              ]),
            ));
  }

  void _addBattery(Asset asset) {
    final makeCtrl = TextEditingController();
    final modelCtrl = TextEditingController();
    final serialCtrl = TextEditingController();
    final billCtrl = TextEditingController();
    final purchCtrl = TextEditingController();
    final warrantExpCtrl = TextEditingController();
    double warrantYears = 1.0;
    showDialog(
        context: context,
        builder: (c) => StatefulBuilder(
            builder: (c2, setSt) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  title: const Text("Add Battery Record",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Expanded(
                          child: TextField(
                              style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                              controller: makeCtrl,
                              decoration: InputDecoration(
                                  labelText: "Make (e.g. Exide)",
                                  filled: true,
                                  fillColor: const Color(0xFFF6FAFF),
                                  labelStyle: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                  floatingLabelStyle: const TextStyle(
                                      color: Color(0xFF0EA5E9),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9),
                                          width: 2))))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                              controller: modelCtrl,
                              decoration: InputDecoration(
                                  labelText: "Model",
                                  filled: true,
                                  fillColor: const Color(0xFFF6FAFF),
                                  labelStyle: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                  floatingLabelStyle: const TextStyle(
                                      color: Color(0xFF0EA5E9),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9),
                                          width: 2)))))
                    ]),
                    const SizedBox(height: 10),
                    TextField(
                        style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                        controller: serialCtrl,
                        decoration: InputDecoration(
                            labelText: "Serial / Battery No. *",
                            filled: true,
                            fillColor: const Color(0xFFF6FAFF),
                            labelStyle: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                            floatingLabelStyle: const TextStyle(
                                color: Color(0xFF0EA5E9),
                                fontWeight: FontWeight.w800,
                                fontSize: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFF0EA5E9))),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFF0EA5E9))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Color(0xFF0EA5E9), width: 2)))),
                    const SizedBox(height: 10),
                    TextField(
                        style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                        controller: billCtrl,
                        decoration: InputDecoration(
                            labelText: "Bill No.",
                            filled: true,
                            fillColor: const Color(0xFFF6FAFF),
                            labelStyle: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 13,
                                fontWeight: FontWeight.w500),
                            floatingLabelStyle: const TextStyle(
                                color: Color(0xFF0EA5E9),
                                fontWeight: FontWeight.w800,
                                fontSize: 12),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFF0EA5E9))),
                            enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: Color(0xFF0EA5E9))),
                            focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: Color(0xFF0EA5E9), width: 2)))),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                          child: TextField(
                              style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                              controller: purchCtrl,
                              decoration: InputDecoration(
                                  labelText: "Purchase Date",
                                  filled: true,
                                  fillColor: const Color(0xFFF6FAFF),
                                  labelStyle: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                  floatingLabelStyle: const TextStyle(
                                      color: Color(0xFF0EA5E9),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9),
                                          width: 2))))),
                      const SizedBox(width: 10),
                      Expanded(
                          child: TextField(
                              style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                              controller: warrantExpCtrl,
                              decoration: InputDecoration(
                                  labelText: "Warranty Expiry",
                                  filled: true,
                                  fillColor: const Color(0xFFF6FAFF),
                                  labelStyle: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                  floatingLabelStyle: const TextStyle(
                                      color: Color(0xFF0EA5E9),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9),
                                          width: 2)))))
                    ]),
                    const SizedBox(height: 10),
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Warranty (Years):",
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          Text("${warrantYears.toStringAsFixed(0)} yr",
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900))
                        ]),
                    Slider(
                        value: warrantYears,
                        min: 0.5,
                        max: 5,
                        divisions: 9,
                        activeColor: const Color(0xFFF6FAFF),
                        label: "${warrantYears.toStringAsFixed(0)}yr",
                        onChanged: (v) => setSt(() => warrantYears = v)),
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text("Cancel")),
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF6FAFF)),
                        onPressed: () {
                          if (serialCtrl.text.isEmpty) return;
                          setState(() => asset.batteries.add(Battery(
                              make: makeCtrl.text,
                              model: modelCtrl.text,
                              serialNo: serialCtrl.text,
                              billNo: billCtrl.text,
                              purchaseDate: purchCtrl.text,
                              warrantyExpiry: warrantExpCtrl.text,
                              warrantyYears: warrantYears)));
                          _save();
                          Navigator.pop(c);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  content: Text("OK Battery record added!")));
                        },
                        child: const Text("Save",
                            style: TextStyle(color: Color(0xFF0F172A))))
                  ],
                )));
  }

  Future<void> _sendVehicleDocs(Asset a) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (_) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                      padding: const pw.EdgeInsets.all(16),
                      decoration: pw.BoxDecoration(
                          color: const PdfColor(0.04, 0.15, 0.35),
                          borderRadius: pw.BorderRadius.circular(8)),
                      child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text(userProfile.companyName.toUpperCase(),
                                      style: pw.TextStyle(
                                          fontSize: 16,
                                          fontWeight: pw.FontWeight.bold,
                                          color:
                                              const PdfColor(1.0, 1.0, 1.0))),
                                  pw.Text(userProfile.phone,
                                      style: const pw.TextStyle(
                                          fontSize: 9,
                                          color: PdfColor(0.7, 0.7, 0.8)))
                                ]),
                            pw.Text("VEHICLE DOCUMENT BUNDLE",
                                style: pw.TextStyle(
                                    fontSize: 11,
                                    fontWeight: pw.FontWeight.bold,
                                    color: const PdfColor(1.0, 1.0, 1.0))),
                          ])),
                  pw.SizedBox(height: 16),
                  pw.Text(a.number,
                      style: pw.TextStyle(
                          fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text("${a.type} - ${a.axleCount} Axles - ${a.payload}",
                      style: const pw.TextStyle(
                          fontSize: 11, color: PdfColor(0.4, 0.4, 0.4))),
                  pw.SizedBox(height: 16),
                  pw.Table(
                      border: pw.TableBorder.all(
                          color: const PdfColor(0.85, 0.85, 0.85), width: 0.8),
                      columnWidths: {
                        0: const pw.FlexColumnWidth(3),
                        1: const pw.FlexColumnWidth(2),
                        2: const pw.FlexColumnWidth(2)
                      },
                      children: [
                        pw.TableRow(
                            decoration: const pw.BoxDecoration(
                                color: PdfColor(0.05, 0.09, 0.16)),
                            children: [
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Text("Document",
                                      style: pw.TextStyle(
                                          color: const PdfColor(1.0, 1.0, 1.0),
                                          fontWeight: pw.FontWeight.bold))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Text("Status",
                                      style: pw.TextStyle(
                                          color: const PdfColor(1.0, 1.0, 1.0),
                                          fontWeight: pw.FontWeight.bold))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Text("Expiry",
                                      style: pw.TextStyle(
                                          color: const PdfColor(1.0, 1.0, 1.0),
                                          fontWeight: pw.FontWeight.bold)))
                            ]),
                        ...a.docs.map((d) => pw.TableRow(children: [
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Text(d.name)),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Text(
                                      d.isUploaded
                                          ? "OK Valid"
                                          : "Missing Missing",
                                      style: pw.TextStyle(
                                          color: d.isUploaded
                                              ? const PdfColor(0, 0.6, 0)
                                              : const PdfColor(0.8, 0, 0)))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(8),
                                  child: pw.Text(
                                      d.isUploaded ? d.expiryDate : "-"))
                            ])),
                      ]),
                  if (a.batteries.isNotEmpty) ...[
                    pw.SizedBox(height: 12),
                    pw.Text("Battery Records",
                        style: pw.TextStyle(
                            fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Table(
                        border: pw.TableBorder.all(
                            color: const PdfColor(0.85, 0.85, 0.85),
                            width: 0.8),
                        columnWidths: {
                          0: const pw.FlexColumnWidth(2),
                          1: const pw.FlexColumnWidth(2),
                          2: const pw.FlexColumnWidth(1.5),
                          3: const pw.FlexColumnWidth(1.5)
                        },
                        children: [
                          pw.TableRow(
                              decoration: const pw.BoxDecoration(
                                  color: PdfColor(0.9, 0.9, 0.9)),
                              children: [
                                "Make/Model",
                                "Serial No.",
                                "Bill No.",
                                "Warranty"
                              ]
                                  .map((h) => pw.Padding(
                                      padding: const pw.EdgeInsets.all(6),
                                      child: pw.Text(h,
                                          style: pw.TextStyle(
                                              fontWeight: pw.FontWeight.bold,
                                              fontSize: 9))))
                                  .toList()),
                          ...a.batteries.map((b) => pw.TableRow(children: [
                                pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text("${b.make} ${b.model}",
                                        style:
                                            const pw.TextStyle(fontSize: 9))),
                                pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(b.serialNo,
                                        style:
                                            const pw.TextStyle(fontSize: 9))),
                                pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(
                                        b.billNo.isNotEmpty ? b.billNo : 'N/A',
                                        style:
                                            const pw.TextStyle(fontSize: 9))),
                                pw.Padding(
                                    padding: const pw.EdgeInsets.all(6),
                                    child: pw.Text(
                                        "${b.warrantyYears}yr till ${b.warrantyExpiry}",
                                        style: const pw.TextStyle(fontSize: 9)))
                              ])),
                        ]),
                  ],
                ])));
    try {
      await Printing.sharePdf(
          bytes: await pdf.save(), filename: 'VehicleDocs_${a.number}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  // Indian commercial vehicle: tyre count -> axles
  // Front axle: 2 tyres (single). Rear axles: 4 tyres each (dual).
  // 6T=3ax, 10T=5ax, 12T=6ax (standard tanker), 14T=7ax, 16T=8ax, 18T=10ax, 22T=12ax
  int _tyresToAxles(int tyres) {
    if (tyres <= 4) return 2;
    if (tyres == 6) return 3;
    if (tyres == 8) return 4;
    if (tyres == 10) return 5;
    if (tyres == 12) return 6;
    if (tyres == 14) return 7;
    if (tyres == 16) return 8;
    if (tyres == 18) return 9;
    if (tyres == 20) return 10;
    if (tyres == 22) return 11;
    if (tyres == 24) return 12;
    // General formula: front axle has 2 tyres, each additional axle adds 4
    return ((tyres - 2) ~/ 4) + 1;
  }

  // Default tyres by vehicle type
  int _defaultTyres(String type) {
    switch (type) {
      case 'LCV':
        return 6;
      case 'SS Tanker':
      case 'MS Tanker':
        return 12; // 6-axle standard
      case 'Container':
      case 'Open Truck':
        return 10;
      case 'Trailer':
        return 18;
      case 'Reefer':
        return 10;
      default:
        return 12;
    }
  }

  void _addVehicle() {
    final numCtrl = TextEditingController();
    final tyCtrl = TextEditingController(text: "12");
    final axCtrl = TextEditingController(text: "6");
    final payCtrl = TextEditingController(text: "30 Ton");
    String vType = "SS Tanker";
    _addVehicleFuelType = "Diesel";

    showDialog(
        context: context,
        builder: (c) => StatefulBuilder(builder: (c2, setSt) {
              void onTyreChange() {
                final t = int.tryParse(tyCtrl.text) ?? 0;
                if (t > 0) {
                  axCtrl.text = _tyresToAxles(t).toString();
                  setSt(() {});
                }
              }

              tyCtrl.addListener(onTyreChange);

              final axles = int.tryParse(axCtrl.text) ?? 6;

              return AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: const Row(children: [
                  Icon(Icons.local_shipping, color: Color(0xFF0F172A)),
                  SizedBox(width: 8),
                  Text("Add New Vehicle",
                      style: TextStyle(fontWeight: FontWeight.w800))
                ]),
                content: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      TextField(
                          style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                          controller: numCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: InputDecoration(
                              labelText: "Vehicle Number *",
                              hintText: "GJ-01-WT-1234",
                              prefixIcon: const Icon(Icons.confirmation_number,
                                  size: 18),
                              filled: true,
                              fillColor: const Color(0xFFF6FAFF),
                              labelStyle: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                              floatingLabelStyle: const TextStyle(
                                  color: Color(0xFF0EA5E9),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF0EA5E9))),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF0EA5E9))),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF0EA5E9), width: 2)))),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                          style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                          initialValue: vType,
                          decoration: InputDecoration(
                              labelText: "Vehicle Type",
                              prefixIcon: const Icon(Icons.category, size: 18),
                              filled: true,
                              fillColor: const Color(0xFFF6FAFF),
                              labelStyle: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                              floatingLabelStyle: const TextStyle(
                                  color: Color(0xFF0EA5E9),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF0EA5E9))),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF0EA5E9))),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF0EA5E9), width: 2))),
                          items: [
                            "SS Tanker",
                            "MS Tanker",
                            "Container",
                            "Open Truck",
                            "Trailer",
                            "LCV",
                            "Reefer"
                          ]
                              .map((v) =>
                                  DropdownMenuItem(value: v, child: Text(v)))
                              .toList(),
                          onChanged: (v) {
                            setSt(() {
                              vType = v!;
                              tyCtrl.text = _defaultTyres(v).toString();
                              axCtrl.text =
                                  _tyresToAxles(_defaultTyres(v)).toString();
                            });
                          }),
                      const SizedBox(height: 12),
                      TextField(
                          style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 14,
                              fontWeight: FontWeight.w500),
                          controller: payCtrl,
                          decoration: InputDecoration(
                              labelText: "Payload Capacity",
                              hintText: "e.g. 30 Ton",
                              prefixIcon: const Icon(Icons.scale, size: 18),
                              filled: true,
                              fillColor: const Color(0xFFF6FAFF),
                              labelStyle: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                              floatingLabelStyle: const TextStyle(
                                  color: Color(0xFF0EA5E9),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF0EA5E9))),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF0EA5E9))),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF0EA5E9), width: 2)))),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: TextField(
                                style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                                controller: tyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                    labelText: "No. of Tyres",
                                    hintText: "12",
                                    prefixIcon:
                                        const Icon(Icons.circle, size: 16),
                                    filled: true,
                                    fillColor: const Color(0xFFF6FAFF),
                                    labelStyle: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500),
                                    floatingLabelStyle: const TextStyle(
                                        color: Color(0xFF0EA5E9),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF0EA5E9))),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF0EA5E9))),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF0EA5E9),
                                            width: 2))))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: TextField(
                                controller: axCtrl,
                                keyboardType: TextInputType.number,
                                readOnly: true,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A)),
                                decoration: InputDecoration(
                                    labelText: "Axles (auto)",
                                    prefixIcon: const Icon(Icons.linear_scale,
                                        size: 16),
                                    filled: true,
                                    fillColor: const Color(0xFFF6FAFF),
                                    labelStyle: const TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500),
                                    floatingLabelStyle: const TextStyle(
                                        color: Color(0xFF0EA5E9),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF0EA5E9))),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF0EA5E9))),
                                    focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                            color: Color(0xFF0EA5E9),
                                            width: 2))))),
                      ]),
                      const SizedBox(height: 8),
                      const SizedBox(height: 8),
                      // Fuel Type selector
                      StatefulBuilder(
                          builder: (_, ssFuel) => Column(children: [
                                DropdownButtonFormField<String>(
                                    initialValue: _addVehicleFuelType,
                                    decoration: InputDecoration(
                                        labelText: "Fuel Type",
                                        prefixIcon: const Icon(
                                            Icons.local_gas_station,
                                            size: 18),
                                        filled: true,
                                        fillColor: const Color(0xFFF6FAFF),
                                        labelStyle: const TextStyle(
                                            color: Color(0xFF0F172A),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500),
                                        floatingLabelStyle: const TextStyle(
                                            color: Color(0xFF22c55e),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12),
                                        border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: Color(0xFF22c55e))),
                                        enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: Color(0xFF22c55e))),
                                        focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: const BorderSide(
                                                color: Color(0xFF22c55e),
                                                width: 2))),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'Diesel',
                                          child: Text('⛽  Diesel')),
                                      DropdownMenuItem(
                                          value: 'CNG',
                                          child: Text('🟢  CNG (−25% CO₂)')),
                                      DropdownMenuItem(
                                          value: 'LNG',
                                          child: Text('🔵  LNG (−20% CO₂)')),
                                      DropdownMenuItem(
                                          value: 'Hybrid',
                                          child: Text('🔋  Hybrid (−15% CO₂)')),
                                      DropdownMenuItem(
                                          value: 'Electric',
                                          child: Text(
                                              '⚡  Electric EV (−80% CO₂)')),
                                      DropdownMenuItem(
                                          value: 'Hydrogen',
                                          child: Text(
                                              '💧  Hydrogen (near-zero CO₂)')),
                                    ],
                                    onChanged: (v) {
                                      ssFuel(() => _addVehicleFuelType = v!);
                                      setSt(() {});
                                    }),
                                if (_addVehicleFuelType != 'Diesel') ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                        color: Colors.green
                                            .withValues(alpha: 0.08),
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: Row(children: [
                                      const Icon(Icons.eco,
                                          color: Colors.green, size: 16),
                                      const SizedBox(width: 8),
                                      Expanded(
                                          child: Text(
                                              _addVehicleFuelType == 'Electric'
                                                  ? '⚡ EV: ~80% lower CO₂ — green priority on load board & Green Impact'
                                                  : _addVehicleFuelType ==
                                                          'Hydrogen'
                                                      ? '💧 Hydrogen: near-zero emissions — highest green badge'
                                                      : _addVehicleFuelType ==
                                                              'CNG'
                                                          ? '🟢 CNG: ~25% lower CO₂ vs diesel — preferred for urban loads'
                                                          : _addVehicleFuelType ==
                                                                  'LNG'
                                                              ? '🔵 LNG: ~20% lower CO₂ — ideal for long-haul'
                                                              : '🔋 Hybrid: ~15% lower CO₂ vs diesel',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.green,
                                                  fontWeight:
                                                      FontWeight.w600))),
                                    ]),
                                  ),
                                ],
                              ])),
                      // FASTag rate preview
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(children: [
                            const Icon(Icons.toll,
                                color: Colors.orange, size: 16),
                            const SizedBox(width: 8),
                            Text(
                                "FASTag: Rs.${(kTollPerAxlePerKm[axles] ?? 8.40).toStringAsFixed(2)}/km × ${(kNhFraction * 100).toStringAsFixed(0)}% NH (NHAI FY2024-25, $axles-axle)",
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w700)),
                          ])),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text("Cancel")),
                  ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF6FAFF),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(Icons.save,
                          color: Color(0xFF0F172A), size: 16),
                      label: const Text("Add Vehicle",
                          style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.bold)),
                      onPressed: () {
                        if (numCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Enter vehicle number"),
                                  backgroundColor: Colors.red));
                          return;
                        }
                        final tc = int.tryParse(tyCtrl.text) ?? 12;
                        final ac = int.tryParse(axCtrl.text) ?? 6;
                        setState(() => fleet.add(Asset(
                            id: "V${DateTime.now().millisecondsSinceEpoch}",
                            number: numCtrl.text.toUpperCase(),
                            type: vType,
                            payload:
                                payCtrl.text.isEmpty ? "30 Ton" : payCtrl.text,
                            tyreCount: tc,
                            axleCount: ac,
                            tyreSerials: List.filled(tc, ""),
                            batteries: [],
                            fuelType: _addVehicleFuelType,
                            docs: VehicleDocConfig.getRequiredDocs(vType)
                                .map((d) => FleetDoc(name: d))
                                .toList())));
                        _save();
                        Navigator.pop(c);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            content: Text(
                                "OK ${numCtrl.text.toUpperCase()} added - $ac axles, $tc tyres")));
                      }),
                ],
              );
            }));
  }

  void _editAsset(Asset asset) {
    final cs = List.generate(asset.tyreCount,
        (i) => TextEditingController(text: asset.tyreSerials[i]));
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text("Tyre Serials - ${asset.number}",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                content: SizedBox(
                    width: double.maxFinite,
                    child: SingleChildScrollView(
                        child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    childAspectRatio: 2.5,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10),
                            itemCount: asset.tyreCount,
                            itemBuilder: (_, i) => TextField(
                                controller: cs[i],
                                decoration: InputDecoration(
                                    labelText: "T${i + 1}",
                                    border: const OutlineInputBorder(),
                                    contentPadding:
                                        const EdgeInsets.all(8)))))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel")),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo),
                      onPressed: () {
                        setState(() {
                          for (int i = 0; i < asset.tyreCount; i++) {
                            asset.tyreSerials[i] = cs[i].text;
                          }
                        });
                        _save();
                        Navigator.pop(ctx);
                      },
                      child: const Text("Save",
                          style: TextStyle(color: Color(0xFF0F172A))))
                ]));
  }

  //
  Widget
      _buildDrivers() => ListView(padding: const EdgeInsets.all(16), children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("Driver Roster",
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A))),
              ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF6FAFF),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10))),
                  onPressed: _addDriver,
                  icon: const Icon(Icons.person_add,
                      color: Color(0xFF0F172A), size: 16),
                  label: const Text("Add Driver",
                      style: TextStyle(color: Color(0xFF0F172A), fontSize: 12)))
            ]),
            const SizedBox(height: 8),
            GestureDetector(
                onTap: _resyncAllDriversToPublic,
                child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.2))),
                    child: Row(children: [
                      const Icon(Icons.sync, color: Colors.blue, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(
                              "Sync drivers so they can log in to the app",
                              style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600))),
                      const Icon(Icons.arrow_forward_ios,
                          color: Colors.blue, size: 12),
                    ]))),
            const SizedBox(height: 12),
            if (drivers.isEmpty)
              const Center(
                  child: Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Column(children: [
                        Icon(Icons.group_off, size: 60, color: Colors.grey),
                        SizedBox(height: 12),
                        Text("No drivers added",
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 16))
                      ]))),
            ...drivers.map((d) => Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12)
                    ]),
                child: ExpansionTile(
                  tilePadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                      radius: 26,
                      backgroundColor:
                          d.isVerified ? Colors.green[50] : Colors.blue[50],
                      child: Stack(children: [
                        Text(d.name.isNotEmpty ? d.name[0].toUpperCase() : "D",
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: Color(0xFF0F172A))),
                        if (d.isVerified)
                          const Positioned(
                              bottom: 0,
                              right: 0,
                              child: Icon(Icons.verified,
                                  size: 14, color: Colors.green))
                      ])),
                  title: Row(children: [
                    Expanded(
                      child: Text(d.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: d.isBlacklisted
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF0F172A))),
                    ),
                    if (d.isVerifiedBadge)
                      Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFF3B82F6),
                                Color(0xFF1D4ED8)
                              ]),
                              borderRadius: BorderRadius.circular(6)),
                          child: const Text('✓',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900))),
                    if (d.isBlacklisted)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.block_rounded,
                            color: Color(0xFFEF4444), size: 16),
                      ),
                    // Delete driver (removes cloud data too — DPDP retention)
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Color(0xFF94A3B8), size: 20),
                      tooltip: 'Delete driver',
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (dc) => AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            title: const Text('Delete Driver'),
                            content: Text(
                                'Remove ${d.name} and their data from this app '
                                'and the shared lookup? This cannot be undone.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(dc, false),
                                  child: const Text('Cancel')),
                              ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFDC2626)),
                                  onPressed: () => Navigator.pop(dc, true),
                                  child: const Text('Delete',
                                      style: TextStyle(color: Colors.white))),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        await FirebaseService.deleteDriver(d);
                        if (!mounted) return;
                        setState(() {
                          drivers.removeWhere((x) => x.id == d.id);
                        });
                        _save();
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${d.name} deleted')));
                      },
                    ),
                  ]),
                  subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.phone,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                                fontSize: 13)),
                        const SizedBox(height: 4),
                        // Trust score bar
                        Row(children: [
                          SizedBox(
                            width: 80,
                            height: 6,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: d.trustPoints / 100,
                                backgroundColor: Colors.grey.shade200,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(d.trustColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                              child: Text(
                                  '${d.trustPoints}/100 · ${d.trustLabel}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: d.trustColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700))),
                          if (d.violations.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Text('· ${d.violations.length}⚠',
                                style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ]),
                        const SizedBox(height: 4),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          if (d.aadharNum.isNotEmpty)
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Text("Aadhaar OK",
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.blue[800],
                                        fontWeight: FontWeight.bold))),
                          if (d.dlNum.isNotEmpty)
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Text("DL OK",
                                    style: TextStyle(
                                        fontSize: 9,
                                        color: Colors.green[800],
                                        fontWeight: FontWeight.bold))),
                        ]),
                        // Blacklist warning
                        if (d.isBlacklisted) ...[
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                                color: const Color(0xFFEF4444)
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFFEF4444)
                                        .withValues(alpha: 0.3))),
                            child: Row(children: [
                              const Icon(Icons.warning_rounded,
                                  color: Color(0xFFEF4444), size: 12),
                              const SizedBox(width: 5),
                              Expanded(
                                  child: Text(
                                      'Blacklisted: ${d.blacklistReason.isNotEmpty ? d.blacklistReason : "Contact admin"}',
                                      style: const TextStyle(
                                          color: Color(0xFFEF4444),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis)),
                            ]),
                          ),
                        ],
                      ]),
                  trailing: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 80),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text("Balance",
                                style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.bold)),
                            FittedBox(
                                child: Text(
                                    "Rs.${d.balance.toStringAsFixed(0)}",
                                    style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 15,
                                        color: d.balance >= 0
                                            ? Colors.green
                                            : Colors.red)))
                          ])),
                  children: [
                    Container(
                        padding: const EdgeInsets.all(16),
                        color: _cardBg,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("KYC Documents",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13,
                                      color: Color(0xFF0F172A))),
                              const SizedBox(height: 10),
                              if (d.selfieDocPath.isNotEmpty ||
                                  d.aadhaarDocPath.isNotEmpty ||
                                  d.dlDocPath.isNotEmpty) ...[
                                Container(
                                    padding: const EdgeInsets.all(10),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                        color:
                                            Colors.teal.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.teal
                                                .withValues(alpha: 0.2))),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text('Driver Uploaded',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.teal)),
                                          const SizedBox(height: 6),
                                          Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: [
                                                if (d.selfieDocPath.isNotEmpty)
                                                  GestureDetector(
                                                      onTap: () => showDialog(
                                                          context: context,
                                                          builder: (_) =>
                                                              Dialog(
                                                                  shape: RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              16)),
                                                                  child: Column(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        Padding(
                                                                            padding:
                                                                                const EdgeInsets.all(12),
                                                                            child: Row(children: [
                                                                              const Text('Selfie', style: TextStyle(fontWeight: FontWeight.w900)),
                                                                              const Spacer(),
                                                                              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
                                                                            ])),
                                                                        ClipRRect(
                                                                            borderRadius:
                                                                                const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                                                                            child: Image.file(File(d.selfieDocPath), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(24), child: Text('Preview unavailable'))))
                                                                      ]))),
                                                      child: Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4),
                                                          decoration: BoxDecoration(
                                                              color: Colors.green
                                                                  .withValues(
                                                                      alpha:
                                                                          0.1),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                          child: const Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                    Icons
                                                                        .camera_alt,
                                                                    size: 12,
                                                                    color: Colors
                                                                        .green),
                                                                SizedBox(
                                                                    width: 4),
                                                                Text('Selfie',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        color: Colors
                                                                            .green,
                                                                        fontWeight:
                                                                            FontWeight.w700))
                                                              ]))),
                                                if (d.aadhaarDocPath.isNotEmpty)
                                                  GestureDetector(
                                                      onTap: () => showDialog(
                                                          context: context,
                                                          builder: (_) =>
                                                              Dialog(
                                                                  shape: RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              16)),
                                                                  child: Column(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        Padding(
                                                                            padding:
                                                                                const EdgeInsets.all(12),
                                                                            child: Row(children: [
                                                                              const Text('Aadhaar', style: TextStyle(fontWeight: FontWeight.w900)),
                                                                              const Spacer(),
                                                                              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
                                                                            ])),
                                                                        ClipRRect(
                                                                            borderRadius:
                                                                                const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                                                                            child: Image.file(File(d.aadhaarDocPath), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(24), child: Text('Preview unavailable'))))
                                                                      ]))),
                                                      child: Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4),
                                                          decoration: BoxDecoration(
                                                              color: Colors.blue
                                                                  .withValues(
                                                                      alpha:
                                                                          0.1),
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                          child: const Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                    Icons
                                                                        .credit_card,
                                                                    size: 12,
                                                                    color: Colors
                                                                        .blue),
                                                                SizedBox(
                                                                    width: 4),
                                                                Text('Aadhaar',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        color: Colors
                                                                            .blue,
                                                                        fontWeight:
                                                                            FontWeight.w700))
                                                              ]))),
                                                if (d.dlDocPath.isNotEmpty)
                                                  GestureDetector(
                                                      onTap: () => showDialog(
                                                          context: context,
                                                          builder: (_) =>
                                                              Dialog(
                                                                  shape: RoundedRectangleBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              16)),
                                                                  child: Column(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .min,
                                                                      children: [
                                                                        Padding(
                                                                            padding:
                                                                                const EdgeInsets.all(12),
                                                                            child: Row(children: [
                                                                              const Text('DL', style: TextStyle(fontWeight: FontWeight.w900)),
                                                                              const Spacer(),
                                                                              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
                                                                            ])),
                                                                        ClipRRect(
                                                                            borderRadius:
                                                                                const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                                                                            child: Image.file(File(d.dlDocPath), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(24), child: Text('Preview unavailable'))))
                                                                      ]))),
                                                      child: Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 4),
                                                          decoration: BoxDecoration(
                                                              color: Colors
                                                                  .orange
                                                                  .withValues(
                                                                      alpha:
                                                                          0.1),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                      8)),
                                                          child: const Row(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Icon(
                                                                    Icons
                                                                        .drive_eta,
                                                                    size: 12,
                                                                    color: Colors
                                                                        .orange),
                                                                SizedBox(
                                                                    width: 4),
                                                                Text('DL',
                                                                    style: TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        color: Colors
                                                                            .orange,
                                                                        fontWeight:
                                                                            FontWeight.w700))
                                                              ]))),
                                              ]),
                                        ])),
                              ],
                              ...d.documents.map((doc) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                          color: doc.isUploaded
                                              ? Colors.green[50]
                                              : Colors.orange[50],
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: doc.isUploaded
                                                  ? Colors.green[200]!
                                                  : Colors.orange[200]!)),
                                      child: Row(children: [
                                        Icon(
                                            doc.isUploaded
                                                ? Icons.check_circle
                                                : Icons.warning_amber,
                                            color: doc.isUploaded
                                                ? Colors.green
                                                : Colors.orange,
                                            size: 16),
                                        const SizedBox(width: 10),
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              Text(doc.label,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13)),
                                              if (doc.docNumber.isNotEmpty)
                                                Text("No: ${doc.docNumber}",
                                                    style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 11)),
                                              if (doc.isUploaded)
                                                Text(
                                                    "Uploaded: ${doc.uploadDate}",
                                                    style: const TextStyle(
                                                        color: Colors.grey,
                                                        fontSize: 10)),
                                            ])),
                                        Row(children: [
                                          if (doc.isUploaded &&
                                              doc.filePath.isNotEmpty)
                                            IconButton(
                                                icon: const Icon(
                                                    Icons.visibility,
                                                    size: 18,
                                                    color: Colors.teal),
                                                tooltip: "View",
                                                onPressed: () =>
                                                    _viewDriverDoc(doc)),
                                          IconButton(
                                              icon: const Icon(Icons.camera_alt,
                                                  size: 18, color: Colors.blue),
                                              onPressed: () => _uploadDriverDoc(
                                                  d,
                                                  doc,
                                                  DocUploadMethod.camera)),
                                          IconButton(
                                              icon: const Icon(
                                                  Icons.upload_file,
                                                  size: 18,
                                                  color: Colors.indigo),
                                              onPressed: () => _uploadDriverDoc(
                                                  d,
                                                  doc,
                                                  DocUploadMethod.file)),
                                        ]),
                                      ])))),
                              if (d.monthlySalary > 0)
                                Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                        color: Colors.purple
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8)),
                                    child: Text(
                                        "Monthly Salary: Rs.${d.monthlySalary.toStringAsFixed(0)}",
                                        style: const TextStyle(
                                            color: Colors.purple,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12))),
                              const SizedBox(height: 10),
                              // Quick salary / advance / penalty actions
                              Row(children: [
                                Expanded(
                                    child: _driverQuickBtn(
                                        '💰 Pay Salary',
                                        const Color(0xFF10B981),
                                        () => _quickDriverActionFromMain(
                                            d, 'salary'))),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: _driverQuickBtn(
                                        '💵 Advance',
                                        const Color(0xFFF59E0B),
                                        () => _quickDriverActionFromMain(
                                            d, 'advance'))),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: _driverQuickBtn(
                                        '⚖️ Penalty',
                                        const Color(0xFFEF4444),
                                        () => _quickDriverActionFromMain(
                                            d, 'penalty'))),
                              ]),
                              const SizedBox(height: 8),
                              // Report / Merit buttons
                              Row(children: [
                                Expanded(
                                    child: _driverQuickBtn(
                                        '👎 Report Issue',
                                        const Color(0xFFEF4444),
                                        () => _submitComplaintForDriverMain(d,
                                            startAsDemerit: true))),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: _driverQuickBtn(
                                        '👍 Give Merit',
                                        const Color(0xFF10B981),
                                        () => _submitComplaintForDriverMain(d,
                                            startAsDemerit: false))),
                              ]),
                              const SizedBox(height: 8),
                              Row(children: [
                                Expanded(
                                    child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFFF6FAFF),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10))),
                                        onPressed: () async {
                                          await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      DriverLedgerScreen(
                                                          driver: d,
                                                          onUpdate: () =>
                                                              _save())));
                                          setState(() {});
                                        },
                                        icon: const Icon(Icons.receipt_long,
                                            size: 15, color: Color(0xFF0F172A)),
                                        label: const Text("Driver Ledger",
                                            style: TextStyle(
                                                color: Color(0xFF0F172A),
                                                fontSize: 12)))),
                              ]),
                            ]))
                  ],
                ))),
          ]);

  // ── Quick button widget for driver cards ────────────────────
  Widget _driverQuickBtn(String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.35))),
          child: Center(
              child: Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800))),
        ),
      );

  // ── Salary / Advance / Penalty quick action (main shell) ────
  void _quickDriverActionFromMain(Driver d, String action) {
    final ctrl = TextEditingController(
        text: action == "salary" ? d.monthlySalary.toStringAsFixed(0) : "");
    final noteCtrl = TextEditingController();
    final colors = {
      "salary": const Color(0xFF10B981),
      "advance": const Color(0xFFF59E0B),
      "penalty": const Color(0xFFEF4444)
    };
    final labels = {
      "salary": "Pay Salary",
      "advance": "Give Advance",
      "penalty": "Add Penalty"
    };
    showDialog(
        context: context,
        builder: (c) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: Text("${labels[action]} — ${d.name}",
                  style: TextStyle(
                      color: colors[action]!,
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: "Amount (Rs.)",
                        prefixIcon: const Icon(Icons.currency_rupee),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 10),
                TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(
                        labelText: "Notes",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)))),
              ]),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text("Cancel")),
                ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: colors[action]!,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    onPressed: () {
                      double amt = double.tryParse(ctrl.text) ?? 0;
                      if (amt <= 0) return;
                      final txType = action == "salary"
                          ? DriverTxType.salary
                          : action == "advance"
                              ? DriverTxType.advance
                              : DriverTxType.penalty;
                      final sign =
                          (action == "penalty" || action == "advance") ? -1 : 1;
                      setState(() {
                        d.transactions.insert(
                            0,
                            DriverTx(
                                date:
                                    "${DateTime.now().day}/${DateTime.now().month}",
                                type: txType,
                                amount: amt * sign,
                                note: noteCtrl.text.isNotEmpty
                                    ? noteCtrl.text
                                    : action));
                        d.balance += amt * sign;
                      });
                      _save();
                      Navigator.pop(c);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          backgroundColor: colors[action]!,
                          behavior: SnackBarBehavior.floating,
                          content: Text(
                              "OK Rs.${amt.toStringAsFixed(0)} recorded for ${d.name}")));
                    },
                    child: const Text("Confirm",
                        style: TextStyle(fontWeight: FontWeight.w800))),
              ],
            ));
  }

  // ── Report issue / Give merit for driver (main shell) ───────
  void _submitComplaintForDriverMain(Driver d, {bool startAsDemerit = true}) {
    final reasonCtrl = TextEditingController();
    int pts = startAsDemerit ? -10 : 10;
    bool isMerit = !startAsDemerit;
    final cats = [
      'Late delivery',
      'Vehicle damage',
      'Rash driving',
      'Dishonesty',
      'Absence without notice',
      'Good service ✓',
      'Excellent trip ✓',
      'Early delivery ✓'
    ];
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
              builder: (ctx, ss) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: Text(
                    '${startAsDemerit ? "Report Issue" : "Give Merit"} — ${d.name}',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
                content: SingleChildScrollView(
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Points apply only after admin approval.',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: GestureDetector(
                          onTap: () => ss(() {
                            isMerit = false;
                            pts = -10;
                          }),
                          child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                  color: !isMerit
                                      ? Colors.red.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: !isMerit
                                          ? Colors.red
                                          : Colors.grey.shade300)),
                              child: const Column(children: [
                                Icon(Icons.thumb_down_rounded,
                                    color: Colors.red),
                                SizedBox(height: 4),
                                Text('Demerit',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: Colors.red))
                              ])),
                        )),
                        const SizedBox(width: 10),
                        Expanded(
                            child: GestureDetector(
                          onTap: () => ss(() {
                            isMerit = true;
                            pts = 10;
                          }),
                          child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                  color: isMerit
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: isMerit
                                          ? Colors.green
                                          : Colors.grey.shade300)),
                              child: const Column(children: [
                                Icon(Icons.thumb_up_rounded,
                                    color: Colors.green),
                                SizedBox(height: 4),
                                Text('Merit',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                        color: Colors.green))
                              ])),
                        )),
                      ]),
                      const SizedBox(height: 10),
                      Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: cats
                              .map((cat) => GestureDetector(
                                    onTap: () {
                                      reasonCtrl.text = cat;
                                      ss(() {});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                          color: reasonCtrl.text == cat
                                              ? const Color(0xFF0EA5E9)
                                                  .withValues(alpha: 0.12)
                                              : const Color(0xFFF1F5F9),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                              color: reasonCtrl.text == cat
                                                  ? const Color(0xFF0EA5E9)
                                                  : Colors.transparent)),
                                      child: Text(cat,
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: reasonCtrl.text == cat
                                                  ? const Color(0xFF0EA5E9)
                                                  : const Color(0xFF334155))),
                                    ),
                                  ))
                              .toList()),
                      const SizedBox(height: 10),
                      TextField(
                          controller: reasonCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                              labelText: 'Reason / description',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10)))),
                      const SizedBox(height: 10),
                      Row(children: [
                        const Text('Points: ',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(width: 8),
                        GestureDetector(
                            onTap: () => ss(
                                () => pts = (pts - 5).clamp(-50, 50).toInt()),
                            child: const Icon(Icons.remove_circle_outline,
                                color: Colors.red)),
                        const SizedBox(width: 8),
                        Text('${pts > 0 ? "+" : ""}$pts',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: pts >= 0 ? Colors.green : Colors.red)),
                        const SizedBox(width: 8),
                        GestureDetector(
                            onTap: () => ss(
                                () => pts = (pts + 5).clamp(-50, 50).toInt()),
                            child: const Icon(Icons.add_circle_outline,
                                color: Colors.green)),
                      ]),
                    ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0EA5E9),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      onPressed: () {
                        if (reasonCtrl.text.trim().isEmpty) return;
                        FirebaseService.submitComplaint(
                          reporterUid: FirebaseService.currentUser?.uid ?? '',
                          reporterName: userProfile.companyName.isNotEmpty
                              ? userProfile.companyName
                              : userProfile.phone,
                          targetName: d.name,
                          targetType: 'driver',
                          targetId: d.id,
                          reason: reasonCtrl.text.trim(),
                          suggestedPoints: pts,
                        ).then((_) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  '✅ Report submitted — admin will review and apply points'),
                              backgroundColor: Color(0xFF0EA5E9),
                              behavior: SnackBarBehavior.floating));
                        });
                      },
                      child: const Text('Submit to Admin',
                          style: TextStyle(fontWeight: FontWeight.w800))),
                ],
              ),
            ));
  }

  Future<void> _uploadDriverDoc(
      Driver driver, DriverDoc doc, DocUploadMethod method) async {
    String? pickedFile;
    String? pickedPath;
    String pickedMime = 'image/jpeg';
    Map<String, String> ocrData = {};
    try {
      if (method == DocUploadMethod.camera) {
        final xfile = await ImagePicker().pickImage(
            source: ImageSource.camera,
            imageQuality: 95,
            maxWidth: 2048,
            maxHeight: 2048,
            preferredCameraDevice: CameraDevice.rear);
        if (xfile != null) {
          pickedFile = xfile.name;
          pickedPath = xfile.path;
          pickedMime = 'image/jpeg';
        }
      } else {
        final res = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
            allowMultiple: false,
            withData: false);
        if (res != null && res.files.isNotEmpty) {
          pickedFile = res.files.single.name;
          pickedPath = res.files.single.path;
          pickedMime =
              pickedFile.endsWith('.pdf') ? 'application/pdf' : 'image/jpeg';
        }
      }
    } catch (e) {
      pickedFile = null;
    }

    // Run OCR on the image
    if (pickedPath != null && pickedMime.startsWith('image') && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [
            SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF0F172A))),
            SizedBox(width: 12),
            Text("Reading document details...")
          ]),
          backgroundColor: Colors.indigo,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 6)));
      ocrData = await FirebaseService.extractDocumentText(pickedPath);
      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
    if (!mounted) return;
    // Pre-fill from OCR
    String ocrDocNum = '';
    if (doc.type == 'aadhaar' && ocrData['aadhaarNo'] != null) {
      ocrDocNum = ocrData['aadhaarNo']!;
    }
    if (doc.type == 'dl' && ocrData['dlNo'] != null) {
      ocrDocNum = ocrData['dlNo']!;
    }
    final numCtrl = TextEditingController(
        text: ocrDocNum.isNotEmpty ? ocrDocNum : doc.docNumber);
    final expCtrl = TextEditingController(text: ocrData['expiryDate'] ?? '');
    showDialog(
        context: context,
        builder: (c) => StatefulBuilder(
            builder: (c, ss) => AlertDialog(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                  title: Row(children: [
                    Icon(
                        pickedFile != null
                            ? Icons.check_circle
                            : Icons.edit_document,
                        color: pickedFile != null
                            ? Colors.green
                            : const Color(0xFFF6FAFF),
                        size: 22),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Text("Upload ${doc.label}",
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w800))),
                  ]),
                  content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (pickedFile != null)
                          Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: Colors.green.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.green.shade200)),
                              child: Row(children: [
                                const Icon(Icons.attach_file,
                                    color: Colors.green, size: 18),
                                const SizedBox(width: 8),
                                Flexible(
                                    child: Text(pickedFile,
                                        style: const TextStyle(
                                            color: Colors.green,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12),
                                        overflow: TextOverflow.ellipsis)),
                              ]))
                        else
                          Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Text(
                                  "Enter details manually or try again",
                                  style: TextStyle(
                                      color: Colors.orange, fontSize: 12))),
                        TextField(
                            style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 14,
                                fontWeight: FontWeight.w500),
                            controller: numCtrl,
                            decoration: InputDecoration(
                                labelText: doc.type == 'aadhaar'
                                    ? "Aadhaar Number (12 digits)"
                                    : doc.type == 'dl'
                                        ? "DL Number"
                                        : "Reference Number",
                                prefixIcon: Icon(
                                    doc.type == 'aadhaar'
                                        ? Icons.fingerprint
                                        : doc.type == 'dl'
                                            ? Icons.card_membership
                                            : Icons.numbers,
                                    size: 18),
                                filled: true,
                                fillColor: const Color(0xFFF6FAFF),
                                labelStyle: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                                floatingLabelStyle: const TextStyle(
                                    color: Color(0xFF0EA5E9),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF0EA5E9))),
                                enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF0EA5E9))),
                                focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                        color: Color(0xFF0EA5E9), width: 2)))),
                        if (doc.type != 'photo') ...[
                          const SizedBox(height: 10),
                          TextField(
                              style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500),
                              controller: expCtrl,
                              decoration: InputDecoration(
                                  labelText: "Expiry Date (DD/MM/YYYY)",
                                  hintText: "e.g. 31/12/2028",
                                  prefixIcon: const Icon(Icons.calendar_today,
                                      size: 18),
                                  filled: true,
                                  fillColor: const Color(0xFFF6FAFF),
                                  labelStyle: const TextStyle(
                                      color: Color(0xFF0F172A),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500),
                                  floatingLabelStyle: const TextStyle(
                                      color: Color(0xFF0EA5E9),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9))),
                                  focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF0EA5E9),
                                          width: 2)))),
                        ],
                      ]),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(c),
                        child: const Text("Cancel")),
                    ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF6FAFF),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        icon: const Icon(Icons.check,
                            color: Color(0xFF0F172A), size: 16),
                        label: const Text("Save",
                            style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.bold)),
                        onPressed: () {
                          setState(() {
                            doc.isUploaded = true;
                            doc.docNumber = numCtrl.text;
                            doc.uploadDate =
                                "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";
                            if (expCtrl.text.isNotEmpty) {
                              doc.expiryDate = expCtrl.text;
                            }
                            if (pickedFile != null) {
                              doc.fileName = pickedFile;
                            }
                            if (pickedPath != null) {
                              doc.filePath = pickedPath;
                              doc.mimeType = pickedMime;
                            }
                            if (doc.type == 'aadhaar' &&
                                numCtrl.text.isNotEmpty) {
                              driver.aadharNum = numCtrl.text;
                            }
                            if (doc.type == 'dl' && numCtrl.text.isNotEmpty) {
                              driver.dlNum = numCtrl.text;
                            }
                          });
                          _save();
                          // Sync to Firestore so fleet owner sees the doc
                          final fsUid = FirebaseService.currentUser?.uid ?? '';
                          if (fsUid.isNotEmpty && pickedPath != null) {
                            final updates = <String, dynamic>{
                              'docs.${doc.type}.isUploaded': true,
                              'docs.${doc.type}.filePath': pickedPath,
                              'docs.${doc.type}.docNumber': numCtrl.text,
                              'docs.${doc.type}.uploadDate': doc.uploadDate,
                              'docs.${doc.type}.label': doc.label,
                            };
                            if (doc.type == 'photo') {
                              updates['selfieDocPath'] = pickedPath;
                            }
                            if (doc.type == 'aadhaar') {
                              updates['aadhaarDocPath'] = pickedPath;
                            }
                            if (doc.type == 'dl') {
                              updates['dlDocPath'] = pickedPath;
                            }
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(fsUid)
                                .collection('drivers')
                                .doc(driver.id)
                                .set(updates, SetOptions(merge: true))
                                .ignore();
                          }
                          Navigator.pop(c);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              content: Text(
                                  "OK ${doc.label} ${pickedFile != null ? 'uploaded' : 'recorded'}!")));
                        }),
                  ],
                )));
  }

  void _addDriver() {
    final nm = TextEditingController();
    final ph = TextEditingController();
    final aa = TextEditingController();
    final dl = TextEditingController();
    final sl = TextEditingController();
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (c) => Container(
              decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28))),
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(c).viewInsets.bottom,
                  left: 24,
                  right: 24,
                  top: 28),
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text("Add New Driver",
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 18),
                Center(
                    child: Stack(children: [
                  CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue.withValues(alpha: 0.18),
                      child: const Icon(Icons.person,
                          size: 40, color: Colors.blue)),
                  Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                          onTap: () async {
                            try {
                              final img = await ImagePicker().pickImage(
                                  source: ImageSource.camera, imageQuality: 90);
                              if (img != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        backgroundColor: Colors.green,
                                        behavior: SnackBarBehavior.floating,
                                        content: Text(
                                            " Photo captured: ${img.name}")));
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          "Camera unavailable - check permissions"),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating));
                            }
                          },
                          child: CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFFF6FAFF),
                              child: const Icon(Icons.camera_alt,
                                  size: 16, color: Color(0xFF0F172A))))),
                ])),
                const SizedBox(height: 18),
                TextField(
                    style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    controller: nm,
                    decoration: InputDecoration(
                        labelText: "Full Name *",
                        prefixIcon: const Icon(Icons.person),
                        filled: true,
                        fillColor: const Color(0xFFF6FAFF),
                        labelStyle: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        floatingLabelStyle: const TextStyle(
                            color: Color(0xFF0EA5E9),
                            fontWeight: FontWeight.w800,
                            fontSize: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF0EA5E9))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF0EA5E9))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF0EA5E9), width: 2)))),
                const SizedBox(height: 12),
                TextField(
                    style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    controller: ph,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                        labelText: "Phone Number *",
                        prefixIcon: const Icon(Icons.phone),
                        filled: true,
                        fillColor: const Color(0xFFF6FAFF),
                        labelStyle: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        floatingLabelStyle: const TextStyle(
                            color: Color(0xFF0EA5E9),
                            fontWeight: FontWeight.w800,
                            fontSize: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF0EA5E9))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF0EA5E9))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF0EA5E9), width: 2)))),
                const SizedBox(height: 12),
                TextField(
                    style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    controller: sl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: "Monthly Salary (Rs.)",
                        prefixIcon: const Icon(Icons.currency_rupee),
                        filled: true,
                        fillColor: const Color(0xFFF6FAFF),
                        labelStyle: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        floatingLabelStyle: const TextStyle(
                            color: Color(0xFF0EA5E9),
                            fontWeight: FontWeight.w800,
                            fontSize: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF0EA5E9))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF0EA5E9))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF0EA5E9), width: 2)))),
                const SizedBox(height: 12),
                TextField(
                    style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    controller: aa,
                    keyboardType: TextInputType.number,
                    maxLength: 12,
                    decoration: InputDecoration(
                        counterText: "",
                        labelText: "Aadhaar Number (12 digits)",
                        prefixIcon: const Icon(Icons.credit_card),
                        filled: true,
                        fillColor: const Color(0xFFF6FAFF),
                        labelStyle: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        floatingLabelStyle: const TextStyle(
                            color: Color(0xFF0EA5E9),
                            fontWeight: FontWeight.w800,
                            fontSize: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF0EA5E9))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF0EA5E9))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF0EA5E9), width: 2)))),
                const SizedBox(height: 12),
                TextField(
                    style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    controller: dl,
                    decoration: InputDecoration(
                        labelText: "Driving Licence Number",
                        prefixIcon: const Icon(Icons.directions_car),
                        filled: true,
                        fillColor: const Color(0xFFF6FAFF),
                        labelStyle: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                        floatingLabelStyle: const TextStyle(
                            color: Color(0xFF0EA5E9),
                            fontWeight: FontWeight.w800,
                            fontSize: 12),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF0EA5E9))),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFF0EA5E9))),
                        focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF0EA5E9), width: 2)))),
                const SizedBox(height: 12),
                // Aadhaar + DL quick upload row
                StatefulBuilder(builder: (ctx, setDoc) {
                  bool aadhaarDone = aa.text.isNotEmpty;
                  bool dlDone = dl.text.isNotEmpty;
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Quick Document Scan",
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A))),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: GestureDetector(
                                  onTap: () async {
                                    try {
                                      final img = await ImagePicker().pickImage(
                                          source: ImageSource.camera,
                                          imageQuality: 90);
                                      if (img != null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                backgroundColor: Colors.indigo,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                content: Text(
                                                    "Reading Aadhaar...")));
                                        final ocr = await FirebaseService
                                            .extractDocumentText(img.path);
                                        ScaffoldMessenger.of(context)
                                            .hideCurrentSnackBar();
                                        if (ocr['aadhaarNo'] != null) {
                                          aa.text = ocr['aadhaarNo']!;
                                          setDoc(() {});
                                        }
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                backgroundColor: Colors.green,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                content: Text(ocr[
                                                            'aadhaarNo'] !=
                                                        null
                                                    ? "Aadhaar: ${ocr['aadhaarNo']}"
                                                    : "Photo captured - enter number manually")));
                                      }
                                    } catch (_) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content:
                                                  Text("Camera unavailable"),
                                              backgroundColor: Colors.red));
                                    }
                                  },
                                  child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: aadhaarDone
                                              ? Colors.green[50]
                                              : const Color(0xFFF6FAFF)
                                                  .withValues(alpha: 0.05),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: aadhaarDone
                                                  ? Colors.green
                                                  : const Color(0xFFF6FAFF))),
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                                aadhaarDone
                                                    ? Icons.check_circle
                                                    : Icons.camera_alt,
                                                size: 16,
                                                color: aadhaarDone
                                                    ? Colors.green
                                                    : const Color(0xFFF6FAFF)),
                                            const SizedBox(width: 6),
                                            Text("Scan Aadhaar",
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: aadhaarDone
                                                        ? Colors.green
                                                        : const Color(
                                                            0xFF0F172A)))
                                          ])))),
                          const SizedBox(width: 8),
                          Expanded(
                              child: GestureDetector(
                                  onTap: () async {
                                    try {
                                      final img = await ImagePicker().pickImage(
                                          source: ImageSource.camera,
                                          imageQuality: 90);
                                      if (img != null) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                backgroundColor: Colors.indigo,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                content: Text(
                                                    "Reading Driving Licence...")));
                                        final ocr = await FirebaseService
                                            .extractDocumentText(img.path);
                                        ScaffoldMessenger.of(context)
                                            .hideCurrentSnackBar();
                                        if (ocr['dlNo'] != null) {
                                          dl.text = ocr['dlNo']!;
                                          setDoc(() {});
                                        }
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                backgroundColor: Colors.green,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                content: Text(ocr['dlNo'] !=
                                                        null
                                                    ? "DL: ${ocr['dlNo']}"
                                                    : "Photo captured - enter number manually")));
                                      }
                                    } catch (_) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content:
                                                  Text("Camera unavailable"),
                                              backgroundColor: Colors.red));
                                    }
                                  },
                                  child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                          color: dlDone
                                              ? Colors.green[50]
                                              : Colors.blue
                                                  .withValues(alpha: 0.05),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: dlDone
                                                  ? Colors.green
                                                  : Colors.blue)),
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                                dlDone
                                                    ? Icons.check_circle
                                                    : Icons.camera_alt,
                                                size: 16,
                                                color: dlDone
                                                    ? Colors.green
                                                    : Colors.blue),
                                            const SizedBox(width: 6),
                                            Text("Scan DL",
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: dlDone
                                                        ? Colors.green
                                                        : Colors.blue))
                                          ])))),
                        ]),
                      ]);
                }),
                const SizedBox(height: 20),
                SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF6FAFF),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14))),
                        onPressed: () {
                          final d = Driver(
                              id: "D${drivers.length + 1}",
                              name: nm.text,
                              phone: ph.text,
                              balance: 0,
                              transactions: [],
                              aadharNum: aa.text,
                              dlNum: dl.text,
                              monthlySalary: double.tryParse(sl.text) ?? 0);
                          if (aa.text.isNotEmpty) {
                            final doc = d.documents
                                .firstWhere((doc) => doc.type == 'aadhaar');
                            doc.docNumber = aa.text;
                            doc.isUploaded = true;
                            doc.uploadDate =
                                "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";
                          }
                          if (dl.text.isNotEmpty) {
                            final doc = d.documents
                                .firstWhere((doc) => doc.type == 'dl');
                            doc.docNumber = dl.text;
                            doc.isUploaded = true;
                            doc.uploadDate =
                                "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}";
                          }
                          setState(() => drivers.add(d));
                          _save();
                          Navigator.pop(c);
                        },
                        child: const Text("Save Driver",
                            style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 16,
                                fontWeight: FontWeight.bold)))),
                const SizedBox(height: 24),
              ])),
            ));
  }

  //
  void _openProfile() {
    if (_isDriver) {
      _openDriverProfile();
      return;
    }
    final cn = TextEditingController(text: userProfile.companyName);
    final cg = TextEditingController(text: userProfile.gstin);
    final cp = TextEditingController(text: userProfile.phone);
    final ca = TextEditingController(text: userProfile.address);
    final ce = TextEditingController(text: userProfile.email);
    final cb = TextEditingController(text: userProfile.bankName);
    final cac = TextEditingController(text: userProfile.bankAccount);
    final ci = TextEditingController(text: userProfile.bankIfsc);
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => UniversalScaffold(
                  appBar: AppBar(
                      backgroundColor: const Color(0xFFF6FAFF),
                      iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
                      title: const Text("Company Profile",
                          style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.w900))),
                  body: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                                onTap: _openSub,
                                child: Container(
                                    padding: const EdgeInsets.all(18),
                                    margin: const EdgeInsets.only(bottom: 24),
                                    decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                            colors: [
                                              const Color(0xFFF6FAFF),
                                              subscription.tierColor
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight),
                                        borderRadius:
                                            BorderRadius.circular(18)),
                                    child: Row(children: [
                                      Icon(Icons.workspace_premium,
                                          color: subscription.tierColor,
                                          size: 30),
                                      const SizedBox(width: 14),
                                      Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                            Text(
                                                "${subscription.tierName} Plan",
                                                style: const TextStyle(
                                                    color: Color(0xFF0F172A),
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 18)),
                                            Text(
                                                subscription.tier ==
                                                        SubscriptionTier.free
                                                    ? "10 trips/month"
                                                    : subscription.tier ==
                                                            SubscriptionTier
                                                                .enterprise
                                                        ? "50+ vehicles - 10 users"
                                                        : "Unlimited - PDF + GPS",
                                                style: const TextStyle(
                                                    color: Color(0x99334155),
                                                    fontSize: 12),
                                                overflow: TextOverflow.ellipsis)
                                          ])),
                                      const Text("Upgrade ->",
                                          style: TextStyle(
                                              color: Color(0x99334155),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12))
                                    ]))),
                            const Text("Company Details",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A))),
                            const SizedBox(height: 14),
                            TextField(
                                style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                                controller: cn,
                                decoration: InputDecoration(
                                    labelText: "Company Name",
                                    prefixIcon: Icon(Icons.business),
                                    border: OutlineInputBorder())),
                            const SizedBox(height: 12),
                            TextField(
                                style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                                controller: cg,
                                decoration: InputDecoration(
                                    labelText: "GSTIN",
                                    prefixIcon: Icon(Icons.receipt),
                                    border: OutlineInputBorder())),
                            const SizedBox(height: 12),
                            TextField(
                                style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                                controller: cp,
                                decoration: InputDecoration(
                                    labelText: "Phone",
                                    prefixIcon: Icon(Icons.phone),
                                    border: OutlineInputBorder())),
                            const SizedBox(height: 12),
                            TextField(
                                style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                                controller: ce,
                                decoration: InputDecoration(
                                    labelText: "Email",
                                    prefixIcon: Icon(Icons.email),
                                    border: OutlineInputBorder())),
                            const SizedBox(height: 12),
                            TextField(
                                style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                                controller: ca,
                                maxLines: 2,
                                decoration: InputDecoration(
                                    labelText: "Address",
                                    prefixIcon: Icon(Icons.location_on),
                                    border: OutlineInputBorder())),
                            const SizedBox(height: 18),
                            const Text("Bank Details",
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A))),
                            const SizedBox(height: 12),
                            TextField(
                                style: const TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500),
                                controller: cb,
                                decoration: InputDecoration(
                                    labelText: "Bank Name",
                                    prefixIcon: Icon(Icons.account_balance),
                                    border: OutlineInputBorder())),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(
                                  child: TextField(
                                      style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500),
                                      controller: cac,
                                      decoration: InputDecoration(
                                          labelText: "Account No.",
                                          border: OutlineInputBorder()))),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: TextField(
                                      style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500),
                                      controller: ci,
                                      decoration: InputDecoration(
                                          labelText: "IFSC Code",
                                          border: OutlineInputBorder())))
                            ]),
                            const SizedBox(height: 22),
                            const SizedBox(height: 16),
                            const Text("App Language",
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF64748B))),
                            const SizedBox(height: 6),
                            Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                    border: Border.all(
                                        color: const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(10)),
                                child: DropdownButton<String>(
                                  value: 'English',
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  style: const TextStyle(
                                      fontSize: 14, color: Color(0xFF0F172A)),
                                  items: [
                                    'English',
                                    'Hindi (हिन्दी)',
                                    'Gujarati (ગુજરાતી)',
                                    'Punjabi (ਪੰਜਾਬੀ)',
                                    'Marathi (मराठी)',
                                    'Tamil (தமிழ்)',
                                    'Telugu (తెలుగు)'
                                  ]
                                      .map((lang) => DropdownMenuItem(
                                          value: lang, child: Text(lang)))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v != null && !v.startsWith('English')) {
                                      showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            16)),
                                                title: const Text('Coming Soon',
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w900)),
                                                content: const Text(
                                                    'Multi-language support is on the roadmap.\nEmail support@routemaster.app to request your language.'),
                                                actions: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context),
                                                      child: const Text('OK'))
                                                ],
                                              ));
                                    }
                                  },
                                )),
                            const SizedBox(height: 16),
                            SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12))),
                                    onPressed: () {
                                      setState(() {
                                        userProfile.companyName = cn.text;
                                        userProfile.gstin = cg.text;
                                        userProfile.phone = cp.text;
                                        userProfile.address = ca.text;
                                        userProfile.email = ce.text;
                                        userProfile.bankName = cb.text;
                                        userProfile.bankAccount = cac.text;
                                        userProfile.bankIfsc = ci.text;
                                      });
                                      _save();
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text("Profile Updated"),
                                              backgroundColor: Colors.green));
                                    },
                                    child: const Text("Save Details",
                                        style: TextStyle(
                                            color: Color(0xFFF6FAFF),
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold)))),
                            const SizedBox(height: 20),
                            // Privacy & Your Data (DPDP data rights)
                            GestureDetector(
                                onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const PrivacySettingsScreen())),
                                child: Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 15),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFF0EA5E9)
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                            color: const Color(0xFF0EA5E9)
                                                .withValues(alpha: 0.3))),
                                    child: const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.privacy_tip_outlined,
                                              color: Color(0xFF0EA5E9),
                                              size: 18),
                                          SizedBox(width: 8),
                                          Text("Privacy & Your Data",
                                              style: TextStyle(
                                                  color: Color(0xFF0EA5E9),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15)),
                                        ]))),
                            // Logout button
                            GestureDetector(
                              onTap: () => showDialog(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                        backgroundColor:
                                            const Color(0xFFF6FAFF),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        title: const Row(children: [
                                          Icon(Icons.logout_rounded,
                                              color: Color(0xFFDC2626)),
                                          SizedBox(width: 10),
                                          Text("Sign Out",
                                              style: TextStyle(
                                                  color: Color(0xFF0F172A),
                                                  fontWeight: FontWeight.w900))
                                        ]),
                                        content: const Text(
                                            "You will be signed out and need to login again.",
                                            style: TextStyle(
                                                color: Color(0xFF0F172A))),
                                        actions: [
                                          TextButton(
                                              onPressed: () => Navigator.pop(c),
                                              child: const Text("Cancel",
                                                  style: TextStyle(
                                                      color:
                                                          Color(0xFF22C55E)))),
                                          GestureDetector(
                                            onTap: () async {
                                              final prefs =
                                                  await SharedPreferences
                                                      .getInstance();
                                              await prefs.setBool(
                                                  'rm_session_active', false);
                                              try {
                                                await FirebaseService.auth
                                                    .signOut();
                                              } catch (_) {}
                                              if (!mounted) return;
                                              Navigator.of(context)
                                                  .pushAndRemoveUntil(
                                                      MaterialPageRoute(
                                                          builder: (_) =>
                                                              const LoginScreen()),
                                                      (_) => false);
                                            },
                                            child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 18,
                                                        vertical: 8),
                                                decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFDC2626),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            10)),
                                                child: const Text("Sign Out",
                                                    style: TextStyle(
                                                        color:
                                                            Color(0xFFF6FAFF),
                                                        fontWeight:
                                                            FontWeight.w800))),
                                          ),
                                        ],
                                      )),
                              child: Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 8),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626)
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: const Color(0xFFDC2626)
                                            .withValues(alpha: 0.3))),
                                child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.logout_rounded,
                                          color: Color(0xFFDC2626), size: 18),
                                      SizedBox(width: 8),
                                      Text("Sign Out",
                                          style: TextStyle(
                                              color: Color(0xFFDC2626),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15))
                                    ]),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // ── Language Selector ──────────────────
                            Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(children: [
                                    Icon(Icons.translate_rounded,
                                        color: Color(0xFF0EA5E9), size: 18),
                                    SizedBox(width: 8),
                                    Text("App Language",
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF0F172A))),
                                  ]),
                                  const SizedBox(height: 10),
                                  _LanguageSelectorWidget(
                                      onUpdate: () => setState(() {})),
                                ]),
                            const SizedBox(height: 20),
                            // ── Route Cost Calculator shortcut ──────
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                setState(() => _idx = 0);
                                Future.delayed(
                                    const Duration(milliseconds: 200),
                                    () => openAiControlTower(
                                        context: context,
                                        ledgers: _visibleLedgers,
                                        bankEntries: moduleState.bankEntries,
                                        maintenanceTickets:
                                            moduleState.maintenanceTickets,
                                        fleet: fleet,
                                        marketLoads: marketLoads,
                                        complianceVault:
                                            moduleState.complianceVault,
                                        onApplyReconciliation: (id, amt) {
                                          final i = ledgers
                                              .indexWhere((l) => l.id == id);
                                          if (i >= 0) {
                                            setState(() => ledgers[i]
                                                .paymentReceived += amt);
                                            _save();
                                          }
                                        },
                                        onImportCsv: _showCSVImport));
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF0EA5E9)
                                        .withValues(alpha: 0.07),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: const Color(0xFF0EA5E9)
                                            .withValues(alpha: 0.25))),
                                child: const Row(children: [
                                  Icon(Icons.calculate_rounded,
                                      color: Color(0xFF0EA5E9), size: 22),
                                  SizedBox(width: 12),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text("Route Cost Calculator",
                                            style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 14,
                                                color: Color(0xFF0F172A))),
                                        Text(
                                            "Diesel + toll estimate for any trip",
                                            style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 11)),
                                      ])),
                                  Icon(Icons.arrow_forward_ios_rounded,
                                      size: 14, color: Color(0xFF0EA5E9)),
                                ]),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const ThemePicker(),
                            const SizedBox(height: 12),
                            Center(
                                child: Text(
                                    "NavGati ERP v${AppConfig.appVersion}",
                                    style: const TextStyle(
                                        color: Color(0xFFE2E8F0),
                                        fontSize: 10))),
                          ])),
                )));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return UniversalScaffold(
          body: const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F172A))));
    }
    final themeConfig = ThemeHelper.getConfig(ref.watch(appThemeProvider));
    return UniversalScaffold(
        extendBodyBehindAppBar: false,
        appBar: AppBar(
            backgroundColor: themeConfig.navBarColor,
            foregroundColor: themeConfig.primaryTextColor,
            title: GestureDetector(
                onTap: () {},
                onLongPress: _promptAdminPin,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: themeConfig.highlightColor,
                          borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.local_shipping_rounded,
                          color: Color(0xFFFFFFFF), size: 16)),
                  const SizedBox(width: 8),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("NAVGATI",
                            style: TextStyle(
                                color: themeConfig.primaryTextColor,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                                fontSize: 14,
                                height: 1.1)),
                        Text("ERP  v${AppConfig.appVersion}",
                            style: TextStyle(
                                color: themeConfig.highlightColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 9,
                                letterSpacing: 2)),
                      ]),
                ])),
            actions: [
              // AI Control Tower button
              IconButton(
                  tooltip: 'AI Control Tower',
                  icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color: themeConfig.highlightColor
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.auto_awesome_rounded,
                          color: themeConfig.highlightColor, size: 18)),
                  onPressed: () => openAiControlTower(
                      context: context,
                      ledgers: _visibleLedgers,
                      bankEntries: moduleState.bankEntries,
                      maintenanceTickets: moduleState.maintenanceTickets,
                      fleet: fleet,
                      marketLoads: marketLoads,
                      complianceVault: moduleState.complianceVault,
                      onApplyReconciliation: (id, amt) {
                        final i = ledgers.indexWhere((l) => l.id == id);
                        if (i >= 0) {
                          setState(() => ledgers[i].paymentReceived += amt);
                          _save();
                        }
                      },
                      onImportCsv: _showCSVImport)),
              Builder(builder: (ctx) {
                final activeAlerts = _visibleLedgers
                    .where((l) =>
                        (l.isPaymentOverdue || l.isDueSoon) &&
                        l.partyPending > 0)
                    .toList();
                final hasUnread = activeAlerts.isNotEmpty && !_notifsSeen;
                return IconButton(
                    icon: Stack(children: [
                      Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: themeConfig.highlightColor
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(
                              hasUnread
                                  ? Icons.notifications_rounded
                                  : Icons.notifications_outlined,
                              color: themeConfig.primaryTextColor,
                              size: 20)),
                      if (hasUnread)
                        Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 1.5)))),
                    ]),
                    onPressed: () async {
                      setState(() => _notifsSeen = true);
                      await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => SharedEventsScreen(
                                    ledgers: _visibleLedgers,
                                    userProfile: userProfile,
                                    onMarkAllRead: () =>
                                        setState(() => _notifsSeen = true),
                                  )));
                      // Do NOT reset _notifsSeen here — only reset when NEW alerts arrive
                      // (handled in the Firestore ledger stream listener)
                    });
              }),
              IconButton(
                  icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                          color:
                              themeConfig.highlightColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.person_outline_rounded,
                          color: themeConfig.primaryTextColor, size: 20)),
                  onPressed: _openProfile),
              const SizedBox(width: 4),
            ]),
        body: Stack(children: [
          Positioned.fill(
              child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  color: themeConfig.surfaceColor)),
          IndexedStack(index: _idx, children: _buildTabScreens())
        ]),
        bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: themeConfig.navBarColor,
              border: Border(
                  top: BorderSide(
                      color: themeConfig.cardBorder.withValues(alpha: 0.8))),
            ),
            child: SafeArea(
              child: BottomNavigationBar(
                  currentIndex: _idx,
                  type: BottomNavigationBarType.fixed,
                  selectedItemColor: themeConfig.highlightColor,
                  unselectedItemColor: themeConfig.secondaryTextColor,
                  backgroundColor: Colors.transparent,
                  selectedFontSize: 9,
                  unselectedFontSize: 9,
                  elevation: 0,
                  onTap: (i) => setState(() => _idx = i),
                  items: _buildNavItems()),
            ))); // closes SafeArea
  }

  // ── Tab screens list — filtered by user type ─────────────────
  List<Widget> _buildTabScreens() {
    if (_isDriver) {
      return [_buildDriverDash(), _buildDriverDocsTab()];
    }
    if (_isConsignor) {
      // Consignor: finds loads, dispatches, views khata — no fleet/driver mgmt
      return [
        _buildDash(),
        _buildFindLoad(),
        _buildPostLoad(),
        _buildKhata(),
        const GreenImpactScreen()
      ];
    }
    // Fleet owner: full access
    return [
      _buildDash(),
      _buildFindLoad(),
      _buildPostLoad(),
      _buildKhata(),
      _buildFleet(),
      _buildDrivers(),
      const GreenImpactScreen()
    ];
  }

  List<BottomNavigationBarItem> _buildNavItems() {
    if (_isDriver) {
      return const [
        BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined, size: 22),
            activeIcon: Icon(Icons.dashboard_rounded, size: 22),
            label: "Home"),
        BottomNavigationBarItem(
            icon: Icon(Icons.badge_outlined, size: 22),
            activeIcon: Icon(Icons.badge_rounded, size: 22),
            label: "My Profile"),
      ];
    }
    if (_isConsignor) {
      return const [
        BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined, size: 22),
            activeIcon: Icon(Icons.dashboard_rounded, size: 22),
            label: "Home"),
        BottomNavigationBarItem(
            icon: Icon(Icons.search_outlined, size: 22),
            activeIcon: Icon(Icons.search_rounded, size: 22),
            label: "Find Load"),
        BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined, size: 22),
            activeIcon: Icon(Icons.add_box_rounded, size: 22),
            label: "Dispatch"),
        BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined, size: 22),
            activeIcon: Icon(Icons.receipt_long_rounded, size: 22),
            label: "Khata"),
        BottomNavigationBarItem(
            icon: Icon(Icons.eco_outlined, size: 22),
            activeIcon: Icon(Icons.eco_rounded, size: 22),
            label: "Green"),
      ];
    }
    return const [
      BottomNavigationBarItem(
          icon: Icon(Icons.dashboard_outlined, size: 22),
          activeIcon: Icon(Icons.dashboard_rounded, size: 22),
          label: "Home"),
      BottomNavigationBarItem(
          icon: Icon(Icons.search_outlined, size: 22),
          activeIcon: Icon(Icons.search_rounded, size: 22),
          label: "Find Load"),
      BottomNavigationBarItem(
          icon: Icon(Icons.add_box_outlined, size: 22),
          activeIcon: Icon(Icons.add_box_rounded, size: 22),
          label: "Dispatch"),
      BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined, size: 22),
          activeIcon: Icon(Icons.receipt_long_rounded, size: 22),
          label: "Khata"),
      BottomNavigationBarItem(
          icon: Icon(Icons.local_shipping_outlined, size: 22),
          activeIcon: Icon(Icons.local_shipping_rounded, size: 22),
          label: "Fleet"),
      BottomNavigationBarItem(
          icon: Icon(Icons.badge_outlined, size: 22),
          activeIcon: Icon(Icons.badge_rounded, size: 22),
          label: "Drivers"),
      BottomNavigationBarItem(
          icon: Icon(Icons.eco_outlined, size: 22),
          activeIcon: Icon(Icons.eco_rounded, size: 22),
          label: "Green"),
    ];
  } // end _buildNavItems

  void _showDriverSalarySheet(Driver? driver) {
    if (driver == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'No salary records. Ask fleet owner to tap Sync in Drivers tab.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating));
      return;
    }
    final txns = driver.transactions;
    final earned = txns
        .where((t) =>
            t.type == DriverTxType.salary || t.type == DriverTxType.bonus)
        .fold(0.0, (s, t) => s + t.amount);
    final deducted = txns
        .where((t) =>
            t.type == DriverTxType.advance ||
            t.type == DriverTxType.penalty ||
            t.type == DriverTxType.deduction)
        .fold(0.0, (s, t) => s + t.amount);
    final balance = earned - deducted;
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.95,
            builder: (_, ctrl) => ListView(
                    controller: ctrl,
                    padding: const EdgeInsets.all(20),
                    children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Salary Ledger",
                                style: TextStyle(
                                    fontWeight: FontWeight.w900, fontSize: 18)),
                            Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                    color: balance >= 0
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text("Rs. ${balance.toStringAsFixed(0)}",
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        color: balance >= 0
                                            ? Colors.green
                                            : Colors.red))),
                          ]),
                      const SizedBox(height: 4),
                      Text(driver.name,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13)),
                      Text(
                          "Earned Rs. ${earned.toStringAsFixed(0)}  |  Deducted Rs. ${deducted.toStringAsFixed(0)}",
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                      const Divider(height: 24),
                      if (txns.isEmpty)
                        const Center(
                            child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                    "No transactions yet. Your fleet owner will add salary entries here.",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: Colors.grey, height: 1.6)))),
                      ...txns.reversed.map((t) {
                        final isCredit = t.type == DriverTxType.salary ||
                            t.type == DriverTxType.bonus;
                        return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                                color: isCredit
                                    ? Colors.green.withValues(alpha: 0.07)
                                    : Colors.red.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: isCredit
                                        ? Colors.green.withValues(alpha: 0.2)
                                        : Colors.red.withValues(alpha: 0.2))),
                            child: Row(children: [
                              Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                      color: isCredit
                                          ? Colors.green.withValues(alpha: 0.1)
                                          : Colors.red.withValues(alpha: 0.1),
                                      shape: BoxShape.circle),
                                  child: Icon(
                                      isCredit
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward,
                                      color:
                                          isCredit ? Colors.green : Colors.red,
                                      size: 16)),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(
                                        t.note.isNotEmpty
                                            ? t.note
                                            : t.type.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13)),
                                    Text(t.date,
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 11)),
                                  ])),
                              Text(
                                  "${isCredit ? '+' : '-'}Rs. ${t.amount.toStringAsFixed(0)}",
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15,
                                      color: isCredit
                                          ? Colors.green
                                          : Colors.red)),
                            ]));
                      }),
                    ])));
  }

  void _openDriverProfile() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => UniversalScaffold(
                appBar: AppBar(
                    backgroundColor: const Color(0xFFF6FAFF),
                    iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
                    title: const Text("My Profile",
                        style: TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w900))),
                body: _buildDriverDocsTab())));
  }

  Widget _buildDriverDocsTab() {
    final driverEntry = drivers.where((d) {
      final dp = d.phone.replaceAll(RegExp(r'\D'), '');
      final up = userProfile.phone.replaceAll(RegExp(r'\D'), '');
      if (dp.isEmpty || up.isEmpty) return false;
      final dp10 = dp.length >= 10 ? dp.substring(dp.length - 10) : dp;
      final up10 = up.length >= 10 ? up.substring(up.length - 10) : up;
      return dp10 == up10;
    }).firstOrNull;
    final txns = driverEntry?.transactions ?? [];
    final earned = txns
        .where((t) =>
            t.type == DriverTxType.salary || t.type == DriverTxType.bonus)
        .fold(0.0, (s, t) => s + t.amount);
    final deducted = txns
        .where((t) =>
            t.type == DriverTxType.advance ||
            t.type == DriverTxType.penalty ||
            t.type == DriverTxType.deduction)
        .fold(0.0, (s, t) => s + t.amount);
    final balance = earned - deducted;

    return StatefulBuilder(builder: (ctx, setS) {
      String selfieP = driverEntry?.selfieDocPath ?? '';
      String aadhaarP = driverEntry?.aadhaarDocPath ?? '';
      String dlP = driverEntry?.dlDocPath ?? '';

      Future<void> pickDoc(String type) async {
        String? p;
        try {
          final img = await ImagePicker()
              .pickImage(source: ImageSource.camera, imageQuality: 90);
          if (img != null) p = img.path;
        } catch (_) {}
        if (p == null) {
          try {
            final res = await FilePicker.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                withData: false);
            if (res != null && res.files.isNotEmpty) p = res.files.single.path;
          } catch (_) {}
        }
        if (p == null) return;
        if (driverEntry != null) {
          setState(() {
            if (type == 'selfie') driverEntry.selfieDocPath = p!;
            if (type == 'aadhaar') driverEntry.aadhaarDocPath = p!;
            if (type == 'dl') driverEntry.dlDocPath = p!;
          });
          setS(() {
            if (type == 'selfie') selfieP = p!;
            if (type == 'aadhaar') aadhaarP = p!;
            if (type == 'dl') dlP = p!;
          });
          _save();
          if (driverEntry.fleetOwnerUid?.isNotEmpty == true) {
            final updates = <String, dynamic>{
              '${type}DocPath': p,
              'docs.$type.isUploaded': true,
              'docs.$type.filePath': p,
              'docs.$type.uploadDate':
                  "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
            };
            FirebaseFirestore.instance
                .collection('users')
                .doc(driverEntry.fleetOwnerUid)
                .collection('drivers')
                .doc(driverEntry.id)
                .set(updates, SetOptions(merge: true))
                .ignore();
          }
        }
        if (!mounted) return;
        final label = type == 'selfie'
            ? 'Selfie'
            : type == 'aadhaar'
                ? 'Aadhaar'
                : 'Driving Licence';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            content: Text('$label uploaded and synced!')));
      }

      void viewDoc(String path, String label) {
        if (path.isEmpty) return;
        showDialog(
            context: context,
            builder: (_) => Dialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(children: [
                        Text(label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 16)),
                        const Spacer(),
                        IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close)),
                      ])),
                  ClipRRect(
                      borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16)),
                      child: path.toLowerCase().endsWith('.pdf')
                          ? const Padding(
                              padding: EdgeInsets.all(32),
                              child: Column(children: [
                                Icon(Icons.picture_as_pdf,
                                    size: 64, color: Colors.red),
                                SizedBox(height: 8),
                                Text('PDF uploaded')
                              ]))
                          : Image.file(File(path),
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text('Preview unavailable')))),
                ])));
      }

      Widget docTile(String label, String type, String path, IconData icon) {
        final done = path.isNotEmpty;
        return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: done
                    ? Colors.green.withValues(alpha: 0.07)
                    : Colors.orange.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: done
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.orange.withValues(alpha: 0.3))),
            child: Row(children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: done
                          ? Colors.green.withValues(alpha: 0.12)
                          : Colors.orange.withValues(alpha: 0.12),
                      shape: BoxShape.circle),
                  child: Icon(icon,
                      color: done ? Colors.green : Colors.orange, size: 22)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF0F172A))),
                    Text(done ? 'Uploaded' : 'Not uploaded yet',
                        style: TextStyle(
                            fontSize: 11,
                            color: done ? Colors.green : Colors.orange)),
                  ])),
              if (done)
                IconButton(
                    icon: const Icon(Icons.visibility_rounded,
                        size: 20, color: Colors.blue),
                    onPressed: () => viewDoc(path, label)),
              IconButton(
                  icon: Icon(
                      done ? Icons.refresh_rounded : Icons.upload_file_rounded,
                      size: 20,
                      color: done ? Colors.green : Colors.orange),
                  onPressed: () => pickDoc(type)),
            ]));
      }

      return ListView(padding: const EdgeInsets.all(20), children: [
        const Text("My Profile",
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        Text(
            userProfile.companyName.isNotEmpty
                ? userProfile.companyName
                : userProfile.phone,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        const SizedBox(height: 20),
        GestureDetector(
            onTap: () => _showDriverSalarySheet(driverEntry),
            child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [Color(0xFF0EA5E9), Color(0xFF10B981)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  const Icon(Icons.payments_rounded,
                      color: Colors.white, size: 32),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text("Salary Balance",
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12)),
                        Text("Rs. ${balance.toStringAsFixed(0)}",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 26)),
                        Text(
                            "Earned Rs. ${earned.toStringAsFixed(0)}  |  Deducted Rs. ${deducted.toStringAsFixed(0)}",
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ])),
                  const Column(children: [
                    Icon(Icons.arrow_forward_ios,
                        color: Colors.white70, size: 14),
                    SizedBox(height: 4),
                    Text('View Ledger',
                        style: TextStyle(color: Colors.white70, fontSize: 10))
                  ]),
                ]))),
        const Text("My Documents",
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A))),
        const SizedBox(height: 4),
        const Text("Shared with your fleet owner automatically.",
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        const SizedBox(height: 12),
        docTile("Selfie / Photo", "selfie", selfieP, Icons.camera_alt_rounded),
        docTile("Aadhaar Card", "aadhaar", aadhaarP, Icons.credit_card_rounded),
        docTile("Driving Licence (DL)", "dl", dlP, Icons.drive_eta_rounded),
        const SizedBox(height: 24),
        GestureDetector(
            onTap: () => showDialog(
                context: context,
                builder: (dc) => AlertDialog(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                        title: const Row(children: [
                          Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
                          SizedBox(width: 10),
                          Text("Sign Out",
                              style: TextStyle(fontWeight: FontWeight.w900))
                        ]),
                        content: const Text("You will be signed out."),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(dc),
                              child: const Text("Cancel")),
                          ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626)),
                              onPressed: () async {
                                Navigator.pop(dc);
                                try {
                                  await FirebaseService.auth.signOut();
                                } catch (_) {}
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.remove('rm_fleet_owner_uid');
                                await prefs.setBool('rm_session_active', false);
                                if (!mounted) return;
                                Navigator.of(context).pushAndRemoveUntil(
                                    MaterialPageRoute(
                                        builder: (_) => const LoginScreen()),
                                    (_) => false);
                              },
                              child: const Text("Sign Out",
                                  style: TextStyle(color: Colors.white))),
                        ])),
            child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.3))),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout_rounded,
                          color: Color(0xFFDC2626), size: 18),
                      SizedBox(width: 8),
                      Text("Sign Out",
                          style: TextStyle(
                              color: Color(0xFFDC2626),
                              fontWeight: FontWeight.w800,
                              fontSize: 15)),
                    ]))),
      ]);
    });
  }

  Future<void> _resyncAllDriversToPublic() async {
    final uid = FirebaseService.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    int count = 0;
    for (final d in drivers) {
      if (d.phone.isEmpty) continue;
      if (d.fleetOwnerUid == null || d.fleetOwnerUid!.isEmpty) {
        d.fleetOwnerUid = uid;
      }
      final cp = d.phone.replaceAll(RegExp(r'\D'), '');
      final l10 = cp.length >= 10 ? cp.substring(cp.length - 10) : cp;
      await FirebaseFirestore.instance
          .collection('publicDrivers')
          .doc(l10)
          .set({
        'phone': l10,
        'name': d.name,
        'fleetOwnerUid': uid,
        'license': d.dlNum,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('drivers')
          .doc(d.id)
          .set(d.toJson(), SetOptions(merge: true))
          .ignore();
      count++;
    }
    _save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        content: Text(
            "$count driver${count == 1 ? '' : 's'} synced! Ask them to log out and back in.")));
  }
} // end _MainShellState

// ================================================================
// CITY SEARCH FIELD
// ================================================================
// ================================================================
// FACTORY SEARCH FIELD - Google Places autocomplete for factories/plants
// ================================================================
