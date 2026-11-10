import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/bosses.dart';
import '../services/boss_battle.dart';
import '../state/providers.dart';
import '../state/records.dart';
import '../theme.dart';
import '../widgets/phone_frame.dart';

/// ボス選び: テーマごとの哲学者ボス。これまでの戦績も出す
class BossSelectScreen extends ConsumerWidget {
  const BossSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const p = Palette.main;
    final topics = ref.watch(topicsProvider);
    final battles = ref.watch(battleRecordsProvider);

    return Scaffold(
      body: PhoneFrame(
        background: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A1414), AppColors.paperBottom],
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(title: 'BATTLE', palette: p, onBack: () => context.go('/topics')),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 20, 6),
                child: Text(
                  '立場を選んで、反対側の哲学者に挑もう。\n強い反論ほど、ボスの「確信」を削れる。',
                  style: sans(12, weight: FontWeight.w700, color: AppColors.bodyText, height: 1.7),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                  children: [
                    for (final t in topics)
                      if (bossesFor(t.id) case final pair when pair.length == 2)
                        _BossCard(
                          bosses: pair,
                          topicTitle: t.title,
                          image: t.image,
                          history: battles.where((r) => r.topicId == t.id).toList(),
                          onTap: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => _BattleSetupSheet(
                              bosses: pair,
                              question: battleQuestions[t.id] ?? t.title,
                              cleared: {
                                for (final r in battles.where((r) => r.topicId == t.id && r.won)) '${r.boss}${r.stars}',
                              },
                              onPick: (vs, d) {
                                Navigator.of(context).pop();
                                context.go('/topics/${t.id}/boss?level=${d.stars}&vs=$vs');
                              },
                            ),
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

class _BossCard extends StatelessWidget {
  const _BossCard({
    required this.bosses,
    required this.topicTitle,
    required this.image,
    required this.history,
    required this.onTap,
  });

  /// そのテーマの2人（反対の立場）
  final List<Boss> bosses;
  final String topicTitle;
  final String image;
  final List<BattleRecord> history;
  final VoidCallback onTap;

  static const _gold = Color(0xFFFFD54F);

  @override
  Widget build(BuildContext context) {
    final won = history.any((r) => r.won);
    final bestStars = history.where((r) => r.won).fold(0, (a, r) => r.stars > a ? r.stars : a);
    final best = history.isEmpty ? null : history.map((r) => r.damage).reduce((a, b) => a > b ? a : b);
    final question = battleQuestions[bosses.first.topicId] ?? topicTitle;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: won ? _gold : AppColors.red, width: 2),
          boxShadow: const [BoxShadow(color: Color(0xAA000000), offset: Offset(4, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // テーマの絵をうっすら
            Positioned.fill(
              child: Opacity(
                opacity: 0.18,
                child: Image.asset(image, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        topicTitle,
                        style: sans(12, weight: FontWeight.w800, color: AppColors.accent),
                      ),
                      const SizedBox(width: 6),
                      if (won)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(4)),
                          child: Text(
                            'CLEAR ${'★' * bestStars}',
                            style: sans(9, weight: FontWeight.w800, color: const Color(0xFF16181A)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(question, style: serif(16, weight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  // 2人の哲学者（反対の立場）
                  Row(
                    children: [
                      Expanded(child: _Side(boss: bosses[0])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          'VS',
                          style: sans(
                            15,
                            weight: FontWeight.w800,
                            color: AppColors.red,
                          ).copyWith(fontStyle: FontStyle.italic),
                        ),
                      ),
                      Expanded(child: _Side(boss: bosses[1])),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        best == null ? 'はじめての挑戦' : '最高ダメージ $best・${history.length}回挑戦',
                        style: sans(11, weight: FontWeight.w700, color: AppColors.muted),
                      ),
                      const Spacer(),
                      Text(
                        '立場を選んで挑む ›',
                        style: sans(13, weight: FontWeight.w800, color: won ? _gold : AppColors.red),
                      ),
                    ],
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

/// カードの中の、哲学者1人と立場
class _Side extends StatelessWidget {
  const _Side({required this.boss});

  final Boss boss;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.ink.withValues(alpha: 0.8), width: 2),
          ),
          child: ClipOval(child: Image.asset(boss.portrait, width: 42, height: 42, fit: BoxFit.cover)),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 長い名前（ウィトゲンシュタイン）も切らずに縮める
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(boss.name, maxLines: 1, style: sans(12, weight: FontWeight.w800)),
              ),
              Text(
                '「${boss.stance}」',
                maxLines: 2,
                style: sans(11, weight: FontWeight.w700, color: AppColors.bodyText, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 立場（＝戦う相手）と、難しさ（★1〜★3）を選ぶ
class _BattleSetupSheet extends StatefulWidget {
  const _BattleSetupSheet({required this.bosses, required this.question, required this.cleared, required this.onPick});

  final List<Boss> bosses;
  final String question;

  /// 勝ったことのある「ボスの名前＋★の数」
  final Set<String> cleared;

  /// どちらのボスと（0 / 1）、どの難しさで
  final void Function(int vs, Difficulty d) onPick;

  @override
  State<_BattleSetupSheet> createState() => _BattleSetupSheetState();
}

class _BattleSetupSheetState extends State<_BattleSetupSheet> {
  /// 選んだ相手（まだなら null）
  int? _vs;

  @override
  Widget build(BuildContext context) {
    final vs = _vs;
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 430, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: const BoxDecoration(
            color: AppColors.paperBottom,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
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
                  const SizedBox(height: 14),
                  Text(widget.question, style: serif(17, weight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    '1. あなたの立場を選ぼう（反対側の哲学者と戦う）',
                    style: sans(12, weight: FontWeight.w700, color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < widget.bosses.length; i++)
                    _StanceTile(
                      // あなたの立場は、相手（i）の反対側
                      yours: widget.bosses[1 - i].stance,
                      boss: widget.bosses[i],
                      selected: vs == i,
                      onTap: () => setState(() => _vs = i),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    '2. 難しさを選んで、はじめる',
                    style: sans(12, weight: FontWeight.w700, color: AppColors.muted),
                  ),
                  const SizedBox(height: 10),
                  // 立場を選ぶまでは押せない
                  IgnorePointer(
                    ignoring: vs == null,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: vs == null ? 0.35 : 1,
                      child: Column(
                        children: [
                          for (final d in Difficulty.values)
                            _DifficultyTile(
                              difficulty: d,
                              cleared: vs != null && widget.cleared.contains('${widget.bosses[vs].name}${d.stars}'),
                              onTap: () => widget.onPick(vs!, d),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 立場の選択肢: 「あなた: 〇〇」 → 相手の哲学者
class _StanceTile extends StatelessWidget {
  const _StanceTile({required this.yours, required this.boss, required this.selected, required this.onTap});

  final String yours;
  final Boss boss;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.ink : AppColors.ink.withValues(alpha: 0.35), width: 2),
          boxShadow: selected ? const [BoxShadow(color: Color(0x99000000), offset: Offset(3, 3))] : null,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: selected ? AppColors.onNavy : AppColors.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'あなた: 「$yours」',
                    style: sans(15, weight: FontWeight.w800, color: selected ? AppColors.onNavy : AppColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '相手: ${boss.name}（${boss.stance}）',
                    style: sans(11, weight: FontWeight.w700, color: selected ? AppColors.accent : AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ClipOval(child: Image.asset(boss.portrait, width: 36, height: 36, fit: BoxFit.cover)),
          ],
        ),
      ),
    );
  }
}

class _DifficultyTile extends StatelessWidget {
  const _DifficultyTile({required this.difficulty, required this.cleared, required this.onTap});

  final Difficulty difficulty;
  final bool cleared;
  final VoidCallback onTap;

  static const _gold = Color(0xFFFFD54F);

  @override
  Widget build(BuildContext context) {
    final d = difficulty;
    final color = switch (d) {
      Difficulty.easy => AppColors.xpGreen,
      Difficulty.normal => AppColors.accent,
      Difficulty.hard => AppColors.red,
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color, width: 2),
          boxShadow: const [BoxShadow(color: Color(0x99000000), offset: Offset(3, 3))],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 70,
              child: Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Icon(
                      i < d.stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 22,
                      color: i < d.stars ? _gold : AppColors.muted.withValues(alpha: 0.5),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        d.label,
                        style: sans(15, weight: FontWeight.w800, color: color),
                      ),
                      if (cleared) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle_rounded, size: 16, color: _gold),
                      ],
                    ],
                  ),
                  Text(
                    'ボスの確信（HP） ${d.bossHp}・ヒント ${d.unlimitedHints
                        ? 'あり'
                        : d.hints == 0
                        ? 'なし'
                        : '${d.hints}回まで'}',
                    style: sans(11, color: AppColors.bodyText),
                  ),
                  Text(
                    '勝利: +${d.winXp} EXP・ちびのう +${d.winBrains}',
                    style: sans(11, weight: FontWeight.w700, color: AppColors.xpGreenLight),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
