// ══════════════════════════════════════════════════════════════
// lib/widgets/kenexpress_logo.dart
// Logo KenExpress — widget réutilisable (rouge + bleu)
// Usage :
//   KenExpressLogo()              → taille normale (280×140)
//   KenExpressLogo(scale: 0.6)    → petit (appbar)
//   KenExpressLogo(scale: 1.4)    → grand (splash / auth)
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

class KenExpressLogo extends StatelessWidget {
  final double scale;
  const KenExpressLogo({super.key, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final w = 280.0 * scale;
    final h = 140.0 * scale;
    return SizedBox(
      width: w,
      height: h,
      child: CustomPaint(painter: _LogoPainter(scale: scale)),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final double scale;
  const _LogoPainter({required this.scale});

  static const _red  = Color(0xFFE53935);
  static const _blue = Color(0xFF1E88E5);
  static const _bg   = Color(0xFFEEF4FF);
  static const _grey = Color(0xFF888888);

  @override
  void paint(Canvas canvas, Size size) {
    final s = scale;

    // ── Fond pilule ──
    final pillPaint = Paint()..color = _bg;
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 8 * s, 280 * s, 100 * s),
      Radius.circular(50 * s),
    );
    canvas.drawRRect(pillRect, pillPaint);

    // ── Panier (dessiné à la main) ──
    _drawBasket(canvas, s);

    // ── KEN ──
    _drawText(
      canvas,
      text: 'KEN',
      x: 95 * s,
      y: 72 * s,
      fontSize: 48 * s,
      fontWeight: FontWeight.w900,
      color: _red,
      letterSpacing: -1,
    );

    // ── EXPRESS ──
    _drawText(
      canvas,
      text: 'EXPRESS',
      x: 95 * s,
      y: 98 * s,
      fontSize: 20 * s,
      fontWeight: FontWeight.w700,
      color: _blue,
      letterSpacing: 3,
    );

    // ── Badge check bleu ──
    _drawBadge(canvas, s);

    // ── Séparateur ──
    final sepPaint = Paint()
      ..color = const Color(0xFFDDE3EF)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(40 * s, 114 * s),
      Offset(240 * s, 114 * s),
      sepPaint,
    );

    // ── Tagline ligne 1 : Achat · Vente · Livraison ──
    _drawTagline(canvas, s);

    // ── Tagline ligne 2 ──
    _drawText(
      canvas,
      text: 'au Burkina Faso',
      x: 140 * s,
      y: 133 * s,
      fontSize: 9 * s,
      fontWeight: FontWeight.w400,
      color: _grey,
      letterSpacing: 1.5,
      centered: true,
    );

    // ── 3 points déco ──
    final dotR = Paint()..color = _red;
    final dotB = Paint()..color = _blue;
    canvas.drawCircle(Offset(115 * s, 139 * s), 2 * s, dotR);
    canvas.drawCircle(Offset(140 * s, 139 * s), 2 * s, dotB);
    canvas.drawCircle(Offset(165 * s, 139 * s), 2 * s, dotR);
  }

  void _drawBasket(Canvas canvas, double s) {
    final paint = Paint()
      ..color = _red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final ox = 18.0 * s;
    final oy = 22.0 * s;

    // Anse
    final ansePath = Path()
      ..moveTo(ox + 10 * s, oy + 12 * s)
      ..quadraticBezierTo(ox + 10 * s, oy + 2 * s, ox + 20 * s, oy + 2 * s)
      ..quadraticBezierTo(ox + 30 * s, oy + 2 * s, ox + 30 * s, oy + 12 * s);
    canvas.drawPath(ansePath, paint);

    // Corps
    final bodyPaint = Paint()
      ..color = _red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(ox + 2 * s, oy + 18 * s, 36 * s, 24 * s),
      Radius.circular(4 * s),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Lignes verticales intérieures
    final linePaint = Paint()
      ..color = _red.withValues(alpha: 0.35)
      ..strokeWidth = 1.5 * s;
    canvas.drawLine(
        Offset(ox + 14 * s, oy + 18 * s), Offset(ox + 14 * s, oy + 42 * s), linePaint);
    canvas.drawLine(
        Offset(ox + 26 * s, oy + 18 * s), Offset(ox + 26 * s, oy + 42 * s), linePaint);

    // Barre du haut
    final topPaint = Paint()
      ..color = _red
      ..strokeWidth = 2.5 * s
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(ox, oy + 18 * s), Offset(ox + 40 * s, oy + 18 * s), topPaint);

    // Roues
    final wheelPaint = Paint()..color = _red;
    canvas.drawCircle(Offset(ox + 12 * s, oy + 49 * s), 4 * s, wheelPaint);
    canvas.drawCircle(Offset(ox + 28 * s, oy + 49 * s), 4 * s, wheelPaint);
  }

  void _drawBadge(Canvas canvas, double s) {
    final bgPaint = Paint()..color = _blue;
    canvas.drawCircle(Offset(248 * s, 32 * s), 9 * s, bgPaint);

    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final checkPath = Path()
      ..moveTo(244 * s, 32 * s)
      ..lineTo(247 * s, 35 * s)
      ..lineTo(252 * s, 28 * s);
    canvas.drawPath(checkPath, checkPaint);
  }

  void _drawTagline(Canvas canvas, double s) {
    // "Achat" en rouge
    _drawText(canvas,
        text: 'Achat',
        x: 68 * s, y: 122 * s,
        fontSize: 9.5 * s,
        fontWeight: FontWeight.w700,
        color: _red,
        letterSpacing: 0.5);

    // "·" gris
    _drawText(canvas,
        text: '·',
        x: 102 * s, y: 122 * s,
        fontSize: 9.5 * s,
        fontWeight: FontWeight.w400,
        color: _grey);

    // "Vente" en bleu
    _drawText(canvas,
        text: 'Vente',
        x: 112 * s, y: 122 * s,
        fontSize: 9.5 * s,
        fontWeight: FontWeight.w700,
        color: _blue,
        letterSpacing: 0.5);

    // "·" gris
    _drawText(canvas,
        text: '·',
        x: 148 * s, y: 122 * s,
        fontSize: 9.5 * s,
        fontWeight: FontWeight.w400,
        color: _grey);

    // "Livraison" en rouge
    _drawText(canvas,
        text: 'Livraison',
        x: 158 * s, y: 122 * s,
        fontSize: 9.5 * s,
        fontWeight: FontWeight.w700,
        color: _red,
        letterSpacing: 0.5);
  }

  void _drawText(
      Canvas canvas, {
        required String text,
        required double x,
        required double y,
        required double fontSize,
        required FontWeight fontWeight,
        required Color color,
        double letterSpacing = 0,
        bool centered = false,
      }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          letterSpacing: letterSpacing,
          fontFamily: 'Arial',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final dx = centered ? x - tp.width / 2 : x;
    tp.paint(canvas, Offset(dx, y - tp.height));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}