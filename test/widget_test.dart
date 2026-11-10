import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetsugaku/data/bosses.dart';
import 'package:tetsugaku/services/music.dart';
import 'package:tetsugaku/data/credits.dart';
import 'package:tetsugaku/data/philosopher_comments.dart';
import 'package:tetsugaku/data/philosopher_profiles.dart';
import 'package:tetsugaku/services/boss_battle.dart';
import 'package:tetsugaku/services/depth_grader.dart';
import 'package:tetsugaku/services/philosopher_reply.dart';
import 'package:tetsugaku/data/quotes.dart';
import 'package:tetsugaku/data/topics.dart';
import 'package:tetsugaku/models/think_card.dart';
import 'package:tetsugaku/state/brains.dart';
import 'package:tetsugaku/state/mail.dart';
import 'package:tetsugaku/state/missions.dart';
import 'package:tetsugaku/state/providers.dart';
import 'package:tetsugaku/state/revisit.dart';
import 'package:tetsugaku/widgets/revisit.dart';
import 'package:tetsugaku/state/records.dart';
import 'package:tetsugaku/state/thinking_style.dart';
import 'package:tetsugaku/widgets/gift_button.dart';
import 'package:tetsugaku/widgets/reel_tasks.dart';

void main() {
  test('どのテーマも「今日の問い」で始まり、自由記述で終わる', () {
    for (final t in allTopics) {
      expect(t.cards.first.isLead, isTrue, reason: t.id);
      expect(t.cards.last.isInput, isTrue, reason: t.id);
    }
  });

  test('テーマIDは重複しない', () {
    final ids = allTopics.map((t) => t.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('セッション状態はテーマごとに独立して保持される', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    c.read(sessionProvider('theseus').notifier).goTo(3);
    c.read(sessionProvider('theseus').notifier).choose(2, 1);

    expect(c.read(sessionProvider('theseus')).index, 3);
    expect(c.read(sessionProvider('theseus')).choices[2], 1);
    expect(c.read(sessionProvider('trolley')).index, 0);

    c.read(sessionProvider('theseus').notifier).reset();
    expect(c.read(sessionProvider('theseus')).index, 0);
  });

  test('経験値からレベルとメーターが計算される', () {
    const p = PlayerState(xp: 350);
    expect(p.level, 2);
    expect(p.xpInLevel, 50);
    expect(p.levelProgress, closeTo(50 / 300, 1e-9));
    expect(const PlayerState().level, 1);
  });

  test('テーマを1つ考えきると経験値が増える', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(playerProvider.notifier).addXp(PlayerNotifier.xpPerTopic);
    expect(c.read(playerProvider).xp, PlayerNotifier.xpPerTopic);
  });

  test('名言はどの言語でも空でない', () {
    for (final q in quotes) {
      for (final lang in QuoteLanguage.values) {
        expect(q.text(lang).trim(), isNotEmpty);
      }
    }
  });

  test('名言の言語を設定で切り替えられる（初期値は日本語）', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(settingsProvider).quoteLanguage, QuoteLanguage.ja);
    c.read(settingsProvider.notifier).setQuoteLanguage(QuoteLanguage.en);
    expect(c.read(settingsProvider).quoteLanguage, QuoteLanguage.en);
    // 他の設定は変わらない
    expect(c.read(settingsProvider).lockSeconds, 6);
  });

  test('リールの「やること」はカードの種類で決まる', () {
    const lead = ThinkCard(label: 'a', question: 'q', isLead: true);
    const quote = ThinkCard(label: 'a', quote: 'q');
    const choice = ThinkCard(label: 'a', question: 'q', choices: ['x', 'y']);
    const input = ThinkCard(label: 'a', question: 'q', isInput: true);
    const plain = ThinkCard(label: 'a', question: 'q');
    expect(taskFor(lead), ReelTask.instinct);
    expect(taskFor(quote), ReelTask.agree);
    expect(taskFor(choice), ReelTask.choice);
    expect(taskFor(input), ReelTask.write);
    expect(taskFor(plain), ReelTask.instinct); // 書くのは最後の1枚だけ。他は選ぶだけ
  });

  test('やることは、選ぶか1文字でも書けば終わる', () {
    expect(taskDone(ReelTask.instinct, null, null), isFalse);
    expect(taskDone(ReelTask.instinct, 0, null), isTrue);
    expect(taskDone(ReelTask.choice, null, null), isFalse);
    expect(taskDone(ReelTask.choice, 1, null), isTrue); // 理由は書かなくてよい
    expect(taskDone(ReelTask.write, null, ''), isFalse);
    expect(taskDone(ReelTask.write, null, '   '), isFalse); // 空白だけはだめ
    expect(taskDone(ReelTask.write, null, 'あ'), isTrue); // 1文字でもOK
  });

  test('書くカード（自由記述）は各テーマの最後の1枚だけ', () {
    for (final t in allTopics) {
      final writes = [
        for (final c in t.cards)
          if (taskFor(c) == ReelTask.write) c,
      ];
      expect(writes.length, 1, reason: t.id);
      expect(t.cards.last.isInput, isTrue, reason: t.id);
    }
  });

  test('書くカード以外は、どの答えにも反論がある', () {
    for (final t in allTopics) {
      for (final c in t.cards) {
        final n = switch (taskFor(c)) {
          ReelTask.choice => c.choices!.length,
          ReelTask.instinct => instinctOptions.length,
          ReelTask.agree => 3, // 反対 / 賛成 / どちらとも
          ReelTask.write => null,
        };
        if (n == null) continue;
        expect(c.counters?.length, n, reason: '${t.id}: ${c.question ?? c.quote}');
      }
    }
  });

  test('選んだだけでは進めず、反論に答える必要がある', () {
    final card = allTopics.first.cards[1];
    expect(needsStance(card, null, null), isFalse); // まだ選んでいない
    expect(needsStance(card, 0, null), isTrue); // 選んだ → 反論が出る
    expect(needsStance(card, 0, 1), isFalse); // 反論に答えた
    expect(counterIndex(card, 2), 2);
    // 共感スライダーは 反対 / 賛成 / どちらとも の3つに分かれる
    const quote = ThinkCard(label: 'a', quote: 'q', counters: ['x', 'y', 'z']);
    expect(counterIndex(quote, 10), 0);
    expect(counterIndex(quote, 90), 1);
    expect(counterIndex(quote, 50), 2);
  });

  test('「考えを変える」で選んだ答えが消え、選び直せる', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final s = c.read(sessionProvider('theseus').notifier);
    s.choose(1, 0);
    s.setStance(1, stanceChange);
    s.unchoose(1);
    expect(c.read(sessionProvider('theseus')).choices[1], isNull);
    expect(c.read(sessionProvider('theseus')).stances[1], stanceChange);
  });

  test('最後の自由記述カードには、それに合った投票がある', () {
    for (final t in allTopics) {
      final last = t.cards.last;
      expect(last.pollQuestion, isNotNull, reason: t.id);
      expect(last.pollOptions?.length, greaterThanOrEqualTo(2), reason: t.id);
    }
  });

  test('日時は「2026/11/07 09:05」の形で表示する', () {
    expect(formatDateTime(DateTime(2026, 11, 7, 9, 5)), '2026/11/07 09:05');
  });

  test('ログインボーナスは1日1通メールで届き、読むと経験値（2回読んでも1回分）', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(giftProvider.notifier).deliverToday();
    c.read(giftProvider.notifier).deliverToday();
    expect(c.read(mailProvider).length, 1);
    expect(c.read(unreadMailProvider), 1);
    final id = c.read(mailProvider).single.id;
    c.read(mailProvider.notifier).read(id);
    c.read(mailProvider.notifier).read(id);
    expect(c.read(playerProvider).xp, GiftNotifier.reward);
    expect(c.read(unreadMailProvider), 0);
    expect(c.read(mailProvider).single.read, isTrue);
  });

  test('ミッション: 回数が目標に届くと受け取れて、経験値が増える（同じ期間に2回は受け取れない）', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final vote = missions.firstWhere((m) => m.id == 'd_vote');
    c.read(missionProvider.notifier).claim(vote); // まだ0回なので受け取れない
    expect(c.read(playerProvider).xp, 0);
    for (var i = 0; i < vote.target; i++) {
      c.read(missionProvider.notifier).add(MissionKind.vote);
    }
    c.read(missionProvider.notifier).claim(vote);
    expect(c.read(playerProvider).xp, vote.reward);
    c.read(missionProvider.notifier).claim(vote); // 2回は受け取れない
    expect(c.read(playerProvider).xp, vote.reward);
  });

  test('ミッション: デイリーは次の日、ウィークリーは月曜、マンスリーは1日にリセット。ずっとは残る', () {
    addTearDown(() => missionClock = DateTime.now);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(missionProvider.notifier);
    int progress(String id) => c.read(missionProgressProvider(id));
    missionClock = () => DateTime(2026, 11, 9, 10); // 月曜
    n.add(MissionKind.bossWin);
    expect((progress('w_boss'), progress('m_boss'), progress('e_boss1')), (1, 1, 1));
    n.claim(missions.firstWhere((m) => m.id == 'w_boss'));
    expect(c.read(missionClaimedProvider('w_boss')), isTrue);
    // 同じ週の金曜: 週の数はそのまま
    missionClock = () => DateTime(2026, 11, 13, 10);
    c.invalidate(missionProgressProvider);
    c.invalidate(missionClaimedProvider);
    expect((progress('w_boss'), c.read(missionClaimedProvider('w_boss'))), (1, true));
    // 次の週の月曜: ウィークリーはリセット、マンスリー・ずっとは残る
    missionClock = () => DateTime(2026, 11, 16, 10);
    c.invalidate(missionProgressProvider);
    c.invalidate(missionClaimedProvider);
    expect((progress('w_boss'), progress('m_boss'), progress('e_boss1')), (0, 1, 1));
    expect(c.read(missionClaimedProvider('w_boss')), isFalse);
    // 次の月: マンスリーもリセット
    missionClock = () => DateTime(2026, 12, 1, 10);
    c.invalidate(missionProgressProvider);
    expect((progress('m_boss'), progress('e_boss1')), (0, 1));
    expect(MissionPeriod.weekly.resetAfter(DateTime(2026, 11, 11)), DateTime(2026, 11, 16));
  });

  test('存在しないテーマIDは null', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(topicProvider('nope')), isNull);
  });

  test('深さの判定: 点数は4観点の合計（0〜25に丸める）で、20点ごとに1段階', () {
    final g = DepthGrade.fromJson({
      'axes': {'reasons': 30, 'counter': 20, 'change': -5, 'own': 18},
      'pattern': 'skeptic',
      'goodPoint': 'a',
      'nextQuestion': 'b',
    });
    expect(g.axes, {'reasons': 25, 'counter': 20, 'change': 0, 'own': 18});
    expect(g.score, 63);
    expect(g.depth.name, '深海');
    expect(patternOf(g.pattern).name, '懐疑派');
    expect(patternOf('unknown').id, 'explorer');
    expect(DepthGrade.fromJson({'axes': {}}).depth.name, '水面');
    expect(
      DepthGrade.fromJson({
        'axes': {'reasons': 25, 'counter': 25, 'change': 25, 'own': 25},
      }).depth.name,
      '海溝',
    );
  });

  test('記録は判定ごと保存・読み込みできる', () {
    final r = TopicRecord(
      topicId: 'theseus',
      finishedAt: DateTime(2026, 11, 7, 14, 5),
      answered: 7,
      total: 8,
      changedMind: 1,
      finalAnswer: '同じ船だと思う',
      xp: 100,
      grade: const DepthGrade(
        axes: {'reasons': 20, 'counter': 15, 'change': 10, 'own': 5},
        pattern: 'principle',
        goodPoint: 'g',
        nextQuestion: 'q',
      ),
    );
    final back = TopicRecord.fromJson(r.toJson());
    expect(back.finishedAt, r.finishedAt);
    expect(back.finalAnswer, r.finalAnswer);
    expect(back.grade!.score, 50);
    expect(back.grade!.pattern, 'principle');
    expect(TopicRecord.fromJson({'topicId': 'x'}).grade, isNull);
  });

  test('ボス戦: どのテーマにもボスがいて、顔写真がある', () {
    for (final t in allTopics) {
      final b = bossFor(t.id);
      expect(b, isNotNull, reason: t.id);
      expect(b!.portrait, startsWith('assets/portraits/'));
    }
  });

  test('ボス戦: どのテーマにも反対の立場のボスが2人いて、どちらの側からも戦える', () {
    for (final t in allTopics) {
      final pair = bossesFor(t.id);
      expect(pair.length, 2, reason: t.id);
      expect(pair[0].stance, isNot(pair[1].stance));
      expect(rivalOf(pair[0])!.name, pair[1].name);
      expect(rivalOf(pair[1])!.name, pair[0].name);
      expect(bossFor(t.id, 1)!.name, pair[1].name);
      expect(bossFor(t.id, 9)!.name, pair[1].name); // 範囲外でも落ちない
      expect(bossNamed(t.id, pair[1].name)!.name, pair[1].name);
      for (final b in pair) {
        expect(b.portrait, startsWith('assets/portraits/'));
      }
    }
  });

  test('ボス戦の記録: やりとりも保存でき、古い記録は結果だけ残す', () {
    final turn = BossJudge.parseTurn('反論', {'damage': 33, 'counter': 2, 'reason': 'よい', 'reply': '返事'});
    BattleRecord rec(int i) => BattleRecord(
      topicId: 'theseus',
      boss: 'アリストテレス',
      finishedAt: DateTime(2026, 11, 9, 10, i),
      won: false,
      turns: 1,
      damage: 33,
      bestAttack: '反論',
      bestDamage: 33,
      brains: 2,
      log: [turn],
    );
    final back = BattleRecord.fromJson(rec(0).toJson());
    expect(back.log.single.attack, '反論');
    expect(back.log.single.reply, '返事');
    expect(back.log.single.hit, Hit.mega);
    expect(BattleRecord.fromJson({'boss': 'x'}).log, isEmpty); // 前の形の記録も読める
    final c = ProviderContainer();
    addTearDown(c.dispose);
    for (var i = 0; i < BattleRecordsNotifier.keepLogs + 5; i++) {
      c.read(battleRecordsProvider.notifier).add(rec(i));
    }
    final list = c.read(battleRecordsProvider);
    expect(list.where((r) => r.log.isNotEmpty).length, BattleRecordsNotifier.keepLogs);
    expect(list.last.log, isEmpty);
    expect(list.last.bestAttack, '反論');
  });

  test('BGM: 画面ごとに曲が決まる', () {
    expect(BgmTrack.forPath('/'), BgmTrack.home);
    expect(BgmTrack.forPath('/topics'), BgmTrack.home);
    expect(BgmTrack.forPath('/records'), BgmTrack.home);
    expect(BgmTrack.forPath('/topics/theseus'), BgmTrack.reel);
    expect(BgmTrack.forPath('/topics/battle'), BgmTrack.battle);
    expect(BgmTrack.forPath('/topics/trolley/boss'), BgmTrack.battle);
    expect(BgmTrack.forPath('/hitachan'), BgmTrack.hitachan);
  });

  test('ボス戦: ダメージは0〜40、当たり方は点数で決まる', () {
    BattleTurn t(int d, int c) => BossJudge.parseTurn('x', {'damage': d, 'counter': c, 'reply': 'r'});
    expect(t(55, 0).damage, 40);
    expect(t(35, 0).hit, Hit.mega);
    expect(t(20, 0).hit, Hit.hit);
    expect(t(7, 0).hit, Hit.graze);
    expect(t(0, 0).hit, Hit.miss);
    expect(t(10, 99).counter, 30);
  });

  test('ボス戦: HPが0で勝ち、自分のHPが0かターン切れで負け', () {
    BattleTurn t(int d, int c) => BossJudge.parseTurn('x', {'damage': d, 'counter': c, 'reply': 'r'});
    var s = BattleState();
    s = s.apply(t(40, 10)).apply(t(40, 10));
    expect((s.bossHp, s.playerHp, s.outcome), (20, 80, BattleOutcome.ongoing));
    // 倒した一撃では反撃を受けない
    s = s.apply(t(30, 30));
    expect((s.bossHp, s.playerHp, s.outcome), (0, 80, BattleOutcome.won));

    var lose = BattleState();
    for (var i = 0; i < 4; i++) {
      lose = lose.apply(t(0, 30));
    }
    expect(lose.playerHp, 0);
    expect(lose.outcome, BattleOutcome.lost);

    var timeout = BattleState();
    for (var i = 0; i < timeout.maxTurns; i++) {
      timeout = timeout.apply(t(5, 0));
    }
    expect(timeout.outcome, BattleOutcome.lost);
  });

  test('ちびのう: メールで届き、読むと持ち物に。同じことでは差の分だけ、あげると育つ', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(brainProvider.notifier);
    n.earnUpTo('grade:theseus', 2, 'a');
    n.earnUpTo('grade:theseus', 2, 'a'); // 同じ判定のやり直しでは増えない
    expect((c.read(unreadBrainsProvider), c.read(brainProvider).stock), (2, 0)); // メールに届いただけ
    n.earnUpTo('grade:theseus', 5, 'a'); // 深くなったら差の分
    n.clearKeys('grade:theseus');
    n.earnUpTo('grade:theseus', 1, 'a'); // 次に遊んだ時はまたもらえる
    expect(c.read(unreadBrainsProvider), 6);
    for (final m in [...c.read(mailProvider)]) {
      c.read(mailProvider.notifier).read(m.id); // 1通ずつ読む
    }
    expect((c.read(unreadBrainsProvider), c.read(brainProvider).stock), (0, 6));

    expect(c.read(brainProvider).stage.name, 'しぼみ');
    expect(n.feedAll(), isTrue); // 6 → めざめ（5）
    expect((c.read(brainProvider).stock, c.read(brainProvider).fed), (0, 6));
    expect(c.read(brainProvider).stage.name, 'めざめ');
    expect(n.feedAll(), isFalse);
    expect(c.read(brainProvider).progress, closeTo(0.1, 1e-9));

    final back = BrainState.fromJson(c.read(brainProvider).toJson());
    expect((back.stock, back.fed), (0, 6));
    final mail = Mail.fromJson(c.read(mailProvider).first.toJson());
    expect((mail.brains, mail.read), (1, true));
    expect(BrainState(fed: hitaStages.last.need).nextStage, isNull);
  });

  test('ミッション: 受け取るとEXP、ちびのうはメールへ', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final boss = missions.firstWhere((m) => m.id == 'e_boss1');
    c.read(missionProvider.notifier).add(MissionKind.bossWin);
    c.read(missionProvider.notifier).claim(boss);
    expect(c.read(playerProvider).xp, boss.reward);
    expect(c.read(unreadBrainsProvider), boss.brains);
  });

  test('クレジット: 表記が必要な画像（CC BY / BY-SA）がすべて載っている', () {
    final required = [for (final s in imageCredits) ...s.items.where((c) => c.attributionRequired)];
    expect(
      required.map((c) => c.license).toSet(),
      containsAll(['CC BY 4.0 https://creativecommons.org/licenses/by/4.0/', 'CC BY-SA 3.0']),
    );
    expect(required.length, 4); // 水槽の脳の絵・セネカ・サルトル・ボーヴォワール
    for (final s in imageCredits) {
      for (final c in s.items) {
        expect(c.source, startsWith('https://'), reason: c.title);
      }
    }
  });

  test('思考スタイル: いちばん多い型＋いちばん強い観点の二つ名、変化も追える', () {
    TopicRecord rec(int day, String pattern, Map<String, int> axes) => TopicRecord(
      topicId: 'theseus',
      finishedAt: DateTime(2026, 11, day),
      answered: 8,
      total: 8,
      changedMind: 0,
      finalAnswer: 'x',
      xp: 100,
      grade: DepthGrade(axes: axes, pattern: pattern, goodPoint: '', nextQuestion: ''),
    );
    expect(ThinkingStyle.from(const []), isNull);
    final s = ThinkingStyle.from([
      rec(3, 'skeptic', {'reasons': 20, 'counter': 22, 'change': 10, 'own': 15}),
      rec(1, 'intuition', {'reasons': 5, 'counter': 5, 'change': 5, 'own': 10}),
      rec(2, 'skeptic', {'reasons': 15, 'counter': 20, 'change': 10, 'own': 15}),
    ])!;
    expect(s.archetype.title, '疑いの探偵');
    expect(s.first.title, '直感の詩人'); // いちばん古い判定
    expect(s.changed, isTrue);
    expect(s.axes['counter'], closeTo(47 / 3, 1e-9));
    expect(s.epithet, '反論を恐れない');
    expect(s.fullTitle, '反論を恐れない 疑いの探偵');
    expect(s.axisGrowth['counter'], 17); // 5 → 22
    // 同じ数なら、新しく出てきた型
    final tie = ThinkingStyle.from([
      rec(1, 'empathy', {'reasons': 2}),
      rec(2, 'principle', {'reasons': 2}),
    ])!;
    expect(tie.archetype.title, '法の番人');
    expect(tie.epithet, ''); // 平均が低いと二つ名なし
    expect(archetypes.length, thoughtPatterns.length);
  });

  test('哲学者のプロフィール: 話す哲学者（コメント欄・ボス）全員にあり、コメントの言葉も資料にある', () {
    for (final c in philosopherComments) {
      final p = profileOf(c.name);
      expect(p, isNotNull, reason: c.name);
      // コメントで言っている言葉は、引用してよい言葉に入っている（AI の返事と食い違わないように）
      expect(p!.quotes, contains(c.text), reason: c.name);
      expect(p.toPrompt(), contains(c.name));
    }
    for (final b in bosses) {
      expect(profileOf(b.name), isNotNull, reason: b.name);
    }
  });

  test('ボス戦の記録: 保存して読み込める', () {
    final r = BattleRecord(
      topicId: 'trolley',
      boss: 'カント',
      finishedAt: DateTime(2026, 11, 8, 21, 40),
      won: true,
      turns: 4,
      damage: 100,
      bestAttack: 'a',
      bestDamage: 36,
      brains: 9,
    );
    final back = BattleRecord.fromJson(r.toJson());
    expect((back.boss, back.won, back.turns, back.damage, back.bestDamage, back.brains), ('カント', true, 4, 100, 36, 9));
    expect(back.finishedAt, r.finishedAt);
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(battleRecordsProvider.notifier).add(r);
    c.read(battleRecordsProvider.notifier).add(BattleRecord.fromJson({'boss': 'デカルト'}));
    expect(c.read(battleRecordsProvider).first.boss, 'デカルト'); // 新しい順
  });

  test('ボス戦の難しさ: ★が多いほど HP が多く・ターンが少なく・反撃が強い', () {
    BattleTurn t(int d, int c, Difficulty diff) =>
        BossJudge.parseTurn('x', {'damage': d, 'counter': c, 'reply': 'r'}, difficulty: diff);
    final easy = BattleState(difficulty: Difficulty.easy);
    final hard = BattleState(difficulty: Difficulty.hard);
    expect((easy.bossHp, easy.maxTurns), (80, 7));
    expect((hard.bossHp, hard.maxTurns), (130, 5));
    expect(t(10, 20, Difficulty.easy).counter, 12);
    expect(t(10, 20, Difficulty.hard).counter, 26);
    expect(hard.apply(t(40, 0, Difficulty.hard)).damageDealt, 40);
    expect(Difficulty.ofStars(3), Difficulty.hard);
    expect(Difficulty.ofStars(9), Difficulty.normal);
    expect([Hit.of(30), Hit.of(29), Hit.of(5), Hit.of(4)], [Hit.mega, Hit.hit, Hit.graze, Hit.miss]);
    expect(Hit.graze.label, 'かすり');
  });

  test('哲学者の返事: 1つのリールにつき3回まで（コメントをまたいで数える）', () {
    const me = CommentReply('a');
    const them = CommentReply('b', mine: false);
    expect(PhilosopherReplier.leftIn(const [[]]), 3);
    expect(
      PhilosopherReplier.leftIn(const [
        [me, them],
        [me, them],
      ]),
      1,
    );
    expect(
      PhilosopherReplier.leftIn(const [
        [me, them, me, them],
        [me, them, me],
      ]),
      0,
    );
    expect(
      PhilosopherReplier.usedIn(const [
        [me, them, me, them],
        [me, them],
      ]),
      3,
    );
  });

  test('コピペ防止: 一度に10文字以上増えたら受けつけない（変換中・ふつうの入力は通す）', () {
    var blocked = 0;
    final f = NoPasteFormatter(() => blocked++);
    TextEditingValue v(String t, {TextRange composing = TextRange.empty}) => TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: t.length),
      composing: composing,
    );
    // 1文字ずつは通る
    expect(f.formatEditUpdate(v('あ'), v('あい')).text, 'あい');
    // 貼り付け（いきなり長い文）は止める
    expect(f.formatEditUpdate(v('あ'), v('あ人間は考える葦である。パスカル')).text, 'あ');
    expect(blocked, 1);
    // 変換の確定（変換中だった文字が一気に確定）は通す
    final composing = v('にんげんはかんがえるあしである', composing: const TextRange(start: 0, end: 15));
    expect(f.formatEditUpdate(composing, v('人間は考える葦である')).text, '人間は考える葦である');
    expect(blocked, 1);
  });

  test('もう一度考える: 答えて10分たった問いを、10分に1回だけ出す', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(revisitProvider.notifier);
    final t0 = DateTime(2026, 11, 9, 12);
    const iv = RevisitNotifier.interval;
    n.remember('theseus', 1, 2, now: t0);
    n.remember('trolley', 0, 1, now: t0.add(const Duration(minutes: 1)));
    // まだ時間がたっていない
    expect(n.due(now: t0.add(iv - const Duration(seconds: 1))), isNull);
    // たった: 古い方から
    final first = n.due(now: t0.add(iv))!;
    expect(first.key, 'theseus#1');
    n.shown(now: t0.add(iv));
    // 出したばかりなので、次はまだ
    expect(n.due(now: t0.add(iv * 1.5)), isNull);
    final r = n.answer(first, 0, changed: true, now: t0.add(iv));
    expect(r.before, 2);
    expect(r.after, 0);
    expect(c.read(revisitProvider).items.map((i) => i.key), ['trolley#0']);
    // 次の10分後には、もう1問
    expect(n.due(now: t0.add(iv * 2))?.key, 'trolley#0');
  });

  test('もう一度考える: 同じ問いにまた答えたら上書き・「あとで」は後ろへ・保存して戻せる', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(revisitProvider.notifier);
    final t0 = DateTime(2026, 11, 9, 12);
    n.remember('theseus', 1, 2, now: t0);
    n.remember('theseus', 2, 0, now: t0);
    n.remember('theseus', 1, 3, now: t0);
    expect(c.read(revisitProvider).items.map((i) => '${i.key}=${i.choice}'), ['theseus#2=0', 'theseus#1=3']);
    n.later(c.read(revisitProvider).items.first);
    expect(c.read(revisitProvider).items.first.key, 'theseus#1');
    n.answer(c.read(revisitProvider).items.first, 1, changed: true, now: t0);
    n.shown(now: t0);
    final back = RevisitState.fromJson(c.read(revisitProvider).toJson());
    expect(back.items.map((i) => i.key), ['theseus#2']);
    expect(back.results.single.changed, isTrue);
    expect(back.lastShownAt, t0);
    // 壊れたデータは読み飛ばす
    expect(RevisitState.fromJson({'items': [{'topic': 1}], 'results': 'x'}).items, isEmpty);
  });

  test('もう一度考える: スライダーは、ことばが変わった時だけ「変わった」', () {
    final quote = allTopics.first.cards.firstWhere((c) => c.quote != null);
    expect(revisitChanged(quote, 60, 68), isFalse); // どちらも「やや賛成」
    expect(revisitChanged(quote, 60, 90), isTrue);
    final choice = allTopics.first.cards.firstWhere((c) => c.choices != null);
    expect(revisitChanged(choice, 1, 1), isFalse);
    expect(revisitChanged(choice, 1, 2), isTrue);
  });
}
