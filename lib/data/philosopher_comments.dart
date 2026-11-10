/// リール画面のコメント欄に出す、哲学者の言葉（遊び心で「コメント」として表示）。
/// 文章はよく知られた言葉の一般的な日本語訳。出典の扱いは ../docs/著作物利用シート.md
class PhilosopherComment {
  const PhilosopherComment({
    required this.name,
    required this.ago,
    required this.text,
    required this.likes,
    required this.portrait,
  });

  final String name;

  /// 顔写真（assets/portraits/。出典とライセンスは ../docs/著作物利用シート.md）
  final String portrait;

  /// 「何年前のコメントか」の表示
  final String ago;
  final String text;
  final int likes;
}

const philosopherComments = <PhilosopherComment>[
  PhilosopherComment(
    name: 'ソクラテス',
    ago: '2400年前',
    text: '自分が何も知らないということを、私は知っている。',
    likes: 24100,
    portrait: 'assets/portraits/socrates.jpg',
  ),
  PhilosopherComment(
    name: 'プラトン',
    ago: '2400年前',
    text: '驚きこそが、知を愛することの始まりだ。',
    likes: 18300,
    portrait: 'assets/portraits/plato.jpg',
  ),
  PhilosopherComment(
    name: 'アリストテレス',
    ago: '2300年前',
    text: '人間は、本性上ポリス的動物である。',
    likes: 9200,
    portrait: 'assets/portraits/aristotle.jpg',
  ),
  PhilosopherComment(
    name: 'ヘラクレイトス',
    ago: '2500年前',
    text: '同じ川に二度入ることはできない。',
    likes: 15600,
    portrait: 'assets/portraits/heraclitus.jpg',
  ),
  PhilosopherComment(
    name: '孔子',
    ago: '2500年前',
    text: '学びて思わざれば則ち罔し。思いて学ばざれば則ち殆うし。',
    likes: 21000,
    portrait: 'assets/portraits/confucius.jpg',
  ),
  PhilosopherComment(
    name: '老子',
    ago: '2500年前',
    text: '足るを知る者は富む。',
    likes: 12800,
    portrait: 'assets/portraits/laozi.jpg',
  ),
  PhilosopherComment(
    name: 'エピクテトス',
    ago: '1900年前',
    text: '人を悩ませるのは物事ではなく、物事についての考えだ。',
    likes: 30500,
    portrait: 'assets/portraits/epictetus.jpg',
  ),
  PhilosopherComment(
    name: 'セネカ',
    ago: '1950年前',
    text: '生きることを学ぶには、一生かかる。',
    likes: 11400,
    portrait: 'assets/portraits/seneca.jpg',
  ),
  PhilosopherComment(
    name: 'デカルト',
    ago: '390年前',
    text: '我思う、ゆえに我あり。',
    likes: 42000,
    portrait: 'assets/portraits/descartes.jpg',
  ),
  PhilosopherComment(
    name: 'パスカル',
    ago: '360年前',
    text: '人間は考える葦である。',
    likes: 27300,
    portrait: 'assets/portraits/pascal.jpg',
  ),
  PhilosopherComment(
    name: 'カント',
    ago: '240年前',
    text: 'あえて賢くあれ。自分の知性を使う勇気を持て。',
    likes: 16900,
    portrait: 'assets/portraits/kant.jpg',
  ),
  PhilosopherComment(
    name: 'ニーチェ',
    ago: '140年前',
    text: '深淵をのぞくとき、深淵もまたこちらをのぞいている。',
    likes: 38800,
    portrait: 'assets/portraits/nietzsche.jpg',
  ),
  PhilosopherComment(
    name: 'ウィトゲンシュタイン',
    ago: '100年前',
    text: '語りえぬものについては、沈黙しなければならない。',
    likes: 13300,
    portrait: 'assets/portraits/wittgenstein.jpg',
  ),
  PhilosopherComment(
    name: 'サルトル',
    ago: '80年前',
    text: '人間は自由の刑に処せられている。',
    likes: 19700,
    portrait: 'assets/portraits/sartre.jpg',
  ),
  PhilosopherComment(
    name: 'ボーヴォワール',
    ago: '75年前',
    text: '人は女に生まれるのではない、女になるのだ。',
    likes: 14500,
    portrait: 'assets/portraits/beauvoir.jpg',
  ),
];

/// [index] 枚目のカードに出すコメント（毎回同じ顔ぶれになるよう、番号から決める）
List<PhilosopherComment> commentsFor(int index, {int count = 5}) {
  final n = philosopherComments.length;
  return [for (var i = 0; i < count; i++) philosopherComments[(index * 3 + i * 4) % n]];
}

/// 1.2万 のような短い数の表示
String compactCount(int n) {
  if (n >= 10000) {
    final v = n / 10000;
    return '${v.toStringAsFixed(v >= 10 ? 0 : 1)}万';
  }
  // 日本のSNSと同じく「千」は使わず、1万未満はそのまま（3桁ごとにカンマ）
  return n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');
}
