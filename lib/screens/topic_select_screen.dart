import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/think_card.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/battle_button.dart';
import '../widgets/folder_button.dart';
import '../widgets/phone_frame.dart';

/// テーマ選択（ゲームのコース選択のイメージ）。フォルダ型のタイルを2列で並べる。
class TopicSelectScreen extends ConsumerWidget {
  const TopicSelectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topics = ref.watch(topicsProvider);
    const p = Palette.main;

    return Scaffold(
      body: PhoneFrame(
        background: p.background,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(
                title: 'テーマ',
                palette: p,
                icon: Icons.close_rounded,
                onBack: () => context.go('/'),
                // ボス戦への入り口（目立つように右上）
                trailing: RepaintBoundary(child: BattleButton(onPressed: () => context.go('/topics/battle'))),
              ),
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                      sliver: SliverGrid.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.86,
                        ),
                        itemCount: topics.length,
                        itemBuilder: (context, i) => _TopicFolder(number: i + 1, topic: topics[i], palette: p),
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

class _TopicFolder extends ConsumerWidget {
  const _TopicFolder({required this.number, required this.topic, required this.palette});

  final int number;
  final Topic topic;
  final Palette palette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = ref.watch(completedTopicsProvider).contains(topic.id);
    final progress = ref.watch(sessionProvider(topic.id)).index / topic.cards.length;
    final p = palette;

    Widget? badge;
    if (done) {
      badge = _Badge(
        ink: p.text,
        child: Icon(Icons.check_rounded, color: p.accent, size: 18),
      );
    } else if (progress > 0) {
      badge = _Badge(
        ink: p.text,
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 3,
            color: p.accent,
            backgroundColor: p.subText.withValues(alpha: 0.25),
          ),
        ),
      );
    }

    return FolderButton(
      image: topic.image,
      title: topic.title,
      tabLabel: number.toString().padLeft(2, '0'),
      ink: p.text,
      paper: p.card.face,
      accent: p.accent,
      badge: badge,
      onPressed: () => context.go('/topics/${topic.id}'),
    );
  }
}

/// フォルダ右上の小さい白い丸（完了・途中）
class _Badge extends StatelessWidget {
  const _Badge({required this.ink, required this.child});

  final Color ink;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: ink, width: 2),
      ),
      child: Center(child: child),
    );
  }
}
