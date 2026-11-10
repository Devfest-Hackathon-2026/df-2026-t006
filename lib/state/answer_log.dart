import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 答えの記録（1回答えるごとに1件）。
///
/// 今は端末の中に置いておくだけ。Google Cloud につないだら:
///   - Google Analytics（Firebase）にイベントとして送る / スプレッドシートに書き出して集計する
///   - 「深さ」のスコアに使う: 考えた時間、反論に向き合ったか、最後の文の長さ など
///   - 意見の向き（どの選択肢を選んだか）と固さ（反論で揺らいだか）から、
///     反対の意見の人を見つけて、議論のマッチングに使う
/// TODO: 送る前に、個人がわからない形にする（匿名ID・集計のみ）
class AnswerEvent {
  const AnswerEvent({
    required this.topicId,
    required this.card,
    required this.thinkMs,
    this.choice,
    this.stance,
    this.textLength,
    this.changedMind = false,
    this.revisit = false,
    this.prevChoice,
  });

  final String topicId;

  /// カード番号
  final int card;

  /// 選んだ答え（選択肢の番号・スライダーの値）
  final int? choice;

  /// 反論への答え（stanceOptions の番号）
  final int? stance;

  /// 書いた文の長さ（最後のカード）
  final int? textLength;

  /// 反論を読んで、答えを選び直したか
  final bool changedMind;

  /// カードが出てから答えるまでの時間
  final int thinkMs;

  /// 「もう一度考える」で、時間をおいて答え直したか（その時の前の答えが [prevChoice]）
  final bool revisit;
  final int? prevChoice;

  Map<String, Object?> toJson() => {
    'topic': topicId,
    'card': card,
    'choice': choice,
    'stance': stance,
    'text_length': textLength,
    'changed_mind': changedMind,
    'think_ms': thinkMs,
    'revisit': revisit,
    'prev_choice': prevChoice,
  };
}

class AnswerLog extends Notifier<List<AnswerEvent>> {
  @override
  List<AnswerEvent> build() => const [];

  void add(AnswerEvent e) => state = [...state, e];
}

final answerLogProvider = NotifierProvider<AnswerLog, List<AnswerEvent>>(AnswerLog.new);
