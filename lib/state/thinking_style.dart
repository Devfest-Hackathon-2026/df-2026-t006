import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/depth_grader.dart';
import 'records.dart';

/// 思考スタイル（プロフィールの「称号」のようなもの）。
/// Gemini が判定した思考パターン（7種類）を、かっこいい「型」にする。
class StyleArchetype {
  const StyleArchetype({
    required this.pattern,
    required this.title,
    required this.english,
    required this.icon,
    required this.color,
    required this.description,
  });

  /// thoughtPatterns の id
  final String pattern;
  final String title;
  final String english;
  final IconData icon;
  final Color color;
  final String description;
}

const archetypes = <StyleArchetype>[
  StyleArchetype(
    pattern: 'principle',
    title: '法の番人',
    english: 'THE GUARDIAN',
    icon: Icons.balance_rounded,
    color: Color(0xFF6C8FD8),
    description: '筋が通っているかを何より大事にする。ゆずれない原則を持つ人。',
  ),
  StyleArchetype(
    pattern: 'consequence',
    title: '未来の計算者',
    english: 'THE STRATEGIST',
    icon: Icons.insights_rounded,
    color: Color(0xFF4FB6A8),
    description: '行動の先に何が起きるかを見通して、いちばん良い道を探す人。',
  ),
  StyleArchetype(
    pattern: 'empathy',
    title: '心の翻訳者',
    english: 'THE EMPATH',
    icon: Icons.favorite_rounded,
    color: Color(0xFFE07A93),
    description: '人の気持ちや立場に入りこんで、答えを探す人。',
  ),
  StyleArchetype(
    pattern: 'skeptic',
    title: '疑いの探偵',
    english: 'THE DETECTIVE',
    icon: Icons.search_rounded,
    color: Color(0xFF9B7FD6),
    description: '当たり前を疑い、隠れた前提を見つけ出す人。',
  ),
  StyleArchetype(
    pattern: 'synthesis',
    title: '橋をかける者',
    english: 'THE BRIDGE BUILDER',
    icon: Icons.hub_rounded,
    color: Color(0xFFE0A84F),
    description: 'ちがう見方をつないで、新しい答えをつくる人。',
  ),
  StyleArchetype(
    pattern: 'intuition',
    title: '直感の詩人',
    english: 'THE POET',
    icon: Icons.auto_awesome_rounded,
    color: Color(0xFFD9779E),
    description: '心が動く方向を手がかりに、まっすぐ考える人。',
  ),
  StyleArchetype(
    pattern: 'explorer',
    title: '問いの旅人',
    english: 'THE WANDERER',
    icon: Icons.explore_rounded,
    color: Color(0xFF7FA6C9),
    description: '答えを急がず、問いの向こうへ旅を続ける人。',
  ),
];

StyleArchetype archetypeOf(String pattern) =>
    archetypes.firstWhere((a) => a.pattern == pattern, orElse: () => archetypes.last);

/// いちばん強い観点でつく「二つ名」（平均がこれ以上の時だけ）
const _epithetMin = 15.0;
const _epithets = {'reasons': '筋金入りの', 'counter': '反論を恐れない', 'change': 'しなやかな', 'own': '自分の言葉を持つ'};

/// 思考スタイル（判定が1つもない時は null）
class ThinkingStyle {
  const ThinkingStyle({
    required this.archetype,
    required this.epithet,
    required this.counts,
    required this.axes,
    required this.averageScore,
    required this.history,
    required this.first,
  });

  final StyleArchetype archetype;

  /// 二つ名（なければ空）
  final String epithet;

  /// パターンごとの回数
  final Map<String, int> counts;

  /// 観点ごとの平均（0〜25）
  final Map<String, double> axes;

  /// 深さの点数の平均（0〜100）
  final double averageScore;

  /// 判定のついた記録（古い順）
  final List<TopicRecord> history;

  /// いちばん最初のスタイル（変化を見せる用）
  final StyleArchetype first;

  String get fullTitle => epithet.isEmpty ? archetype.title : '$epithet ${archetype.title}';

  /// 平均の深さ（水面〜海溝）
  DepthLevel get depth => depthLevels[(averageScore ~/ 20).clamp(0, depthLevels.length - 1)];

  bool get changed => first.pattern != archetype.pattern;

  /// 観点ごとの、最初の判定から最新の判定までの変化
  Map<String, int> get axisGrowth {
    final a = history.first.grade!.axes;
    final b = history.last.grade!.axes;
    return {for (final (k, _) in depthAxes) k: (b[k] ?? 0) - (a[k] ?? 0)};
  }

  /// 記録から思考スタイルを決める。
  /// いちばん多いパターン（同じ数なら、新しい判定に出てきた方）が「型」になる。
  static ThinkingStyle? from(List<TopicRecord> records) {
    final graded = [...records.where((r) => r.grade != null)]..sort((a, b) => a.finishedAt.compareTo(b.finishedAt));
    if (graded.isEmpty) return null;
    final counts = <String, int>{};
    final lastSeen = <String, int>{};
    for (var i = 0; i < graded.length; i++) {
      final p = graded[i].grade!.pattern;
      counts[p] = (counts[p] ?? 0) + 1;
      lastSeen[p] = i;
    }
    final top = counts.keys.reduce((a, b) {
      final c = counts[a]!.compareTo(counts[b]!);
      return c != 0 ? (c > 0 ? a : b) : (lastSeen[a]! >= lastSeen[b]! ? a : b);
    });
    final axes = {
      for (final (k, _) in depthAxes)
        k: graded.map((r) => r.grade!.axes[k] ?? 0).reduce((a, b) => a + b) / graded.length,
    };
    final best = axes.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return ThinkingStyle(
      archetype: archetypeOf(top),
      epithet: best.value >= _epithetMin ? _epithets[best.key]! : '',
      counts: counts,
      axes: axes,
      averageScore: graded.map((r) => r.grade!.score).reduce((a, b) => a + b) / graded.length,
      history: graded,
      first: archetypeOf(graded.first.grade!.pattern),
    );
  }
}

final thinkingStyleProvider = Provider<ThinkingStyle?>((ref) => ThinkingStyle.from(ref.watch(recordsProvider)));
