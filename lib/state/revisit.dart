import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 「もう一度考える」: リールで答えた問いを、しばらくしてからもう一度出す（1回につき1問）。
///
/// 時間をおくと、考えが変わることがある。その「変わった・変わらなかった」を記録する。
///   - 答えた問い（直感・選択・名言のスライダー）を [RevisitItem] として覚えておく
///   - 答えてから [RevisitNotifier.interval] たったら、出してよい問いになる
///   - 出すのは [RevisitNotifier.interval] に1回まで（「あとで」を押しても同じだけ待つ）
///   - もう一度答えたら [RevisitResult] に残す（記録の画面・Analytics）
/// 画面に出すのは widgets/revisit.dart。この機能をやめる時は、この2つのファイルと、呼んでいる所を消す。

/// もう一度出す候補（1つの問い）
class RevisitItem {
  const RevisitItem({required this.topicId, required this.card, required this.choice, required this.answeredAt});

  final String topicId;
  final int card;

  /// その時の答え（選択肢の番号・スライダーの値）
  final int choice;
  final DateTime answeredAt;

  String get key => '$topicId#$card';

  Map<String, Object?> toJson() => {
    'topic': topicId,
    'card': card,
    'choice': choice,
    'at': answeredAt.millisecondsSinceEpoch,
  };

  static RevisitItem? fromJson(Map<String, dynamic> j) {
    final topic = j['topic'], card = j['card'], choice = j['choice'], at = j['at'];
    if (topic is! String || card is! num || choice is! num || at is! num) return null;
    return RevisitItem(
      topicId: topic,
      card: card.toInt(),
      choice: choice.toInt(),
      answeredAt: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
    );
  }
}

/// もう一度答えた結果
class RevisitResult {
  const RevisitResult({
    required this.topicId,
    required this.card,
    required this.before,
    required this.after,
    required this.changed,
    required this.answeredAt,
    required this.at,
  });

  final String topicId;
  final int card;

  /// 前の答えと、今の答え
  final int before;
  final int after;

  /// 考えが変わったか（スライダーは、ことば（やや賛成 など）が変わったら）
  final bool changed;

  /// 前に答えた時刻と、もう一度答えた時刻
  final DateTime answeredAt;
  final DateTime at;

  Map<String, Object?> toJson() => {
    'topic': topicId,
    'card': card,
    'before': before,
    'after': after,
    'changed': changed,
    'answeredAt': answeredAt.millisecondsSinceEpoch,
    'at': at.millisecondsSinceEpoch,
  };

  static RevisitResult? fromJson(Map<String, dynamic> j) {
    final topic = j['topic'], card = j['card'], before = j['before'], after = j['after'];
    final answeredAt = j['answeredAt'], at = j['at'];
    if (topic is! String || card is! num || before is! num || after is! num || at is! num) return null;
    return RevisitResult(
      topicId: topic,
      card: card.toInt(),
      before: before.toInt(),
      after: after.toInt(),
      changed: j['changed'] == true,
      answeredAt: DateTime.fromMillisecondsSinceEpoch((answeredAt is num ? answeredAt : at).toInt()),
      at: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
    );
  }
}

class RevisitState {
  const RevisitState({this.items = const [], this.results = const [], this.lastShownAt});

  /// まだもう一度答えていない問い（古い順）
  final List<RevisitItem> items;

  /// もう一度答えた結果（新しい順）
  final List<RevisitResult> results;

  /// 最後に「もう一度考える？」を出した時刻
  final DateTime? lastShownAt;

  RevisitState copyWith({List<RevisitItem>? items, List<RevisitResult>? results, DateTime? lastShownAt}) =>
      RevisitState(
        items: items ?? this.items,
        results: results ?? this.results,
        lastShownAt: lastShownAt ?? this.lastShownAt,
      );

  Map<String, Object?> toJson() => {
    'items': [for (final i in items) i.toJson()],
    'results': [for (final r in results) r.toJson()],
    'lastShownAt': lastShownAt?.millisecondsSinceEpoch,
  };

  factory RevisitState.fromJson(Map<String, dynamic> j) => RevisitState(
    items: [
      for (final i in switch (j['items']) {
        final List l => l,
        _ => const [],
      })
        if (i is Map) ?RevisitItem.fromJson(Map<String, dynamic>.from(i)),
    ],
    results: [
      for (final r in switch (j['results']) {
        final List l => l,
        _ => const [],
      })
        if (r is Map) ?RevisitResult.fromJson(Map<String, dynamic>.from(r)),
    ],
    lastShownAt: switch (j['lastShownAt']) {
      final num ms => DateTime.fromMillisecondsSinceEpoch(ms.toInt()),
      _ => null,
    },
  );
}

class RevisitNotifier extends Notifier<RevisitState> {
  /// 答えてから出すまで・出してから次を出すまでの時間（確認用: --dart-define=REVISIT_SECONDS=20）
  static const interval = Duration(seconds: int.fromEnvironment('REVISIT_SECONDS', defaultValue: 600));

  /// 覚えておく数（Firestore の1つの文書に入れるので、多くなりすぎないように）
  static const maxItems = 30;
  static const maxResults = 50;

  /// もう一度答えた時の経験値
  static const xp = 15;

  @override
  RevisitState build() => const RevisitState();

  void restore(RevisitState s) => state = s;

  /// リールで答えた時に呼ぶ。同じ問いにまた答えたら、新しい答えと時刻にする
  void remember(String topicId, int card, int choice, {DateTime? now}) {
    final item = RevisitItem(topicId: topicId, card: card, choice: choice, answeredAt: now ?? DateTime.now());
    final rest = state.items.where((i) => i.key != item.key).toList();
    final items = [...rest, item];
    state = state.copyWith(items: items.length > maxItems ? items.sublist(items.length - maxItems) : items);
  }

  /// 今出してよい問い（なければ null）。
  /// 前に出してから [interval] たっていて、答えてから [interval] たった問いのうち、いちばん古いもの
  RevisitItem? due({DateTime? now}) {
    final t = now ?? DateTime.now();
    final last = state.lastShownAt;
    if (last != null && t.difference(last) < interval) return null;
    for (final i in state.items) {
      if (t.difference(i.answeredAt) >= interval) return i;
    }
    return null;
  }

  /// 「もう一度考える？」を出した（「あとで」でも、次は [interval] 後）
  void shown({DateTime? now}) => state = state.copyWith(lastShownAt: now ?? DateTime.now());

  /// 「あとで」: その問いは後ろへ回す（次は別の問いが出やすいように）
  void later(RevisitItem item) {
    final rest = state.items.where((i) => i.key != item.key).toList();
    state = state.copyWith(items: [...rest, item]);
  }

  /// もう一度答えた。結果を残して、その問いは候補から外す
  RevisitResult answer(RevisitItem item, int after, {required bool changed, DateTime? now}) {
    final r = RevisitResult(
      topicId: item.topicId,
      card: item.card,
      before: item.choice,
      after: after,
      changed: changed,
      answeredAt: item.answeredAt,
      at: now ?? DateTime.now(),
    );
    final results = [r, ...state.results];
    state = state.copyWith(
      items: state.items.where((i) => i.key != item.key).toList(),
      results: results.length > maxResults ? results.sublist(0, maxResults) : results,
    );
    return r;
  }
}

final revisitProvider = NotifierProvider<RevisitNotifier, RevisitState>(RevisitNotifier.new);
