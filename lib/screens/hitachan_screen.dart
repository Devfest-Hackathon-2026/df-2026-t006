import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/brains.dart';
import '../state/mail.dart';
import '../theme.dart';
import '../widgets/hitachan.dart';
import '../widgets/phone_frame.dart';
import '../widgets/push_button.dart';

/// ひたちゃん: 集めたちびのうをあげて、最後のひたちゃんを育てる
class HitachanScreen extends ConsumerStatefulWidget {
  const HitachanScreen({super.key});

  @override
  ConsumerState<HitachanScreen> createState() => _HitachanScreenState();
}

class _HitachanScreenState extends ConsumerState<HitachanScreen> with TickerProviderStateMixin {
  /// ちびのうが飛んでいくアニメーション
  late final AnimationController _feed = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  /// 食べた時に、ぽよんとはねる
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  int _flying = 0;

  Future<void> _feedAll() async {
    final stock = ref.read(brainProvider).stock;
    if (stock == 0 || _feed.isAnimating) return;
    HapticFeedback.lightImpact();
    setState(() => _flying = math.min(stock, 8));
    await _feed.forward(from: 0);
    if (!mounted) return;
    final grew = ref.read(brainProvider.notifier).feedAll();
    setState(() => _flying = 0);
    HapticFeedback.mediumImpact();
    _bounce.forward(from: 0);
    if (grew && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      unawaited(
        showDialog<void>(
          context: context,
          builder: (_) => _GrewDialog(state: ref.read(brainProvider)),
        ),
      );
    }
  }

  @override
  void dispose() {
    _feed.dispose();
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const p = Palette.main;
    final b = ref.watch(brainProvider);
    final next = b.nextStage;

    return Scaffold(
      body: PhoneFrame(
        background: p.background,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                title: 'ひたちゃん',
                palette: p,
                icon: Icons.close_rounded,
                onBack: () => context.go('/'),
                // 遊び方は「？」の中に
                trailing: PushButton.circle(
                  face: p.card.face,
                  edge: p.card.edge,
                  border: p.card.border,
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const _HelpSheet(),
                  ),
                  child: Icon(Icons.question_mark_rounded, color: p.card.content),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    // ひたちゃんと、ひとこと
                    Container(
                      height: 400,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.ink, width: 1.5),
                        boxShadow: const [BoxShadow(color: Color(0x99000000), offset: Offset(4, 4))],
                        image: const DecorationImage(
                          image: AssetImage('assets/prologue/p2_arcadian.jpg'),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(Color(0x99101418), BlendMode.darken),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(top: 14, left: 16, right: 16, child: _Bubble(text: b.stage.message)),
                          Positioned(
                            bottom: 4,
                            child: AnimatedBuilder(
                              animation: _bounce,
                              builder: (context, child) {
                                final v = math.sin(_bounce.value * math.pi) * (1 - _bounce.value);
                                return Transform.scale(scaleY: 1 - v * 0.12, scaleX: 1 + v * 0.1, child: child);
                              },
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 500),
                                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                                child: Hitachan(
                                  key: ValueKey(b.stageIndex),
                                  stage: b.stageIndex,
                                  size: 300,
                                  lively: true,
                                ),
                              ),
                            ),
                          ),
                          // 飛んでいくちびのう
                          if (_flying > 0)
                            AnimatedBuilder(
                              animation: _feed,
                              builder: (context, _) => Stack(
                                children: [
                                  for (var k = 0; k < _flying; k++)
                                    _FlyingBrain(t: (_feed.value * 1.6 - k * 0.08).clamp(0.0, 1.0), index: k),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 段階と、次までの進み
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'すがた',
                          style: sans(12, weight: FontWeight.w800, color: AppColors.accent),
                        ),
                        const SizedBox(width: 8),
                        Text(b.stage.name, style: serif(24, weight: FontWeight.w800)),
                        const Spacer(),
                        Text(
                          next == null ? 'これ以上ない育ち！' : 'つぎ「${next.name}」まで ${next.need - b.fed}',
                          style: sans(12, weight: FontWeight.w800, color: AppColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        for (var k = 0; k < hitaStages.length; k++) ...[
                          Expanded(
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(
                                color: k < b.stageIndex
                                    ? AppColors.accent
                                    : k == b.stageIndex
                                    ? AppColors.navy
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(color: AppColors.ink.withValues(alpha: k == b.stageIndex ? 1 : 0.3)),
                              ),
                              child: k == b.stageIndex
                                  ? FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: b.progress.clamp(0, 1),
                                      child: const ColoredBox(color: AppColors.accent),
                                    )
                                  : null,
                            ),
                          ),
                          if (k < hitaStages.length - 1) const SizedBox(width: 4),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 持っているちびのうと、あげるボタン
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      decoration: BoxDecoration(
                        color: AppColors.navy,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.ink, width: 1.5),
                        boxShadow: const [BoxShadow(color: Color(0x99000000), offset: Offset(4, 4))],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const ChibinoIcon(size: 26),
                              const SizedBox(width: 8),
                              Text(
                                'ちびのう',
                                style: sans(15, weight: FontWeight.w800, color: AppColors.onNavy),
                              ),
                              const Spacer(),
                              Text(
                                '× ${b.stock}',
                                style: sans(26, weight: FontWeight.w800, color: AppColors.onNavy),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          PushButton.colored(
                            colors: b.stock > 0 ? p.primary : p.card,
                            height: 50,
                            depth: 4,
                            radius: 14,
                            // ちびのうがない時: メールに届いていればメールへ、なければホームへ（考えて集めに行く）
                            onPressed: b.stock > 0
                                ? _feedAll
                                : () => context.go(ref.read(unreadBrainsProvider) > 0 ? '/mail' : '/'),
                            child: Text(
                              b.stock > 0
                                  ? 'ちびのうをあげる'
                                  : ref.watch(unreadBrainsProvider) > 0
                                  ? 'メールに ${ref.watch(unreadBrainsProvider)} 個 届いています'
                                  : 'ちびのうを集めよう ›',
                              style: sans(
                                15,
                                weight: FontWeight.w800,
                                color: b.stock > 0 ? AppColors.onNavy : p.card.content,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 9),
        decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(14)),
        child: Text(
          text,
          style: sans(14, weight: FontWeight.w800, color: const Color(0xFF16181A)),
        ),
      ),
    );
  }
}

/// 下からひたちゃんへ飛んでいく、ちびのう1つ
class _FlyingBrain extends StatelessWidget {
  const _FlyingBrain({required this.t, required this.index});

  final double t;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (t <= 0 || t >= 1) return const SizedBox.shrink();
    final startX = -120.0 + (index % 4) * 80;
    final x = startX * (1 - t);
    final y = 140 - t * 120 - math.sin(t * math.pi) * 60;
    return Positioned.fill(
      child: Align(
        alignment: Alignment.center,
        child: Transform.translate(
          offset: Offset(x, y),
          child: Opacity(opacity: 1 - t * 0.6, child: const ChibinoIcon(size: 22)),
        ),
      ),
    );
  }
}

class _HowTo extends StatelessWidget {
  const _HowTo({required this.icon, required this.title, required this.detail});

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: sans(13, weight: FontWeight.w800)),
                Text(detail, style: sans(11, color: AppColors.muted, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GrewDialog extends StatelessWidget {
  const _GrewDialog({required this.state});

  final BrainState state;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.ink, width: 2),
          boxShadow: const [BoxShadow(color: Color(0xAA000000), offset: Offset(5, 5))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ひたちゃんが育った！',
              style: sans(19, weight: FontWeight.w800, color: AppColors.onNavy),
            ),
            const SizedBox(height: 4),
            Hitachan(stage: state.stageIndex, size: 170),
            Text(
              '「${state.stage.name}」になった',
              style: serif(18, weight: FontWeight.w800, color: AppColors.onNavy),
            ),
            const SizedBox(height: 4),
            Text('「${state.stage.message}」', style: sans(13, color: AppColors.accent)),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'やったね',
                style: sans(14, weight: FontWeight.w800, color: AppColors.onNavy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 遊び方（右上の「？」）
class _HelpSheet extends StatelessWidget {
  const _HelpSheet();

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: AppColors.paperBottom,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('ひたちゃんの育て方', style: sans(18, weight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'ちびのうをあげると、ひたちゃんは「しぼみ」から「哲人」まで育ちます。\n'
                  'ちびのうは、AI（Gemini）が「ちゃんと考えた」と判定した時だけもらえます。'
                  'たくさん遊ぶと増えるのは EXP、深く考えると増えるのがちびのう。',
                  style: sans(13, color: AppColors.bodyText, height: 1.7),
                ),
                const SizedBox(height: 14),
                const _HowTo(
                  icon: Icons.water_rounded,
                  title: 'リールで深く考える',
                  detail: '最後のカードでAIに深さを測ってもらう\n浅瀬 1・中層 2・深海 3・海溝 5',
                ),
                const _HowTo(icon: Icons.sync_alt_rounded, title: '反論を読んで考えを変える', detail: '1つのカードにつき 1'),
                const _HowTo(
                  icon: Icons.local_fire_department_rounded,
                  title: 'ボス戦で理由をぶつける',
                  detail: 'ヒット 1・クリティカル 2・勝利 +5',
                ),
                const SizedBox(height: 4),
                Text('ひたちゃんを押すと、ぴょんと跳ねます。', style: sans(12, color: AppColors.muted)),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go('/prologue');
                    },
                    icon: const Icon(Icons.auto_stories_rounded, size: 18, color: AppColors.accent),
                    label: Text(
                      'ひたちゃんのおはなしを、もう一度見る',
                      style: sans(13, weight: FontWeight.w800, color: AppColors.accent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
