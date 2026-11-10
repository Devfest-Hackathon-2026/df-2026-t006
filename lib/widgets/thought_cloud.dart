import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 問いを載せる、白いもくもくの雲（考えごとの吹き出し）。
/// 下に小さな丸が2つ続いて、「頭の中の考え」に見えるようにする。
class ThoughtCloud extends StatelessWidget {
  const ThoughtCloud({super.key, required this.child, this.color = AppColors.ink, this.glow});

  final Widget child;

  /// まわりの光（反論の雲は赤く不気味に光る）
  final Color? glow;

  /// 雲の色（変わる時はなめらかに）。反論の時は灰色
  final Color color;

  /// 雲のふちの、もこもこ1つの半径
  static const bump = 15.0;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: color),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      builder: (context, c, _) => _build(c ?? color),
    );
  }

  Widget _build(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          painter: _CloudPainter(color, glow),
          child: Container(
            // どのページでも同じ幅にして、めくった時に雲の大きさが変わらないようにする
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(bump + 10, bump + 8, bump + 10, bump + 8),
            child: child,
          ),
        ),
        // 考えごとの小さな丸
        Padding(
          padding: const EdgeInsets.only(left: 34, top: 2),
          child: _Puff(size: 16, color: color, glow: glow),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 22, top: 3),
          child: _Puff(size: 9, color: color, glow: glow),
        ),
      ],
    );
  }
}

class _Puff extends StatelessWidget {
  const _Puff({required this.size, required this.color, this.glow});

  final Color? glow;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          const BoxShadow(color: Color(0x88000000), blurRadius: 10, offset: Offset(0, 3)),
          if (glow != null) BoxShadow(color: glow!.withValues(alpha: 0.45), blurRadius: 10),
        ],
      ),
    );
  }
}

class _CloudPainter extends CustomPainter {
  const _CloudPainter(this.color, this.glow);

  final Color color;
  final Color? glow;

  /// 角丸の四角のまわりに、大きさが少しずつ違う丸を並べて、もこもこにする
  Path _cloud(Size size) {
    const r = ThoughtCloud.bump;
    final inner = Rect.fromLTRB(r, r, size.width - r, size.height - r);
    final p = Path()..addRRect(RRect.fromRectAndRadius(inner, const Radius.circular(r)));

    void edge(Offset a, Offset b, int seed) {
      final len = (b - a).distance;
      final n = math.max(2, (len / (r * 1.5)).round());
      for (var i = 0; i <= n; i++) {
        final c = Offset.lerp(a, b, i / n)!;
        // 丸の大きさを少しずつ変えて、手描きの雲っぽく
        final rr = r * (1.0 + 0.22 * math.sin((i + seed) * 2.3));
        p.addOval(Rect.fromCircle(center: c, radius: rr));
      }
    }

    edge(inner.topLeft, inner.topRight, 0);
    edge(inner.topRight, inner.bottomRight, 3);
    edge(inner.bottomRight, inner.bottomLeft, 5);
    edge(inner.bottomLeft, inner.topLeft, 7);
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _cloud(size);
    // 影で浮いて見えるように
    canvas.drawShadow(path, Colors.black, 10, false);
    // 赤い不気味な光（にじませて、ふちから漏れるように）
    final g = glow;
    if (g != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = g.withValues(alpha: 0.55)
          ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 14),
      );
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _CloudPainter oldDelegate) => oldDelegate.color != color || oldDelegate.glow != glow;
}
