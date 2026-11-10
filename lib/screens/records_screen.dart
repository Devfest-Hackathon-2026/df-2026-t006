import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/bosses.dart';
import '../models/think_card.dart';
import '../screens/battle_screen.dart';
import '../services/depth_grader.dart';
import '../state/providers.dart';
import '../state/records.dart';
import '../theme.dart';
import '../widgets/hitachan.dart';
import '../widgets/phone_frame.dart';
import '../widgets/revisit.dart';

/// 記録: 考え中のテーマ（続きから）と、考えきったテーマ（日時・進み具合・最後に書いたこと）
class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  /// 見ている方: false = リール、true = ボス戦
  bool _battles = false;

  @override
  Widget build(BuildContext context) {
    const p = Palette.main;
    final records = ref.watch(recordsProvider);
    final battles = ref.watch(battleRecordsProvider);
    final topics = ref.watch(topicsProvider);
    // 途中まで考えたテーマ（1枚目より先に進んでいる）
    final inProgress = [
      for (final t in topics)
        if (ref.watch(sessionProvider(t.id)).index > 0) t,
    ];

    return Scaffold(
      body: PhoneFrame(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(title: '記録', palette: p, onBack: () => context.go('/')),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  children: [
                    _Summary(
                      count: records.length,
                      wins: battles.where((b) => b.won).length,
                      xp: records.fold(0, (a, r) => a + r.xp),
                    ),
                    const SizedBox(height: 16),
                    // リール / ボス戦 を切りかえる（たまっても、すぐ見たい方へ行ける）
                    Row(
                      children: [
                        Expanded(
                          child: _Tab(
                            icon: Icons.view_day_rounded,
                            label: 'リール',
                            count: records.length,
                            selected: !_battles,
                            onTap: () => setState(() => _battles = false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _Tab(
                            icon: Icons.local_fire_department_rounded,
                            label: 'ボス戦',
                            count: battles.length,
                            selected: _battles,
                            onTap: () => setState(() => _battles = true),
                          ),
                        ),
                      ],
                    ),
                    if (!_battles && inProgress.isNotEmpty) ...[
                      const _SectionTitle(icon: Icons.hourglass_top_rounded, text: '考え中'),
                      for (final t in inProgress)
                        _RecordTile(
                          topic: t,
                          progress: ref.watch(sessionProvider(t.id)).index,
                          total: t.cards.length,
                          subtitle: '${ref.watch(sessionProvider(t.id)).index + 1}枚目まで',
                          trailing: '続きから ›',
                          onTap: () => context.go('/topics/${t.id}'),
                        ),
                    ],
                    // 時間をおいて、もう一度答えた問い（widgets/revisit.dart）
                    if (!_battles) const RevisitHistory(),
                    if (!_battles) const _SectionTitle(icon: Icons.verified_rounded, text: '考えきった'),
                    if (!_battles && records.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'まだありません。\nテーマを最後まで考えると、ここに残ります。',
                          textAlign: TextAlign.center,
                          style: sans(13, color: AppColors.muted, height: 1.8),
                        ),
                      ),
                    if (!_battles)
                      for (final r in records)
                        if (topics.where((t) => t.id == r.topicId).firstOrNull case final t?)
                          _RecordTile(
                            topic: t,
                            progress: r.answered,
                            total: r.total,
                            subtitle: formatDateTime(r.finishedAt),
                            trailing: '+${r.xp} EXP',
                            detail: r,
                          ),
                    if (_battles) const SizedBox(height: 16),
                    if (_battles && battles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'まだありません。\nテーマ選択の「BATTLE」から、哲学者ボスに挑もう。',
                          textAlign: TextAlign.center,
                          style: sans(13, color: AppColors.muted, height: 1.8),
                        ),
                      ),
                    if (_battles)
                      for (final b in battles)
                        _BattleTile(
                          record: b,
                          topic: topics.where((t) => t.id == b.topicId).firstOrNull,
                          onRetry: () {
                            final vs = bossesFor(b.topicId).indexWhere((x) => x.name == b.boss);
                            context.go('/topics/${b.topicId}/boss?level=${b.stars}&vs=${vs < 0 ? 0 : vs}');
                          },
                          onOpen: () => showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) =>
                                _BattleLogSheet(record: b, topic: topics.where((t) => t.id == b.topicId).firstOrNull),
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

class _Summary extends StatelessWidget {
  const _Summary({required this.count, required this.wins, required this.xp});

  final int count;
  final int wins;
  final int xp;

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, String value) => Expanded(
      child: Column(
        children: [
          Text(value, style: sans(22, weight: FontWeight.w800)),
          Text(
            label,
            style: sans(11, weight: FontWeight.w700, color: AppColors.muted),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink, width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x99000000), offset: Offset(4, 4))],
      ),
      child: Row(children: [stat('考えきったテーマ', '$count'), stat('ボスに勝った', '$wins'), stat('もらった EXP', '$xp')]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 0, 10),
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

/// 記録1つ: 左にテーマの絵、右に題名・日時・進み具合
class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.topic,
    required this.progress,
    required this.total,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    this.detail,
  });

  final Topic topic;
  final int progress;
  final int total;
  final String subtitle;
  final String trailing;
  final VoidCallback? onTap;

  /// 考えきった記録なら、考えを変えた回数と最後に書いたことも出す
  final TopicRecord? detail;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.ink.withValues(alpha: 0.35)),
            boxShadow: const [BoxShadow(color: Color(0x88000000), offset: Offset(3, 3))],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: d != null ? 58 : 78,
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.mode(Color(0x33000000), BlendMode.darken),
                    child: Image.asset(topic.image, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: d != null
                        ? const EdgeInsets.fromLTRB(12, 9, 12, 10)
                        : const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(topic.title, style: sans(15, weight: FontWeight.w800)),
                            ),
                            // 考え中のテーマだけ「続きから ›」（考えきった記録は、深さと型だけ）
                            if (d == null)
                              Text(
                                trailing,
                                style: sans(11, weight: FontWeight.w800, color: AppColors.xpGreenLight),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded, size: 12, color: AppColors.muted),
                            const SizedBox(width: 4),
                            Text(
                              subtitle,
                              style: sans(11, weight: FontWeight.w700, color: AppColors.muted),
                            ),
                          ],
                        ),
                        // 進み具合（考え中のテーマだけ）
                        if (d == null) const SizedBox(height: 8),
                        if (d == null)
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: total == 0 ? 0 : progress / total,
                                    minHeight: 6,
                                    backgroundColor: AppColors.ink.withValues(alpha: 0.12),
                                    color: d != null ? AppColors.xpGreen : AppColors.accent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('$progress/$total', style: sans(11, weight: FontWeight.w800)),
                            ],
                          ),
                        if (d != null) ...[
                          const SizedBox(height: 7),
                          if (d.grade case final g?)
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _Chip(icon: Icons.water_rounded, text: '深さ ${g.depth.name}・${g.score}点', strong: true),
                                _Chip(icon: Icons.psychology_rounded, text: patternOf(g.pattern).name),
                              ],
                            )
                          else
                            Text(
                              'AIの判定なし',
                              style: sans(11, weight: FontWeight.w700, color: AppColors.muted),
                            ),
                        ],
                      ],
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

/// 記録の小さなラベル（深さ・思考パターン）
class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, this.strong = false});

  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 9, 3),
      decoration: BoxDecoration(
        color: strong ? AppColors.navy : AppColors.navyDeep,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(
            text,
            style: sans(11, weight: FontWeight.w800, color: AppColors.onNavy),
          ),
        ],
      ),
    );
  }
}

/// ボス戦の記録1つ: ボスの顔・勝敗・日時・与えたダメージ・いちばん効いた反論
class _BattleTile extends StatelessWidget {
  const _BattleTile({required this.record, required this.topic, required this.onRetry, required this.onOpen});

  final BattleRecord record;
  final Topic? topic;
  final VoidCallback onRetry;

  /// タップで、やりとりの全部を開く
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final boss = bossNamed(r.topicId, r.boss);
    final color = r.won ? const Color(0xFFFFD54F) : AppColors.muted;
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: r.won ? color.withValues(alpha: 0.7) : AppColors.ink.withValues(alpha: 0.35)),
          boxShadow: const [BoxShadow(color: Color(0x88000000), offset: Offset(3, 3))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: r.won ? color : AppColors.red, width: 2),
                  ),
                  child: ClipOval(
                    child: boss == null
                        ? const SizedBox(width: 44, height: 44)
                        : ColorFiltered(
                            colorFilter: ColorFilter.mode(
                              r.won ? Colors.grey : Colors.transparent,
                              r.won ? BlendMode.saturation : BlendMode.dst,
                            ),
                            child: Image.asset(boss.portrait, width: 44, height: 44, fit: BoxFit.cover),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: r.won ? color : AppColors.quietFace,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              r.won ? 'WIN' : 'LOSE',
                              style: sans(
                                10,
                                weight: FontWeight.w800,
                                color: r.won ? const Color(0xFF16181A) : AppColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${r.boss}・${topic?.title ?? ''}',
                              overflow: TextOverflow.ellipsis,
                              style: sans(14, weight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${'★' * r.stars}  ${formatDateTime(r.finishedAt)}・${r.turns}ターン',
                        style: sans(11, weight: FontWeight.w700, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                if (r.brains > 0) ...[
                  const ChibinoIcon(size: 16),
                  Text(' +${r.brains}', style: sans(12, weight: FontWeight.w800)),
                ],
              ],
            ),
            const SizedBox(height: 10),
            // 与えたダメージ
            Row(
              children: [
                Text(
                  'ダメージ',
                  style: sans(11, weight: FontWeight.w800, color: AppColors.muted),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: r.damage / r.bossMaxHp,
                      minHeight: 7,
                      color: AppColors.red,
                      backgroundColor: Colors.black.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${r.damage}/${r.bossMaxHp}', style: sans(11, weight: FontWeight.w800)),
              ],
            ),
            if (r.bestAttack.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'いちばん効いた反論（${r.bestDamage}ダメージ）',
                      style: sans(10, weight: FontWeight.w800, color: AppColors.navy),
                    ),
                    Text(
                      '「${r.bestAttack}」',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: sans(12, weight: FontWeight.w700, color: const Color(0xFF16181A), height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onOpen,
                  child: Text(
                    'やりとりを見る ›',
                    style: sans(12, weight: FontWeight.w800, color: AppColors.ink),
                  ),
                ),
                TextButton(
                  onPressed: onRetry,
                  child: Text(
                    r.won ? 'もう一度戦う ›' : 'リベンジする ›',
                    style: sans(12, weight: FontWeight.w800, color: AppColors.accent),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// ボス戦の記録を開いた時: やりとりの全部
class _BattleLogSheet extends StatelessWidget {
  const _BattleLogSheet({required this.record, required this.topic});

  final BattleRecord record;
  final Topic? topic;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final boss = bossNamed(r.topicId, r.boss);
    final yours = boss == null ? null : rivalOf(boss)?.stance;
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 430, maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        child: Container(
          width: double.infinity,
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
                const SizedBox(height: 12),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r.won ? 'WIN' : 'LOSE'}・${r.boss}・${topic?.title ?? ''}',
                              style: sans(16, weight: FontWeight.w800),
                            ),
                            Text(
                              '${'★' * r.stars}  ${formatDateTime(r.finishedAt)}・${r.turns}ターン・${r.damage}/${r.bossMaxHp}ダメージ',
                              style: sans(11, weight: FontWeight.w700, color: AppColors.muted),
                            ),
                            if (yours != null)
                              Text(
                                'あなた「$yours」 vs ${r.boss}「${boss!.stance}」',
                                style: sans(11, weight: FontWeight.w800, color: AppColors.accent),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: AppColors.ink),
                      ),
                    ],
                  ),
                ),
                const Divider(color: AppColors.line, height: 12),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: boss != null && r.log.isNotEmpty
                        ? BattleTranscript(boss: boss, turns: r.log)
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('この戦いは、やりとりを残すようになる前の記録です。', style: sans(13, color: AppColors.muted, height: 1.7)),
                              if (r.bestAttack.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'いちばん効いた反論（${r.bestDamage}ダメージ）\n「${r.bestAttack}」',
                                  style: sans(13, weight: FontWeight.w700, height: 1.6),
                                ),
                              ],
                            ],
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

/// 記録の切りかえタブ（リール / ボス戦）
class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? const Color(0xFF16181A) : AppColors.ink;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.ink.withValues(alpha: selected ? 1 : 0.35), width: 1.5),
          boxShadow: selected ? const [BoxShadow(color: Color(0x99000000), offset: Offset(3, 3))] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 6),
            Text(
              label,
              style: sans(14, weight: FontWeight.w800, color: fg),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: sans(12, weight: FontWeight.w800, color: fg.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
