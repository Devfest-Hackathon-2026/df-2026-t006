import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../router.dart';
import '../screens/loading_screen.dart';
import '../state/brains.dart';
import '../state/missions.dart';
import '../theme.dart';
import 'hitachan.dart';

/// ミッションが進んだ時・達成した時に、画面の上から出てくる通知。
/// アプリ全体（どの画面の上でも）に重ねて出す。押すとミッション画面へ。
class MissionToastHost extends ConsumerStatefulWidget {
  const MissionToastHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MissionToastHost> createState() => _MissionToastHostState();
}

class _MissionToastHostState extends ConsumerState<MissionToastHost> {
  /// 今出している通知（ミッションと、その時の回数）
  (Mission, int)? _toast;
  bool _visible = false;
  Timer? _hide;

  void _show(Mission m, int progress) {
    if (progress >= m.target) HapticFeedback.mediumImpact();
    _hide?.cancel();
    setState(() {
      _toast = (m, progress);
      _visible = true;
    });
    _hide = Timer(Duration(milliseconds: progress >= m.target ? 3200 : 2200), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  /// ちびのうをもらった時の通知（下から出る）
  BrainGain? _brain;
  bool _brainVisible = false;
  Timer? _brainHide;

  void _showBrain(BrainGain g) {
    HapticFeedback.lightImpact();
    _brainHide?.cancel();
    setState(() {
      _brain = g;
      _brainVisible = true;
    });
    _brainHide = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _brainVisible = false);
    });
  }

  /// 通知を出さない時: 起動の読み込み中（保存データを戻した時に「進んだ」と勘違いしないように）と、プロローグ
  bool get _quiet {
    if (!LoadingScreen.booted) return true;
    final path = appRouter.routerDelegate.currentConfiguration.uri.path;
    return path == '/loading' || path == '/prologue';
  }

  @override
  void dispose() {
    _hide?.cancel();
    _brainHide?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 回数が増えた時だけ知らせる（達成した後に増えても、もう出さない）
    for (final m in missions) {
      ref.listen<int>(missionProgressProvider(m.id), (prev, next) {
        if (_quiet) return;
        if (prev != null && next > prev && prev < m.target) _show(m, next.clamp(0, m.target));
      });
    }

    ref.listen<BrainGain?>(brainProvider.select((b) => b.gain), (prev, next) {
      if (_quiet) return;
      if (next != null && next.id != prev?.id) _showBrain(next);
    });

    final toast = _toast;
    final brain = _brain;
    return Stack(
      children: [
        widget.child,
        if (brain != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: AnimatedSlide(
                offset: _brainVisible ? Offset.zero : const Offset(0, 2),
                duration: const Duration(milliseconds: 380),
                curve: _brainVisible ? Curves.easeOutBack : Curves.easeInCubic,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _brainVisible = false);
                        // ちびのうはメールボックスに届くので、メールボックスへ
                        appRouter.go('/mail');
                      },
                      child: Material(
                        type: MaterialType.transparency,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
                          decoration: BoxDecoration(
                            color: AppColors.navy,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: AppColors.ink, width: 1.5),
                            boxShadow: const [BoxShadow(color: Color(0xAA000000), offset: Offset(3, 3))],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const ChibinoIcon(size: 24),
                              const SizedBox(width: 8),
                              // 理由が長い時（アチーブメントの名前など）は折り返す（画面からはみ出さない）
                              Flexible(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'ちびのう +${brain.amount}',
                                      style: sans(14, weight: FontWeight.w800, color: AppColors.onNavy),
                                    ),
                                    Text(
                                      '${brain.reason}・メールに届きました',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: sans(11, weight: FontWeight.w700, color: AppColors.accent),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (toast != null)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: SafeArea(
              child: AnimatedSlide(
                offset: _visible ? Offset.zero : const Offset(0, -1.6),
                duration: const Duration(milliseconds: 380),
                curve: _visible ? Curves.easeOutBack : Curves.easeInCubic,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: _Toast(
                        mission: toast.$1,
                        progress: toast.$2,
                        onTap: () {
                          setState(() => _visible = false);
                          appRouter.go('/missions');
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.mission, required this.progress, required this.onTap});

  final Mission mission;
  final int progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = progress >= mission.target;
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: done ? AppColors.xpGreen : AppColors.ink.withValues(alpha: 0.6), width: 1.5),
            boxShadow: const [BoxShadow(color: Color(0xAA000000), offset: Offset(4, 4))],
          ),
          child: Row(
            children: [
              Icon(
                done ? Icons.emoji_events_rounded : Icons.flag_rounded,
                color: done ? AppColors.xpGreen : AppColors.accent,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      done ? 'ミッション達成！' : 'ミッション',
                      style: sans(11, weight: FontWeight.w800, color: done ? AppColors.xpGreenLight : AppColors.muted),
                    ),
                    Text(mission.title, style: sans(13, weight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: (progress - 1) / mission.target, end: progress / mission.target),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 5,
                          backgroundColor: AppColors.ink.withValues(alpha: 0.12),
                          color: AppColors.xpGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                done ? '受け取る ›' : '$progress/${mission.target}',
                style: sans(12, weight: FontWeight.w800, color: AppColors.xpGreenLight),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
