import 'package:flutter/material.dart';

import '../theme.dart';
import 'push_button.dart';

/// 画面の枠。
/// - スマホ（幅 [phoneMaxWidth] 以下）: 画面いっぱいに表示
/// - PC・タブレットなど広い画面: スマホの形（[designWidth] × 縦横比 [designAspect]）で作った画面を
///   丸ごと拡大・縮小して中央に表示する。ウィンドウを大きくしても比率が崩れない。
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child, this.background});

  final Widget child;

  /// 背景（グラデーション等）。省略時は紙色。
  final Gradient? background;

  /// これより狭ければスマホとみなし、画面いっぱいに使う
  static const phoneMaxWidth = 500.0;

  /// 広い画面で使う、基準のスマホ画面の幅と縦横比（幅÷高さ。iPhone と同じ 9:19.5）
  static const designWidth = 400.0;
  static const designAspect = 9 / 19.5;

  @override
  Widget build(BuildContext context) {
    final screen = DecoratedBox(
      decoration: BoxDecoration(gradient: background ?? Palette.main.background),
      child: child,
    );

    return ColoredBox(
      color: AppColors.frame,
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth <= phoneMaxWidth) return SizedBox.expand(child: screen);

          // 広い画面: スマホの形の画面を、ウィンドウに収まる最大サイズまで等倍で拡大する
          return Center(
            child: AspectRatio(
              aspectRatio: designAspect,
              child: FittedBox(
                child: SizedBox(width: designWidth, height: designWidth / designAspect, child: screen),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// アプリ全体の枠（MaterialApp の builder で、いちばん外に置く）。
/// PC など広い画面では、アプリ全体をスマホの形（[PhoneFrame.designWidth] × 縦横比 [PhoneFrame.designAspect]）に
/// 収めて、そのまま拡大・縮小する。ダイアログ・下から出るシート・通知もこの中に出るので、
/// スマホの形の外にはみ出さない。スマホ（幅 [PhoneFrame.phoneMaxWidth] 以下）では何もしない。
class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth <= PhoneFrame.phoneMaxWidth) return child;
        const w = PhoneFrame.designWidth;
        const h = w / PhoneFrame.designAspect;
        final mq = MediaQuery.of(context);
        return ColoredBox(
          color: AppColors.frame,
          child: Center(
            child: AspectRatio(
              aspectRatio: PhoneFrame.designAspect,
              child: FittedBox(
                child: SizedBox(
                  width: w,
                  height: h,
                  // 中の画面には「スマホの大きさの画面」だと伝える（シートの高さなどが、枠に合うように）
                  child: MediaQuery(
                    data: mq.copyWith(
                      size: const Size(w, h),
                      padding: EdgeInsets.zero,
                      viewPadding: EdgeInsets.zero,
                      viewInsets: EdgeInsets.zero,
                    ),
                    child: ClipRect(child: child),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 戻るボタン + 見出し（ホーム以外の明るい画面で共通）
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    required this.onBack,
    required this.palette,
    this.icon = Icons.close_rounded,
    this.trailing,
  });

  /// 左のボタンのアイコン（どの画面も ✕ で閉じる）
  final IconData icon;

  /// 右はしに置くもの（ボタンなど）
  final Widget? trailing;

  final String title;
  final VoidCallback onBack;
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          PushButton.circle(
            face: palette.card.face,
            edge: palette.card.edge,
            border: palette.card.border,
            onPressed: onBack,
            child: Icon(icon, color: palette.card.content),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: sans(22, weight: FontWeight.w800, color: palette.text),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}
