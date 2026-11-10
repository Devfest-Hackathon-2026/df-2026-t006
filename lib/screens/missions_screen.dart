import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/missions.dart';
import '../theme.dart';
import '../widgets/hitachan.dart';
import '../widgets/phone_frame.dart';
import '../widgets/push_button.dart';

/// ミッション一覧。達成したら「受け取る」で経験値をもらえる。
class MissionsScreen extends ConsumerStatefulWidget {
  const MissionsScreen({super.key});

  @override
  ConsumerState<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends ConsumerState<MissionsScreen> {
  MissionPeriod _period = MissionPeriod.daily;

  @override
  Widget build(BuildContext context) {
    const p = Palette.main;
    // 並べ方: 受け取れる → まだ途中 → 受け取りずみ（灰色・いちばん下）
    int rank(Mission m) {
      if (ref.watch(missionClaimedProvider(m.id))) return 2;
      return ref.watch(missionProgressProvider(m.id)) >= m.target ? 0 : 1;
    }

    int claimableIn(MissionPeriod period) => missions
        .where(
          (m) =>
              m.period == period &&
              !ref.watch(missionClaimedProvider(m.id)) &&
              ref.watch(missionProgressProvider(m.id)) >= m.target,
        )
        .length;

    final shown = [...missions.where((m) => m.period == _period)]..sort((a, b) => rank(a).compareTo(rank(b)));
    final reset = _period.resetAfter(DateTime.now());
    return Scaffold(
      body: PhoneFrame(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(title: 'ミッション', palette: p, onBack: () => context.go('/')),
              // デイリー・ウィークリー・マンスリー・ずっと
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(
                  children: [
                    for (final period in MissionPeriod.values) ...[
                      Expanded(
                        child: _PeriodTab(
                          label: period.label,
                          selected: period == _period,
                          badge: claimableIn(period) > 0,
                          onTap: () => setState(() => _period = period),
                        ),
                      ),
                      if (period != MissionPeriod.values.last) const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 10, 20, 0),
                child: Text(
                  reset == null ? '1回だけのミッション' : 'リセットまで ${_untilText(reset)}',
                  style: sans(12, weight: FontWeight.w700, color: AppColors.muted),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => MissionTile(mission: shown[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 「あと5時間」「あと3日」など
  String _untilText(DateTime reset) {
    final d = reset.difference(DateTime.now());
    if (d.inDays >= 1) return 'あと${d.inDays}日';
    if (d.inHours >= 1) return 'あと${d.inHours}時間';
    return 'あと${d.inMinutes.clamp(1, 59)}分';
  }
}

/// 期間のタブ（受け取れるミッションがあれば赤い点）
class _PeriodTab extends StatelessWidget {
  const _PeriodTab({required this.label, required this.selected, required this.badge, required this.onTap});

  final String label;
  final bool selected;
  final bool badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? AppColors.ink : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.ink.withValues(alpha: selected ? 1 : 0.3), width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            // 長い名前（アチーブメント）も1行に収める
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: sans(12, weight: FontWeight.w800, color: selected ? const Color(0xFF16181A) : AppColors.ink),
              ),
            ),
          ),
          if (badge)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: AppColors.red,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.paperBottom, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// ミッション1つ（コメント欄でも使う）
class MissionTile extends ConsumerWidget {
  const MissionTile({super.key, required this.mission, this.compact = false});

  final Mission mission;

  /// コメント欄の中など、小さく出す時
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(missionProgressProvider(mission.id)).clamp(0, mission.target);
    final claimed = ref.watch(missionClaimedProvider(mission.id));
    final done = progress >= mission.target;

    // 受け取りずみは灰色に
    return Opacity(
      opacity: claimed ? 0.45 : 1,
      child: Container(
        padding: EdgeInsets.all(compact ? 10 : 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: (done && !claimed ? AppColors.xpGreen : AppColors.ink).withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(
              claimed ? Icons.verified_rounded : Icons.flag_rounded,
              color: claimed ? AppColors.xpGreen : AppColors.accent,
              size: compact ? 18 : 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(mission.title, style: sans(compact ? 12 : 14, weight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress / mission.target,
                            minHeight: 6,
                            backgroundColor: AppColors.ink.withValues(alpha: 0.12),
                            color: AppColors.xpGreen,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$progress/${mission.target}',
                        style: sans(11, weight: FontWeight.w800, color: AppColors.xpGreenLight),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (claimed)
              Text(
                '受取済み',
                style: sans(11, weight: FontWeight.w700, color: AppColors.muted),
              )
            else if (done)
              PushButton(
                width: compact ? 74 : 86,
                height: compact ? 32 : 38,
                depth: 3,
                radius: 10,
                face: AppColors.xpGreen,
                edge: AppColors.ink,
                border: AppColors.ink,
                onPressed: () => ref.read(missionProvider.notifier).claim(mission),
                child: Text(
                  '受け取る',
                  style: sans(12, weight: FontWeight.w800, color: AppColors.onNavy),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '+${mission.reward} EXP',
                    style: sans(15, weight: FontWeight.w800, color: AppColors.xpGreenLight),
                  ),
                  if (mission.brains > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ChibinoIcon(size: 20),
                        Text(
                          ' ×${mission.brains}',
                          style: sans(15, weight: FontWeight.w800, color: AppColors.ink),
                        ),
                      ],
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
