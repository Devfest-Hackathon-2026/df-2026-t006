import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/music.dart';
import '../theme.dart';

/// 押し込める「厚み」のあるボタン。
/// 面(face)の下に側面(edge)があり、押すと面が沈む。
class PushButton extends StatefulWidget {
  const PushButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.face = AppColors.navy,
    this.edge = AppColors.navyDeep,
    this.border,
    this.width,
    this.height = 64,
    this.depth = 6,
    this.radius = 18,
    this.borderWidth = 2,
  });

  /// 配色（ButtonColors）からまとめて指定する
  PushButton.colored({
    super.key,
    required this.child,
    required this.onPressed,
    required ButtonColors colors,
    this.width,
    this.height = 64,
    this.depth = 6,
    this.radius = 18,
  }) : face = colors.face,
       edge = colors.edge,
       border = colors.border,
       borderWidth = 2;

  /// 丸いアイコンボタン
  const PushButton.circle({
    super.key,
    required this.child,
    required this.onPressed,
    this.face = AppColors.surface,
    this.edge = AppColors.ink,
    this.border,
    double size = 52,
    this.depth = 4,
  }) : width = size,
       height = size,
       radius = size / 2,
       borderWidth = 2;

  final Widget child;
  final VoidCallback? onPressed;
  final Color face;
  final Color edge;

  /// 輪郭線（null なら線なし）
  final Color? border;
  final double? width;
  final double height;
  final double depth;
  final double radius;

  /// 輪郭線の太さ
  final double borderWidth;

  @override
  State<PushButton> createState() => _PushButtonState();
}

class _PushButtonState extends State<PushButton> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onPressed == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.radius);
    final sink = _down ? widget.depth : 0.0;
    final outline = widget.border == null ? null : Border.all(color: widget.border!, width: widget.borderWidth);

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: widget.onPressed == null
            ? null
            : () {
                HapticFeedback.lightImpact();
                Sfx.tap();
                widget.onPressed!();
              },
        child: SizedBox(
          width: widget.width,
          height: widget.height + widget.depth,
          child: Stack(
            children: [
              // 側面
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: widget.height,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: widget.edge, borderRadius: r, border: outline),
                ),
              ),
              // 面
              AnimatedPositioned(
                duration: const Duration(milliseconds: 60),
                left: 0,
                right: 0,
                top: sink,
                height: widget.height,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: widget.face, borderRadius: r, border: outline),
                  child: Center(child: widget.child),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
