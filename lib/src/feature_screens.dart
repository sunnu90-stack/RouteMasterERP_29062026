// ============================================================
// feature_screens.dart  —  part of liquid_logistics main library
// Auto-extracted from main_v23_8.dart (original lines 20310-26964)
// DO NOT add imports here — all imports live in main.dart
// ============================================================
part of 'package:liquid_logistics/main.dart';

class TripDetailScreen extends StatefulWidget {
  final TripLedger ledger;
  final UserProfile userProfile;
  final SubscriptionInfo subscription;
  final List<Driver> drivers;
  final Function(TripLedger) onUpdateLedger;
  final Function(KredXApplication) onKredXApply;
  const TripDetailScreen(
      {super.key,
      required this.ledger,
      required this.userProfile,
      required this.subscription,
      required this.drivers,
      required this.onUpdateLedger,
      required this.onKredXApply});
  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late TripLedger _l;
  @override
  void initState() {
    super.initState();
    _l = widget.ledger;
  }

  String _f(double v) => v.toStringAsFixed(2);

  pw.Widget _cell(String t,
          {bool hdr = false,
          bool bold = false,
          pw.TextAlign? align,
          PdfColor? col}) =>
      pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(t,
              textAlign: align,
              style: pw.TextStyle(
                  fontSize: hdr ? 9 : 10,
                  fontWeight:
                      hdr || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: hdr
                      ? const PdfColor(1.0, 1.0, 1.0)
                      : (col ?? const PdfColor(0.15, 0.15, 0.15)))));
  pw.Widget _pRow(String l, String v) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(children: [
        pw.Text("$l: ",
            style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: const PdfColor(0.4, 0.4, 0.4))),
        pw.Flexible(child: pw.Text(v, style: const pw.TextStyle(fontSize: 9)))
      ]));

  Future<void> _shareLR() async {
    if (!widget.subscription.canExportPDF) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          content: Text("PDF Export requires PRO plan or above")));
      return;
    }
    final pdf = pw.Document();
    final up = widget.userProfile;
    final l = _l;

    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) {
          pw.Widget borderBox(pw.Widget child, {pw.EdgeInsets? pad}) =>
              pw.Container(
                  padding: pad ?? const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                      border: pw.Border.all(
                          color: const PdfColor(0.75, 0.75, 0.75), width: 0.6)),
                  child: child);

          // ignore: unused_element
          pw.Widget label(String t) =>
              pw.Text(t.toUpperCase(), // used for PDF generation
                  style: const pw.TextStyle(
                      fontSize: 7, color: PdfColor(0.5, 0.5, 0.5)));
          pw.Widget value(String t, {bool bold = false, double size = 10}) =>
              pw.Text(t,
                  style: pw.TextStyle(
                      fontSize: size,
                      fontWeight:
                          bold ? pw.FontWeight.bold : pw.FontWeight.normal));

          final balance = l.freightBilled - l.paymentReceived;
          final fromCity = l.loadingPoint.isNotEmpty
              ? l.loadingPoint
              : l.route.split('->').first.trim();
          final toCity = l.unloadingPoint.isNotEmpty
              ? l.unloadingPoint
              : l.route.split('->').last.trim();

          return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                //
                pw.Container(
                    color: const PdfColor(0.04, 0.15, 0.35),
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                              child: pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                pw.Text(up.companyName.toUpperCase(),
                                    style: pw.TextStyle(
                                        fontSize: 18,
                                        fontWeight: pw.FontWeight.bold,
                                        color: const PdfColor(1.0, 1.0, 1.0),
                                        letterSpacing: 1)),
                                pw.SizedBox(height: 2),
                                if (up.address.isNotEmpty)
                                  pw.Text(up.address,
                                      style: const pw.TextStyle(
                                          fontSize: 8,
                                          color: PdfColor(0.7, 0.8, 0.9))),
                                pw.Text(
                                    "Tel: ${up.phone}${up.gstin.isNotEmpty ? '  |  GST: ${up.gstin}' : ''}",
                                    style: const pw.TextStyle(
                                        fontSize: 8,
                                        color: PdfColor(0.7, 0.8, 0.9))),
                              ])),
                          pw.SizedBox(width: 24),
                          pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    color: const PdfColor(0.95, 0.45, 0.05),
                                    child: pw.Text("LORRY RECEIPT",
                                        style: pw.TextStyle(
                                            fontSize: 13,
                                            fontWeight: pw.FontWeight.bold,
                                            color:
                                                const PdfColor(1.0, 1.0, 1.0),
                                            letterSpacing: 1.5))),
                                pw.SizedBox(height: 5),
                                pw.Text("LR No:  LR-${l.id}",
                                    style: pw.TextStyle(
                                        fontWeight: pw.FontWeight.bold,
                                        fontSize: 10,
                                        color: const PdfColor(1.0, 1.0, 1.0))),
                                pw.Text("Date:  ${l.date}",
                                    style: const pw.TextStyle(
                                        fontSize: 9,
                                        color: PdfColor(0.75, 0.75, 0.85))),
                              ]),
                        ])),

                //
                pw.Row(children: [
                  pw.Expanded(
                      child: borderBox(
                          pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(children: [
                                  pw.Container(
                                      width: 3,
                                      height: 3,
                                      decoration: const pw.BoxDecoration(
                                          shape: pw.BoxShape.circle,
                                          color: PdfColor(0.0, 0.6, 0.3))),
                                  pw.SizedBox(width: 4),
                                  pw.Text("CONSIGNOR (FROM)",
                                      style: const pw.TextStyle(
                                          fontSize: 7,
                                          color: PdfColor(0.5, 0.5, 0.5)))
                                ]),
                                pw.SizedBox(height: 4),
                                value(l.partyName.toUpperCase(),
                                    bold: true, size: 12),
                                value(fromCity, size: 9),
                                if (l.loadingState.isNotEmpty)
                                  value(l.loadingState, size: 9),
                                if (l.consignorPhone.isNotEmpty)
                                  value("Tel: ${l.consignorPhone}", size: 8),
                                if (l.consignorGstin.isNotEmpty)
                                  value("GSTIN: ${l.consignorGstin}", size: 8),
                              ]),
                          pad: const pw.EdgeInsets.all(10))),
                  pw.Expanded(
                      child: borderBox(
                          pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Row(children: [
                                  pw.Container(
                                      width: 3,
                                      height: 3,
                                      decoration: const pw.BoxDecoration(
                                          shape: pw.BoxShape.circle,
                                          color: PdfColor(0.8, 0.1, 0.1))),
                                  pw.SizedBox(width: 4),
                                  pw.Text("CONSIGNEE (TO)",
                                      style: const pw.TextStyle(
                                          fontSize: 7,
                                          color: PdfColor(0.5, 0.5, 0.5)))
                                ]),
                                pw.SizedBox(height: 4),
                                value(toCity.toUpperCase(),
                                    bold: true, size: 12),
                                if (l.unloadingState.isNotEmpty)
                                  value(l.unloadingState, size: 9),
                                value("Delivery at: $toCity", size: 8),
                              ]),
                          pad: const pw.EdgeInsets.all(10))),
                ]),

                //
                borderBox(
                    pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("SHIPMENT DETAILS",
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: const PdfColor(0.04, 0.15, 0.35))),
                          pw.SizedBox(height: 8),
                          pw.Table(
                              border: pw.TableBorder.all(
                                  color: const PdfColor(0.88, 0.88, 0.88),
                                  width: 0.5),
                              columnWidths: {
                                0: const pw.FlexColumnWidth(2),
                                1: const pw.FlexColumnWidth(3),
                                2: const pw.FlexColumnWidth(2),
                                3: const pw.FlexColumnWidth(3),
                              },
                              children: [
                                pw.TableRow(
                                    decoration: const pw.BoxDecoration(
                                        color: PdfColor(0.93, 0.95, 0.99)),
                                    children: [
                                      pw.Padding(
                                          padding: const pw.EdgeInsets.all(5),
                                          child: pw.Text("Vehicle No",
                                              style: pw.TextStyle(
                                                  fontSize: 8,
                                                  fontWeight:
                                                      pw.FontWeight.bold))),
                                      pw.Padding(
                                          padding: const pw.EdgeInsets.all(5),
                                          child: pw.Text(l.vehicleNo,
                                              style: pw.TextStyle(
                                                  fontSize: 9,
                                                  fontWeight:
                                                      pw.FontWeight.bold))),
                                      pw.Padding(
                                          padding: const pw.EdgeInsets.all(5),
                                          child: pw.Text("Driver",
                                              style: pw.TextStyle(
                                                  fontSize: 8,
                                                  fontWeight:
                                                      pw.FontWeight.bold))),
                                      pw.Padding(
                                          padding: const pw.EdgeInsets.all(5),
                                          child: pw.Text(l.driverName ?? "-",
                                              style: const pw.TextStyle(
                                                  fontSize: 9))),
                                    ]),
                                pw.TableRow(children: [
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text("Material",
                                          style: pw.TextStyle(
                                              fontSize: 8,
                                              fontWeight: pw.FontWeight.bold))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text(l.materialName,
                                          style:
                                              const pw.TextStyle(fontSize: 9))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text("Weight",
                                          style: pw.TextStyle(
                                              fontSize: 8,
                                              fontWeight: pw.FontWeight.bold))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text(
                                          l.weightTons > 0
                                              ? "${l.weightTons} ${l.weightUnit}"
                                              : "As per weighbridge",
                                          style:
                                              const pw.TextStyle(fontSize: 9))),
                                ]),
                                pw.TableRow(children: [
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text("E-Way Bill",
                                          style: pw.TextStyle(
                                              fontSize: 8,
                                              fontWeight: pw.FontWeight.bold))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text(l.eWayBillNo,
                                          style:
                                              const pw.TextStyle(fontSize: 9))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text("Distance",
                                          style: pw.TextStyle(
                                              fontSize: 8,
                                              fontWeight: pw.FontWeight.bold))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text(
                                          l.distanceKm > 0
                                              ? "${l.distanceKm.toStringAsFixed(0)} km"
                                              : "-",
                                          style:
                                              const pw.TextStyle(fontSize: 9))),
                                ]),
                                if (l.materialInvoiceNo.isNotEmpty)
                                  pw.TableRow(children: [
                                    pw.Padding(
                                        padding: const pw.EdgeInsets.all(5),
                                        child: pw.Text("Invoice No.",
                                            style: pw.TextStyle(
                                                fontSize: 8,
                                                fontWeight:
                                                    pw.FontWeight.bold))),
                                    pw.Padding(
                                        padding: const pw.EdgeInsets.all(5),
                                        child: pw.Text(l.materialInvoiceNo,
                                            style: const pw.TextStyle(
                                                fontSize: 9))),
                                    pw.Padding(
                                        padding: const pw.EdgeInsets.all(5),
                                        child: pw.Text("Weight",
                                            style: pw.TextStyle(
                                                fontSize: 8,
                                                fontWeight:
                                                    pw.FontWeight.bold))),
                                    pw.Padding(
                                        padding: const pw.EdgeInsets.all(5),
                                        child: pw.Text(
                                            l.weightTons > 0
                                                ? "${l.weightTons} ${l.weightUnit}"
                                                : "As per weighbridge",
                                            style: const pw.TextStyle(
                                                fontSize: 9))),
                                  ]),
                                pw.TableRow(children: [
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text("Loading Date",
                                          style: pw.TextStyle(
                                              fontSize: 8,
                                              fontWeight: pw.FontWeight.bold))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text(l.date,
                                          style:
                                              const pw.TextStyle(fontSize: 9))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text("Pay Terms",
                                          style: pw.TextStyle(
                                              fontSize: 8,
                                              fontWeight: pw.FontWeight.bold))),
                                  pw.Padding(
                                      padding: const pw.EdgeInsets.all(5),
                                      child: pw.Text(
                                          "${l.paymentTermsDays} Days from delivery",
                                          style:
                                              const pw.TextStyle(fontSize: 9))),
                                ]),
                              ]),
                        ]),
                    pad: const pw.EdgeInsets.all(10)),

                //
                pw.SizedBox(height: 4),
                pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Expanded(
                          flex: 3,
                          child: borderBox(
                              pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Text("FREIGHT DETAILS",
                                        style: pw.TextStyle(
                                            fontSize: 9,
                                            fontWeight: pw.FontWeight.bold,
                                            color: const PdfColor(
                                                0.05, 0.09, 0.16))),
                                    pw.SizedBox(height: 8),
                                    pw.Row(
                                        mainAxisAlignment:
                                            pw.MainAxisAlignment.spaceBetween,
                                        children: [
                                          pw.Text("Agreed Freight:",
                                              style: pw.TextStyle(
                                                  fontSize: 9,
                                                  fontWeight:
                                                      pw.FontWeight.bold)),
                                          pw.Text(
                                              "INR ${l.freightBilled.toStringAsFixed(2)}",
                                              style: pw.TextStyle(
                                                  fontSize: 9,
                                                  fontWeight:
                                                      pw.FontWeight.bold))
                                        ]),
                                    if (l.paymentReceived > 0) ...[
                                      pw.SizedBox(height: 3),
                                      pw.Row(
                                          mainAxisAlignment:
                                              pw.MainAxisAlignment.spaceBetween,
                                          children: [
                                            pw.Text("Advance Paid:",
                                                style: const pw.TextStyle(
                                                    fontSize: 9,
                                                    color: PdfColor(
                                                        0.4, 0.4, 0.4))),
                                            pw.Text(
                                                "INR ${l.paymentReceived.toStringAsFixed(2)}",
                                                style: const pw.TextStyle(
                                                    fontSize: 9,
                                                    color: PdfColor(
                                                        0.5, 0.3, 0.0)))
                                          ]),
                                    ],
                                    pw.SizedBox(height: 6),
                                    pw.Container(
                                        color: const PdfColor(0.04, 0.15, 0.35),
                                        padding: const pw.EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 6),
                                        child: pw.Row(
                                            mainAxisAlignment: pw
                                                .MainAxisAlignment.spaceBetween,
                                            children: [
                                              pw.Text("BALANCE ON DELIVERY:",
                                                  style: pw.TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          pw.FontWeight.bold,
                                                      color: const PdfColor(
                                                          0.1, 0.23, 0.1))),
                                              pw.Text(
                                                  "INR ${balance.toStringAsFixed(2)}",
                                                  style: pw.TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          pw.FontWeight.bold,
                                                      color: balance > 0
                                                          ? const PdfColor(
                                                              0.0, 0.9, 0.4)
                                                          : const PdfColor(
                                                              0.1, 0.23, 0.1))),
                                            ])),
                                  ]),
                              pad: const pw.EdgeInsets.all(10))),
                      pw.SizedBox(width: 4),
                      pw.Expanded(
                          flex: 2,
                          child: pw.Container(
                              height: double.infinity,
                              padding: const pw.EdgeInsets.all(10),
                              decoration: pw.BoxDecoration(
                                  border: pw.Border.all(
                                      color: const PdfColor(0.75, 0.75, 0.75),
                                      width: 0.6)),
                              child: pw.Column(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.center,
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.center,
                                  children: [
                                    pw.Text("AUTHORISED SIGNATORY",
                                        style: const pw.TextStyle(
                                            fontSize: 8,
                                            color: PdfColor(0.5, 0.5, 0.5))),
                                    pw.SizedBox(height: 30),
                                    pw.Container(
                                        width: 100,
                                        height: 0.7,
                                        color: const PdfColor(0.3, 0.3, 0.3)),
                                    pw.SizedBox(height: 4),
                                    pw.Text(up.companyName,
                                        style: pw.TextStyle(
                                            fontSize: 8,
                                            fontWeight: pw.FontWeight.bold)),
                                    pw.Text("Stamp & Seal",
                                        style: const pw.TextStyle(
                                            fontSize: 7,
                                            color: PdfColor(0.6, 0.6, 0.6))),
                                  ]))),
                    ]),

                //
                if (l.invoiceItems.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Text("PART LOAD CONSIGNMENT DETAILS",
                      style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor(0.04, 0.15, 0.35))),
                  pw.SizedBox(height: 4),
                  pw.Table(
                      border: pw.TableBorder.all(
                          color: const PdfColor(0.85, 0.85, 0.85), width: 0.5),
                      columnWidths: {
                        0: const pw.FixedColumnWidth(20),
                        1: const pw.FlexColumnWidth(3),
                        2: const pw.FlexColumnWidth(2),
                        3: const pw.FlexColumnWidth(2)
                      },
                      children: [
                        pw.TableRow(
                            decoration: const pw.BoxDecoration(
                                color: PdfColor(0.1, 0.1, 0.1)),
                            children: ['#', 'Material', 'Invoice No.', 'Weight']
                                .map((h) => pw.Padding(
                                    padding: const pw.EdgeInsets.all(4),
                                    child: pw.Text(h,
                                        style: pw.TextStyle(
                                            fontSize: 8,
                                            fontWeight: pw.FontWeight.bold,
                                            color: const PdfColor(
                                                0.1, 0.23, 0.1)))))
                                .toList()),
                        ...l.invoiceItems.asMap().entries.map((e) =>
                            pw.TableRow(children: [
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text("${e.key + 1}",
                                      style: const pw.TextStyle(fontSize: 8))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(e.value.materialName,
                                      style: const pw.TextStyle(fontSize: 8))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(
                                      e.value.invoiceNo.isNotEmpty
                                          ? e.value.invoiceNo
                                          : "-",
                                      style: const pw.TextStyle(fontSize: 8))),
                              pw.Padding(
                                  padding: const pw.EdgeInsets.all(4),
                                  child: pw.Text(
                                      "${e.value.weight} ${e.value.weightUnit}",
                                      style: const pw.TextStyle(fontSize: 8))),
                            ])),
                      ]),
                ],

                //
                pw.SizedBox(height: 8),
                pw.Container(
                    color: const PdfColor(0.97, 0.97, 0.97),
                    padding: const pw.EdgeInsets.all(8),
                    child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("Terms & Conditions",
                              style: pw.TextStyle(
                                  fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 3),
                          pw.Text(
                              "1. Goods received in apparent good order and condition.  2. Carrier's liability limited as per Carriage by Road Act.  3. Subject to ${up.address.split(',').last.trim()} jurisdiction.  4. Interest @ 2% per month on delayed payments.  5. E. & O.E.",
                              style: const pw.TextStyle(
                                  fontSize: 7.5,
                                  color: PdfColor(0.4, 0.4, 0.4))),
                          if (up.bankAccount.isNotEmpty) ...[
                            pw.SizedBox(height: 4),
                            pw.Text(
                                "Bank: ${up.bankName}  |  A/C No: ${up.bankAccount}  |  IFSC: ${up.bankIfsc}",
                                style: pw.TextStyle(
                                    fontSize: 7.5,
                                    fontWeight: pw.FontWeight.bold,
                                    color: const PdfColor(0.2, 0.2, 0.5)))
                          ],
                        ])),

                if (l.lrNotes.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      color: const PdfColor(1.0, 0.97, 0.88),
                      child: pw.Text("Remarks: ${l.lrNotes}",
                          style: const pw.TextStyle(
                              fontSize: 9, color: PdfColor(0.4, 0.3, 0.0)))),
                ],

                // DRIVER COPY footer line
                pw.SizedBox(height: 8),
                pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          color: const PdfColor(0.9, 0.9, 0.9),
                          child: pw.Text("DRIVER COPY",
                              style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColor(0.4, 0.4, 0.4)))),
                      pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          color: const PdfColor(0.9, 0.9, 0.9),
                          child: pw.Text("CONSIGNOR COPY",
                              style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColor(0.4, 0.4, 0.4)))),
                      pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          color: const PdfColor(0.9, 0.9, 0.9),
                          child: pw.Text("OFFICE COPY",
                              style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColor(0.4, 0.4, 0.4)))),
                    ]),
              ]);
        }));

    try {
      await Printing.sharePdf(
          bytes: await pdf.save(),
          filename: 'LR_${l.id}_${l.partyName.replaceAll(' ', '_')}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("PDF Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _shareInvoice() async {
    if (!widget.subscription.canExportPDF) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          content: Text("PDF Export requires PRO or BUSINESS plan")));
      return;
    }
    final pdf = pw.Document();
    final up = widget.userProfile;
    final l = _l;
    final cgst = l.gstType == GstType.cgstSgst ? l.gstAmount / 2 : 0.0;
    final sgst = l.gstType == GstType.cgstSgst ? l.gstAmount / 2 : 0.0;
    final igst = l.gstType == GstType.igst ? l.gstAmount : 0.0;
    pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(up.companyName.toUpperCase(),
                                  style: pw.TextStyle(
                                      fontSize: 20,
                                      fontWeight: pw.FontWeight.bold,
                                      color: const PdfColor(0.04, 0.15, 0.35))),
                              pw.SizedBox(height: 4),
                              pw.Text(up.address,
                                  style: const pw.TextStyle(
                                      fontSize: 10,
                                      color: PdfColor(0.4, 0.4, 0.4))),
                              pw.Text("Tel: ${up.phone}",
                                  style: const pw.TextStyle(
                                      fontSize: 10,
                                      color: PdfColor(0.4, 0.4, 0.4))),
                              if (up.gstin.isNotEmpty &&
                                  up.gstin != "Unregistered")
                                pw.Text("GSTIN: ${up.gstin}",
                                    style: pw.TextStyle(
                                        fontSize: 10,
                                        fontWeight: pw.FontWeight.bold)),
                              if (up.email.isNotEmpty)
                                pw.Text("Email: ${up.email}",
                                    style: const pw.TextStyle(
                                        fontSize: 10,
                                        color: PdfColor(0.4, 0.4, 0.4)))
                            ]),
                        pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.end,
                            children: [
                              pw.Container(
                                  padding: const pw.EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: pw.BoxDecoration(
                                      color: const PdfColor(0.04, 0.15, 0.35),
                                      borderRadius:
                                          pw.BorderRadius.circular(6)),
                                  child: pw.Text("TAX INVOICE",
                                      style: pw.TextStyle(
                                          fontSize: 14,
                                          fontWeight: pw.FontWeight.bold,
                                          color:
                                              const PdfColor(1.0, 1.0, 1.0)))),
                              pw.SizedBox(height: 8),
                              pw.Text("Invoice No: INV-${l.id}",
                                  style: pw.TextStyle(
                                      fontWeight: pw.FontWeight.bold,
                                      fontSize: 11)),
                              pw.Text("Date: ${l.date}",
                                  style: const pw.TextStyle(
                                      fontSize: 10,
                                      color: PdfColor(0.4, 0.4, 0.4))),
                              pw.Text("Due: ${l.paymentTermsDays} Days",
                                  style: const pw.TextStyle(
                                      fontSize: 10,
                                      color: PdfColor(0.4, 0.4, 0.4)))
                            ]),
                      ]),
                  pw.SizedBox(height: 16),
                  pw.Divider(
                      color: const PdfColor(0.04, 0.15, 0.35), thickness: 1.5),
                  pw.SizedBox(height: 14),
                  pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Expanded(
                            child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                              pw.Text("BILL TO:",
                                  style: const pw.TextStyle(
                                      fontSize: 9,
                                      color: PdfColor(0.5, 0.5, 0.5))),
                              pw.SizedBox(height: 4),
                              pw.Text(l.partyName.toUpperCase(),
                                  style: pw.TextStyle(
                                      fontSize: 15,
                                      fontWeight: pw.FontWeight.bold)),
                              if (l.consignorGstin.isNotEmpty)
                                pw.Text("GSTIN: ${l.consignorGstin}",
                                    style: const pw.TextStyle(fontSize: 10)),
                              if (l.consignorPhone.isNotEmpty)
                                pw.Text("Phone: ${l.consignorPhone}",
                                    style: const pw.TextStyle(fontSize: 10))
                            ])),
                        pw.SizedBox(width: 20),
                        pw.Expanded(
                            child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                              pw.Text("SHIPMENT:",
                                  style: const pw.TextStyle(
                                      fontSize: 9,
                                      color: PdfColor(0.5, 0.5, 0.5))),
                              pw.SizedBox(height: 4),
                              _pRow("Route",
                                  "${l.loadingPoint.isNotEmpty ? l.loadingPoint : ''} -> ${l.unloadingPoint.isNotEmpty ? l.unloadingPoint : l.route.split('->').last.trim()}"),
                              _pRow("Vehicle", l.vehicleNo),
                              _pRow("Material", l.materialName),
                              if (l.weightTons > 0)
                                _pRow("Weight",
                                    "${l.weightTons} ${l.weightUnit}"),
                              _pRow("E-Way", l.eWayBillNo),
                              if (l.driverName != null)
                                _pRow("Driver", l.driverName!)
                            ])),
                      ]),
                  pw.SizedBox(height: 16),
                  pw.Table(
                      border: pw.TableBorder.all(
                          color: const PdfColor(0.85, 0.85, 0.85), width: 0.8),
                      columnWidths: {
                        0: const pw.FixedColumnWidth(28),
                        1: const pw.FlexColumnWidth(5),
                        2: const pw.FlexColumnWidth(2)
                      },
                      children: [
                        pw.TableRow(
                            decoration: const pw.BoxDecoration(
                                color: PdfColor(0.05, 0.09, 0.16)),
                            children: [
                              _cell("#", hdr: true, align: pw.TextAlign.center),
                              _cell("DESCRIPTION", hdr: true),
                              _cell("AMOUNT (Rs.)",
                                  hdr: true, align: pw.TextAlign.right)
                            ]),
                        pw.TableRow(children: [
                          _cell("1", align: pw.TextAlign.center),
                          _cell(
                              "Freight for ${l.materialName}\n${l.route}\nVehicle: ${l.vehicleNo}${l.weightTons > 0 ? ' | ${l.weightTons} ${l.weightUnit}' : ''}"),
                          _cell(_f(l.taxableFreight), align: pw.TextAlign.right)
                        ]),
                        if (l.gstType == GstType.cgstSgst) ...[
                          pw.TableRow(children: [
                            _cell("", align: pw.TextAlign.center),
                            _cell("CGST @ ${l.gstRate / 2}%"),
                            _cell(_f(cgst), align: pw.TextAlign.right)
                          ]),
                          pw.TableRow(children: [
                            _cell("", align: pw.TextAlign.center),
                            _cell("SGST @ ${l.gstRate / 2}%"),
                            _cell(_f(sgst), align: pw.TextAlign.right)
                          ])
                        ],
                        if (l.gstType == GstType.igst)
                          pw.TableRow(children: [
                            _cell("", align: pw.TextAlign.center),
                            _cell("IGST @ ${l.gstRate}%"),
                            _cell(_f(igst), align: pw.TextAlign.right)
                          ]),
                        // Correct invoice table - no duplicates
                        pw.TableRow(
                            decoration: const pw.BoxDecoration(
                                color: PdfColor(0.93, 0.97, 1.0)),
                            children: [
                              _cell("", align: pw.TextAlign.center),
                              _cell("TAXABLE FREIGHT", bold: true),
                              _cell("INR ${_f(l.taxableFreight)}",
                                  align: pw.TextAlign.right, bold: true)
                            ]),
                        if (l.gstType == GstType.cgstSgst) ...[
                          pw.TableRow(children: [
                            _cell("", align: pw.TextAlign.center),
                            _cell("Add: CGST @ ${l.gstRate / 2}%"),
                            _cell("INR ${_f(l.gstAmount / 2)}",
                                align: pw.TextAlign.right)
                          ]),
                          pw.TableRow(children: [
                            _cell("", align: pw.TextAlign.center),
                            _cell("Add: SGST @ ${l.gstRate / 2}%"),
                            _cell("INR ${_f(l.gstAmount / 2)}",
                                align: pw.TextAlign.right)
                          ]),
                        ],
                        if (l.gstType == GstType.igst)
                          pw.TableRow(children: [
                            _cell("", align: pw.TextAlign.center),
                            _cell("Add: IGST @ ${l.gstRate}%"),
                            _cell("INR ${_f(l.gstAmount)}",
                                align: pw.TextAlign.right)
                          ]),
                        pw.TableRow(
                            decoration: const pw.BoxDecoration(
                                color: PdfColor(0.93, 0.97, 1.0)),
                            children: [
                              _cell("", align: pw.TextAlign.center),
                              _cell("GROSS INVOICE TOTAL", bold: true),
                              _cell("INR ${_f(l.freightBilled + l.gstAmount)}",
                                  align: pw.TextAlign.right, bold: true)
                            ]),
                        if (l.tdsDeduction > 0)
                          pw.TableRow(children: [
                            _cell("", align: pw.TextAlign.center),
                            _cell("Less: TDS u/s 194C @ deducted"),
                            _cell("(INR ${_f(l.tdsDeduction)})",
                                align: pw.TextAlign.right,
                                col: const PdfColor(0.6, 0.1, 0.1))
                          ]),
                        if (l.penalties > 0)
                          pw.TableRow(children: [
                            _cell("", align: pw.TextAlign.center),
                            _cell("Less: Penalties / Damages"),
                            _cell("(INR ${_f(l.penalties)})",
                                align: pw.TextAlign.right,
                                col: const PdfColor(0.6, 0.1, 0.1))
                          ]),
                        if (l.materialLoss > 0)
                          pw.TableRow(children: [
                            _cell("", align: pw.TextAlign.center),
                            _cell("Less: Material Loss"),
                            _cell("(INR ${_f(l.materialLoss)})",
                                align: pw.TextAlign.right,
                                col: const PdfColor(0.6, 0.1, 0.1))
                          ]),
                        if (l.paymentReceived > 0)
                          pw.TableRow(
                              decoration: const pw.BoxDecoration(
                                  color: PdfColor(1.0, 0.97, 0.90)),
                              children: [
                                _cell("", align: pw.TextAlign.center),
                                _cell("Less: Advance Received", bold: true),
                                _cell("(INR ${_f(l.paymentReceived)})",
                                    align: pw.TextAlign.right,
                                    bold: true,
                                    col: const PdfColor(0.5, 0.3, 0.0))
                              ]),
                        pw.TableRow(
                            decoration: const pw.BoxDecoration(
                                color: PdfColor(0.88, 0.97, 0.88)),
                            children: [
                              _cell("", align: pw.TextAlign.center),
                              _cell("NET BALANCE PAYABLE", bold: true),
                              _cell("INR ${_f(l.partyPending)}",
                                  align: pw.TextAlign.right,
                                  bold: true,
                                  col: const PdfColor(0.0, 0.4, 0.0))
                            ]),
                        if (l.paymentReceived > 0)
                          pw.TableRow(children: [
                            _cell("", align: pw.TextAlign.center),
                            _cell("Less: Advance Received"),
                            _cell("(${_f(l.paymentReceived)})",
                                align: pw.TextAlign.right)
                          ]),
                        pw.TableRow(
                            decoration: const pw.BoxDecoration(
                                color: PdfColor(0.88, 0.97, 0.88)),
                            children: [
                              _cell("", align: pw.TextAlign.center),
                              _cell("NET AMOUNT DUE", bold: true),
                              _cell("Rs. ${_f(l.partyPending)}",
                                  align: pw.TextAlign.right,
                                  bold: true,
                                  col: const PdfColor(0.0, 0.4, 0.0))
                            ]),
                      ]),
                  if (up.bankAccount.isNotEmpty) ...[
                    pw.SizedBox(height: 10),
                    pw.Container(
                        padding: const pw.EdgeInsets.all(10),
                        decoration: pw.BoxDecoration(
                            color: const PdfColor(0.97, 0.97, 0.97),
                            borderRadius: pw.BorderRadius.circular(4)),
                        child: pw.Row(children: [
                          pw.Text("Bank: ",
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          pw.Text(up.bankName,
                              style: const pw.TextStyle(fontSize: 9)),
                          pw.SizedBox(width: 16),
                          pw.Text("A/c: ",
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          pw.Text(up.bankAccount,
                              style: const pw.TextStyle(fontSize: 9)),
                          pw.SizedBox(width: 16),
                          pw.Text("IFSC: ",
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold, fontSize: 9)),
                          pw.Text(up.bankIfsc,
                              style: const pw.TextStyle(fontSize: 9))
                        ]))
                  ],
                  if (l.lrNotes.isNotEmpty) ...[
                    pw.SizedBox(height: 8),
                    pw.Text("Notes: ${l.lrNotes}",
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColor(0.4, 0.4, 0.4)))
                  ],
                  pw.Spacer(),
                  pw.Divider(thickness: 0.8),
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text("Declaration:",
                                  style: pw.TextStyle(
                                      fontSize: 8,
                                      fontWeight: pw.FontWeight.bold)),
                              pw.Text(
                                  "This invoice shows the actual price of services described.",
                                  style: const pw.TextStyle(
                                      fontSize: 7.5,
                                      color: PdfColor(0.4, 0.4, 0.4)))
                            ]),
                        pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Container(
                                  width: 140,
                                  height: 1,
                                  color: const PdfColor(0.3, 0.3, 0.3)),
                              pw.SizedBox(height: 4),
                              pw.Text("Authorised Signatory",
                                  style: pw.TextStyle(
                                      fontSize: 9,
                                      fontWeight: pw.FontWeight.bold)),
                              pw.Text(up.companyName,
                                  style: const pw.TextStyle(
                                      fontSize: 8,
                                      color: PdfColor(0.4, 0.4, 0.4)))
                            ]),
                      ]),
                ])));
    try {
      await Printing.sharePdf(
          bytes: await pdf.save(),
          filename: 'Invoice_INV-${l.id}_${l.partyName}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text("PDF Error: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _addEntry() {
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String type = "Payment Received";
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (c) => StatefulBuilder(
            builder: (ctx, setS) => Container(
                  decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24))),
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(ctx).viewInsets.bottom,
                      left: 24,
                      right: 24,
                      top: 28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text("Add to Ledger - ${_l.partyName}",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 18),
                    DropdownButtonFormField<String>(
                        style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                        initialValue: type,
                        decoration: InputDecoration(
                            labelText: "Entry Type",
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
                                    color: Color(0xFF0EA5E9), width: 2))),
                        items: [
                          "Payment Received",
                          "Penalty Deducted",
                          "TDS Deducted",
                          "Short Landing Claim",
                          "Other Deduction"
                        ]
                            .map((t) =>
                                DropdownMenuItem(value: t, child: Text(t)))
                            .toList(),
                        onChanged: (v) => setS(() => type = v!)),
                    const SizedBox(height: 12),
                    TextField(
                        style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 14,
                            fontWeight: FontWeight.w500),
                        controller: amtCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                            labelText: "Amount (Rs.)",
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
                        controller: noteCtrl,
                        decoration: InputDecoration(
                            labelText: "Notes / Reference",
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
                    const SizedBox(height: 18),
                    SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFF6FAFF),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14))),
                            onPressed: () {
                              double amt = double.tryParse(amtCtrl.text) ?? 0;
                              if (amt <= 0) return;
                              final upd = TripLedger(
                                  id: _l.id,
                                  date: _l.date,
                                  partyName: _l.partyName,
                                  vehicleNo: _l.vehicleNo,
                                  route: _l.route,
                                  ownership: _l.ownership,
                                  eWayBillNo: _l.eWayBillNo,
                                  materialName: _l.materialName,
                                  loadingPoint: _l.loadingPoint,
                                  unloadingPoint: _l.unloadingPoint,
                                  loadingState: _l.loadingState,
                                  unloadingState: _l.unloadingState,
                                  consignorPhone: _l.consignorPhone,
                                  consignorEmail: _l.consignorEmail,
                                  consignorGstin: _l.consignorGstin,
                                  freightBilled: _l.freightBilled,
                                  paymentReceived: type == "Payment Received"
                                      ? _l.paymentReceived + amt
                                      : _l.paymentReceived,
                                  diesel: _l.diesel,
                                  toll: _l.toll,
                                  driverExp: _l.driverExp,
                                  materialLoss: type == "Short Landing Claim"
                                      ? _l.materialLoss + amt
                                      : _l.materialLoss,
                                  marketTruckFreight: _l.marketTruckFreight,
                                  marketAdvancePaid: _l.marketAdvancePaid,
                                  penalties: (type == "Penalty Deducted" ||
                                          type == "Other Deduction")
                                      ? _l.penalties + amt
                                      : _l.penalties,
                                  tdsDeduction: type == "TDS Deducted"
                                      ? _l.tdsDeduction + amt
                                      : _l.tdsDeduction,
                                  distanceKm: _l.distanceKm,
                                  fuelEconomy: _l.fuelEconomy,
                                  driverName: _l.driverName,
                                  paymentTermsDays: _l.paymentTermsDays,
                                  lrNotes: _l.lrNotes.isNotEmpty
                                      ? "${_l.lrNotes}\n$type: Rs.${amt.toStringAsFixed(0)} - ${noteCtrl.text}"
                                      : "$type: Rs.${amt.toStringAsFixed(0)} - ${noteCtrl.text}",
                                  gstType: _l.gstType,
                                  gstRate: _l.gstRate,
                                  isGstInclusive: _l.isGstInclusive,
                                  weightTons: _l.weightTons,
                                  weightUnit: _l.weightUnit);
                              setState(() => _l = upd);
                              widget.onUpdateLedger(upd);
                              Navigator.pop(c);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  backgroundColor: Colors.green,
                                  behavior: SnackBarBehavior.floating,
                                  content: Text(
                                      "OK $type of Rs.${amt.toStringAsFixed(0)} recorded")));
                            },
                            child: const Text("Save Entry",
                                style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold)))),
                    const SizedBox(height: 24),
                  ]),
                )));
  }

  @override
  Widget build(BuildContext context) {
    final l = _l;
    final isSelf = l.ownership == VehicleOwnership.self;
    final sc = l.isPaymentOverdue
        ? Colors.red
        : l.isDueSoon
            ? Colors.orange
            : l.partyPending <= 0
                ? Colors.green
                : Colors.orange;
    return UniversalScaffold(
      appBar: AppBar(
          backgroundColor: const Color(0xFFF6FAFF),
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          title: Text(l.partyName,
              style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
          actions: [
            IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: Color(0xFF0F172A)),
                tooltip: "Add Entry",
                onPressed: _addEntry)
          ]),
      body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _card(
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(l.date,
                    style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
                Chip(
                    label: Text(isSelf ? "SELF FLEET" : "MARKET TRUCK",
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A))),
                    backgroundColor: isSelf ? Colors.blueAccent : Colors.purple,
                    padding: const EdgeInsets.symmetric(horizontal: 4))
              ]),
              const SizedBox(height: 8),
              Text(l.partyName,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A))),
              Text(l.vehicleNo,
                  style: const TextStyle(
                      fontSize: 14,
                      color: Colors.indigo,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200)),
                  child: Column(children: [
                    _ir(Icons.route, "Route", l.route),
                    if (l.loadingPoint.isNotEmpty)
                      _ir(Icons.trip_origin, "Loading",
                          "${l.loadingPoint}${l.loadingState.isNotEmpty ? ', ${l.loadingState}' : ''}"),
                    if (l.unloadingPoint.isNotEmpty)
                      _ir(Icons.location_on, "Unloading",
                          "${l.unloadingPoint}${l.unloadingState.isNotEmpty ? ', ${l.unloadingState}' : ''}"),
                    _ir(Icons.science, "Material", l.materialName),
                    if (l.weightTons > 0)
                      _ir(Icons.scale, "Weight",
                          "${l.weightTons} ${l.weightUnit}"),
                    _ir(Icons.receipt, "E-Way Bill", l.eWayBillNo),
                    if (l.platformCommission > 0)
                      _ir(Icons.percent, "Platform Fee (your 2%)",
                          "-Rs.${l.platformCommission.toStringAsFixed(0)}",
                          col: Colors.red.shade700),
                    if (l.consignorCommission > 0)
                      _ir(Icons.percent, "Consignor Fee (2%)",
                          "Rs.${l.consignorCommission.toStringAsFixed(0)}",
                          col: Colors.orange.shade700),
                    if (l.driverName != null)
                      _ir(Icons.person, "Driver", l.driverName!),
                    if (l.distanceKm > 0)
                      _ir(Icons.map, "Distance",
                          "${l.distanceKm.toStringAsFixed(0)} km"),
                  ])),
              const SizedBox(height: 14),
              //
              const Text("DOCUMENTS",
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey,
                      letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _aBtn(Icons.picture_as_pdf, "Generate LR",
                        const Color(0xFFF97316), _shareLR)),
                const SizedBox(width: 8),
                Expanded(
                    child: _aBtn(Icons.receipt_long, "Tax Invoice",
                        const Color(0xFF6366F1), _shareInvoice)),
              ]),
              const SizedBox(height: 8),
              // Share All Documents in one tap
              SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F9D58),
                        foregroundColor: const Color(0xFFF6FAFF),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: _shareAllDocs,
                    icon: const Icon(Icons.share_rounded, size: 16),
                    label: const Text("Share All Documents with Consignor",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  )),
              const SizedBox(height: 12),
              const Text("ACTIONS",
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.grey,
                      letterSpacing: 1.2)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _aBtn(Icons.add_circle, "Add Entry", Colors.green,
                        _addEntry)),
                const SizedBox(width: 8),
                Expanded(
                    child: _aBtn(
                        Icons.gps_fixed_rounded, "Track Live", Colors.teal, () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => LiveTrackingScreen(
                              route: l.route,
                              vehicleNo: l.vehicleNo,
                              distanceKm: l.distanceKm,
                              isLoaded: l.isInTransit,
                              materialName: l.materialName,
                              driverName: l.driverName ?? '',
                              tripId: l.id,
                              destination: l.unloadingPoint,
                              fuelEconomy: l.fuelEconomy)));
                }))
              ]),
            ])),
            const SizedBox(height: 16),
            _card(
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text("FINANCIAL BREAKDOWN",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.grey,
                        letterSpacing: 1.2)),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                        l.partyPending <= 0
                            ? "SETTLED"
                            : l.isPaymentOverdue
                                ? "OVERDUE"
                                : l.isDueSoon
                                    ? "DUE SOON"
                                    : "OUTSTANDING",
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: sc))),
              ]),
              const SizedBox(height: 14),
              _fr("Freight Billed", l.freightBilled, b: true),
              if (l.gstAmount > 0)
                _fr(
                    l.gstType == GstType.igst
                        ? "IGST @${l.gstRate}%"
                        : "GST @${l.gstRate}%",
                    l.gstAmount,
                    c: Colors.indigo),
              _fr("Advance Received", l.paymentReceived, c: Colors.green),
              const Divider(height: 16),
              if (isSelf) ...[
                _fr("Diesel Fuel", l.diesel, c: Colors.deepOrange),
                _fr("Toll / FASTag", l.toll, c: Colors.orange),
                _fr("Driver Expenses", l.driverExp, c: Colors.purple),
                if (l.materialLoss > 0)
                  _fr("Material Loss", l.materialLoss, c: Colors.red[900]!)
              ] else ...[
                _fr("Market Truck Freight", l.marketTruckFreight,
                    c: Colors.red),
                _fr("Advance Paid to Market", l.marketAdvancePaid,
                    c: Colors.red)
              ],
              if (l.tdsDeduction > 0)
                _fr("TDS Deducted", l.tdsDeduction, c: Colors.brown),
              if (l.penalties > 0)
                _fr("Penalties / Deductions", l.penalties,
                    c: Colors.deepOrange),
              const Divider(height: 16),
              if (l.partyPending > 0)
                Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                        color: sc.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                              l.isPaymentOverdue
                                  ? "OVERDUE BALANCE"
                                  : l.isDueSoon
                                      ? "DUE SOON"
                                      : "PENDING BALANCE",
                              style: TextStyle(
                                  color: sc,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13)),
                          Text("Rs.${l.partyPending.toStringAsFixed(0)}",
                              style: TextStyle(
                                  color: sc,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 22))
                        ])),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(isSelf ? "NET PROFIT" : "NET COMMISSION",
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A))),
                Text("Rs.${l.tripProfit.toStringAsFixed(0)}",
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Colors.blueAccent))
              ]),
              if (l.paymentDueDate != null) ...[
                const SizedBox(height: 10),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                          "Payment due: ${l.paymentDueDate!.day}/${l.paymentDueDate!.month}/${l.paymentDueDate!.year}",
                          style: TextStyle(
                              fontSize: 11,
                              color: l.isPaymentOverdue
                                  ? Colors.red
                                  : l.isDueSoon
                                      ? Colors.orange
                                      : Colors.grey,
                              fontWeight: FontWeight.w600))
                    ]))
              ],
            ])),
          ])),
    );
  }

  Widget _card(Widget child) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.40), width: 1.5),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.25),
                Colors.white.withValues(alpha: 0.10)
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Future<void> _shareAllDocs() async {
    if (!widget.subscription.canExportPDF) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          content: Text("PDF Export requires PRO plan or above")));
      return;
    }
    final l = _l;
    // Build both PDFs
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: Colors.indigo,
        behavior: SnackBarBehavior.floating,
        content: Row(children: [
          SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF0F172A))),
          SizedBox(width: 12),
          Text("Preparing documents...")
        ])));
    try {
      // Generate LR PDF
      await _shareLR();
      // Small delay then show success
      await Future.delayed(const Duration(milliseconds: 500));
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        content:
            Text("Documents shared! LR No: LR-${l.id} | Invoice: INV-${l.id}"),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: Colors.red, content: Text("Error: $e")));
    }
  }

  Widget _aBtn(IconData icon, String label, Color c, VoidCallback onTap) =>
      ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
              backgroundColor: c,
              foregroundColor: const Color(0xFFF6FAFF),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          onPressed: onTap,
          icon: Icon(icon, size: 15),
          label: Text(label,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)));
  Widget _ir(IconData icon, String label, String val, {Color? col}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 8),
        SizedBox(
            width: 80,
            child: Text("$label: ",
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w600))),
        Expanded(
            child: Text(val,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: col ?? const Color(0xFF0F172A))))
      ]));
  Widget _fr(String label, double val,
          {Color c = Colors.black87, bool b = false}) =>
      Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label,
                style: TextStyle(
                    fontWeight: b ? FontWeight.w900 : FontWeight.w600,
                    fontSize: b ? 14 : 13,
                    color: const Color(0xFF0F172A))),
            Text("Rs.${val.toStringAsFixed(0)}",
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: c,
                    fontSize: b ? 14 : 13))
          ]));
}

// ================================================================
// LIVE TRACKING SCREEN WIDGET
// ================================================================
class LiveTrackingScreen extends StatefulWidget {
  final String route;
  final String vehicleNo;
  final double distanceKm;
  final bool isLoaded;
  final String materialName;
  final String driverName;
  final String tripId;
  final String destination;
  final double fuelEconomy;
  final int axles;

  const LiveTrackingScreen({
    super.key,
    required this.route,
    required this.vehicleNo,
    required this.distanceKm,
    required this.isLoaded,
    required this.materialName,
    required this.driverName,
    this.tripId = '',
    this.destination = '',
    this.fuelEconomy = 3.5,
    this.axles = 6,
  });

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  static const double _dieselCo2KgPerLitre = 2.68;
  Timer? _routeTimer;
  bool _monitoringRoutes = false;
  bool _checkingRoute = false;
  int _checkIntervalMinutes = 5;
  String? _routeCheckError;
  Map<String, dynamic>? _routeSuggestion;
  String _acceptedRouteSummary = '';
  List<LatLng>? _selectedRoutePolyline;

  String get _destination {
    if (widget.destination.trim().isNotEmpty) {
      return widget.destination.trim();
    }
    final parts = widget.route
        .split(RegExp(r'\s*(?:->|→)\s*'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    return parts.length > 1 ? parts.last.trim() : '';
  }

  @override
  void dispose() {
    _routeTimer?.cancel();
    super.dispose();
  }

  void _setRouteMonitoring(bool enabled) {
    if (!enabled) {
      _routeTimer?.cancel();
      setState(() {
        _monitoringRoutes = false;
        _routeSuggestion = null;
        _routeCheckError = null;
      });
      return;
    }
    if (!widget.isLoaded || widget.tripId.isEmpty || !AppConfig.hasGoogleMaps) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Live route advice needs an in-transit trip and a configured Maps API key.'),
      ));
      return;
    }
    if (_destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('This trip has no destination saved for route advice.'),
      ));
      return;
    }
    setState(() {
      _monitoringRoutes = true;
      _routeCheckError = null;
    });
    _routeTimer?.cancel();
    unawaited(_checkLiveRoute());
    _routeTimer = Timer.periodic(
      Duration(minutes: _checkIntervalMinutes),
      (_) => unawaited(_checkLiveRoute()),
    );
  }

  void _changeRouteInterval(int? minutes) {
    if (minutes == null) return;
    setState(() => _checkIntervalMinutes = minutes);
    if (_monitoringRoutes) {
      _routeTimer?.cancel();
      _routeTimer = Timer.periodic(
        Duration(minutes: minutes),
        (_) => unawaited(_checkLiveRoute()),
      );
    }
  }

  Future<void> _checkLiveRoute() async {
    if (_checkingRoute || !_monitoringRoutes) return;
    _checkingRoute = true;
    setState(() {
      _routeSuggestion = null;
      _routeCheckError = null;
      _checkingRoute = true;
    });
    try {
      final location = await FirebaseFirestore.instance
          .collection('live_locations')
          .doc(widget.tripId)
          .get();
      final data = location.data();
      if (data?['sharing'] != true) {
        throw StateError('The driver is not currently sharing live location.');
      }
      final lat = (data?['lat'] as num?)?.toDouble();
      final lng = (data?['lng'] as num?)?.toDouble();
      if (lat == null ||
          lng == null ||
          !lat.isFinite ||
          !lng.isFinite ||
          lat < -90 ||
          lat > 90 ||
          lng < -180 ||
          lng > 180) {
        throw StateError('Waiting for a valid live vehicle location.');
      }
      final updatedAt = data?['updatedAt'];
      if (updatedAt is! Timestamp) {
        throw StateError('Waiting for a timestamped driver location update.');
      }
      if (DateTime.now().difference(updatedAt.toDate()) >
          const Duration(minutes: 20)) {
        throw StateError('Vehicle location is over 20 minutes old.');
      }
      final result = await RoutingEngine.calculate(
        origin: '$lat,$lng',
        destination: _destination,
        axles: widget.axles,
        fuelEconomy: widget.fuelEconomy,
      );
      if ((result['km'] as int? ?? 0) <= 0) {
        throw StateError(
            'Could not refresh traffic routes. Check Maps API access and destination.');
      }
      if (!(result['source'] as String? ?? '')
          .startsWith('google_directions')) {
        throw StateError(
            'Live traffic routes are unavailable. Check Directions API access.');
      }
      if (!mounted || !_monitoringRoutes) return;
      result['_originLat'] = lat;
      result['_originLng'] = lng;
      setState(() {
        _routeSuggestion = result;
        _routeCheckError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _routeSuggestion = null;
        _routeCheckError = error.toString();
      });
    } finally {
      _checkingRoute = false;
      if (mounted) setState(() => _checkingRoute = false);
    }
  }

  Future<void> _acceptRouteSuggestion() async {
    final suggestion = _routeSuggestion;
    if (suggestion == null || widget.tripId.isEmpty) return;
    final bestKm = (suggestion['distanceKm'] as num?)?.toDouble() ??
        (suggestion['km'] as int? ?? 0).toDouble();
    final defaultRoute = suggestion['defaultRoute'] as Map<String, dynamic>?;
    final defaultKm = (defaultRoute?['distanceKm'] as num?)?.toDouble() ??
        (defaultRoute?['km'] as int? ?? 0).toDouble();
    final savedKm = math.max(0.0, defaultKm - bestKm);
    final economy = widget.fuelEconomy;
    final savedLitres =
        economy.isFinite && economy > 0 ? savedKm / economy : 0.0;
    final savedCo2Kg = savedLitres * _dieselCo2KgPerLitre;
    final originLat = (suggestion['_originLat'] as num?)?.toDouble();
    final originLng = (suggestion['_originLng'] as num?)?.toDouble();
    if (originLat == null || originLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Route estimate is missing its location snapshot. Refresh it before accepting.'),
      ));
      return;
    }
    final decisionKey = crypto.sha256
        .convert(utf8.encode(
          '${originLat.toStringAsFixed(3)}|${originLng.toStringAsFixed(3)}|${suggestion['routeSummary']}|${bestKm.toStringAsFixed(1)}|${defaultKm.toStringAsFixed(1)}',
        ))
        .toString();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sign in to save route optimization results.'),
      ));
      return;
    }
    try {
      final tripRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('ledgers')
          .doc(widget.tripId);
      final decisionRef =
          tripRef.collection('routeOptimizations').doc(decisionKey);
      final recorded = await FirebaseFirestore.instance
          .runTransaction<bool>((transaction) async {
        final existingDecision = await transaction.get(decisionRef);
        if (existingDecision.exists) return false;
        transaction.set(decisionRef, {
          'routeSummary': suggestion['routeSummary'] ?? '',
          'defaultDistanceKm': defaultKm,
          'selectedDistanceKm': bestKm,
          'distanceSavedKm': savedKm,
          'dieselSavedL': savedLitres,
          'co2SavedKg': savedCo2Kg,
          'recordedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(tripRef, {
          'routeDistanceSavedKm': FieldValue.increment(savedKm),
          'routeDieselSavedL': FieldValue.increment(savedLitres),
          'routeCo2SavedKg': FieldValue.increment(savedCo2Kg),
          'optimizedRouteSummary': suggestion['routeSummary'] ?? '',
          'lastRouteOptimizationAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
      if (!recorded) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'This location and route estimate has already been counted.'),
        ));
        return;
      }
      if (!mounted) return;
      setState(() {
        _acceptedRouteSummary =
            suggestion['routeSummary'] as String? ?? 'Recommended route';
        _selectedRoutePolyline = (suggestion['routePolyline'] as List?)
            ?.whereType<LatLng>()
            .toList();
        _routeSuggestion = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(savedKm > 0
            ? 'Route saved. Estimated ${savedKm.toStringAsFixed(1)} km, ${savedLitres.toStringAsFixed(1)} L diesel and ${savedCo2Kg.toStringAsFixed(1)} kg CO₂e saved versus Google’s default route.'
            : 'Route saved. No distance or fuel savings were counted.'),
        duration: const Duration(seconds: 5),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not save route decision: $error'),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.isLoaded ? Colors.green : Colors.orange;
    final routeCities = widget.route
        .split(RegExp(r'\s*(?:->|→)\s*'))
        .map((part) => part.split(',').first.trim())
        .where((part) => part.isNotEmpty)
        .toList();
    const cityCoordinates = <String, LatLng>{
      'Ahmedabad': LatLng(23.03, 72.58),
      'Mumbai': LatLng(19.08, 72.88),
      'Delhi': LatLng(28.61, 77.21),
      'Pune': LatLng(18.52, 73.86),
      'Jaipur': LatLng(26.91, 75.79),
      'Surat': LatLng(21.17, 72.83),
      'Vadodara': LatLng(22.30, 73.18),
      'Bengaluru': LatLng(12.97, 77.59),
      'Hyderabad': LatLng(17.39, 78.49),
      'Chennai': LatLng(13.08, 80.27),
      'Kolkata': LatLng(22.57, 88.36),
      'Ludhiana': LatLng(30.90, 75.85),
    };
    final routePoints = routeCities
        .map((city) => cityCoordinates[city])
        .whereType<LatLng>()
        .toList();
    final fallbackCenter =
        routePoints.isNotEmpty ? routePoints.first : const LatLng(22.5, 78.9);
    final routeMarkers = <Marker>{
      for (var i = 0; i < routePoints.length; i++)
        Marker(
          markerId: MarkerId('route_$i'),
          position: routePoints[i],
          infoWindow: InfoWindow(
              title: i == 0
                  ? 'Vehicle origin'
                  : i == routePoints.length - 1
                      ? 'Vehicle destination'
                      : 'Route stop'),
        ),
    };
    const importantPlaces = <MapEntry<String, LatLng>>[
      MapEntry('Mundra Port', LatLng(22.83, 69.72)),
      MapEntry('JNPT Port', LatLng(18.95, 72.95)),
      MapEntry('Delhi ICD', LatLng(28.61, 77.32)),
      MapEntry('Mumbai Bypass', LatLng(19.20, 72.98)),
    ];
    double routeDistanceKm(LatLng first, LatLng second) {
      const earthRadius = 6371.0;
      final latDelta = (second.latitude - first.latitude) * math.pi / 180;
      final lngDelta = (second.longitude - first.longitude) * math.pi / 180;
      final a = math.sin(latDelta / 2) * math.sin(latDelta / 2) +
          math.cos(first.latitude * math.pi / 180) *
              math.cos(second.latitude * math.pi / 180) *
              math.sin(lngDelta / 2) *
              math.sin(lngDelta / 2);
      return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    }

    for (final place in importantPlaces.where(
        (place) => routeDistanceKm(fallbackCenter, place.value) <= 350)) {
      routeMarkers.add(Marker(
        markerId: MarkerId('place_${place.key}'),
        position: place.value,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow:
            InfoWindow(title: place.key, snippet: 'Place of importance'),
      ));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        backgroundColor: const Color(0xFF0EA5E9),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.local_shipping_rounded,
                        color: statusColor, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.vehicleNo,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A))),
                        Text(
                            widget.isLoaded
                                ? 'Loaded / in transit'
                                : 'Available',
                            style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                _trackingRow(Icons.route_rounded, 'Route', widget.route),
                _trackingRow(
                    Icons.straighten_rounded,
                    'Distance',
                    widget.distanceKm > 0
                        ? '${widget.distanceKm.toStringAsFixed(0)} km'
                        : '-'),
                _trackingRow(Icons.inventory_2_rounded, 'Material',
                    widget.materialName.isEmpty ? '-' : widget.materialName),
                _trackingRow(Icons.person_rounded, 'Driver',
                    widget.driverName.isEmpty ? '-' : widget.driverName),
                if (widget.tripId.isNotEmpty)
                  _trackingRow(Icons.tag_rounded, 'Trip ID', widget.tripId),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 320,
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: widget.tripId.isEmpty
                  ? null
                  : FirebaseFirestore.instance
                      .collection('live_locations')
                      .doc(widget.tripId)
                      .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data();
                final liveLat = (data?['lat'] as num?)?.toDouble();
                final liveLng = (data?['lng'] as num?)?.toDouble();
                final livePosition = liveLat != null && liveLng != null
                    ? LatLng(liveLat, liveLng)
                    : null;
                final liveAnchor = livePosition ?? fallbackCenter;
                final suggestedPolyline =
                    (_routeSuggestion?['routePolyline'] as List?)
                        ?.whereType<LatLng>()
                        .toList();
                final displayedRoutePoints =
                    suggestedPolyline != null && suggestedPolyline.length > 1
                        ? suggestedPolyline
                        : _selectedRoutePolyline != null &&
                                _selectedRoutePolyline!.length > 1
                            ? _selectedRoutePolyline!
                            : routePoints;
                final markers = routeMarkers
                    .where(
                        (marker) => marker.markerId.value.startsWith('route_'))
                    .toSet();
                for (final place in importantPlaces.where((place) =>
                    routeDistanceKm(liveAnchor, place.value) <= 350)) {
                  markers.add(Marker(
                    markerId: MarkerId('place_${place.key}'),
                    position: place.value,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueAzure),
                    infoWindow: InfoWindow(
                        title: place.key, snippet: 'Place of importance'),
                  ));
                }
                if (livePosition != null) {
                  markers.add(Marker(
                    markerId: const MarkerId('live_vehicle'),
                    position: livePosition,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueGreen),
                    infoWindow: InfoWindow(
                        title: widget.vehicleNo,
                        snippet: 'Live vehicle position'),
                  ));
                }
                final speedKph = (data?['speed'] as num?)?.toDouble() ?? 45;
                final trafficMinutes =
                    (_routeSuggestion?['durationInTrafficMinutes'] as int?) ??
                        0;
                final etaHours = widget.distanceKm > 0 && speedKph > 0
                    ? widget.distanceKm / speedKph
                    : 0.0;
                final etaText = trafficMinutes > 0
                    ? '${trafficMinutes ~/ 60}h ${trafficMinutes % 60}m'
                    : etaHours > 0
                        ? '${etaHours.floor()}h ${(etaHours * 60).round() % 60}m'
                        : 'ETA unavailable';
                return Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: GoogleMap(
                          initialCameraPosition:
                              CameraPosition(target: liveAnchor, zoom: 5.5),
                          markers: markers,
                          polylines: displayedRoutePoints.length > 1
                              ? {
                                  Polyline(
                                    polylineId:
                                        const PolylineId('planned_route'),
                                    points: displayedRoutePoints,
                                    color: const Color(0xFF0EA5E9),
                                    width: 5,
                                  )
                                }
                              : const {},
                          myLocationButtonEnabled: true,
                          compassEnabled: true,
                          zoomControlsEnabled: true,
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      color: const Color(0xFF0F172A),
                      child: Text(
                          livePosition == null
                              ? 'Planned route ETA estimate: $etaText'
                              : trafficMinutes > 0
                                  ? 'Traffic ETA from live location: $etaText'
                                  : 'Approximate ETA at ${speedKph.toStringAsFixed(0)} km/h: $etaText',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.alt_route_rounded),
                  title: const Text('Live traffic route advice'),
                  subtitle: Text(
                    !widget.isLoaded
                        ? 'Available while this trip is in transit'
                        : !AppConfig.hasGoogleMaps
                            ? 'Configure a Google Maps API key to enable'
                            : 'Checks the driver location and suggests faster routes',
                  ),
                  value: _monitoringRoutes,
                  onChanged: _setRouteMonitoring,
                ),
                if (_monitoringRoutes)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('Refresh traffic every'),
                        ),
                        DropdownButton<int>(
                          value: _checkIntervalMinutes,
                          items: const [5, 10, 15]
                              .map((minutes) => DropdownMenuItem(
                                    value: minutes,
                                    child: Text('$minutes min'),
                                  ))
                              .toList(),
                          onChanged: _changeRouteInterval,
                        ),
                        if (_checkingRoute) ...[
                          const SizedBox(width: 10),
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (_routeCheckError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      _routeCheckError!,
                      style: TextStyle(color: Colors.red.shade700),
                    ),
                  ),
                if (_routeSuggestion case final suggestion?)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Traffic recommendation${(suggestion['alternatives'] as List? ?? []).isEmpty ? '' : ' · ${(suggestion['alternatives'] as List).length + 1} routes compared'}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${suggestion['routeSummary'] ?? 'Recommended route'} · ${(suggestion['distanceKm'] as num?)?.toStringAsFixed(1) ?? suggestion['km']} km · ${suggestion['durationInTrafficMinutes']} min in current traffic',
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _acceptRouteSuggestion,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Accept estimate & record'),
                        ),
                      ],
                    ),
                  ),
                if (_acceptedRouteSummary.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text('Last selected: $_acceptedRouteSummary'),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text(
                    'Recommendations use live location and Google traffic data. This does not change the driver’s navigation. Keep the driver in control; route and fuel savings are estimates, not verified carbon credits.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trackingRow(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(children: [
          Icon(icon, size: 18, color: const Color(0xFF64748B)),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Color(0xFF0F172A), fontWeight: FontWeight.w800)),
          ),
        ]),
      );
}

// ================================================================
// KREDX SCREEN WIDGET
// ================================================================
class KredXScreen extends StatefulWidget {
  final List<TripLedger> ledgers;
  final List<KredXApplication> kredxApps;
  final Function(KredXApplication) onApply;
  final VoidCallback onUpdate;

  const KredXScreen({
    super.key,
    required this.ledgers,
    required this.kredxApps,
    required this.onApply,
    required this.onUpdate,
  });

  @override
  State<KredXScreen> createState() => _KredXScreenState();
}

class _KredXScreenState extends State<KredXScreen> {
  TripLedger? _selectedLedger;
  final TextEditingController _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final ledger = _selectedLedger;
    if (ledger == null) return;
    final requested =
        double.tryParse(_amountCtrl.text.trim()) ?? ledger.partyPending;
    final now = DateTime.now();
    final app = KredXApplication(
      id: 'KX${now.millisecondsSinceEpoch}',
      invoiceLedgerId: ledger.id,
      partyName: ledger.partyName,
      invoiceAmount: ledger.freightBilled,
      requestedAmount: requested,
      status: KredXStatus.submitted,
      appliedDate: '${now.day}/${now.month}/${now.year}',
    );
    widget.onApply(app);
    widget.onUpdate();
    setState(() {
      _selectedLedger = null;
      _amountCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        content: Text('KredX application submitted')));
  }

  @override
  Widget build(BuildContext context) {
    final eligible = widget.ledgers.where((l) => l.partyPending > 0).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('KredX Financing'),
        backgroundColor: const Color(0xFFF59E0B),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('New invoice financing request',
                  style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
              const SizedBox(height: 12),
              DropdownButtonFormField<TripLedger>(
                initialValue: _selectedLedger,
                decoration: const InputDecoration(
                  labelText: 'Select pending invoice',
                  border: OutlineInputBorder(),
                ),
                items: eligible
                    .map((l) => DropdownMenuItem(
                          value: l,
                          child: Text(
                              '${l.partyName} - ${l.vehicleNo} - Rs.${l.partyPending.toStringAsFixed(0)}'),
                        ))
                    .toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedLedger = v;
                    _amountCtrl.text =
                        v == null ? '' : v.partyPending.toStringAsFixed(0);
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Requested amount',
                  prefixText: 'Rs.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _selectedLedger == null ? null : _submit,
                  icon: const Icon(Icons.account_balance_rounded),
                  label: const Text('Submit Application'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
          const Text('Applications',
              style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
          const SizedBox(height: 8),
          if (widget.kredxApps.isEmpty)
            const Text('No KredX applications yet.',
                style: TextStyle(color: Color(0xFF64748B)))
          else
            ...widget.kredxApps.map((app) => Card(
                  child: ListTile(
                    leading: Icon(Icons.receipt_long_rounded,
                        color: app.statusColor),
                    title: Text(app.partyName,
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                        'Invoice Rs.${app.invoiceAmount.toStringAsFixed(0)} | Requested Rs.${app.requestedAmount.toStringAsFixed(0)}'),
                    trailing: Text(app.statusLabel,
                        style: TextStyle(
                            color: app.statusColor,
                            fontWeight: FontWeight.w900)),
                  ),
                )),
        ],
      ),
    );
  }
}

// ================================================================
// DRIVER LEDGER SCREEN WIDGET
// ================================================================
class DriverLedgerScreen extends StatefulWidget {
  final Driver driver;
  final VoidCallback onUpdate;

  const DriverLedgerScreen({
    super.key,
    required this.driver,
    required this.onUpdate,
  });

  @override
  State<DriverLedgerScreen> createState() => _DriverLedgerScreenState();
}

class _DriverLedgerScreenState extends State<DriverLedgerScreen> {
  static int _signFor(DriverTxType type) {
    switch (type) {
      case DriverTxType.advance:
      case DriverTxType.fuel:
      case DriverTxType.penalty:
      case DriverTxType.deduction:
        return 1;
      case DriverTxType.salary:
      case DriverTxType.bonus:
        return -1;
    }
  }

  void _recomputeBalance() {
    double bal = 0;
    for (final tx in widget.driver.transactions) {
      bal += _signFor(tx.type) * tx.amount;
    }
    widget.driver.balance = double.parse(bal.toStringAsFixed(2));
  }

  void _addTransaction(DriverTxType type, double amount, String note) {
    final now = DateTime.now();
    setState(() {
      widget.driver.transactions.insert(
        0,
        DriverTx(
          date: '${now.day}/${now.month}/${now.year}',
          type: type,
          amount: double.parse(amount.toStringAsFixed(2)),
          note: note,
        ),
      );
      _recomputeBalance();
    });
    widget.onUpdate();
  }

  void _quickAdd(DriverTxType type) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(type.name.toUpperCase()),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount'),
          ),
          TextField(
            controller: noteCtrl,
            decoration: const InputDecoration(labelText: 'Note'),
          ),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
                if (amount <= 0) return;
                Navigator.pop(context);
                _addTransaction(type, amount, noteCtrl.text.trim());
              },
              child: const Text('Add')),
        ],
      ),
    );
  }

  String _money(double v) {
    final neg = v < 0;
    final s = v.abs().toStringAsFixed(2);
    final parts = s.split('.');
    final rev = parts[0].split('').reversed.toList();
    final buf = StringBuffer();
    for (var i = 0; i < rev.length; i++) {
      if (i == 3 || (i > 3 && (i - 3) % 2 == 0)) buf.write(',');
      buf.write(rev[i]);
    }
    final grouped = buf.toString().split('').reversed.join();
    return '${neg ? '-' : ''}Rs.$grouped.${parts[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final driver = widget.driver;
    final bal = driver.balance;
    final owes = bal > 0.009;
    final owed = bal < -0.009;
    final statusText = owes
        ? 'Driver owes you'
        : owed
            ? 'You owe driver'
            : 'All settled';
    final statusColor = owes
        ? const Color(0xFFEF4444)
        : owed
            ? const Color(0xFF10B981)
            : const Color(0xFF64748B);

    double totIn = 0, totOut = 0;
    for (final tx in driver.transactions) {
      if (_signFor(tx.type) > 0) {
        totIn += tx.amount;
      } else {
        totOut += tx.amount;
      }
    }

    final ordered = driver.transactions.reversed.toList();
    final running = <double>[];
    double r = 0;
    for (final tx in ordered) {
      r += _signFor(tx.type) * tx.amount;
      running.add(double.parse(r.toStringAsFixed(2)));
    }
    final runningNewestFirst = running.reversed.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${driver.name} — Ledger'),
        backgroundColor: const Color(0xFF0EA5E9),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(driver.name,
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0F172A))),
                        const SizedBox(height: 2),
                        Text(driver.phone,
                            style: const TextStyle(color: Color(0xFF64748B))),
                      ]),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(statusText,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
              ]),
              const Divider(height: 24),
              const Text('Current Balance',
                  style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(_money(bal.abs()),
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 26,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                    child: _summaryTile('Advances / Deductions', _money(totIn),
                        const Color(0xFFEF4444))),
                const SizedBox(width: 10),
                Expanded(
                    child: _summaryTile('Salary / Bonus', _money(totOut),
                        const Color(0xFF10B981))),
              ]),
            ]),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _addBtn('Advance', DriverTxType.advance, const Color(0xFFEF4444)),
            _addBtn('Fuel', DriverTxType.fuel, const Color(0xFFF59E0B)),
            _addBtn('Penalty', DriverTxType.penalty, const Color(0xFFDC2626)),
            _addBtn('Salary', DriverTxType.salary, const Color(0xFF10B981)),
            _addBtn('Bonus', DriverTxType.bonus, const Color(0xFF059669)),
            _addBtn(
                'Deduction', DriverTxType.deduction, const Color(0xFF6366F1)),
          ]),
          const SizedBox(height: 18),
          const Text('Transactions',
              style: TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
          const SizedBox(height: 8),
          if (driver.transactions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('No ledger entries yet.',
                  style: TextStyle(color: Color(0xFF64748B))),
            )
          else
            ...List.generate(driver.transactions.length, (i) {
              final tx = driver.transactions[i];
              final isDebit = _signFor(tx.type) > 0;
              final amtColor =
                  isDebit ? const Color(0xFFEF4444) : const Color(0xFF10B981);
              final runBal = i < runningNewestFirst.length
                  ? runningNewestFirst[i]
                  : driver.balance;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: amtColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle),
                    child: Icon(
                        isDebit
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        color: amtColor,
                        size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              tx.type.name[0].toUpperCase() +
                                  tx.type.name.substring(1),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: Color(0xFF0F172A))),
                          if (tx.note.isNotEmpty)
                            Text(tx.note,
                                style: const TextStyle(
                                    color: Color(0xFF64748B), fontSize: 12)),
                          Text('${tx.date}  •  Bal: ${_money(runBal)}',
                              style: const TextStyle(
                                  color: Color(0xFF94A3B8), fontSize: 11)),
                        ]),
                  ),
                  Text('${isDebit ? '+' : '−'}${_money(tx.amount)}',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: amtColor)),
                ]),
              );
            }),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 10,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _addBtn(String label, DriverTxType type, Color color) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.12),
          foregroundColor: color,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
      onPressed: () => _quickAdd(type),
      child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    );
  }
}

// ================================================================
// TALLY EXPORT SCREEN
// ================================================================
class TallyExportScreen extends StatefulWidget {
  final List<TripLedger> ledgers;
  final List<Driver> drivers;
  final UserProfile userProfile;
  const TallyExportScreen(
      {super.key,
      required this.ledgers,
      required this.drivers,
      required this.userProfile});
  @override
  State<TallyExportScreen> createState() => _TallyExportScreenState();
}

class _TallyExportScreenState extends State<TallyExportScreen> {
  String _fmt = "CA Audit CSV";
  String? _data;

  String _normName(String? s) =>
      (s ?? '').toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  List<TripLedger> get _effectiveLedgers {
    if (widget.userProfile.role == UserRole.driver) {
      final candidates = <String>{
        _normName(FirebaseService.currentUser?.displayName),
        _normName(widget.userProfile.companyName),
      }..removeWhere((e) => e.isEmpty);
      return widget.ledgers
          .where((l) => candidates.contains(_normName(l.driverName)))
          .toList();
    }
    return widget.ledgers;
  }

  String _csv() {
    final sb = StringBuffer();
    sb.writeln(
        "Trip ID,Date,Party,Vehicle,Route,Material,E-Way,Loading,Unloading,Freight Billed,Received,Pending,Diesel,Toll,Driver Exp,Shortfall,Penalties,TDS,Market Freight,Profit,GST Type,GST Amt,Weight,Terms,Driver,Status");
    for (final l in _effectiveLedgers) {
      final st = l.partyPending <= 0
          ? "Cleared"
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
        '"${l.materialName}"',
        l.eWayBillNo,
        '"${l.loadingPoint}"',
        '"${l.unloadingPoint}"',
        l.freightBilled.toStringAsFixed(2),
        l.paymentReceived.toStringAsFixed(2),
        l.partyPending.toStringAsFixed(2),
        l.diesel.toStringAsFixed(2),
        l.toll.toStringAsFixed(2),
        l.driverExp.toStringAsFixed(2),
        l.materialLoss.toStringAsFixed(2),
        l.penalties.toStringAsFixed(2),
        l.tdsDeduction.toStringAsFixed(2),
        l.marketTruckFreight.toStringAsFixed(2),
        l.tripProfit.toStringAsFixed(2),
        l.gstType.name,
        l.gstAmount.toStringAsFixed(2),
        "${l.weightTons} ${l.weightUnit}",
        l.paymentTermsDays,
        l.driverName ?? '',
        st
      ].join(','));
    }
    return sb.toString();
  }

  String _tallyXml() {
    final sb = StringBuffer();
    sb.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    sb.writeln(
        '<ENVELOPE><HEADER><TALLYREQUEST>Import Data</TALLYREQUEST></HEADER><BODY><IMPORTDATA><REQUESTDESC>');
    sb.writeln(
        '<REPORTNAME>Vouchers</REPORTNAME><STATICVARIABLES><SVCURRENTCOMPANY>${widget.userProfile.companyName}</SVCURRENTCOMPANY></STATICVARIABLES>');
    sb.writeln('</REQUESTDESC><REQUESTDATA>');
    for (final l in _effectiveLedgers) {
      sb.writeln(
          '<TALLYMESSAGE><VOUCHER VCHTYPE="Sales" ACTION="Create"><DATE>${l.date.replaceAll("/", "")}</DATE><NARRATION>Freight-${l.materialName}-${l.route}-EWB:${l.eWayBillNo}</NARRATION><VOUCHERTYPENAME>Sales</VOUCHERTYPENAME><PARTYLEDGERNAME>${l.partyName}</PARTYLEDGERNAME><ALLLEDGERENTRIES.LIST><LEDGERNAME>${l.partyName}</LEDGERNAME><ISDEEMEDPOSITIVE>Yes</ISDEEMEDPOSITIVE><AMOUNT>-${l.freightBilled.toStringAsFixed(2)}</AMOUNT></ALLLEDGERENTRIES.LIST><ALLLEDGERENTRIES.LIST><LEDGERNAME>Freight Income</LEDGERNAME><ISDEEMEDPOSITIVE>No</ISDEEMEDPOSITIVE><AMOUNT>${l.freightBilled.toStringAsFixed(2)}</AMOUNT></ALLLEDGERENTRIES.LIST></VOUCHER></TALLYMESSAGE>');
    }
    sb.writeln('</REQUESTDATA></IMPORTDATA></BODY></ENVELOPE>');
    return sb.toString();
  }

  String _aging() {
    final m = <String, double>{};
    for (final l in _effectiveLedgers) {
      m[l.partyName] = (m[l.partyName] ?? 0) + l.partyPending;
    }
    final sb = StringBuffer();
    sb.writeln("Party Aging Report - ${widget.userProfile.companyName}");
    sb.writeln(
        "Generated: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}\n---");
    sb.writeln("Party Name,Outstanding,Overdue Trips");
    for (final e in m.entries) {
      final ov = _effectiveLedgers
          .where((l) => l.partyName == e.key && l.isPaymentOverdue)
          .length;
      sb.writeln('"${e.key}",${e.value.toStringAsFixed(2)},$ov');
    }
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) => UniversalScaffold(
        appBar: AppBar(
            backgroundColor: const Color(0xFFF6FAFF),
            iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
            title: const Text("Tally / CA Export",
                style: TextStyle(
                    color: Color(0xFF0F172A), fontWeight: FontWeight.w900))),
        body: Column(children: [
          Container(
              color: const Color(0xFF0F172A),
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Export Format",
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Color(0xFF0F172A))),
                    const SizedBox(height: 10),
                    ...[
                      "CA Audit CSV",
                      "Tally XML",
                      "Party Aging Report"
                    ].map((f) => RadioListTile<String>(
                        title: Text(f,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            f == "CA Audit CSV"
                                ? "Full ledger with GST, TDS, deductions"
                                : f == "Tally XML"
                                    ? "Import into TallyPrime/ERP9"
                                    : "Outstanding by party for collections",
                            style: const TextStyle(fontSize: 11)),
                        value: f,
                        groupValue: _fmt,
                        activeColor: const Color(0xFFF6FAFF),
                        onChanged: (v) => setState(() => _fmt = v!))),
                    ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF6FAFF),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            minimumSize: const Size(double.infinity, 0)),
                        onPressed: () =>
                            setState(() => _data = _fmt == "CA Audit CSV"
                                ? _csv()
                                : _fmt == "Tally XML"
                                    ? _tallyXml()
                                    : _aging()),
                        icon: const Icon(Icons.auto_awesome,
                            color: Color(0xFF0F172A), size: 16),
                        label: Text("Generate $_fmt",
                            style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.bold))),
                    if (_data != null) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                            child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                        color: Color(0xFF0F172A)),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12)),
                                onPressed: () {
                                  Clipboard.setData(
                                      ClipboardData(text: _data!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text("OK Copied to clipboard"),
                                          backgroundColor: Colors.green,
                                          behavior: SnackBarBehavior.floating));
                                },
                                icon: const Icon(Icons.copy,
                                    color: Color(0xFF0F172A), size: 16),
                                label: const Text("Copy",
                                    style: TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.bold)))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12)),
                                onPressed: () async {
                                  final ext =
                                      _fmt == "Tally XML" ? "xml" : "csv";
                                  final fname =
                                      "${_fmt.replaceAll(' ', '_')}_${DateTime.now().day}${DateTime.now().month}${DateTime.now().year}.$ext";
                                  final dir = await getTemporaryDirectory();
                                  final file = File('${dir.path}/$fname');
                                  await file.writeAsString(_data!);
                                  await SharePlus.instance.share(ShareParams(
                                      files: [XFile(file.path)],
                                      subject: _fmt,
                                      text:
                                          "NavGati ERP Export - ${widget.userProfile.companyName}"));
                                },
                                icon: const Icon(Icons.share,
                                    color: Color(0xFF0F172A), size: 16),
                                label: const Text("Share File",
                                    style: TextStyle(
                                        color: Color(0xFF0F172A),
                                        fontWeight: FontWeight.bold)))),
                      ]),
                    ],
                  ])),
          if (_data != null)
            Expanded(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9),
                            borderRadius: BorderRadius.circular(12)),
                        child: SelectableText(_data!,
                            style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: Color(0xFF0EA5E9),
                                height: 1.5))))),
        ]),
      );
}

// ================================================================
// BANK IMPORT SCREEN
// ================================================================
class BankImportScreen extends StatefulWidget {
  final List<TripLedger> ledgers;
  final Function(String, double) onMatch;
  final List<BankEntry> sharedEntries;
  final Function(List<BankEntry>) onEntriesUpdated;
  const BankImportScreen(
      {super.key,
      required this.ledgers,
      required this.onMatch,
      this.sharedEntries = const [],
      required this.onEntriesUpdated});
  @override
  State<BankImportScreen> createState() => _BankImportScreenState();
}

class _BankImportScreenState extends State<BankImportScreen> {
  late List<BankEntry> _entries;
  bool _parsed = false;
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _entries = List.from(widget.sharedEntries);
    _parsed = _entries.isNotEmpty;
  }

  void _parse(String raw) {
    final lines = raw.trim().split('\n');
    final out = <BankEntry>[];
    for (int i = 1; i < lines.length; i++) {
      final cols = lines[i].split(',');
      if (cols.length < 4) continue;
      try {
        final e = BankEntry(
            date: cols[0].trim().replaceAll('"', ''),
            narration:
                cols.length > 1 ? cols[1].trim().replaceAll('"', '') : '',
            refNo: cols.length > 2 ? cols[2].trim().replaceAll('"', '') : '',
            debit: double.tryParse(cols.length > 3
                    ? cols[3].trim().replaceAll('"', '').replaceAll(',', '')
                    : '0') ??
                0,
            credit: double.tryParse(cols.length > 4
                    ? cols[4].trim().replaceAll('"', '').replaceAll(',', '')
                    : '0') ??
                0);
        if (e.credit > 0 || e.debit > 0) out.add(e);
      } catch (_) {}
    }
    for (final e in out) {
      for (final l in widget.ledgers) {
        final n = e.narration.toLowerCase();
        final p = l.partyName.toLowerCase();
        if (n.contains(p) ||
            p.split(' ').any((w) => w.length > 3 && n.contains(w))) {
          e.isMatched = true;
          e.matchedLedgerId = l.id;
          break;
        }
      }
    }
    setState(() {
      _entries = out;
      _parsed = true;
    });
    widget.onEntriesUpdated(_entries);
  }

  void _applyAll() {
    int n = 0;
    for (final e in _entries) {
      if (e.isMatched && e.matchedLedgerId != null && e.credit > 0) {
        widget.onMatch(e.matchedLedgerId!, e.credit);
        n++;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        content: Text("OK $n entries applied to ledgers")));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final matched = _entries.where((e) => (e).isMatched == true).length;
    return UniversalScaffold(
      appBar: AppBar(
          backgroundColor: const Color(0xFFF6FAFF),
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          title: const Text("Bank Statement Import",
              style: TextStyle(
                  color: Color(0xFF0F172A), fontWeight: FontWeight.w900)),
          actions: [
            if (matched > 0)
              TextButton(
                  onPressed: _applyAll,
                  child: Text("Apply $matched",
                      style: const TextStyle(
                          color: Color(0xFF0EA5E9),
                          fontWeight: FontWeight.bold)))
          ]),
      body: Column(children: [
        Container(
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.all(20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Paste Bank CSV",
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: Color(0xFF0F172A))),
              const SizedBox(height: 4),
              const Text("Format: Date, Narration, Ref No, Debit, Credit",
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 10),
              TextField(
                  controller: _ctrl,
                  maxLines: 5,
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                      hintText:
                          "Date,Narration,RefNo,Debit,Credit\n23/04/2026,NEFT FROM RELIANCE,REF123,,185000",
                      hintStyle:
                          TextStyle(fontSize: 10, color: Colors.grey[400]),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[50])),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF6FAFF),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 20)),
                  onPressed: () => _parse(_ctrl.text),
                  icon:
                      const Icon(Icons.auto_fix_high, color: Color(0xFF0F172A)),
                  label: const Text("Parse & Auto-Match",
                      style: TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.bold))),
            ])),
        if (_parsed)
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("${_entries.length} entries",
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, color: Colors.grey)),
                    Text("$matched matched",
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: matched > 0 ? Colors.green : Colors.grey))
                  ])),
        Expanded(
            child: _entries.isEmpty
                ? const Center(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                        Icon(Icons.file_upload_outlined,
                            size: 60, color: Colors.grey),
                        SizedBox(height: 12),
                        Text("Paste CSV and tap Parse",
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                                fontSize: 16))
                      ]))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _entries.length,
                    itemBuilder: (_, i) {
                      final e = _entries[i];
                      final ml = e.matchedLedgerId != null
                          ? widget.ledgers
                              .where((l) => l.id == e.matchedLedgerId)
                              .firstOrNull
                          : null;
                      return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                              color: context.cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: e.isMatched
                                      ? Colors.green.shade200
                                      : Colors.grey.shade200)),
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
                                            Text(e.narration,
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13),
                                                overflow:
                                                    TextOverflow.ellipsis),
                                            Text(e.date,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey))
                                          ])),
                                      Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            if (e.credit > 0)
                                              Text(
                                                  "+Rs.${e.credit.toStringAsFixed(0)}",
                                                  style: const TextStyle(
                                                      color: Colors.green,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 14)),
                                            if (e.debit > 0)
                                              Text(
                                                  "-Rs.${e.debit.toStringAsFixed(0)}",
                                                  style: const TextStyle(
                                                      color: Colors.red,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 13))
                                          ]),
                                    ]),
                                if (ml != null) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                          color: Colors.green
                                              .withValues(alpha: 0.08),
                                          borderRadius:
                                              BorderRadius.circular(8)),
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Flexible(
                                                child: Row(children: [
                                              const Icon(Icons.check_circle,
                                                  size: 14,
                                                  color: Colors.green),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                  child: Text(
                                                      "${ml.partyName} - Rs.${ml.partyPending.toStringAsFixed(0)} pending",
                                                      style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.green,
                                                          fontWeight:
                                                              FontWeight.w600)))
                                            ])),
                                            if (e.credit > 0)
                                              TextButton(
                                                  onPressed: () {
                                                    widget.onMatch(
                                                        e.matchedLedgerId!,
                                                        e.credit);
                                                    setState(() =>
                                                        e.isMatched = true);
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(SnackBar(
                                                            backgroundColor:
                                                                Colors.green,
                                                            behavior:
                                                                SnackBarBehavior
                                                                    .floating,
                                                            content: Text(
                                                                "OK Rs.${e.credit.toStringAsFixed(0)} applied")));
                                                  },
                                                  style: TextButton.styleFrom(
                                                      foregroundColor:
                                                          Colors.green,
                                                      padding: EdgeInsets.zero,
                                                      minimumSize:
                                                          const Size(60, 28)),
                                                  child: const Text("Apply",
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 12))),
                                          ]))
                                ],
                              ]));
                    })),
      ]),
    );
  }
}

// ================================================================
// ADVANCED ADMIN SCREEN (hidden - accessed via 7-tap title only)
// ================================================================

// ================================================================
// DRIVER LOCATION SHARING - phone GPS like Uber/Zomato
// ================================================================
class DriverTrackingMode extends StatefulWidget {
  final String tripId, vehicleNo, route;
  const DriverTrackingMode(
      {super.key,
      required this.tripId,
      required this.vehicleNo,
      required this.route});
  @override
  State<DriverTrackingMode> createState() => _DriverTrackingModeState();
}

class _DriverTrackingModeState extends State<DriverTrackingMode> {
  bool _sharing = false;
  bool _starting = false;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _locationRefreshTimer;
  bool _refreshingLocation = false;
  String _status = "Not sharing";
  double? _lat, _lng;
  double _speed = 0;

  Future<void> _startSharing() async {
    if (_starting || _sharing) return;
    setState(() {
      _starting = true;
      _status = "Getting location...";
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError(
            'Turn on device location to share your live position.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
            'Location permission is required. Allow foreground location access to continue.');
      }
      const settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100,
      );
      final position = await Geolocator.getCurrentPosition(
        locationSettings: settings,
      ).timeout(const Duration(seconds: 20));
      if (!mounted) return;
      setState(() {
        _sharing = true;
        _starting = false;
        _status = "Sharing your device GPS while Driver Mode is open";
      });
      await _publishLocation(position);
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        (position) => unawaited(_publishLocationSafely(position)),
        onError: (Object error) {
          if (!mounted) return;
          setState(() {
            _sharing = false;
            _status = 'Location stream stopped: $error';
          });
          unawaited(_positionSubscription?.cancel());
          _locationRefreshTimer?.cancel();
          unawaited(_clearSharedLocation().catchError((Object clearError) {
            debugPrint('Could not clear stopped GPS location: $clearError');
          }));
        },
      );
      _locationRefreshTimer = Timer.periodic(
        const Duration(minutes: 2),
        (_) => unawaited(_refreshCurrentLocation()),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sharing = false;
        _starting = false;
        _status = error.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not start live location: $error'),
        backgroundColor: Colors.red.shade700,
      ));
    }
  }

  Future<void> _publishLocation(Position position) async {
    await FirebaseFirestore.instance
        .collection('live_locations')
        .doc(widget.tripId)
        .set({
      'lat': position.latitude,
      'lng': position.longitude,
      'speed': position.speed * 3.6,
      'vehicleNo': widget.vehicleNo,
      'route': widget.route,
      'updatedAt': FieldValue.serverTimestamp(),
      'sharing': true,
    });
    if (!mounted) return;
    setState(() {
      _lat = position.latitude;
      _lng = position.longitude;
      _speed = position.speed * 3.6;
      _status =
          "Sharing live - ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}";
    });
  }

  Future<void> _publishLocationSafely(Position position) async {
    try {
      await _publishLocation(position);
    } catch (error) {
      if (mounted) {
        setState(() {
          _sharing = false;
          _status = 'Could not publish live location: $error';
        });
      }
      await _positionSubscription?.cancel();
      _locationRefreshTimer?.cancel();
      try {
        await _clearSharedLocation();
      } catch (clearError) {
        debugPrint('Could not clear unpublished GPS location: $clearError');
      }
    }
  }

  Future<void> _refreshCurrentLocation() async {
    if (!_sharing || _refreshingLocation) return;
    _refreshingLocation = true;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
        ),
      ).timeout(const Duration(seconds: 20));
      await _publishLocationSafely(position);
    } catch (error) {
      if (mounted) {
        setState(() => _status = 'Could not refresh GPS location: $error');
      }
    } finally {
      _refreshingLocation = false;
    }
  }

  Future<void> _clearSharedLocation() async {
    await FirebaseFirestore.instance
        .collection('live_locations')
        .doc(widget.tripId)
        .set({
      'lat': FieldValue.delete(),
      'lng': FieldValue.delete(),
      'speed': FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
      'sharing': false,
    }, SetOptions(merge: true));
  }

  Future<void> _stopSharing() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _locationRefreshTimer?.cancel();
    _locationRefreshTimer = null;
    setState(() {
      _sharing = false;
      _status = "Stopping location sharing...";
    });
    try {
      await _clearSharedLocation();
      if (mounted) {
        setState(() {
          _lat = null;
          _lng = null;
          _speed = 0;
          _status = "Stopped sharing";
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
            () => _status = "Sharing stopped locally; server update failed");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not clear the shared location: $error'),
          backgroundColor: Colors.red.shade700,
        ));
      }
    }
  }

  @override
  void dispose() {
    unawaited(_positionSubscription?.cancel());
    _locationRefreshTimer?.cancel();
    if (_sharing) {
      unawaited(_clearSharedLocation().catchError((Object error) {
        debugPrint('Could not clear GPS location on screen exit: $error');
      }));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UniversalScaffold(
        appBar: AppBar(
            backgroundColor: const Color(0xFFF6FAFF),
            iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
            title:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text("Driver Mode",
                  style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w900,
                      fontSize: 16)),
              Text(widget.vehicleNo,
                  style:
                      const TextStyle(color: Color(0x550F766E), fontSize: 11)),
            ])),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            // Status card
            Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                      colors: _sharing
                          ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
                          : [const Color(0xFF0EA5E9), const Color(0xFFF6FAFF)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(children: [
                  Icon(
                      _sharing
                          ? Icons.gps_fixed_rounded
                          : Icons.gps_not_fixed_rounded,
                      color: _sharing
                          ? const Color(0xFF0EA5E9)
                          : Color(0x330F766E),
                      size: 48),
                  const SizedBox(height: 12),
                  Text(
                      _sharing
                          ? "SHARING LIVE LOCATION"
                          : "LOCATION SHARING OFF",
                      style: TextStyle(
                          color: _sharing
                              ? const Color(0xFF0EA5E9)
                              : Color(0x330F766E),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text(_status,
                      style: const TextStyle(
                          color: Color(0x550F766E), fontSize: 12)),
                  if (_lat != null) ...[
                    const SizedBox(height: 8),
                    Text(
                        "${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}",
                        style: const TextStyle(
                            color: Color(0x330F766E),
                            fontSize: 10,
                            fontFamily: 'monospace')),
                    Text("Speed: ${_speed.toStringAsFixed(0)} km/h",
                        style: const TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ])),
            const SizedBox(height: 16),
            Text("Route: ${widget.route}",
                style: const TextStyle(color: Color(0x550F766E), fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const Spacer(),
            // Main action button
            SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _sharing ? Colors.red.shade800 : Colors.green.shade700,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  onPressed: _starting
                      ? null
                      : _sharing
                          ? _stopSharing
                          : _startSharing,
                  icon: Icon(
                      _sharing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      size: 24),
                  label: Text(
                      _starting
                          ? "Starting Location..."
                          : _sharing
                              ? "Stop Sharing Location"
                              : "Start Sharing Location",
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A))),
                )),
            const SizedBox(height: 12),
            const Text(
                "Your GPS is shared with your fleet while this screen is open, refreshed at least every 2 minutes. Sharing stops when you stop or leave Driver Mode.",
                style: TextStyle(color: Color(0x240F766E), fontSize: 11),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

// ================================================================
// ADMIN DASHBOARD - Full Control Panel
// ================================================================
class AdvancedAdminScreen extends StatefulWidget {
  const AdvancedAdminScreen({super.key});
  @override
  State<AdvancedAdminScreen> createState() => _AdvancedAdminScreenState();
}

class _AdvancedAdminScreenState extends State<AdvancedAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _notifTitleCtrl = TextEditingController();
  final _notifBodyCtrl = TextEditingController();
  final _userSearchCtrl = TextEditingController();
  bool _sending = false;

  // Live data snapshots
  List<Map<String, dynamic>> _allUsers = [];
  List<TripLedger> _allTrips = [];
  // ignore: unused_field
  final List<KredXApplication> _allKredx = []; // used for KredX app management
  // ignore: unused_field
  QuerySnapshot? _complaintsSnap; // cached complaints data
  // ignore: unused_field
  QuerySnapshot? _loadsSnap; // cached loads data
  // ignore: unused_field
  QuerySnapshot? _broadcastsSnap; // cached broadcasts data

  bool _usersLoaded = false;
  // ignore: unused_field
  bool _tripsLoaded = false; // tracks if trips data loaded

  final _db = FirebaseFirestore.instance;
  String _userSearch = '';

  // Verify docs tab state
  final _verifyNumCtrl = TextEditingController();
  String _verifyType = 'RC';
  String _verifyResult = '';
  bool _verifying = false;

  // Payments tab state
  final _payAmountCtrl = TextEditingController();
  final _payNameCtrl = TextEditingController();
  final _payPhoneCtrl = TextEditingController();
  final _payDescCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 11, vsync: this);
    _loadAllUsers();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _notifTitleCtrl.dispose();
    _notifBodyCtrl.dispose();
    _userSearchCtrl.dispose();
    super.dispose();
  }

  // ─── Load all users then their sub-collections ────────────────
  Future<void> _loadAllUsers() async {
    try {
      final usersSnap = await _db.collection('users').get();
      final List<Map<String, dynamic>> users = [];
      final List<TripLedger> trips = [];

      for (final doc in usersSnap.docs) {
        final profile = doc.data();
        profile['uid'] = doc.id;

        // Load sub-collection stats
        final ledgersSnap =
            await _db.collection('users/${doc.id}/ledgers').get();
        final fleetSnap = await _db.collection('users/${doc.id}/fleet').get();
        final driversSnap =
            await _db.collection('users/${doc.id}/drivers').get();

        final ledgers =
            ledgersSnap.docs.map((d) => TripLedger.fromJson(d.data())).toList();

        profile['tripCount'] = ledgers.length;
        profile['vehicleCount'] = fleetSnap.docs.length;
        profile['driverCount'] = driversSnap.docs.length;
        profile['totalRevenue'] =
            ledgers.fold(0.0, (s, l) => s + l.freightBilled);
        profile['totalPending'] =
            ledgers.fold(0.0, (s, l) => s + l.partyPending);

        users.add(profile);
        trips.addAll(ledgers);
      }

      if (mounted) {
        setState(() {
          _allUsers = users;
          _allTrips = trips;
          _usersLoaded = true;
          _tripsLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading users: $e')));
      }
    }
  }

  // ─── Summary metrics ──────────────────────────────────────────
  Map<String, dynamic> get _metrics {
    final totalRev =
        _allUsers.fold(0.0, (s, u) => s + ((u['totalRevenue'] as num?) ?? 0));
    final totalPend =
        _allUsers.fold(0.0, (s, u) => s + ((u['totalPending'] as num?) ?? 0));
    final totalVehicles =
        _allUsers.fold(0, (s, u) => s + ((u['vehicleCount'] as int?) ?? 0));
    final overdue = _allTrips.where((t) => t.isPaymentOverdue).length;
    final inTransit = _allTrips.where((t) => t.isInTransit).length;
    return {
      'users': _allUsers.length,
      'revenue': totalRev,
      'trips': _allTrips.length,
      'pending': totalPend,
      'vehicles': totalVehicles,
      'overdue': overdue,
      'inTransit': inTransit,
    };
  }

  String _fmtMoney(double n) {
    final fmt = NumberFormat('#,##,##0', 'en_IN');
    if (n >= 10000000) return '₹${(n / 10000000).toStringAsFixed(1)}Cr';
    if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(1)}L';
    return '₹${fmt.format(n)}';
  }

  @override
  Widget build(BuildContext context) {
    return UniversalScaffold(
      appBar: AppBar(
        backgroundColor: kCard,
        elevation: 0,
        title: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(6)),
            child: const Text('ADMIN',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
          ),
          const SizedBox(width: 10),
          Text('NavGati Control Centre',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: kText)),
        ]),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: kPrimary),
            tooltip: 'Refresh all data',
            onPressed: () {
              setState(() {
                _usersLoaded = false;
                _tripsLoaded = false;
                _allUsers = [];
                _allTrips = [];
              });
              _loadAllUsers();
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          labelColor: kPrimary,
          unselectedLabelColor: kSubtext,
          indicatorColor: kPrimary,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Users'),
            Tab(text: 'All Trips'),
            Tab(text: 'KredX'),
            Tab(text: 'Complaints'),
            Tab(text: 'Loads'),
            Tab(text: 'Broadcast'),
            Tab(text: 'Revenue'),
            Tab(text: 'Fleet'),
            Tab(text: 'Verify Docs'),
            Tab(text: 'Payments'),
          ],
        ),
      ),
      body: _usersLoaded
          ? TabBarView(
              controller: _tabCtrl,
              children: [
                _buildOverviewTab(),
                _buildUsersTab(),
                _buildTripsTab(),
                _buildKredxTab(),
                _buildComplaintsTab(),
                _buildLoadsTab(),
                _buildBroadcastTab(),
                _buildRevenueTab(),
                _buildAdminFleetTab(),
                _buildVerifyDocsTab(),
                _buildPaymentsTab(),
              ],
            )
          : Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: kPrimary),
                const SizedBox(height: 16),
                Text('Loading all users data…',
                    style: TextStyle(color: kSubtext)),
              ]),
            ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 1 — OVERVIEW
  // ════════════════════════════════════════════════════════════════
  Widget _buildOverviewTab() {
    final m = _metrics;
    return ListView(padding: const EdgeInsets.all(16), children: [
      // Metric grid
      GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.4,
        children: [
          _metricCard(
              'Total Users', "${m['users']}", Icons.people_rounded, kPrimary),
          _metricCard('Total Revenue', _fmtMoney(m['revenue']),
              Icons.currency_rupee_rounded, kSuccess),
          _metricCard(
              'Total Trips', "${m['trips']}", Icons.route_rounded, kAccent),
          _metricCard('Pending (₹)', _fmtMoney(m['pending']),
              Icons.pending_actions_rounded, kWarning),
          _metricCard('Vehicles', "${m['vehicles']}",
              Icons.local_shipping_rounded, kSubtext),
          _metricCard(
              'Overdue', "${m['overdue']}", Icons.warning_rounded, kDanger),
        ],
      ),
      const SizedBox(height: 16),
      // Recent Trips
      _sectionCard('Recent Trips (All Users)', Icons.route_rounded,
          child: Column(
            children: _allTrips
                .take(10)
                .map((t) => _tripRow(t, showUser: true))
                .toList(),
          )),
      const SizedBox(height: 12),
      // Tier distribution
      _sectionCard('Users by Subscription Tier', Icons.star_rounded,
          child: _buildTierBreakdown()),
    ]);
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 20),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: kText)),
        Text(label,
            style: TextStyle(fontSize: 10, color: kSubtext),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _buildTierBreakdown() {
    final counts = [0, 0, 0, 0];
    final labels = ['FREE', 'PRO', 'BUSINESS', 'ENTERPRISE'];
    final colors = [
      Colors.grey,
      Colors.blueAccent,
      Colors.amber.shade700,
      Colors.green.shade600
    ];
    for (final u in _allUsers) {
      final t = (u['subscription']?['tier'] as int?) ?? 0;
      if (t >= 0 && t < 4) counts[t]++;
    }
    return Column(
      children: List.generate(
          4,
          (i) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: colors[i],
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(labels[i],
                          style: TextStyle(
                              color: kText,
                              fontWeight: FontWeight.w600,
                              fontSize: 13))),
                  Text('${counts[i]} users',
                      style: TextStyle(color: kSubtext, fontSize: 12)),
                  const SizedBox(width: 12),
                  Container(
                    width: 80,
                    height: 6,
                    decoration: BoxDecoration(
                        color: kBg, borderRadius: BorderRadius.circular(3)),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor:
                          _allUsers.isEmpty ? 0 : counts[i] / _allUsers.length,
                      child: Container(
                          decoration: BoxDecoration(
                              color: colors[i],
                              borderRadius: BorderRadius.circular(3))),
                    ),
                  ),
                ]),
              )),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 2 — USERS
  // ════════════════════════════════════════════════════════════════
  Widget _buildUsersTab() {
    final filtered = _allUsers.where((u) {
      if (_userSearch.isEmpty) return true;
      final q = _userSearch.toLowerCase();
      return (u['companyName'] ?? '').toString().toLowerCase().contains(q) ||
          (u['phone'] ?? '').toString().contains(q) ||
          (u['gstin'] ?? '').toString().toLowerCase().contains(q);
    }).toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _userSearchCtrl,
          decoration: InputDecoration(
            hintText: 'Search by company, phone, GSTIN…',
            prefixIcon: Icon(Icons.search_rounded, color: kSubtext),
            suffixIcon: _userSearch.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: kSubtext),
                    onPressed: () => setState(() {
                          _userSearchCtrl.clear();
                          _userSearch = '';
                        }))
                : null,
            filled: true,
            fillColor: kCard,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
          ),
          onChanged: (v) => setState(() => _userSearch = v),
        ),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: filtered.length,
          itemBuilder: (_, i) => _userCard(filtered[i]),
        ),
      ),
    ]);
  }

  Widget _userCard(Map<String, dynamic> u) {
    final tier = (u['subscription']?['tier'] as int?) ?? 0;
    final tierLabels = ['FREE', 'PRO', 'BUSINESS', 'ENTERPRISE'];
    final tierColors = [
      Colors.grey,
      Colors.blueAccent,
      Colors.amber.shade700,
      Colors.green.shade600
    ];
    final uid = u['uid'] as String? ?? '';
    final revenue = (u['totalRevenue'] as num?)?.toDouble() ?? 0;
    final pending = (u['totalPending'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(u['companyName'] ?? 'Unknown',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: kText)),
                Text(u['phone'] ?? '',
                    style: TextStyle(color: kSubtext, fontSize: 12)),
                if ((u['gstin'] ?? '').isNotEmpty)
                  Text(u['gstin']!,
                      style: TextStyle(
                          color: kSubtext,
                          fontSize: 11,
                          fontFamily: 'monospace')),
              ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: tierColors[tier].withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20)),
            child: Text(tierLabels[tier],
                style: TextStyle(
                    color: tierColors[tier],
                    fontWeight: FontWeight.w800,
                    fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _miniStat('Trips', "${u['tripCount'] ?? 0}"),
          _miniStat('Vehicles', "${u['vehicleCount'] ?? 0}"),
          _miniStat(t('drivers'), "${u['driverCount'] ?? 0}"),
          _miniStat('Revenue', _fmtMoney(revenue)),
          if (pending > 0)
            _miniStat('Pending', _fmtMoney(pending), color: kDanger),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _actionBtn('Upgrade Tier', Icons.star_rounded, kPrimary,
                  () => _showSetTierDialog(uid, u['companyName'] ?? ''))),
          const SizedBox(width: 8),
          Expanded(
              child: _actionBtn('View Trips', Icons.route_rounded, kAccent,
                  () => _showUserTrips(uid, u['companyName'] ?? ''))),
        ]),
      ]),
    );
  }

  Widget _miniStat(String label, String val, {Color? color}) {
    return Expanded(
        child: Column(children: [
      Text(val,
          style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: color ?? kText)),
      Text(label, style: TextStyle(fontSize: 10, color: kSubtext)),
    ]));
  }

  Widget _actionBtn(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 12)),
        ]),
      ),
    );
  }

  void _showUserTrips(String uid, String name) {
    // Show all trips for this specific user from Firestore in real-time
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (__, sc) => Column(children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: kSubtext.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              Expanded(
                  child: Text('Trips — $name',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: kText))),
              IconButton(
                  icon: Icon(Icons.close, color: kSubtext),
                  onPressed: () => Navigator.pop(context)),
            ]),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('users/$uid/ledgers')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return Center(
                      child: CircularProgressIndicator(color: kPrimary));
                }
                final ledgers = snap.data!.docs
                    .map((d) =>
                        TripLedger.fromJson(d.data() as Map<String, dynamic>))
                    .toList();
                if (ledgers.isEmpty) {
                  return Center(
                      child: Text('No trips yet',
                          style: TextStyle(color: kSubtext)));
                }
                return ListView.builder(
                  controller: sc,
                  padding: const EdgeInsets.all(12),
                  itemCount: ledgers.length,
                  itemBuilder: (_, i) => _tripRow(ledgers[i]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  void _showSetTierDialog(String uid, String name) {
    int selectedTier = 1;
    String expiryDate = '31/12/2026';
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: kCard,
          title: Text('Set Subscription — $name',
              style: TextStyle(fontSize: 14, color: kText)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<int>(
              initialValue: selectedTier,
              decoration: InputDecoration(
                  labelText: 'Tier', filled: true, fillColor: kBg),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Free')),
                DropdownMenuItem(value: 1, child: Text('Pro')),
                DropdownMenuItem(value: 2, child: Text('Business')),
                DropdownMenuItem(value: 3, child: Text('Enterprise')),
              ],
              onChanged: (v) => setSt(() => selectedTier = v ?? 1),
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: InputDecoration(
                  labelText: 'Expiry Date (DD/MM/YYYY)',
                  filled: true,
                  fillColor: kBg),
              controller: TextEditingController(text: expiryDate),
              onChanged: (v) => expiryDate = v,
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: TextStyle(color: kSubtext))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
              onPressed: () async {
                Navigator.pop(ctx);
                await FirebaseService.adminSetUserTier(
                    uid, selectedTier, expiryDate);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('✅ Tier updated for $name'),
                      backgroundColor: kSuccess));
                  _loadAllUsers();
                }
              },
              child:
                  const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 3 — ALL TRIPS
  // ════════════════════════════════════════════════════════════════
  Widget _buildTripsTab() {
    final overdue = _allTrips.where((t) => t.isPaymentOverdue).toList();
    final inTransit = _allTrips.where((t) => t.isInTransit).toList();
    final pending = _allTrips.fold(0.0, (s, t) => s + t.partyPending);

    return Column(children: [
      // Summary bar
      Container(
        color: kCard,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          _topStat('Total', '${_allTrips.length}', kText),
          _topStat('In Transit', '${inTransit.length}', kPrimary),
          _topStat('Overdue', '${overdue.length}', kDanger),
          _topStat('Pending ₹', _fmtMoney(pending), kWarning),
        ]),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (overdue.isNotEmpty) ...[
              _sectionHeader(
                  '⚠️ Overdue Payments (${overdue.length})', kDanger),
              ...overdue.map((t) => _tripRow(t, showUser: true)),
              const SizedBox(height: 8),
            ],
            if (inTransit.isNotEmpty) ...[
              _sectionHeader('🚛 In Transit (${inTransit.length})', kPrimary),
              ...inTransit.map((t) => _tripRow(t, showUser: true)),
              const SizedBox(height: 8),
            ],
            _sectionHeader('All Trips (${_allTrips.length})', kText),
            ..._allTrips.map((t) => _tripRow(t, showUser: true)),
          ],
        ),
      ),
    ]);
  }

  Widget _topStat(String label, String val, Color color) {
    return Expanded(
        child: Column(children: [
      Text(val,
          style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 16, color: color)),
      Text(label, style: TextStyle(fontSize: 10, color: kSubtext)),
    ]));
  }

  Widget _sectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w700, fontSize: 13, color: color)),
    );
  }

  Widget _tripRow(TripLedger t, {bool showUser = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: t.isPaymentOverdue
            ? Border.all(color: kDanger.withValues(alpha: 0.3))
            : t.isInTransit
                ? Border.all(color: kPrimary.withValues(alpha: 0.3))
                : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(t.partyName,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: kText)),
                Text('${t.date}  •  ${t.route}',
                    style: TextStyle(color: kSubtext, fontSize: 11)),
                Text(t.vehicleNo,
                    style: TextStyle(
                        color: kSubtext,
                        fontSize: 11,
                        fontFamily: 'monospace')),
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
                '₹${NumberFormat('#,##,##0', 'en_IN').format(t.freightBilled)}',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14, color: kText)),
            if (t.partyPending > 0)
              Text(
                  'Pending: ₹${NumberFormat('#,##,##0', 'en_IN').format(t.partyPending)}',
                  style: TextStyle(color: kDanger, fontSize: 11)),
          ]),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: (t.isInTransit
                        ? kPrimary
                        : t.isPaymentOverdue
                            ? kDanger
                            : kSuccess)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text(
              t.isInTransit
                  ? 'In Transit'
                  : t.isPaymentOverdue
                      ? 'Overdue'
                      : 'Completed',
              style: TextStyle(
                  color: t.isInTransit
                      ? kPrimary
                      : t.isPaymentOverdue
                          ? kDanger
                          : kSuccess,
                  fontSize: 10,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 6),
          Text(
              'Profit: ₹${NumberFormat('#,##,##0', 'en_IN').format(t.tripProfit)}',
              style: TextStyle(
                  fontSize: 11,
                  color: t.tripProfit >= 0 ? kSuccess : kDanger,
                  fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 4 — KREDX
  // ════════════════════════════════════════════════════════════════
  Widget _buildKredxTab() {
    return StreamBuilder<List<KredXApplication>>(
      stream: FirebaseService.kredxStream(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return Center(child: CircularProgressIndicator(color: kPrimary));
        }
        final apps = snap.data!;
        final pending = apps
            .where((a) =>
                a.status == KredXStatus.submitted ||
                a.status == KredXStatus.underReview)
            .toList();
        final approved = apps
            .where((a) =>
                a.status == KredXStatus.approved ||
                a.status == KredXStatus.disbursed)
            .toList();
        final rejected =
            apps.where((a) => a.status == KredXStatus.rejected).toList();
        final totalReq = apps.fold(0.0, (s, a) => s + a.requestedAmount);

        return ListView(padding: const EdgeInsets.all(16), children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.5,
            children: [
              _metricCard('Pending', '${pending.length}', Icons.pending_rounded,
                  kWarning),
              _metricCard('Approved', '${approved.length}',
                  Icons.check_circle_rounded, kSuccess),
              _metricCard('Total Requested', _fmtMoney(totalReq),
                  Icons.currency_rupee_rounded, kPrimary),
              _metricCard('Rejected', '${rejected.length}',
                  Icons.cancel_rounded, kDanger),
            ],
          ),
          const SizedBox(height: 16),
          if (pending.isNotEmpty) ...[
            _sectionHeader('Pending Review', kWarning),
            ...pending.map((a) => _kredxCard(a)),
            const SizedBox(height: 8),
          ],
          if (approved.isNotEmpty) ...[
            _sectionHeader('Approved / Disbursed', kSuccess),
            ...approved.map((a) => _kredxCard(a)),
            const SizedBox(height: 8),
          ],
          if (rejected.isNotEmpty) ...[
            _sectionHeader('Rejected', kDanger),
            ...rejected.map((a) => _kredxCard(a)),
          ],
          if (apps.isEmpty)
            Center(
                child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                Icon(Icons.credit_card_off_rounded,
                    size: 48, color: kSubtext.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text('No KredX applications yet',
                    style: TextStyle(color: kSubtext)),
              ]),
            )),
        ]);
      },
    );
  }

  Widget _kredxCard(KredXApplication app) {
    final statusColors = {
      KredXStatus.draft: kSubtext,
      KredXStatus.submitted: kPrimary,
      KredXStatus.underReview: kWarning,
      KredXStatus.approved: kSuccess,
      KredXStatus.disbursed: kSuccess,
      KredXStatus.rejected: kDanger,
    };
    final color = statusColors[app.status] ?? kSubtext;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(app.partyName,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: kText))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text(app.statusLabel,
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
              child: _infoChip('Invoice',
                  '₹${NumberFormat('#,##,##0', 'en_IN').format(app.invoiceAmount)}')),
          Expanded(
              child: _infoChip('Requested',
                  '₹${NumberFormat('#,##,##0', 'en_IN').format(app.requestedAmount)}')),
          Expanded(child: _infoChip('Rate', '${app.interestRate}%/mo')),
          Expanded(child: _infoChip('Applied', app.appliedDate)),
        ]),
        if (app.status == KredXStatus.submitted ||
            app.status == KredXStatus.underReview)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(children: [
              Expanded(
                  child: _outlinedBtn('Approve', kSuccess,
                      () => _updateKredX(app.id, KredXStatus.approved))),
              const SizedBox(width: 8),
              Expanded(
                  child: _outlinedBtn('Under Review', kWarning,
                      () => _updateKredX(app.id, KredXStatus.underReview))),
              const SizedBox(width: 8),
              Expanded(
                  child: _outlinedBtn('Reject', kDanger,
                      () => _updateKredX(app.id, KredXStatus.rejected))),
            ]),
          ),
      ]),
    );
  }

  Widget _infoChip(String label, String val) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 10, color: kSubtext)),
      Text(val,
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: kText)),
    ]);
  }

  Widget _outlinedBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
          color: color.withValues(alpha: 0.08),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 11)),
      ),
    );
  }

  Future<void> _updateKredX(String id, KredXStatus status) async {
    await FirebaseService.adminUpdateKredX(id, status);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('KredX status updated'), backgroundColor: kSuccess));
    }
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 5 — COMPLAINTS
  // ════════════════════════════════════════════════════════════════
  Widget _buildComplaintsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseService.complaintsStream(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return Center(child: CircularProgressIndicator(color: kPrimary));
        }
        final docs = snap.data!.docs;
        final pending = docs
            .where((d) => (d.data() as Map)['status'] == 'pending')
            .toList();
        final approved = docs
            .where((d) => (d.data() as Map)['status'] == 'approved')
            .toList();
        final rejected = docs
            .where((d) => (d.data() as Map)['status'] == 'rejected')
            .toList();

        return ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Expanded(
                child: _metricCard('Pending', '${pending.length}',
                    Icons.hourglass_top_rounded, kWarning)),
            const SizedBox(width: 10),
            Expanded(
                child: _metricCard('Approved', '${approved.length}',
                    Icons.check_circle_rounded, kSuccess)),
            const SizedBox(width: 10),
            Expanded(
                child: _metricCard('Rejected', '${rejected.length}',
                    Icons.cancel_rounded, kDanger)),
          ]),
          const SizedBox(height: 16),
          if (pending.isNotEmpty) ...[
            _sectionHeader('⏳ Pending Review (${pending.length})', kWarning),
            ...pending.map((d) => _complaintCard(d)),
            const SizedBox(height: 8),
          ],
          if (approved.isNotEmpty) ...[
            _sectionHeader('✅ Approved (${approved.length})', kSuccess),
            ...approved.map((d) => _complaintCard(d)),
            const SizedBox(height: 8),
          ],
          if (rejected.isNotEmpty) ...[
            _sectionHeader('❌ Rejected (${rejected.length})', kDanger),
            ...rejected.map((d) => _complaintCard(d)),
          ],
          if (docs.isEmpty)
            Center(
                child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(children: [
                Icon(Icons.mood_rounded,
                    size: 48, color: kSuccess.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text('No submissions yet',
                    style: TextStyle(color: kSubtext, fontSize: 15)),
              ]),
            )),
        ]);
      },
    );
  }

  Widget _complaintCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] as String? ?? 'pending';
    final isPending = status == 'pending';
    final isApproved = status == 'approved';
    final targetName = data['targetName'] as String? ?? 'Unknown';
    final targetType = data['targetType'] as String? ?? 'driver';
    final reporterName = data['reporterName'] as String? ?? 'Unknown';
    final reason = data['reason'] as String? ?? data['issue'] as String? ?? '';
    final suggestedPts = data['suggestedPoints'] as int? ?? 0;
    final adminNote = data['adminNote'] as String? ?? '';
    final tripId = data['tripId'] as String? ?? '';
    final vehicleNo = data['vehicleNo'] as String? ?? '';
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
    final resolvedAt = (data['resolvedAt'] as Timestamp?)?.toDate();
    final isMerit = suggestedPts > 0;
    final statusColor = isPending
        ? kWarning
        : isApproved
            ? kSuccess
            : kDanger;
    final statusLabel = isPending
        ? 'Pending'
        : isApproved
            ? 'Approved'
            : 'Rejected';
    final pointsColor = suggestedPts >= 0 ? kSuccess : kDanger;

    // Admin can adjust points before approving
    int adjustedPts = suggestedPts;

    return StatefulBuilder(builder: (ctx2, ss) {
      final adminNoteCtrl = TextEditingController(text: adminNote);
      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: statusColor.withValues(alpha: isPending ? 0.4 : 0.15),
              width: isPending ? 1.5 : 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.06),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14))),
            child: Row(children: [
              Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: (isMerit ? kSuccess : kDanger)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(
                      isMerit
                          ? Icons.thumb_up_rounded
                          : Icons.thumb_down_rounded,
                      color: isMerit ? kSuccess : kDanger,
                      size: 16)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(isMerit ? 'Merit Submission' : 'Demerit Submission',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: isMerit ? kSuccess : kDanger)),
                    Text('Re: $targetName ($targetType)',
                        style: TextStyle(
                            color: kText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ])),
              Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11))),
            ]),
          ),
          // ── Body ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Reporter
              Row(children: [
                Icon(Icons.person_outline_rounded, size: 14, color: kSubtext),
                const SizedBox(width: 6),
                Text('Submitted by: $reporterName',
                    style: TextStyle(color: kSubtext, fontSize: 12)),
              ]),
              if (tripId.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.receipt_outlined, size: 14, color: kSubtext),
                  const SizedBox(width: 6),
                  Text('Trip: $tripId',
                      style: TextStyle(color: kSubtext, fontSize: 11)),
                ]),
              ],
              if (vehicleNo.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.local_shipping_outlined,
                      size: 14, color: kSubtext),
                  const SizedBox(width: 6),
                  Text('Vehicle: $vehicleNo',
                      style: TextStyle(color: kSubtext, fontSize: 11)),
                ]),
              ],
              const SizedBox(height: 10),
              // Reason
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: kBg, borderRadius: BorderRadius.circular(8)),
                child: Text(reason.isNotEmpty ? reason : '(No reason provided)',
                    style: TextStyle(
                        color: kText,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),
              // Suggested points
              Row(children: [
                Text('Suggested: ',
                    style: TextStyle(color: kSubtext, fontSize: 12)),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                        color: pointsColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(
                        '${suggestedPts > 0 ? "+" : ""}\$suggestedPts points',
                        style: TextStyle(
                            color: pointsColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 13))),
                const Spacer(),
                Text(
                    submittedAt != null
                        ? '${submittedAt.day}/${submittedAt.month}/${submittedAt.year}'
                        : '',
                    style: TextStyle(color: kSubtext, fontSize: 10)),
              ]),
              // Admin note (if resolved)
              if (!isPending && adminNote.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: statusColor.withValues(alpha: 0.2))),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Admin Note:',
                            style: TextStyle(
                                color: kSubtext,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(adminNote,
                            style: TextStyle(color: kText, fontSize: 12)),
                        if (resolvedAt != null)
                          Text(
                              'Resolved ${resolvedAt.day}/${resolvedAt.month}/${resolvedAt.year}',
                              style: TextStyle(color: kSubtext, fontSize: 10)),
                      ]),
                ),
              ],
              // ── Approve / Reject (pending only) ───────────
              if (isPending) ...[
                const Divider(height: 20),
                // Adjustable points
                Row(children: [
                  Text('Apply points:',
                      style: TextStyle(
                          color: kText,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                  const SizedBox(width: 10),
                  GestureDetector(
                      onTap: () => ss(() => adjustedPts =
                          (adjustedPts - 5).clamp(-50, 50).toInt()),
                      child: Icon(Icons.remove_circle_outline,
                          color: kDanger, size: 22)),
                  const SizedBox(width: 8),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: (adjustedPts >= 0 ? kSuccess : kDanger)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Text('${adjustedPts > 0 ? "+" : ""}\$adjustedPts',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: adjustedPts >= 0 ? kSuccess : kDanger))),
                  const SizedBox(width: 8),
                  GestureDetector(
                      onTap: () => ss(() => adjustedPts =
                          (adjustedPts + 5).clamp(-50, 50).toInt()),
                      child: Icon(Icons.add_circle_outline,
                          color: kSuccess, size: 22)),
                ]),
                const SizedBox(height: 10),
                TextField(
                  controller: adminNoteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                      hintText: 'Admin note / reason for decision (optional)',
                      hintStyle: TextStyle(color: kSubtext, fontSize: 12),
                      filled: true,
                      fillColor: kBg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10)),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                              side: BorderSide(color: kDanger),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12)),
                          onPressed: () async {
                            await FirebaseService.resolveComplaint(
                                doc.id,
                                false,
                                adminNoteCtrl.text.trim().isEmpty
                                    ? 'Rejected by admin'
                                    : adminNoteCtrl.text.trim());
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: const Text(
                                      '❌ Submission rejected. No points applied.'),
                                  backgroundColor: kDanger));
                            }
                          },
                          icon: Icon(Icons.cancel_outlined,
                              color: kDanger, size: 16),
                          label: Text('Reject',
                              style: TextStyle(
                                  color: kDanger,
                                  fontWeight: FontWeight.w800)))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: kSuccess,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12)),
                          onPressed: () async {
                            final note = adminNoteCtrl.text.trim().isEmpty
                                ? '${adjustedPts > 0 ? "Merit" : "Demerit"} approved by admin'
                                : adminNoteCtrl.text.trim();
                            await FirebaseService.resolveComplaint(
                              doc.id,
                              true,
                              note,
                              pointsToApply: adjustedPts,
                              driverUid: data['targetUid'] as String? ??
                                  data['driverUid'] as String?,
                              driverId: data['targetId'] as String? ??
                                  data['driverId'] as String?,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(
                                      '✅ Approved! ${adjustedPts > 0 ? "+" : ""}\$adjustedPts points applied to $targetName'),
                                  backgroundColor: kSuccess));
                            }
                          },
                          icon: const Icon(Icons.check_circle_outline,
                              color: Colors.white, size: 16),
                          label: const Text('Approve & Apply',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800)))),
                ]),
              ],
            ]),
          ),
        ]),
      );
    });
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 6 — LOAD BOARD
  // ════════════════════════════════════════════════════════════════
  Widget _buildLoadsTab() {
    return StreamBuilder<List<MarketLoad>>(
      stream: FirebaseService.marketLoadsStream(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return Center(child: CircularProgressIndicator(color: kPrimary));
        }
        final loads = snap.data!;
        final active = loads.where((l) => l.status == BidStatus.pending).length;
        final booked = loads.where((l) => l.status == BidStatus.booked).length;
        final totalBids = loads.fold(0, (s, l) => s + l.bids.length);
        final avgRate = loads.isEmpty
            ? 0.0
            : loads.fold(0.0, (s, l) => s + l.targetPrice) / loads.length;

        return ListView(padding: const EdgeInsets.all(16), children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.5,
            children: [
              _metricCard('Active Loads', '$active',
                  Icons.local_shipping_rounded, kPrimary),
              _metricCard(
                  'Booked', '$booked', Icons.check_circle_rounded, kSuccess),
              _metricCard(
                  'Total Bids', '$totalBids', Icons.gavel_rounded, kWarning),
              _metricCard('Avg Rate', _fmtMoney(avgRate),
                  Icons.trending_up_rounded, kAccent),
            ],
          ),
          const SizedBox(height: 16),
          ...loads.map((l) => _loadCard(l)),
          if (loads.isEmpty)
            Center(
                child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(children: [
                Icon(Icons.inbox_outlined,
                    size: 48, color: kSubtext.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                Text('No loads posted yet', style: TextStyle(color: kSubtext)),
              ]),
            )),
        ]);
      },
    );
  }

  Widget _loadCard(MarketLoad l) {
    final statusColor = l.status == BidStatus.booked
        ? kSuccess
        : l.status == BidStatus.inTransit
            ? kWarning
            : kPrimary;
    final statusLabel = l.status == BidStatus.booked
        ? 'Booked'
        : l.status == BidStatus.inTransit
            ? 'Bidding'
            : 'Open';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('${l.originCity} → ${l.destCity}',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: kText))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20)),
            child: Text(statusLabel,
                style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _infoChip('Material', l.materialType),
            const SizedBox(width: 6),
            _infoChip('Vehicle', l.vehicleType),
            const SizedBox(width: 6),
            _infoChip('Weight', '${l.weightTons} MT'),
            const SizedBox(width: 6),
            _infoChip('Target',
                '₹${NumberFormat('#,##,##0', 'en_IN').format(l.targetPrice)}'),
          ]),
        ),
        const SizedBox(height: 4),
        Text('Posted by: ${l.postedByName}  •  ${l.bids.length} bids',
            style: TextStyle(fontSize: 11, color: kSubtext)),
      ]),
    );
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 7 — BROADCAST
  // ════════════════════════════════════════════════════════════════
  Widget _buildBroadcastTab() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Send form
      Expanded(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _sectionCard('Send Notification to All Users', Icons.send_rounded,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  TextField(
                    controller: _notifTitleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Title *',
                      filled: true,
                      fillColor: kBg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notifBodyCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Message Body',
                      filled: true,
                      fillColor: kBg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        minimumSize: const Size.fromHeight(46)),
                    onPressed: _sending ? null : _sendBroadcast,
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, color: Colors.white),
                    label: Text(_sending ? 'Sending…' : 'Send to All Users',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ]),
              )),
        ]),
      ),
      // Past broadcasts
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 16, 8),
            child: Text('Past Broadcasts',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14, color: kText)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('adminNotifications')
                  .orderBy('sentAt', descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return Center(
                      child: CircularProgressIndicator(color: kPrimary));
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                        child: Text('No broadcasts sent yet',
                            style: TextStyle(color: kSubtext))),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(right: 16),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final d = docs[i].data() as Map<String, dynamic>;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4)
                        ],
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d['title'] ?? '',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: kText)),
                            if ((d['body'] ?? '').isNotEmpty)
                              Text(d['body'],
                                  style:
                                      TextStyle(color: kSubtext, fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(d['sentAt']?.toString().split('T').first ?? '',
                                style:
                                    TextStyle(fontSize: 10, color: kSubtext)),
                            const SizedBox(height: 4),
                            Text(
                                'Push: ${d['pushStatus'] ?? 'queued'}${d['pushError'] is String ? ' · ${d['pushError']}' : ''}',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: d['pushStatus'] == 'failed' ||
                                            d['pushStatus'] == 'rejected'
                                        ? kDanger
                                        : kSubtext)),
                          ]),
                    );
                  },
                );
              },
            ),
          ),
        ]),
      ),
    ]);
  }

  Future<void> _sendBroadcast() async {
    final title = _notifTitleCtrl.text.trim();
    final body = _notifBodyCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }
    setState(() => _sending = true);
    final ok = await FirebaseService.adminBroadcastNotification(
        title: title, body: body);
    if (mounted) {
      setState(() => _sending = false);
      if (ok) {
        _notifTitleCtrl.clear();
        _notifBodyCtrl.clear();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Broadcast queued for push delivery.'),
            backgroundColor: kSuccess));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text('Failed to send'), backgroundColor: kDanger));
      }
    }
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 8 — REVENUE ANALYTICS
  // ════════════════════════════════════════════════════════════════
  Widget _buildRevenueTab() {
    final byParty = <String, double>{};
    final byMonth = <String, double>{};
    for (final t in _allTrips) {
      byParty[t.partyName] = (byParty[t.partyName] ?? 0) + t.freightBilled;
      final month = t.date.length >= 7 ? t.date.substring(0, 7) : 'Unknown';
      byMonth[month] = (byMonth[month] ?? 0) + t.freightBilled;
    }
    final sortedUsers = byParty.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedMonths = byMonth.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final totalRev = _allTrips.fold<double>(0, (s, t) => s + t.freightBilled);
    final totalExp = _allTrips.fold<double>(
        0, (s, t) => s + t.selfExpenses + t.marketTruckFreight);
    final totalProfit = totalRev - totalExp;

    return ListView(padding: const EdgeInsets.all(16), children: [
      // Summary cards
      Row(children: [
        Expanded(
            child: _metricCard(
                'Total Revenue',
                '₹${(totalRev / 100000).toStringAsFixed(1)}L',
                Icons.currency_rupee_rounded,
                kSuccess)),
        const SizedBox(width: 10),
        Expanded(
            child: _metricCard(
                'Total Expenses',
                '₹${(totalExp / 100000).toStringAsFixed(1)}L',
                Icons.receipt_rounded,
                kDanger)),
        const SizedBox(width: 10),
        Expanded(
            child: _metricCard(
                'Net Profit',
                '₹${(totalProfit / 100000).toStringAsFixed(1)}L',
                Icons.trending_up_rounded,
                kPrimary)),
      ]),
      const SizedBox(height: 16),
      // Monthly trend
      _sectionCard(
        'Monthly Revenue Trend',
        Icons.bar_chart_rounded,
        child: Column(children: [
          ...sortedMonths.map((e) {
            final pct = totalRev > 0 ? e.value / totalRev : 0.0;
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(children: [
                SizedBox(
                    width: 60,
                    child: Text(e.key,
                        style: TextStyle(fontSize: 11, color: kSubtext))),
                const SizedBox(width: 8),
                Expanded(
                    child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: pct.toDouble(),
                      backgroundColor: kBg,
                      valueColor: AlwaysStoppedAnimation(kSuccess),
                      minHeight: 16),
                )),
                const SizedBox(width: 8),
                Text('₹${(e.value / 1000).toStringAsFixed(0)}K',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kText)),
              ]),
            );
          }),
        ]),
      ),
      const SizedBox(height: 12),
      // Top users by revenue
      _sectionCard(
        'Top Parties by Revenue',
        Icons.leaderboard_rounded,
        child: Column(children: [
          ...sortedUsers.take(10).map((e) => ListTile(
                dense: true,
                leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: kPrimary.withValues(alpha: 0.1),
                    child: Text(e.key.isNotEmpty ? e.key[0].toUpperCase() : '?',
                        style: TextStyle(
                            color: kPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800))),
                title: Text(e.key,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: kText)),
                trailing: Text('₹${(e.value / 1000).toStringAsFixed(0)}K',
                    style: TextStyle(
                        color: kSuccess, fontWeight: FontWeight.w800)),
              )),
        ]),
      ),
    ]);
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 9 — FLEET OVERVIEW (all users' vehicles)
  // ════════════════════════════════════════════════════════════════
  Widget _buildAdminFleetTab() {
    return FutureBuilder<QuerySnapshot>(
      future:
          FirebaseFirestore.instance.collectionGroup('fleet').limit(200).get(),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final vehicles = snap.data!.docs;
        final byType = <String, int>{};
        for (final v in vehicles) {
          final t = (v.data() as Map)['vehicleType'] ?? 'Unknown';
          byType[t] = (byType[t] ?? 0) + 1;
        }
        return ListView(padding: const EdgeInsets.all(16), children: [
          Row(children: [
            Expanded(
                child: _metricCard('Total Vehicles', '${vehicles.length}',
                    Icons.local_shipping_rounded, kPrimary)),
            const SizedBox(width: 10),
            Expanded(
                child: _metricCard('Vehicle Types', '${byType.length}',
                    Icons.category_rounded, kAccent)),
          ]),
          const SizedBox(height: 16),
          _sectionCard(
            'Fleet by Type',
            Icons.pie_chart_rounded,
            child: Column(children: [
              ...byType.entries.map((e) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.local_shipping_rounded,
                        size: 18, color: kPrimary),
                    title: Text(e.key,
                        style: TextStyle(
                            color: kText, fontWeight: FontWeight.w600)),
                    trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: kPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text('${e.value}',
                            style: TextStyle(
                                color: kPrimary, fontWeight: FontWeight.w800))),
                  )),
            ]),
          ),
          const SizedBox(height: 12),
          _sectionCard(
            'All Vehicles',
            Icons.list_rounded,
            child: Column(children: [
              ...vehicles.take(50).map((v) {
                final d = v.data() as Map<String, dynamic>;
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.local_shipping_rounded,
                      size: 16, color: kSubtext),
                  title: Text(d['number'] ?? 'Unknown',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: kText)),
                  subtitle: Text(
                      '${d['vehicleType'] ?? ''} · ${d['axleCount'] ?? 0} axle',
                      style: TextStyle(fontSize: 11, color: kSubtext)),
                  trailing: Text(d['ownerName'] ?? '',
                      style: TextStyle(fontSize: 11, color: kSubtext)),
                );
              }),
            ]),
          ),
        ]);
      },
    );
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 10 — VERIFY DOCS (Surepass API)
  // ════════════════════════════════════════════════════════════════
  // HOW TO GET API KEY: Sign up at https://surepass.io → Dashboard → API Keys
  // Free trial: 100 API calls. Covers RC, PAN, Aadhaar OTP, DL, GSTIN, Bank verification.
  static const _surepassToken =
      'YOUR_SUREPASS_API_TOKEN'; // Replace with your token

  Future<void> _runVerification() async {
    final num = _verifyNumCtrl.text.trim();
    if (num.isEmpty) return;
    setState(() {
      _verifying = true;
      _verifyResult = '';
    });

    final endpoints = {
      'RC': 'https://kyc-api.surepass.io/api/v1/rc/rc-full',
      'PAN': 'https://kyc-api.surepass.io/api/v1/pan/pan',
      'DL':
          'https://kyc-api.surepass.io/api/v1/driving-license/driving-license',
      'GSTIN': 'https://kyc-api.surepass.io/api/v1/gstin/gstin',
      'VAHAN': 'https://kyc-api.surepass.io/api/v1/rc/rc-full',
    };
    final bodyKeys = {
      'RC': 'id_number',
      'PAN': 'id_number',
      'DL': 'id_number',
      'GSTIN': 'id_number',
      'VAHAN': 'id_number',
    };

    try {
      final resp = await http.post(
        Uri.parse(endpoints[_verifyType]!),
        headers: {
          'Authorization': 'Bearer $_surepassToken',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({bodyKeys[_verifyType]!: num}),
      );
      final data = jsonDecode(resp.body);
      if (data['success'] == true) {
        final d = data['data'] as Map<String, dynamic>;
        final lines = d.entries
            .where((e) => e.value != null && e.value.toString().isNotEmpty)
            .map((e) => '${e.key}: ${e.value}')
            .join('\n');
        setState(() {
          _verifyResult = lines;
          _verifying = false;
        });
      } else {
        setState(() {
          _verifyResult = 'Error: ${data['message'] ?? 'Verification failed'}';
          _verifying = false;
        });
      }
    } catch (e) {
      setState(() {
        _verifyResult = 'Network error: $e';
        _verifying = false;
      });
    }
  }

  Widget _buildVerifyDocsTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.amber.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.info_outline, color: Colors.amber.shade700, size: 16),
            const SizedBox(width: 6),
            Text('Surepass API Setup',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: Colors.amber.shade800))
          ]),
          const SizedBox(height: 6),
          Text(
              '1. Go to surepass.io → Sign up (free 100 calls)\n2. Get your API token from Dashboard → API Keys\n3. Replace YOUR_SUREPASS_API_TOKEN in main.dart line with your token\n4. Supported: RC Lookup, PAN, Driving Licence, GSTIN, Aadhaar (requires KYC tier)',
              style: TextStyle(fontSize: 12, color: Colors.amber.shade900)),
        ]),
      ),
      const SizedBox(height: 16),
      _sectionCard(
        'Document Verification',
        Icons.verified_user_rounded,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              DropdownButtonFormField<String>(
                initialValue: _verifyType,
                decoration: InputDecoration(
                    labelText: 'Document Type',
                    filled: true,
                    fillColor: kBg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none)),
                items: ['RC', 'VAHAN', 'PAN', 'DL', 'GSTIN']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _verifyType = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _verifyNumCtrl,
                decoration: InputDecoration(
                    labelText: 'Enter Number (RC / PAN / DL / GSTIN)',
                    filled: true,
                    fillColor: kBg,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _verifyNumCtrl.clear())),
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    minimumSize: const Size.fromHeight(46)),
                onPressed: _verifying ? null : _runVerification,
                icon: _verifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.search_rounded, color: Colors.white),
                label: Text(_verifying ? 'Verifying…' : 'Verify Document',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              if (_verifyResult.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _verifyResult.startsWith('Error')
                          ? kDanger.withValues(alpha: 0.08)
                          : kSuccess.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _verifyResult.startsWith('Error')
                              ? kDanger
                              : kSuccess),
                    ),
                    child: SelectableText(_verifyResult,
                        style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: _verifyResult.startsWith('Error')
                                ? kDanger
                                : kSuccess))),
              ],
            ])),
      ),
    ]);
  }

  // ════════════════════════════════════════════════════════════════
  // TAB 11 — PAYMENTS (Razorpay)
  // ════════════════════════════════════════════════════════════════
  // HOW TO GET API KEY:
  // 1. Go to https://razorpay.com → Sign up (free)
  // 2. Dashboard → Settings → API Keys → Generate Key
  // 3. You get Key ID (starts with rzp_test_) and Key Secret
  // 4. Replace the values below. Switch to rzp_live_ when going live.
  // 5. Add razorpay_flutter: ^1.3.6 to pubspec.yaml dependencies
  // ignore: unused_field
  static const _razorpayKeyId =
      'rzp_test_YOUR_KEY_ID'; // Replace with your Razorpay Key ID - used for payment processing

  Future<void> _initiatePayment() async {
    final amount = double.tryParse(_payAmountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter valid amount')));
      return;
    }
    // Create Razorpay order via your backend or directly
    // For now, shows the integration pattern:
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Razorpay integration ready — add razorpay_flutter package & replace API key'),
      backgroundColor: kPrimary,
    ));
    // Full implementation after adding razorpay_flutter to pubspec:
    // final razorpay = Razorpay();
    // razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    // razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    // razorpay.open({
    //   'key': _razorpayKeyId,
    //   'amount': (amount * 100).toInt(), // in paise
    //   'name': 'NavGati ERP',
    //   'description': _payDescCtrl.text,
    //   'prefill': {'contact': _payPhoneCtrl.text, 'name': _payNameCtrl.text},
    //   'theme': {'color': '#0EA5E9'},
    // });
  }

  Widget _buildPaymentsTab() {
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade200)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.payments_rounded,
                color: Colors.green.shade700, size: 16),
            const SizedBox(width: 6),
            Text('Razorpay Setup',
                style: TextStyle(
                    fontWeight: FontWeight.w800, color: Colors.green.shade800))
          ]),
          const SizedBox(height: 6),
          Text(
              '1. razorpay.com → Sign up → Dashboard → Settings → API Keys\n2. Copy Key ID (rzp_test_...) → paste in main.dart _razorpayKeyId\n3. Add to pubspec: razorpay_flutter: ^1.3.6\n4. Supports: UPI, Cards, Net Banking, Wallets, EMI\n5. Switch rzp_test_ → rzp_live_ when going live',
              style: TextStyle(fontSize: 12, color: Colors.green.shade900)),
        ]),
      ),
      const SizedBox(height: 16),
      // Payment collection form
      _sectionCard(
        'Collect Payment',
        Icons.point_of_sale_rounded,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              TextField(
                  controller: _payNameCtrl,
                  decoration: InputDecoration(
                      labelText: 'Party Name',
                      filled: true,
                      fillColor: kBg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none))),
              const SizedBox(height: 10),
              TextField(
                  controller: _payPhoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                      labelText: 'Phone Number',
                      filled: true,
                      fillColor: kBg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none))),
              const SizedBox(height: 10),
              TextField(
                  controller: _payAmountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText: 'Amount (₹)',
                      filled: true,
                      fillColor: kBg,
                      prefixIcon: const Icon(Icons.currency_rupee_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none))),
              const SizedBox(height: 10),
              TextField(
                  controller: _payDescCtrl,
                  decoration: InputDecoration(
                      labelText: 'Description (LR / Trip ID)',
                      filled: true,
                      fillColor: kBg,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none))),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    minimumSize: const Size.fromHeight(48)),
                onPressed: _initiatePayment,
                icon: const Icon(Icons.payment_rounded, color: Colors.white),
                label: const Text('Collect via Razorpay',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
              ),
            ])),
      ),
      const SizedBox(height: 16),
      // UPI payment option
      _sectionCard(
        'Quick UPI Payment Link',
        Icons.link_rounded,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Text(
                  'Generate a UPI payment link for any party without Razorpay:',
                  style: TextStyle(color: kSubtext, fontSize: 13)),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6739B7),
                    minimumSize: const Size.fromHeight(44)),
                onPressed: () {
                  final amount = _payAmountCtrl.text;
                  final name = _payNameCtrl.text;
                  if (amount.isNotEmpty) {
                    final upiUrl =
                        'upi://pay?pa=YOUR_UPI_ID@bank&pn=Route+Master+ERP&am=$amount&cu=INR&tn=${Uri.encodeComponent(name)}';
                    launchUrl(Uri.parse(upiUrl));
                  }
                },
                icon: const Icon(Icons.currency_rupee_rounded,
                    color: Colors.white),
                label: const Text('Open in UPI App',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Text('Replace YOUR_UPI_ID@bank with your business UPI ID',
                  style: TextStyle(fontSize: 11, color: kSubtext)),
            ])),
      ),
      const SizedBox(height: 16),
      // Firebase silent OTP setup guide
      _sectionCard(
        'Silent OTP Setup (No Webpage)',
        Icons.phonelink_lock_rounded,
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Steps to eliminate the reCAPTCHA webpage for OTP:',
                  style: TextStyle(color: kText, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ...[
                '1. Run: keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android',
                '2. Copy the SHA-1 fingerprint from the output',
                '3. Firebase Console → Project Settings → Your Android App → Add Fingerprint → paste SHA-1',
                '4. Download updated google-services.json → replace android/app/google-services.json',
                '5. Firebase Console → Authentication → App Check → Enable Play Integrity',
                '6. Done — Firebase will silently verify & OTP arrives directly on phone',
              ].map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(s,
                        style: TextStyle(fontSize: 12, color: kSubtext)),
                  )),
            ])),
      ),
    ]);
  }

  // ─── Helpers ──────────────────────────────────────────────────
  Widget _sectionCard(String title, IconData icon, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            Icon(icon, color: kPrimary, size: 18),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14, color: kText)),
          ]),
        ),
        child,
      ]),
    );
  }
}
// ================================================================
// END AdvancedAdminScreen — NavGati ERP v5.0
// ================================================================

// ================================================================
// PARTY STATEMENT GENERATOR — Finance Tab
// ================================================================
class _PartyStatementGenerator extends StatefulWidget {
  final List<TripLedger> ledgers;
  final Color cardColor,
      card2Color,
      borderColor,
      accentColor,
      purpleColor,
      greenColor,
      redColor;
  const _PartyStatementGenerator({
    required this.ledgers,
    required this.cardColor,
    required this.card2Color,
    required this.borderColor,
    required this.accentColor,
    required this.purpleColor,
    required this.greenColor,
    required this.redColor,
  });
  @override
  State<_PartyStatementGenerator> createState() =>
      _PartyStatementGeneratorState();
}

class _PartyStatementGeneratorState extends State<_PartyStatementGenerator> {
  String? _selectedParty;
  bool _generating = false;

  List<String> get _parties {
    final s = <String>{};
    for (final l in widget.ledgers) {
      s.add(l.partyName);
    }
    return s.toList()..sort();
  }

  Future<void> _generateStatement() async {
    if (_selectedParty == null) return;
    setState(() => _generating = true);
    try {
      final trips =
          widget.ledgers.where((l) => l.partyName == _selectedParty).toList();
      final totalFreight = trips.fold(0.0, (s, l) => s + l.freightBilled);
      final totalReceived = trips.fold(0.0, (s, l) => s + l.paymentReceived);
      final totalPending = trips.fold(
          0.0, (s, l) => s + (l.partyPending > 0 ? l.partyPending : 0));
      final now = DateTime.now();

      final pdf = pw.Document();
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#0D1F14'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('NAVGATI ERP',
                              style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 15)),
                          pw.Text('Party Account Statement',
                              style: pw.TextStyle(
                                  color: PdfColor.fromHex('#8FBC8F'),
                                  fontSize: 10)),
                        ]),
                    pw.Text('As of ${now.day}/${now.month}/${now.year}',
                        style:
                            pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                  ]),
            ),
            pw.SizedBox(height: 14),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                    color: PdfColor.fromHex('#BFDBFE'), width: 0.5),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                color: PdfColor.fromHex('#EFF6FF'),
              ),
              child: pw.Row(children: [
                pw.Text('Party: ',
                    style:
                        pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                pw.Text(_selectedParty!,
                    style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold, fontSize: 14)),
                pw.Spacer(),
                pw.Text('Total Trips: ${trips.length}',
                    style: pw.TextStyle(fontSize: 10)),
              ]),
            ),
            pw.SizedBox(height: 12),
            // Summary row
            pw.Row(children: [
              _pdfSummaryBox(
                  'Total Freight',
                  'Rs.${totalFreight.toStringAsFixed(0)}',
                  PdfColor.fromHex('#1D4ED8')),
              pw.SizedBox(width: 8),
              _pdfSummaryBox(
                  'Received',
                  'Rs.${totalReceived.toStringAsFixed(0)}',
                  PdfColor.fromHex('#059669')),
              pw.SizedBox(width: 8),
              _pdfSummaryBox(
                  'Outstanding',
                  'Rs.${totalPending.toStringAsFixed(0)}',
                  PdfColor.fromHex('#DC2626')),
            ]),
            pw.SizedBox(height: 14),
            pw.Text('TRIP DETAILS',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                    color: PdfColor.fromHex('#1D4ED8'))),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(
                  color: PdfColor.fromHex('#BFDBFE'), width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1.2),
                5: const pw.FlexColumnWidth(1.2),
              },
              children: [
                pw.TableRow(
                  decoration:
                      pw.BoxDecoration(color: PdfColor.fromHex('#EFF6FF')),
                  children: [
                    'Date',
                    'Route',
                    'Vehicle',
                    'Freight',
                    'Received',
                    'Pending'
                  ]
                      .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(h,
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 8))))
                      .toList(),
                ),
                ...trips.map((t) => pw.TableRow(children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(t.date,
                              style: pw.TextStyle(fontSize: 8))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(t.route,
                              style: pw.TextStyle(fontSize: 8))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(t.vehicleNo,
                              style: pw.TextStyle(fontSize: 8))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                              'Rs.${t.freightBilled.toStringAsFixed(0)}',
                              style: pw.TextStyle(fontSize: 8))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                              'Rs.${t.paymentReceived.toStringAsFixed(0)}',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColor.fromHex('#059669')))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                              'Rs.${(t.partyPending > 0 ? t.partyPending : 0).toStringAsFixed(0)}',
                              style: pw.TextStyle(
                                  fontSize: 8,
                                  color: t.partyPending > 0
                                      ? PdfColor.fromHex('#DC2626')
                                      : PdfColor.fromHex('#059669')))),
                    ])),
              ],
            ),
            pw.Spacer(),
            pw.Text(
                'Generated by NavGati ERP v5.0 | ${now.day}/${now.month}/${now.year}',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
          ],
        ),
      ));
      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name: 'PartyStatement_${_selectedParty!.replaceAll(" ", "_")}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            backgroundColor: Colors.red, content: Text('PDF error: $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  pw.Widget _pdfSummaryBox(String label, String value, PdfColor color) =>
      pw.Expanded(
          child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
          color: PdfColor(color.red, color.green, color.blue, 0.1),
        ),
        child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.SizedBox(height: 3),
              pw.Text(value,
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                      color: color)),
            ]),
      ));

  @override
  Widget build(BuildContext context) {
    final parties = _parties;
    if (parties.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: widget.card2Color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: widget.borderColor)),
        child: const Text(
            'No trip data yet. Add trips to generate party statements.',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: widget.cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text(
            'Select party to generate a PDF statement of all trips and outstanding:',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _selectedParty,
          style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            labelText: 'Select Party / Consignor',
            filled: true,
            fillColor: widget.card2Color,
            labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: widget.borderColor)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: widget.borderColor)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: widget.accentColor, width: 2)),
            prefixIcon: Icon(Icons.business_rounded,
                color: widget.purpleColor, size: 18),
          ),
          items: parties
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (v) => setState(() => _selectedParty = v),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: (_selectedParty == null || _generating)
                ? null
                : _generateStatement,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: (_selectedParty == null || _generating)
                    ? const Color(0xFF94A3B8)
                    : widget.purpleColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (_generating)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                else
                  const Icon(Icons.picture_as_pdf_rounded,
                      color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                    _generating
                        ? 'Generating...'
                        : 'Generate Party Statement PDF',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

// ================================================================
// SUBSCRIPTION SCREEN WIDGET
// ================================================================
class SubscriptionScreen extends StatefulWidget {
  final SubscriptionInfo current;
  final Function(SubscriptionTier) onUpgrade;
  final Function(Set<String> addOns, int extraUsers, int extraVehicleBlocks)
      onAddOnsUpdate;

  const SubscriptionScreen({
    super.key,
    required this.current,
    required this.onUpgrade,
    required this.onAddOnsUpdate,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  late Set<String> _selectedAddOns;
  late int _extraUsers;
  late int _extraVehicleBlocks;

  @override
  void initState() {
    super.initState();
    _selectedAddOns = Set<String>.from(widget.current.addOns);
    _extraUsers = widget.current.extraUsers;
    _extraVehicleBlocks = widget.current.extraVehicleBlocks;
  }

  double get _addOnsTotal {
    double total = 0;
    for (final f in kAlaCarteFeatures) {
      if (_selectedAddOns.contains(f.id)) total += f.monthlyPrice;
    }
    total += _extraUsers * kAlaCartePerExtraUserPrice;
    total += _extraVehicleBlocks * kAlaCartePerExtraVehicleBlockPrice;
    return total;
  }

  Widget _planCard(BuildContext context, SubscriptionTier tier, String name,
      String price, String period, Color color, List<Widget> features,
      {bool recommended = false}) {
    final isCurrent = widget.current.tier == tier;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent ? color.withValues(alpha: 0.12) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrent ? color : const Color(0xFFE2E8F0),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (recommended)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'BEST VALUE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  period,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...features,
          const SizedBox(height: 12),
          if (!isCurrent)
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  widget.onUpgrade(tier);
                  Navigator.pop(context);
                },
                child: Text(
                  tier.index > widget.current.tier.index
                      ? 'Upgrade to $name'
                      : 'Downgrade to $name',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          if (isCurrent)
            Container(
              width: double.infinity,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: const Center(
                child: Text(
                  '✓ Your Current Plan',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _feature(bool enabled, String label) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(
              enabled ? Icons.check_circle : Icons.remove_circle_outline,
              size: 16,
              color:
                  enabled ? const Color(0xFFFB8C00) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: enabled
                      ? const Color(0xFF0F172A)
                      : const Color(0xFF64748B),
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        title: const Text('Choose Your Plan'),
        backgroundColor: const Color(0xFFFFF8E1),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.workspace_premium,
                    color: widget.current.tierColor,
                    size: 32,
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Plan',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        widget.current.tierName,
                        style: TextStyle(
                          color: widget.current.tierColor,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${widget.current.tripsUsedThisMonth}/${widget.current.tier == SubscriptionTier.free ? '10' : '∞'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const Text(
                        'trips this month',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _planCard(
              context,
              SubscriptionTier.free,
              'FREE',
              '₹0',
              'Forever',
              Colors.grey,
              [
                _feature(true, '10 trips per month'),
                _feature(true, 'Basic ledger & fleet'),
                _feature(true, 'Driver roster'),
                _feature(false, 'PDF Export (LR & Invoice)'),
                _feature(false, 'Live GPS Tracking'),
                _feature(false, 'KredX Financing'),
              ],
            ),
            const SizedBox(height: 14),
            _planCard(
              context,
              SubscriptionTier.pro,
              'PRO',
              '₹799',
              '/month',
              Colors.blueAccent,
              [
                _feature(true, 'Unlimited trips'),
                _feature(true, 'PDF Export (LR & Invoice)'),
                _feature(true, 'Live GPS Tracking'),
                _feature(true, 'Route auto-calculator'),
                _feature(true, 'Priority support'),
                _feature(false, 'KredX Financing'),
              ],
            ),
            const SizedBox(height: 14),
            _planCard(
              context,
              SubscriptionTier.business,
              'BUSINESS',
              '₹4,999',
              '/month',
              Colors.amber.shade700,
              [
                _feature(true, 'Everything in PRO'),
                _feature(true, 'KredX Invoice Financing'),
                _feature(true, 'Instant advances on invoices'),
                _feature(true, '3 sub-users'),
                _feature(true, 'Up to 50 vehicles'),
                _feature(true, 'Advanced P&L reports'),
                _feature(true, 'Dedicated account manager'),
              ],
              recommended: true,
            ),
            const SizedBox(height: 14),
            _planCard(
              context,
              SubscriptionTier.enterprise,
              'ENTERPRISE',
              '₹9,999',
              '/month',
              const Color(0xFFFB8C00),
              [
                _feature(true, 'Everything in BUSINESS'),
                _feature(true, 'Unlimited vehicles (50+)'),
                _feature(true, '10 staff / sub-user logins'),
                _feature(true, 'Custom company branding'),
                _feature(true, 'White-label PDF reports'),
                _feature(true, 'Priority 24x7 phone support'),
                _feature(true, 'Onboarding & training session'),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'All plans include local data backup. Cancel anytime.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11,
              ),
            ),
            _buildAlaCarteSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAlaCarteSection() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded,
                  color: Color(0xFF8B5CF6), size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Or Build Your Own — Add Only What You Need',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Add-ons work on top of whichever plan you're on above — no need to upgrade your whole tier for one feature.",
            style:
                TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
          const SizedBox(height: 14),
          ...kAlaCarteFeatures.map((f) => CheckboxListTile(
                value: _selectedAddOns.contains(f.id),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _selectedAddOns.add(f.id);
                  } else {
                    _selectedAddOns.remove(f.id);
                  }
                }),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                activeColor: const Color(0xFF8B5CF6),
                title: Text(f.label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
                subtitle: Text(f.description,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B))),
                secondary: Text('+₹${f.monthlyPrice.toStringAsFixed(0)}/mo',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF8B5CF6))),
              )),
          const Divider(height: 24),
          _stepperRow(
            'Extra sub-users',
            '+₹${kAlaCartePerExtraUserPrice.toStringAsFixed(0)}/mo each',
            _extraUsers,
            (v) => setState(() => _extraUsers = v),
          ),
          const SizedBox(height: 8),
          _stepperRow(
            'Extra vehicle capacity (+10 each)',
            '+₹${kAlaCartePerExtraVehicleBlockPrice.toStringAsFixed(0)}/mo each',
            _extraVehicleBlocks,
            (v) => setState(() => _extraVehicleBlocks = v),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Add-ons total',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
                Text('+₹${_addOnsTotal.toStringAsFixed(0)}/mo',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF8B5CF6))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                widget.onAddOnsUpdate(
                    _selectedAddOns, _extraUsers, _extraVehicleBlocks);
                Navigator.pop(context);
              },
              child: const Text(
                'Save Add-ons',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepperRow(
      String label, String priceNote, int value, void Function(int) onChanged) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A))),
              Text(priceNote,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 22),
          color: const Color(0xFF8B5CF6),
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 24,
          child: Text('$value',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 22),
          color: const Color(0xFF8B5CF6),
          onPressed: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

// ================================================================
// SHARED EVENTS SCREEN WIDGET
// ================================================================
class SharedEventsScreen extends StatelessWidget {
  final List<TripLedger> ledgers;
  final UserProfile userProfile;
  final VoidCallback onMarkAllRead;

  const SharedEventsScreen({
    super.key,
    required this.ledgers,
    required this.userProfile,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared Events'),
        backgroundColor: const Color(0xFF0EA5E9),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: onMarkAllRead,
            tooltip: 'Mark all as read',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Events for ${userProfile.companyName}'),
            Text('Total ledgers: ${ledgers.length}'),
            const SizedBox(height: 20),
            const Text('Shared Events Screen - Coming Soon'),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// LANGUAGE SELECTOR WIDGET
// ================================================================
