import 'package:flutter/material.dart';

import '../theme.dart';

/// 電車の案内表示のように、名言が右から左へ流れる帯。
/// 半透明の黒地に、ドット文字（DotGothic16。アプリに同梱）。
class QuoteTicker extends StatefulWidget {
  const QuoteTicker({super.key, required this.quotes, this.speed = 45});

  /// 流す言葉（言語の切り替えは設定画面。lib/data/quotes.dart）
  final List<String> quotes;

  /// 流れる速さ（ピクセル/秒）
  final double speed;

  @override
  State<QuoteTicker> createState() => _QuoteTickerState();
}

class _QuoteTickerState extends State<QuoteTicker> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  double _loopWidth = 0;

  static const _separator = '　◆　';

  String get _line => widget.quotes.join(_separator) + _separator;

  /// DotGothic16 は16pxの格子で作られているので、16pxちょうどだとドットがくっきり出る
  TextStyle get _style => const TextStyle(
    fontFamily: 'DotGothic16',
    fontSize: 16,
    color: AppColors.onNavy,
    letterSpacing: 2,
    height: 1,
    // 電光掲示板のような、うっすらとした光
    shadows: [Shadow(color: Color(0x99F1EFEA), blurRadius: 6)],
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// 1周分の文字列の幅を測り、速さが一定になるようアニメーションの長さを決める
  void _measure() {
    final tp = TextPainter(
      text: TextSpan(text: _line, style: _style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    if (tp.width == _loopWidth) return;
    _loopWidth = tp.width;
    _c
      ..duration = Duration(milliseconds: (_loopWidth / widget.speed * 1000).round())
      ..repeat();
  }

  @override
  Widget build(BuildContext context) {
    _measure();
    final text = Text(_line, style: _style, maxLines: 1, softWrap: false);

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        border: Border.symmetric(horizontal: BorderSide(color: AppColors.ink.withValues(alpha: 0.25))),
      ),
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) => OverflowBox(
            alignment: Alignment.centerLeft,
            maxWidth: double.infinity,
            child: Transform.translate(offset: Offset(-_c.value * _loopWidth, 0), child: child),
          ),
          // 同じ文字列を2つ並べて、つなぎ目なくループさせる
          child: Row(mainAxisSize: MainAxisSize.min, children: [text, text]),
        ),
      ),
    );
  }
}
