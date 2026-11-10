import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../brand.dart';
import '../theme.dart';
import 'paper_letters.dart';
import 'baked_image.dart';

/// ホームのスタートボタン。ロゴ（脳と∞）の上を、切り抜き文字の「テ・ツ・ル」が
/// ∞のリボンに沿ってメリーゴーランドのように回る。
/// 背景も輪郭もなく、影だけでボタンらしい立体感を出す:
///   - ロゴの真下に落ちる影（浮いて見える）
///   - 足元の楕円の影（地面に置かれたボタン）
/// 押すとロゴが沈み、影が小さく濃くなる（押し込んだ感じ）。
class StartButton extends StatefulWidget {
  const StartButton({super.key, required this.onPressed, this.size = 200});

  final VoidCallback onPressed;
  final double size;

  /// ロゴの下に貼る切り抜き文字
  static const label = 'テツル';

  @override
  State<StartButton> createState() => _StartButtonState();
}

class _StartButtonState extends State<StartButton> with TickerProviderStateMixin {
  bool _down = false;

  /// 文字が∞の上を1周する時間
  late final AnimationController _ride = AnimationController(vsync: this, duration: const Duration(seconds: 10))
    ..repeat();

  /// 「押してね」と誘うような、ゆっくりした上下の揺れ（2秒で1往復）
  late final AnimationController _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))
    ..repeat(reverse: true);

  /// 揺れの高さ（0 = 一番下、1 = 一番上）
  double get _bobHeight => Curves.easeInOut.transform(_bob.value);

  @override
  void dispose() {
    _bob.dispose();
    _ride.dispose();
    super.dispose();
  }

  /// mark.png（480×362）の縦横比
  static const _markAspect = 362 / 480;
  static const _markWidth = 480.0;

  /// ∞のリボンの中心線（mark.png 480×362 上で測った値）。
  /// ベルヌーイのレムニスケート（∞の形の曲線）を、ロゴのリボンに合わせて縦につぶしたもの。
  static const _ribbonCenter = Offset(238, 198);
  static const _ribbonHalfWidth = 186.0;
  static const _ribbonSquash = 0.62;

  /// ∞の上の位置（t は 0〜2π。1周）を、ロゴ上の割合（0〜1）で返す
  static Offset _onRibbon(double t) {
    final d = 1 + math.sin(t) * math.sin(t);
    final x = _ribbonHalfWidth * math.cos(t) / d;
    final y = _ribbonSquash * _ribbonHalfWidth * math.sin(t) * math.cos(t) / d;
    return Offset((_ribbonCenter.dx + x) / 480, (_ribbonCenter.dy + y) / 362);
  }

  /// 黒地のロゴ画像を「明るさ＝不透明度」の白い絵に変える（黒い部分が透明になる）
  static const _blackToClear = ColorFilter.matrix(<double>[
    0, 0, 0, 0, 241, //
    0, 0, 0, 0, 239, //
    0, 0, 0, 0, 234, //
    0.27, 0.92, 0.09, 0, -24,
  ]);

  /// 同じ形の、黒い影
  static const _blackToShadow = ColorFilter.matrix(<double>[
    0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, //
    0, 0, 0, 0, 0, //
    0.3, 1.0, 0.1, 0, -24,
  ]);

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final logoW = size * 0.96;
    final logoH = logoW * _markAspect;
    const anim = Duration(milliseconds: 90);

    // 押した時: ロゴが沈み、影が近く・小さくなる
    final lift = _down ? 1.0 : 5.0;
    final sink = _down ? 4.0 : 0.0;

    // 白いロゴと、ぼかした影は、1回だけ作って使い回す（浮き沈みのたびに、フィルターやぼかしをかけ直さない）
    final logo = BakedImage(LogoAsset.mark, filter: _blackToClear, width: logoW, height: logoH, fit: BoxFit.fill);
    // 影のぼかし: 画面で 5px ぶん（元の画像のピクセルに直す）
    final scale = logoW / _markWidth;
    final blur = (5 / scale * 10).roundToDouble() / 10;
    final pad = BakedImage.padFor(blur) * scale;

    return Semantics(
      button: true,
      label: 'はじめる',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onPressed();
        },
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              // 足元の楕円の影（ふちがぼやけた黒い楕円。ぼかしの代わりに、まるいグラデーションで軽く）
              Positioned(
                // 脳との間を広めにあける（浮いて見える）
                bottom: -size * 0.13,
                // 脳が上がると影は小さく薄く、下がると大きく濃くなる
                child: AnimatedBuilder(
                  animation: _bob,
                  builder: (context, child) => Opacity(
                    opacity: 1 - 0.3 * _bobHeight,
                    child: Transform.scale(scale: 1 - 0.14 * _bobHeight, child: child),
                  ),
                  child: Builder(
                    builder: (context) {
                      final w = size * (_down ? 0.74 : 0.88);
                      final h = size * (_down ? 0.12 : 0.15);
                      // まるいグラデーションを縦につぶして、楕円にする
                      return SizedBox(
                        width: w,
                        height: h,
                        child: OverflowBox(
                          maxWidth: w,
                          maxHeight: w,
                          child: Transform.scale(
                            scaleY: h / w,
                            child: Container(
                              width: w,
                              height: w,
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  radius: 0.5,
                                  colors: [
                                    Colors.black.withValues(alpha: _down ? 0.75 : 0.6),
                                    Colors.black.withValues(alpha: _down ? 0.45 : 0.32),
                                    Colors.black.withValues(alpha: 0),
                                  ],
                                  stops: const [0, 0.5, 1],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: anim,
                // 少し下げる（足元の影に近づける）
                top: (size - logoH) / 2 + size * 0.06 + sink,
                child: AnimatedBuilder(
                  animation: _bob,
                  // ゆっくり浮き沈み（押している間は止める）
                  builder: (context, child) =>
                      Transform.translate(offset: Offset(0, _down ? 0 : -size * 0.045 * _bobHeight), child: child),
                  child: SizedBox(
                    width: logoW,
                    height: logoH,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // ロゴの真下に落ちる、ぼかした影（浮いて見える）
                        AnimatedPositioned(
                          duration: anim,
                          left: -pad,
                          top: lift + 2 - pad,
                          child: BakedImage(
                            LogoAsset.mark,
                            filter: _blackToShadow,
                            blur: blur,
                            width: logoW + pad * 2,
                            height: logoH + pad * 2,
                            fit: BoxFit.fill,
                          ),
                        ),
                        logo,
                        // 切り抜き文字「テ」「ツ」「ル」が、∞のリボンの上をメリーゴーランドのように回る
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _ride,
                            builder: (context, _) {
                              final chars = StartButton.label.characters.toList();
                              return Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  for (var i = 0; i < chars.length; i++)
                                    _letterAt(
                                      chars[i],
                                      i,
                                      // 3文字を1/3周ずつずらして、等間隔で回す
                                      (_ride.value + i / chars.length) * 2 * math.pi,
                                      logoW,
                                      logoH,
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 切り抜き文字1枚を、∞の上の位置 [t] に置く。
  /// 輪の下側（手前）に来ると少し大きく、上側（奥）では少し小さくして、奥行きを出す。
  Widget _letterAt(String char, int index, double t, double w, double h) {
    final at = _onRibbon(t);
    final depth = (at.dy - _ribbonCenter.dy / 362) / 0.12; // -1（奥）〜 1（手前）くらい
    // 小さめにして、∞の形が見えるようにする
    final letter = w * 0.145 * (1 + 0.12 * depth.clamp(-1.0, 1.0));
    final box = letter * 1.4;
    return Positioned(
      left: at.dx * w - box / 2,
      top: at.dy * h - box / 2,
      width: box,
      height: box,
      child: Center(
        child: PaperLetter(char, index: index, height: letter, pinned: true),
      ),
    );
  }
}

/// はじめての時だけ、脳（はじめるボタン）の上で跳ねる「おしてみて！」
class PressHint extends StatefulWidget {
  const PressHint({super.key});

  @override
  State<PressHint> createState() => _PressHintState();
}

class _PressHintState extends State<PressHint> with SingleTickerProviderStateMixin {
  late final AnimationController _hop = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _hop,
      builder: (context, child) =>
          Transform.translate(offset: Offset(0, -8 * Curves.easeInOut.transform(_hop.value)), child: child),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 7),
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF16181A), width: 2),
              boxShadow: const [BoxShadow(color: Color(0x99000000), offset: Offset(3, 3))],
            ),
            child: Text(
              'おしてみて！',
              style: sans(15, weight: FontWeight.w800, color: const Color(0xFF16181A)),
            ),
          ),
          // 下向きの三角（脳を指す）
          CustomPaint(size: const Size(16, 9), painter: _Pointer()),
        ],
      ),
    );
  }
}

class _Pointer extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(_Pointer old) => false;
}
