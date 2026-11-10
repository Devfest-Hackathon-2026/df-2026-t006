import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../services/depth_grader.dart';
import '../state/providers.dart';
import '../state/thinking_style.dart';
import '../theme.dart';
import '../widgets/phone_frame.dart';
import '../widgets/push_button.dart';

/// プロフィール: 思考スタイル（あなたの「型」と二つ名）と、考え方がどう変わってきたか。
/// TODO: アカウント機能ができたら、名前・アイコンの変更もここで
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const p = Palette.main;
    final style = ref.watch(thinkingStyleProvider);
    final player = ref.watch(playerProvider);

    return Scaffold(
      body: PhoneFrame(
        background: p.background,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(title: 'プロフィール', palette: p, onBack: () => context.go('/')),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    // レベル（大きく、思考スタイルの上に）
                    _Level(player: player),
                    const SizedBox(height: 16),
                    style == null ? const _UnknownCard() : _IdentityCard(style: style, name: player.name),
                    // 考え方の変化は、押すと見られる
                    if (style != null) ...[
                      const SizedBox(height: 16),
                      _OpenChanges(
                        onTap: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => _ChangesSheet(style: style),
                        ),
                      ),
                    ],
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

/// 思考スタイルのカード（大きなエンブレム・型・二つ名・深度）
class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.style, required this.name});

  final ThinkingStyle style;
  final String name;

  @override
  Widget build(BuildContext context) {
    final a = style.archetype;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(a.color, Colors.black, 0.35)!, AppColors.navyDeep],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ink, width: 2),
        boxShadow: const [BoxShadow(color: Color(0xAA000000), offset: Offset(5, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '思考スタイル',
                style: sans(11, weight: FontWeight.w800, color: AppColors.onNavy, spacing: 2),
              ),
              const Spacer(),
              Text(
                name,
                style: sans(11, weight: FontWeight.w800, color: AppColors.accent),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Emblem(archetype: a, size: 84),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (style.epithet.isNotEmpty)
                      Text(
                        style.epithet,
                        style: sans(13, weight: FontWeight.w800, color: a.color),
                      ),
                    Text(
                      a.title,
                      style: serif(28, weight: FontWeight.w800, color: AppColors.onNavy).copyWith(height: 1.25),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a.english,
                      style: sans(11, weight: FontWeight.w800, color: AppColors.accent, spacing: 3),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            a.description,
            style: sans(13, weight: FontWeight.w700, color: AppColors.onNavy, height: 1.6),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.water_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: 4),
              Text(
                '平均の深さ「${style.depth.name}」 ${style.averageScore.round()}点',
                style: sans(12, weight: FontWeight.w800, color: AppColors.onNavy),
              ),
              const Spacer(),
              Text(
                '${style.history.length}回の判定から',
                style: sans(10, weight: FontWeight.w700, color: AppColors.accent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// まだ判定がない時
class _UnknownCard extends StatelessWidget {
  const _UnknownCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.5), width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.4),
              border: Border.all(color: AppColors.muted, width: 2),
            ),
            child: Text(
              '？',
              style: serif(40, weight: FontWeight.w800, color: AppColors.muted),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '思考スタイル',
                  style: sans(11, weight: FontWeight.w800, color: AppColors.muted, spacing: 2),
                ),
                Text(
                  '？？？',
                  style: serif(26, weight: FontWeight.w800, color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                Text(
                  'テーマの最後で AI に深さを測ってもらうと、あなたの思考スタイルがわかります。',
                  style: sans(12, color: AppColors.bodyText, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 型のエンブレム（光る丸に、型のアイコン）
class _Emblem extends StatelessWidget {
  const _Emblem({required this.archetype, required this.size});

  final StyleArchetype archetype;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [archetype.color, Color.lerp(archetype.color, Colors.black, 0.55)!]),
        border: Border.all(color: AppColors.ink, width: 2.5),
        boxShadow: [BoxShadow(color: archetype.color.withValues(alpha: 0.55), blurRadius: 18)],
      ),
      child: Icon(archetype.icon, size: size * 0.5, color: Colors.white),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 24, 0, 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 6),
          Text(
            text,
            style: sans(13, weight: FontWeight.w800, color: AppColors.accent, spacing: 1),
          ),
        ],
      ),
    );
  }
}

/// 最初の型 → 今の型
class _StyleShift extends StatelessWidget {
  const _StyleShift({required this.style});

  final ThinkingStyle style;

  @override
  Widget build(BuildContext context) {
    Widget side(String label, StyleArchetype a) => Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: sans(10, weight: FontWeight.w800, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          _Emblem(archetype: a, size: 46),
          const SizedBox(height: 6),
          Text(
            a.title,
            textAlign: TextAlign.center,
            style: sans(12, weight: FontWeight.w800),
          ),
        ],
      ),
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              side('はじめ', style.first),
              const Icon(Icons.arrow_forward_rounded, color: AppColors.accent),
              side('いま', style.archetype),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            style.changed ? '考えるうちに、あなたの「型」が変わってきています。' : 'はじめから、ぶれない「型」を持っています。',
            style: sans(12, weight: FontWeight.w700, color: AppColors.bodyText),
          ),
        ],
      ),
    );
  }
}

/// 4つの観点の平均と、最初から最新への変化
class _Axes extends StatelessWidget {
  const _Axes({required this.style});

  final ThinkingStyle style;

  @override
  Widget build(BuildContext context) {
    final growth = style.history.length >= 2 ? style.axisGrowth : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          for (final (key, label) in depthAxes)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(label, style: sans(12, weight: FontWeight.w800)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (style.axes[key] ?? 0) / 25,
                        minHeight: 8,
                        color: style.archetype.color,
                        backgroundColor: Colors.black.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      growth == null
                          ? (style.axes[key] ?? 0).toStringAsFixed(0)
                          : '${growth[key]! >= 0 ? '↑' : '↓'}${growth[key]!.abs()}',
                      textAlign: TextAlign.right,
                      style: sans(
                        12,
                        weight: FontWeight.w800,
                        color: growth == null
                            ? AppColors.muted
                            : growth[key]! > 0
                            ? AppColors.xpGreenLight
                            : growth[key]! < 0
                            ? AppColors.red
                            : AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (growth != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('数字は、最初の判定から最新の判定までの変化（各25点）', style: sans(10, color: AppColors.muted)),
            ),
        ],
      ),
    );
  }
}

/// 7つの型の割合
class _PatternBars extends StatelessWidget {
  const _PatternBars({required this.style});

  final ThinkingStyle style;

  @override
  Widget build(BuildContext context) {
    final total = style.counts.values.fold(0, (a, b) => a + b);
    final sorted = [...archetypes]
      ..sort((a, b) => (style.counts[b.pattern] ?? 0).compareTo(style.counts[a.pattern] ?? 0));
    final maxCount = math.max(1, style.counts.values.fold(0, math.max));
    return Column(
      children: [
        for (final a in sorted.where((a) => (style.counts[a.pattern] ?? 0) > 0))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(a.icon, size: 18, color: a.color),
                const SizedBox(width: 6),
                SizedBox(
                  width: 92,
                  child: Text(a.title, style: sans(12, weight: FontWeight.w800)),
                ),
                Expanded(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: (style.counts[a.pattern] ?? 0) / maxCount,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(color: a.color, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ),
                SizedBox(
                  width: 44,
                  child: Text(
                    '${((style.counts[a.pattern] ?? 0) / total * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: sans(11, weight: FontWeight.w800, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// レベルと経験値（プロフィールのいちばん上）
class _Level extends StatelessWidget {
  const _Level({required this.player});

  final PlayerState player;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Lv.', style: sans(18, weight: FontWeight.w800, height: 1.1)),
            Text('${player.level}', style: sans(44, weight: FontWeight.w900, height: 1.0)),
            const Spacer(),
            Text(
              '${player.xpInLevel} / ${PlayerState.xpPerLevel} EXP',
              style: sans(13, weight: FontWeight.w800, color: AppColors.xpGreenLight),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            border: Border.all(color: AppColors.ink, width: 1.5),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: player.levelProgress.clamp(0, 1),
            child: const ColoredBox(color: AppColors.xpGreen),
          ),
        ),
      ],
    );
  }
}

/// 「考え方の変化を見る」ボタン
class _OpenChanges extends StatelessWidget {
  const _OpenChanges({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PushButton.colored(
      colors: Palette.main.card,
      height: 56,
      depth: 4,
      radius: 14,
      onPressed: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.trending_up_rounded, color: AppColors.accent),
          const SizedBox(width: 8),
          Text(
            '考え方の変化を見る',
            style: sans(15, weight: FontWeight.w800, color: Palette.main.card.content),
          ),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: Palette.main.card.content),
        ],
      ),
    );
  }
}

/// 考え方の変化（はじめ → いま・観点の伸び・型の割合）
class _ChangesSheet extends StatelessWidget {
  const _ChangesSheet({required this.style});

  final ThinkingStyle style;

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 430, maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          decoration: const BoxDecoration(
            color: AppColors.paperBottom,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
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
                  const _Title(icon: Icons.trending_up_rounded, text: '考え方の変化'),
                  if (style.history.length >= 2) _StyleShift(style: style),
                  _Axes(style: style),
                  const _Title(icon: Icons.pie_chart_rounded, text: 'あなたの中の「型」'),
                  _PatternBars(style: style),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
