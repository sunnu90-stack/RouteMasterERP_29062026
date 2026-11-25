// ============================================================
// ROUTE MASTER ERP v3.0 — ENHANCED BUILD
// ============================================================

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;

// ==========================================
// CONFIG
// ==========================================
class AppConfig {
  static const String appVersion = "3.0.0";
  static const String adminPin = "1234";
  // Developer mode: tap version badge 7× on splash → enter this password
  static const String developerPassword = "ROUTEDEV2024";
  // Insert Google Maps/Places API Key for real-time features
  static const String googleMapsApiKey = "";
  static const String kredxPartnerCode = "ROUTEMASTER_ERP";
  // Fuel price per litre (₹) — update as needed
  static const double defaultDieselPrice = 92.0;
}

// ==========================================
// ENUMS
// ==========================================
enum UserRole { visitor, verified, owner, driver, admin, developer }

enum BidStatus { pending, dispatched }

enum VehicleOwnership { self, market }

enum DriverTxType { advance, salary, penalty, fuel, bonus, deduction }

enum SubscriptionTier { free, pro, business }

enum KredXStatus {
  draft,
  submitted,
  underReview,
  approved,
  disbursed,
  rejected
}

enum TripStatus { active, completed, overdue }

enum AdjustmentType {
  penaltyDeduction,
  taxDeduction,
  bonus,
  shortageDeduction,
  damageDeduction,
  other
}

enum ExportFormat { tally, caAudit, gst, csv }

enum GstType { none, cgstSgst, igst }

// ==========================================
// INDIAN STATES DATA
// ==========================================
class IndiaData {
  static const List<String> states = [
    "Andhra Pradesh",
    "Arunachal Pradesh",
    "Assam",
    "Bihar",
    "Chhattisgarh",
    "Goa",
    "Gujarat",
    "Haryana",
    "Himachal Pradesh",
    "Jharkhand",
    "Karnataka",
    "Kerala",
    "Madhya Pradesh",
    "Maharashtra",
    "Manipur",
    "Meghalaya",
    "Mizoram",
    "Nagaland",
    "Odisha",
    "Punjab",
    "Rajasthan",
    "Sikkim",
    "Tamil Nadu",
    "Telangana",
    "Tripura",
    "Uttar Pradesh",
    "Uttarakhand",
    "West Bengal",
    "Andaman & Nicobar Islands",
    "Chandigarh",
    "Dadra & Nagar Haveli",
    "Daman & Diu",
    "Delhi",
    "Jammu & Kashmir",
    "Ladakh",
    "Lakshadweep",
    "Puducherry"
  ];

  static const Map<String, List<String>> majorCitiesByState = {
    "Gujarat": [
      "Ahmedabad",
      "Surat",
      "Vadodara",
      "Rajkot",
      "Gandhinagar",
      "Anand",
      "Bharuch",
      "Bharuch GIDC",
      "Dahej Port",
      "Hazira",
      "Mundra Port",
      "Kandla Port",
      "Morbi",
      "Bhavnagar",
      "Jamnagar",
      "Mehsana",
      "Valsad",
      "Navsari"
    ],
    "Maharashtra": [
      "Mumbai",
      "Pune",
      "Nagpur",
      "Nashik",
      "Aurangabad",
      "Solapur",
      "Thane",
      "Navi Mumbai",
      "Raigad",
      "JNPT",
      "Bhiwandi",
      "Kolhapur",
      "Ahmednagar"
    ],
    "Rajasthan": [
      "Jaipur",
      "Jodhpur",
      "Udaipur",
      "Kota",
      "Ajmer",
      "Bikaner",
      "Alwar",
      "Bhilwara"
    ],
    "Punjab": [
      "Amritsar",
      "Ludhiana",
      "Chandigarh",
      "Jalandhar",
      "Patiala",
      "Bathinda"
    ],
    "Haryana": [
      "Gurgaon",
      "Faridabad",
      "Panipat",
      "Ambala",
      "Hisar",
      "Rohtak",
      "Sonipat"
    ],
    "Delhi": [
      "New Delhi",
      "Delhi NCR",
      "Okhla",
      "Naraina",
      "Wazirpur",
      "Ghazipur"
    ],
    "Uttar Pradesh": [
      "Lucknow",
      "Kanpur",
      "Agra",
      "Varanasi",
      "Meerut",
      "Noida",
      "Ghaziabad",
      "Allahabad",
      "Mathura"
    ],
    "Madhya Pradesh": [
      "Bhopal",
      "Indore",
      "Jabalpur",
      "Gwalior",
      "Ujjain",
      "Ratlam",
      "Dewas"
    ],
    "Tamil Nadu": [
      "Chennai",
      "Coimbatore",
      "Madurai",
      "Tiruchirappalli",
      "Salem",
      "Tiruppur",
      "Thoothukudi"
    ],
    "Karnataka": [
      "Bengaluru",
      "Mysuru",
      "Mangaluru",
      "Hubli",
      "Belgaum",
      "Davangere"
    ],
    "Telangana": [
      "Hyderabad",
      "Warangal",
      "Karimnagar",
      "Nizamabad",
      "Khammam"
    ],
    "West Bengal": [
      "Kolkata",
      "Howrah",
      "Durgapur",
      "Asansol",
      "Siliguri",
      "Haldia Port"
    ],
    "Andhra Pradesh": [
      "Visakhapatnam",
      "Vijayawada",
      "Guntur",
      "Nellore",
      "Kakinada",
      "Tirupati"
    ],
  };

  static List<String> searchCities(String query) {
    if (query.length < 2) return [];
    final q = query.toLowerCase();
    List<String> results = [];
    majorCitiesByState.forEach((state, cities) {
      for (final city in cities) {
        if (city.toLowerCase().contains(q)) {
          results.add("$city, $state");
        }
      }
    });
    // Also match state names
    for (final state in states) {
      if (state.toLowerCase().contains(q) &&
          !results.any((r) => r.contains(state))) {
        results.add(state);
      }
    }
    return results.take(8).toList();
  }

  static String? extractState(String cityStateString) {
    if (cityStateString.contains(',')) {
      return cityStateString.split(',').last.trim();
    }
    if (states.contains(cityStateString.trim())) return cityStateString.trim();
    return null;
  }
}

// Fallback Indian Cities for CitySearchField when Maps API is empty
const List<Map<String, String>> kIndianCities = [
  {'city': 'Ahmedabad', 'state': 'Gujarat', 'full': 'Ahmedabad, Gujarat'},
  {'city': 'Surat', 'state': 'Gujarat', 'full': 'Surat, Gujarat'},
  {'city': 'Mumbai', 'state': 'Maharashtra', 'full': 'Mumbai, Maharashtra'},
  {'city': 'Delhi', 'state': 'Delhi', 'full': 'Delhi, NCR'},
  {'city': 'Bangalore', 'state': 'Karnataka', 'full': 'Bangalore, Karnataka'},
  {'city': 'Chennai', 'state': 'Tamil Nadu', 'full': 'Chennai, Tamil Nadu'},
  {'city': 'Hyderabad', 'state': 'Telangana', 'full': 'Hyderabad, Telangana'},
  {'city': 'Kolkata', 'state': 'West Bengal', 'full': 'Kolkata, West Bengal'},
  {'city': 'Pune', 'state': 'Maharashtra', 'full': 'Pune, Maharashtra'},
  {'city': 'Jaipur', 'state': 'Rajasthan', 'full': 'Jaipur, Rajasthan'},
];

class BankEntry {
  final String date;
  final String narration;
  final String refNo;
  final double debit;
  final double credit;
  bool isMatched;
  String? matchedLedgerId;

  BankEntry({
    required this.date,
    required this.narration,
    required this.refNo,
    required this.debit,
    required this.credit,
    this.isMatched = false,
    this.matchedLedgerId,
  });
}

// ==========================================
// MODELS
// ==========================================

class LedgerAdjustment {
  AdjustmentType type;
  double amount;
  String note;
  String date;
  bool isDeduction; // true = reduces amount owed to us / increases expense

  LedgerAdjustment({
    required this.type,
    required this.amount,
    required this.note,
    required this.date,
    required this.isDeduction,
  });

  String get typeLabel {
    switch (type) {
      case AdjustmentType.penaltyDeduction:
        return "Penalty Deduction";
      case AdjustmentType.taxDeduction:
        return "Tax Deducted at Source";
      case AdjustmentType.bonus:
        return "Bonus / Extra Payment";
      case AdjustmentType.shortageDeduction:
        return "Shortage / Shortage Claim";
      case AdjustmentType.damageDeduction:
        return "Damage Claim";
      case AdjustmentType.other:
        return "Other Adjustment";
    }
  }

  Color get color => isDeduction ? Colors.black : Colors.black;

  Map<String, dynamic> toJson() => {
        'type': type.index,
        'amount': amount,
        'note': note,
        'date': date,
        'isDeduction': isDeduction
      };
  factory LedgerAdjustment.fromJson(Map<String, dynamic> j) => LedgerAdjustment(
        type: AdjustmentType.values[j['type'] ?? 0],
        amount: j['amount'] ?? 0,
        note: j['note'] ?? '',
        date: j['date'] ?? '',
        isDeduction: j['isDeduction'] ?? true,
      );
}

class BankTransaction {
  String date, description, ref;
  double credit, debit;
  bool isMatched;
  String? matchedTripId;
  String? matchedParty;

  BankTransaction({
    required this.date,
    required this.description,
    required this.ref,
    this.credit = 0,
    this.debit = 0,
    this.isMatched = false,
    this.matchedTripId,
    this.matchedParty,
  });

  double get amount => credit > 0 ? credit : -debit;
}

class DriverDocument {
  String type; // 'aadhaar', 'dl', 'photo'
  bool isUploaded;
  String fileName;
  String uploadDate;

  DriverDocument(
      {required this.type,
      this.isUploaded = false,
      this.fileName = '',
      this.uploadDate = ''});

  String get displayName {
    switch (type) {
      case 'aadhaar':
        return 'Aadhaar Card';
      case 'dl':
        return 'Driving Licence';
      case 'photo':
        return 'Driver Photo';
      default:
        return type;
    }
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'isUploaded': isUploaded,
        'fileName': fileName,
        'uploadDate': uploadDate
      };
  factory DriverDocument.fromJson(Map<String, dynamic> j) => DriverDocument(
        type: j['type'] ?? '',
        isUploaded: j['isUploaded'] ?? false,
        fileName: j['fileName'] ?? '',
        uploadDate: j['uploadDate'] ?? '',
      );
}

class SubscriptionInfo {
  SubscriptionTier tier;
  String expiryDate;
  int tripsUsedThisMonth;

  SubscriptionInfo(
      {this.tier = SubscriptionTier.free,
      this.expiryDate = "",
      this.tripsUsedThisMonth = 0});

  int get maxTripsPerMonth => tier == SubscriptionTier.free ? 10 : 99999;
  bool get canExportPDF =>
      true; // Enabled for all for demo; in prod: tier != SubscriptionTier.free
  bool get canUseGPS => tier != SubscriptionTier.free;
  bool get canUseKredX => tier == SubscriptionTier.business;
  bool get hasAdvancedAnalytics => tier != SubscriptionTier.free;
  bool get isTripsLimitReached =>
      tier == SubscriptionTier.free && tripsUsedThisMonth >= 10;

  String get tierName {
    switch (tier) {
      case SubscriptionTier.free:
        return "FREE";
      case SubscriptionTier.pro:
        return "PRO";
      case SubscriptionTier.business:
        return "BUSINESS";
    }
  }

  Color get tierColor {
    switch (tier) {
      case SubscriptionTier.free:
        return Colors.black;
      case SubscriptionTier.pro:
        return const Color(0xFF212121);
      case SubscriptionTier.business:
        return Colors.black;
    }
  }

  Map<String, dynamic> toJson() => {
        'tier': tier.index,
        'expiryDate': expiryDate,
        'tripsUsedThisMonth': tripsUsedThisMonth
      };
  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) =>
      SubscriptionInfo(
        tier: SubscriptionTier.values[json['tier'] ?? 0],
        expiryDate: json['expiryDate'] ?? "",
        tripsUsedThisMonth: json['tripsUsedThisMonth'] ?? 0,
      );
}

class KredXApplication {
  String id, invoiceLedgerId, partyName;
  double invoiceAmount, requestedAmount, approvedAmount;
  KredXStatus status;
  String appliedDate;
  int tenureDays;
  double interestRate;

  KredXApplication({
    required this.id,
    required this.invoiceLedgerId,
    required this.partyName,
    required this.invoiceAmount,
    required this.requestedAmount,
    this.approvedAmount = 0,
    this.status = KredXStatus.draft,
    required this.appliedDate,
    this.tenureDays = 30,
    this.interestRate = 1.5,
  });

  double get estimatedInterest =>
      (approvedAmount > 0 ? approvedAmount : requestedAmount) *
      (interestRate / 100) *
      (tenureDays / 30);
  double get netDisbursal =>
      (approvedAmount > 0 ? approvedAmount : requestedAmount) -
      estimatedInterest;

  String get statusLabel {
    switch (status) {
      case KredXStatus.draft:
        return "Draft";
      case KredXStatus.submitted:
        return "Submitted";
      case KredXStatus.underReview:
        return "Under Review";
      case KredXStatus.approved:
        return "Approved ✓";
      case KredXStatus.disbursed:
        return "Disbursed 💸";
      case KredXStatus.rejected:
        return "Rejected";
    }
  }

  Color get statusColor {
    switch (status) {
      case KredXStatus.draft:
        return Colors.black;
      case KredXStatus.submitted:
        return Colors.black;
      case KredXStatus.underReview:
        return Colors.black;
      case KredXStatus.approved:
        return Colors.black;
      case KredXStatus.disbursed:
        return Colors.black;
      case KredXStatus.rejected:
        return Colors.black;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoiceLedgerId': invoiceLedgerId,
        'partyName': partyName,
        'invoiceAmount': invoiceAmount,
        'requestedAmount': requestedAmount,
        'approvedAmount': approvedAmount,
        'status': status.index,
        'appliedDate': appliedDate,
        'tenureDays': tenureDays,
        'interestRate': interestRate
      };
  factory KredXApplication.fromJson(Map<String, dynamic> json) =>
      KredXApplication(
        id: json['id'],
        invoiceLedgerId: json['invoiceLedgerId'],
        partyName: json['partyName'],
        invoiceAmount: json['invoiceAmount'],
        requestedAmount: json['requestedAmount'],
        approvedAmount: json['approvedAmount'] ?? 0,
        status: KredXStatus.values[json['status'] ?? 0],
        appliedDate: json['appliedDate'],
        tenureDays: json['tenureDays'] ?? 30,
        interestRate: json['interestRate'] ?? 1.5,
      );
}

class UserProfile {
  String companyName,
      gstin,
      phone,
      address,
      email,
      bankName,
      bankAccount,
      bankIfsc,
      panNumber;
  UserRole role;
  UserProfile({
    this.companyName = "Sandhu Logistics",
    this.gstin = "Unregistered",
    this.phone = "+91 0000000000",
    this.address = "Ahmedabad, Gujarat",
    this.email = "",
    this.bankName = "",
    this.bankAccount = "",
    this.bankIfsc = "",
    this.panNumber = "",
    this.role = UserRole.owner,
  });
  Map<String, dynamic> toJson() => {
        'companyName': companyName,
        'gstin': gstin,
        'phone': phone,
        'address': address,
        'email': email,
        'bankName': bankName,
        'bankAccount': bankAccount,
        'bankIfsc': bankIfsc,
        'panNumber': panNumber,
        'role': role.index,
      };
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        companyName: json['companyName'] ?? "",
        gstin: json['gstin'] ?? "",
        phone: json['phone'] ?? "",
        address: json['address'] ?? "",
        email: json['email'] ?? "",
        bankName: json['bankName'] ?? "",
        bankAccount: json['bankAccount'] ?? "",
        bankIfsc: json['bankIfsc'] ?? "",
        panNumber: json['panNumber'] ?? "",
        role: json.containsKey('role')
            ? UserRole.values[(json['role'] as int)]
            : UserRole.owner,
      );

  Null get pan => null;
}

class DriverTx {
  String date;
  DriverTxType type;
  double amount;
  String note;
  DriverTx(
      {required this.date,
      required this.type,
      required this.amount,
      required this.note});
  Map<String, dynamic> toJson() =>
      {'date': date, 'type': type.index, 'amount': amount, 'note': note};
  factory DriverTx.fromJson(Map<String, dynamic> json) => DriverTx(
      date: json['date'],
      type: DriverTxType.values[json['type']],
      amount: json['amount'],
      note: json['note']);
}

class Driver {
  String id, name, phone, aadharNum, dlNum;
  double balance, monthlySalary;
  bool hasSelfie;
  List<DriverTx> transactions;
  List<DriverDocument> documents;

  Driver({
    required this.id,
    required this.name,
    required this.phone,
    required this.balance,
    required this.transactions,
    this.aadharNum = "",
    this.dlNum = "",
    this.hasSelfie = false,
    this.monthlySalary = 0,
    List<DriverDocument>? documents,
  }) : documents = documents ??
            [
              DriverDocument(type: 'aadhaar'),
              DriverDocument(type: 'dl'),
              DriverDocument(type: 'photo'),
            ];

  bool get allDocumentsUploaded => documents.every((d) => d.isUploaded);
  int get uploadedDocCount => documents.where((d) => d.isUploaded).length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'balance': balance,
        'aadharNum': aadharNum,
        'dlNum': dlNum,
        'hasSelfie': hasSelfie,
        'monthlySalary': monthlySalary,
        'transactions': transactions.map((t) => t.toJson()).toList(),
        'documents': documents.map((d) => d.toJson()).toList(),
      };
  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
        id: json['id'],
        name: json['name'],
        phone: json['phone'],
        balance: (json['balance'] as num).toDouble(),
        transactions: (json['transactions'] as List)
            .map((t) => DriverTx.fromJson(t))
            .toList(),
        aadharNum: json['aadharNum'] ?? "",
        dlNum: json['dlNum'] ?? "",
        hasSelfie: json['hasSelfie'] ?? false,
        monthlySalary: (json['monthlySalary'] as num?)?.toDouble() ?? 0,
        documents: json['documents'] != null
            ? (json['documents'] as List)
                .map((d) => DriverDocument.fromJson(d))
                .toList()
            : null,
      );
}

class TripLedger {
  String id, date, partyName, vehicleNo, route;
  VehicleOwnership ownership;
  String eWayBillNo, materialName;
  double freightBilled, paymentReceived;
  double diesel, toll, driverExp, materialLoss;
  double marketTruckFreight, marketAdvancePaid;
  String? driverName;
  String? driverId;
  int paymentTermsDays;
  String loadingPoint, unloadingPoint, loadingState, unloadingState;
  double distanceKm;
  double fuelEconomy;
  double dieselPricePerLitre;
  int vehicleAxles;
  String consignorPhone, consignorEmail;
  List<LedgerAdjustment> adjustments;
  bool documentsSentToConsignor;
  bool paymentNotificationSent;
  double grossWeight, tareWeight;
  String lrNumber;
  double tdsDeduction;
  double penalties;
  GstType gstType;
  double gstRate;
  bool isGstInclusive;
  double weightTons;
  String weightUnit;
  String lrNotes;
  String consignorGstin;
  // Fields required by main_shell.dart
  bool isInTransit;
  String dispatchedAt;
  String estimatedArrival;
  double platformCommission;
  double consignorCommission;
  String materialInvoiceNo;
  List<Map<String, dynamic>> invoiceItems;
  String eWayBillNo2; // alias kept for compat — use eWayBillNo

  TripLedger({
    required this.id,
    required this.date,
    required this.partyName,
    required this.vehicleNo,
    required this.route,
    required this.ownership,
    this.eWayBillNo = "PENDING",
    this.materialName = "General Goods",
    required this.freightBilled,
    this.paymentReceived = 0,
    this.diesel = 0,
    this.toll = 0,
    this.driverExp = 0,
    this.materialLoss = 0,
    this.marketTruckFreight = 0,
    this.marketAdvancePaid = 0,
    this.driverName,
    this.driverId,
    this.paymentTermsDays = 30,
    this.loadingPoint = "",
    this.unloadingPoint = "",
    this.loadingState = "",
    this.unloadingState = "",
    this.distanceKm = 0,
    this.fuelEconomy = 3.5,
    this.dieselPricePerLitre = 92.0,
    this.vehicleAxles = 6,
    this.consignorPhone = "",
    this.consignorEmail = "",
    List<LedgerAdjustment>? adjustments,
    this.documentsSentToConsignor = false,
    this.paymentNotificationSent = false,
    this.grossWeight = 0,
    this.tareWeight = 0,
    this.lrNumber = "",
    this.tdsDeduction = 0,
    this.penalties = 0,
    this.gstType = GstType.none,
    this.gstRate = 0,
    this.isGstInclusive = false,
    this.weightTons = 0,
    this.weightUnit = "MT",
    this.lrNotes = "",
    this.consignorGstin = "",
    this.isInTransit = false,
    this.dispatchedAt = "",
    this.estimatedArrival = "",
    this.platformCommission = 0,
    this.consignorCommission = 0,
    this.materialInvoiceNo = "",
    List<Map<String, dynamic>>? invoiceItems,
  })  : adjustments = adjustments ?? [],
        invoiceItems = invoiceItems ?? [],
        eWayBillNo2 = "";

  double get totalAdjustmentDeductions =>
      adjustments.where((a) => a.isDeduction).fold(0, (s, a) => s + a.amount);
  double get totalAdjustmentAdditions =>
      adjustments.where((a) => !a.isDeduction).fold(0, (s, a) => s + a.amount);
  double get netFreightBilled =>
      freightBilled - totalAdjustmentDeductions + totalAdjustmentAdditions;
  double get taxableFreight => isGstInclusive && gstRate > 0
      ? freightBilled / (1 + (gstRate / 100))
      : freightBilled;
  double get gstAmount => isGstInclusive && gstRate > 0
      ? freightBilled - taxableFreight
      : freightBilled * (gstRate / 100);
  double get selfExpenses => diesel + toll + driverExp + materialLoss;
  double get marketCommission =>
      freightBilled - marketTruckFreight - materialLoss;
  double get tripProfit => ownership == VehicleOwnership.self
      ? (netFreightBilled - selfExpenses)
      : marketCommission;
  double get partyPending => netFreightBilled - paymentReceived;
  bool get isOverdue => partyPending > 0;
  double get netPayload => grossWeight - tareWeight;
  DateTime? get paymentDueDate => dueDateObj;
  bool get isPaymentOverdue => isPaymentDue;

  DateTime? get dueDateObj {
    try {
      final parts = date.split('/');
      final d = DateTime(
          int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      return d.add(Duration(days: paymentTermsDays));
    } catch (_) {
      return null;
    }
  }

  bool get isPaymentDue {
    final due = dueDateObj;
    if (due == null) return false;
    return DateTime.now().isAfter(due) && partyPending > 0;
  }

  /// True when payment is due within the next 5 days (but not yet overdue)
  bool get isDueSoon {
    final due = dueDateObj;
    if (due == null) return false;
    final now = DateTime.now();
    final diff = due.difference(now).inDays;
    return diff >= 0 && diff <= 5 && partyPending > 0;
  }

  int get daysOverdue {
    final due = dueDateObj;
    if (due == null) return 0;
    return DateTime.now().difference(due).inDays;
  }

  TripStatus get status {
    if (partyPending <= 0) return TripStatus.completed;
    if (isOverdue) return TripStatus.overdue;
    return TripStatus.active;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'partyName': partyName,
        'vehicleNo': vehicleNo,
        'route': route,
        'ownership': ownership.index,
        'eWayBillNo': eWayBillNo,
        'materialName': materialName,
        'freightBilled': freightBilled,
        'paymentReceived': paymentReceived,
        'diesel': diesel,
        'toll': toll,
        'driverExp': driverExp,
        'materialLoss': materialLoss,
        'marketTruckFreight': marketTruckFreight,
        'marketAdvancePaid': marketAdvancePaid,
        'driverName': driverName,
        'driverId': driverId,
        'paymentTermsDays': paymentTermsDays,
        'loadingPoint': loadingPoint,
        'unloadingPoint': unloadingPoint,
        'loadingState': loadingState,
        'unloadingState': unloadingState,
        'distanceKm': distanceKm,
        'fuelEconomy': fuelEconomy,
        'dieselPricePerLitre': dieselPricePerLitre,
        'vehicleAxles': vehicleAxles,
        'consignorPhone': consignorPhone,
        'consignorEmail': consignorEmail,
        'adjustments': adjustments.map((a) => a.toJson()).toList(),
        'documentsSentToConsignor': documentsSentToConsignor,
        'paymentNotificationSent': paymentNotificationSent,
        'grossWeight': grossWeight,
        'tareWeight': tareWeight,
        'lrNumber': lrNumber,
        'tdsDeduction': tdsDeduction,
        'penalties': penalties,
        'gstType': gstType.index,
        'gstRate': gstRate,
        'isGstInclusive': isGstInclusive,
        'weightTons': weightTons,
        'weightUnit': weightUnit,
        'lrNotes': lrNotes,
        'consignorGstin': consignorGstin,
        'isInTransit': isInTransit,
        'dispatchedAt': dispatchedAt,
        'estimatedArrival': estimatedArrival,
        'platformCommission': platformCommission,
        'consignorCommission': consignorCommission,
        'materialInvoiceNo': materialInvoiceNo,
        'invoiceItems': invoiceItems,
      };

  factory TripLedger.fromJson(Map<String, dynamic> json) => TripLedger(
        id: json['id'] ?? "TRP${math.Random().nextInt(9999)}",
        date: json['date'] ?? "",
        partyName: json['partyName'] ?? "",
        vehicleNo: json['vehicleNo'] ?? "",
        route: json['route'] ?? "",
        ownership: json['ownership'] != null
            ? VehicleOwnership.values[json['ownership']]
            : VehicleOwnership.self,
        eWayBillNo: json['eWayBillNo'] ?? "PENDING",
        materialName: json['materialName'] ?? "General Goods",
        freightBilled: (json['freightBilled'] as num?)?.toDouble() ?? 0,
        paymentReceived: (json['paymentReceived'] as num?)?.toDouble() ?? 0,
        diesel: (json['diesel'] as num?)?.toDouble() ?? 0,
        toll: (json['toll'] as num?)?.toDouble() ?? 0,
        driverExp: (json['driverExp'] as num?)?.toDouble() ?? 0,
        materialLoss: (json['materialLoss'] as num?)?.toDouble() ?? 0,
        marketTruckFreight:
            (json['marketTruckFreight'] as num?)?.toDouble() ?? 0,
        marketAdvancePaid: (json['marketAdvancePaid'] as num?)?.toDouble() ?? 0,
        driverName: json['driverName'],
        driverId: json['driverId'],
        paymentTermsDays: json['paymentTermsDays'] ?? 30,
        loadingPoint: json['loadingPoint'] ?? "",
        unloadingPoint: json['unloadingPoint'] ?? "",
        loadingState: json['loadingState'] ?? "",
        unloadingState: json['unloadingState'] ?? "",
        distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0,
        fuelEconomy: (json['fuelEconomy'] as num?)?.toDouble() ?? 3.5,
        dieselPricePerLitre:
            (json['dieselPricePerLitre'] as num?)?.toDouble() ?? 92.0,
        vehicleAxles: json['vehicleAxles'] ?? 6,
        consignorPhone: json['consignorPhone'] ?? "",
        consignorEmail: json['consignorEmail'] ?? "",
        adjustments: json['adjustments'] != null
            ? (json['adjustments'] as List)
                .map((a) => LedgerAdjustment.fromJson(a))
                .toList()
            : [],
        documentsSentToConsignor: json['documentsSentToConsignor'] ?? false,
        paymentNotificationSent: json['paymentNotificationSent'] ?? false,
        grossWeight: (json['grossWeight'] as num?)?.toDouble() ?? 0,
        tareWeight: (json['tareWeight'] as num?)?.toDouble() ?? 0,
        lrNumber: json['lrNumber'] ?? "",
        tdsDeduction: (json['tdsDeduction'] as num?)?.toDouble() ?? 0,
        penalties: (json['penalties'] as num?)?.toDouble() ?? 0,
        gstType: json['gstType'] != null
            ? GstType.values[json['gstType']]
            : GstType.none,
        gstRate: (json['gstRate'] as num?)?.toDouble() ?? 0,
        isGstInclusive: json['isGstInclusive'] ?? false,
        weightTons: (json['weightTons'] as num?)?.toDouble() ?? 0,
        weightUnit: json['weightUnit'] ?? "MT",
        lrNotes: json['lrNotes'] ?? "",
        consignorGstin: json['consignorGstin'] ?? "",
        isInTransit: json['isInTransit'] ?? false,
        dispatchedAt: json['dispatchedAt'] ?? "",
        estimatedArrival: json['estimatedArrival'] ?? "",
        platformCommission:
            (json['platformCommission'] as num?)?.toDouble() ?? 0,
        consignorCommission:
            (json['consignorCommission'] as num?)?.toDouble() ?? 0,
        materialInvoiceNo: json['materialInvoiceNo'] ?? "",
        invoiceItems: json['invoiceItems'] != null
            ? List<Map<String, dynamic>>.from(json['invoiceItems'])
            : [],
      );
}

class FleetDoc {
  String name;
  bool isUploaded;
  String expiryDate;
  FleetDoc(
      {required this.name,
      this.isUploaded = false,
      this.expiryDate = "Pending"});
  Map<String, dynamic> toJson() =>
      {'name': name, 'isUploaded': isUploaded, 'expiryDate': expiryDate};
  factory FleetDoc.fromJson(Map<String, dynamic> json) => FleetDoc(
      name: json['name'],
      isUploaded: json['isUploaded'] ?? false,
      expiryDate: json['expiryDate'] ?? "Pending");
}

class Battery {
  String make, serial;
  bool hasBill;
  Battery(this.make, this.serial, this.hasBill);
  Map<String, dynamic> toJson() =>
      {'make': make, 'serial': serial, 'hasBill': hasBill};
  factory Battery.fromJson(Map<String, dynamic> json) =>
      Battery(json['make'], json['serial'], json['hasBill']);
}

class Asset {
  String id, number, type, payload;
  int tyreCount;
  List<String> tyreSerials;
  List<Battery> batteries;
  List<FleetDoc> docs;
  int axleCount;
  String ownerName, ownerPhone;

  Asset({
    required this.id,
    required this.number,
    required this.type,
    required this.payload,
    required this.tyreCount,
    required this.tyreSerials,
    required this.batteries,
    required this.docs,
    this.axleCount = 6,
    this.ownerName = "",
    this.ownerPhone = "",
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'type': type,
        'payload': payload,
        'tyreCount': tyreCount,
        'tyreSerials': tyreSerials,
        'batteries': batteries.map((b) => b.toJson()).toList(),
        'docs': docs.map((d) => d.toJson()).toList(),
        'axleCount': axleCount,
        'ownerName': ownerName,
        'ownerPhone': ownerPhone,
      };
  factory Asset.fromJson(Map<String, dynamic> json) => Asset(
        id: json['id'],
        number: json['number'],
        type: json['type'],
        payload: json['payload'],
        tyreCount: json['tyreCount'],
        tyreSerials: List<String>.from(json['tyreSerials']),
        batteries: json['batteries'] != null
            ? (json['batteries'] as List)
                .map((b) => Battery.fromJson(b))
                .toList()
            : [],
        docs: json['docs'] != null
            ? (json['docs'] as List).map((d) => FleetDoc.fromJson(d)).toList()
            : [],
        axleCount: json['axleCount'] ?? 6,
        ownerName: json['ownerName'] ?? "",
        ownerPhone: json['ownerPhone'] ?? "",
      );
}

class MarketLoad {
  String id, route, details, vehicleType;
  double targetPrice;
  BidStatus status;
  String loadingState, unloadingState, loadingCity, unloadingCity;
  String materialType;
  double weightTons;
  String postedDate;

  MarketLoad({
    required this.id,
    required this.route,
    required this.details,
    required this.vehicleType,
    required this.targetPrice,
    this.status = BidStatus.pending,
    this.loadingState = "",
    this.unloadingState = "",
    this.loadingCity = "",
    this.unloadingCity = "",
    this.materialType = "",
    this.weightTons = 0,
    this.postedDate = "",
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'route': route,
        'details': details,
        'vehicleType': vehicleType,
        'targetPrice': targetPrice,
        'status': status.index,
        'loadingState': loadingState,
        'unloadingState': unloadingState,
        'loadingCity': loadingCity,
        'unloadingCity': unloadingCity,
        'materialType': materialType,
        'weightTons': weightTons,
        'postedDate': postedDate,
      };
  factory MarketLoad.fromJson(Map<String, dynamic> json) => MarketLoad(
        id: json['id'],
        route: json['route'],
        details: json['details'],
        vehicleType: json['vehicleType'],
        targetPrice: (json['targetPrice'] as num).toDouble(),
        status: BidStatus.values[json['status']],
        loadingState: json['loadingState'] ?? "",
        unloadingState: json['unloadingState'] ?? "",
        loadingCity: json['loadingCity'] ?? "",
        unloadingCity: json['unloadingCity'] ?? "",
        materialType: json['materialType'] ?? "",
        weightTons: (json['weightTons'] as num?)?.toDouble() ?? 0,
        postedDate: json['postedDate'] ?? "",
      );
}

// ==========================================
// GOOGLE MAPS / DISTANCE HELPER
// ==========================================
class RoutingEngine {
  static Future<Map<String, dynamic>> calculateRoute({
    required String origin,
    required String destination,
    int axles = 6,
    double fuelEconomy = 3.5,
    double dieselPrice = AppConfig.defaultDieselPrice,
  }) async {
    int km = 0;
    String source = "Smart Local Engine";

    if (AppConfig.googleMapsApiKey.isNotEmpty) {
      try {
        final enc = Uri.encodeComponent;
        final url = 'https://maps.googleapis.com/maps/api/distancematrix/json'
            '?origins=${enc(origin)}&destinations=${enc(destination)}'
            '&key=${AppConfig.googleMapsApiKey}&region=in&units=metric';
        final resp =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final meters =
              data['rows'][0]['elements'][0]['distance']['value'] as int;
          km = (meters / 1000).round();
          source = "Google Maps API";
        }
      } catch (_) {}
    }

    if (km == 0) {
      km =
          _smartDistanceLookup(origin.toLowerCase(), destination.toLowerCase());
      source = "Smart Local Engine";
    }

    double diesel = (km / fuelEconomy) * dieselPrice;
    // Toll: ₹2.0–2.5 per km per axle-pair (NHAI average for 4–6 axle)
    double tollPerKm = axles <= 2
        ? 1.2
        : axles <= 4
            ? 1.8
            : 2.2;
    double toll = km * tollPerKm;

    return {
      'km': km,
      'diesel': diesel.round(),
      'toll': toll.round(),
      'source': source,
      'axles': axles,
    };
  }

  static int _smartDistanceLookup(String o, String d) {
    final routes = <String, int>{
      'ahmedabad_mumbai': 530,
      'ahmedabad_delhi': 940,
      'ahmedabad_surat': 265,
      'ahmedabad_amritsar': 1150,
      'ahmedabad_pune': 660,
      'ahmedabad_jaipur': 680,
      'ahmedabad_indore': 590,
      'ahmedabad_nagpur': 870,
      'ahmedabad_hyderabad': 1050,
      'ahmedabad_bangalore': 1350,
      'ahmedabad_kolkata': 2020,
      'surat_mumbai': 290,
      'surat_delhi': 1200,
      'surat_pune': 390,
      'mumbai_delhi': 1420,
      'mumbai_bangalore': 990,
      'mumbai_hyderabad': 710,
      'mumbai_pune': 155,
      'mumbai_nagpur': 825,
      'delhi_jaipur': 270,
      'delhi_amritsar': 450,
      'delhi_lucknow': 550,
      'delhi_chandigarh': 250,
      'delhi_kolkata': 1500,
      'pune_bangalore': 840,
      'pune_hyderabad': 560,
      'bangalore_hyderabad': 570,
      'bangalore_chennai': 350,
      'hyderabad_chennai': 630,
      'hyderabad_kolkata': 1490,
      'kolkata_patna': 580,
      'kolkata_bhubaneswar': 440,
      'jaipur_amritsar': 500,
      'jaipur_jodhpur': 335,
      'bharuch_mumbai': 330,
      'bharuch_delhi': 900,
      'bharuch_surat': 80,
      'kandla_mumbai': 780,
      'kandla_delhi': 1200,
      'kandla_ahmedabad': 370,
      'hazira_mumbai': 320,
      'hazira_surat': 20,
      'hazira_ahmedabad': 280,
      'dahej_ahmedabad': 200,
      'dahej_surat': 150,
      'dahej_mumbai': 400,
    };

    String normalize(String s) => s
        .replaceAll(RegExp(r',.*'), '')
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^a-z]'), '');

    final a = normalize(o);
    final b = normalize(d);

    final key1 = '${a}_$b';
    final key2 = '${b}_$a';
    if (routes.containsKey(key1)) return routes[key1]!;
    if (routes.containsKey(key2)) return routes[key2]!;

    for (final entry in routes.entries) {
      final parts = entry.key.split('_');
      if ((parts[0].contains(a) || a.contains(parts[0])) &&
          (parts[1].contains(b) || b.contains(parts[1]))) {
        return entry.value;
      }
      if ((parts[1].contains(a) || a.contains(parts[1])) &&
          (parts[0].contains(b) || b.contains(parts[0]))) {
        return entry.value;
      }
    }

    return (a.length + b.length) * 35 + 200;
  }

  static Future<List<String>> getPlaceSuggestions(String query) async {
    if (query.length < 2) return [];

    if (AppConfig.googleMapsApiKey.isNotEmpty) {
      try {
        final enc = Uri.encodeComponent;
        final url =
            'https://maps.googleapis.com/maps/api/place/autocomplete/json'
            '?input=${enc(query)}&components=country:in&types=geocode'
            '&key=${AppConfig.googleMapsApiKey}';
        final resp =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          final data = jsonDecode(resp.body);
          final preds = data['predictions'] as List;
          return preds.map((p) => p['description'].toString()).take(6).toList();
        }
      } catch (_) {}
    }

    return IndiaData.searchCities(query);
  }
}

// ==========================================
// CSV / BANK STATEMENT PARSER
// ==========================================
class BankStatementParser {
  static List<BankTransaction> parseCSV(
      String csvContent, List<TripLedger> ledgers) {
    final lines = csvContent.split('\n');
    if (lines.isEmpty) return [];

    final transactions = <BankTransaction>[];

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final cols = _splitCsv(line);
      if (cols.length < 3) continue;

      try {
        final tx = BankTransaction(
          date: cols[0].trim(),
          description: cols.length > 1 ? cols[1].trim() : '',
          ref: cols.length > 2 ? cols[2].trim() : '',
          debit: cols.length > 3
              ? (double.tryParse(cols[3].replaceAll(',', '').trim()) ?? 0)
              : 0,
          credit: cols.length > 4
              ? (double.tryParse(cols[4].replaceAll(',', '').trim()) ?? 0)
              : 0,
        );

        for (final ledger in ledgers) {
          if (_fuzzyMatch(tx.description, ledger.partyName)) {
            tx.isMatched = true;
            tx.matchedTripId = ledger.id;
            tx.matchedParty = ledger.partyName;
            break;
          }
        }

        transactions.add(tx);
      } catch (_) {}
    }

    return transactions;
  }

  static bool _fuzzyMatch(String bankDesc, String partyName) {
    final a = bankDesc.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final b = partyName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (a.isEmpty || b.isEmpty) return false;
    for (final word in b.split(RegExp(r'\s+'))) {
      if (word.length > 3 &&
          a.contains(word.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''))) {
        return true;
      }
    }
    return false;
  }

  static List<String> _splitCsv(String line) {
    final result = <String>[];
    bool inQuotes = false;
    final current = StringBuffer();
    for (int i = 0; i < line.length; i++) {
      if (line[i] == '"') {
        inQuotes = !inQuotes;
      } else if (line[i] == ',' && !inQuotes) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(line[i]);
      }
    }
    result.add(current.toString());
    return result;
  }

  static String generateTallyExport(
      List<TripLedger> ledgers, UserProfile profile) {
    final sb = StringBuffer();
    sb.writeln(
        '"Voucher Type","Date","Voucher No","Party Name","Narration","Dr/Cr","Amount","Ledger"');

    for (final l in ledgers) {
      sb.writeln(
          '"Sales","${l.date}","${l.lrNumber.isNotEmpty ? l.lrNumber : l.id}","${l.partyName}",'
          '"Freight for ${l.materialName} - ${l.route}","Cr","${l.freightBilled.toStringAsFixed(2)}","Freight Income"');

      if (l.ownership == VehicleOwnership.self) {
        if (l.diesel > 0) {
          sb.writeln('"Payment","${l.date}","${l.id}","${l.vehicleNo}",'
              '"Diesel for ${l.route}","Dr","${l.diesel.toStringAsFixed(2)}","Diesel Expenses"');
        }
        if (l.toll > 0) {
          sb.writeln('"Payment","${l.date}","${l.id}","${l.vehicleNo}",'
              '"Toll/Fastag - ${l.route}","Dr","${l.toll.toStringAsFixed(2)}","Toll Expenses"');
        }
        if (l.driverExp > 0) {
          sb.writeln(
              '"Payment","${l.date}","${l.id}","${l.driverName ?? 'Driver'}",'
              '"Driver expenses - ${l.route}","Dr","${l.driverExp.toStringAsFixed(2)}","Driver Expenses"');
        }
      } else {
        sb.writeln('"Payment","${l.date}","${l.id}","Market Transporter",'
            '"Market truck freight - ${l.route}","Dr","${l.marketTruckFreight.toStringAsFixed(2)}","Market Truck Freight"');
      }

      for (final adj in l.adjustments) {
        sb.writeln('"Journal","${adj.date}","ADJ-${l.id}","${l.partyName}",'
            '"${adj.typeLabel} - ${adj.note}","${adj.isDeduction ? 'Dr' : 'Cr'}","${adj.amount.toStringAsFixed(2)}","${adj.typeLabel}"');
      }

      if (l.paymentReceived > 0) {
        sb.writeln('"Receipt","${l.date}","RCP-${l.id}","${l.partyName}",'
            '"Payment received for ${l.route}","Dr","${l.paymentReceived.toStringAsFixed(2)}","${l.partyName}"');
      }
    }

    return sb.toString();
  }

  static String generateCAAuditExport(
      List<TripLedger> ledgers, List<Driver> drivers, UserProfile profile) {
    final sb = StringBuffer();
    sb.writeln(
        '"COMPANY: ${profile.companyName} | GSTIN: ${profile.gstin} | PAN: ${profile.panNumber}"');
    sb.writeln(
        '"CA AUDIT EXPORT — Generated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}"');
    sb.writeln('');
    sb.writeln('"=== TRIP LEDGER SUMMARY ==="');
    sb.writeln(
        '"Trip ID","Date","LR No","Party","Vehicle","Route","Material","E-Way Bill",'
        '"Freight Billed","Payment Received","Pending","Diesel","Toll","Driver Exp","Material Loss",'
        '"Market Freight","Profit/Commission","Adjustments","Net Profit","Status"');

    for (final l in ledgers) {
      final adj = l.totalAdjustmentDeductions - l.totalAdjustmentAdditions;
      final status = l.partyPending <= 0
          ? 'Cleared'
          : (l.isPaymentDue ? 'OVERDUE' : 'Pending');
      sb.writeln(
          '"${l.id}","${l.date}","${l.lrNumber.isNotEmpty ? l.lrNumber : 'N/A'}","${l.partyName}",'
          '"${l.vehicleNo}","${l.route}","${l.materialName}","${l.eWayBillNo}",'
          '"${l.freightBilled}","${l.paymentReceived}","${l.partyPending.toStringAsFixed(2)}",'
          '"${l.diesel}","${l.toll}","${l.driverExp}","${l.materialLoss}",'
          '"${l.marketTruckFreight}","${l.tripProfit.toStringAsFixed(2)}",'
          '"${adj.toStringAsFixed(2)}","${l.tripProfit.toStringAsFixed(2)}","$status"');
    }

    sb.writeln('');
    sb.writeln('"=== PARTY-WISE SUMMARY ==="');
    sb.writeln(
        '"Party Name","Total Billed","Total Received","Outstanding","Trips"');
    final partyMap = <String, Map<String, dynamic>>{};
    for (final l in ledgers) {
      partyMap.putIfAbsent(
          l.partyName, () => {'billed': 0.0, 'received': 0.0, 'trips': 0});
      partyMap[l.partyName]!['billed'] =
          (partyMap[l.partyName]!['billed'] as double) + l.freightBilled;
      partyMap[l.partyName]!['received'] =
          (partyMap[l.partyName]!['received'] as double) + l.paymentReceived;
      partyMap[l.partyName]!['trips'] =
          (partyMap[l.partyName]!['trips'] as int) + 1;
    }
    partyMap.forEach((party, data) {
      final billed = data['billed'] as double;
      final received = data['received'] as double;
      sb.writeln(
          '"$party","${billed.toStringAsFixed(2)}","${received.toStringAsFixed(2)}",'
          '"${(billed - received).toStringAsFixed(2)}","${data['trips']}"');
    });

    sb.writeln('');
    sb.writeln('"=== DRIVER LEDGER ==="');
    sb.writeln(
        '"Driver Name","Phone","Outstanding Balance","Total Advance","Total Salary","Trips"');
    for (final d in drivers) {
      final totalAdv = d.transactions
          .where((t) => t.type == DriverTxType.advance)
          .fold(0.0, (s, t) => s + t.amount.abs());
      final totalSal = d.transactions
          .where((t) => t.type == DriverTxType.salary)
          .fold(0.0, (s, t) => s + t.amount.abs());
      sb.writeln(
          '"${d.name}","${d.phone}","${d.balance.toStringAsFixed(2)}","${totalAdv.toStringAsFixed(2)}","${totalSal.toStringAsFixed(2)}","${d.transactions.length}"');
    }

    return sb.toString();
  }
}

// ==========================================
// CITY SEARCH FIELD UI
// ==========================================
