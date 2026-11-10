import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ひたちゃん（脳の生きもの）。古い版画のような線で描く「考える脳」。
/// ロダンの「考える人」のように、こぶしにあごをのせて考えている。
///   0: しぼんで灰色。まぶたが重く、眉は下がり、汗
///   1〜3: だんだん色づき、大きくなり、目つきがしっかりする
///   4: 象牙色に輝き、月桂冠（ローマの冠）をかぶる
class Hitachan extends StatefulWidget {
  const Hitachan({
    super.key,
    required this.stage,
    this.size = 200,
    this.animate = true,
    this.fade = 0,
    this.lively = false,
  });

  /// 0〜4
  final int stage;
  final double size;

  /// ゆっくり呼吸するように動く
  final bool animate;

  /// 0〜1: 消えかけ（プロローグ用。薄く・小さくなる）
  final double fade;

  /// いきいき動く（ときどき跳ねる・まばたき・汗がたれる）。押すとぴょんと跳ねる
  final bool lively;

  @override
  State<Hitachan> createState() => _HitachanState();
}

class _HitachanState extends State<Hitachan> with TickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  /// いきいき動く時の1周（跳ねる → 着地でつぶれる → まばたき、汗はずっとたれる）
  late final AnimationController _life = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));

  /// 押した時の、ぴょん
  late final AnimationController _tap = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _breath.repeat(reverse: true);
    if (widget.lively) _life.repeat();
  }

  @override
  void dispose() {
    _breath.dispose();
    _life.dispose();
    _tap.dispose();
    super.dispose();
  }

  /// [from]〜[to] の間だけ 0→1→0 と山になる
  static double _bump(double v, double from, double to) =>
      v < from || v > to ? 0 : math.sin((v - from) / (to - from) * math.pi);

  @override
  Widget build(BuildContext context) {
    final paint = SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_breath, _life, _tap]),
        builder: (context, _) {
          final l = widget.lively ? _life.value : -1.0;
          // しぼんでいる時は、跳ねる元気も少し
          final power = widget.stage == 0 ? 0.35 : 1.0;
          final hop = _bump(l, 0, 0.14) * power + _bump(_tap.value, 0, 0.75);
          final squash = _bump(l, 0.14, 0.22) * power + _bump(_tap.value, 0.75, 1);
          return CustomPaint(
            painter: _HitaPainter(
              stage: widget.stage.clamp(0, 4),
              breath: Curves.easeInOut.transform(_breath.value),
              fade: widget.fade,
              hop: hop,
              squash: squash,
              blink: _bump(l, 0.56, 0.6) + _bump(l, 0.63, 0.67),
              sweat: widget.lively ? l : null,
            ),
          );
        },
      ),
    );
    if (!widget.lively) return paint;
    // 動き続けるので、ほかの部分と分けて描きなおす
    return RepaintBoundary(
      child: GestureDetector(onTap: () => _tap.forward(from: 0), child: paint),
    );
  }
}

class _HitaPainter extends CustomPainter {
  _HitaPainter({
    required this.stage,
    required this.breath,
    required this.fade,
    this.hop = 0,
    this.squash = 0,
    this.blink = 0,
    this.sweat,
  });

  final int stage;
  final double breath;
  final double fade;

  /// 0〜1: 跳ねる高さ
  final double hop;

  /// 0〜1: 着地でつぶれる
  final double squash;

  /// 0〜1: まばたき（1で目を閉じる）
  final double blink;

  /// 0〜1: 汗がたれていく進み（null なら止まった汗）
  final double? sweat;

  static const _scale = [0.58, 0.68, 0.78, 0.88, 0.96];
  static const _dull = Color(0xFFA39D94);
  static const _ivory = Color(0xFFEFE3CA);
  static const _ink = Color(0xFF2E2118);

  @override
  void paint(Canvas canvas, Size size) {
    final t = stage / 4;
    final alpha = (1 - fade).clamp(0.0, 1.0);
    final body = Color.lerp(_dull, _ivory, t)!.withValues(alpha: alpha);
    final ink = _ink.withValues(alpha: alpha);

    final s = size.width * _scale[stage] * (1 - fade * 0.35);
    final w = s * 0.9;
    final h = s * (0.66 - (1 - t) * 0.06);
    final cx = size.width / 2;
    // しぼんでいるほど低く沈む。呼吸でわずかに上下
    final cy = size.height * (0.54 + (1 - t) * 0.06) - breath * size.height * 0.012;

    canvas.save();
    canvas.translate(cx, cy);

    // 影（地面にあるので、跳ねると小さく薄くなる）
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, h * 0.58),
        width: w * 0.86 * (1 - hop * 0.3),
        height: h * 0.14 * (1 - hop * 0.3),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.3 * alpha * (1 - hop * 0.4)),
    );

    // 跳ねる・つぶれる（足もとを中心に、のびちぢみ）
    canvas.translate(0, -hop * size.height * 0.09);
    canvas.translate(0, h * 0.55);
    canvas.scale(1 + squash * 0.1 - hop * 0.04, 1 - squash * 0.12 + hop * 0.06);
    canvas.translate(0, -h * 0.55);

    // 哲人: 後ろの金色の光
    if (stage == 4) {
      canvas.drawCircle(
        Offset(0, -h * 0.05),
        w * 0.8,
        Paint()
          ..shader = RadialGradient(
            colors: [
              const Color(0xFFFFE2A0).withValues(alpha: 0.5 * alpha),
              Colors.transparent,
            ],
          ).createShader(Rect.fromCircle(center: Offset(0, -h * 0.05), radius: w * 0.8)),
      );
    }

    // 体: 左右の脳と、下のふくらみをひとつの形に
    final bodyPath = Path.combine(
      PathOperation.union,
      Path.combine(
        PathOperation.union,
        Path()..addOval(Rect.fromCenter(center: Offset(-w * 0.2, -h * 0.07), width: w * 0.64, height: h * 0.9)),
        Path()..addOval(Rect.fromCenter(center: Offset(w * 0.2, -h * 0.07), width: w * 0.64, height: h * 0.9)),
      ),
      Path()..addOval(Rect.fromCenter(center: Offset(0, h * 0.16), width: w * 0.98, height: h * 0.72)),
    );
    canvas.drawPath(bodyPath, Paint()..color = body);

    // 版画のような線（しわ・影）は体の中だけ
    canvas.save();
    canvas.clipPath(bodyPath);
    _folds(canvas, w, h, ink.withValues(alpha: 0.5 * alpha), s);
    _hatch(canvas, w, h, ink.withValues(alpha: 0.2 * alpha), s);
    canvas.restore();

    // 輪郭と、まん中のみぞ
    final outline = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.024
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(bodyPath, outline);
    canvas.drawPath(
      Path()
        ..moveTo(0, -h * 0.5)
        ..cubicTo(-w * 0.04, -h * 0.38, w * 0.03, -h * 0.26, 0, -h * 0.14),
      outline,
    );

    _face(canvas, w, h, s, body, ink, t);

    // 考える腕（こぶしにあごをのせる）。しぼんでいる時は腕を上げる元気もない
    if (stage >= 1) _arm(canvas, w, h, s, body, ink);

    // 汗: しぼみはいつも、めざめは動いている時だけ。動いている時は、たれて消えていく
    final sw = sweat;
    if (stage == 0 || (stage == 1 && sw != null)) {
      final fall = sw == null ? 0.0 : Curves.easeIn.transform(sw);
      final dy = fall * h * 0.34;
      final a = sw == null ? alpha : alpha * (1 - Curves.easeIn.transform(sw));
      final drop = Path()
        ..moveTo(w * 0.42, -h * 0.24 + dy)
        ..quadraticBezierTo(w * 0.5, -h * 0.05 + dy, w * 0.42, -h * 0.03 + dy)
        ..quadraticBezierTo(w * 0.34, -h * 0.05 + dy, w * 0.42, -h * 0.24 + dy);
      canvas.drawPath(drop, Paint()..color = const Color(0xFF9DB9D6).withValues(alpha: a));
      canvas.drawPath(
        drop,
        Paint()
          ..color = _ink.withValues(alpha: a)
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.014,
      );
    }

    // 頭の上: 考えている「？」、哲人はひらめきの線
    _thought(canvas, w, h, s, ink, alpha);

    // 哲人: 月桂冠
    if (stage == 4) _laurel(canvas, w, h, alpha);

    canvas.restore();
  }

  /// 脳のしわ（左右に、ゆらぐ横線を何本も）
  void _folds(Canvas canvas, double w, double h, Color color, double s) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.016
      ..strokeCap = StrokeCap.round;
    for (final sx in [-1.0, 1.0]) {
      for (var i = 0; i < 6; i++) {
        final y0 = -h * 0.44 + i * h * 0.13;
        final start = 0.05 + (i % 3) * 0.04;
        final len = 0.36 + ((i * 7) % 5) * 0.025;
        final freq = 2.4 + ((i * 3 + (sx > 0 ? 1 : 0)) % 4) * 0.55;
        final path = Path();
        const steps = 18;
        for (var k = 0; k <= steps; k++) {
          final u = k / steps;
          final x = sx * (w * start + u * w * len);
          final y = y0 + math.sin(u * math.pi * freq + i * 1.7 + (sx > 0 ? 0.8 : 0)) * h * (0.03 + (i % 2) * 0.015);
          k == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
        }
        canvas.drawPath(path, p);
      }
    }
  }

  /// 右下の影（版画の斜線）
  void _hatch(Canvas canvas, double w, double h, Color color, double s) {
    final p = Paint()
      ..color = color
      ..strokeWidth = s * 0.01;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(w * 0.05, h * 0.05, w, h));
    for (var i = -10; i < 16; i++) {
      final x = i * w * 0.045;
      canvas.drawLine(Offset(x, h * 0.6), Offset(x + w * 0.3, h * 0.0), p);
    }
    canvas.restore();
  }

  /// 顔: 上を見て考えこむ目、寄せた眉、むすんだ口
  void _face(Canvas canvas, double w, double h, double s, Color body, Color ink, double t) {
    final eyeY = h * 0.12;
    final eyeDx = w * 0.15;
    final ew = w * 0.12;
    final eh = h * 0.13;
    Paint stroke(double width) => Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * width
      ..strokeCap = StrokeCap.round;
    // まぶたの重さ（しぼみ 0.5 → 哲人 0.1）
    final lid = math.max(0.5 - t * 0.4, blink.clamp(0.0, 1.0));
    for (final sx in [-1.0, 1.0]) {
      final c = Offset(sx * eyeDx, eyeY);
      final eye = Rect.fromCenter(center: c, width: ew, height: eh);
      // 白目
      canvas.drawOval(eye, Paint()..color = Color.lerp(body, Colors.white, 0.55)!);
      // 黒目: 右上を見て考えている。重いまぶた（体の色で上を覆う）
      canvas.save();
      canvas.clipPath(Path()..addOval(eye));
      canvas.drawCircle(c + Offset(ew * 0.18, stage == 0 ? eh * 0.12 : -eh * 0.02), ew * 0.24, Paint()..color = ink);
      canvas.drawCircle(
        c + Offset(ew * 0.1, stage == 0 ? eh * 0.06 : -eh * 0.1),
        ew * 0.06,
        Paint()..color = Colors.white.withValues(alpha: 0.8),
      );
      canvas.drawRect(Rect.fromLTRB(eye.left, eye.top, eye.right, eye.top + eh * lid), Paint()..color = body);
      canvas.restore();
      canvas.drawOval(eye, stroke(0.02));
      canvas.drawLine(
        Offset(eye.left + ew * 0.05, eye.top + eh * lid),
        Offset(eye.right - ew * 0.05, eye.top + eh * lid),
        stroke(0.026),
      );
      // 眉: 考えこむと内側が下がる（しぼみの時は、困って内側が上がる）
      final inner = stage == 0 ? -h * 0.03 : h * 0.025;
      canvas.drawLine(
        Offset(sx * (eyeDx + ew * 0.62), eyeY - eh * 0.85),
        Offset(sx * (eyeDx - ew * 0.55), eyeY - eh * 0.85 + inner),
        stroke(0.028),
      );
    }
    // 口: 「うーん」と少しゆがんだ一文字
    final my = eyeY + h * 0.2;
    canvas.drawPath(
      Path()
        ..moveTo(-w * 0.1, my + h * 0.004)
        ..quadraticBezierTo(-w * 0.04, my - h * 0.012, w * 0.01, my - h * 0.002),
      stroke(0.022),
    );
  }

  /// 腕とこぶし（あごの下）
  void _arm(Canvas canvas, double w, double h, double s, Color body, Color ink) {
    final my = h * 0.12 + h * 0.2;
    final fist = Offset(w * 0.1, my + h * 0.11);
    // ひじは体の下。そこから前腕がまっすぐ上がって、こぶしがあごの下に
    final arm = Path()
      ..moveTo(w * 0.2, h * 0.56)
      ..quadraticBezierTo(w * 0.17, h * 0.5, fist.dx + w * 0.02, fist.dy + h * 0.04);
    canvas.drawPath(
      arm,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.075
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      arm,
      Paint()
        ..color = body
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.04
        ..strokeCap = StrokeCap.round,
    );
    final r = w * 0.07;
    canvas.drawCircle(fist, r, Paint()..color = body);
    canvas.drawCircle(
      fist,
      r,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.02,
    );
    // 指の線
    final finger = Paint()
      ..color = ink
      ..strokeWidth = s * 0.012
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 2; i++) {
      final y = fist.dy - r * 0.25 + i * r * 0.45;
      canvas.drawLine(Offset(fist.dx - r * 0.55, y), Offset(fist.dx + r * 0.1, y), finger);
    }
  }

  void _thought(Canvas canvas, double w, double h, double s, Color ink, double alpha) {
    final at = Offset(w * 0.36, -h * 0.66);
    if (stage == 4) {
      final p = Paint()
        ..color = const Color(0xFFE0B04A).withValues(alpha: alpha)
        ..strokeWidth = s * 0.022
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 5; i++) {
        final a = -math.pi / 2 + (i - 2) * 0.45;
        final d = Offset(math.cos(a), math.sin(a));
        canvas.drawLine(at + d * w * 0.06, at + d * w * 0.14, p);
      }
      return;
    }
    final tp = TextPainter(
      text: TextSpan(
        text: '？',
        style: TextStyle(
          fontFamily: 'NotoSerifJP',
          fontWeight: FontWeight.w800,
          fontSize: s * (0.13 + stage * 0.015),
          color: ink.withValues(alpha: (0.6 + stage * 0.1) * alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    canvas.save();
    canvas.translate(at.dx, at.dy - breath * h * 0.04);
    canvas.rotate(0.15);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  void _laurel(Canvas canvas, double w, double h, double alpha) {
    final leaf = Paint()..color = const Color(0xFF6F8A45).withValues(alpha: alpha);
    final vein = Paint()
      ..color = const Color(0xFF3F5226).withValues(alpha: alpha)
      ..strokeWidth = w * 0.006;
    for (var i = 0; i < 7; i++) {
      for (final sx in [-1, 1]) {
        final a = -math.pi / 2 + sx * (0.35 + i * 0.17);
        final p = Offset(math.cos(a) * w * 0.42, -h * 0.16 + math.sin(a) * h * 0.5);
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(a + sx * 0.9);
        final r = Rect.fromCenter(center: Offset.zero, width: w * 0.1, height: w * 0.042);
        canvas.drawOval(r, leaf);
        canvas.drawLine(Offset(-r.width / 2, 0), Offset(r.width / 2, 0), vein);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_HitaPainter old) =>
      old.stage != stage ||
      old.breath != breath ||
      old.fade != fade ||
      old.hop != hop ||
      old.squash != squash ||
      old.blink != blink ||
      old.sweat != sweat;
}

/// 小さなちびのう（通知・ボタン用のアイコン）
class ChibinoIcon extends StatelessWidget {
  const ChibinoIcon({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) => Hitachan(stage: 2, size: size * 1.5, animate: false);
}
