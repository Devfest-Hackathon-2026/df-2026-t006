import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/news.dart';
import '../theme.dart';
import '../widgets/phone_frame.dart';

class NewsScreen extends ConsumerWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const p = Palette.main;
    // 開いたら「見た」ことにする（ホームの赤い点が消える）
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(newsSeenProvider.notifier).markAllSeen());

    return Scaffold(
      body: PhoneFrame(
        background: p.background,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(title: 'お知らせ', palette: p, onBack: () => context.go('/')),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  itemCount: news.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: p.card.face,
                      border: Border.all(color: p.card.border ?? p.card.edge, width: 2),
                      boxShadow: [BoxShadow(color: p.card.edge, offset: const Offset(4, 4))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${news[i].date}・${news[i].tag}',
                          style: sans(12, weight: FontWeight.w800, color: p.accent),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          news[i].title,
                          style: sans(15, weight: FontWeight.w700, color: p.card.content),
                        ),
                        const SizedBox(height: 4),
                        Text(news[i].body, style: sans(12, color: p.subText, height: 1.6)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
