import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Logo MifBudget : un « m » fait de deux arches (vert et orange) qui se
/// chevauchent, sur un carré arrondi vert profond. Mêmes formes que
/// `tool/logo/icon.svg` (repère de 1024).
class MifLogo extends StatelessWidget {
  const MifLogo({super.key, this.size = 72});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'MifBudget',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: const CustomPaint(painter: _LogoPainter()),
    ),
  );
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  static Path _arch(double left) {
    const r = 105.0;
    return Path()
      ..moveTo(left, 715)
      ..lineTo(left, 450)
      ..arcTo(
        Rect.fromCircle(center: Offset(left + r, 450), radius: r),
        math.pi,
        math.pi,
        false,
      )
      ..lineTo(left + 2 * r, 715);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 1024);
    const full = Rect.fromLTWH(0, 0, 1024, 1024);
    canvas.drawRRect(
      RRect.fromRectAndRadius(full, const Radius.circular(225)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B2A1F), Color(0xFF1F6B4F)],
        ).createShader(full),
    );
    canvas
      ..translate(512, 540)
      ..scale(0.9)
      ..translate(-512, -540);
    // Dégradé vertical sur la hauteur des arches.
    const span = Rect.fromLTRB(0, 345, 1024, 715);
    Paint stroke(List<Color> colors) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 116
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ).createShader(span);
    canvas.drawPath(
      _arch(287),
      stroke(const [Color(0xFF6FF0B8), Color(0xFF22A06F)]),
    );
    canvas.drawPath(
      _arch(527),
      stroke(const [Color(0xFFFFB877), Color(0xFFE0622E)])
        ..blendMode = BlendMode.screen,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) => false;
}
