import 'package:material_ui/material_ui.dart';
import 'package:sax_buddy/features/sax/domain/entities/sax_models.dart';

class SaxFingeringDiagram extends StatelessWidget {
  const SaxFingeringDiagram({
    required this.pressedKeys,
    this.height = 360,
    super.key,
  });

  final Set<SaxKeyId> pressedKeys;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      height: height,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: CustomPaint(
        painter: _SaxKeyDiagramPainter(
          pressedKeys: pressedKeys,
          activeColor: const Color(0xFFD97706),
          activeStroke: const Color(0xFFFBBF24),
          inactiveFill: theme.brightness == Brightness.dark
              ? const Color(0xFF1E293B)
              : const Color(0xFFF1F5F9),
          inactiveStroke: cs.outlineVariant,
          labelColor: cs.onSurface,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _SaxKeyDiagramPainter extends CustomPainter {
  const _SaxKeyDiagramPainter({
    required this.pressedKeys,
    required this.activeColor,
    required this.activeStroke,
    required this.inactiveFill,
    required this.inactiveStroke,
    required this.labelColor,
  });

  final Set<SaxKeyId> pressedKeys;
  final Color activeColor;
  final Color activeStroke;
  final Color inactiveFill;
  final Color inactiveStroke;
  final Color labelColor;

  void _drawKey(
    Canvas canvas, {
    required SaxKeyId id,
    required Rect rect,
    bool isCircle = false,
  }) {
    final pressed = pressedKeys.contains(id);
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = pressed ? activeColor : inactiveFill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = pressed ? 2.4 : 1.5
      ..color = pressed ? activeStroke : inactiveStroke;

    if (pressed) {
      final glowPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = activeColor.withValues(alpha: 0.22);
      if (isCircle) {
        canvas.drawOval(rect.inflate(4), glowPaint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(3), const Radius.circular(10)),
          glowPaint,
        );
      }
    }

    if (isCircle) {
      canvas.drawOval(rect, fillPaint);
      canvas.drawOval(rect, strokePaint);
    } else {
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
      canvas.drawRRect(rrect, fillPaint);
      canvas.drawRRect(rrect, strokePaint);
    }

    final tp = TextPainter(
      text: TextSpan(
        text: id.shortLabel,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: pressed ? Colors.white : labelColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        rect.center.dx - tp.width / 2,
        rect.center.dy - tp.height / 2,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width * 0.5;
    final h = size.height;

    // Central brass body spine line
    final spinePaint = Paint()
      ..color = inactiveStroke.withValues(alpha: 0.45)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(cx, h * 0.06), Offset(cx, h * 0.94), spinePaint);
    canvas.drawLine(
      Offset(cx - 48, h * 0.51),
      Offset(cx + 48, h * 0.51),
      spinePaint..strokeWidth = 1.5,
    );

    Rect box(double nx, double ny, double w, double ht) => Rect.fromCenter(
          center: Offset(cx + nx, h * ny),
          width: w,
          height: ht,
        );

    // Octave key (left thumb)
    _drawKey(canvas, id: SaxKeyId.oct, rect: box(-52, 0.14, 34, 24));

    // Front F + Left Stack (1, Bis, 2, 3)
    _drawKey(canvas, id: SaxKeyId.frontF, rect: box(0, 0.09, 32, 20));
    _drawKey(canvas, id: SaxKeyId.lh1, rect: box(0, 0.19, 36, 36), isCircle: true);
    _drawKey(canvas, id: SaxKeyId.bis, rect: box(0, 0.275, 24, 18), isCircle: true);
    _drawKey(canvas, id: SaxKeyId.lh2, rect: box(0, 0.355, 36, 36), isCircle: true);
    _drawKey(canvas, id: SaxKeyId.lh3, rect: box(0, 0.45, 36, 36), isCircle: true);

    // Left Palm Keys (D, Eb, F) on top-right of LH
    _drawKey(canvas, id: SaxKeyId.palmF, rect: box(52, 0.14, 30, 20));
    _drawKey(canvas, id: SaxKeyId.palmEb, rect: box(62, 0.22, 30, 20));
    _drawKey(canvas, id: SaxKeyId.palmD, rect: box(52, 0.30, 30, 20));

    // Left Pinky Table (G#, Low C#, Low B, Low Bb)
    _drawKey(canvas, id: SaxKeyId.gSharp, rect: box(58, 0.39, 34, 19));
    _drawKey(canvas, id: SaxKeyId.lowB, rect: box(46, 0.45, 24, 19));
    _drawKey(canvas, id: SaxKeyId.lowCSharp, rect: box(72, 0.45, 24, 19));
    _drawKey(canvas, id: SaxKeyId.lowBb, rect: box(58, 0.51, 36, 19));

    // Right Stack (4, 5, 6)
    _drawKey(canvas, id: SaxKeyId.rh4, rect: box(0, 0.59, 36, 36), isCircle: true);
    _drawKey(canvas, id: SaxKeyId.rh5, rect: box(0, 0.70, 36, 36), isCircle: true);
    _drawKey(canvas, id: SaxKeyId.rh6, rect: box(0, 0.81, 36, 36), isCircle: true);

    // Right Side Keys (Te, Tc, Ta) on left side of diagram
    _drawKey(canvas, id: SaxKeyId.sideTe, rect: box(-54, 0.56, 32, 19));
    _drawKey(canvas, id: SaxKeyId.sideTc, rect: box(-54, 0.63, 32, 19));
    _drawKey(canvas, id: SaxKeyId.sideTa, rect: box(-54, 0.70, 32, 19));

    // High F# & Fork F# trill keys
    _drawKey(canvas, id: SaxKeyId.sideFSharp, rect: box(-54, 0.78, 34, 19));
    _drawKey(canvas, id: SaxKeyId.highFSharp, rect: box(52, 0.68, 34, 20));

    // Right Pinky Rollers (Low Eb, Low C)
    _drawKey(canvas, id: SaxKeyId.lowEb, rect: box(-46, 0.87, 36, 20));
    _drawKey(canvas, id: SaxKeyId.lowC, rect: box(-46, 0.94, 36, 20));
  }

  @override
  bool shouldRepaint(covariant _SaxKeyDiagramPainter oldDelegate) {
    return oldDelegate.pressedKeys != pressedKeys ||
        oldDelegate.labelColor != labelColor;
  }
}
