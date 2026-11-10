import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/depth_grader.dart';
import '../state/brains.dart';
import 'hitachan.dart';
import '../theme.dart';

/// ふりかえりの一番上: Gemini が答えを読んで、考えの深さと思考パターンを出す
class DepthPanel extends ConsumerStatefulWidget {
  const DepthPanel({super.key, required this.topicId, required this.transcript});

  final String topicId;

  /// Gemini に送る記録を作る
  final String Function() transcript;

  @override
  ConsumerState<DepthPanel> createState() => _DepthPanelState();
}

class _DepthPanelState extends ConsumerState<DepthPanel> {
  @override
  void initState() {
    super.initState();
    // ふりかえりを開いたら、まだなら自動で測る
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(depthGradeProvider(widget.topicId)) == null) _grade();
    });
  }

  void _grade() => ref.read(depthGradeProvider(widget.topicId).notifier).grade(widget.transcript());

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(depthGradeProvider(widget.topicId));
    ref.listen(depthGradeProvider(widget.topicId), (prev, next) {
      if (next is AsyncData && prev is! AsyncData) HapticFeedback.mediumImpact();
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink, width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x99000000), offset: Offset(4, 4))],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: switch (state) {
          AsyncData(:final value) => _Result(grade: value, onRetry: _grade),
          AsyncError(:final error) => _Error(
            message: error is DepthGradeException ? error.message : '判定できませんでした',
            onRetry: _grade,
          ),
          _ => const _Loading(),
        },
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.auto_awesome_rounded, size: 15, color: AppColors.accent),
        const SizedBox(width: 6),
        Text(
          'Gemini の判定',
          style: sans(12, weight: FontWeight.w800, color: AppColors.accent, spacing: 1),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label(),
        const SizedBox(height: 14),
        Text(
          'あなたの答えを読んでいます…',
          style: sans(16, weight: FontWeight.w800, color: AppColors.onNavy),
        ),
        const SizedBox(height: 4),
        Text('考えの深さと、思考のパターンを測っています', style: sans(12, color: AppColors.accent)),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: const LinearProgressIndicator(
            minHeight: 6,
            color: AppColors.accent,
            backgroundColor: AppColors.navyDeep,
          ),
        ),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label(),
        const SizedBox(height: 12),
        Text(
          message,
          style: sans(13, weight: FontWeight.w700, color: AppColors.onNavy, height: 1.6),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onRetry,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.refresh_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 4),
                Text(
                  'もう一度',
                  style: sans(13, weight: FontWeight.w800, color: AppColors.accent),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.grade, required this.onRetry});

  final DepthGrade grade;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final pattern = patternOf(grade.pattern);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label(),
        const SizedBox(height: 10),
        // 深さ（大きく）と点数
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '考えの深さ',
                    style: sans(11, weight: FontWeight.w800, color: AppColors.accent),
                  ),
                  Text(
                    grade.depth.name,
                    style: serif(34, weight: FontWeight.w800, color: AppColors.onNavy),
                  ),
                ],
              ),
            ),
            TweenAnimationBuilder<int>(
              tween: IntTween(begin: 0, end: grade.score),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$v',
                      style: sans(30, weight: FontWeight.w800, color: AppColors.onNavy),
                    ),
                    TextSpan(
                      text: ' / 100',
                      style: sans(12, weight: FontWeight.w800, color: AppColors.accent),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                grade.depth.description,
                style: sans(12, weight: FontWeight.w700, color: AppColors.accent),
              ),
            ),
            if (brainsForDepth[grade.level] > 0) ...[
              const ChibinoIcon(size: 18),
              const SizedBox(width: 4),
              Text(
                '考えきると ×${brainsForDepth[grade.level]}',
                style: sans(12, weight: FontWeight.w800, color: AppColors.onNavy),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _DepthGauge(level: grade.level),
        const SizedBox(height: 16),
        // 思考パターン
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
          decoration: BoxDecoration(color: AppColors.navyDeep, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '思考パターン',
                    style: sans(11, weight: FontWeight.w800, color: AppColors.accent),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    pattern.name,
                    style: sans(16, weight: FontWeight.w800, color: AppColors.onNavy),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(pattern.description, style: sans(12, color: AppColors.bodyText)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // 4つの観点
        for (final (key, label) in depthAxes) _AxisBar(label: label, value: grade.axes[key] ?? 0),
        if (grade.goodPoint.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'いいところ',
            style: sans(11, weight: FontWeight.w800, color: AppColors.accent),
          ),
          const SizedBox(height: 3),
          Text(
            grade.goodPoint,
            style: sans(13, weight: FontWeight.w700, color: AppColors.onNavy, height: 1.6),
          ),
        ],
        if (grade.nextQuestion.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '次に考えてみたい問い',
                  style: sans(11, weight: FontWeight.w800, color: AppColors.navy),
                ),
                const SizedBox(height: 3),
                Text(
                  grade.nextQuestion,
                  style: sans(14, weight: FontWeight.w800, color: const Color(0xFF16181A), height: 1.5),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text('※ AIによる目安です', style: sans(10, color: AppColors.accent)),
      ],
    );
  }
}

/// 5段階の深さ（右に行くほど深い・暗い）
class _DepthGauge extends StatelessWidget {
  const _DepthGauge({required this.level});

  final int level;

  static const _shades = [
    Color(0xFFB9CBEA),
    Color(0xFF8DA6D4),
    Color(0xFF5E7DB5),
    Color(0xFF34558F),
    Color(0xFF0B1A36),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < depthLevels.length; i++) ...[
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: i <= level ? 1 : 0),
                  duration: Duration(milliseconds: 250 + i * 150),
                  curve: Curves.easeOut,
                  builder: (context, t, _) => Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: Color.lerp(AppColors.navyDeep, _shades[i], t),
                      borderRadius: BorderRadius.circular(3),
                      border: i == level ? Border.all(color: AppColors.ink, width: 1.5) : null,
                    ),
                  ),
                ),
              ),
              if (i < depthLevels.length - 1) const SizedBox(width: 4),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 0; i < depthLevels.length; i++)
              Expanded(
                child: Text(
                  depthLevels[i].name,
                  textAlign: TextAlign.center,
                  style: sans(
                    10,
                    weight: FontWeight.w800,
                    color: i == level ? AppColors.onNavy : AppColors.accent.withValues(alpha: 0.6),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _AxisBar extends StatelessWidget {
  const _AxisBar({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: sans(12, weight: FontWeight.w800, color: AppColors.onNavy),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value / 25),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 7,
                  color: AppColors.accent,
                  backgroundColor: AppColors.navyDeep,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              '$value/25',
              textAlign: TextAlign.right,
              style: sans(10, weight: FontWeight.w800, color: AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }
}
