import 'package:flutter/material.dart';

import '../../chords/domain/chord_library.dart';

class GuitarChordDiagram extends StatelessWidget {
  const GuitarChordDiagram({
    super.key,
    required this.voicing,
    this.leftHanded = false,
    this.size = const Size(112, 132),
  });
  final GuitarVoicing voicing;
  final bool leftHanded;
  final Size size;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '推荐指法，标准定弦，${leftHanded ? '左手显示，' : ''}${voicing.stringDescription}',
    child: ExcludeSemantics(
      child: CustomPaint(
        size: size,
        painter: GuitarChordPainter(
          voicing,
          Theme.of(context).colorScheme.onSurface,
          leftHanded,
        ),
      ),
    ),
  );
}

class GuitarChordPainter extends CustomPainter {
  const GuitarChordPainter(this.voicing, this.color, this.leftHanded);
  final GuitarVoicing voicing;
  final Color color;
  final bool leftHanded;
  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 112;
    canvas.save();
    canvas.scale(unit, size.height / 132);
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    double x(int string) => 22 + (leftHanded ? 5 - string : string) * 15.0;
    void text(String value, Offset at, {double font = 10, Color? ink}) {
      final tp = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(color: ink ?? color, fontSize: font),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }

    const top = 27.0, h = 22.0;
    for (var i = 0; i < 6; i++) {
      canvas.drawLine(Offset(x(i), top), Offset(x(i), top + 4 * h), p);
      final f = voicing.frets[i];
      if (f <= 0) text(f < 0 ? '×' : '○', Offset(x(i), 13), font: 13);
      text('${6 - i}', Offset(x(i), 125), font: 9);
    }
    for (var i = 0; i <= 4; i++) {
      canvas.drawLine(
        Offset(x(0), top + i * h),
        Offset(x(5), top + i * h),
        p..strokeWidth = i == 0 && voicing.baseFret == 1 ? 3 : 1,
      );
    }
    if (voicing.baseFret > 1) {
      text('${voicing.baseFret}', const Offset(8, top + h / 2));
    }
    for (final b in voicing.barres) {
      final y = top + (b[0] - voicing.baseFret + .5) * h;
      final a = x(b[1]), z = x(b[2]);
      canvas.drawLine(
        Offset(a, y),
        Offset(z, y),
        p
          ..strokeWidth = 10
          ..strokeCap = StrokeCap.round,
      );
    }
    p
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.butt;
    for (var i = 0; i < 6; i++) {
      final f = voicing.frets[i];
      if (f > 0) {
        final at = Offset(x(i), top + (f - voicing.baseFret + .5) * h);
        canvas.drawCircle(at, 6, p);
        // Cut out numbers against dark/light theme ink.
        text(
          '${voicing.fingers[i]}',
          at,
          font: 9,
          ink: color.computeLuminance() > .5 ? Colors.black : Colors.white,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GuitarChordPainter oldDelegate) =>
      oldDelegate.voicing != voicing ||
      oldDelegate.color != color ||
      oldDelegate.leftHanded != leftHanded;
}
