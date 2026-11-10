import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../data/bosses.dart';
import 'boss_battle.dart';
import 'cloud.dart';

/// ボス戦の手助け（Gemini）:
///   - [simplify]: ボスのむずかしい言葉を、やさしい言葉に言いかえる
///   - [hint]: 長く考えこんでいる時の、反論のヒント（答えそのものは言わない）
class BattleHelper {
  BattleHelper._();

  static const _models = [
    ('gemini-3.5-flash-lite', Duration(seconds: 12)),
    ('gemini-3.5-flash', Duration(seconds: 25)),
  ];

  /// 一度言いかえた言葉は覚えておく（同じ言葉で何度も呼ばない）
  static final _simple = <String, String>{};

  static Future<String> _ask(String system, String prompt, {double temperature = 0.4}) async {
    if (!Cloud.ready) throw Exception('オフライン');
    Object? last;
    for (final (name, wait) in _models) {
      try {
        final model = Cloud.ai.generativeModel(
          model: name,
          systemInstruction: Content.system(system),
          generationConfig: GenerationConfig(
            temperature: temperature,
            thinkingConfig: ThinkingConfig.withThinkingLevel(ThinkingLevel.low),
          ),
        );
        final res = await model.generateContent([Content.text(prompt)]).timeout(wait);
        final text = (res.text ?? '').trim();
        if (text.isNotEmpty) return text;
      } catch (e) {
        last = e;
        debugPrint('Gemini ($name) のボス戦の手助けでエラー: $e');
      }
    }
    throw Exception('Gemini に聞けませんでした: $last');
  }

  /// ボスの言葉を、小学校高学年〜中学生にわかる言葉に言いかえる
  static Future<String> simplify(Boss boss, String text) => _simplify(
    speaker: '哲学者${boss.name}',
    context: 'テーマの問い: ${battleQuestions[boss.topicId] ?? ''}\n${boss.name}の立場: ${boss.stance}',
    text: text,
  );

  /// リールの「哲学者の言葉」（名言）を、やさしい言葉に言いかえる
  static Future<String> simplifyQuote(String quote, {String? author, required String topic}) => _simplify(
    speaker: author == null ? '哲学者' : author.replaceAll('—', '').trim(),
    context: 'テーマ: $topic\n（名言なので、言葉の意味をかみくだいて説明する。テーマとのつながりが分かるようにしてよい）',
    text: quote,
  );

  static Future<String> _simplify({required String speaker, required String context, required String text}) async {
    final cached = _simple[text];
    if (cached != null) return cached;
    final out = await _ask(
      '''
あなたは、哲学ゲームの「やさしく言いかえる係」です。
$speakerの言葉を、小学校高学年〜中学生にもわかる、やさしい日本語に言いかえてください。

ルール:
- 意味は変えない。言っていないことを付け足さない。どちらの立場が正しいかの意見も言わない
- むずかしい言葉・哲学の用語は、ふだんの言葉に置きかえる（例: 「手段」→「道具」、「功利」→「みんなの幸せの合計」）
- 身近なたとえを一つ使ってよい
- 「〜ということ。」のような、ふつうの話し言葉で。2〜3文、全体で100字以内
- 前置き（「やさしく言うと」など）や記号・箇条書きは書かない。言いかえた文だけを書く
''',
      '$context\n\n言いかえる言葉:\n$text',
      temperature: 0.3,
    );
    return _simple[text] = out;
  }

  /// 反論のヒント。答えは言わず、考える糸口になる問いかけを1つ
  static Future<String> hint(Boss boss, BattleState s, {String draft = '', List<String> previous = const []}) {
    final yours = rivalOf(boss)?.stance ?? 'ボスと反対の立場';
    final last = s.turns.lastOrNull?.reply ?? boss.claim;
    return _ask(
      '''
あなたは、哲学ゲーム「ボス戦」でプレイヤーを助けるコーチです。
プレイヤーは「$yours」の立場から、哲学者${boss.name}（立場:「${boss.stance}」）に反論しようとして、考えこんでいます。

ヒントのルール（いちばん大事: 答えを教えない。方向だけを指す）:
- 反論の中身（言うべき理由・反例・具体的な例・結論）は、絶対に書かない。ほのめかすのもだめ
- やることは「どこを見るか」「どんな角度で考えるか」を、ぼんやり指すだけ
  - よい例: 「${boss.name}の言葉の中で、言い切りすぎているところはないかな？」
  - よい例: 「その言葉、いつでも本当に当てはまるだろうか。」
  - よい例: 「『同じ』という言葉、人によって意味がちがわないかな？」（言葉の意味に目を向けさせる程度まで）
  - だめな例: 「〜という例を考えると、〜と言えるよね」（答えになっている）
  - だめな例: 具体的な場面・反例・理由を出すもの
- プレイヤーの下書きがあっても、続きを書いたり直したりしない。考える方向が合っているかを、ぼんやり示すだけでよい
- 前に出したヒントと同じ角度はなるべく避ける
- やさしい言葉の問いかけで、1文・45字以内。前置きや記号・箇条書きは書かない
''',
      '${BossJudge.transcript(boss, s, draft.isEmpty ? '（まだ書いていない）' : '（下書き）$draft')}\n\nボスの直前の言葉: $last'
          '${previous.isEmpty ? '' : '\n\n前に出したヒント（同じ角度は避ける）:\n${previous.join('\n')}'}',
      temperature: 0.7,
    );
  }

  /// Gemini につながらない時のヒント（いくつかを順番に）
  static String offlineHint(Boss boss, int n) {
    final yours = rivalOf(boss)?.stance ?? 'あなたの立場';
    final list = [
      '${boss.name}の言葉の中で、いちばん強く言い切っているところはどこ？ 本当に「いつでも」そう言えるかな？',
      '${boss.name}の言うことは、どんな時でも本当に当てはまるかな？',
      '「$yours」と考えるのは、何を大事にしているから？ その理由を一言で書いてみよう。',
      '${boss.name}の言葉の中に、意味があいまいな言葉はないかな？',
    ];
    return list[n % list.length];
  }
}
