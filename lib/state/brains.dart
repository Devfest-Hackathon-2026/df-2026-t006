import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mail.dart';

/// ひたちゃんの成長の段階
class HitaStage {
  const HitaStage(this.name, this.need, this.message);

  final String name;

  /// この段階になるのに必要な、あげたちびのうの合計
  final int need;

  /// ひたちゃんのひとこと
  final String message;
}

const hitaStages = <HitaStage>[
  HitaStage('しぼみ', 0, 'おなか…すいた…'),
  HitaStage('めざめ', 5, 'ちょっと元気が出てきた！'),
  HitaStage('すくすく', 15, 'もっと「なぜ？」を食べたいな'),
  HitaStage('たくましい', 35, '考えるって、たのしいね！'),
  HitaStage('哲人', 70, 'きみの「なぜ？」が、ぼくを育てた。'),
];

/// ちびのう（Gemini が「ちゃんと考えた」と判定した時にもらえる）と、ひたちゃんの育ち具合。
/// EXP はたくさん遊ぶと増える。ちびのうは、深く考えた時だけ増える。
class BrainState {
  const BrainState({this.stock = 0, this.fed = 0, this.awarded = const {}, this.gain});

  /// まだあげていないちびのう
  final int stock;

  /// ひたちゃんにあげたちびのうの合計（これで育つ）
  final int fed;

  /// 同じことで何度ももらえないように、もらった数を覚えておく（キー → 数）
  final Map<String, int> awarded;

  /// 最後にもらった時（通知に出す）
  final BrainGain? gain;

  int get stageIndex => hitaStages.lastIndexWhere((s) => fed >= s.need);

  HitaStage get stage => hitaStages[stageIndex];

  HitaStage? get nextStage => stageIndex + 1 < hitaStages.length ? hitaStages[stageIndex + 1] : null;

  /// 次の段階までの進み（0〜1。最後の段階なら1）
  double get progress {
    final next = nextStage;
    if (next == null) return 1;
    return (fed - stage.need) / (next.need - stage.need);
  }

  BrainState copyWith({int? stock, int? fed, Map<String, int>? awarded, BrainGain? gain}) => BrainState(
    stock: stock ?? this.stock,
    fed: fed ?? this.fed,
    awarded: awarded ?? this.awarded,
    gain: gain ?? this.gain,
  );

  Map<String, Object?> toJson() => {'stock': stock, 'fed': fed};

  static BrainState fromJson(Map<String, dynamic> j) =>
      BrainState(stock: (j['stock'] as num?)?.toInt() ?? 0, fed: (j['fed'] as num?)?.toInt() ?? 0);
}

/// ちびのうをもらった1回分（通知用。id で新しいかを見分ける）
class BrainGain {
  const BrainGain(this.id, this.amount, this.reason);

  final int id;
  final int amount;
  final String reason;
}

class BrainNotifier extends Notifier<BrainState> {
  @override
  BrainState build() => const BrainState();

  int _gainId = 0;

  void restore(BrainState s) => state = s;

  /// ちびのうをもらう: メールで届く（開いて読むと持ち物に入る）
  void earn(int amount, String reason) {
    if (amount <= 0) return;
    final g = BrainGain(++_gainId, amount, reason);
    state = state.copyWith(gain: g);
    ref
        .read(mailProvider.notifier)
        .deliver(
          Mail(
            id: 'brain-${DateTime.now().microsecondsSinceEpoch}-$_gainId',
            title: 'ちびのうが届きました',
            body: reason,
            receivedAt: DateTime.now(),
            brains: amount,
          ),
        );
  }

  /// メールを読んで受け取ったちびのうを、持ち物に入れる
  void addStock(int amount) => state = state.copyWith(stock: state.stock + amount);

  /// 同じことで何度ももらえないように: [key] でもらった数が [amount] より少ない時だけ、差の分をもらう。
  /// （例: AIの判定をやり直して、深さが上がった時は差の分だけ）
  void earnUpTo(String key, int amount, String reason) {
    final already = state.awarded[key] ?? 0;
    if (amount <= already) return;
    state = state.copyWith(awarded: {...state.awarded, key: amount});
    earn(amount - already, reason);
  }

  /// テーマを考えきった時などに、そのテーマのキーを忘れる（次に遊んだ時、またもらえる）
  void clearKeys(String prefix) =>
      state = state.copyWith(awarded: {...state.awarded}..removeWhere((k, _) => k.startsWith(prefix)));

  /// 持っているちびのうを全部、ひたちゃんにあげる。段階が上がったら true
  bool feedAll() {
    if (state.stock == 0) return false;
    final before = state.stageIndex;
    state = state.copyWith(fed: state.fed + state.stock, stock: 0);
    return state.stageIndex > before;
  }
}

final brainProvider = NotifierProvider<BrainNotifier, BrainState>(BrainNotifier.new);

/// 深さの判定（0〜4: 水面〜海溝）でもらえるちびのう
const brainsForDepth = [0, 1, 2, 3, 5];

/// プロローグを見たか
class PrologueSeen extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool v) => state = v;
}

final prologueSeenProvider = NotifierProvider<PrologueSeen, bool>(PrologueSeen.new);

/// ホームの脳（はじめるボタン）を押したことがあるか。まだなら「おしてみて！」を出す（はじめの1回だけ）
class StartTapped extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool v) => state = v;
}

final startTappedProvider = NotifierProvider<StartTapped, bool>(StartTapped.new);
