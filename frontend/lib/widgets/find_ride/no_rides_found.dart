import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Empty state for the Available Rides screen.
///
/// [filtersHideRides] is true when rides exist for the route but the chosen
/// vehicle / route filters hide all of them.
class NoRidesFound extends StatelessWidget {
  final bool filtersHideRides;
  final String vehicleFilter;
  final VoidCallback? onChangeSearch;
  final VoidCallback? onClearFilters;

  const NoRidesFound({
    super.key,
    this.filtersHideRides = false,
    this.vehicleFilter = 'Any',
    this.onChangeSearch,
    this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = Theme.of(context).textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black);
    final bodyColor = isDark ? Colors.white60 : Colors.grey.shade600;

    final String title;
    final String body;
    if (filtersHideRides) {
      title = vehicleFilter == 'Any' ? 'No rides match these filters' : 'No ${vehicleFilter.toLowerCase()} rides right now';
      body = 'There are rides on this route, just not with the filters you picked. Clear them to see everything.';
    } else {
      title = 'No rides on this route yet';
      body = "Nobody's heading your way right now. Try a different time or a wider walking distance, "
          'or pull down to check again. New rides get posted all the time.';
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 8, 32, 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: CustomPaint(painter: EmptyRoadPainter(isDark: isDark)),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: titleColor),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.45, color: bodyColor),
            ),
            const SizedBox(height: 24),
            if (filtersHideRides)
              _PrimaryButton(label: 'Clear filters', icon: Icons.filter_alt_off_outlined, onPressed: onClearFilters, isDark: isDark)
            else ...[
              _PrimaryButton(label: 'Change search', icon: Icons.tune_rounded, onPressed: onChangeSearch, isDark: isDark),
            ],
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isDark;
  const _PrimaryButton({required this.label, required this.icon, required this.onPressed, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 48,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white : Colors.black,
          foregroundColor: isDark ? Colors.black : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      ),
    );
  }
}

/// A quiet, empty road winding up to a destination pin: sky, sun or moon,
/// clouds and hills inside a round frame. Colours follow the app theme.
class EmptyRoadPainter extends CustomPainter {
  final bool isDark;
  EmptyRoadPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = math.min(w, h) / 2;

    final sky1 = isDark ? const Color(0xFF1B2433) : const Color(0xFFEAF3FF);
    final sky2 = isDark ? const Color(0xFF26324A) : const Color(0xFFF7FAFF);
    final hillBack = isDark ? const Color(0xFF2E3B33) : const Color(0xFFCFE8D5);
    final hillFront = isDark ? const Color(0xFF34473A) : const Color(0xFFB5DDBF);
    final road = isDark ? const Color(0xFF4A4F57) : const Color(0xFF5B6270);
    final roadEdge = isDark ? const Color(0xFF5E646D) : const Color(0xFF747C8A);
    final dash = isDark ? const Color(0xFFE8D27A) : Colors.white;
    final cloud = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.white;

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));

    // Sky
    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [sky1, sky2]).createShader(Offset.zero & size),
    );

    // Sun or moon
    final orb = Offset(w * 0.28, h * 0.28);
    if (isDark) {
      canvas.drawCircle(orb, w * 0.075, Paint()..color = const Color(0xFFF2E6B8));
      canvas.drawCircle(orb + Offset(w * 0.035, -h * 0.02), w * 0.065, Paint()..color = sky1);
      final star = Paint()..color = Colors.white.withValues(alpha: 0.7);
      for (final p in [Offset(w * 0.62, h * 0.18), Offset(w * 0.74, h * 0.30), Offset(w * 0.46, h * 0.12)]) {
        canvas.drawCircle(p, 1.4, star);
      }
    } else {
      canvas.drawCircle(orb, w * 0.11, Paint()..color = const Color(0xFFFFE7A3).withValues(alpha: 0.6));
      canvas.drawCircle(orb, w * 0.075, Paint()..color = const Color(0xFFFFD166));
    }

    // Clouds
    void drawCloud(Offset c, double s) {
      final p = Paint()..color = cloud;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: 46 * s, height: 14 * s), Radius.circular(7 * s)), p);
      canvas.drawCircle(c + Offset(-7 * s, -6 * s), 9 * s, p);
      canvas.drawCircle(c + Offset(6 * s, -8 * s), 11 * s, p);
    }
    drawCloud(Offset(w * 0.70, h * 0.24), w / 200);
    drawCloud(Offset(w * 0.52, h * 0.38), w / 300);

    // Hills
    final back = Path()
      ..moveTo(0, h * 0.62)
      ..quadraticBezierTo(w * 0.25, h * 0.48, w * 0.55, h * 0.60)
      ..quadraticBezierTo(w * 0.80, h * 0.50, w, h * 0.58)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(back, Paint()..color = hillBack);
    final front = Path()
      ..moveTo(0, h * 0.72)
      ..quadraticBezierTo(w * 0.35, h * 0.62, w * 0.65, h * 0.70)
      ..quadraticBezierTo(w * 0.85, h * 0.66, w, h * 0.70)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(front, Paint()..color = hillFront);

    // Winding road from the bottom up to the horizon
    final centerLine = Path()
      ..moveTo(w * 0.42, h * 1.02)
      ..cubicTo(w * 0.30, h * 0.86, w * 0.78, h * 0.78, w * 0.62, h * 0.60);
    canvas.drawPath(
      centerLine,
      Paint()
        ..color = roadEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.17
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      centerLine,
      Paint()
        ..color = road
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.14
        ..strokeCap = StrokeCap.round,
    );

    // Dashed centre line
    final dashPaint = Paint()
      ..color = dash
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.012
      ..strokeCap = StrokeCap.round;
    for (final metric in centerLine.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final len = math.min(w * 0.04, metric.length - d);
        canvas.drawPath(metric.extractPath(d, d + len), dashPaint);
        d += w * 0.075;
      }
    }

    canvas.restore();

    // Destination pin standing at the end of the road (allowed past the frame)
    final pinTip = Offset(w * 0.62, h * 0.60);
    final pinR = w * 0.075;
    final pinCenter = pinTip - Offset(0, pinR * 2.0);
    canvas.drawOval(
      Rect.fromCenter(center: pinTip + const Offset(0, 2), width: pinR * 1.3, height: pinR * 0.4),
      Paint()..color = Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
    );
    final pin = Path()
      ..moveTo(pinTip.dx, pinTip.dy)
      ..quadraticBezierTo(pinCenter.dx - pinR * 1.05, pinCenter.dy + pinR * 0.9, pinCenter.dx - pinR, pinCenter.dy)
      ..arcToPoint(Offset(pinCenter.dx + pinR, pinCenter.dy), radius: Radius.circular(pinR))
      ..quadraticBezierTo(pinCenter.dx + pinR * 1.05, pinCenter.dy + pinR * 0.9, pinTip.dx, pinTip.dy)
      ..close();
    canvas.drawPath(pin, Paint()..color = const Color(0xFFE5484D));
    canvas.drawCircle(pinCenter, pinR * 0.42, Paint()..color = Colors.white);

    // Soft ring around the frame
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
    );
  }

  @override
  bool shouldRepaint(covariant EmptyRoadPainter oldDelegate) => oldDelegate.isDark != isDark;
}
