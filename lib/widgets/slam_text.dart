import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// フォンク系のエディット動画のような文字。
/// 極太の Dela Gothic One で、1文字ずつ「ドン」と落ちてきて、最後に少し揺れる。
/// 白い文字に黒い縁取り。赤と水色のずれ（色収差）はごく控えめに。
class SlamText extends StatefulWidget {
  const SlamText(
    this.text, {
    super.key,
    required this.fontSize,
    this.play = true,
    this.onLight = false,
    this.lineHeight = 1.42,
  });

  final String text;
  final double fontSize;

  /// true になった時にアニメーションを始める（表示中のページになった時など）
  final bool play;

  /// 白い雲の上に載せる時（黒い文字）
  final bool onLight;

  /// 行の高さ（文字の大きさに対する倍率）。反論の黒い雲は、読みやすいよう少し広め
  final double lineHeight;

  /// 太字のフォンク風スタイル
  static TextStyle style(double size, {bool onLight = false, double height = 1.42}) => onLight
      ? TextStyle(
          fontFamily: 'DelaGothicOne',
          fontSize: size,
          color: const Color(0xFF16181A),
          height: height,
          letterSpacing: 1,
          shadows: const [
            Shadow(color: Color(0x33FF2D4B), offset: Offset(-0.7, 0)),
            Shadow(color: Color(0x3300A8C0), offset: Offset(0.7, 0)),
          ],
        )
      : TextStyle(
          fontFamily: 'DelaGothicOne',
          fontSize: size,
          color: Colors.white,
          height: height,
          letterSpacing: 1,
          // 読みやすさ優先: 色ずれ（赤・水色）はごく控えめにし、黒い縁取りでくっきりさせる
          shadows: const [
            Shadow(color: Color(0x40FF2D4B), offset: Offset(-0.8, 0)),
            Shadow(color: Color(0x4000E5FF), offset: Offset(0.8, 0)),
            Shadow(color: Color(0xFF000000), blurRadius: 3),
            Shadow(color: Color(0x99000000), blurRadius: 10),
          ],
        );

  @override
  State<SlamText> createState() => _SlamTextState();
}

class _SlamTextState extends State<SlamText> with SingleTickerProviderStateMixin {
  /// 1文字が出るまでの間隔と、1文字が落ちてくる時間
  static const _step = 55;
  static const _drop = 260;

  /// 最後の揺れ
  static const _shake = 220;

  /// 1つずつ落とすかたまり。基本は1文字だが、日本語の禁則（行頭に「、。」」などが来ない／行末に「「」が残らない）
  /// を守るため、句読点や閉じかっこは前の文字に、開きかっこは次の文字にくっつける
  late final List<String> _chars = _tokens(widget.text);

  static const _noLineStart = '、。，．・：；？！ー～…」』）】〕〉》ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮ';
  static const _noLineEnd = '「『（【〔〈《';

  static List<String> _tokens(String text) {
    final out = <String>[];
    var carry = '';
    for (final ch in text.characters) {
      if (_noLineStart.contains(ch) && out.isNotEmpty) {
        out[out.length - 1] += ch;
      } else if (_noLineEnd.contains(ch)) {
        carry += ch;
      } else {
        out.add(carry + ch);
        carry = '';
      }
    }
    if (carry.isNotEmpty) out.add(carry);
    return out;
  }

  late final AnimationController _c =
      AnimationController(
        vsync: this,
        duration: Duration(milliseconds: _chars.length * _step + _drop + _shake),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) HapticFeedback.mediumImpact();
      });

  @override
  void initState() {
    super.initState();
    if (widget.play) _c.forward();
  }

  @override
  void didUpdateWidget(SlamText old) {
    super.didUpdateWidget(old);
    if (widget.play && !old.play) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = SlamText.style(widget.fontSize, onLight: widget.onLight, height: widget.lineHeight);
    final total = _c.duration!.inMilliseconds;
    final slamEnd = _chars.length * _step + _drop;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final ms = _c.value * total;
        // 全部落ちた後の、短い揺れ
        final shakeT = ((ms - slamEnd) / _shake).clamp(0.0, 1.0);
        final shake = shakeT > 0 && shakeT < 1 ? math.sin(shakeT * math.pi * 6) * 3 * (1 - shakeT) : 0.0;

        return Transform.translate(
          offset: Offset(shake, 0),
          child: Wrap(
            children: [
              for (var i = 0; i < _chars.length; i++) _char(i, ((ms - i * _step) / _drop).clamp(0.0, 1.0), style),
            ],
          ),
        );
      },
    );
  }

  /// 1文字分。p: 0（まだ）→ 1（着地）
  Widget _char(int i, double p, TextStyle style) {
    final eased = Curves.easeOutBack.transform(p);
    // 文字ごとに少しずつ違う傾きから、まっすぐに戻る
    final tilt = (math.sin(i * 12.9898) * 0.35) * (1 - eased);
    return Opacity(
      opacity: p == 0 ? 0 : (p * 3).clamp(0.0, 1.0),
      child: Transform.rotate(
        angle: tilt,
        child: Transform.scale(
          scale: 1 + (1 - eased) * 1.4,
          child: Text(_chars[i], style: style),
        ),
      ),
    );
  }
}
