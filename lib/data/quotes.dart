/// ホームの帯に流れる名言（言語ごと）。
/// 出典の扱いは ../docs/著作物利用シート.md の「文章・データ」を参照。
enum QuoteLanguage {
  ja('日本語'),
  en('English');

  const QuoteLanguage(this.label);

  /// 設定画面での表示名
  final String label;
}

class Quote {
  const Quote({required this.ja, required this.en});

  final String ja;
  final String en;

  String text(QuoteLanguage lang) => switch (lang) {
    QuoteLanguage.ja => ja,
    QuoteLanguage.en => en,
  };
}

const quotes = <Quote>[
  Quote(ja: '汝自身を知れ', en: 'Know thyself'),
  Quote(ja: '無知の知 ― ソクラテス', en: 'I know that I know nothing ― Socrates'),
  Quote(ja: '我思う、ゆえに我あり ― デカルト', en: 'I think, therefore I am ― Descartes'),
  Quote(ja: '人間は考える葦である ― パスカル', en: 'Man is a thinking reed ― Pascal'),
  Quote(ja: '万物は流転する ― ヘラクレイトス', en: 'Everything flows ― Heraclitus'),
  Quote(ja: '人間は自由の刑に処せられている ― サルトル', en: 'Man is condemned to be free ― Sartre'),
  Quote(ja: '吟味されない生に、生きる価値はない ― ソクラテス', en: 'The unexamined life is not worth living ― Socrates'),
];
