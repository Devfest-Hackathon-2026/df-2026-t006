import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'baked_image.dart';

/// フォルダの形（左上にタブ）をしたパス。
Path folderPath(Size s, {double tabHeight = 18, double radius = 12}) {
  final w = s.width, h = s.height, r = radius, t = tabHeight;
  final tabW = w * 0.42;
  const slope = 14.0;

  return Path()
    ..moveTo(0, r)
    ..quadraticBezierTo(0, 0, r, 0)
    ..lineTo(tabW - r, 0)
    // タブの右肩: なめらかに下へ
    ..cubicTo(tabW, 0, tabW, t, tabW + slope, t)
    ..lineTo(w - r, t)
    ..quadraticBezierTo(w, t, w, t + r)
    ..lineTo(w, h - r)
    ..quadraticBezierTo(w, h, w - r, h)
    ..lineTo(r, h)
    ..quadraticBezierTo(0, h, 0, h - r)
    ..close();
}

class _FolderClipper extends CustomClipper<Path> {
  const _FolderClipper(this.tabHeight);

  final double tabHeight;

  @override
  Path getClip(Size size) => folderPath(size, tabHeight: tabHeight);

  @override
  bool shouldReclip(_FolderClipper old) => old.tabHeight != tabHeight;
}

class _FolderPainter extends CustomPainter {
  _FolderPainter({required this.color, required this.tabHeight, this.fill = false});

  final Color color;
  final double tabHeight;
  final bool fill;

  @override
  void paint(Canvas canvas, Size size) {
    final path = folderPath(size, tabHeight: tabHeight);
    final paint = Paint()
      ..color = color
      ..style = fill ? PaintingStyle.fill : PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
    if (!fill) {
      // タブと本体の境目
      canvas.drawLine(Offset(0, tabHeight), Offset(size.width, tabHeight), paint);
    }
  }

  @override
  bool shouldRepaint(_FolderPainter old) => old.color != color || old.fill != fill;
}

/// 押し込めるフォルダ型ボタン（テーマ選択用）。
/// 本体に画像を「刻んだ」ように表示し、下に題名の帯。
class FolderButton extends StatefulWidget {
  const FolderButton({
    super.key,
    required this.image,
    required this.title,
    required this.tabLabel,
    required this.onPressed,
    this.badge,
    this.ink = AppColors.ink,
    this.paper = AppColors.surface,
    this.accent = AppColors.accent,
    this.depth = 6,
  });

  /// assets の画像パス
  final String image;
  final String title;

  /// タブに書く文字（番号）
  final String tabLabel;
  final VoidCallback onPressed;

  /// 右上に出すバッジ（完了マークなど）
  final Widget? badge;

  final Color ink;
  final Color paper;
  final Color accent;
  final double depth;

  static const tabHeight = 22.0;

  @override
  State<FolderButton> createState() => _FolderButtonState();
}

class _FolderButtonState extends State<FolderButton> {
  bool _down = false;

  /// 画像を版画のような白黒・高コントラストにする
  static const _engrave = ColorFilter.matrix(<double>[
    0.28, 0.94, 0.09, 0, -40, //
    0.27, 0.92, 0.09, 0, -42, //
    0.25, 0.85, 0.08, 0, -46, //
    0, 0, 0, 1, 0,
  ]);

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    const t = FolderButton.tabHeight;

    return Semantics(
      button: true,
      label: widget.title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapCancel: () => _set(false),
        onTapUp: (_) => _set(false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onPressed();
        },
        child: LayoutBuilder(
          builder: (context, c) {
            final faceH = c.maxHeight - widget.depth;
            final sink = _down ? widget.depth : 0.0;

            return Stack(
              children: [
                // 厚み（黒いフォルダの影）
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: faceH,
                  child: CustomPaint(
                    painter: _FolderPainter(color: widget.ink, tabHeight: t, fill: true),
                  ),
                ),
                // 面
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 60),
                  left: 0,
                  right: 0,
                  top: sink,
                  height: faceH,
                  child: Stack(
                    children: [
                      ClipPath(
                        clipper: const _FolderClipper(t),
                        child: Stack(
                          children: [
                            Positioned.fill(child: ColoredBox(color: widget.paper)),
                            // タブの番号
                            Positioned(
                              left: 14,
                              top: 0,
                              height: t,
                              child: Center(
                                child: Text(
                                  widget.tabLabel,
                                  style: sans(12, weight: FontWeight.w900, color: widget.accent, height: 1),
                                ),
                              ),
                            ),
                            // 本体: 画像 + 題名の帯
                            Positioned(
                              left: 0,
                              right: 0,
                              top: t,
                              bottom: 0,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: BakedImage(widget.image, filter: _engrave),
                                    ),
                                  ),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                                    decoration: BoxDecoration(
                                      color: widget.paper,
                                      border: Border(top: BorderSide(color: widget.ink, width: 2)),
                                    ),
                                    child: Text(
                                      widget.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: serif(
                                        16,
                                        weight: FontWeight.w700,
                                        color: widget.ink,
                                      ).copyWith(height: 1.3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 輪郭
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _FolderPainter(color: widget.ink, tabHeight: t),
                          ),
                        ),
                      ),
                      if (widget.badge != null) Positioned(top: t + 8, right: 8, child: widget.badge!),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
