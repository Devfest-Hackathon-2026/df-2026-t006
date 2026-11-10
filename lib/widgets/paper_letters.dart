import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 雑誌や新聞から1文字ずつ切り抜いて貼ったような文字。
/// 1文字ずつ、いびつな長方形の紙片に入れ、書体と色（白・黒だけ）と傾きを変える。
class PaperLetters extends StatelessWidget {
  const PaperLetters(this.text, {super.key, this.height = 44});

  final String text;

  /// 紙片1枚の高さ
  final double height;

  @override
  Widget build(BuildContext context) {
    final chars = text.characters.toList();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < chars.length; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: height * 0.03),
            child: _Scrap(char: chars[i], style: _styles[i % _styles.length], height: height),
          ),
      ],
    );
  }
}

/// 切り抜き文字1枚（[index] 番目の紙の見た目で）。ロゴの上など、好きな位置に1文字ずつ置きたい時に使う。
class PaperLetter extends StatelessWidget {
  const PaperLetter(this.char, {super.key, required this.index, this.height = 44, this.pinned = false});

  final String char;
  final int index;
  final double height;

  /// 上に画鋲を刺す（ロゴなどに留めてあるように見せる）
  final bool pinned;

  @override
  Widget build(BuildContext context) =>
      _Scrap(char: char, style: _styles[index % _styles.length], height: height, pinned: pinned);
}

enum _Font { serif, sans, dot }

/// 紙片1枚の見た目
class _ScrapStyle {
  const _ScrapStyle({
    required this.paper,
    required this.ink,
    required this.font,
    required this.angle,
    required this.dy,
    required this.widthRatio,
    required this.seed,
  });

  /// 紙の色（白か黒）
  final Color paper;

  /// 文字の色（白か黒）
  final Color ink;

  final _Font font;

  /// 傾き（度）
  final double angle;

  /// 上下のずれ（高さに対する割合）
  final double dy;

  /// 横幅（高さに対する割合）
  final double widthRatio;

  /// 切り口のいびつさを決める乱数の種（毎回同じ形にするため固定）
  final int seed;
}

const _white = Color(0xFFF1EFEA);
const _black = Color(0xFF151515);

const _styles = <_ScrapStyle>[
  // 白い紙 + 黒い明朝
  _ScrapStyle(paper: _white, ink: _black, font: _Font.serif, angle: -7, dy: 0.03, widthRatio: 0.9, seed: 3),
  // 黒い紙 + 白い太ゴシック
  _ScrapStyle(paper: _black, ink: _white, font: _Font.sans, angle: 5, dy: -0.06, widthRatio: 0.84, seed: 11),
  // 白い紙 + 黒いドット文字
  _ScrapStyle(paper: _white, ink: _black, font: _Font.dot, angle: -3, dy: 0.05, widthRatio: 0.86, seed: 23),
];

class _Scrap extends StatelessWidget {
  const _Scrap({required this.char, required this.style, required this.height, this.pinned = false});

  final bool pinned;

  final String char;
  final _ScrapStyle style;
  final double height;

  TextStyle _textStyle() {
    final size = height * 0.62;
    final base = switch (style.font) {
      _Font.serif => serif(size, weight: FontWeight.w900),
      _Font.sans => sans(size, weight: FontWeight.w900),
      _Font.dot => TextStyle(fontFamily: 'DotGothic16', fontSize: size),
    };
    return base.copyWith(color: style.ink, height: 1);
  }

  @override
  Widget build(BuildContext context) {
    final s = style;
    final w = height * s.widthRatio;

    return Transform.translate(
      offset: Offset(0, s.dy * height),
      child: Transform.rotate(
        angle: s.angle * math.pi / 180,
        child: SizedBox(
          width: w,
          height: height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 紙の影（貼った感じ）
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(height * 0.03, height * 0.05),
                  child: ClipPath(
                    clipper: _CutEdge(s.seed),
                    child: const ColoredBox(color: Color(0x73000000)),
                  ),
                ),
              ),
              // 紙 + 文字
              Positioned.fill(
                child: ClipPath(
                  clipper: _CutEdge(s.seed),
                  child: ColoredBox(
                    color: s.paper,
                    child: Center(child: Text(char, style: _textStyle())),
                  ),
                ),
              ),
              // 画鋲（紙の上端の真ん中に刺さっている）
              if (pinned)
                Positioned(
                  top: -height * 0.12,
                  left: w / 2 - height * 0.12,
                  child: _Pin(size: height * 0.24),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// はさみで切ったような、いびつな長方形
class _CutEdge extends CustomClipper<Path> {
  const _CutEdge(this.seed);

  final int seed;

  /// 歪みの大きさ（辺の長さに対する割合）
  static const _jag = 0.06;

  @override
  Path getClip(Size size) {
    final r = math.Random(seed);
    double j(double len) => (r.nextDouble() - 0.5) * 2 * _jag * len;
    final w = size.width, h = size.height;
    // 四隅をずらし、各辺の真ん中にも点を入れて切り口を少しガタつかせる
    return Path()
      ..moveTo(j(w).abs(), j(h).abs())
      ..lineTo(w * 0.5, j(h) * 0.6)
      ..lineTo(w - j(w).abs(), j(h).abs())
      ..lineTo(w + j(w) * 0.6, h * 0.5)
      ..lineTo(w - j(w).abs(), h - j(h).abs())
      ..lineTo(w * 0.5, h + j(h) * 0.6)
      ..lineTo(j(w).abs(), h - j(h).abs())
      ..lineTo(j(w) * 0.6, h * 0.5)
      ..close();
  }

  @override
  bool shouldReclip(_CutEdge old) => old.seed != seed;
}

/// 画鋲（グレーの金属。左上に光、右下に影）
class _Pin extends StatelessWidget {
  const _Pin({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.4),
          radius: 0.9,
          colors: [Color(0xFFF4F4F4), Color(0xFF9A9A9A), Color(0xFF3A3A3A)],
          stops: [0.0, 0.45, 1.0],
        ),
        border: Border.all(color: const Color(0xFF202020), width: 0.8),
        boxShadow: [
          BoxShadow(color: const Color(0x99000000), blurRadius: size * 0.25, offset: Offset(size * 0.12, size * 0.2)),
        ],
      ),
    );
  }
}
