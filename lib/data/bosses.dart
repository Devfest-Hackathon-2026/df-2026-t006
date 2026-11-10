/// ボス戦の相手。テーマごとに、反対の立場の哲学者が2人いる。
/// プレイヤーは自分の立場を選び、反対側の哲学者と戦う（理由を言葉にして、ボスの「確信」を削る）。
class Boss {
  const Boss({
    required this.topicId,
    required this.name,
    required this.portrait,
    required this.stance,
    required this.claim,
    required this.voice,
  });

  final String topicId;
  final String name;

  /// 顔写真（assets/portraits/。出典とライセンスは ../docs/著作物利用シート.md）
  final String portrait;

  /// このボスの立場（短く。立場を選ぶ画面に出す）
  final String stance;

  /// ボスの主張（最初のセリフ）
  final String claim;

  /// 話し方（Gemini に演じてもらう時の指示）
  final String voice;
}

/// テーマごとの問い（ボス選びの画面に出す）
const battleQuestions = <String, String>{
  'theseus': '板を全部とりかえた船は、同じ船？',
  'trolley': 'レバーを引いて、5人の代わりに1人を犠牲にする？',
  'brain-in-vat': 'この世界が本物だと言える？',
  'free-will': 'あなたは自分で選んでいる？',
};

const bosses = <Boss>[
  // テセウスの船
  Boss(
    topicId: 'theseus',
    name: 'ヘラクレイトス',
    portrait: 'assets/portraits/heraclitus.jpg',
    stance: '別の船だ',
    claim: '万物は流れる。板が1枚でも変われば、それはもう別の船だ。「同じ船」など、どこにもない。',
    voice: '古代ギリシャの哲学者。謎めいた短い言葉で話す。「〜だ」「〜ではないか」口調',
  ),
  Boss(
    topicId: 'theseus',
    name: 'アリストテレス',
    portrait: 'assets/portraits/aristotle.jpg',
    stance: '同じ船だ',
    claim: 'まず区別しよう。板は船の「材料」にすぎない。形と、人を運ぶという目的が続いている限り、それは同じテセウスの船である。',
    voice: '冷静で整理好きな哲学者。「まず区別しよう」「〜である」口調',
  ),
  // トロッコ問題
  Boss(
    topicId: 'trolley',
    name: 'カント',
    portrait: 'assets/portraits/kant.jpg',
    stance: '引いてはならない',
    claim: '5人を救うためでも、1人を犠牲にしてはならない。人を「道具」として使うことは、決して許されない。',
    voice: '厳格な哲学者。きっちりした丁寧語で、原則を大事にする。「〜です」「〜なのです」口調',
  ),
  Boss(
    topicId: 'trolley',
    name: 'ミル',
    portrait: 'assets/portraits/mill.jpg',
    stance: '引くべきだ',
    claim: '5人が死ぬより、1人が死ぬほうが不幸は少ない。関わる全員の幸福を同じ重さで数えれば、レバーを引くのが正しい行いです。',
    voice: '穏やかで理性的な紳士。結果を一つずつ比べて話す。「〜ではないでしょうか」「〜なのです」口調',
  ),
  // 水槽の脳
  Boss(
    topicId: 'brain-in-vat',
    name: 'デカルト',
    portrait: 'assets/portraits/descartes.jpg',
    stance: '本物だと証明できない',
    claim: 'あなたが今見ているこの世界が本物だと、あなたは証明できない。夢や幻でないと、どうして言える？',
    voice: '疑うことを武器にする哲学者。冷静で、少し挑発的。「〜かね？」「〜だろう」口調',
  ),
  Boss(
    topicId: 'brain-in-vat',
    name: 'ウィトゲンシュタイン',
    portrait: 'assets/portraits/wittgenstein.jpg',
    stance: '疑う意味がない',
    claim: '「全部が夢かもしれない」と疑うにも、疑わずに使っている言葉や確かさがいる。土台ごと疑うことは、意味をなさない。',
    voice: 'ぶっきらぼうで鋭い哲学者。短く言い切る。「〜だ」「〜ではないか」口調',
  ),
  // 自由意志
  Boss(
    topicId: 'free-will',
    name: 'ニーチェ',
    portrait: 'assets/portraits/nietzsche.jpg',
    stance: '自由意志は幻想だ',
    claim: '自由意志など幻想だ。あなたの「選んだ」は、生まれや環境があなたに選ばせたものにすぎない。',
    voice: '情熱的で皮肉っぽい哲学者。力強く断言する。「〜だ！」「〜にすぎぬ」口調',
  ),
  Boss(
    topicId: 'free-will',
    name: 'サルトル',
    portrait: 'assets/portraits/sartre.jpg',
    stance: '人は自由に選んでいる',
    claim: '人間は自由の刑に処せられている。生まれや環境を言い訳にしても、それをどう受け止めるかを選んだのは、きみだ。',
    voice: '熱く、まっすぐな哲学者。「きみは〜」と語りかける口調',
  ),
];

/// そのテーマのボス（2人。反対の立場）
List<Boss> bossesFor(String topicId) => bosses.where((b) => b.topicId == topicId).toList();

/// そのテーマの [index] 番目のボス（範囲外なら1人目）
Boss? bossFor(String topicId, [int index = 0]) {
  final list = bossesFor(topicId);
  if (list.isEmpty) return null;
  return list[index.clamp(0, list.length - 1)];
}

/// 名前からボスを探す（記録の表示用）
Boss? bossNamed(String topicId, String name) =>
    bosses.where((b) => b.topicId == topicId && b.name == name).firstOrNull ?? bossFor(topicId);

/// ボスの反対側（＝プレイヤーの立場）
Boss? rivalOf(Boss b) => bosses.where((x) => x.topicId == b.topicId && x.name != b.name).firstOrNull;
