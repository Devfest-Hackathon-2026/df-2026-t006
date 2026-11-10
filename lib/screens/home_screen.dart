import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/quotes.dart';
import '../state/missions.dart';
import '../state/brains.dart';
import '../state/providers.dart';
import '../data/news.dart';
import '../theme.dart';
import '../widgets/news_popup.dart';
import '../widgets/ad_banner.dart';
import '../widgets/gift_button.dart';
import '../widgets/home_backdrop.dart';
import '../widgets/phone_frame.dart';
import '../widgets/push_button.dart';
import '../widgets/quote_ticker.dart';
import '../widgets/start_button.dart';
import '../widgets/status_window.dart';

/// ホーム画面（ゲームのロビーのイメージ）。
///
///  [ステータス(Lv・EXP)      ] (設定)
///  ＝＝＝ 名言が流れる帯 ＝＝＝＝＝＝＝
///      背景: 古代エジプトの絵（5秒ごとに切り替わる）
///         [ロゴ型の はじめる]
///  [お知らせ] [ミッション] [記録] [図鑑]
///  [ 広告枠（仮） ]
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const p = Palette.main;
    final quoteLanguage = ref.watch(settingsProvider.select((s) => s.quoteLanguage));
    // アプリを開くたびに、お知らせ（イベント・新機能）を1つ。ホームがふわっと出てから
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 900), () {
        if (context.mounted) NewsPopup.showOncePerLaunch(context);
      });
    });
    // 下のボタンの大きさ
    const buttonSize = 62.0;

    return Scaffold(
      body: PhoneFrame(
        background: p.background,
        child: Stack(
          children: [
            // 動くもの（背景・名言の帯・ロゴ）は、それぞれ別に描きなおす（ほかの部分まで毎フレーム描かない）
            const Positioned.fill(child: RepaintBoundary(child: HomeBackdrop())),
            SafeArea(
              child: Column(
                children: [
                  // 画面の上端から少し離す
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 0),
                    child: Row(
                      children: [
                        Expanded(child: StatusWindow(onPortrait: () => context.go('/profile'))),
                        const SizedBox(width: 14),
                        PushButton.circle(
                          face: p.card.face,
                          edge: p.card.edge,
                          border: p.card.border,
                          size: 52,
                          onPressed: () => context.go('/settings'),
                          child: Icon(Icons.settings_rounded, color: p.card.content, size: 26),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 名言が流れる帯（画面の端から端まで）
                  RepaintBoundary(child: QuoteTicker(quotes: [for (final q in quotes) q.text(quoteLanguage)])),
                  // 右側: メールボックス
                  const Padding(
                    padding: EdgeInsets.fromLTRB(0, 14, 20, 0),
                    child: Align(alignment: Alignment.centerRight, child: GiftButton()),
                  ),
                  // 背景の絵を見せる余白（はじめるボタンを中央より少し下に置く）
                  // 背景の絵を見せる余白。イベント枠がない時は、余った分の一部を下にも回してボタンを上げる
                  const Spacer(flex: 5),
                  Padding(
                    // 下半分は画面の端から少し離す
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
                    child: Column(
                      children: [
                        // ロゴの形のはじめるボタン
                        // はじめての時だけ、脳の上に「おしてみて！」
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.topCenter,
                          children: [
                            RepaintBoundary(
                              child: StartButton(
                                onPressed: () {
                                  ref.read(startTappedProvider.notifier).set(true);
                                  context.go('/topics');
                                },
                              ),
                            ),
                            if (!ref.watch(startTappedProvider))
                              const Positioned(
                                top: -44,
                                child: IgnorePointer(child: RepaintBoundary(child: PressHint())),
                              ),
                          ],
                        ),
                        // テツルを少し下げる（イベント枠との間を詰める）
                        const SizedBox(height: 44),
                        // 小さいボタンの列（端からさらに少し内側に）
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _IconButton(
                                icon: Icons.campaign_rounded,
                                label: 'お知らせ',
                                colors: p.button,
                                labelColor: p.text,
                                size: buttonSize,
                                // 見ていないお知らせがある時だけ（お知らせを開くと消える）
                                badge: ref.watch(hasUnseenNewsProvider),
                                onPressed: () => context.go('/news'),
                              ),
                              _IconButton(
                                icon: Icons.flag_rounded,
                                label: 'ミッション',
                                colors: p.button,
                                labelColor: p.text,
                                size: buttonSize,
                                // 受け取れる報酬がある時は赤い点
                                badge: ref.watch(claimableMissionsProvider) > 0,
                                onPressed: () => context.go('/missions'),
                              ),
                              _IconButton(
                                icon: Icons.auto_stories_rounded,
                                label: '記録',
                                colors: p.button,
                                labelColor: p.text,
                                size: buttonSize,
                                onPressed: () => context.go('/records'),
                              ),
                              _IconButton(
                                icon: Icons.psychology_rounded,
                                label: 'ひたちゃん',
                                colors: p.button,
                                labelColor: p.text,
                                size: buttonSize,
                                // あげられるちびのうがある時は赤い点
                                badge: ref.watch(brainProvider.select((b) => b.stock)) > 0,
                                onPressed: () => context.go('/hitachan'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 画面の一番下にくっつかないよう余白をあける
                  const SizedBox(height: 20),
                  // 一番下の広告枠（仮。後で AdMob に差し替え）
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 28), child: AdBanner()),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// アイコン + 小さいラベルの四角いボタン
class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.label,
    required this.colors,
    required this.labelColor,
    required this.onPressed,
    this.size = 46,
    this.badge = false,
  });

  final IconData icon;
  final String label;
  final ButtonColors colors;
  final Color labelColor;
  final VoidCallback onPressed;

  /// ボタンの大きさ（イベント枠がない時は大きくする）
  final double size;

  /// 新着がある時の赤い点
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            PushButton.colored(
              colors: colors,
              width: size,
              height: size,
              depth: 4,
              radius: size * 0.28,
              onPressed: onPressed,
              child: Icon(icon, color: colors.content, size: size * 0.48),
            ),
            if (badge)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surface, width: 2),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          // 背景の画像の上でも読めるよう、うっすら影を付ける
          style: sans(
            11,
            weight: FontWeight.w800,
            color: labelColor,
          ).copyWith(shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 6)]),
        ),
      ],
    );
  }
}
