import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../data/events.dart';
import '../theme.dart';

/// 明るい紙の色と、その上の文字色
const _paper = Color(0xFFF1EFEA);
const _dark = Color(0xFF1D1F20);

/// 開催中のイベントを自動でめくっていく長方形の枠。
/// 左右の「‹‹」「››」で前後へ。指で横にスワイプしても切り替えられ、タップするとイベント先へ移動する。
class EventCarousel extends StatefulWidget {
  const EventCarousel({
    super.key,
    this.events = currentEvents,
    this.interval = const Duration(seconds: 4),
    this.height = 92,
  });

  final List<AppEvent> events;
  final Duration interval;
  final double height;

  @override
  State<EventCarousel> createState() => _EventCarouselState();
}

class _EventCarouselState extends State<EventCarousel> {
  // 端で止まらず一方向にめくり続けられるよう、大きな番号から始める
  static const _start = 1000;
  final _controller = PageController(initialPage: _start);
  Timer? _timer;
  int _page = _start;

  int get _count => widget.events.length;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  /// 自動めくり。指で触ったらタイマーを最初からやり直す
  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (_) {
      if (!_controller.hasClients) return;
      _controller.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeInOutCubic);
    });
  }

  /// 矢印で前後へ（押したら自動めくりのタイマーもやり直す）
  void _step(int delta) {
    if (!_controller.hasClients) return;
    _restartTimer();
    final target = (_controller.page ?? _page.toDouble()).round() + delta;
    _controller.animateToPage(target, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _DoubleChevron(left: true, onPressed: () => _step(-1)),
        Expanded(child: _card()),
        _DoubleChevron(left: false, onPressed: () => _step(1)),
      ],
    );
  }

  Widget _card() {
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        // 明るい版（試作）。暗い版に戻す場合: 面 AppColors.surface(0.92) / 輪郭・影 AppColors.ink
        color: _paper,
        // ずらした影はやめて、板全体を囲む柔らかい影 + 細い縁で浮かせる
        border: Border.all(color: const Color(0xFFCFCBC2), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 18, spreadRadius: 1)],
      ),
      child: Stack(
        children: [
          NotificationListener<ScrollStartNotification>(
            onNotification: (n) {
              if (n.dragDetails != null) _restartTimer();
              return false;
            },
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (p) => setState(() => _page = p),
              itemBuilder: (context, i) => _EventPage(event: widget.events[i % _count]),
            ),
          ),
          // 何枚目か（右上の点。下の説明文と重ならないように）
          Positioned(
            right: 12,
            top: 14,
            child: Row(
              children: [
                for (var i = 0; i < _count; i++)
                  Container(
                    width: i == _page % _count ? 14 : 6,
                    height: 6,
                    margin: const EdgeInsets.only(left: 4),
                    color: i == _page % _count ? AppColors.navy : _dark.withValues(alpha: 0.25),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventPage extends StatelessWidget {
  const _EventPage({required this.event});

  final AppEvent event;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: event.route == null ? null : () => context.go(event.route!),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: AppColors.navy,
                    child: Text(
                      event.tag,
                      style: sans(11, weight: FontWeight.w800, color: AppColors.onNavy, height: 1.2),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: serif(18, weight: FontWeight.w700, color: _dark).copyWith(height: 1.3),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.detail,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: sans(12, color: _dark.withValues(alpha: 0.6), height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 「‹‹」「››」の形の、細くて控えめな矢印ボタン
class _DoubleChevron extends StatefulWidget {
  const _DoubleChevron({required this.left, required this.onPressed});

  final bool left;
  final VoidCallback onPressed;

  @override
  State<_DoubleChevron> createState() => _DoubleChevronState();
}

class _DoubleChevronState extends State<_DoubleChevron> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.left ? '前のイベント' : '次のイベント',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onPressed();
        },
        // 押しやすいよう、見た目より広い範囲で反応する
        child: SizedBox(
          width: 40,
          height: 64,
          child: Center(
            child: AnimatedScale(
              scale: _down ? 0.8 : 1,
              duration: const Duration(milliseconds: 80),
              child: CustomPaint(
                size: const Size(20, 18),
                painter: _ChevronPainter(left: widget.left),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({required this.left});

  final bool left;

  @override
  void paint(Canvas canvas, Size size) {
    // 2本の「く」。外側を少し薄くして、奥行きを出す
    void chevron(double x, double alpha) {
      final dir = left ? -1.0 : 1.0;
      final tip = x + dir * size.width * 0.18;
      final back = x - dir * size.width * 0.18;
      final p = Paint()
        ..color = AppColors.ink.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(
        Path()
          ..moveTo(back, size.height * 0.1)
          ..lineTo(tip, size.height * 0.5)
          ..lineTo(back, size.height * 0.9),
        p,
      );
    }

    final inner = left ? size.width * 0.62 : size.width * 0.38;
    final outer = left ? size.width * 0.3 : size.width * 0.7;
    chevron(inner, 0.95);
    chevron(outer, 0.5);
  }

  @override
  bool shouldRepaint(_ChevronPainter old) => old.left != left;
}
