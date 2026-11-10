import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'brains.dart';
import 'providers.dart';

/// ミッションで数えるもの
enum MissionKind {
  /// コメント欄のミニゲーム「誰の言葉？」に正解した回数
  quizWin,

  /// コメント欄の投票をした回数
  vote,

  /// 哲学者のコメントに返信した回数
  reply,

  /// テーマを最後まで考えきった数
  topic,

  /// 考えの深さ「深海」以上の判定をもらった回数
  deepGrade,

  /// ボスに勝った回数
  bossWin,

  /// 反論を読んで考えを変えた回数
  changeMind,

  /// 自分の考えをコメントした回数
  comment,
}

/// ミッションの期間（その期間が終わると、回数と受け取りがリセットされる）
enum MissionPeriod {
  daily('デイリー'),
  weekly('ウィークリー'),
  monthly('マンスリー'),
  eternal('アチーブメント');

  const MissionPeriod(this.label);

  final String label;

  /// 今の期間を表す文字（日・週・月ごとに変わる。ずっとは空）
  String keyAt(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    switch (this) {
      case MissionPeriod.daily:
        return 'd${t.year}${two(t.month)}${two(t.day)}';
      case MissionPeriod.weekly:
        // 月曜はじまりの週
        final monday = DateTime(t.year, t.month, t.day).subtract(Duration(days: t.weekday - 1));
        return 'w${monday.year}${two(monday.month)}${two(monday.day)}';
      case MissionPeriod.monthly:
        return 'm${t.year}${two(t.month)}';
      case MissionPeriod.eternal:
        return '';
    }
  }

  /// 次にリセットされる時刻（ずっとは null）
  DateTime? resetAfter(DateTime t) {
    final today = DateTime(t.year, t.month, t.day);
    return switch (this) {
      MissionPeriod.daily => today.add(const Duration(days: 1)),
      MissionPeriod.weekly => today.add(Duration(days: 8 - t.weekday)),
      MissionPeriod.monthly => DateTime(t.year, t.month + 1),
      MissionPeriod.eternal => null,
    };
  }
}

class Mission {
  const Mission({
    required this.id,
    required this.kind,
    required this.title,
    required this.target,
    required this.reward,
    required this.period,
    this.brains = 0,
  });

  final String id;
  final MissionKind kind;
  final String title;
  final MissionPeriod period;

  /// 達成に必要な回数
  final int target;

  /// もらえる経験値
  final int reward;

  /// もらえるちびのう（メールボックスに届く）
  final int brains;
}

// ミッション一覧（数字・題はあとで調整）
const missions = <Mission>[
  // デイリー
  Mission(
    id: 'd_topic',
    period: MissionPeriod.daily,
    kind: MissionKind.topic,
    title: 'テーマを1つ考えきる',
    target: 1,
    reward: 40,
    brains: 1,
  ),
  Mission(id: 'd_vote', period: MissionPeriod.daily, kind: MissionKind.vote, title: '投票を2回する', target: 2, reward: 20),
  Mission(
    id: 'd_reply',
    period: MissionPeriod.daily,
    kind: MissionKind.reply,
    title: '哲学者に返信する',
    target: 1,
    reward: 20,
  ),
  // ウィークリー
  Mission(
    id: 'w_topic',
    period: MissionPeriod.weekly,
    kind: MissionKind.topic,
    title: 'テーマを3つ考えきる',
    target: 3,
    reward: 100,
    brains: 3,
  ),
  Mission(
    id: 'w_boss',
    period: MissionPeriod.weekly,
    kind: MissionKind.bossWin,
    title: 'ボスに1回勝つ',
    target: 1,
    reward: 80,
    brains: 3,
  ),
  Mission(
    id: 'w_quiz',
    period: MissionPeriod.weekly,
    kind: MissionKind.quizWin,
    title: '「誰の言葉？」に5回正解する',
    target: 5,
    reward: 60,
  ),
  Mission(
    id: 'w_mind',
    period: MissionPeriod.weekly,
    kind: MissionKind.changeMind,
    title: '反論を読んで3回考えを変える',
    target: 3,
    reward: 50,
    brains: 2,
  ),
  // マンスリー
  Mission(
    id: 'm_deep',
    period: MissionPeriod.monthly,
    kind: MissionKind.deepGrade,
    title: '考えの深さ「深海」以上を3回とる',
    target: 3,
    reward: 150,
    brains: 5,
  ),
  Mission(
    id: 'm_boss',
    period: MissionPeriod.monthly,
    kind: MissionKind.bossWin,
    title: 'ボスに5回勝つ',
    target: 5,
    reward: 200,
    brains: 6,
  ),
  Mission(
    id: 'm_comment',
    period: MissionPeriod.monthly,
    kind: MissionKind.comment,
    title: '自分の考えを10回コメントする',
    target: 10,
    reward: 100,
    brains: 3,
  ),
  // ずっと（1回だけ）
  Mission(
    id: 'e_topic1',
    period: MissionPeriod.eternal,
    kind: MissionKind.topic,
    title: 'はじめてテーマを考えきる',
    target: 1,
    reward: 50,
    brains: 2,
  ),
  Mission(
    id: 'e_boss1',
    period: MissionPeriod.eternal,
    kind: MissionKind.bossWin,
    title: 'はじめてボスに勝つ',
    target: 1,
    reward: 80,
    brains: 3,
  ),
  Mission(
    id: 'e_deep1',
    period: MissionPeriod.eternal,
    kind: MissionKind.deepGrade,
    title: 'はじめて「深海」以上をとる',
    target: 1,
    reward: 50,
    brains: 3,
  ),
  Mission(
    id: 'e_topic10',
    period: MissionPeriod.eternal,
    kind: MissionKind.topic,
    title: 'テーマを10回考えきる',
    target: 10,
    reward: 300,
    brains: 10,
  ),
];

/// 今の時刻（テストで差しかえられるように）
DateTime Function() missionClock = DateTime.now;

String _countKey(MissionKind k, MissionPeriod p, DateTime t) {
  final key = p.keyAt(t);
  return key.isEmpty ? k.name : '${k.name}@$key';
}

String _claimKey(Mission m, DateTime t) {
  final key = m.period.keyAt(t);
  return key.isEmpty ? m.id : '${m.id}@$key';
}

/// ミッションの進み具合（回数と、報酬を受け取ったミッション）。
/// 回数は「何を・どの期間に」ごとに数える（期間が変わると、新しい期間の数え方になる＝リセット）。
/// クラウド（Firestore）への保存は services/cloud.dart
class MissionState {
  const MissionState({this.counts = const {}, this.claimed = const {}});

  /// 例: 'vote@d20261109'（今日の投票数）、'vote'（ずっとの投票数）
  final Map<String, int> counts;

  /// 例: 'd_vote@d20261109'、'e_boss1'
  final Set<String> claimed;

  int countOf(Mission m, DateTime t) => counts[_countKey(m.kind, m.period, t)] ?? 0;

  bool isClaimed(Mission m, DateTime t) => claimed.contains(_claimKey(m, t));

  Map<String, Object?> toJson() => {'counts': counts, 'claimed': claimed.toList()};

  static MissionState fromJson(Map<String, dynamic> j) {
    final c = (j['counts'] as Map?) ?? const {};
    return MissionState(
      counts: {
        for (final e in c.entries)
          if (e.value is num) '${e.key}': (e.value as num).toInt(),
      },
      claimed: {...((j['claimed'] as List?) ?? const []).whereType<String>()},
    );
  }
}

class MissionNotifier extends Notifier<MissionState> {
  @override
  MissionState build() => const MissionState();

  void restore(MissionState s) => state = s;

  /// 1回数える（デイリー・ウィークリー・マンスリー・ずっと、の全部に）。
  /// 終わった期間の古い数は消しておく
  void add(MissionKind k) {
    final now = missionClock();
    final current = {for (final p in MissionPeriod.values) p.keyAt(now)};
    bool stillValid(String key) {
      final at = key.indexOf('@');
      return at < 0 || current.contains(key.substring(at + 1));
    }

    final counts = {
      for (final e in state.counts.entries)
        if (stillValid(e.key)) e.key: e.value,
    };
    for (final p in MissionPeriod.values) {
      final key = _countKey(k, p, now);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    state = MissionState(counts: counts, claimed: {...state.claimed.where(stillValid)});
  }

  /// 報酬を受け取る（達成済みで、この期間にまだ受け取っていない時だけ）
  void claim(Mission m) {
    final now = missionClock();
    if (state.isClaimed(m, now) || state.countOf(m, now) < m.target) return;
    state = MissionState(counts: state.counts, claimed: {...state.claimed, _claimKey(m, now)});
    ref.read(playerProvider.notifier).addXp(m.reward);
    // ちびのうはメールボックスへ
    ref.read(brainProvider.notifier).earn(m.brains, 'ミッション「${m.title}」（${m.period.label}）');
  }
}

final missionProvider = NotifierProvider<MissionNotifier, MissionState>(MissionNotifier.new);

/// 画面表示用: ミッションの進み具合（0〜target）
final missionProgressProvider = Provider.family<int, String>((ref, id) {
  final m = missions.firstWhere((x) => x.id == id);
  return ref.watch(missionProvider).countOf(m, missionClock());
});

/// この期間に受け取りずみか
final missionClaimedProvider = Provider.family<bool, String>((ref, id) {
  final m = missions.firstWhere((x) => x.id == id);
  return ref.watch(missionProvider).isClaimed(m, missionClock());
});

/// 達成して、まだ報酬を受け取っていないミッションの数（ホームの赤い点）
final claimableMissionsProvider = Provider<int>((ref) {
  return missions
      .where((m) => !ref.watch(missionClaimedProvider(m.id)) && ref.watch(missionProgressProvider(m.id)) >= m.target)
      .length;
});
