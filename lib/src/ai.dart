// ============================================================
// ai.dart  —  part of liquid_logistics main library
// Auto-extracted from main_v23_8.dart (original lines 3899-6610)
// DO NOT add imports here — all imports live in main.dart
// ============================================================
part of 'package:liquid_logistics/main.dart';

enum AiInsightType {
  anomaly,
  overdue,
  duplicate,
  lowMargin,
  reconciled,
  maintenance,
  route,
  ocr
}

enum AiSeverity { info, warning, critical }

class AiInsight {
  final String id, title, body, ledgerId, vehicleNo;
  final AiInsightType type;
  final AiSeverity severity;
  final double? amount;
  final String actionLabel;
  final VoidCallback? onAction;
  bool isDismissed;
  AiInsight({
    required this.id,
    required this.title,
    required this.body,
    this.ledgerId = '',
    this.vehicleNo = '',
    required this.type,
    this.severity = AiSeverity.info,
    this.amount,
    this.actionLabel = '',
    this.onAction,
    this.isDismissed = false,
  });

  Color get severityColor => severity == AiSeverity.critical
      ? const Color(0xFFEF4444)
      : severity == AiSeverity.warning
          ? const Color(0xFFF59E0B)
          : const Color(0xFF0EA5E9);

  IconData get icon {
    switch (type) {
      case AiInsightType.anomaly:
        return Icons.warning_amber_rounded;
      case AiInsightType.overdue:
        return Icons.payment_rounded;
      case AiInsightType.duplicate:
        return Icons.copy_rounded;
      case AiInsightType.lowMargin:
        return Icons.trending_down_rounded;
      case AiInsightType.reconciled:
        return Icons.check_circle_rounded;
      case AiInsightType.maintenance:
        return Icons.build_circle_rounded;
      case AiInsightType.route:
        return Icons.route_rounded;
      case AiInsightType.ocr:
        return Icons.document_scanner_rounded;
    }
  }
}

class AiReconciliationSuggestion {
  final BankEntry bankEntry;
  final TripLedger ledger;
  final double confidence; // 0–1
  final String reason;
  AiReconciliationSuggestion({
    required this.bankEntry,
    required this.ledger,
    required this.confidence,
    required this.reason,
  });
}

class AiMaintenanceForecast {
  final String vehicleNo;
  final String issue;
  final int daysUntilDue;
  final String recommendation;
  final AiSeverity severity;
  AiMaintenanceForecast({
    required this.vehicleNo,
    required this.issue,
    required this.daysUntilDue,
    required this.recommendation,
    this.severity = AiSeverity.info,
  });
}

class AiRouteSuggestion {
  final TripLedger ledger;
  final double suggestedFreight;
  final double marketAvgFreight;
  final double estimatedMargin;
  final String advice;
  AiRouteSuggestion({
    required this.ledger,
    required this.suggestedFreight,
    required this.marketAvgFreight,
    required this.estimatedMargin,
    required this.advice,
  });
}

class AiCopilotMessage {
  final String role; // 'user' | 'ai'
  final String text;
  final DateTime timestamp;
  AiCopilotMessage(
      {required this.role, required this.text, DateTime? timestamp})
      : timestamp = timestamp ?? DateTime.now();
}

// ══════════════════════════════════════════════════════════════════
// AI USAGE GUARD — enforces the per-plan monthly token cap defined in
// AiUsageLimits (config.dart) before any AI provider is called.
// ══════════════════════════════════════════════════════════════════
// The caller passes in the user's current SubscriptionTier (read from
// the app's own `subscription` object — see AiControlTowerScreen and
// the extractTripFromFile call in main_shell.dart) so this never has
// to guess where tier data lives. Usage itself is tracked in its own
// `ai_usage/{uid}` document — a collection this guard fully owns, so
// it never collides with or depends on the rest of your Firestore
// schema:
//   ai_usage/{uid} → { month: "2026-09", tokensUsed: 1234 }
// ══════════════════════════════════════════════════════════════════
class AiUsageGuard {
  static const String _collection = 'ai_usage';

  static String _monthKey(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}';

  /// Atomic check + consume. Returns null (call allowed) or a
  /// user-facing block message. Uses a Firestore transaction so two AI
  /// calls firing close together can't both read the same "used" value
  /// and double-spend past the cap.
  static Future<String?> checkAndConsume(
      int estimatedTokens, SubscriptionTier tier) async {
    final user = FirebaseService.currentUser;
    // Not signed in (shouldn't normally happen this deep in the app) —
    // don't block; there's no account to meter against.
    if (user == null) return null;
    final tokens = estimatedTokens < 1 ? 1 : estimatedTokens;
    final cap = AiUsageLimits.capFor(tier.name);
    final docRef =
        FirebaseFirestore.instance.collection(_collection).doc(user.uid);

    try {
      return await FirebaseFirestore.instance
          .runTransaction<String?>((tx) async {
        final snap = await tx.get(docRef);
        final data = snap.data() ?? <String, dynamic>{};
        final monthKey = _monthKey(DateTime.now());
        final used = data['month'] == monthKey
            ? ((data['tokensUsed'] as num?)?.toInt() ?? 0)
            : 0;
        if (used + tokens > cap) {
          final tierLabel =
              '${tier.name[0].toUpperCase()}${tier.name.substring(1)}';
          return '🚫 Monthly AI limit reached ($used/$cap on your $tierLabel plan). '
              'Upgrade your plan for more AI usage, or it resets next month.';
        }
        tx.set(docRef, {'month': monthKey, 'tokensUsed': used + tokens},
            SetOptions(merge: true));
        return null; // allowed
      });
    } catch (e) {
      // Firestore unreachable — fail OPEN rather than block a paying
      // user over a metering hiccup. Worst case is one uncounted call.
      debugPrint('AiUsageGuard: fail-open ($e)');
      return null;
    }
  }

  /// Returns tokens to the pool when a metered call failed and the app
  /// fell back to the free local engine — so users aren't charged AI
  /// budget for answers the AI never actually produced.
  static Future<void> refund(int tokens) async {
    final user = FirebaseService.currentUser;
    if (user == null || tokens < 1) return;
    final docRef =
        FirebaseFirestore.instance.collection(_collection).doc(user.uid);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        final data = snap.data();
        if (data == null) return;
        if (data['month'] != _monthKey(DateTime.now())) return; // rolled over
        final used = (data['tokensUsed'] as num?)?.toInt() ?? 0;
        final back = tokens > used ? used : tokens;
        if (back > 0) {
          tx.set(docRef, {'tokensUsed': used - back}, SetOptions(merge: true));
        }
      });
    } catch (e) {
      debugPrint('AiUsageGuard: refund failed ($e)');
    }
  }
}

// ── AI Engine Service ────────────────────────────────────────────
class AiEngine {
  static String _localCopilotAnswer({
    required String question,
    required List<TripLedger> ledgers,
    required List<BankEntry> bankEntries,
    required List<MaintenanceTicket> tickets,
    required List<Asset> fleet,
    String reason = '',
  }) {
    final q = question.toLowerCase();
    final pending = ledgers.fold(
        0.0, (s, l) => s + (l.partyPending > 0 ? l.partyPending : 0));
    final revenue = ledgers.fold(0.0, (s, l) => s + l.freightBilled);
    final profit = ledgers.fold(0.0, (s, l) => s + l.tripProfit);
    final expenses = ledgers.fold(
        0.0,
        (s, l) =>
            s +
            (l.ownership == VehicleOwnership.self
                ? l.selfExpenses
                : l.marketTruckFreight));
    final diesel = ledgers.fold(0.0, (s, l) => s + l.diesel);
    final toll = ledgers.fold(0.0, (s, l) => s + l.toll);
    final overdue = ledgers.where((l) => l.isPaymentOverdue).toList()
      ..sort((a, b) => b.partyPending.compareTo(a.partyPending));
    final dueSoon =
        ledgers.where((l) => l.isDueSoon && !l.isPaymentOverdue).toList();
    final lossTrips = ledgers.where((l) => l.tripProfit < 0).toList()
      ..sort((a, b) => a.tripProfit.compareTo(b.tripProfit));
    final openMx = tickets.where((t) => t.status == 'open').toList();
    final unmatched =
        bankEntries.where((e) => e.credit > 0 && !e.isMatched).length;
    final inTransit = ledgers.where((l) => l.isInTransit).toList();

    String fmt(double v) => v >= 100000
        ? 'Rs.${(v / 100000).toStringAsFixed(1)}L'
        : 'Rs.${v.toStringAsFixed(0)}';

    // Keep simple conversational questions useful when the live provider is
    // unavailable instead of returning an unrelated data snapshot.
    if (q.contains('your name') || q.contains('who are you')) {
      return 'I\'m NavGati AI, your transport operations copilot. I can analyse collections, trips, profits, fuel, routes, vehicles, maintenance, and reconciliation.';
    }
    if (q == 'hi' ||
        q == 'hello' ||
        q == 'hey' ||
        q.startsWith('hi ') ||
        q.startsWith('hello ') ||
        q.startsWith('hey ')) {
      return 'Hello! I\'m NavGati AI. Ask me about your trips, collections, profits, vehicles, fuel, or maintenance.';
    }

    // ── Pending / Collections ──────────────────────────────────
    if (q.contains('pending') ||
        q.contains('collection') ||
        q.contains('collect')) {
      final sb = StringBuffer('💰 Collections Summary\n\n');
      sb.writeln('Total pending: ${fmt(pending)}');
      sb.writeln(
          'Overdue: ${overdue.length} trips | Due soon: ${dueSoon.length} trips');
      if (overdue.isNotEmpty) {
        sb.writeln('\n🔴 Call first (highest overdue):');
        for (final l in overdue.take(4)) {
          sb.writeln(
              '• ${l.partyName} — ${fmt(l.partyPending)} (${l.route.split('->').first.trim()})');
        }
      }
      if (dueSoon.isNotEmpty) {
        sb.writeln('\n🟡 Due soon:');
        for (final l in dueSoon.take(3))
          sb.writeln('• ${l.partyName} — ${fmt(l.partyPending)}');
      }
      return sb.toString().trim();
    }

    // ── Overdue ────────────────────────────────────────────────
    if (q.contains('overdue')) {
      if (overdue.isEmpty)
        return '✅ No overdue payments! All collections are on track.';
      final sb = StringBuffer(
          '⚠️ ${overdue.length} overdue payment${overdue.length > 1 ? "s" : ""}\n\n');
      for (final l in overdue.take(6)) {
        sb.writeln(
            '• ${l.partyName}\n  ${l.route}\n  Pending: ${fmt(l.partyPending)} | Date: ${l.date}\n');
      }
      sb.writeln('Action: Call each party and request immediate payment.');
      return sb.toString().trim();
    }

    // ── Profit / Revenue / Finance ─────────────────────────────
    if (q.contains('profit') ||
        q.contains('revenue') ||
        q.contains('finance')) {
      final margin = revenue > 0 ? (profit / revenue * 100) : 0;
      final sb = StringBuffer('📊 Financial Analysis\n\n');
      sb.writeln('Revenue:  ${fmt(revenue)}');
      sb.writeln('Expenses: ${fmt(expenses)}');
      sb.writeln(
          'Profit:   ${fmt(profit)} (${margin.toStringAsFixed(1)}% margin)');
      sb.writeln('\nExpense Breakdown:');
      sb.writeln(
          '  Diesel: ${fmt(diesel)} (${revenue > 0 ? (diesel / revenue * 100).toStringAsFixed(1) : "0"}% of revenue)');
      sb.writeln('  Toll:   ${fmt(toll)}');
      if (lossTrips.isNotEmpty) {
        sb.writeln('\n⚠️ ${lossTrips.length} loss-making trips:');
        for (final l in lossTrips.take(3))
          sb.writeln(
              '• ${l.partyName} (${l.route.split("->").first.trim()}) — loss: ${fmt(l.tripProfit)}');
      }
      return sb.toString().trim();
    }

    // ── Diesel / Fuel ──────────────────────────────────────────
    if (q.contains('diesel') ||
        q.contains('fuel') ||
        q.contains('petrol') ||
        q.contains('mileage') ||
        q.contains('efficiency')) {
      // Use actual fuelEconomy data entered by user per trip
      // Commercial tankers/trucks: realistic range is 3-5 km/L
      final tripsWithMileage = ledgers
          .where((l) =>
              l.fuelEconomy > 0 && l.fuelEconomy < 20 && l.distanceKm > 0)
          .toList();
      final avgMileage = tripsWithMileage.isEmpty
          ? 0.0
          : tripsWithMileage.fold(0.0, (s, l) => s + l.fuelEconomy) /
              tripsWithMileage.length;
      final totalDist = ledgers.fold(0.0, (s, l) => s + l.distanceKm);

      final sb = StringBuffer('⛽ Fuel & Mileage Analysis\n\n');
      sb.writeln('Total diesel spend: ${fmt(diesel)}');
      if (revenue > 0)
        sb.writeln(
            'Diesel as % of revenue: ${(diesel / revenue * 100).toStringAsFixed(1)}%');
      if (totalDist > 0)
        sb.writeln(
            'Total distance covered: ${totalDist.toStringAsFixed(0)} km');
      if (avgMileage > 0) {
        sb.writeln(
            'Avg fuel economy: ${avgMileage.toStringAsFixed(2)} km/L (from ${tripsWithMileage.length} trips)');
        // Flag suspicious values
        if (avgMileage > 8)
          sb.writeln(
              '⚠️ Note: >8 km/L is unusual for commercial trucks — check if mileage data is correct');
      } else {
        sb.writeln(
            'Fuel economy: Not recorded yet — enter km/L in each trip entry for analysis');
      }

      // Per-vehicle breakdown
      final vehicleMap = <String, List<double>>{};
      for (final l in tripsWithMileage) {
        vehicleMap.putIfAbsent(l.vehicleNo, () => []).add(l.fuelEconomy);
      }
      if (vehicleMap.isNotEmpty) {
        final sorted = vehicleMap.entries.toList()
          ..sort((a, b) => (b.value.fold(0.0, (x, y) => x + y) / b.value.length)
              .compareTo(a.value.fold(0.0, (x, y) => x + y) / a.value.length));
        sb.writeln('\nBest mileage vehicles:');
        for (final e in sorted.take(3)) {
          final avg = e.value.fold(0.0, (x, y) => x + y) / e.value.length;
          sb.writeln('• ${e.key}: ${avg.toStringAsFixed(2)} km/L');
        }
        if (sorted.length > 3) {
          sb.writeln('\nLowest mileage (check engine/tyres):');
          for (final e in sorted.reversed.take(3)) {
            final avg = e.value.fold(0.0, (x, y) => x + y) / e.value.length;
            sb.writeln('• ${e.key}: ${avg.toStringAsFixed(2)} km/L');
          }
        }
      }

      // Highest diesel spend trips
      final highDiesel = ledgers.where((l) => l.diesel > 0).toList()
        ..sort((a, b) => b.diesel.compareTo(a.diesel));
      if (highDiesel.isNotEmpty) {
        sb.writeln('\nHighest diesel spend trips:');
        for (final l in highDiesel.take(3))
          sb.writeln('• ${l.route.split("->").first.trim()}: ${fmt(l.diesel)}');
      }
      sb.writeln(
          '\nTips to reduce diesel cost:\n• Tyre pressure check (saves 3-5%)\n• Avoid engine idling\n• Plan routes to avoid congestion\n• Service engine & air filter every 5,000 km\n• Compare mileage across vehicles — poor mileage = engine issue');
      return sb.toString().trim();
    }

    // ── Maintenance / Fleet ─────────────────────────────────────
    if (q.contains('maintenance') ||
        q.contains('repair') ||
        q.contains('fleet') ||
        q.contains('vehicle')) {
      final sb = StringBuffer('🔧 Fleet & Maintenance\n\n');
      sb.writeln('Fleet: ${fleet.length} vehicles');
      sb.writeln('Open maintenance tickets: ${openMx.length}');
      if (openMx.isNotEmpty) {
        sb.writeln('\nPriority repairs:');
        for (final t in openMx.take(4))
          sb.writeln('• ${t.vehicleNo}: ${t.issue}');
      }
      final inTransitVehicles = inTransit.map((l) => l.vehicleNo).toSet();
      if (inTransitVehicles.isNotEmpty) {
        sb.writeln('\nCurrently on road: ${inTransitVehicles.join(", ")}');
      }
      return sb.toString().trim();
    }

    // ── Loss-making trips ──────────────────────────────────────
    if (q.contains('loss') || q.contains('losing')) {
      if (lossTrips.isEmpty)
        return '✅ No loss-making trips! All trips are profitable.';
      final sb =
          StringBuffer('📉 Loss-Making Trips (${lossTrips.length} trips)\n\n');
      for (final l in lossTrips.take(5)) {
        sb.writeln(
            '• ${l.partyName} | ${l.route.split("->").first.trim()} → ${l.route.split("->").last.trim()}');
        sb.writeln(
            '  Freight: ${fmt(l.freightBilled)} | Loss: ${fmt(l.tripProfit)}\n');
      }
      sb.writeln(
          'Action: Review freight rates on these routes. Check if diesel or market truck cost is too high.');
      return sb.toString().trim();
    }

    // ── Top paying party / customer ─────────────────────────────
    if (q.contains('party') ||
        q.contains('customer') ||
        q.contains('client') ||
        q.contains('paying')) {
      final partyStats = <String, Map<String, dynamic>>{};
      for (final l in ledgers) {
        if (l.partyName.isEmpty) continue;
        final p = partyStats.putIfAbsent(l.partyName,
            () => {'trips': 0, 'freight': 0.0, 'profit': 0.0, 'pending': 0.0});
        p['trips'] = (p['trips'] as int) + 1;
        p['freight'] = (p['freight'] as double) + l.freightBilled;
        p['profit'] = (p['profit'] as double) + l.tripProfit;
        p['pending'] = (p['pending'] as double) +
            (l.partyPending > 0 ? l.partyPending : 0);
      }
      if (partyStats.isEmpty) {
        return '🏆 Party Analysis\n\nNo trip data with party names found yet.';
      }
      final sorted = partyStats.entries.toList()
        ..sort((a, b) => (b.value['freight'] as double)
            .compareTo(a.value['freight'] as double));
      final sb = StringBuffer('🏆 Top Paying Parties\n\n');
      for (final e in sorted.take(5)) {
        final v = e.value;
        sb.writeln(
            '• ${e.key}: ${v['trips']} trips | Freight ${fmt(v['freight'] as double)} | Profit ${fmt(v['profit'] as double)}${(v['pending'] as double) > 0 ? " | Pending ${fmt(v['pending'] as double)}" : ""}');
      }
      sb.writeln(
          '\nYour top party by freight billed is ${sorted.first.key} — prioritizing repeat business with your highest payers is usually a safe bet, as long as they also pay on time.');
      return sb.toString().trim();
    }

    // ── Driver performance ────────────────────────────────────
    if (q.contains('driver') ||
        q.contains('best') ||
        q.contains('worst') ||
        q.contains('performance') ||
        q.contains('behaviour') ||
        q.contains('behavior')) {
      // Group trips by driver and compute their stats
      final driverStats = <String, Map<String, dynamic>>{};
      for (final l in ledgers) {
        if (l.driverName == null || l.driverName!.isEmpty) continue;
        final d = driverStats.putIfAbsent(
            l.driverName!,
            () => {
                  'trips': 0,
                  'profit': 0.0,
                  'diesel': 0.0,
                  'freight': 0.0,
                  'lossTrips': 0,
                  'mileageVals': <double>[]
                });
        d['trips'] = (d['trips'] as int) + 1;
        d['profit'] = (d['profit'] as double) + l.tripProfit;
        d['diesel'] = (d['diesel'] as double) + l.diesel;
        d['freight'] = (d['freight'] as double) + l.freightBilled;
        if (l.tripProfit < 0) d['lossTrips'] = (d['lossTrips'] as int) + 1;
        if (l.fuelEconomy > 0 && l.fuelEconomy < 20)
          (d['mileageVals'] as List<double>).add(l.fuelEconomy);
      }
      if (driverStats.isEmpty)
        return '📊 Driver Analysis\n\nNo trip data with driver names found.\nAssign drivers when creating trip entries to enable this analysis.';
      final sb = StringBuffer('👤 Driver Performance Analysis\n\n');
      final sorted = driverStats.entries.toList()
        ..sort((a, b) => (b.value['profit'] as double)
            .compareTo(a.value['profit'] as double));
      sb.writeln('Best performing drivers (by profit):');
      for (final e in sorted.take(3)) {
        final v = e.value;
        final mileageList = v['mileageVals'] as List<double>;
        final avgMile = mileageList.isEmpty
            ? 0.0
            : mileageList.fold(0.0, (a, b) => a + b) / mileageList.length;
        sb.writeln(
            '• ${e.key}: ${v['trips']} trips | Profit ${fmt(v['profit'] as double)} | Diesel ${fmt(v['diesel'] as double)}${avgMile > 0 ? " | ${avgMile.toStringAsFixed(2)} km/L" : ""}');
      }
      if (sorted.length > 3) {
        sb.writeln('\nNeeds improvement:');
        for (final e in sorted.reversed.take(2)) {
          final v = e.value;
          sb.writeln(
              '• ${e.key}: ${v['lossTrips']} loss trips | Diesel ${fmt(v['diesel'] as double)} of ${fmt(v['freight'] as double)} freight');
        }
      }
      return sb.toString().trim();
    }

    // ── Route analysis ──────────────────────────────────────────
    if (q.contains('route') ||
        q.contains('lane') ||
        q.contains('best route') ||
        q.contains('which route')) {
      final routeStats = <String, Map<String, dynamic>>{};
      for (final l in ledgers) {
        final route =
            '${l.route.split("->").first.trim()} → ${l.route.split("->").last.trim()}';
        final r = routeStats.putIfAbsent(route,
            () => {'trips': 0, 'profit': 0.0, 'freight': 0.0, 'diesel': 0.0});
        r['trips'] = (r['trips'] as int) + 1;
        r['profit'] = (r['profit'] as double) + l.tripProfit;
        r['freight'] = (r['freight'] as double) + l.freightBilled;
        r['diesel'] = (r['diesel'] as double) + l.diesel;
      }
      final sorted = routeStats.entries.toList()
        ..sort((a, b) => (b.value['profit'] as double)
            .compareTo(a.value['profit'] as double));
      final sb = StringBuffer('🗺️ Route Analysis\n\n');
      sb.writeln('Most profitable routes:');
      for (final e in sorted.take(4)) {
        final v = e.value;
        final margin = (v['freight'] as double) > 0
            ? (v['profit'] as double) / (v['freight'] as double) * 100
            : 0;
        sb.writeln(
            '• ${e.key}\n  ${v['trips']} trips | Profit ${fmt(v['profit'] as double)} (${margin.toStringAsFixed(0)}% margin)');
      }
      if (sorted.length > 4) {
        sb.writeln('\nLeast profitable routes:');
        for (final e in sorted.reversed.take(2)) {
          sb.writeln('• ${e.key}: Profit ${fmt(e.value['profit'] as double)}');
        }
      }
      return sb.toString().trim();
    }

    // ── Bank / Reconciliation ──────────────────────────────────
    if (q.contains('bank') ||
        q.contains('reconcil') ||
        q.contains('unmatched')) {
      return '🏦 Bank Summary\n\nUnmatched credits: $unmatched entries\nGo to Reconcile tab to match bank entries with trip payments.';
    }

    // ── Default snapshot ───────────────────────────────────────
    final tripsWithFuelData2 =
        ledgers.where((l) => l.fuelEconomy > 0 && l.fuelEconomy < 20).toList();
    final avgFuel2 = tripsWithFuelData2.isEmpty
        ? 0.0
        : tripsWithFuelData2.fold(0.0, (s, l) => s + l.fuelEconomy) /
            tripsWithFuelData2.length;
    final sb = StringBuffer('📋 Fleet Snapshot\n\n');
    sb.writeln('Trips: ${ledgers.length} | In Transit: ${inTransit.length}');
    sb.writeln('Revenue: ${fmt(revenue)} | Profit: ${fmt(profit)}');
    sb.writeln('Pending: ${fmt(pending)} | Overdue: ${overdue.length}');
    sb.writeln(
        'Diesel spend: ${fmt(diesel)} | Total distance: ${ledgers.fold(0.0, (s, l) => s + l.distanceKm).toStringAsFixed(0)} km');
    if (avgFuel2 > 0)
      sb.writeln(
          'Avg mileage: ${avgFuel2.toStringAsFixed(2)} km/L (${tripsWithFuelData2.length} trips)');
    sb.writeln(
        'Fleet: ${fleet.length} vehicles | Open issues: ${openMx.length}');
    if (overdue.isNotEmpty)
      sb.writeln(
          '\n⚠️ ${overdue.length} overdue — call ${overdue.first.partyName} first!');
    return sb.toString().trim();
  }

  // ── MODULE 1: Financial Automation ──────────────────────────
  static List<AiInsight> analyzeFinance({
    required List<TripLedger> ledgers,
    required List<BankEntry> bankEntries,
  }) {
    final insights = <AiInsight>[];
    final now = DateTime.now();

    // 1a. Overdue collections
    for (final l in ledgers) {
      if (l.isPaymentOverdue &&
          l.partyPending > 500 &&
          l.paymentDueDate != null) {
        final daysLate = now.difference(l.paymentDueDate!).inDays;
        insights.add(AiInsight(
          id: 'ovd_${l.id}',
          title: 'Collection Overdue: ${l.partyName}',
          body:
              '₹${l.partyPending.toStringAsFixed(0)} pending for $daysLate days on ${l.vehicleNo}. Route: ${l.route}.',
          ledgerId: l.id,
          vehicleNo: l.vehicleNo,
          type: AiInsightType.overdue,
          severity: daysLate > 30 ? AiSeverity.critical : AiSeverity.warning,
          amount: l.partyPending,
          actionLabel: 'Mark Paid',
        ));
      }
    }

    // 1b. Loss-making trips (including penalty trips)
    for (final l in ledgers) {
      if (l.tripProfit < -2000) {
        final penaltyNote = l.penalties > 0
            ? ' Penalties: ₹${l.penalties.toStringAsFixed(0)}.'
            : '';
        final notesNote = l.lrNotes.isNotEmpty ? '\n${l.lrNotes}' : '';
        insights.add(AiInsight(
          id: 'loss_${l.id}',
          title: 'Loss-Making Trip: ${l.vehicleNo}',
          body:
              '${l.route} shows a loss of ₹${l.tripProfit.abs().toStringAsFixed(0)}.$penaltyNote$notesNote',
          ledgerId: l.id,
          vehicleNo: l.vehicleNo,
          type: AiInsightType.lowMargin,
          severity:
              l.tripProfit < -20000 ? AiSeverity.critical : AiSeverity.warning,
          amount: l.tripProfit,
          actionLabel: 'View Trip',
        ));
      }
    }

    // 1c. Duplicate party / amount detection
    final seen = <String, TripLedger>{};
    for (final l in ledgers) {
      final key =
          '${l.partyName.toLowerCase().trim()}_${l.freightBilled.round()}_${l.date}';
      if (seen.containsKey(key)) {
        insights.add(AiInsight(
          id: 'dup_${l.id}',
          title: 'Possible Duplicate Entry',
          body:
              '${l.partyName} with ₹${l.freightBilled.toStringAsFixed(0)} on ${l.date} appears twice. Verify and remove duplicate.',
          ledgerId: l.id,
          type: AiInsightType.duplicate,
          severity: AiSeverity.warning,
          amount: l.freightBilled,
          actionLabel: 'Review',
        ));
      }
      seen[key] = l;
    }

    // 1d. High diesel spend vs freight (>40% of freight = anomalous)
    for (final l in ledgers) {
      if (l.freightBilled > 0 &&
          l.diesel / l.freightBilled > 0.40 &&
          l.diesel > 5000) {
        insights.add(AiInsight(
          id: 'dsl_${l.id}',
          title: 'High Diesel Spend: ${l.vehicleNo}',
          body:
              'Diesel cost ₹${l.diesel.toStringAsFixed(0)} is ${(l.diesel / l.freightBilled * 100).toStringAsFixed(0)}% of freight for ${l.route}. Possible fuel pilferage or route deviation.',
          ledgerId: l.id,
          vehicleNo: l.vehicleNo,
          type: AiInsightType.anomaly,
          severity: AiSeverity.warning,
          amount: l.diesel,
          actionLabel: 'View Trip',
        ));
      }
    }

    // 1e. Unmatched high-value bank credits
    for (final e in bankEntries) {
      if (e.credit > 10000 && !e.isMatched) {
        insights.add(AiInsight(
          id: 'bank_${e.refNo}',
          title: 'Unreconciled Bank Credit',
          body:
              '₹${e.credit.toStringAsFixed(0)} received on ${e.date} (${e.narration}) has no matching ledger entry. Reconcile to close pending.',
          type: AiInsightType.reconciled,
          severity: AiSeverity.info,
          amount: e.credit,
          actionLabel: 'Reconcile',
        ));
      }
    }

    return insights;
  }

  // ── MODULE 2: Bank Reconciliation AI ─────────────────────────
  static List<AiReconciliationSuggestion> reconcile({
    required List<BankEntry> bankEntries,
    required List<TripLedger> ledgers,
  }) {
    final results = <AiReconciliationSuggestion>[];
    for (final e in bankEntries.where((b) => b.credit > 0 && !b.isMatched)) {
      TripLedger? bestMatch;
      double bestScore = 0;
      String bestReason = '';
      for (final l in ledgers.where((l) => l.partyPending > 0)) {
        double score = 0;
        final reasons = <String>[];
        // Amount match within 2%
        final amtDiff = (e.credit - l.partyPending).abs();
        if (amtDiff < l.partyPending * 0.02) {
          score += 0.5;
          reasons.add('Amount matches ₹${l.partyPending.toStringAsFixed(0)}');
        } else if (amtDiff < l.partyPending * 0.10) {
          score += 0.2;
          reasons.add('Amount close');
        }
        // Party name in narration
        final n = e.narration.toLowerCase();
        final p = l.partyName.toLowerCase();
        if (n.contains(p) ||
            p.split(' ').any((w) => w.length > 3 && n.contains(w))) {
          score += 0.35;
          reasons.add('Party name matches');
        }
        // Vehicle no in narration
        if (n.contains(l.vehicleNo.toLowerCase().replaceAll(' ', ''))) {
          score += 0.15;
          reasons.add('Vehicle no. in narration');
        }
        if (score > bestScore) {
          bestScore = score;
          bestMatch = l;
          bestReason = reasons.join(' • ');
        }
      }
      if (bestMatch != null && bestScore > 0.3) {
        results.add(AiReconciliationSuggestion(
          bankEntry: e,
          ledger: bestMatch,
          confidence: bestScore.clamp(0.0, 1.0),
          reason: bestReason,
        ));
      }
    }
    // Sort by confidence descending
    results.sort((a, b) => b.confidence.compareTo(a.confidence));
    return results;
  }

  // ── MODULE 3: OCR Post-Processing AI ─────────────────────────
  static List<AiInsight> analyzeOcrDocs({
    required List<ComplianceVaultItem> vault,
  }) {
    final insights = <AiInsight>[];
    final now = DateTime.now();
    for (final doc in vault) {
      if (doc.expiryDate.isEmpty) continue;
      try {
        final parts = doc.expiryDate.split('/');
        if (parts.length < 3) continue;
        final expiry = DateTime(
            int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        final daysLeft = expiry.difference(now).inDays;
        if (daysLeft < 0) {
          insights.add(AiInsight(
            id: 'ocr_exp_${doc.id}',
            title: 'Document Expired: ${doc.documentName}',
            body:
                '${doc.vehicleNo} — ${doc.documentName} expired ${(-daysLeft)} days ago. Renew immediately to avoid penalties.',
            vehicleNo: doc.vehicleNo,
            type: AiInsightType.ocr,
            severity: AiSeverity.critical,
            actionLabel: 'Renew',
          ));
        } else if (daysLeft <= 30) {
          insights.add(AiInsight(
            id: 'ocr_due_${doc.id}',
            title: 'Document Expiring Soon: ${doc.documentName}',
            body:
                '${doc.vehicleNo} — ${doc.documentName} expires in $daysLeft days. Schedule renewal to avoid operational disruption.',
            vehicleNo: doc.vehicleNo,
            type: AiInsightType.ocr,
            severity: daysLeft <= 7 ? AiSeverity.critical : AiSeverity.warning,
            actionLabel: 'Schedule Renewal',
          ));
        }
      } catch (_) {}
    }
    return insights;
  }

  // ── MODULE 4: Predictive Maintenance AI ──────────────────────
  static List<AiMaintenanceForecast> predictMaintenance({
    required List<MaintenanceTicket> tickets,
    required List<Asset> fleet,
  }) {
    final forecasts = <AiMaintenanceForecast>[];
    final addedIds = <String>{};

    // 1. All open tickets → show as forecasts immediately
    for (final t in tickets.where((t) => t.status == 'open')) {
      if (addedIds.contains(t.id)) continue;
      addedIds.add(t.id);
      forecasts.add(AiMaintenanceForecast(
        vehicleNo: t.vehicleNo,
        issue: t.issue,
        daysUntilDue: t.isSos ? 0 : (t.isServiceDue ? 0 : 3),
        recommendation: t.issue,
        severity: t.isSos
            ? AiSeverity.critical
            : t.priority == BreakdownPriority.urgent
                ? AiSeverity.warning
                : AiSeverity.info,
      ));
    }

    // 2. Fleet-level predictive checks (odometer based)
    for (final v in fleet) {
      final currentOdo = tickets
          .where((t) => t.vehicleNo == v.number)
          .fold<int>(0, (mx, t) => t.odometerKm > mx ? t.odometerKm : mx);
      final lastServiceOdo = tickets
          .where((t) => t.vehicleNo == v.number && t.status == 'closed')
          .fold<int>(0, (mx, t) => t.odometerKm > mx ? t.odometerKm : mx);
      final kmSinceService = currentOdo - lastServiceOdo;

      if (kmSinceService > 12000) {
        final remaining = 15000 - kmSinceService;
        forecasts.add(AiMaintenanceForecast(
          vehicleNo: v.number,
          issue:
              'Engine Oil & Filter Change Due (${kmSinceService}km since last service)',
          daysUntilDue: (remaining / 250).round().clamp(0, 30),
          recommendation:
              '$kmSinceService km since last oil change. Service interval is 15,000 km. Schedule within ${(remaining / 250).round()} days.',
          severity:
              kmSinceService > 14000 ? AiSeverity.critical : AiSeverity.warning,
        ));
      }
      if (currentOdo > 70000) {
        forecasts.add(AiMaintenanceForecast(
          vehicleNo: v.number,
          issue: 'Tyre Inspection Due (${currentOdo}km total)',
          daysUntilDue: 10,
          recommendation:
              'High mileage vehicle. Schedule tyre depth check and rotation to prevent blowouts.',
          severity: AiSeverity.info,
        ));
      }
    }

    // Sort: critical first, then warning, then info
    forecasts.sort((a, b) => a.severity.index.compareTo(b.severity.index));
    return forecasts;
  }

  // ── MODULE 5: Route & Load Optimization AI ───────────────────
  static List<AiRouteSuggestion> optimizeRoutes({
    required List<TripLedger> ledgers,
    required List<MarketLoad> marketLoads,
  }) {
    final suggestions = <AiRouteSuggestion>[];
    // Group ledgers by route to get average freight
    final routeAvg = <String, List<double>>{};
    for (final l in ledgers) {
      routeAvg.putIfAbsent(l.route, () => []).add(l.freightBilled);
    }
    for (final l
        in ledgers.where((l) => l.tripProfit < l.freightBilled * 0.10)) {
      final avgs = routeAvg[l.route] ?? [l.freightBilled];
      final avg = avgs.reduce((a, b) => a + b) / avgs.length;
      if (l.freightBilled < avg * 0.85 && avg > 0) {
        suggestions.add(AiRouteSuggestion(
          ledger: l,
          suggestedFreight: avg * 1.05,
          marketAvgFreight: avg,
          estimatedMargin: (avg * 1.05) - l.selfExpenses,
          advice:
              'Freight of ₹${l.freightBilled.toStringAsFixed(0)} is below route average of ₹${avg.toStringAsFixed(0)} for ${l.route}. Renegotiate or reject future loads below ₹${(avg * 0.92).toStringAsFixed(0)}.',
        ));
      }
    }
    // Return load suggestions: vehicles that just delivered and have nearby market loads
    for (final load in marketLoads.take(3)) {
      final totalFreight =
          load.targetPrice * (load.weightTons > 0 ? load.weightTons : 1);
      final routeLabel = load.route.isNotEmpty
          ? load.route
          : '${load.originCity} → ${load.destCity}';
      suggestions.add(AiRouteSuggestion(
        ledger: TripLedger(
          id: 'market_${load.id}',
          date: DateTime.now().toString().substring(0, 10),
          partyName: load.details.isNotEmpty
              ? load.details.split(' ').take(3).join(' ')
              : 'Market Load',
          vehicleNo: load.vehicleType,
          route: routeLabel,
          ownership: VehicleOwnership.self,
          freightBilled: totalFreight,
        ),
        suggestedFreight: totalFreight,
        marketAvgFreight: totalFreight,
        estimatedMargin: totalFreight * 0.15,
        advice:
            'Market load available: $routeLabel (${load.materialType}). Estimated margin ₹${(totalFreight * 0.15).toStringAsFixed(0)}. Book before it fills up.',
      ));
    }
    return suggestions;
  }

  // ── Defensive response parsing (handles all provider formats) ──
  // Providers don't all return text in the same JSON shape, and a 200
  // with an unexpected shape was silently collapsing to "empty
  // response" — the root cause of the Copilot showing local fallbacks
  // even when a provider (e.g. Sarvam) genuinely succeeded.
  static Map<String, dynamic>? _tryJsonMap(String body) {
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null; // HTML error pages, empty bodies, etc.
    }
  }

  /// Extract text from a Gemini-format response body. Returns null if
  /// the expected fields aren't present (never throws).
  static String? _extractGeminiText(String body) {
    final data = _tryJsonMap(body);
    if (data == null) return null;
    final candidates = data['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final buf = StringBuffer();
    for (final c in candidates) {
      if (c is! Map) continue;
      final content = c['content'];
      if (content is! Map) continue;
      final parts = content['parts'];
      if (parts is! List) continue;
      for (final p in parts) {
        if (p is Map && p['text'] is String) buf.write(p['text']);
      }
    }
    final s = buf.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Extract text from an OpenAI-compatible response (Groq, Sarvam,
  /// OpenRouter, Pollinations). Checks BOTH message.content AND the
  /// alternate top-level `text` field some providers use. Returns null
  /// if neither is present (never throws).
  static String? _extractOpenAiText(String body) {
    final data = _tryJsonMap(body);
    if (data == null) return null;
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) return null;
    final first = choices.first;
    if (first is! Map) return null;
    final msg = first['message'];
    if (msg is Map && msg['content'] is String) {
      final s = (msg['content'] as String).trim();
      if (s.isNotEmpty) return s;
    }
    final text = first['text'];
    if (text is String && text.trim().isNotEmpty) return text.trim();
    return null;
  }

  // ── Copilot – Real AI via Google Gemini API (free tier) ──────
  /// Builds a rich context string from live fleet data, sends it to
  /// Gemini 2.0 Flash via the Google AI API, and returns the reply.
  /// Falls back to heuristics if the call fails (offline / no key).
  static Future<String> copilotAnswer({
    required String question,
    required List<TripLedger> ledgers,
    required List<BankEntry> bankEntries,
    required List<MaintenanceTicket> tickets,
    required List<Asset> fleet,
    required SubscriptionTier tier,
    List<Map<String, String>> conversationHistory = const [],
    // Override the default per-call token estimate — e.g. the PDF
    // executive-summary call passes AiUsageLimits.copilotReportCostTokens
    // since it generates a longer answer than a normal chat question.
    int? estimatedTokenCost,
  }) async {
    // ── 0. Enforce this plan's monthly AI token cap ────────────────
    final int tokenCost =
        estimatedTokenCost ?? AiUsageLimits.copilotChatCostTokens;
    final blocked = await AiUsageGuard.checkAndConsume(tokenCost, tier);
    if (blocked != null) return blocked;

    // ── 1. Build live data context ───────────────────────────────
    final totalPending = ledgers.fold(
        0.0, (s, l) => s + (l.partyPending > 0 ? l.partyPending : 0));
    final totalProfit = ledgers.fold(0.0, (s, l) => s + l.tripProfit);
    final overdueCount = ledgers.where((l) => l.isPaymentOverdue).length;
    final inTransit = ledgers.where((l) => l.isInTransit).length;
    final openMx = tickets.where((t) => t.status == 'open').length;
    final unmatched =
        bankEntries.where((e) => e.credit > 0 && !e.isMatched).length;
    final lossTrips = ledgers.where((l) => l.tripProfit < 0).length;
    final overdueAmt = ledgers
        .where((l) => l.isPaymentOverdue)
        .fold(0.0, (s, l) => s + l.partyPending);

    // Top 5 overdue parties
    final overdueParties = ledgers
        .where((l) => l.isPaymentOverdue)
        .map((l) {
          final due = l.paymentDueDate;
          final late =
              due == null ? '?' : '${DateTime.now().difference(due).inDays}d';
          return '${l.partyName} (₹${l.partyPending.toStringAsFixed(0)}, $late late)';
        })
        .take(5)
        .join('; ');

    // Top 3 loss trips
    final lossDetails = ledgers
        .where((l) => l.tripProfit < 0)
        .take(3)
        .map((l) =>
            '${l.vehicleNo} on ${l.route}: loss ₹${l.tripProfit.abs().toStringAsFixed(0)}')
        .join('; ');

    // SOS tickets
    final sosDetails = tickets
        .where((t) => t.isSos && t.status == 'open')
        .map((t) => '${t.vehicleNo}: ${t.issue}')
        .join('; ');

    // Build per-trip data for accurate AI analysis
    final totalDiesel = ledgers.fold(0.0, (s, l) => s + l.diesel);
    final totalDistance = ledgers.fold(0.0, (s, l) => s + l.distanceKm);
    // Real fleet fuel economy — weighted average from actual entered data
    final tripsWithFuelData = ledgers
        .where(
            (l) => l.fuelEconomy > 0 && l.fuelEconomy < 20 && l.distanceKm > 0)
        .toList();
    final avgFuelEconomy = tripsWithFuelData.isEmpty
        ? 0.0
        : tripsWithFuelData.fold(0.0, (s, l) => s + l.fuelEconomy) /
            tripsWithFuelData.length;
    // Per-vehicle fuel economy
    final vehicleFuelMap = <String, List<double>>{};
    for (final l in tripsWithFuelData) {
      vehicleFuelMap.putIfAbsent(l.vehicleNo, () => []).add(l.fuelEconomy);
    }
    final vehicleFuelSummary = vehicleFuelMap.entries
        .map((e) =>
            '${e.key}: ${(e.value.fold(0.0, (a, b) => a + b) / e.value.length).toStringAsFixed(1)} km/L')
        .take(8)
        .join(', ');
    // Per-trip detail for recent trips
    final recentTrips = ledgers
        .take(15)
        .map((l) =>
            '${l.vehicleNo} | ${l.route.split("->").first.trim()}→${l.route.split("->").last.trim()} | '
            'Freight:₹${l.freightBilled.toStringAsFixed(0)} | '
            'Diesel:₹${l.diesel.toStringAsFixed(0)}${l.distanceKm > 0 ? " | Dist:${l.distanceKm.toStringAsFixed(0)}km" : ""}'
            '${l.fuelEconomy > 0 && l.fuelEconomy < 20 ? " | Mileage:${l.fuelEconomy.toStringAsFixed(1)}km/L" : ""}'
            ' | Profit:₹${l.tripProfit.toStringAsFixed(0)}')
        .join("\n");

    final systemPrompt =
        '''You are NavGati AI — the intelligent copilot inside NavGati ERP for an Indian fleet/transport operator.
You have FULL access to the owner's actual operational data. Use ONLY the real numbers below. Never invent or estimate figures.

═══ LIVE FLEET DATA ═══
TRIPS: ${ledgers.length} total | Revenue: ₹${ledgers.fold(0.0, (s, l) => s + l.freightBilled).toStringAsFixed(0)} | Profit: ₹$totalProfit
DIESEL: ₹${totalDiesel.toStringAsFixed(0)} total spend | Distance: ${totalDistance.toStringAsFixed(0)} km total
FUEL ECONOMY: ${avgFuelEconomy > 0 ? "${avgFuelEconomy.toStringAsFixed(1)} km/L avg (from ${tripsWithFuelData.length} trips with data)" : "not entered yet — remind user to fill mileage in trip entries"}
${vehicleFuelSummary.isNotEmpty ? "Per vehicle: $vehicleFuelSummary" : ""}
COLLECTIONS: ₹${totalPending.toStringAsFixed(0)} pending | $overdueCount overdue (₹${overdueAmt.toStringAsFixed(0)})
${overdueParties.isNotEmpty ? "Overdue parties: $overdueParties" : "No overdue parties"}
FLEET: ${fleet.length} vehicles | $inTransit in transit | $lossTrips loss-making trips
${lossDetails.isNotEmpty ? "Loss trips: $lossDetails" : ""}
MAINTENANCE: $openMx open tickets${sosDetails.isNotEmpty ? " | SOS: $sosDetails" : ""}
BANK: ${bankEntries.length} entries | $unmatched unmatched credits

RECENT TRIPS (most recent 15):
$recentTrips

═══ RULES ═══
1. Use ONLY the numbers above. Never say "approximately" or make up figures.
2. Commercial tankers/trucks in India get 3–5 km/L. If you see >8 km/L it is a data error — flag it.
3. Be specific: name vehicles, parties, and routes from the data.
4. Answers should be actionable. Tell the owner exactly what to do.
5. Use ₹ for rupees. Keep answers under 200 words unless a detailed list is asked.''';

    // ── 2. Build messages for Gemini ────────────────────────────
    final geminiMessages = <Map<String, dynamic>>[];
    // System prompt sent as first user+model exchange (Gemini format)
    geminiMessages.add({
      'role': 'user',
      'parts': [
        {'text': systemPrompt}
      ],
    });
    geminiMessages.add({
      'role': 'model',
      'parts': [
        {'text': 'Understood. I am NavGati AI, ready to help.'}
      ],
    });
    // Add previous conversation turns
    for (final h in conversationHistory.take(10)) {
      geminiMessages.add({
        'role': h['role'] == 'assistant' ? 'model' : 'user',
        'parts': [
          {'text': h['content']!}
        ],
      });
    }
    // Add current question
    geminiMessages.add({
      'role': 'user',
      'parts': [
        {'text': question}
      ],
    });

    // ── 3. Call AI API chain: Gemini 2.5 → Gemini 1.5 → OpenRouter ──
    try {
      // Gemini free-tier models — try most stable first
      // Get a free key at: aistudio.google.com (no card needed)
      final geminiModels = [
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent',
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent',
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent',
      ];
      // 0 means no provider has returned an HTTP response yet. It must not
      // be shown to the user as if it were a real service status.
      http.Response response = http.Response('{}', 0);

      // ── Try Gemini models in order ────────────────────────────
      if (AppConfig.geminiApiKey.isNotEmpty &&
          !AppConfig.geminiApiKey.startsWith('PASTE_')) {
        for (final modelUrl in geminiModels) {
          final url = '$modelUrl?key=${AppConfig.geminiApiKey}';
          try {
            response = await http
                .post(
                  Uri.parse(url),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'contents': geminiMessages,
                    'generationConfig': {
                      'maxOutputTokens': 800,
                      'temperature': 0.4
                    }
                  }),
                )
                .timeout(const Duration(seconds: 20));
            debugPrint('Gemini tried: $modelUrl → ${response.statusCode}');
            if (response.statusCode == 200) break;
            // 403/400 = bad key; 404 on all models = key rejected across board
            if (response.statusCode == 403 || response.statusCode == 400) break;
            // Continue to next model on 404 (model may not be available for this key tier)
          } catch (_) {
            continue;
          }
        }
      }

      // If Gemini failed, try fallback chain
      if (response.statusCode != 200) {
        // Build OpenAI-format messages (used by Groq, OpenRouter, Pollinations)
        final oaiMessages = <Map<String, String>>[
          {
            'role': 'system',
            'content': geminiMessages.isNotEmpty
                ? (geminiMessages[0]['parts']?[0]?['text'] ?? '')
                : 'You are a helpful fleet management AI.'
          },
        ];
        for (var i = 1; i < geminiMessages.length; i++) {
          final m = geminiMessages[i];
          final role = m['role'] == 'model' ? 'assistant' : 'user';
          final txt = m['parts']?[0]?['text'] ?? '';
          if (txt.isNotEmpty) oaiMessages.add({'role': role, 'content': txt});
        }

        // ── Fallback A: Groq (free, fast — console.groq.com) ──────────
        if (AppConfig.groqApiKey.isNotEmpty &&
            !AppConfig.groqApiKey.startsWith('PASTE_')) {
          try {
            response = await http
                .post(
                  Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer ${AppConfig.groqApiKey}',
                  },
                  body: jsonEncode({
                    'model': 'llama-3.1-8b-instant',
                    'messages': oaiMessages,
                    'max_tokens': 800,
                    'temperature': 0.4,
                  }),
                )
                .timeout(const Duration(seconds: 20));
            debugPrint('Groq → ${response.statusCode}');
            if (response.statusCode == 200) {
              final t = _extractOpenAiText(response.body);
              if (t != null) return t;
              debugPrint('Groq 200 but unparsable: '
                  '${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
            }
          } catch (_) {}
        }

        // ── Fallback B: Sarvam AI (free, 10 Indian languages — dashboard.sarvam.ai) ──
        if (response.statusCode != 200 &&
            AppConfig.sarvamApiKey.isNotEmpty &&
            !AppConfig.sarvamApiKey.startsWith('PASTE_')) {
          try {
            // Sarvam uses OpenAI-compatible chat completions
            // Model: sarvam-2b (multilingual, supports Hindi/Gujarati/Punjabi/Marathi etc.)
            // NOTE: sarvam-m was deprecated by Sarvam AI. If you get another
            //       "model deprecated" error in the future, just change the
            //       string on the 'model' line below to whatever new name
            //       Sarvam's error message suggests.
            response = await http
                .post(
                  Uri.parse('https://api.sarvam.ai/v1/chat/completions'),
                  headers: {
                    'Content-Type': 'application/json',
                    'api-subscription-key': AppConfig.sarvamApiKey,
                  },
                  body: jsonEncode({
                    'model': 'sarvam-105b',
                    'messages': oaiMessages,
                    'max_tokens': 500,
                    'temperature': 0.3,
                    'stop': ['પણ પણ', 'par par', 'but but', '\n\n\n'],
                  }),
                )
                .timeout(const Duration(seconds: 25));
            debugPrint('Sarvam AI → ${response.statusCode}');
            if (response.statusCode == 200) {
              final t = _extractOpenAiText(response.body);
              if (t != null) return t;
              // 200 but neither content nor text field had usable data —
              // print the raw shape so we can see where the text lives.
              debugPrint('Sarvam 200 but unparsable. Raw body: '
                  '${response.body.length > 800 ? response.body.substring(0, 800) : response.body}');
            }
          } catch (e) {
            debugPrint('Sarvam AI threw: $e');
          }
        }

        // ── Fallback C: OpenRouter auto (picks best model automatically) ──
        if (AppConfig.openRouterApiKey.length > 10 &&
            !AppConfig.openRouterApiKey.startsWith('PASTE_')) {
          try {
            response = await http
                .post(
                  Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer ${AppConfig.openRouterApiKey}',
                    'HTTP-Referer': 'https://routemaster.app',
                    'X-Title': 'NavGati ERP',
                  },
                  body: jsonEncode({
                    'model':
                        'openrouter/auto', // auto-selects best model for each request
                    'messages': oaiMessages,
                    'max_tokens': 800,
                    'temperature': 0.4,
                    'route':
                        'fallback', // fallback to next best if auto pick fails
                  }),
                )
                .timeout(const Duration(seconds: 25));
            debugPrint('OpenRouter auto → ${response.statusCode}');
            if (response.statusCode == 200) {
              final data = _tryJsonMap(response.body);
              debugPrint(
                  'OpenRouter served by: ${data?['model'] ?? 'unknown'}');
              final t = _extractOpenAiText(response.body);
              if (t != null) return t;
            }
          } catch (_) {}
        }

        // ── Fallback C: Pollinations.ai — no key needed ────────────
        if (response.statusCode != 200) {
          try {
            // Build messages list
            final pollinationsMsgs = <Map<String, String>>[];
            if (geminiMessages.isNotEmpty) {
              pollinationsMsgs.add({
                'role': 'system',
                'content': geminiMessages[0]['parts']?[0]?['text'] ??
                    'You are a fleet management AI assistant.'
              });
            }
            for (var i = 1; i < geminiMessages.length; i++) {
              final m = geminiMessages[i];
              final role = m['role'] == 'model' ? 'assistant' : 'user';
              final txt = m['parts']?[0]?['text'] ?? '';
              if (txt.isNotEmpty)
                pollinationsMsgs.add({'role': role, 'content': txt});
            }
            // Try Pollinations OpenAI-compatible endpoint (no key required)
            final pResp = await http
                .post(
                  Uri.parse('https://text.pollinations.ai/openai'),
                  headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json'
                  },
                  body: jsonEncode({
                    'model': 'openai-large',
                    'messages': pollinationsMsgs,
                    'max_tokens': 600,
                    'private': true,
                  }),
                )
                .timeout(const Duration(seconds: 30));
            response = pResp;
            debugPrint('Pollinations → ${pResp.statusCode}');
            if (pResp.statusCode == 200 && pResp.body.isNotEmpty) {
              final t = _extractOpenAiText(pResp.body);
              if (t != null) return t;
              // Pollinations sometimes returns plain text, not JSON
              final raw = pResp.body.trim();
              if (raw.isNotEmpty && raw.length > 10 && !raw.startsWith('{')) {
                return raw;
              }
            }
          } catch (_) {}
        }
      }

      if (response.statusCode == 200) {
        // Try Gemini format first, then OpenAI/OpenRouter format — both
        // via the defensive extractors so an unexpected shape no longer
        // collapses a real success into "empty response".
        final text = _extractGeminiText(response.body) ??
            _extractOpenAiText(response.body);
        if (text != null) return text;
        final data = _tryJsonMap(response.body);
        final fr = data?['candidates']?[0]?['finishReason'] as String? ?? '';
        return fr == 'SAFETY'
            ? '⚠️ Blocked by safety filter. Please rephrase.'
            : '⚠️ AI returned empty response. Try again.';
      } else if (response.statusCode == 0) {
        await AiUsageGuard.refund(tokenCost);
        return '⚠️ Live AI is unavailable right now. Showing the latest local analysis instead:\n\n${_localCopilotAnswer(question: question, ledgers: ledgers, bankEntries: bankEntries, tickets: tickets, fleet: fleet, reason: 'no provider response')}';
      } else if (response.statusCode == 400) {
        await AiUsageGuard.refund(tokenCost);
        try {
          final b = jsonDecode(response.body) as Map<String, dynamic>;
          final msg = b['error']?['message'] ??
              response.body.substring(0, response.body.length.clamp(0, 150));
          return '⚠️ Gemini 400: $msg\n\nLocal: ${_localCopilotAnswer(question: question, ledgers: ledgers, bankEntries: bankEntries, tickets: tickets, fleet: fleet)}';
        } catch (_) {
          return _localCopilotAnswer(
              question: question,
              ledgers: ledgers,
              bankEntries: bankEntries,
              tickets: tickets,
              fleet: fleet,
              reason: 'Gemini 400');
        }
      } else if (response.statusCode == 403) {
        await AiUsageGuard.refund(tokenCost);
        return '🔑 Gemini API key is invalid or expired.\n\nGet a free key in 2 minutes:\n1. Visit aistudio.google.com\n2. Sign in → Get API Key → Create API key\n3. Copy the key (starts with AIzaSy...)\n4. In AppConfig replace geminiApiKey with the new key\n\nFree tier: 1,500 requests/day, no card needed.\n\n📊 Local analysis:\n${_localCopilotAnswer(question: question, ledgers: ledgers, bankEntries: bankEntries, tickets: tickets, fleet: fleet)}';
      } else if (response.statusCode == 429) {
        await AiUsageGuard.refund(tokenCost);
        return _localCopilotAnswer(
            question: question,
            ledgers: ledgers,
            bankEntries: bankEntries,
            tickets: tickets,
            fleet: fleet,
            reason: 'Gemini rate limit');
      } else if (response.statusCode == 404) {
        await AiUsageGuard.refund(tokenCost);
        return _localCopilotAnswer(
            question: question,
            ledgers: ledgers,
            bankEntries: bankEntries,
            tickets: tickets,
            fleet: fleet,
            reason: 'AI unavailable');
      } else {
        await AiUsageGuard.refund(tokenCost);
        // Both Gemini and OpenRouter failed — return clean local analysis
        return '⚠️ AI service unavailable (status ${response.statusCode}). Showing local analysis:\n\n${_localCopilotAnswer(question: question, ledgers: ledgers, bankEntries: bankEntries, tickets: tickets, fleet: fleet)}';
      }
    } on TimeoutException {
      await AiUsageGuard.refund(tokenCost);
      return '⏱️ AI request timed out. Check your internet connection and try again.\n\nLocal: ${_localCopilotAnswer(question: question, ledgers: ledgers, bankEntries: bankEntries, tickets: tickets, fleet: fleet)}';
    } catch (e) {
      await AiUsageGuard.refund(tokenCost);
      final es = e.toString();
      if (es.contains('XMLHttpRequest') ||
          es.contains('SocketException') ||
          es.contains('CORS')) {
        return _localCopilotAnswer(
            question: question,
            ledgers: ledgers,
            bankEntries: bankEntries,
            tickets: tickets,
            fleet: fleet,
            reason: 'network/CORS');
      }
      return _localCopilotAnswer(
          question: question,
          ledgers: ledgers,
          bankEntries: bankEntries,
          tickets: tickets,
          fleet: fleet,
          reason: es.replaceAll("Exception: ", ""));
    }
  }

  static String lastCaptureError = ''; // set on failure so UI can show why

  // ══════════════════════════════════════════════════════════════
  // QUICK CAPTURE — extract trip details from a photo or voice note
  // ══════════════════════════════════════════════════════════════
  static Future<Map<String, dynamic>?> extractTripFromFile({
    required Uint8List fileBytes,
    required String mimeType,
    required SubscriptionTier tier,
  }) async {
    lastCaptureError = '';

    if (AppConfig.geminiApiKey.isEmpty) {
      lastCaptureError = 'LR and WhatsApp note reading needs a Gemini API key. '
          'Build with --dart-define=GEMINI_API_KEY=your_key.';
      return null;
    }

    // ── Enforce this plan's monthly AI token cap ───────────────────
    final blocked = await AiUsageGuard.checkAndConsume(
        AiUsageLimits.photoExtractCostTokens, tier);
    if (blocked != null) {
      lastCaptureError = blocked;
      return null;
    }

    int lastStatus = 0;
    String lastBodySnippet = '';
    final base64Data = base64Encode(fileBytes);
    final isAudio = mimeType.startsWith('audio/');
    final prompt = '''
You are reading ${isAudio ? "a voice note" : "a photo of a paper transport document (LR, invoice, or delivery challan)"} from an Indian trucking/logistics business. It may be in Hindi, Gujarati, or English, casual or mixed language.

Extract the trip details and return ONLY valid JSON, no markdown, no explanation, no code fences — just the raw JSON object, with exactly these keys:
{
  "partyName": "",
  "vehicleNo": "",
  "driverName": "",
  "route": "",
  "materialName": "",
  "freightBilled": 0,
  "weightTons": 0,
  "distanceKm": 0,
  "eWayBillNo": "",
  "notes": ""
}

Rules:
- route should be formatted as "Origin -> Destination" if both are mentioned.
- freightBilled, weightTons, distanceKm are plain numbers (no ₹ symbol, no commas, no units). Use 0 if not mentioned.
- Use "" for any text field not mentioned or unclear.
- notes: put anything important you understood that doesn't fit the fields above (e.g. "advance ₹5000 paid", "driver said pickup delayed").
- Never invent details that were not said or written.
''';

    final geminiModels = [
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent',
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent',
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-lite-latest:generateContent',
    ];

    for (final modelUrl in geminiModels) {
      final url = '$modelUrl?key=${AppConfig.geminiApiKey}';
      try {
        final response = await http
            .post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'contents': [
                  {
                    'role': 'user',
                    'parts': [
                      {'text': prompt},
                      {
                        'inline_data': {
                          'mime_type': mimeType,
                          'data': base64Data,
                        }
                      },
                    ],
                  }
                ],
                'generationConfig': {
                  'maxOutputTokens': 500,
                  'temperature': 0.2,
                },
              }),
            )
            .timeout(const Duration(seconds: 45));
        debugPrint('extractTripFromFile ($modelUrl) -> ${response.statusCode}');
        lastStatus = response.statusCode;
        if (response.body.isNotEmpty) {
          lastBodySnippet = response.body.length > 200
              ? response.body.substring(0, 200)
              : response.body;
        }
        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        String text = data['candidates']?[0]?['content']?['parts']?[0]?['text']
                as String? ??
            '';
        if (text.isEmpty) {
          lastCaptureError = 'AI connected (200) but returned no text — '
              'the photo may be too blurry or dark to read.';
          continue;
        }

        text = text.trim();
        if (text.startsWith('```')) {
          text = text.replaceFirst(RegExp(r'^```[a-zA-Z]*\n?'), '');
          text = text.replaceFirst(RegExp(r'```\s*$'), '');
          text = text.trim();
        }
        final jsonStart = text.indexOf('{');
        final jsonEnd = text.lastIndexOf('}');
        if (jsonStart == -1 || jsonEnd == -1 || jsonEnd < jsonStart) {
          lastCaptureError =
              'AI read the image but did not return usable data. '
              'It said: ${text.length > 120 ? text.substring(0, 120) : text}';
          continue;
        }
        text = text.substring(jsonStart, jsonEnd + 1);

        final parsed = jsonDecode(text) as Map<String, dynamic>;
        return parsed;
      } catch (e) {
        debugPrint('extractTripFromFile error ($modelUrl): $e');
        lastCaptureError = 'Error: $e';
        continue;
      }
    }
    // Nothing worked — build a helpful message from the last status seen.
    if (lastCaptureError.isEmpty) {
      if (lastStatus == 404) {
        lastCaptureError = 'AI model not found (404). The model name is wrong '
            'or not available for your key.';
      } else if (lastStatus == 429) {
        lastCaptureError =
            'Rate limit hit (429). Wait 1 minute and try again — '
            'the free tier allows only a few requests per minute.';
      } else if (lastStatus == 403) {
        lastCaptureError =
            'API key rejected (403). Check the Gemini key in config.';
      } else if (lastStatus == 400) {
        lastCaptureError = 'Bad request (400): $lastBodySnippet';
      } else if (lastStatus != 0) {
        lastCaptureError = 'AI returned status $lastStatus. $lastBodySnippet';
      } else {
        lastCaptureError = 'Could not reach AI — check internet connection.';
      }
    }
    return null;
  }
}

// ── AI Control Tower Screen ──────────────────────────────────────

// ── App Theme Constants ──────────────────────────────────────────
const kPrimary = Color(0xFF0EA5E9); // Sky blue - main brand
const kAccent = Color(0xFFF59E0B); // Amber - highlights
const kSuccess = Color(0xFF10B981); // Green
const kDanger = Color(0xFFEF4444); // Red
const kWarning = Color(0xFFF97316); // Orange
const kBg = Color(0xFFF6FAFF); // Light page background
const kCard = Color(0xFFFFFFFF); // Card background
const kText = Color(0xFF0F172A); // Primary text
const kSubtext = Color(0xFF64748B); // Secondary text

// ── Global theme-aware card helpers (use from any widget via context) ──────
extension ThemeContextExt on BuildContext {
  AppThemeConfig get _themeCfg {
    try {
      return ThemeHelper.getConfig(
          ProviderScope.containerOf(this).read(appThemeProvider));
    } catch (_) {
      return ThemeHelper.getConfig(AppThemeType.light);
    }
  }

  Color get cardColor => _themeCfg.cardColor;
  Color get cardBorderColor => _themeCfg.cardBorder;
  bool get isGlassTheme => _themeCfg.isGlass;
  BoxDecoration cardDeco({double radius = 14}) {
    final cfg = _themeCfg;
    return BoxDecoration(
      color: cfg.cardColor,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: cfg.cardBorder, width: 1.2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: cfg.shadowOpacity),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }
}

class AiControlTowerScreen extends StatefulWidget {
  final List<TripLedger> ledgers;
  final List<BankEntry> bankEntries;
  final List<MaintenanceTicket> maintenanceTickets;
  final List<Asset> fleet;
  final List<MarketLoad> marketLoads;
  final List<ComplianceVaultItem> complianceVault;
  final SubscriptionTier tier;
  final Function(String ledgerId, double amount)? onApplyReconciliation;
  final VoidCallback? onImportCsv;

  const AiControlTowerScreen({
    super.key,
    required this.ledgers,
    required this.bankEntries,
    required this.maintenanceTickets,
    required this.fleet,
    required this.marketLoads,
    required this.complianceVault,
    required this.tier,
    this.onApplyReconciliation,
    this.onImportCsv,
  });
  @override
  State<AiControlTowerScreen> createState() => _AiControlTowerScreenState();
}

class _AiControlTowerScreenState extends State<AiControlTowerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _chatCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<AiCopilotMessage> _chat = [];
  bool _aiTyping = false;
  int _lastSentTime = 0;
  String _aiStatusMsg = ''; // empty = ok, non-empty = last error for banner
  // Voice input
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechAvailable = false;

  late List<AiInsight> _financeInsights;
  late List<AiReconciliationSuggestion> _reconciliations;
  late List<AiMaintenanceForecast> _maintenanceForecasts;
  late List<AiRouteSuggestion> _routeSuggestions;
  late List<AiInsight> _ocrInsights;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _computeInsights();
    // Initialize speech recognition with explicit permission request
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      try {
        final available = await _speech.initialize(
          onStatus: (s) {
            if (s == 'done' || s == 'notListening') {
              if (mounted) setState(() => _isListening = false);
            }
          },
          onError: (e) {
            debugPrint('Speech error: ${e.errorMsg}');
            if (mounted) setState(() => _isListening = false);
          },
          // This triggers the Android permission dialog automatically
          finalTimeout: const Duration(seconds: 5),
        );
        if (mounted) setState(() => _speechAvailable = available);
        debugPrint('Speech available: $available');
      } catch (e) {
        debugPrint('Speech init error: $e');
      }
    });
    // Restore previous chat if it exists, otherwise show welcome message
    if (_persistentChat.isEmpty) {
      _persistentChat.add(AiCopilotMessage(
          role: 'ai',
          text:
              '👋 Hi! I\'m your NavGati AI.\n\nI\'ve analysed ${widget.ledgers.length} trips, ${widget.fleet.length} vehicles and ${widget.bankEntries.length} bank entries.\n\nAsk me anything — collections, profits, fleet health, reconciliation!'));
    }
    _chat = List.from(_persistentChat);
  }

  void _computeInsights() {
    _financeInsights = AiEngine.analyzeFinance(
        ledgers: widget.ledgers, bankEntries: widget.bankEntries);
    _reconciliations = AiEngine.reconcile(
        ledgers: widget.ledgers, bankEntries: widget.bankEntries);
    _maintenanceForecasts = AiEngine.predictMaintenance(
        tickets: widget.maintenanceTickets, fleet: widget.fleet);
    _routeSuggestions = AiEngine.optimizeRoutes(
        ledgers: widget.ledgers, marketLoads: widget.marketLoads);
    _ocrInsights = AiEngine.analyzeOcrDocs(vault: widget.complianceVault);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _chatCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // Conversation history — static so it persists across screen opens
  static final List<Map<String, String>> _history = [];
  static final List<AiCopilotMessage> _persistentChat = [];

  String _lastSentMessage = '';
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _aiTyping) return;
    if (text.trim() == _lastSentMessage &&
        DateTime.now().millisecondsSinceEpoch - _lastSentTime < 2000) return;
    _lastSentMessage = text.trim();
    _lastSentTime = DateTime.now().millisecondsSinceEpoch;
    _chatCtrl.clear();
    final userMsg = text.trim();
    final userChatMsg = AiCopilotMessage(role: 'user', text: userMsg);
    setState(() {
      _chat.add(userChatMsg);
      _persistentChat.add(userChatMsg);
      _aiTyping = true;
    });
    // Scroll to bottom immediately
    Future.delayed(const Duration(milliseconds: 80), () {
      if (_scrollCtrl.hasClients)
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });

    // Auto-detect language from the script used in the message
    // This works regardless of app locale setting
    String detectedLang = 'English';
    final msg = userMsg;
    if (msg.runes.any((r) => r >= 0x0A80 && r <= 0x0AFF)) {
      detectedLang = 'Gujarati'; // Gujarati script
    } else if (msg.runes.any((r) => r >= 0x0900 && r <= 0x097F)) {
      detectedLang = 'Hindi'; // Devanagari (Hindi/Marathi)
    } else if (msg.runes.any((r) => r >= 0x0A00 && r <= 0x0A7F)) {
      detectedLang = 'Punjabi'; // Gurmukhi
    } else if (msg.runes.any((r) => r >= 0x0B80 && r <= 0x0BFF)) {
      detectedLang = 'Tamil';
    } else if (msg.runes.any((r) => r >= 0x0C00 && r <= 0x0C7F)) {
      detectedLang = 'Telugu';
    } else if (msg.runes.any((r) => r >= 0x0C80 && r <= 0x0CFF)) {
      detectedLang = 'Kannada';
    } else if (msg.runes.any((r) => r >= 0x0980 && r <= 0x09FF)) {
      detectedLang = 'Bengali';
    }
    // Also check app locale as fallback
    final appLangNames = {
      'en': 'English',
      'hi': 'Hindi',
      'gu': 'Gujarati',
      'pa': 'Punjabi',
      'mr': 'Marathi',
      'ta': 'Tamil',
      'te': 'Telugu',
      'kn': 'Kannada',
      'bn': 'Bengali',
    };
    if (detectedLang == 'English' && appLocale.value.languageCode != 'en') {
      detectedLang = appLangNames[appLocale.value.languageCode] ?? 'English';
    }
    final questionWithLang = detectedLang == 'English'
        ? userMsg
        : '$userMsg\n\n[IMPORTANT: Reply ONLY in $detectedLang script. Do not use English. Keep numbers in English but all text in $detectedLang.]';
    final answer = await AiEngine.copilotAnswer(
      question: questionWithLang,
      ledgers: widget.ledgers,
      bankEntries: widget.bankEntries,
      tickets: widget.maintenanceTickets,
      fleet: widget.fleet,
      tier: widget.tier,
      conversationHistory: _history,
    );

    // Update history for multi-turn context
    _history.add({'role': 'user', 'content': userMsg});
    _history.add({'role': 'assistant', 'content': answer});
    // Keep last 10 exchanges (20 messages) to stay within context
    if (_history.length > 20) _history.removeRange(0, _history.length - 20);

    if (!mounted) return;
    setState(() {
      final msg = AiCopilotMessage(role: 'ai', text: answer);
      _chat.add(msg);
      _persistentChat.add(msg); // persist for next time screen opens
      // Keep persistent chat to last 40 messages
      if (_persistentChat.length > 40) _persistentChat.removeAt(0);
      _aiTyping = false;
      // Track if AI actually worked or fell back to local
      if (answer.contains('🚫')) {
        _aiStatusMsg = 'Monthly AI limit reached';
      } else if (answer.startsWith('🔑') || answer.startsWith('⏱️')) {
        _aiStatusMsg = 'Live AI provider unavailable; local analysis is active';
      } else {
        _aiStatusMsg = '';
      }
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollCtrl.hasClients)
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  // ── helpers ────────────────────────────────────────────────────
  String _fmt(double v) {
    if (v.abs() >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v.abs() >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  void _snack(String msg, {Color bg = kSuccess}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating));

  @override
  Widget build(BuildContext context) {
    final allInsights = [..._financeInsights, ..._ocrInsights]
        .where((i) => !i.isDismissed)
        .toList();
    final criticals =
        allInsights.where((i) => i.severity == AiSeverity.critical).length;
    final totalBadge = _financeInsights.length +
        _reconciliations.length +
        _maintenanceForecasts.length;

    return UniversalScaffold(
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: Row(children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kPrimary.withValues(alpha: 0.3))),
              child:
                  Icon(Icons.auto_awesome_rounded, color: kPrimary, size: 18)),
          const SizedBox(width: 10),
          Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('AI Control Tower',
                    style: TextStyle(
                        color: kText,
                        fontWeight: FontWeight.w900,
                        fontSize: 16)),
                Text(
                    '${widget.ledgers.length} trips  •  ${widget.fleet.length} vehicles',
                    style: TextStyle(color: kSubtext, fontSize: 10)),
              ]),
        ]),
        actions: [
          if (criticals > 0)
            Container(
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: kDanger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kDanger.withValues(alpha: 0.4))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.warning_amber_rounded, color: kDanger, size: 13),
                  const SizedBox(width: 4),
                  Text('$criticals Critical',
                      style: TextStyle(
                          color: kDanger,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ])),
          if (totalBadge > 0)
            Container(
                margin: const EdgeInsets.only(right: 14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: kPrimary.withValues(alpha: 0.35))),
                child: Text('$totalBadge insights',
                    style: TextStyle(
                        color: kPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800))),
        ],
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(color: kPrimary.withValues(alpha: 0.15)),
                      bottom: BorderSide(
                          color: kPrimary.withValues(alpha: 0.2), width: 1.5))),
              child: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: kPrimary,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: kPrimary,
                  unselectedLabelColor: kSubtext,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 12),
                  tabs: [
                    _tab(Icons.account_balance_wallet_rounded, 'Finance',
                        _financeInsights.length),
                    _tab(Icons.sync_alt_rounded, 'Reconcile',
                        _reconciliations.length),
                    _tab(Icons.build_circle_rounded, 'Maintenance',
                        _maintenanceForecasts.length),
                    _tab(Icons.route_rounded, 'Routes',
                        _routeSuggestions.length),
                    _tab(Icons.smart_toy_rounded, 'Copilot', _chat.length - 1),
                  ]),
            )), // PreferredSize + Container
      ),
      body: TabBarView(controller: _tabs, children: [
        _buildFinanceTab(),
        _buildReconcileTab(),
        _buildMaintenanceTab(),
        _buildRoutesTab(),
        _buildCopilotTab(),
      ]),
    );
  }

  Tab _tab(IconData icon, String label, int count) => Tab(
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                    color: kPrimary, borderRadius: BorderRadius.circular(8)),
                child: Text('$count',
                    style: const TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.w900))),
          ],
        ]),
      );

  // ─── Finance Tab ──────────────────────────────────────────────
  void _showRouteCostCalculator() {
    final distCtrl = TextEditingController();
    final dieselCtrl = TextEditingController(text: '93');
    final mileageCtrl = TextEditingController(text: '4.5');
    final driverCtrl = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(builder: (ctx2, ss) {
              double diesel = 0, toll = 0, driverCost = 0, total = 0;
              void calc() {
                final km = double.tryParse(distCtrl.text) ?? 0;
                final rate = double.tryParse(dieselCtrl.text) ?? 93;
                final kmpl = double.tryParse(mileageCtrl.text) ?? 4.5;
                final drv = double.tryParse(driverCtrl.text) ?? 0;
                // Diesel = km / mileage * rate
                diesel = km > 0 && kmpl > 0 ? (km / kmpl) * rate : 0;
                // Accurate NHAI FasTag toll estimate for 6-axle HCV (most common truck type)
                toll = km > 0 ? estimateToll(km, 6) : 0;
                driverCost = drv;
                total = diesel + toll + driverCost;
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                title: const Row(children: [
                  Icon(Icons.calculate_rounded, color: kPrimary, size: 22),
                  SizedBox(width: 8),
                  Text('Trip Cost Calculator',
                      style:
                          TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                ]),
                content: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8)),
                    child: const Row(children: [
                      Icon(Icons.info_outline_rounded,
                          size: 14, color: Color(0xFF3B82F6)),
                      SizedBox(width: 6),
                      Expanded(
                          child: Text(
                              '💡 Tap "View Route" on the load card first → Google Maps shows exact distance. Enter that distance here for accurate calculation.',
                              style: TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontSize: 11,
                                  height: 1.4))),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('Distance (km)',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          TextField(
                              controller: distCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => ss(() {}),
                              decoration: InputDecoration(
                                  hintText: 'e.g. 1380',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10))),
                        ])),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('Diesel Rate (₹/L)',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          TextField(
                              controller: dieselCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => ss(() {}),
                              decoration: InputDecoration(
                                  hintText: '93',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10))),
                        ])),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('Mileage (km/litre)',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          TextField(
                              controller: mileageCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => ss(() {}),
                              decoration: InputDecoration(
                                  hintText: '4.5',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10))),
                        ])),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          const Text('Driver Expense (₹)',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          TextField(
                              controller: driverCtrl,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => ss(() {}),
                              decoration: InputDecoration(
                                  hintText: 'e.g. 3500',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10))),
                        ])),
                  ]),
                  Builder(builder: (_) {
                    calc();
                    if (total <= 0) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            kPrimary.withValues(alpha: 0.08),
                            kPrimary.withValues(alpha: 0.03)
                          ]),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: kPrimary.withValues(alpha: 0.25))),
                      child: Column(children: [
                        _calcRow('⛽ Diesel', '₹${diesel.toStringAsFixed(0)}',
                            Colors.orange,
                            sub:
                                '${(double.tryParse(distCtrl.text) ?? 0) / (double.tryParse(mileageCtrl.text) ?? 4.5).clamp(0.1, 100)} L'),
                        const Divider(height: 10),
                        _calcRow('🛣️ Toll (est.)',
                            '₹${toll.toStringAsFixed(0)}', Colors.blue,
                            sub: 'NHAI FasTag 6-axle, 78% NH'),
                        if (driverCost > 0) ...[
                          const Divider(height: 10),
                          _calcRow(
                              '👤 Driver',
                              '₹${driverCost.toStringAsFixed(0)}',
                              const Color(0xFF8B5CF6))
                        ],
                        const Divider(height: 12),
                        _calcRow('💰 TOTAL COST',
                            '₹${total.toStringAsFixed(0)}', kDanger,
                            isBold: true),
                        const SizedBox(height: 8),
                        Text(
                            'Min. freight to break even: ₹${(total * 1.15).toStringAsFixed(0)} (+15% margin)',
                            style: TextStyle(
                                color: kSuccess,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ]),
                    );
                  }),
                ])),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Close')),
                  if (true)
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10))),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _tabs.animateTo(4);
                          final km = distCtrl.text;
                          final rate = dieselCtrl.text;
                          final kmpl = mileageCtrl.text;
                          Future.delayed(
                              const Duration(milliseconds: 300),
                              () => _sendMessage(
                                  'For a trip of ${km}km at diesel ₹$rate/L, mileage ${kmpl}km/L: '
                                  'What freight rate should I charge to make good profit? '
                                  'Also suggest how to reduce diesel cost on this route.'));
                        },
                        child: const Text('Ask AI')),
                ],
              );
            }));
  }

  Widget _calcRow(String label, String val, Color color,
          {String? sub, bool isBold = false}) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: isBold ? 13 : 12,
                          fontWeight:
                              isBold ? FontWeight.w900 : FontWeight.w600,
                          color: const Color(0xFF334155))),
                  if (sub != null)
                    Text(sub,
                        style: const TextStyle(
                            fontSize: 10, color: Color(0xFF94A3B8))),
                ])),
            Text(val,
                style: TextStyle(
                    fontSize: isBold ? 14 : 12,
                    fontWeight: FontWeight.w900,
                    color: color)),
          ]));

  Future<void> _doDownloadReport() async {
    // First get AI analysis, then embed in PDF
    _snack('🤖 Generating AI analysis...');
    String aiAnalysis = '';
    try {
      aiAnalysis = await AiEngine.copilotAnswer(
        question:
            'Write a brief executive summary (max 150 words) of this fleet business. '
            'Cover: total revenue, net profit, biggest loss routes, top paying party, '
            'most pending collection, and 3 specific actionable recommendations.',
        ledgers: widget.ledgers,
        bankEntries: widget.bankEntries,
        fleet: widget.fleet,
        tickets: widget.maintenanceTickets,
        tier: widget.tier,
        conversationHistory: [],
        estimatedTokenCost: AiUsageLimits.copilotReportCostTokens,
      );
    } catch (_) {
      aiAnalysis = 'AI analysis unavailable — add Gemini API key in AppConfig.';
    }

    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final totalRevenue =
          widget.ledgers.fold(0.0, (s, l) => s + l.freightBilled);
      final totalProfit2 = widget.ledgers.fold(0.0, (s, l) => s + l.tripProfit);
      final totalPending2 =
          widget.ledgers.fold(0.0, (s, l) => s + l.partyPending);
      final lossTrips = widget.ledgers.where((l) => l.tripProfit < 0).toList()
        ..sort((a, b) => a.tripProfit.compareTo(b.tripProfit));
      final topParties = <String, double>{};
      for (final l in widget.ledgers) {
        topParties[l.partyName] =
            (topParties[l.partyName] ?? 0) + l.freightBilled;
      }
      final sortedParties = topParties.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final overdueParties = widget.ledgers
          .where((l) => l.isPaymentOverdue && l.partyPending > 0)
          .toList()
        ..sort((a, b) => b.partyPending.compareTo(a.partyPending));
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (_) => [
          pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#0D1F14'),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8))),
              child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('NAVGATI ERP — AI FINANCE REPORT',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 14)),
                    pw.Text('${now.day}/${now.month}/${now.year}',
                        style: pw.TextStyle(
                            color: PdfColors.grey300, fontSize: 11)),
                  ])),
          pw.SizedBox(height: 14),
          // AI EXECUTIVE SUMMARY
          pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#EFF6FF'),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(
                      color: PdfColor.fromHex('#3B82F6'), width: 0.5)),
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('🤖 AI EXECUTIVE SUMMARY',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 10,
                            color: PdfColor.fromHex('#1D4ED8'))),
                    pw.SizedBox(height: 6),
                    pw.Text(aiAnalysis,
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColor.fromHex('#1E3A5F'),
                            lineSpacing: 2)),
                  ])),
          pw.SizedBox(height: 12),
          // LOSS-MAKING TRIPS
          if (lossTrips.isNotEmpty) ...[
            pw.Text('⚠️ LOSS-MAKING TRIPS (${lossTrips.length})',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                    color: PdfColor.fromHex('#DC2626'))),
            pw.SizedBox(height: 6),
            pw.Table(
                border:
                    pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
                children: [
                  pw.TableRow(
                      decoration:
                          pw.BoxDecoration(color: PdfColor.fromHex('#FEE2E2')),
                      children: ['Party', 'Route', 'Freight', 'Loss', 'Reason']
                          .map((h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(h,
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 8))))
                          .toList()),
                  ...lossTrips.take(5).map((l) => pw.TableRow(children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(l.partyName,
                                style: pw.TextStyle(fontSize: 7))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(l.route,
                                style: pw.TextStyle(fontSize: 7))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                                '₹${l.freightBilled.toStringAsFixed(0)}',
                                style: pw.TextStyle(fontSize: 7))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                                '₹${l.tripProfit.toStringAsFixed(0)}',
                                style: pw.TextStyle(
                                    fontSize: 7,
                                    color: PdfColor.fromHex('#DC2626')))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                                l.diesel > l.freightBilled * 0.35
                                    ? 'High diesel'
                                    : l.penalties > 0
                                        ? 'Penalties'
                                        : l.driverExp > l.freightBilled * 0.25
                                            ? 'High driver exp'
                                            : 'Low freight',
                                style: pw.TextStyle(fontSize: 7))),
                      ])),
                ]),
            pw.SizedBox(height: 12),
          ],
          // OVERDUE COLLECTIONS
          if (overdueParties.isNotEmpty) ...[
            pw.Text('🔴 OVERDUE COLLECTIONS (${overdueParties.length})',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                    color: PdfColor.fromHex('#D97706'))),
            pw.SizedBox(height: 6),
            pw.Table(
                border:
                    pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
                children: [
                  pw.TableRow(
                      decoration:
                          pw.BoxDecoration(color: PdfColor.fromHex('#FEF3C7')),
                      children: ['Party', 'Route', 'Pending', 'Vehicle']
                          .map((h) => pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(h,
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 8))))
                          .toList()),
                  ...overdueParties.take(5).map((l) => pw.TableRow(children: [
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(l.partyName,
                                style: pw.TextStyle(fontSize: 7))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(l.route,
                                style: pw.TextStyle(fontSize: 7))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(
                                '₹${l.partyPending.toStringAsFixed(0)}',
                                style: pw.TextStyle(
                                    fontSize: 7,
                                    color: PdfColor.fromHex('#D97706')))),
                        pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(l.vehicleNo,
                                style: pw.TextStyle(fontSize: 7))),
                      ])),
                ]),
            pw.SizedBox(height: 12),
          ],
          // TOP PARTIES
          pw.Text('📊 TOP PARTIES BY REVENUE',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: PdfColor.fromHex('#1D4ED8'))),
          pw.SizedBox(height: 6),
          pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
              children: [
                pw.TableRow(
                    decoration:
                        pw.BoxDecoration(color: PdfColor.fromHex('#EFF6FF')),
                    children: ['Party', 'Revenue', 'Trips']
                        .map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(h,
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 8))))
                        .toList()),
                ...sortedParties.take(5).map((e) {
                  final partyTrips =
                      widget.ledgers.where((l) => l.partyName == e.key).length;
                  return pw.TableRow(children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child:
                            pw.Text(e.key, style: pw.TextStyle(fontSize: 7))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('₹${e.value.toStringAsFixed(0)}',
                            style: pw.TextStyle(
                                fontSize: 7,
                                color: PdfColor.fromHex('#059669')))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text('$partyTrips',
                            style: pw.TextStyle(fontSize: 7))),
                  ]);
                }),
              ]),
          pw.SizedBox(height: 14),
          pw.Row(children: [
            pw.Expanded(
                child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(6))),
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Total Revenue',
                              style: pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey600)),
                          pw.Text('Rs.${totalRevenue.toStringAsFixed(0)}',
                              style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#0EA5E9')))
                        ]))),
            pw.SizedBox(width: 8),
            pw.Expanded(
                child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(6))),
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Net Profit',
                              style: pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey600)),
                          pw.Text('Rs.${totalProfit2.toStringAsFixed(0)}',
                              style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                  color: totalProfit2 >= 0
                                      ? PdfColor.fromHex('#10B981')
                                      : PdfColor.fromHex('#EF4444')))
                        ]))),
            pw.SizedBox(width: 8),
            pw.Expanded(
                child: pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                        borderRadius:
                            const pw.BorderRadius.all(pw.Radius.circular(6))),
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Outstanding',
                              style: pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey600)),
                          pw.Text('Rs.${totalPending2.toStringAsFixed(0)}',
                              style: pw.TextStyle(
                                  fontSize: 18,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColor.fromHex('#F59E0B')))
                        ]))),
          ]),
          // FULL TRIP LEDGER
          pw.Text('📋 COMPLETE TRIP LEDGER',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: PdfColor.fromHex('#374151'))),
          pw.SizedBox(height: 6),
          pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
              children: [
                pw.TableRow(
                    decoration:
                        pw.BoxDecoration(color: PdfColor.fromHex('#F3F4F6')),
                    children: [
                      'Date',
                      'Party',
                      'Route',
                      'Freight',
                      'Expenses',
                      'Profit',
                      'Status'
                    ]
                        .map((h) => pw.Padding(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(h,
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 7))))
                        .toList()),
                ...widget.ledgers.map((l) {
                  final exp = l.diesel + l.toll + l.driverExp + l.penalties;
                  return pw.TableRow(children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child:
                            pw.Text(l.date, style: pw.TextStyle(fontSize: 7))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(l.partyName,
                            style: pw.TextStyle(fontSize: 7))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child:
                            pw.Text(l.route, style: pw.TextStyle(fontSize: 6))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text('₹${l.freightBilled.toStringAsFixed(0)}',
                            style: pw.TextStyle(fontSize: 7))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text('₹${exp.toStringAsFixed(0)}',
                            style: pw.TextStyle(fontSize: 7))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text('₹${l.tripProfit.toStringAsFixed(0)}',
                            style: pw.TextStyle(
                                fontSize: 7,
                                color: l.tripProfit >= 0
                                    ? PdfColor.fromHex('#059669')
                                    : PdfColor.fromHex('#DC2626')))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: pw.Text(
                            l.partyPending > 0 ? 'Pending' : 'Settled',
                            style: pw.TextStyle(fontSize: 7))),
                  ]);
                }),
              ]),
          pw.SizedBox(height: 8),
          pw.Text(
              'Generated by NavGati ERP AI Control Tower · ${now.day}/${now.month}/${now.year}',
              style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
        ],
      ));
      await Printing.layoutPdf(
          onLayout: (_) async => pdf.save(),
          name: 'AI_FinanceReport_${now.day}_${now.month}_${now.year}.pdf');
    } catch (e) {
      _snack('PDF error: $e');
    }
  }

  void _doSendReminders() {
    final overdue = widget.ledgers
        .where((l) => l.isPaymentOverdue && l.partyPending > 0)
        .toList();
    final dueSoon = widget.ledgers
        .where((l) => l.isDueSoon && !l.isPaymentOverdue && l.partyPending > 0)
        .toList();
    if (overdue.isEmpty && dueSoon.isEmpty) {
      _snack('No outstanding payments to remind!');
      return;
    }
    final sb = StringBuffer('🚛 *NavGati ERP — Payment Reminders*\n\n');
    if (overdue.isNotEmpty) {
      sb.writeln('⚠️ *OVERDUE PAYMENTS:*');
      for (final l in overdue.take(5)) {
        sb.writeln(
            '• ${l.partyName}: ₹${l.partyPending.toStringAsFixed(0)} (${l.route})');
      }
      sb.writeln();
    }
    if (dueSoon.isNotEmpty) {
      sb.writeln('🔔 *DUE SOON:*');
      for (final l in dueSoon.take(5)) {
        sb.writeln(
            '• ${l.partyName}: ₹${l.partyPending.toStringAsFixed(0)} (${l.route})');
      }
    }
    sb.writeln('\nPlease clear dues at the earliest. Thank you!');
    SharePlus.instance
        .share(ShareParams(text: sb.toString(), subject: 'Payment Reminders'));
  }

  Widget _buildFinanceTab() {
    final totalPending = widget.ledgers
        .fold(0.0, (s, l) => s + (l.partyPending > 0 ? l.partyPending : 0));
    final totalProfit = widget.ledgers.fold(0.0, (s, l) => s + l.tripProfit);
    final overdueAmt = widget.ledgers
        .where((l) => l.isPaymentOverdue)
        .fold(0.0, (s, l) => s + l.partyPending);
    final lossTrips = widget.ledgers.where((l) => l.tripProfit < 0).length;

    return ListView(padding: const EdgeInsets.all(16), children: [
      // ── KPI cards row 1
      Row(children: [
        _kpi('Total Pending', '₹${_fmt(totalPending)}', kWarning,
            Icons.hourglass_top_rounded,
            sub:
                '${widget.ledgers.where((l) => l.partyPending > 0).length} trips'),
        const SizedBox(width: 10),
        _kpi('Overdue', '₹${_fmt(overdueAmt)}', kDanger,
            Icons.warning_amber_rounded,
            sub:
                '${widget.ledgers.where((l) => l.isPaymentOverdue).length} accounts'),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        _kpi(
            'Net Profit',
            '₹${_fmt(totalProfit)}',
            totalProfit >= 0 ? kSuccess : kDanger,
            totalProfit >= 0
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            sub: '${widget.ledgers.length} trips analysed'),
        const SizedBox(width: 10),
        _kpi('Loss Trips', '$lossTrips', Colors.purple,
            Icons.remove_circle_rounded,
            sub: 'Below break-even'),
      ]),
      const SizedBox(height: 20),
      // ── Quick action buttons
      Row(children: [
        Expanded(
            child: _actionBtn('Download Report', Icons.download_rounded,
                kPrimary, _doDownloadReport)),
        const SizedBox(width: 10),
        Expanded(
            child: _actionBtn('Send Reminders', Icons.send_rounded, kWarning,
                _doSendReminders)),
      ]),
      const SizedBox(height: 20),
      _sectionHead('AI Findings', '${_financeInsights.length} issues detected'),
      ..._financeInsights.map((i) {
        // Wire up action based on type
        VoidCallback? action;
        if (i.ledgerId.isNotEmpty) {
          final ledger = widget.ledgers
              .cast<TripLedger?>()
              .firstWhere((l) => l!.id == i.ledgerId, orElse: () => null);
          if (ledger != null) {
            if (i.type == AiInsightType.overdue) {
              // Mark Paid → ask for amount and mark
              action = () => showDialog(
                  context: context,
                  builder: (ctx) {
                    final ctrl = TextEditingController(
                        text: ledger.partyPending.toStringAsFixed(0));
                    return AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: const Text('Mark Payment Received'),
                      content:
                          Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                            '${ledger.partyName} — ₹${ledger.partyPending.toStringAsFixed(0)} pending'),
                        const SizedBox(height: 12),
                        TextField(
                            controller: ctrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                                labelText: 'Amount received (₹)',
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)))),
                      ]),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel')),
                        ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white),
                            onPressed: () {
                              final amt = double.tryParse(ctrl.text) ?? 0;
                              if (amt > 0)
                                widget.onApplyReconciliation
                                    ?.call(ledger.id, amt);
                              Navigator.pop(ctx);
                              setState(() => i.isDismissed = true);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(
                                      '✅ ₹${amt.toStringAsFixed(0)} marked as received for ${ledger.partyName}'),
                                  backgroundColor: const Color(0xFF10B981),
                                  behavior: SnackBarBehavior.floating));
                            },
                            child: const Text('Confirm')),
                      ],
                    );
                  });
            } else {
              // View Trip / Review → show full trip breakdown dialog
              action = () => _showLedgerDetailDialog(ledger, i);
            }
          }
        } else if (i.type == AiInsightType.reconciled) {
          // Reconcile → switch to reconcile tab
          action = () => _tabs.animateTo(1);
        }
        return _insightCard(
          i,
          onDismiss: () => setState(() => i.isDismissed = true),
          onTapCard: action,
        );
      }),
      if (_financeInsights.isEmpty)
        _empty('No anomalies 🎉', 'Your finances look healthy!',
            Icons.check_circle_outline_rounded, kSuccess),
    ]);
  }

  // ─── Reconcile Tab ────────────────────────────────────────────
  Widget _buildReconcileTab() {
    final totalCredit = widget.bankEntries
        .where((e) => e.credit > 0 && !e.isMatched)
        .fold(0.0, (s, e) => s + e.credit);
    final matchedCount = _reconciliations.length;

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Summary card
      Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              kPrimary.withValues(alpha: 0.08),
              kPrimary.withValues(alpha: 0.03)
            ]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kPrimary.withValues(alpha: 0.25))),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
              child: Icon(Icons.account_balance_rounded,
                  color: kPrimary, size: 22)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('₹${_fmt(totalCredit)} unmatched credits',
                    style: TextStyle(
                        color: kText,
                        fontWeight: FontWeight.w900,
                        fontSize: 15)),
                Text('AI found $matchedCount high-confidence matches',
                    style: TextStyle(color: kSubtext, fontSize: 12)),
              ])),
          if (matchedCount > 0)
            ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8)),
                onPressed: () {
                  for (final r in List.from(_reconciliations)) {
                    widget.onApplyReconciliation
                        ?.call(r.ledger.id, r.bankEntry.credit);
                    r.bankEntry.isMatched = true;
                  }
                  setState(() => _reconciliations.clear());
                  _snack('✅ All $matchedCount entries reconciled!');
                },
                icon: const Icon(Icons.done_all_rounded, size: 14),
                label: const Text('Apply All',
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
        ]),
      ),
      _sectionHead('Matched Entries', '$matchedCount suggestions'),
      ..._reconciliations.map((r) => _reconcileCard(r)),
      // CSV Import Button — always visible at bottom of reconcile tab
      const SizedBox(height: 16),
      GestureDetector(
        onTap: () {
          Navigator.pop(context);
          widget.onImportCsv?.call();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                kPrimary.withValues(alpha: 0.1),
                kPrimary.withValues(alpha: 0.04)
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kPrimary.withValues(alpha: 0.3))),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.12),
                    shape: BoxShape.circle),
                child:
                    Icon(Icons.upload_file_rounded, color: kPrimary, size: 22)),
            const SizedBox(width: 14),
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Import Bank Statement CSV',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text(
                      'Upload your bank CSV — AI will auto-match credits to your trips',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                ])),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Color(0xFF0EA5E9)),
          ]),
        ),
      ),
      if (_reconciliations.isEmpty)
        _empty(
            'No matches yet',
            'Import a bank CSV above to get AI matching suggestions.',
            Icons.account_balance_outlined,
            kPrimary),
    ]);
  }

  // ─── Maintenance Tab ─────────────────────────────────────────
  Widget _buildMaintenanceTab() {
    final sosCount = _maintenanceForecasts
        .where((f) => f.severity == AiSeverity.critical)
        .length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      if (sosCount > 0)
        Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                color: kDanger.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kDanger.withValues(alpha: 0.3))),
            child: Row(children: [
              Icon(Icons.emergency_rounded, color: kDanger, size: 20),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(
                      '$sosCount vehicle${sosCount > 1 ? "s require" : " requires"} immediate attention!',
                      style: TextStyle(
                          color: kDanger, fontWeight: FontWeight.w800))),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kDanger,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8)),
                  onPressed: () {
                    _snack(
                        '🚨 SOS: Schedule immediate maintenance for $sosCount vehicles!');
                    _tabs.animateTo(4); // open copilot
                    Future.delayed(
                        const Duration(milliseconds: 300),
                        () => _sendMessage(
                            'Which vehicles need emergency maintenance right now? Give me a priority list.'));
                  },
                  child: const Text('Ask AI →',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w800))),
            ])),
      _sectionHead('Predictive Maintenance',
          '${_maintenanceForecasts.length} forecasts'),
      ..._maintenanceForecasts.map((f) => _maintenanceCard(f)),
      if (_maintenanceForecasts.isEmpty)
        _empty(
            'Fleet is healthy! ✅',
            'No upcoming maintenance alerts. AI monitors odometer trends continuously.',
            Icons.verified_rounded,
            kSuccess),
    ]);
  }

  // ─── Routes Tab ───────────────────────────────────────────────
  Widget _buildRoutesTab() {
    // Build per-route analytics from actual trip history
    final routeStats = <String, Map<String, dynamic>>{};
    for (final l in widget.ledgers) {
      final key = l.route;
      if (!routeStats.containsKey(key)) {
        routeStats[key] = {
          'trips': 0,
          'totalFreight': 0.0,
          'totalExpenses': 0.0,
          'totalDiesel': 0.0,
          'totalToll': 0.0,
          'totalDriverExp': 0.0,
          'totalProfit': 0.0,
          'vehicles': <String>{},
          'lastDate': l.date,
          'party': l.partyName,
        };
      }
      final s = routeStats[key]!;
      s['trips'] = (s['trips'] as int) + 1;
      s['totalFreight'] = (s['totalFreight'] as double) + l.freightBilled;
      s['totalExpenses'] = (s['totalExpenses'] as double) + l.selfExpenses;
      s['totalDiesel'] = (s['totalDiesel'] as double) + l.diesel;
      s['totalToll'] = (s['totalToll'] as double) + l.toll;
      s['totalDriverExp'] = (s['totalDriverExp'] as double) + l.driverExp;
      s['totalProfit'] = (s['totalProfit'] as double) + l.tripProfit;
      (s['vehicles'] as Set<String>).add(l.vehicleNo);
    }
    final sortedRoutes = routeStats.entries.toList()
      ..sort((a, b) => (b.value['totalFreight'] as double)
          .compareTo(a.value['totalFreight'] as double));

    // Live loads on these routes
    final routeLoads = <String, List<MarketLoad>>{};
    for (final load in widget.marketLoads) {
      final key = '${load.originCity} → ${load.destCity}';
      routeLoads.putIfAbsent(key, () => []).add(load);
    }

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Route Cost Calculator
      GestureDetector(
        onTap: () => _showRouteCostCalculator(),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                kPrimary.withValues(alpha: 0.08),
                kPrimary.withValues(alpha: 0.03)
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kPrimary.withValues(alpha: 0.25))),
          child: Row(children: [
            Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: kPrimary.withValues(alpha: 0.12),
                    shape: BoxShape.circle),
                child:
                    Icon(Icons.calculate_rounded, color: kPrimary, size: 22)),
            const SizedBox(width: 12),
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Trip Cost Calculator',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: Color(0xFF0F172A))),
                  SizedBox(height: 2),
                  Text(
                      'Enter distance, diesel rate & mileage → get exact diesel + toll cost',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                ])),
            Icon(Icons.arrow_forward_ios_rounded, size: 13, color: kPrimary),
          ]),
        ),
      ),
      Row(children: [
        Expanded(
            child: _actionBtn(
                'Find Market Load', Icons.search_rounded, kSuccess, () {
          Navigator.pop(context);
          _snack('Opening Market tab — check available loads');
        })),
        const SizedBox(width: 10),
        Expanded(
            child: _actionBtn(
                'Ask AI for Rate', Icons.calculate_rounded, kPrimary, () {
          _tabs.animateTo(4);
          Future.delayed(
              const Duration(milliseconds: 300),
              () => _sendMessage(
                  'Based on my trip history, what is the ideal freight rate for each of my regular routes? Consider my actual diesel, toll and driver expenses.'));
        })),
      ]),
      const SizedBox(height: 20),
      _sectionHead(
          'Route Performance Analytics', '${routeStats.length} routes'),
      if (routeStats.isEmpty)
        _empty('No routes yet', 'Add trips to see route analytics',
            Icons.route_outlined, kSubtext)
      else
        ...sortedRoutes.take(10).map((entry) {
          final r = entry.value;
          final trips = r['trips'] as int;
          final freight = r['totalFreight'] as double;
          final profit = r['totalProfit'] as double;
          final diesel = r['totalDiesel'] as double;
          final toll = r['totalToll'] as double;
          final drvExp = r['totalDriverExp'] as double;
          final avgFreight = trips > 0 ? freight / trips : 0.0;
          final avgProfit = trips > 0 ? profit / trips : 0.0;
          final avgDiesel = trips > 0 ? diesel / trips : 0.0;
          final avgToll = trips > 0 ? toll / trips : 0.0;
          final avgDrv = trips > 0 ? drvExp / trips : 0.0;
          final margin = freight > 0 ? (profit / freight * 100) : 0.0;
          final isHealthy = margin > 15;
          final liveLoads = routeLoads[entry.key] ?? [];
          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: isHealthy
                      ? kSuccess.withValues(alpha: 0.3)
                      : kDanger.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
              ],
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: isHealthy
                        ? kSuccess.withValues(alpha: 0.06)
                        : kDanger.withValues(alpha: 0.06),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(15))),
                child: Row(children: [
                  Icon(Icons.route_rounded,
                      color: isHealthy ? kSuccess : kDanger, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(entry.key,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: Color(0xFF0F172A))),
                        Text(
                            '$trips trip${trips > 1 ? "s" : ""} · ${(r["vehicles"] as Set).length} vehicle${(r["vehicles"] as Set).length > 1 ? "s" : ""} · Last: ${r["lastDate"]}',
                            style: const TextStyle(
                                color: Color(0xFF64748B), fontSize: 11)),
                      ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${margin.toStringAsFixed(1)}%',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: isHealthy ? kSuccess : kDanger)),
                    Text('margin',
                        style: const TextStyle(
                            color: Color(0xFF64748B), fontSize: 10)),
                  ]),
                ]),
              ),
              // Per-trip averages
              Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(children: [
                    // Revenue row
                    Row(children: [
                      Expanded(
                          child: _miniStat(
                              'Avg Freight',
                              '₹${avgFreight.toStringAsFixed(0)}',
                              const Color(0xFF0EA5E9))),
                      Expanded(
                          child: _miniStat(
                              'Avg Profit',
                              '₹${avgProfit.toStringAsFixed(0)}',
                              avgProfit >= 0 ? kSuccess : kDanger)),
                      Expanded(
                          child: _miniStat('Total Trips', '$trips',
                              const Color(0xFF6366F1))),
                    ]),
                    const SizedBox(height: 10),
                    // Expense breakdown bar
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10)),
                      child: Column(children: [
                        const Row(children: [
                          Icon(Icons.receipt_long_rounded,
                              size: 12, color: Color(0xFF64748B)),
                          SizedBox(width: 5),
                          Text('Avg expenses per trip',
                              style: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 8),
                        _expBar(
                            '⛽ Diesel', avgDiesel, avgFreight, Colors.orange),
                        _expBar('🛣️ Toll/FASTag', avgToll, avgFreight,
                            Colors.blue),
                        _expBar('👤 Driver exp', avgDrv, avgFreight,
                            const Color(0xFF8B5CF6)),
                        _expBar('📊 Total cost', (avgDiesel + avgToll + avgDrv),
                            avgFreight, kDanger),
                      ]),
                    ),
                    // Live loads on this route
                    if (liveLoads.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: kSuccess.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: kSuccess.withValues(alpha: 0.2))),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.local_shipping_rounded,
                                    size: 13, color: Color(0xFF10B981)),
                                const SizedBox(width: 5),
                                Text(
                                    '${liveLoads.length} live load${liveLoads.length > 1 ? "s" : ""} available on this route',
                                    style: const TextStyle(
                                        color: Color(0xFF10B981),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800)),
                              ]),
                              const SizedBox(height: 6),
                              ...liveLoads.take(2).map((load) {
                                final expProfit = load.targetPrice -
                                    (avgDiesel + avgToll + avgDrv);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 5),
                                  child: Row(children: [
                                    Expanded(
                                        child: Text(
                                            '₹${load.targetPrice.toStringAsFixed(0)} · ${load.vehicleType} · ${load.weightTons}T${load.postedByName.isNotEmpty ? " · ${load.postedByName}" : ""}',
                                            style: const TextStyle(
                                                color: Color(0xFF0F172A),
                                                fontSize: 11))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: expProfit > 0
                                              ? kSuccess.withValues(alpha: 0.1)
                                              : kDanger.withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(6)),
                                      child: Text(
                                          'Est. ₹${expProfit.toStringAsFixed(0)} profit',
                                          style: TextStyle(
                                              color: expProfit > 0
                                                  ? kSuccess
                                                  : kDanger,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ]),
                                );
                              }),
                            ]),
                      ),
                    ],
                    // AI suggestion
                    if (!isHealthy) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () {
                          _tabs.animateTo(4);
                          Future.delayed(
                              const Duration(milliseconds: 300),
                              () => _sendMessage(
                                  'My route "${entry.key}" has a ${margin.toStringAsFixed(1)}% margin on average. '
                                  'Avg freight ₹${avgFreight.toStringAsFixed(0)}, diesel ₹${avgDiesel.toStringAsFixed(0)}, toll ₹${avgToll.toStringAsFixed(0)}, driver ₹${avgDrv.toStringAsFixed(0)}. '
                                  'How should I improve profitability on this route?'));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                              color: kPrimary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: kPrimary.withValues(alpha: 0.2))),
                          child: Row(children: [
                            const Icon(Icons.auto_awesome_rounded,
                                size: 13, color: Color(0xFF0EA5E9)),
                            const SizedBox(width: 6),
                            const Expanded(
                                child: Text(
                                    'Tap to ask AI how to improve this route →',
                                    style: TextStyle(
                                        color: Color(0xFF0EA5E9),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700))),
                          ]),
                        ),
                      ),
                    ],
                  ])),
            ]),
          );
        }),
      if (_routeSuggestions.isNotEmpty) ...[
        const SizedBox(height: 8),
        _sectionHead(
            'AI Route Suggestions', '${_routeSuggestions.length} found'),
        ..._routeSuggestions.map((s) => _routeCard(s)),
      ],
    ]);
  }

  Widget _miniStat(String label, String value, Color color) =>
      Column(children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w900, fontSize: 14, color: color)),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 9,
                fontWeight: FontWeight.w600)),
      ]);

  Widget _expBar(String label, double val, double total, Color color) {
    final pct = total > 0 ? (val / total).clamp(0.0, 1.0) : 0.0;
    return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(children: [
          SizedBox(
              width: 90,
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xFF64748B)))),
          Expanded(
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(color)))),
          const SizedBox(width: 8),
          SizedBox(
              width: 55,
              child: Text('₹${val.toStringAsFixed(0)}',
                  style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.right)),
        ]));
  }

  // ─── Copilot Tab ─────────────────────────────────────────────
  Widget _buildCopilotTab() {
    final quickQ = [
      '💰 Show pending collections with party names and exact amounts',
      '📉 Which trips are loss-making and why? Give specific reasons',
      '⛽ How can I reduce diesel cost? Analyse my route fuel efficiency',
      '🏆 Who is my best paying party? Should I give them priority?',
      '📊 Give me this month P&L — revenue, expenses, net profit',
      '🚛 Which vehicles are underutilized? How can I improve fleet usage?',
      '🔮 Forecast next month revenue based on my trip patterns',
      '⚠️ What are my biggest financial risks right now?',
    ];
    return Column(children: [
      // Quick-ask chip row
      Container(
        color: const Color(0xFFF6FAFF),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final q in quickQ)
                GestureDetector(
                    onTap: () => _sendMessage(q),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                          color: kPrimary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: kPrimary.withValues(alpha: 0.25))),
                      child: Text(q.length > 30 ? '${q.substring(0, 30)}…' : q,
                          style: TextStyle(
                              color: kPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    )),
            ])),
      ),
      // AI status banner
      if (_aiStatusMsg.isNotEmpty)
        Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: kWarning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kWarning.withValues(alpha: 0.3))),
            child: Row(children: [
              Icon(Icons.wifi_off_rounded, color: kWarning, size: 16),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(_aiStatusMsg,
                      style: TextStyle(
                          color: kWarning,
                          fontSize: 11,
                          fontWeight: FontWeight.w600))),
              GestureDetector(
                  onTap: () => setState(() => _aiStatusMsg = ''),
                  child: Icon(Icons.close_rounded, color: kWarning, size: 16)),
            ])),
      Expanded(
        child: ListView.builder(
          controller: _scrollCtrl,
          padding: const EdgeInsets.all(16),
          itemCount: _chat.length + (_aiTyping ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == _chat.length && _aiTyping) return _typingDot();
            final m = _chat[i];
            final isAi = m.role == 'ai';
            return Align(
              alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.82),
                decoration: BoxDecoration(
                  color: isAi ? kCard : kText,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isAi ? 4 : 16),
                    bottomRight: Radius.circular(isAi ? 16 : 4),
                  ),
                  border: isAi
                      ? Border.all(color: kPrimary.withValues(alpha: 0.2))
                      : null,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2))
                  ],
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isAi)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(children: [
                              Icon(Icons.auto_awesome_rounded,
                                  color: kPrimary, size: 12),
                              const SizedBox(width: 4),
                              Text('AI Copilot',
                                  style: TextStyle(
                                      color: kPrimary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800)),
                            ])),
                      Text(m.text,
                          style: TextStyle(
                              color: isAi ? kText : Colors.white,
                              fontSize: 13,
                              height: 1.5)),
                      const SizedBox(height: 4),
                      Text(
                          '${m.timestamp.hour.toString().padLeft(2, '0')}:${m.timestamp.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                              color: isAi ? kSubtext : Colors.white54,
                              fontSize: 9)),
                    ]),
              ),
            );
          },
        ),
      ),
      // Quick suggestions chips
      if (_chat.length <= 1)
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: quickQ.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => _sendMessage(quickQ[i]),
              child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: kPrimary.withValues(alpha: 0.3))),
                  child: Text(quickQ[i],
                      style: TextStyle(
                          color: kPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600))),
            ),
          ),
        ),
      const SizedBox(height: 8),
      // Input wrapped in SafeArea to prevent keyboard overflow
      SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
                color: context.cardColor,
                border: Border(top: BorderSide(color: Colors.grey.shade200))),
            child: Row(children: [
              Expanded(
                  child: TextField(
                controller: _chatCtrl,
                style: TextStyle(color: kText, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ask anything about your fleet...',
                  hintStyle: TextStyle(
                      color: kSubtext.withValues(alpha: 0.7), fontSize: 13),
                  filled: true,
                  fillColor: kBg,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none),
                ),
                onSubmitted: _sendMessage,
              )),
              const SizedBox(width: 8),
              // Mic button — tap to speak in any language
              GestureDetector(
                  onTap: () async {
                    // Step 1: Explicitly request microphone permission (works on all Android including Vivo)
                    final micStatus = await Permission.microphone.request();
                    if (micStatus.isDenied || micStatus.isPermanentlyDenied) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text(
                                'Microphone permission denied. Go to Settings → Apps → NavGati → Permissions → Microphone → Allow'),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 6),
                            action: SnackBarAction(
                              label: 'Settings',
                              textColor: Colors.white,
                              onPressed: () => openAppSettings(),
                            )));
                      }
                      return;
                    }
                    // Step 2: Initialize speech after permission granted
                    if (!_speechAvailable) {
                      final available = await _speech.initialize(
                        onStatus: (s) {
                          if (mounted && (s == 'done' || s == 'notListening'))
                            setState(() => _isListening = false);
                        },
                        onError: (e) {
                          if (mounted) setState(() => _isListening = false);
                        },
                      );
                      if (mounted) setState(() => _speechAvailable = available);
                      if (!available) {
                        if (mounted)
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text(
                                  'Speech recognition not available on this device'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating));
                        return;
                      }
                    }
                    if (_isListening) {
                      // Stop listening and send what was captured
                      await _speech.stop();
                      setState(() => _isListening = false);
                      final text = _chatCtrl.text.trim();
                      if (text.isNotEmpty) _sendMessage(text);
                    } else {
                      // Start listening
                      final langCode = appLocale.value.languageCode;
                      final localeMap = {
                        'en': 'en_IN',
                        'hi': 'hi_IN',
                        'gu': 'gu_IN',
                        'pa': 'pa_IN',
                        'mr': 'mr_IN',
                        'ta': 'ta_IN',
                        'te': 'te_IN',
                        'kn': 'kn_IN',
                        'bn': 'bn_IN',
                      };
                      final locale = localeMap[langCode] ?? 'en_IN';
                      setState(() => _isListening = true);
                      await _speech.listen(
                        localeId: locale,
                        listenFor: const Duration(seconds: 30),
                        pauseFor: const Duration(seconds: 3),
                        onResult: (result) {
                          if (mounted) {
                            setState(() {
                              _chatCtrl.text = result.recognizedWords;
                              if (result.finalResult &&
                                  result.recognizedWords.isNotEmpty) {
                                _isListening = false;
                                _sendMessage(result.recognizedWords);
                                _chatCtrl.clear();
                              }
                            });
                          }
                        },
                      );
                    }
                  },
                  child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                          color: _isListening
                              ? Colors.red.withValues(alpha: 0.15)
                              : const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _isListening
                                  ? Colors.red
                                  : const Color(0xFF0EA5E9)
                                      .withValues(alpha: 0.3),
                              width: _isListening ? 2 : 1)),
                      child: Icon(
                          _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                          color: _isListening
                              ? Colors.red
                              : const Color(0xFF0EA5E9),
                          size: 18))),
              const SizedBox(width: 6),
              GestureDetector(
                  onTap: () => _sendMessage(_chatCtrl.text),
                  child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)]),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFF0EA5E9)
                                    .withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ]),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 18))),
            ]),
          )), // SafeArea
    ]);
  }

  // ─── Reusable widgets ─────────────────────────────────────────
  Widget _kpi(String label, String val, Color c, IconData icon,
          {String sub = ''}) =>
      Expanded(
          child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(color: c.withValues(alpha: 0.08), blurRadius: 10)
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: c, size: 16)),
            const Spacer(),
          ]),
          const SizedBox(height: 8),
          Text(val,
              style: TextStyle(
                  color: c, fontWeight: FontWeight.w900, fontSize: 18)),
          Text(label,
              style: TextStyle(
                  color: kSubtext, fontSize: 11, fontWeight: FontWeight.w600)),
          if (sub.isNotEmpty)
            Text(sub,
                style:
                    TextStyle(color: c.withValues(alpha: 0.7), fontSize: 10)),
        ]),
      ));

  Widget _actionBtn(String label, IconData icon, Color c, VoidCallback onTap) =>
      ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: c,
              foregroundColor: Colors.white,
              disabledBackgroundColor: c.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 3,
              shadowColor: c.withValues(alpha: 0.4)),
          onPressed: onTap,
          icon: Icon(icon, size: 16, color: Colors.white),
          label: Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Colors.white)));

  void _showLedgerDetailDialog(TripLedger l, AiInsight insight) {
    final isLoss = l.tripProfit < 0;
    final color = isLoss ? kDanger : kWarning;

    // Build loss reason list
    final reasons = <String>[];
    if (l.diesel > 0) reasons.add('Diesel: ₹${l.diesel.toStringAsFixed(0)}');
    if (l.toll > 0) reasons.add('Toll: ₹${l.toll.toStringAsFixed(0)}');
    if (l.driverExp > 0)
      reasons.add('Driver expenses: ₹${l.driverExp.toStringAsFixed(0)}');
    if (l.penalties > 0)
      reasons.add('Penalties: ₹${l.penalties.toStringAsFixed(0)}');
    if (l.materialLoss > 0)
      reasons.add('Material loss: ₹${l.materialLoss.toStringAsFixed(0)}');
    if (l.marketTruckFreight > 0)
      reasons.add(
          'Market truck hired: ₹${l.marketTruckFreight.toStringAsFixed(0)}');
    if (l.tdsDeduction > 0)
      reasons.add('TDS deducted: ₹${l.tdsDeduction.toStringAsFixed(0)}');
    if (l.lrNotes.isNotEmpty) reasons.add('Notes: ${l.lrNotes}');

    final totalExpenses = l.diesel +
        l.toll +
        l.driverExp +
        l.penalties +
        l.materialLoss +
        l.marketTruckFreight +
        l.tdsDeduction;

    showDialog(
      context: context,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(19)),
              ),
              child: Row(children: [
                Icon(
                    isLoss
                        ? Icons.trending_down_rounded
                        : Icons.warning_amber_rounded,
                    color: color,
                    size: 22),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(insight.title,
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w900,
                              fontSize: 15)),
                      Text('${l.vehicleNo} • ${l.route}',
                          style: TextStyle(color: kSubtext, fontSize: 12)),
                    ])),
                GestureDetector(
                  onTap: () => Navigator.pop(c),
                  child: Icon(Icons.close_rounded, color: kSubtext, size: 20),
                ),
              ]),
            ),
            // Body
            Flexible(
                child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary row
                    Row(children: [
                      Expanded(
                          child: _dialogStat(
                              'Freight Billed',
                              '₹${l.freightBilled.toStringAsFixed(0)}',
                              kSuccess)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _dialogStat('Total Expenses',
                              '₹${totalExpenses.toStringAsFixed(0)}', kDanger)),
                      const SizedBox(width: 8),
                      Expanded(
                          child: _dialogStat(
                              isLoss ? 'Net Loss' : 'Net Profit',
                              '₹${l.tripProfit.abs().toStringAsFixed(0)}',
                              color)),
                    ]),
                    const SizedBox(height: 16),
                    // Expense breakdown
                    if (reasons.isNotEmpty) ...[
                      Text('EXPENSE BREAKDOWN',
                          style: TextStyle(
                              color: kSubtext,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8)),
                      const SizedBox(height: 8),
                      ...reasons.map((r) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(children: [
                              Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                      color: color, shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text(r,
                                  style: TextStyle(color: kText, fontSize: 13)),
                            ]),
                          )),
                      const SizedBox(height: 12),
                    ],
                    // Pending payment
                    if (l.partyPending > 0)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: kWarning.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: kWarning.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          Icon(Icons.payment_rounded,
                              color: kWarning, size: 16),
                          const SizedBox(width: 8),
                          Text(
                              '₹${l.partyPending.toStringAsFixed(0)} still pending from ${l.partyName}',
                              style: TextStyle(
                                  color: kWarning,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12)),
                        ]),
                      ),
                  ]),
            )),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0),
                  onPressed: () => Navigator.pop(c),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Close',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _dialogStat(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  color: kSubtext, fontSize: 9, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 14)),
        ]),
      );

  void _showAiDetail(String title, String body, IconData icon, Color color) {
    showDialog(
        context: context,
        builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: Row(children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 10),
                Flexible(
                    child: Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 17))),
              ]),
              content: SingleChildScrollView(
                  child: Text(body,
                      style: const TextStyle(
                          height: 1.45,
                          fontSize: 13,
                          color: Color(0xFF334155)))),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'))
              ],
            ));
  }

  Widget _insightCard(AiInsight insight,
      {VoidCallback? onDismiss, VoidCallback? onTapCard}) {
    final tap = onTapCard ??
        insight.onAction ??
        () => _showAiDetail(
              insight.title,
              '${insight.body}\n\nSeverity: ${insight.severity.name.toUpperCase()}${insight.amount != null ? "\nAmount: Rs.${insight.amount!.abs().toStringAsFixed(0)}" : ""}',
              insight.icon,
              insight.severityColor,
            );
    return Material(
        color: Colors.transparent,
        child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: tap,
            splashColor: insight.severityColor.withValues(alpha: 0.15),
            highlightColor: insight.severityColor.withValues(alpha: 0.08),
            child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                    color: context.cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: insight.severityColor.withValues(alpha: 0.25)),
                    boxShadow: [
                      BoxShadow(
                          color: insight.severityColor.withValues(alpha: 0.07),
                          blurRadius: 8)
                    ]),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                              color:
                                  insight.severityColor.withValues(alpha: 0.07),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(13))),
                          child: Row(children: [
                            Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                    color: insight.severityColor
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Icon(insight.icon,
                                    color: insight.severityColor, size: 14)),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(insight.title,
                                    style: TextStyle(
                                        color: insight.severityColor,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13))),
                            if (onDismiss != null)
                              GestureDetector(
                                  onTap: onDismiss,
                                  child: Icon(Icons.close_rounded,
                                      color: kSubtext, size: 16)),
                          ])),
                      Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(insight.body,
                                    style: TextStyle(
                                        color: kSubtext,
                                        fontSize: 12,
                                        height: 1.5)),
                                if (insight.amount != null) ...[
                                  const SizedBox(height: 10),
                                  Row(children: [
                                    Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                            color: insight.severityColor
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(8)),
                                        child: Text(
                                            '₹${insight.amount!.abs().toStringAsFixed(0)}',
                                            style: TextStyle(
                                                color: insight.severityColor,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 13))),
                                    const Spacer(),
                                    if (insight.actionLabel.isNotEmpty)
                                      ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  insight.severityColor,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 8),
                                              elevation: 0),
                                          onPressed: onTapCard ??
                                              insight.onAction ??
                                              () {},
                                          child: Text(insight.actionLabel,
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight:
                                                      FontWeight.w800))),
                                  ]),
                                ],
                              ])),
                    ]))));
  }

  Widget _reconcileCard(AiReconciliationSuggestion r) {
    final pct = (r.confidence * 100).round();
    final color = pct >= 70
        ? kSuccess
        : pct >= 45
            ? kWarning
            : kSubtext;
    return Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 8)
            ]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(13))),
              child: Row(children: [
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('$pct% match',
                        style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w900))),
                const SizedBox(width: 8),
                Text(r.reason, style: TextStyle(color: kSubtext, fontSize: 10)),
                const Spacer(),
                Text(r.bankEntry.date,
                    style: TextStyle(color: kSubtext, fontSize: 11)),
              ])),
          // Body
          Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('BANK CREDIT',
                                style: TextStyle(
                                    color: kSubtext,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5)),
                            Text('₹${r.bankEntry.credit.toStringAsFixed(0)}',
                                style: TextStyle(
                                    color: kText,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18)),
                            Text(r.bankEntry.narration,
                                style: TextStyle(color: kSubtext, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ])),
                      Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                              color: kPrimary.withValues(alpha: 0.1),
                              shape: BoxShape.circle),
                          child: Icon(Icons.arrow_forward_rounded,
                              color: kPrimary, size: 16)),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                            Text('LEDGER PENDING',
                                style: TextStyle(
                                    color: kSubtext,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5)),
                            Text('₹${r.ledger.partyPending.toStringAsFixed(0)}',
                                style: TextStyle(
                                    color: kPrimary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18)),
                            Text(r.ledger.partyName,
                                style: TextStyle(color: kSubtext, fontSize: 11),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ])),
                    ]),
                    const SizedBox(height: 12),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                                elevation: 2,
                                shadowColor: color.withValues(alpha: 0.3)),
                            onPressed: () {
                              widget.onApplyReconciliation
                                  ?.call(r.ledger.id, r.bankEntry.credit);
                              setState(() {
                                r.bankEntry.isMatched = true;
                                _reconciliations.removeWhere(
                                    (x) => x.bankEntry == r.bankEntry);
                              });
                              _snack(
                                  '✅ ₹${r.bankEntry.credit.toStringAsFixed(0)} applied to ${r.ledger.partyName}');
                            },
                            icon: const Icon(Icons.check_circle_rounded,
                                size: 16),
                            label: const Text('Apply Reconciliation',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14)))),
                  ])),
        ]));
  }

  Widget _maintenanceCard(AiMaintenanceForecast f) {
    final c = f.severity == AiSeverity.critical ? kDanger : kWarning;
    return Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(color: c.withValues(alpha: 0.07), blurRadius: 8)
            ]),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: c.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.build_circle_rounded, color: c, size: 22)),
          title: Row(children: [
            Expanded(
                child: Text(f.vehicleNo,
                    style: TextStyle(
                        color: kText,
                        fontWeight: FontWeight.w900,
                        fontSize: 13))),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: c, borderRadius: BorderRadius.circular(8)),
                child: Text(
                    f.daysUntilDue == 0 ? 'NOW' : 'In ${f.daysUntilDue}d',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900))),
          ]),
          subtitle:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(f.issue,
                style: TextStyle(
                    color: c, fontWeight: FontWeight.w700, fontSize: 12)),
            const SizedBox(height: 2),
            Text(f.recommendation,
                style: TextStyle(color: kSubtext, fontSize: 11, height: 1.4),
                overflow: TextOverflow.ellipsis,
                maxLines: 3),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: c,
                          side: BorderSide(color: c),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 6)),
                      onPressed: () => _snack(
                          'Maintenance ticket raised for ${f.vehicleNo}'),
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          size: 14),
                      label: const Text('Raise Ticket',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)))),
              const SizedBox(width: 8),
              Expanded(
                  child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: c,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 0),
                      onPressed: () =>
                          _snack('Alert sent to driver of ${f.vehicleNo}'),
                      icon: const Icon(Icons.notifications_rounded, size: 14),
                      label: const Text('Alert Driver',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)))),
            ]),
          ]),
        ));
  }

  Widget _routeCard(AiRouteSuggestion s) => Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kSuccess.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(color: kSuccess.withValues(alpha: 0.06), blurRadius: 8)
          ]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.route_rounded, color: kSuccess, size: 16),
          const SizedBox(width: 6),
          Expanded(
              child: Text(s.ledger.route,
                  style: TextStyle(
                      color: kText, fontWeight: FontWeight.w800, fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _routeKpi('Current Rate',
              '₹${s.ledger.freightBilled.toStringAsFixed(0)}', kWarning),
          const SizedBox(width: 8),
          _routeKpi('Suggested Rate',
              '₹${s.suggestedFreight.toStringAsFixed(0)}', kSuccess),
          const SizedBox(width: 8),
          _routeKpi('Est. Margin', '₹${s.estimatedMargin.toStringAsFixed(0)}',
              kPrimary),
        ]),
        const SizedBox(height: 10),
        Text(s.advice,
            style: TextStyle(color: kSubtext, fontSize: 11, height: 1.5)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimary,
                      side: const BorderSide(color: kPrimary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8)),
                  onPressed: () => _snack('Route details copied'),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text('Copy Route',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700)))),
          const SizedBox(width: 8),
          Expanded(
              child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kSuccess,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0),
                  onPressed: () => _snack('Rate suggestion sent to sales team'),
                  icon: const Icon(Icons.send_rounded, size: 14),
                  label: const Text('Apply Rate',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)))),
        ]),
      ]));

  Widget _routeKpi(String label, String val, Color c) => Expanded(
      child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
              color: c.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: c.withValues(alpha: 0.2))),
          child: Column(children: [
            Text(val,
                style: TextStyle(
                    color: c, fontWeight: FontWeight.w900, fontSize: 14)),
            Text(label,
                style: TextStyle(color: kSubtext, fontSize: 9),
                textAlign: TextAlign.center),
          ])));

  Widget _sectionHead(String title, String sub) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title,
            style: TextStyle(
                color: kText, fontWeight: FontWeight.w900, fontSize: 15)),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: kPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(sub,
                style: TextStyle(
                    color: kPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700))),
      ]));

  Widget _empty(String title, String sub, IconData icon, Color c) => Center(
      child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(children: [
            Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, color: c, size: 40)),
            const SizedBox(height: 14),
            Text(title,
                style: TextStyle(
                    color: c, fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 6),
            Text(sub,
                style: TextStyle(color: kSubtext, fontSize: 12),
                textAlign: TextAlign.center),
          ])));

  Widget _typingDot() => Align(
      alignment: Alignment.centerLeft,
      child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kPrimary.withValues(alpha: 0.2))),
          child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                  3,
                  (i) => TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.3, end: 1.0),
                      duration: Duration(milliseconds: 500 + i * 180),
                      builder: (_, v, __) => Container(
                          margin: const EdgeInsets.only(right: 4),
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                              color: kPrimary.withValues(alpha: v),
                              shape: BoxShape.circle)),
                      child: const SizedBox())))));
}

// ================================================================
// MAIN
// ================================================================
