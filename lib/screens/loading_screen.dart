import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../brand.dart';
import '../services/cloud.dart';
import '../services/music.dart';
import '../state/brains.dart';
import '../widgets/gift_button.dart';
import '../theme.dart';
import '../widgets/phone_frame.dart';

/// 起動時のタイトル画面（ゲームの「タップしてスタート」のイメージ）。
///   1. 黒地にロゴがふわっと出る + スローガン
///   2. 読み込み中はバー（Firebaseのログインと保存データ）
///   3. 読み込みが終わると「画面をタップしてはじめる」が点滅
///   4. 画面をタップするとホームへ（router.dart でフェード）
/// 読み込み中にタップした場合は、終わりしだいホームへ進む。
class LoadingScreen extends ConsumerStatefulWidget {
  const LoadingScreen({super.key});

  /// 読み込みが一瞬で終わっても、ロゴを見せるために最低これだけ待つ
  static const minDuration = Duration(milliseconds: 1200);

  /// 起動時の読み込みが終わったか（終わるまでは、どの画面に来てもここへ戻す）
  static bool booted = false;

  @override
  ConsumerState<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends ConsumerState<LoadingScreen> with TickerProviderStateMixin {
  /// ロゴのフェードイン
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
    ..forward();

  /// 読み込みバー
  late final AnimationController _bar = AnimationController(vsync: this, duration: LoadingScreen.minDuration)
    ..forward();

  /// 「タップしてはじめる」の点滅
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  /// 画面を押した時: ロゴに吸いこまれるようにズームしながら暗転（そのあとプロローグかホームへ）
  late final AnimationController _exit = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  bool _ready = false;
  bool _tapped = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await Future.wait([
      Future<void>.delayed(LoadingScreen.minDuration),
      // Firebase: 匿名ログイン → 保存してあるデータを読み込む（つながらなくても続行）
      Cloud.init().then((_) => mounted ? Cloud.load(ref) : null),
    ]);
    if (!mounted) return;
    LoadingScreen.booted = true;
    // 1日1回のログインボーナスをメールで届ける
    ref.read(giftProvider.notifier).deliverToday();
    // ここから先の変更は自動で Firestore に保存
    ref.read(cloudSyncProvider);
    setState(() => _ready = true);
    _blink.repeat(reverse: true);
    if (_tapped) _enter();
  }

  void _onTap() {
    _tapped = true;
    if (_ready) _enter();
  }

  Future<void> _enter() async {
    if (_exit.isAnimating) return;
    HapticFeedback.lightImpact();
    // ブラウザは最初のタップまで音を出せないので、ここで BGM を始める
    Bgm.start();
    // いつも: ロゴへズーム → 真っ暗 → はじめての時はプロローグ（ひたちゃんのお話）、2回目からはホームがフェードイン
    await _exit.forward();
    if (mounted) context.go(ref.read(prologueSeenProvider) ? '/' : '/prologue');
  }

  @override
  void dispose() {
    _intro.dispose();
    _bar.dispose();
    _blink.dispose();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const p = Palette.main;

    return Scaffold(
      backgroundColor: logoBlack,
      body: PhoneFrame(
        background: const LinearGradient(colors: [logoBlack, logoBlack]),
        // 画面のどこをタップしても進む（PCではEnter/スペースでも）
        child: Focus(
          autofocus: true,
          onKeyEvent: (_, e) {
            if (e is KeyDownEvent &&
                (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.space)) {
              _onTap();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _onTap,
            child: LayoutBuilder(
              builder: (context, c) {
                final logo = c.maxWidth * 0.62;

                // ズームしても、スマホの画面の外にはみ出さない
                return ClipRect(
                  child: AnimatedBuilder(
                    animation: _exit,
                    builder: (context, child) {
                      final z = Curves.easeInCubic.transform(_exit.value);
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // ロゴの中心（脳）へ寄っていく
                          Transform.scale(scale: 1 + z * 7, alignment: const Alignment(0, -0.12), child: child),
                          // だんだん真っ暗に
                          IgnorePointer(
                            child: ColoredBox(
                              color: Colors.black.withValues(
                                alpha: Curves.easeIn.transform((_exit.value * 1.25).clamp(0, 1)),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // ロゴ + スローガン（ふわっと出る）
                        FadeTransition(
                          opacity: CurvedAnimation(parent: _intro, curve: Curves.easeOut),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              LogoImage(LogoAsset.full, width: logo, height: logo),
                              const SizedBox(height: 20),
                              // スローガン全体を「～ ～」で囲み、斜体・少し灰色に。
                              // 日本語フォントには斜体がないので、少し傾けて斜体にする
                              Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.skewX(-0.2),
                                child: Text(
                                  '～$slogan、ひたすらテツガク～',
                                  style: serif(
                                    16,
                                    weight: FontWeight.w600,
                                    color: AppColors.muted,
                                  ).copyWith(letterSpacing: 3, height: 1),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // 下: 読み込み中はバー、終わったら「画面をタップしてはじめる」
                        Positioned(
                          bottom: 72,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: _ready
                                ? FadeTransition(
                                    key: const ValueKey('tap'),
                                    opacity: Tween(
                                      begin: 0.25,
                                      end: 1.0,
                                    ).animate(CurvedAnimation(parent: _blink, curve: Curves.easeInOut)),
                                    child: Text(
                                      '画面をタップしてはじめる',
                                      style: sans(14, weight: FontWeight.w700).copyWith(letterSpacing: 3),
                                    ),
                                  )
                                : AnimatedBuilder(
                                    key: const ValueKey('bar'),
                                    animation: _bar,
                                    builder: (context, _) =>
                                        _Bar(value: Curves.easeOut.transform(_bar.value), palette: p),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 角ばった読み込みバー（ステータスのEXPバーと同じ見た目）
class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.palette});

  final double value;
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 10,
      decoration: BoxDecoration(
        color: palette.meterTrack,
        border: Border.all(color: palette.text, width: 1.5),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: value,
        child: ColoredBox(color: palette.meter),
      ),
    );
  }
}
