import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/music.dart';
import '../theme.dart';

/// ボス戦への入り口のボタン（赤く脈打つ「BATTLE」）
class BattleButton extends StatefulWidget {
  const BattleButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<BattleButton> createState() => _BattleButtonState();
}

class _BattleButtonState extends State<BattleButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))
    ..repeat(reverse: true);

  bool _down = false;

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        HapticFeedback.mediumImpact();
        Sfx.tap();
        widget.onPressed();
      },
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, child) {
          final v = Curves.easeInOut.transform(_pulse.value);
          return AnimatedSlide(
            duration: const Duration(milliseconds: 80),
            offset: _down ? const Offset(0.02, 0.06) : Offset.zero,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 9, 16, 9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF2463F), Color(0xFFB3201A)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.ink, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.red.withValues(alpha: 0.35 + v * 0.35),
                    blurRadius: 10 + v * 14,
                    spreadRadius: v * 2,
                  ),
                  if (!_down) const BoxShadow(color: Color(0xCC000000), offset: Offset(3, 4)),
                ],
              ),
              child: child,
            ),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 4),
            Text(
              'BATTLE',
              style: sans(17, weight: FontWeight.w800, color: Colors.white, spacing: 2).copyWith(
                fontStyle: FontStyle.italic,
                shadows: const [Shadow(color: Color(0x99000000), offset: Offset(1, 1))],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
