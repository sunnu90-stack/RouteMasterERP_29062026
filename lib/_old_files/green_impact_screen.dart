part of 'package:liquid_logistics/main.dart';

// ============================================================
// GREEN IMPACT TRACKER — NavGati ERP v5.0
// Tracks ALL paper-saving and carbon-reducing features:
//   - LR / Lorry Receipts (digital vs paper)
//   - GST Tax Invoices generated
//   - AI Finance / Audit Reports exported as PDF
//   - Bank Statement Reconciliation (digital matching)
//   - E-Way Bills (digital vs paper)
//   - Maintenance Tickets (digital logs)
//   - Compliance Vault docs (digital storage)
//   - AI Control Tower queries (vs phone calls / manual work)
// ============================================================

// ── Theme tokens ─────────────────────────────────────────────
const _scaffold = Color(0xFF0D1F14);
const _card = Color(0xFF1A3A2A);
const _input = Color(0xFF243D2E);
const _primary = Color(0xFF3D7A52);
const _accent = Color(0xFF52A06A);
const _sage = Color(0xFF8FBC8F);
const _tan = Color(0xFFC4A882);
const _cream = Color(0xFFF2EDE4);
const _muted = Color(0xFF6B9E7A);
const _border = Color(0xFF2E5C3E);
const _gold = Color(0xFFD4AC5A);
const _red = Color(0xFFE57373);
const _teal = Color(0xFF4DB6AC);
const _indigo = Color(0xFF7986CB);

// ── Emission factors (MoRTH India) ───────────────────────────
const double _treeAbsorbYear = 21.0;

// ── Paper CO₂ constants ──────────────────────────────────────
// Based on: 1 A4 sheet = ~10g CO₂ (paper production + printing)
const double _gramsPerSheet = 10.0; // g CO₂ per A4 sheet
const double _lrSheets = 3.0; // LR set: 3 copies × 1 sheet each
const double _invoiceSheets = 2.0; // Invoice: original + copy
const double _auditSheets = 8.0; // Audit/finance report: ~8 pages
const double _reconcileSheets = 4.0; // Bank recon statement: ~4 pages
const double _ewaySheets = 2.0; // E-way bill printout: 2 pages
const double _maintSheets = 1.5; // Maintenance job card: 1-2 pages
const double _complianceSheets = 1.0; // Doc stored digitally vs photocopy

// ── State-wise diesel fallback (₹/litre) ─────────────────────
const Map<String, double> _stateDiesel = {
  'Maharashtra': 99.99,
  'Gujarat': 98.88,
  'Delhi': 95.62,
  'Karnataka': 98.55,
  'Tamil Nadu': 101.22,
  'West Bengal': 102.33,
  'Rajasthan': 101.10,
  'Madhya Pradesh': 100.00,
  'Uttar Pradesh': 98.55,
  'Punjab': 96.52,
  'Haryana': 98.00,
  'Telangana': 101.25,
  'Andhra Pradesh': 103.35,
  'Odisha': 101.27,
  'Bihar': 100.88,
  'Jharkhand': 101.85,
  'Chhattisgarh': 99.89,
  'Assam': 96.75,
};
const double _dieselFallback = 98.0;

// ── Impact model ──────────────────────────────────────────────
class _Impact {
  // Transport savings
  final double routeCo2;
  final double emptyCo2;
  final double routeKmSaved;
  final double dieselSaved;
  final double fuelSavingRs;
  // Paper savings (all in kg CO₂)
  final double lrPaperCo2;
  final double invoicePaperCo2;
  final double auditPaperCo2;
  final double reconcilePaperCo2;
  final double ewayPaperCo2;
  final double maintPaperCo2;
  final double compliancePaperCo2;
  // Counts
  final int trips;
  final int lrs;
  final int invoices;
  final int auditReports;
  final int reconciliations;
  final int ewayBills;
  final int maintTickets;
  final int complianceDocs;
  final int last30Days;
  final int aiQueries; // AI queries = replaced phone calls

  const _Impact({
    required this.routeCo2,
    required this.emptyCo2,
    required this.routeKmSaved,
    required this.dieselSaved,
    required this.fuelSavingRs,
    required this.lrPaperCo2,
    required this.invoicePaperCo2,
    required this.auditPaperCo2,
    required this.reconcilePaperCo2,
    required this.ewayPaperCo2,
    required this.maintPaperCo2,
    required this.compliancePaperCo2,
    required this.trips,
    required this.lrs,
    required this.invoices,
    required this.auditReports,
    required this.reconciliations,
    required this.ewayBills,
    required this.maintTickets,
    required this.complianceDocs,
    required this.last30Days,
    required this.aiQueries,
  });

  double get totalPaperCo2 =>
      lrPaperCo2 +
      invoicePaperCo2 +
      auditPaperCo2 +
      reconcilePaperCo2 +
      ewayPaperCo2 +
      maintPaperCo2 +
      compliancePaperCo2;

  double get totalCo2 => routeCo2 + emptyCo2 + totalPaperCo2;
  double get treesEq => totalCo2 / _treeAbsorbYear;

  // Total paper sheets saved
  int get totalSheetsSaved => (lrs * _lrSheets +
          invoices * _invoiceSheets +
          auditReports * _auditSheets +
          reconciliations * _reconcileSheets +
          ewayBills * _ewaySheets +
          maintTickets * _maintSheets +
          complianceDocs * _complianceSheets)
      .round();
}

double _gCo2(int count, double sheetsPerDoc) =>
    count * sheetsPerDoc * _gramsPerSheet / 1000; // → kg

_Impact _calculate(
    List<Map<String, dynamic>> ledgers,
    List<Map<String, dynamic>> bankEntries,
    List<Map<String, dynamic>> maintTickets,
    List<Map<String, dynamic>> complianceDocs,
    int aiQueryCount,
    {double dieselPrice = _dieselFallback}) {
  double routeCo2 = 0, routeKmSaved = 0, dieselSaved = 0;
  int lrs = 0, invoices = 0, ewayBills = 0, last30 = 0;

  final cutoff = DateTime.now().subtract(const Duration(days: 30));

  for (final d in ledgers) {
    final dateStr = (d['date'] as String?) ?? '';

    // 30-day count
    if (dateStr.length >= 8) {
      try {
        final p = dateStr.split('/');
        if (p.length == 3) {
          final dt =
              DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
          if (dt.isAfter(cutoff)) last30++;
        }
      } catch (_) {}
    }

    routeKmSaved += (d['routeDistanceSavedKm'] as num?)?.toDouble() ?? 0;
    dieselSaved += (d['routeDieselSavedL'] as num?)?.toDouble() ?? 0;
    routeCo2 += (d['routeCo2SavedKg'] as num?)?.toDouble() ?? 0;

    // Count document types per trip
    // LR: every trip has an LR
    lrs++;
    // Invoice: trips with materialInvoiceNo or invoiceItems
    if ((d['materialInvoiceNo'] as String? ?? '').isNotEmpty ||
        ((d['invoiceItems'] as List?)?.isNotEmpty ?? false)) {
      invoices++;
    }
    // E-way bill
    final eWay = (d['eWayBillNo'] as String?) ?? '';
    if (eWay.isNotEmpty && eWay != 'PENDING') ewayBills++;
  }

  // Audit reports: count from Firestore bankEntries as proxy
  // (each reconciliation session = 1 audit report generated)
  final reconciledEntries =
      bankEntries.where((e) => e['isMatched'] == true).length;
  final reconcileSessions =
      (reconciledEntries / 10).ceil(); // ~10 entries per session

  final fuelSavingRs = dieselSaved * dieselPrice;

  return _Impact(
    routeCo2: routeCo2,
    emptyCo2: 0,
    routeKmSaved: routeKmSaved,
    dieselSaved: dieselSaved,
    fuelSavingRs: fuelSavingRs,
    lrPaperCo2: _gCo2(lrs, _lrSheets),
    invoicePaperCo2: _gCo2(invoices, _invoiceSheets),
    auditPaperCo2: _gCo2(reconcileSessions, _auditSheets),
    reconcilePaperCo2: _gCo2(reconciledEntries, _reconcileSheets),
    ewayPaperCo2: _gCo2(ewayBills, _ewaySheets),
    maintPaperCo2: _gCo2(maintTickets.length, _maintSheets),
    compliancePaperCo2: _gCo2(complianceDocs.length, _complianceSheets),
    trips: ledgers.length,
    lrs: lrs,
    invoices: invoices,
    auditReports: reconcileSessions,
    reconciliations: reconciledEntries,
    ewayBills: ewayBills,
    maintTickets: maintTickets.length,
    complianceDocs: complianceDocs.length,
    last30Days: last30,
    aiQueries: aiQueryCount,
  );
}

// ═══════════════════════════════════════════════════════════════
class GreenImpactScreen extends StatefulWidget {
  const GreenImpactScreen({super.key});
  @override
  State<GreenImpactScreen> createState() => _GreenImpactScreenState();
}

class _GreenImpactScreenState extends State<GreenImpactScreen>
    with TickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;
  String? _error;
  _Impact? _impact;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ledgerSubscription;
  double _dieselUsed = _dieselFallback;
  String _dieselSource = 'National avg';

  late AnimationController _animCtrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _anim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _load();
  }

  @override
  void dispose() {
    unawaited(_ledgerSubscription?.cancel());
    _tabs.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('Not signed in');

      final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

      // Fetch all collections in parallel
      final results = await Future.wait([
        userRef.collection('ledgers').get(),
        userRef.collection('bankEntries').get(),
        userRef.collection('maintenanceTickets').get(),
        userRef.collection('complianceVault').get(),
      ]);

      final ledgers = results[0].docs.map((d) => d.data()).toList();
      final bankEnts = results[1].docs.map((d) => d.data()).toList();
      final maint = results[2].docs.map((d) => d.data()).toList();
      final compliance = results[3].docs.map((d) => d.data()).toList();

      // AI query count from user profile
      int aiQueries = 0;
      try {
        final profile = await userRef.get();
        aiQueries = (profile.data()?['aiQueryCount'] as num?)?.toInt() ?? 0;
      } catch (_) {}

      // Diesel price
      final stateCounts = <String, int>{};
      for (final d in ledgers) {
        final s = (d['loadingState'] as String?) ?? '';
        if (s.isNotEmpty) stateCounts[s] = (stateCounts[s] ?? 0) + 1;
      }
      final topState = stateCounts.isEmpty
          ? ''
          : stateCounts.entries
              .reduce((a, b) => a.value >= b.value ? a : b)
              .key;

      double dp = _stateDiesel[topState] ?? _dieselFallback;
      String ds = topState.isNotEmpty ? topState : 'National avg';
      try {
        final q = topState.isNotEmpty
            ? 'diesel price per litre today $topState India'
            : 'diesel price per litre today India';
        final uri = Uri.parse(
            'https://www.google.com/search?q=${Uri.encodeComponent(q)}');
        final res = await http.get(uri, headers: {
          'User-Agent': 'Mozilla/5.0'
        }).timeout(const Duration(seconds: 6));
        final m = RegExp(r'₹\s*(\d{2,3}(?:\.\d{1,2})?)').firstMatch(res.body);
        if (m != null) {
          final p = double.tryParse(m.group(1) ?? '');
          if (p != null && p > 50 && p < 200) {
            dp = p;
            ds = '${topState.isNotEmpty ? topState : "India"} (live)';
          }
        }
      } catch (_) {}

      final impact = _calculate(ledgers, bankEnts, maint, compliance, aiQueries,
          dieselPrice: dp);

      if (mounted) {
        setState(() {
          _impact = impact;
          _dieselUsed = dp;
          _dieselSource = ds;
          _loading = false;
        });
        _animCtrl.reset();
        _animCtrl.forward();
      }

      // Real-time ledger stream
      await _ledgerSubscription?.cancel();
      _ledgerSubscription =
          userRef.collection('ledgers').snapshots().listen((snap) {
        if (!mounted) return;
        final live = snap.docs.map((d) => d.data()).toList();
        setState(() => _impact = _calculate(
            live, bankEnts, maint, compliance, aiQueries,
            dieselPrice: dp));
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffold,
      appBar: AppBar(
        backgroundColor: _card,
        foregroundColor: _cream,
        elevation: 0,
        title: Row(children: [
          const Text('🌿', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          const Text('Green Impact',
              style: TextStyle(
                  color: _cream,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ]),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: _accent,
          labelColor: _accent,
          unselectedLabelColor: _muted,
          tabs: const [
            Tab(text: '📊 Impact'),
            Tab(text: '📄 Paper'),
            Tab(text: '📋 Report')
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabs,
                  children: [_buildImpact(), _buildPaper(), _buildReport()]),
    );
  }

  Widget _buildError() => Center(
          child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.warning_amber_rounded, color: _red, size: 48),
          const SizedBox(height: 16),
          const Text('Could not load data',
              style: TextStyle(
                  color: _cream, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(_error!,
              style: const TextStyle(color: _muted, fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _primary, foregroundColor: _cream)),
        ]),
      ));

  // ── TAB 1: IMPACT ─────────────────────────────────────────
  Widget _buildImpact() {
    final imp = _impact!;
    return RefreshIndicator(
      color: _accent,
      backgroundColor: _card,
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_primary, _accent]),
              borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            const Text('🌱', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('${imp.trips} trips · ${imp.last30Days} in last 30 days',
                      style: const TextStyle(
                          color: _cream,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  Text(
                      'Diesel ₹${_dieselUsed.toStringAsFixed(1)}/L ($_dieselSource) · Pull to refresh',
                      style: TextStyle(
                          color: _cream.withValues(alpha: 0.8), fontSize: 11)),
                ])),
          ]),
        ),
        const SizedBox(height: 16),

        _animCard(
            icon: '💨',
            label: 'Total CO₂ Saved',
            value: '${imp.totalCo2.toStringAsFixed(1)} kg',
            sub: 'transport + all paperless operations',
            color: _accent),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _animCard(
                  icon: '🌳',
                  label: 'Trees Equivalent',
                  value: imp.treesEq.toStringAsFixed(1),
                  sub: 'absorbing for 1 year',
                  color: _sage,
                  small: true)),
          const SizedBox(width: 12),
          Expanded(
              child: _animCard(
                  icon: '🛣️',
                  label: 'Route Distance Saved',
                  value: '${imp.routeKmSaved.toStringAsFixed(1)} km',
                  sub: 'from accepted live-route suggestions',
                  color: _tan,
                  small: true)),
        ]),
        const SizedBox(height: 12),
        _animCard(
            icon: '⛽',
            label: 'Diesel Saved',
            value: '${imp.dieselSaved.toStringAsFixed(1)} L',
            sub: 'estimated from saved km and trip mileage',
            color: _tan),
        const SizedBox(height: 12),
        _animCard(
            icon: '🏷️',
            label: 'Potential Carbon Credit Equivalent',
            value: '${(imp.routeCo2 / 1000).toStringAsFixed(4)} tCO₂e',
            sub:
                'Estimate only; credits require independent verification and registry issuance',
            color: _accent),
        const SizedBox(height: 12),
        _animCard(
            icon: '💰',
            label: 'Fuel Cost Saved',
            value: '₹${imp.fuelSavingRs.toStringAsFixed(0)}',
            sub: 'at ₹${_dieselUsed.toStringAsFixed(1)}/L · $_dieselSource',
            color: _gold),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
              child: _animCard(
                  icon: '📄',
                  label: 'Sheets Saved',
                  value: '${imp.totalSheetsSaved}',
                  sub: 'A4 sheets not printed',
                  color: _teal,
                  small: true)),
          const SizedBox(width: 12),
          Expanded(
              child: _animCard(
                  icon: '🤖',
                  label: 'AI Queries',
                  value: '${imp.aiQueries}',
                  sub: 'decisions via AI vs calls',
                  color: _indigo,
                  small: true)),
        ]),

        const SizedBox(height: 20),
        const Text('CO₂ Breakdown',
            style: TextStyle(
                color: _cream, fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 10),
        _breakdownBar(
            'Route Optimisation', imp.routeCo2, imp.totalCo2, _accent),
        const SizedBox(height: 8),
        _breakdownBar(
            'Paperless Documents', imp.totalPaperCo2, imp.totalCo2, _teal),

        const SizedBox(height: 20),
        const Text('Applicable Schemes',
            style: TextStyle(
                color: _cream, fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 8),
        _schemeRow(
            '🇮🇳 Startup India', 'DPIIT sustainability track recognition'),
        _schemeRow('🌿 MoEFCC', 'Voluntary carbon credit market eligibility'),
        _schemeRow('💻 NASSCOM', 'GreenTech logistics startup programme'),
        _schemeRow('🚛 MoRTH', 'Green freight corridor initiative'),
        _schemeRow('📊 SEBI', 'ESG reporting for Business/Enterprise clients'),
        const SizedBox(height: 16),
      ]),
    );
  }

  // ── TAB 2: PAPER SAVINGS DETAIL ───────────────────────────
  Widget _buildPaper() {
    final imp = _impact!;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border)),
        child: Column(children: [
          Row(children: [
            const Text('📄', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Text('Paperless Operations',
                style: TextStyle(
                    color: _cream, fontWeight: FontWeight.w700, fontSize: 15)),
            const Spacer(),
            Text('${imp.totalPaperCo2.toStringAsFixed(2)} kg CO₂',
                style: TextStyle(
                    color: _teal, fontWeight: FontWeight.w700, fontSize: 13)),
          ]),
          const SizedBox(height: 4),
          Text(
              '${imp.totalSheetsSaved} A4 sheets · ${(imp.totalSheetsSaved * 10 / 1000).toStringAsFixed(2)} kg paper saved',
              style: TextStyle(color: _muted, fontSize: 11)),
        ]),
      ),
      const SizedBox(height: 12),
      _paperCard(
        icon: '🧾',
        color: _accent,
        label: 'Lorry Receipts (LR)',
        count: imp.lrs,
        sheets: _lrSheets,
        co2: imp.lrPaperCo2,
        detail:
            'Each LR traditionally printed in 3 copies (consignor, transporter, driver). '
            'Your digital LRs eliminate all paper copies.',
      ),
      _paperCard(
        icon: '🧾',
        color: _gold,
        label: 'GST Tax Invoices',
        count: imp.invoices,
        sheets: _invoiceSheets,
        co2: imp.invoicePaperCo2,
        detail:
            'Each invoice has an original + copy traditionally printed and signed. '
            'Digital invoices via NavGati ERP eliminate both.',
      ),
      _paperCard(
        icon: '📊',
        color: _indigo,
        label: 'Audit / Finance Reports',
        count: imp.auditReports,
        sheets: _auditSheets,
        co2: imp.auditPaperCo2,
        detail:
            'AI-generated finance reports replace printed audit packets (~8 pages each). '
            'Exported as PDF only, never printed.',
      ),
      _paperCard(
        icon: '🏦',
        color: _teal,
        label: 'Bank Reconciliation',
        count: imp.reconciliations,
        sheets: _reconcileSheets,
        co2: imp.reconcilePaperCo2,
        detail:
            'Traditional bank reconciliation involves printing bank statements and ledgers. '
            'Digital auto-matching saves ~4 pages per matched entry.',
      ),
      _paperCard(
        icon: '📋',
        color: _sage,
        label: 'E-Way Bills',
        count: imp.ewayBills,
        sheets: _ewaySheets,
        co2: imp.ewayPaperCo2,
        detail:
            'E-way bills are legally generated digitally but often printed for verification. '
            'Your app tracks them digitally, eliminating print copies.',
      ),
      _paperCard(
        icon: '🔧',
        color: _tan,
        label: 'Maintenance Tickets',
        count: imp.maintTickets,
        sheets: _maintSheets,
        co2: imp.maintPaperCo2,
        detail:
            'Traditional fleet maintenance uses paper job cards (1-2 pages each). '
            'Digital tickets in NavGati ERP replace all paper logging.',
      ),
      _paperCard(
        icon: '📁',
        color: _red,
        label: 'Compliance Vault Docs',
        count: imp.complianceDocs,
        sheets: _complianceSheets,
        co2: imp.compliancePaperCo2,
        detail: 'RC, insurance, fitness, PUC certs stored digitally. '
            'Eliminates physical document files and photocopies.',
      ),
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('💡 More Green Features in Your App',
              style: TextStyle(
                  color: _gold, fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 10),
          _featureRow('🤖 AI Control Tower',
              '${imp.aiQueries} queries saved manual calls & paperwork'),
          _featureRow('📍 Live Tracking',
              'GPS reduces wait time → less idling → less CO₂'),
          _featureRow('🔗 Load Marketplace',
              'Empty run matching → ${imp.emptyCo2.toStringAsFixed(1)} kg CO₂ saved'),
          _featureRow('📱 Driver App',
              'Digital POD eliminates paper proof-of-delivery'),
          _featureRow('🏦 KredX Financing',
              'Digital invoice discounting replaces paper applications'),
          _featureRow('📤 Tally Export',
              'One-click digital export → no printed ledgers'),
          _featureRow('🌍 Multi-language',
              'Digital comms in 6 languages → no printed translations'),
        ]),
      ),
      const SizedBox(height: 16),
    ]);
  }

  Widget _paperCard(
      {required String icon,
      required Color color,
      required String label,
      required int count,
      required double sheets,
      required double co2,
      required String detail}) {
    if (count == 0) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(icon, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          color: _cream,
                          fontWeight: FontWeight.w600,
                          fontSize: 13))),
              Text('${co2.toStringAsFixed(3)} kg CO₂',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              const SizedBox(width: 26),
              _chip('$count docs', _muted),
              const SizedBox(width: 6),
              _chip('${(count * sheets).round()} sheets saved', color),
              const SizedBox(width: 6),
              _chip(
                  '${(count * sheets * _gramsPerSheet / 1000).toStringAsFixed(3)} kg paper',
                  _tan),
            ]),
            const SizedBox(height: 8),
            Text(detail,
                style: TextStyle(color: _muted, fontSize: 11, height: 1.5)),
          ]),
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );

  Widget _featureRow(String icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.4))),
        ]),
      );

  // ── TAB 3: REPORT ─────────────────────────────────────────
  Widget _buildReport() {
    final imp = _impact!;
    final now = DateTime.now();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('🌿', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Green Impact Report',
                  style: TextStyle(
                      color: _cream,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              Text('NavGati ERP  ·  FY ${now.year}',
                  style: const TextStyle(color: _muted, fontSize: 12)),
            ]),
          ]),
          const SizedBox(height: 14),
          Divider(color: _border),
          const SizedBox(height: 10),
          _rSec('TRANSPORT'),
          _rRow('Total Trips (lifetime)', '${imp.trips}'),
          _rRow('Trips in last 30 days', '${imp.last30Days}'),
          _rRow('Route Optimisation CO₂',
              '${imp.routeCo2.toStringAsFixed(2)} kg'),
          _rRow('Empty Run Reduction CO₂',
              '${imp.emptyCo2.toStringAsFixed(2)} kg'),
          _rRow('Diesel Saved', '${imp.dieselSaved.toStringAsFixed(1)} L'),
          _rRow('Fuel Cost Saved', '₹${imp.fuelSavingRs.toStringAsFixed(0)}'),
          _rRow('Diesel Price Used',
              '₹${_dieselUsed.toStringAsFixed(2)}/L ($_dieselSource)'),
          const SizedBox(height: 10),
          Divider(color: _border),
          const SizedBox(height: 10),
          _rSec('PAPERLESS OPERATIONS'),
          _rRow('Digital LRs',
              '${imp.lrs} docs → ${(imp.lrs * _lrSheets).round()} sheets'),
          _rRow('GST Invoices',
              '${imp.invoices} docs → ${(imp.invoices * _invoiceSheets).round()} sheets'),
          _rRow('Audit/Finance Reports',
              '${imp.auditReports} reports → ${(imp.auditReports * _auditSheets).round()} sheets'),
          _rRow('Bank Reconciliations',
              '${imp.reconciliations} entries → ${(imp.reconciliations * _reconcileSheets).round()} sheets'),
          _rRow('E-Way Bills',
              '${imp.ewayBills} bills → ${(imp.ewayBills * _ewaySheets).round()} sheets'),
          _rRow('Maintenance Tickets',
              '${imp.maintTickets} tickets → ${(imp.maintTickets * _maintSheets).round()} sheets'),
          _rRow('Compliance Docs (Vault)',
              '${imp.complianceDocs} docs → ${(imp.complianceDocs * _complianceSheets).round()} sheets'),
          _rRow('Total Sheets Saved', '${imp.totalSheetsSaved} A4 sheets'),
          _rRow(
              'Paper CO₂ Saved', '${imp.totalPaperCo2.toStringAsFixed(3)} kg'),
          const SizedBox(height: 10),
          Divider(color: _border),
          const SizedBox(height: 10),
          _rSec('TOTAL IMPACT'),
          _rRow('Total CO₂ Avoided', '${imp.totalCo2.toStringAsFixed(2)} kg',
              highlight: true),
          _rRow('Equivalent Trees (1 yr)', imp.treesEq.toStringAsFixed(2),
              highlight: true),
          _rRow('AI Control Tower Queries', '${imp.aiQueries}'),
          const SizedBox(height: 14),
          Divider(color: _border),
          const SizedBox(height: 8),
          const Text(
            'Sources: MoRTH emission factors · IRTS empty-run benchmark · IPCC AR6 tree absorption · '
            'Paper CO₂: WRAP UK (10g CO₂/A4 sheet) · Diesel: live Google · state-wise fallback',
            style: TextStyle(color: _muted, fontSize: 10, height: 1.5),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: _copyReport,
        icon: const Icon(Icons.copy_rounded),
        label: const Text('Copy Report to Clipboard'),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: _cream,
          minimumSize: const Size(double.infinity, 48),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      const SizedBox(height: 24),
    ]);
  }

  Widget _rSec(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label,
            style: TextStyle(
                color: _gold,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
      );

  Widget _rRow(String label, String value, {bool highlight = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child:
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
          Text(value,
              style: TextStyle(
                  color: highlight ? _accent : _cream,
                  fontSize: 12,
                  fontWeight: highlight ? FontWeight.w800 : FontWeight.w600)),
        ]),
      );

  void _copyReport() {
    final imp = _impact!;
    final now = DateTime.now();
    Clipboard.setData(ClipboardData(text: '''
GREEN IMPACT REPORT — NavGati ERP FY ${now.year}
Generated: ${now.day}/${now.month}/${now.year}
================================================
TRANSPORT
  Total trips (lifetime)    : ${imp.trips}
  Trips last 30 days        : ${imp.last30Days}
  Route optimisation CO₂    : ${imp.routeCo2.toStringAsFixed(2)} kg
  Route distance saved      : ${imp.routeKmSaved.toStringAsFixed(1)} km
  Diesel saved              : ${imp.dieselSaved.toStringAsFixed(1)} L
  Potential credit equivalent: ${(imp.routeCo2 / 1000).toStringAsFixed(4)} tCO2e (estimate only; not issued/verified)
  Fuel cost saved           : ₹${imp.fuelSavingRs.toStringAsFixed(0)}
  Diesel rate               : ₹${_dieselUsed.toStringAsFixed(2)}/L ($_dieselSource)

PAPERLESS OPERATIONS
  Digital LRs               : ${imp.lrs} → ${(imp.lrs * _lrSheets).round()} sheets
  GST Invoices              : ${imp.invoices} → ${(imp.invoices * _invoiceSheets).round()} sheets
  Audit/Finance Reports     : ${imp.auditReports} → ${(imp.auditReports * _auditSheets).round()} sheets
  Bank Reconciliations      : ${imp.reconciliations} → ${(imp.reconciliations * _reconcileSheets).round()} sheets
  E-Way Bills               : ${imp.ewayBills} → ${(imp.ewayBills * _ewaySheets).round()} sheets
  Maintenance Tickets       : ${imp.maintTickets} → ${(imp.maintTickets * _maintSheets).round()} sheets
  Compliance Vault Docs     : ${imp.complianceDocs} → ${(imp.complianceDocs * _complianceSheets).round()} sheets
  Total sheets saved        : ${imp.totalSheetsSaved} A4 sheets
  Paper CO₂ saved           : ${imp.totalPaperCo2.toStringAsFixed(3)} kg

TOTAL IMPACT
  Total CO₂ avoided         : ${imp.totalCo2.toStringAsFixed(2)} kg
  Equivalent trees (1 yr)   : ${imp.treesEq.toStringAsFixed(2)}
  AI queries (vs calls)     : ${imp.aiQueries}

Sources: MoRTH India, IRTS, IPCC AR6, WRAP UK (10g CO₂/A4)
'''));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Report copied'),
        backgroundColor: _primary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
  }

  // ── Shared widgets ─────────────────────────────────────────
  Widget _animCard(
      {required String icon,
      required String label,
      required String value,
      required String sub,
      required Color color,
      bool small = false}) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Opacity(
        opacity: _anim.value,
        child: Transform.translate(
          offset: Offset(0, 18 * (1 - _anim.value)),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(small ? 12 : 16),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(icon, style: TextStyle(fontSize: small ? 16 : 20)),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(label,
                        style: TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 6),
              FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: TextStyle(
                          color: color,
                          fontSize: small ? 20 : 26,
                          fontWeight: FontWeight.w800))),
              const SizedBox(height: 2),
              Text(sub,
                  style: TextStyle(color: _muted, fontSize: 10),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _breakdownBar(String label, double value, double total, Color color) {
    final pct = total == 0 ? 0.0 : (value / total).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(color: _cream, fontSize: 12)),
        Text('${value.toStringAsFixed(2)} kg',
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 4),
      AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                    value: pct * _anim.value,
                    minHeight: 8,
                    backgroundColor: _input,
                    valueColor: AlwaysStoppedAnimation(color)),
              )),
    ]);
  }

  Widget _schemeRow(String badge, String desc) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(children: [
          Text(badge,
              style: const TextStyle(
                  color: _tan, fontWeight: FontWeight.w600, fontSize: 12)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(desc,
                  style: const TextStyle(color: _muted, fontSize: 12))),
        ]),
      );
}
