import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../data/news.dart';
import '../theme.dart';

/// アプリを開くたびに、お知らせ（イベント・新機能）を1つ出す。
/// ほかの画面とちがい、角のない四角い箱。✕ は0.3秒たってから出る
class NewsPopup {
  NewsPopup._();

  /// このアプリの起動で、もう出したか
  static bool _shown = false;

  static Future<void> showOncePerLaunch(BuildContext context) async {
    if (_shown) return;
    // ホームがいちばん上の時だけ（すぐ別の画面へ行った時は、次にホームにもどった時に出す）
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    _shown = true;
    // 毎回ちがうお知らせが出るように
    final item = news[math.Random().nextInt(news.length)];
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xCC000000),
      transitionDuration: const Duration(milliseconds: 260),
      transitionBuilder: (context, a, _, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(a), child: child),
      ),
      pageBuilder: (context, _, _) => _NewsBox(item: item),
    );
  }
}

class _NewsBox extends StatefulWidget {
  const _NewsBox({required this.item});

  final NewsItem item;

  @override
  State<_NewsBox> createState() => _NewsBoxState();
}

class _NewsBoxState extends State<_NewsBox> {
  /// ✕ を出すか（0.3秒たってから）
  bool _canClose = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _canClose = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.item;
    const ink = AppColors.ink;
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: 340,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            color: AppColors.paperBottom,
            border: Border.fromBorderSide(BorderSide(color: ink, width: 2)),
            boxShadow: [BoxShadow(color: Color(0xFF000000), offset: Offset(6, 6))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 上の帯: 種類・日付・✕
              Container(
                height: 40,
                color: n.tag == 'イベント' ? AppColors.red : AppColors.navy,
                padding: const EdgeInsets.only(left: 14),
                child: Row(
                  children: [
                    Text(
                      n.tag,
                      style: sans(13, weight: FontWeight.w800, color: Colors.white, spacing: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      n.date,
                      style: sans(12, weight: FontWeight.w700, color: Colors.white70),
                    ),
                    const Spacer(),
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: _canClose ? 1 : 0,
                      child: IgnorePointer(
                        ignoring: !_canClose,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 40,
                            height: 40,
                            color: Colors.black.withValues(alpha: 0.25),
                            alignment: Alignment.center,
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(n.title, style: sans(20, weight: FontWeight.w800, height: 1.4)),
                    const SizedBox(height: 10),
                    Container(width: 36, height: 3, color: ink),
                    const SizedBox(height: 12),
                    Text(n.body, style: sans(14, color: AppColors.bodyText, height: 1.75)),
                    if (n.route != null) ...[
                      const SizedBox(height: 18),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop();
                          context.go(n.route!);
                        },
                        child: Container(
                          height: 46,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: ink,
                            boxShadow: [BoxShadow(color: Color(0xFF000000), offset: Offset(4, 4))],
                          ),
                          child: Text(
                            '${n.action ?? '見てみる'} ›',
                            style: sans(15, weight: FontWeight.w800, color: const Color(0xFF16181A)),
                          ),
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
