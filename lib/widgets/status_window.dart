import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/brains.dart';
import '../state/providers.dart';
import '../state/thinking_style.dart';
import '../theme.dart';
import 'hitachan.dart';

/// プレイヤーの状態（名前・レベル・経験値）。押すとプロフィールへ。
/// ほかのボタンと同じく、ずらした影の上に乗っていて、押すと沈む。
class StatusWindow extends ConsumerStatefulWidget {
  const StatusWindow({super.key, required this.onPortrait});

  /// 押した時（プロフィールへ）
  final VoidCallback onPortrait;

  @override
  ConsumerState<StatusWindow> createState() => _StatusWindowState();
}

class _StatusWindowState extends ConsumerState<StatusWindow> {
  /// 押している間（沈む）
  bool _down = false;

  /// 影の深さ（押すとこの分だけ沈む）
  static const _depth = 4.0;

  VoidCallback get onPortrait => widget.onPortrait;

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    // 思考スタイルがわかったら、顔の代わりにその型のエンブレムを出す
    final style = ref.watch(thinkingStyleProvider);
    const p = Palette.main;
    final ink = p.text;

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        onPortrait();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 70),
        transform: Matrix4.translationValues(_down ? _depth : 0, _down ? _depth : 0, 0),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: p.card.face,
          border: Border.all(color: ink, width: 2),
          boxShadow: [
            // ほかのボタンと同じ、ずらした影（押すと沈んで影が消える）
            if (!_down) BoxShadow(color: p.card.edge, offset: const Offset(_depth, _depth)),
            const BoxShadow(color: Color(0x66000000), blurRadius: 14),
          ],
        ),
        child: Row(
          children: [
            IgnorePointer(
              child: Container(
                width: 44,
                height: 44,
                color: style?.archetype.color ?? ink,
                child: Icon(
                  style?.archetype.icon ?? Icons.person,
                  color: style == null ? p.card.face : Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        // 名前と、その下に思考スタイルの称号（わかっていれば）
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              player.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'NotoSansJP',
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: ink,
                                height: 1.2,
                                letterSpacing: 1,
                              ),
                            ),
                            if (style != null)
                              Text(
                                style.fullTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: sans(11, weight: FontWeight.w800, color: style.archetype.color, height: 1.3),
                              ),
                          ],
                        ),
                      ),
                      // 持っているちびのう（ひたちゃんにあげられる数）
                      const ChibinoIcon(size: 18),
                      Text(
                        '${ref.watch(brainProvider.select((b) => b.stock))}',
                        style: sans(13, weight: FontWeight.w800, color: AppColors.ink, height: 1.1),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Lv.',
                        style: sans(12, weight: FontWeight.w800, color: AppColors.ink, height: 1.1),
                      ),
                      Text(
                        '${player.level}',
                        style: sans(22, weight: FontWeight.w900, color: AppColors.ink, height: 1.0),
                      ),
                      const SizedBox(width: 2),
                      // 押せることがわかるように
                      Icon(Icons.chevron_right_rounded, size: 22, color: ink.withValues(alpha: 0.8)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            color: p.meterTrack,
                            border: Border.all(color: ink, width: 1.5),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: player.levelProgress.clamp(0, 1),
                            child: ColoredBox(color: AppColors.xpGreen),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${player.xpInLevel}/${PlayerState.xpPerLevel}',
                        style: sans(
                          10,
                          weight: FontWeight.w700,
                          color: AppColors.xpGreenLight,
                          height: 1.2,
                        ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
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
