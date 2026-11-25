// ============================================================
// enums.dart  —  part of liquid_logistics main library
// Auto-extracted from main_v23_8.dart (original lines 1070-1104)
// DO NOT add imports here — all imports live in main.dart
// ============================================================
part of 'package:liquid_logistics/main.dart';

enum UserRole { visitor, verified, owner, driver, admin, developer }

enum AppUserType { driver, consignor, fleetOwner }

enum BidStatus { pending, booked, inTransit, delivered, cancelled }

enum VehicleOwnership { self, market }

enum DriverTxType { advance, salary, penalty, fuel, bonus, deduction }

enum SubscriptionTier { free, pro, business, enterprise }

enum KredXStatus {
  draft,
  submitted,
  underReview,
  approved,
  disbursed,
  rejected
}

enum TripStatus { active, completed, overdue }

enum GstType { none, cgstSgst, igst }

enum DocUploadMethod { camera, gallery, file }

enum ExpenseReceiptType { toll, fuel, driverAdvance, repair, other }

enum PodBillingStatus { scanned, invoiceDrafted, invoicePosted }

enum BreakdownPriority { service, urgent, sos }

// ================================================================
// VEHICLE COMPLIANCE DOCS BY TYPE
// ================================================================
