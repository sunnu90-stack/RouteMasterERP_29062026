// ============================================================
// painters.dart  —  part of liquid_logistics main library
// Auto-extracted from main_v23_8.dart (original lines 26965-27264)
// DO NOT add imports here — all imports live in main.dart
// ============================================================
part of 'package:liquid_logistics/main.dart';

class LogisticsBackdropPainter extends CustomPainter {
  final bool admin;
  final List<Color>? gradientColors;
  const LogisticsBackdropPainter({this.admin = false, this.gradientColors});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final resolvedColors = gradientColors ??
        (admin
            ? const [Color(0xFFEFF6FF), Color(0xFFFDF7ED), Color(0xFFF0FDFA)]
            : const [Color(0xFFF6FAFF), Color(0xFFEFF6FF), Color(0xFFFFF7ED)]);
    final bg = Paint()
      ..shader = LinearGradient(
        colors: resolvedColors.length >= 2
            ? resolvedColors
            : [resolvedColors.first, resolvedColors.first],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, bg);

    final grid = Paint()
      ..color = const Color(0xFF0EA5E9).withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (double x = 0; x < w; x += 42) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), grid);
    }
    for (double y = 0; y < h; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    void softCircle(double x, double y, double r, Color c, double opacity) {
      canvas.drawCircle(
          Offset(x, y),
          r,
          Paint()
            ..shader = RadialGradient(colors: [
              c.withValues(alpha: opacity),
              Colors.transparent
            ]).createShader(Rect.fromCircle(center: Offset(x, y), radius: r)));
    }

    softCircle(w * .12, h * .18, 170, const Color(0xFF0EA5E9), .18);
    softCircle(w * .88, h * .22, 150, const Color(0xFFF97316), .16);
    softCircle(w * .72, h * .82, 190, const Color(0xFF10B981), .13);

    final routePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF0EA5E9).withValues(alpha: .25);
    final route = Path()
      ..moveTo(-20, h * .68)
      ..cubicTo(w * .28, h * .45, w * .45, h * .88, w + 20, h * .55);
    canvas.drawPath(route, routePaint);

    final highway = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF0F172A).withValues(alpha: .06);
    canvas.drawLine(Offset(-20, h * .33), Offset(w + 20, h * .18), highway);
    canvas.drawLine(Offset(w * .2, h + 20), Offset(w * .9, -20), highway);

    void pin(double x, double y, Color color) {
      canvas.drawCircle(Offset(x, y), 7, Paint()..color = color);
      canvas.drawCircle(
          Offset(x, y), 18, Paint()..color = color.withValues(alpha: .15));
    }

    pin(w * .22, h * .62, const Color(0xFF10B981));
    pin(w * .55, h * .48, const Color(0xFFF59E0B));
    pin(w * .82, h * .56, const Color(0xFFF97316));

    final truck = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: .08);
    final truckY = h * .78;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * .06, truckY, w * .26, 34),
            const Radius.circular(6)),
        truck);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(w * .29, truckY + 8, w * .08, 26),
            const Radius.circular(5)),
        truck);
    canvas.drawCircle(Offset(w * .12, truckY + 36), 8, truck);
    canvas.drawCircle(Offset(w * .31, truckY + 36), 8, truck);

    final chevron = Paint()
      ..color = const Color(0xFFF97316).withValues(alpha: .18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (double x = w * .48; x < w; x += 38) {
      canvas.drawLine(Offset(x, h * .12), Offset(x + 14, h * .18), chevron);
      canvas.drawLine(Offset(x + 14, h * .18), Offset(x, h * .24), chevron);
    }
  }

  @override
  bool shouldRepaint(covariant LogisticsBackdropPainter oldDelegate) =>
      oldDelegate.admin != admin ||
      !_listEquals(oldDelegate.gradientColors, gradientColors);
}

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class NativePieChartPainter extends CustomPainter {
  final double revenue, expense;
  const NativePieChartPainter({required this.revenue, required this.expense});
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 8;
    final total = revenue > 0 ? revenue : 1;
    final expAngle =
        ((expense / total).clamp(0.0, 1.0) as num).toDouble() * 2 * math.pi;
    final shadowPaint = Paint()
      ..color = const Color(0x330F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(c, r, shadowPaint);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16);
    // Base ring
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = const Color(0xFFE2E8F0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12);
    // Expense arc
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        expAngle,
        false,
        Paint()
          ..color = const Color(0xFFF97316)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round);
    // Profit arc
    final profitAngle = math.max(0.0, 2 * math.pi - expAngle);
    canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2 + expAngle,
        profitAngle,
        false,
        Paint()
          ..color = const Color(0xFF10B981)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round);
    canvas.drawCircle(
        c,
        r - 18,
        Paint()
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.fill);
    canvas.drawCircle(
        c,
        4,
        Paint()
          ..color = const Color(0xFF0EA5E9)
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_) => true;
}

// Alias for backward compatibility
// ignore: unused_element
class _SplashBgPainter extends _RouteBgPainter {}

class _RouteBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    //
    void orb(double cx, double cy, double r, Color c, double opacity) {
      final p = Paint()..style = PaintingStyle.fill;
      p.shader = RadialGradient(
              colors: [c.withValues(alpha: opacity), Colors.transparent])
          .createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      canvas.drawCircle(Offset(cx, cy), r, p);
    }

    orb(w * 0.08, h * 0.12, 180, const Color(0xFF0EA5E9), 0.15);
    orb(w * 0.92, h * 0.38, 220, const Color(0xFFF59E0B), 0.12);
    orb(w * 0.45, h * 0.80, 160, const Color(0xFF0EA5E9), 0.06);
    orb(w * 0.78, h * 0.08, 120, const Color(0xFFF59E0B), 0.10);
    orb(w * 0.2, h * 0.65, 140, const Color(0xFF0EA5E9), 0.10);

    //
    final dotP = Paint()
      ..color = const Color(0xFF0EA5E9).withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    for (double x = 0; x < w; x += 30) {
      for (double y = 0; y < h; y += 30) {
        canvas.drawCircle(Offset(x, y), 1.0, dotP);
      }
    }

    //
    final roadGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    final road = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    // ignore: unused_local_variable
    final dash = Paint() // used for dash line rendering;
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFFF6FAFF).withValues(alpha: 0.08);

    // Diagonal highway 1 - top-left to mid-right
    roadGlow.color = const Color(0xFF0EA5E9).withValues(alpha: 0.12);
    canvas.drawLine(Offset(0, h * 0.3), Offset(w, h * 0.55), roadGlow);
    road.color = const Color(0xFF0EA5E9).withValues(alpha: 0.06);
    canvas.drawLine(Offset(0, h * 0.3), Offset(w, h * 0.55), road);

    // Diagonal highway 2
    roadGlow.color = const Color(0xFFF59E0B).withValues(alpha: 0.10);
    canvas.drawLine(Offset(w * 0.2, 0), Offset(w * 0.85, h), roadGlow);
    road.color = const Color(0xFF0EA5E9).withValues(alpha: 0.04);
    canvas.drawLine(Offset(w * 0.2, 0), Offset(w * 0.85, h), road);

    // Curved route arc
    final arc = Path()
      ..moveTo(0, h * 0.7)
      ..cubicTo(w * 0.3, h * 0.4, w * 0.6, h * 0.8, w, h * 0.3);
    roadGlow.color = const Color(0xFF0EA5E9).withValues(alpha: 0.08);
    roadGlow.strokeWidth = 6;
    canvas.drawPath(arc, roadGlow);
    road.color = const Color(0xFF0EA5E9).withValues(alpha: 0.05);
    road.strokeWidth = 1.5;
    canvas.drawPath(arc, road);

    // Location pins glow
    void pin(double x, double y, Color c) {
      canvas.drawCircle(
          Offset(x, y),
          6,
          Paint()
            ..color = c.withValues(alpha: 0.8)
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          Offset(x, y),
          12,
          Paint()
            ..color = c.withValues(alpha: 0.2)
            ..style = PaintingStyle.fill);
      canvas.drawCircle(
          Offset(x, y),
          20,
          Paint()
            ..color = c.withValues(alpha: 0.07)
            ..style = PaintingStyle.fill);
    }

    pin(w * 0.18, h * 0.32, const Color(0xFF0EA5E9));
    pin(w * 0.82, h * 0.52, const Color(0xFFEF4444));
    pin(w * 0.5, h * 0.18, const Color(0xFFF59E0B));

    // Moving truck dots on highway
    for (int i = 0; i < 4; i++) {
      final t = (i / 4.0);
      final tx = w * 0.1 + w * 0.7 * t;
      final ty = h * 0.31 + (h * 0.55 - h * 0.31) * t;
      canvas.drawCircle(
          Offset(tx, ty),
          3,
          Paint()
            ..color = const Color(0xFFF6FAFF).withValues(alpha: 0.25)
            ..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
