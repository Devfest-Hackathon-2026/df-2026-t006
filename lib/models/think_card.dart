/// 1枚のカード（スクロールの1画面）を表すデータ。
///
/// 問いはすべて人間が書いたもの。AIは問いを生成しない。
class ThinkCard {
  const ThinkCard({
    required this.label,
    this.question,
    this.body,
    this.quote,
    this.quoteAuthor,
    this.choices,
    this.counters,
    this.pollQuestion,
    this.pollOptions,
    this.isInput = false,
    this.isLead = false,
  });

  /// 上部の小さいラベル（例: 「思考実験」）
  final String label;

  /// メインの問い・文章
  final String? question;

  /// 補足テキスト
  final String? body;

  /// 哲学者の言葉
  final String? quote;
  final String? quoteAuthor;

  /// 選択肢（あれば選択カード）
  final List<String>? choices;

  /// 反論（選んだ答えへの「でも…？」）。適当に選んで先へ進むのを防ぎ、もう一度考えてもらう。
  ///   - 選択カード: 選択肢と同じ数・同じ順番
  ///   - 今日の問い: 「そう思う / 思わない / わからない」の順
  ///   - 哲学者の言葉: 「反対 / 賛成 / どちらとも」の順
  final List<String>? counters;

  /// コメント欄の「みんなの投票」用（選択肢のないカード、主に最後の自由記述カード）
  final String? pollQuestion;
  final List<String>? pollOptions;

  /// 自由記述カードかどうか
  final bool isInput;

  /// 最初の「今日の問い」カード（文字を大きく表示）
  final bool isLead;
}

/// 1つのテーマ（1セッション分のカードの束）
class Topic {
  const Topic({required this.id, required this.title, required this.image, required this.cards});

  /// URLに使うID（例: theseus）
  final String id;
  final String title;

  /// テーマ選択で背景に使う画像（assets/topics/）。出典は ../docs/著作物利用シート.md
  final String image;

  final List<ThinkCard> cards;
}
