import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 渦巻くポータルに吸い込まれるような画面遷移（スタートボタン → テーマ選択）。
///   前半: 画面の真ん中から黒い虚空が広がり、煙と塵を渦巻かせながら画面を覆う
///   後半: 渦の中心から次の画面が円形に広がり、回転しながらズームして現れる
Widget portalTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final t = animation.value;
      // 渦が広がる（前半: 0〜0.5）
      final grow = Curves.easeInCubic.transform((t / 0.5).clamp(0.0, 1.0));
      // 画面が完全に黒くなった後に、次の画面が現れる（後半: 0.58〜1）。
      // 間を空けることで、元のホーム画面が端から見えてしまう瞬間をなくす
      final blackout = t >= 0.5;
      final reveal = Curves.easeOutCubic.transform(((t - 0.58) / 0.42).clamp(0.0, 1.0));

      return LayoutBuilder(
        builder: (context, c) {
          // 画面の隅まで届く半径
          final cover = math.sqrt(c.maxWidth * c.maxWidth + c.maxHeight * c.maxHeight) / 2 * 1.05;

          return Stack(
            fit: StackFit.expand,
            children: [
              // 真っ暗になったら、全面を黒で塗りつぶしたままにする（ホーム画面を見せない）
              if (blackout) const ColoredBox(color: Colors.black),
              if (reveal < 1)
                IgnorePointer(
                  child: Opacity(
                    opacity: 1 - reveal,
                    child: CustomPaint(
                      painter: _VortexPainter(radius: grow * cover, spin: t * math.pi * 7),
                    ),
                  ),
                ),
              if (reveal > 0)
                ClipPath(
                  clipper: _CircleClipper(reveal * cover),
                  child: Transform.rotate(
                    angle: (1 - reveal) * -0.9,
                    child: Transform.scale(scale: 0.55 + 0.45 * reveal, child: child),
                  ),
                ),
            ],
          );
        },
      );
    },
  );
}

/// 黒い虚空の渦。青や白い縞は使わず、不気味な効果だけ:
///   - 縁がぼやけた真っ黒な穴
///   - 中でゆっくり渦を巻く、かすかな灰色の煙
///   - 縁でちらつく、ごく薄い光
///   - 吸い込まれていく塵の粒
class _VortexPainter extends CustomPainter {
  _VortexPainter({required this.radius, required this.spin});

  final double radius;

  /// 回転角（ラジアン）。時間とともに増える
  final double spin;

  @override
  void paint(Canvas canvas, Size size) {
    if (radius <= 0) return;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);

    // 黒い穴（縁はぼかして周りに溶かす）
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.black, Colors.black, Colors.black.withValues(alpha: 0.85), Colors.black.withValues(alpha: 0)],
          stops: const [0.0, 0.7, 0.9, 1.0],
        ).createShader(rect),
    );

    // かすかな灰色の煙（太くぼかした渦巻き）
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spin * 0.35);
    const arms = 3;
    for (var a = 0; a < arms; a++) {
      final path = Path();
      for (var i = 0; i <= 40; i++) {
        final k = i / 40;
        final r = radius * (0.15 + 0.8 * k);
        final angle = a * 2 * math.pi / arms + k * math.pi * 1.4;
        final p = Offset(math.cos(angle) * r, math.sin(angle) * r);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.14
          ..strokeCap = StrokeCap.round
          ..color = const Color(0xFF9A9A9A).withValues(alpha: 0.07)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.06),
      );
    }
    canvas.restore();

    // 白い渦巻きの線（細く、中心へ向かって薄くなる）
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(spin);
    const lines = 7;
    for (var a = 0; a < lines; a++) {
      final path = Path();
      for (var i = 0; i <= 50; i++) {
        final k = i / 50;
        final r = radius * (0.05 + 0.9 * k);
        final angle = a * 2 * math.pi / lines + k * math.pi * 1.9;
        final p = Offset(math.cos(angle) * r, math.sin(angle) * r);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: 0.45),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.6, 1.0],
          ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
      );
    }
    canvas.restore();

    // 吸い込まれる塵（外から中心へ。中心に近いほど速く回り、消えていく）
    final rnd = math.Random(7);
    for (var i = 0; i < 48; i++) {
      final start = rnd.nextDouble() * 2 * math.pi;
      final phase = rnd.nextDouble();
      final f = (phase + spin / (math.pi * 2) * 0.6) % 1.0; // 0 → 1 で外から中心へ
      final r = radius * 0.95 * (1 - f);
      final angle = start + f * f * math.pi * 3;
      final p = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      canvas.drawCircle(
        p,
        1.2 + (1 - f) * 1.3,
        Paint()..color = Colors.white.withValues(alpha: 0.35 * (1 - f) * (1 - f)),
      );
    }

    // 縁のちらつく薄い光
    final flicker = 0.06 + 0.04 * math.sin(spin * 3.1);
    canvas.drawCircle(
      center,
      radius * 0.88,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius * 0.04
        ..color = Colors.white.withValues(alpha: flicker)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.05),
    );
  }

  @override
  bool shouldRepaint(_VortexPainter old) => old.radius != radius || old.spin != spin;
}

class _CircleClipper extends CustomClipper<Path> {
  const _CircleClipper(this.radius);

  final double radius;

  @override
  Path getClip(Size size) => Path()..addOval(Rect.fromCircle(center: size.center(Offset.zero), radius: radius));

  @override
  bool shouldReclip(_CircleClipper old) => old.radius != radius;
}
