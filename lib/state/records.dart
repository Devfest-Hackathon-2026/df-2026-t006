import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/think_card.dart';
import '../services/boss_battle.dart';
import '../services/depth_grader.dart';
import 'providers.dart';

/// 考えきったテーマの記録（記録の画面に並ぶ）。
/// クラウド（Firestore）への保存は services/cloud.dart
class TopicRecord {
  const TopicRecord({
    required this.topicId,
    required this.finishedAt,
    required this.answered,
    required this.total,
    required this.changedMind,
    required this.finalAnswer,
    required this.xp,
    this.grade,
  });

  final String topicId;

  /// 考えきった日時
  final DateTime finishedAt;

  /// 答えたカードの数 / カードの数
  final int answered;
  final int total;

  /// 反論を読んで考えを変えた回数
  final int changedMind;

  /// 最後のカードに書いたこと
  final String finalAnswer;

  /// もらった経験値
  final int xp;

  /// Gemini による考えの深さの判定（判定できなかった時は null）
  final DepthGrade? grade;

  Map<String, Object?> toJson() => {
    'topicId': topicId,
    'finishedAt': finishedAt.millisecondsSinceEpoch,
    'answered': answered,
    'total': total,
    'changedMind': changedMind,
    'finalAnswer': finalAnswer,
    'xp': xp,
    if (grade != null) 'grade': grade!.toJson(),
  };

  static TopicRecord fromJson(Map<String, dynamic> j) => TopicRecord(
    topicId: j['topicId'] as String? ?? '',
    finishedAt: DateTime.fromMillisecondsSinceEpoch((j['finishedAt'] as num?)?.toInt() ?? 0),
    answered: (j['answered'] as num?)?.toInt() ?? 0,
    total: (j['total'] as num?)?.toInt() ?? 0,
    changedMind: (j['changedMind'] as num?)?.toInt() ?? 0,
    finalAnswer: j['finalAnswer'] as String? ?? '',
    xp: (j['xp'] as num?)?.toInt() ?? 0,
    grade: j['grade'] is Map ? DepthGrade.fromJson(Map<String, dynamic>.from(j['grade'] as Map)) : null,
  );
}

class RecordsNotifier extends Notifier<List<TopicRecord>> {
  /// 見た目確認・デモ動画用: `--dart-define=DEMO_RECORDS=true` で、判定つきの記録がある状態から始める
  static const _demo = bool.fromEnvironment('DEMO_RECORDS');

  @override
  List<TopicRecord> build() => _demo ? _demoRecords() : const [];

  static List<TopicRecord> _demoRecords() {
    TopicRecord r(String id, int day, String pattern, List<int> a, String answer) => TopicRecord(
      topicId: id,
      finishedAt: DateTime(2026, 11, day, 20, 15),
      answered: 6,
      total: 6,
      changedMind: 1,
      finalAnswer: answer,
      xp: PlayerNotifier.xpPerTopic,
      grade: DepthGrade(
        axes: {'reasons': a[0], 'counter': a[1], 'change': a[2], 'own': a[3]},
        pattern: pattern,
        goodPoint: '',
        nextQuestion: '',
      ),
    );
    return [
      r('free-will', 8, 'skeptic', [19, 22, 16, 18], '選んだつもりでも、選ばされているのかもしれない。'),
      r('brain-in-vat', 7, 'skeptic', [16, 18, 12, 15], '証明はできないけど、確かめ続けることはできる。'),
      r('trolley', 6, 'consequence', [14, 10, 12, 13], '数だけで決めていいのか、まだ迷っている。'),
      r('theseus', 5, 'intuition', [8, 6, 9, 12], 'なんとなく同じ船だと思う。'),
    ];
  }

  /// 新しい順に並べたいので、先頭に足す
  void add(TopicRecord r) => state = [r, ...state];

  /// クラウドから読み込んだ記録に置きかえる
  void restore(List<TopicRecord> rs) => state = rs;
}

final recordsProvider = NotifierProvider<RecordsNotifier, List<TopicRecord>>(RecordsNotifier.new);

/// ボス戦の記録（記録の画面に並ぶ）
class BattleRecord {
  const BattleRecord({
    required this.topicId,
    required this.boss,
    required this.finishedAt,
    required this.won,
    required this.turns,
    required this.damage,
    required this.bestAttack,
    required this.bestDamage,
    required this.brains,
    this.stars = 2,
    this.bossMaxHp = 100,
    this.log = const [],
  });

  final String topicId;

  /// 難しさ（★1〜3）
  final int stars;

  /// ボスの「確信」の最大値（難しさで変わる）
  final int bossMaxHp;

  /// ボスの名前
  final String boss;
  final DateTime finishedAt;
  final bool won;

  /// 攻撃した回数
  final int turns;

  /// ボスに与えたダメージの合計（0〜bossMaxHp）
  final int damage;

  /// いちばん効いた反論と、そのダメージ
  final String bestAttack;
  final int bestDamage;

  /// もらったちびのう
  final int brains;

  /// やりとりの全部（記録の画面で読み返せる）。会話を残すようになる前の記録は空
  final List<BattleTurn> log;

  /// やりとりを消した、結果だけの記録
  BattleRecord withoutLog() => BattleRecord(
    topicId: topicId,
    boss: boss,
    finishedAt: finishedAt,
    won: won,
    turns: turns,
    damage: damage,
    bestAttack: bestAttack,
    bestDamage: bestDamage,
    brains: brains,
    stars: stars,
    bossMaxHp: bossMaxHp,
  );

  Map<String, Object?> toJson() => {
    'topicId': topicId,
    'boss': boss,
    'finishedAt': finishedAt.millisecondsSinceEpoch,
    'won': won,
    'turns': turns,
    'damage': damage,
    'bestAttack': bestAttack,
    'bestDamage': bestDamage,
    'brains': brains,
    'stars': stars,
    'bossMaxHp': bossMaxHp,
    'log': [for (final t in log) t.toJson()],
  };

  static BattleRecord fromJson(Map<String, dynamic> j) => BattleRecord(
    topicId: j['topicId'] as String? ?? '',
    boss: j['boss'] as String? ?? '',
    finishedAt: DateTime.fromMillisecondsSinceEpoch((j['finishedAt'] as num?)?.toInt() ?? 0),
    won: j['won'] == true,
    turns: (j['turns'] as num?)?.toInt() ?? 0,
    damage: (j['damage'] as num?)?.toInt() ?? 0,
    bestAttack: j['bestAttack'] as String? ?? '',
    bestDamage: (j['bestDamage'] as num?)?.toInt() ?? 0,
    brains: (j['brains'] as num?)?.toInt() ?? 0,
    stars: (j['stars'] as num?)?.toInt() ?? 2,
    bossMaxHp: (j['bossMaxHp'] as num?)?.toInt() ?? 100,
    log: [
      for (final t in (j['log'] as List?) ?? const [])
        if (t is Map) BattleTurn.fromJson(Map<String, dynamic>.from(t)),
    ],
  );
}

class BattleRecordsNotifier extends Notifier<List<BattleRecord>> {
  /// 見た目確認・デモ動画用（記録と同じ --dart-define=DEMO_RECORDS=true）
  static const _demo = bool.fromEnvironment('DEMO_RECORDS');

  @override
  List<BattleRecord> build() => _demo
      ? [
          BattleRecord(
            topicId: 'trolley',
            boss: 'カント',
            finishedAt: DateTime(2026, 11, 8, 21, 40),
            won: true,
            turns: 4,
            damage: 100,
            bestAttack: '何もしないことも選択なら、5人を見捨てたことにならない？ それも人を手段にしていないと言える？',
            bestDamage: 36,
            brains: 9,
            stars: 2,
            log: [
              BattleTurn.fromJson({
                'attack': '5人の命も1人の命も同じ重さなら、助かる人数が多いほうを選ぶべきだと思う。',
                'damage': 18,
                'reason': '人数で比べる理由ははっきりしている',
                'reply': '命を数で比べた時点で、人を「量」として扱っています。1人の側にも、かけがえのない尊厳があるのです。',
                'counter': 12,
              }),
              BattleTurn.fromJson({
                'attack': '何もしないことも選択なら、5人を見捨てたことにならない？ それも人を手段にしていないと言える？',
                'damage': 36,
                'reason': 'ボスの「何もしない＝無罪」の前提を突いた',
                'reply': '鋭い問いです。しかし、見捨てることと、自分の手で殺すことは、同じではないのです。',
                'counter': 3,
              }),
              BattleTurn.fromJson({
                'attack': '自分の手で殺すかどうかより、結果として何人が死ぬかのほうが、死ぬ人にとっては大事では？',
                'damage': 22,
                'reason': '死ぬ側から見る、新しい角度を出した',
                'reply': '……結果を見よ、と。ですが、もし全員がそう考えたら、人はいつでも数のために犠牲にされうるのです。',
                'counter': 8,
              }),
              BattleTurn.fromJson({
                'attack': 'いつでもじゃない。暴走したトロッコみたいに、だれかが必ず死ぬ場面だけの話。そこで原則だけ守って5人を死なせるのは、責任から逃げているだけだと思う。',
                'damage': 24,
                'reason': '場面を限定し、原則の弱点を突いた',
                'reply': '……一理あります。原則を守ることが、責任から目をそらす言い訳になってはならない。認めましょう。',
                'counter': 0,
              }),
            ],
          ),
          BattleRecord(
            topicId: 'theseus',
            boss: 'ヘラクレイトス',
            finishedAt: DateTime(2026, 11, 7, 19, 5),
            won: false,
            turns: 6,
            damage: 72,
            bestAttack: 'あなた自身も細胞が入れかわり続けているのに、昨日と同じヘラクレイトスだと思っているはず。',
            bestDamage: 35,
            brains: 3,
            stars: 3,
            bossMaxHp: 130,
          ),
        ]
      : const [];

  /// やりとりの全部を残しておく記録の数（Firestore の1つの文書は 1MB までなので、古いものは結果だけ残す）
  static const keepLogs = 30;

  /// 新しい順に並べたいので、先頭に足す
  void add(BattleRecord r) {
    final list = [r, ...state];
    state = [
      for (var i = 0; i < list.length; i++)
        if (i < keepLogs || list[i].log.isEmpty) list[i] else list[i].withoutLog(),
    ];
  }

  void restore(List<BattleRecord> rs) => state = rs;
}

final battleRecordsProvider = NotifierProvider<BattleRecordsNotifier, List<BattleRecord>>(BattleRecordsNotifier.new);

/// 「2026/11/07 14:05」の形にする
String formatDateTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.year}/${two(t.month)}/${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// テーマを考えきった時に呼ぶ: 記録を残す（どの「考える画面」からでも同じ）
void recordFinishedTopic(WidgetRef ref, Topic topic, {int changedMind = 0}) {
  final s = ref.read(sessionProvider(topic.id));
  final total = topic.cards.length;
  final answered = [
    for (var i = 0; i < total; i++)
      if (s.choices[i] != null || (s.answers[i] ?? '').trim().isNotEmpty) i,
  ].length;
  ref
      .read(recordsProvider.notifier)
      .add(
        TopicRecord(
          topicId: topic.id,
          finishedAt: DateTime.now(),
          answered: answered,
          total: total,
          changedMind: changedMind,
          finalAnswer: (s.answers[total - 1] ?? '').trim(),
          xp: PlayerNotifier.xpPerTopic,
          grade: ref.read(depthGradeProvider(topic.id))?.value,
        ),
      );
}
