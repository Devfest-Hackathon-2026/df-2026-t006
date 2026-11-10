import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../brand.dart';
import '../data/philosopher_comments.dart';
import '../models/think_card.dart';
import '../state/answer_log.dart';
import '../state/brains.dart';
import '../state/missions.dart';
import '../state/providers.dart';
import '../state/revisit.dart';
import '../state/records.dart';
import '../theme.dart';
import '../widgets/phone_frame.dart';
import '../services/depth_grader.dart';
import '../services/philosopher_reply.dart';
import '../services/battle_helper.dart';
import '../widgets/depth_panel.dart';
import '../widgets/push_button.dart';
import '../widgets/reel_comments.dart';
import '../widgets/reel_tasks.dart';
import '../widgets/slam_text.dart';
import '../widgets/thought_cloud.dart';
import '../widgets/baked_image.dart';

/// 考える画面（リール風）。TikTok / Instagram リールのように、問いが縦に流れる。
///   - 1枚ずつ全画面。背景はテーマの版画が、ゆっくりズームする
///   - 真ん中に白い雲（問い）と、その下に「やること」（直感・共感スライダー・選ぶ。書くのは最後の1枚だけ）
///   - やることが終わり、考える時間（下のバー）も満ちるまで、次へスワイプできない
///   - 下には哲学者のコメントが1つずつ流れてくる。押すとコメント欄
///   - 右側に いいね・コメント・保存・共有。ダブルタップでもいいね
///   - コメント欄: ミッション・みんなの投票・ミニゲーム「誰の言葉？」・コメント（哲学者に返信できる）
///   - 右上の目次ボタン / 最後のページ: これまでのリールの一覧から、好きなリールに戻れる
class ReelSession extends ConsumerStatefulWidget {
  const ReelSession({super.key, required this.topicId});

  final String topicId;

  @override
  ConsumerState<ReelSession> createState() => _ReelSessionState();
}

class _ReelSessionState extends ConsumerState<ReelSession> with TickerProviderStateMixin {
  late final AnimationController _lock = AnimationController(
    vsync: this,
    duration: Duration(seconds: ref.read(settingsProvider).lockSeconds),
  )..addStatusListener((_) => setState(() {}));

  late final PageController _pages = PageController(initialPage: ref.read(sessionProvider(widget.topicId)).index);
  late int _page = ref.read(sessionProvider(widget.topicId)).index;

  /// いいねしたカード
  final _liked = <int>{};

  /// 自分が書いたコメント（カード番号 → コメント）
  final _myComments = <int, List<String>>{};

  /// 自分のコメントへの哲学者の反応（カード番号 → 自分のコメントの番号 → 反応）
  final _reactions = <int, Map<int, PhilosopherReaction>>{};

  /// コメント欄の投票（カード番号 → 選んだ番号）
  final _votes = <int, int>{};

  /// 哲学者のコメントへの返信（カード番号 → コメント番号 → 返信）
  final _replies = <int, Map<int, List<CommentReply>>>{};

  /// 今のページが出た時刻（考えた時間を記録するため）
  DateTime _shownAt = DateTime.now();

  /// 反論を読んで選び直したカード
  final _changedMind = <int>{};

  /// 考えを変える前に選んでいた答え（AIの判定で「考えの動き」を伝えるため）
  final _before = <int, int>{};

  /// 答えを記録する（後で Google Analytics などに送る）
  void _log(int i, {int? stance, int? textLength}) {
    final s = ref.read(sessionProvider(widget.topicId));
    ref
        .read(answerLogProvider.notifier)
        .add(
          AnswerEvent(
            topicId: widget.topicId,
            card: i,
            choice: s.choices[i],
            stance: stance ?? s.stances[i],
            textLength: textLength,
            changedMind: _changedMind.contains(i),
            thinkMs: DateTime.now().difference(_shownAt).inMilliseconds,
          ),
        );
    // 答えが決まった問いは、しばらくしてから「もう一度考える」に出す（書くカードは除く）
    final choice = s.choices[i];
    if (choice != null && taskFor(_topic.cards[i]) != ReelTask.write) {
      ref.read(revisitProvider.notifier).remember(widget.topicId, i, choice);
    }
  }

  /// 選んだ時。反論の種類が変わったら、反論への答えはやり直し
  void _onChoose(int i, int c) {
    final s = ref.read(sessionProvider(widget.topicId));
    final card = _topic.cards[i];
    final before = counterIndex(card, s.choices[i]);
    _session.choose(i, c);
    final stance = s.stances[i];
    if (stance == stanceChange) {
      // 考えを変えて選び直した: ここで答えが決まる
      if (s.choices[i] == null) _log(i);
      return;
    }
    if (stance != null && before != counterIndex(card, c)) _session.setStance(i, null);
    if (counterIndex(card, c) == null && s.choices[i] == null) _log(i);
  }

  /// 反論への答え
  void _onStance(int i, int stance) {
    _session.setStance(i, stance);
    if (stance == stanceChange) {
      _changedMind.add(i);
      // 反論を受け止めて考え直した → ちびのう（1つのカードにつき1回）
      ref.read(missionProvider.notifier).add(MissionKind.changeMind);
      final prev = ref.read(sessionProvider(widget.topicId)).choices[i];
      if (prev != null) _before.putIfAbsent(i, () => prev);
      _session.unchoose(i);
    } else {
      _log(i, stance: stance);
    }
  }

  /// ダブルタップした位置に出すハート
  Offset? _heartAt;
  late final AnimationController _heart = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  Topic get _topic => ref.read(topicProvider(widget.topicId))!;
  SessionNotifier get _session => ref.read(sessionProvider(widget.topicId).notifier);

  /// 今のページの「やること」が終わったか
  bool get _taskDone {
    if (_page >= _topic.cards.length) return true;
    final s = ref.read(sessionProvider(widget.topicId));
    final card = _topic.cards[_page];
    return taskDone(taskFor(card), s.choices[_page], s.answers[_page]) &&
        !needsStance(card, s.choices[_page], s.stances[_page]);
  }

  /// 次へ進めないか: 一番先のページで、考える時間がまだ、または やることがまだ
  bool get _locked {
    final furthest = ref.read(sessionProvider(widget.topicId)).index;
    if (_page != furthest || _page >= _topic.cards.length) return false;
    return !_lock.isCompleted || !_taskDone;
  }

  /// 下に出す案内の文
  String get _hint {
    if (!_locked) return '↑ スワイプして次へ';
    if (!_lock.isCompleted) return '考えてみよう…';
    final s = ref.read(sessionProvider(widget.topicId));
    final card = _topic.cards[_page];
    if (needsStance(card, s.choices[_page], s.stances[_page])) return '反論に答えると、次へ進めます';
    return taskHint(taskFor(card));
  }

  @override
  void initState() {
    super.initState();
    _lock.forward();
  }

  /// このリールで、哲学者が AI で返事をした回数（返信へも、自分のコメントへも）
  int _aiRepliesIn(int i) =>
      PhilosopherReplier.usedIn((_replies[i] ?? const {}).values) +
      (_reactions[i]?.values.where((r) => r.text != null).length ?? 0);

  @override
  void dispose() {
    _lock.dispose();
    _heart.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _onPageChanged(int p) {
    final furthest = ref.read(sessionProvider(widget.topicId)).index;
    setState(() => _page = p);
    if (p > furthest) {
      // 新しい問いへ進んだ: 進み具合を記録して、考える時間を数え始める
      _session.goTo(p);
      _lock.forward(from: 0);
      _shownAt = DateTime.now();
      HapticFeedback.selectionClick();
    }
  }

  void _toggleLike(int i, {bool onlyLike = false}) {
    setState(() {
      if (_liked.contains(i)) {
        if (!onlyLike) _liked.remove(i);
      } else {
        _liked.add(i);
      }
    });
    HapticFeedback.lightImpact();
  }

  void _doubleTapLike(int i, Offset at) {
    _toggleLike(i, onlyLike: true);
    setState(() => _heartAt = at);
    _heart.forward(from: 0);
  }

  /// Gemini に読んでもらう「考えた記録」（問い・選んだ答え・反論への答え・考えた時間・最後に書いた文）
  String _transcript() {
    final topic = _topic;
    final s = ref.read(sessionProvider(widget.topicId));
    final log = ref.read(answerLogProvider).where((e) => e.topicId == widget.topicId);
    final b = StringBuffer('テーマ: ${topic.title}\n');
    for (var i = 0; i < topic.cards.length; i++) {
      final card = topic.cards[i];
      final t = taskFor(card);
      b.writeln(
        '\n[${i + 1}] ${card.quote != null ? '名言: 「${card.quote}」（${card.quoteAuthor ?? ''}）' : '問い: ${card.question ?? card.label}'}',
      );
      if (t == ReelTask.write) {
        final text = (s.answers[i] ?? '').trim();
        b.writeln('  最後に自分の言葉で書いた文: ${text.isEmpty ? '（何も書いていない）' : '「$text」'}');
        continue;
      }
      if (t == ReelTask.agree) b.writeln('  （0=反対〜100=賛成のスライダー）');
      final first = _before[i];
      if (first != null) {
        b.writeln('  最初の答え: ${_answerOf(card, first, null) ?? first}');
        final c = counterIndex(card, first);
        if (c != null) b.writeln('  読んだ反論: ${card.counters![c]}');
        b.writeln('  → 反論を読んで「考えを変える」を選び、選び直した');
      }
      final now = s.choices[i];
      b.writeln(
        '  ${first != null ? '選び直した答え' : '答え'}: ${now == null ? '（答えていない）' : _answerOf(card, now, null) ?? now}',
      );
      if (first == null) {
        final c = counterIndex(card, now);
        final st = s.stances[i];
        if (c != null) b.writeln('  読んだ反論: ${card.counters![c]}');
        if (st != null) b.writeln('  反論への答え: ${stanceOptions[st]}');
      }
      final ms = log.where((e) => e.card == i).lastOrNull?.thinkMs;
      if (ms != null) b.writeln('  考えた時間: ${(ms / 1000).round()}秒');
    }
    b.writeln('\n反論を読んで考えを変えた回数: ${_changedMind.length}');
    return b.toString();
  }

  /// ふりかえり（これまでのリールのまとめ）のページへ
  void _toRecap() {
    HapticFeedback.lightImpact();
    _pages.animateToPage(
      _topic.cards.length,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeInOutCubic,
    );
  }

  /// 最後に判定した時の記録（書き直したら、もう一度測る）
  String? _gradedTranscript;

  /// ミッション「深海以上」を数えたテーマ
  final _deepCounted = <String>{};

  /// 最後のカードで、書いてAIに測ってもらったか（「考えきった！おわる」「書き直す」を出す）
  bool _wrote = false;

  /// 書き直した回数（入力欄を作り直す）
  int _writeVersion = 0;

  /// 書き直す: 書いた文を消して、もう一度
  void _rewrite() {
    final last = _topic.cards.length - 1;
    _session.setAnswer(last, '');
    setState(() {
      _wrote = false;
      _writeVersion++;
    });
  }

  /// AIの判定をポップアップで出す
  void _openGrade() {
    setState(() => _wrote = true);
    final t = _transcript();
    final grade = ref.read(depthGradeProvider(widget.topicId).notifier);
    if (t != _gradedTranscript || ref.read(depthGradeProvider(widget.topicId)) is AsyncError) {
      _gradedTranscript = t;
      grade.grade(t);
    }
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => _GradeSheet(
        topicId: widget.topicId,
        transcript: _transcript,
        onRecap: () {
          Navigator.of(sheet).pop();
          _toRecap();
        },
      ),
    );
  }

  void _finish() {
    // 最後のカード（書いた文）を記録
    final last = _topic.cards.length - 1;
    _log(last, textLength: (ref.read(sessionProvider(widget.topicId)).answers[last] ?? '').trim().length);
    recordFinishedTopic(ref, _topic, changedMind: _changedMind.length);
    ref.read(completedTopicsProvider.notifier).complete(widget.topicId);
    ref.read(missionProvider.notifier).add(MissionKind.topic);
    ref.read(playerProvider.notifier).addXp(PlayerNotifier.xpPerTopic);
    // ちびのうは、考えきった時にまとめてメールで届く（深さの判定 + 反論で考えを変えた数）
    final grade = ref.read(depthGradeProvider(widget.topicId))?.value;
    final fromDepth = grade == null ? 0 : brainsForDepth[grade.level];
    final brains = fromDepth + _changedMind.length;
    ref
        .read(brainProvider.notifier)
        .earn(
          brains,
          'テーマ「${_topic.title}」を考えきった'
          '${grade == null ? '' : '（深さ「${grade.depth.name}」${fromDepth > 0 ? ' +$fromDepth' : ''}）'}'
          '${_changedMind.isEmpty ? '' : '（反論で考えを変えた +${_changedMind.length}）'}',
        );
    _session.reset();
    ref.read(depthGradeProvider(widget.topicId).notifier).reset();
    context.go('/');
  }

  /// 目次から、見たことのあるリールへ移動する
  void _jumpTo(int i) {
    if (i > ref.read(sessionProvider(widget.topicId)).index) return;
    _pages.animateToPage(i, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
  }

  /// 目次（コマンドパネル）を下から出す
  void _openIndex() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheet) => Consumer(
        builder: (context, ref, _) => _IndexSheet(
          topic: _topic,
          session: ref.watch(sessionProvider(widget.topicId)),
          current: _page,
          onJump: (i) {
            Navigator.of(sheet).pop();
            _jumpTo(i);
          },
        ),
      ),
    );
  }

  void _openComments(int i) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReelCommentsSheet(
        topicTitle: _topic.title,
        card: _topic.cards[i],
        index: i,
        comments: commentsFor(i),
        mine: _myComments[i] ?? const [],
        myVote: _votes[i],
        reactions: _reactions[i] ?? const {},
        onPost: (text, philosopher) async {
          final mine = _myComments[i] ??= [];
          setState(() => mine.add(text));
          ref.read(missionProvider.notifier).add(MissionKind.comment);
          final k = mine.length - 1;
          final card = _topic.cards[i];
          // 返事できる回数が残っていれば哲学者が返事、なければ「いいね」
          final answer = await PhilosopherReplier.reply(
            comment: commentsFor(i)[philosopher],
            topicTitle: _topic.title,
            question: card.question ?? card.quote ?? card.label,
            thread: [CommentReply(text)],
            usedInReel: _aiRepliesIn(i),
            toUserComment: true,
          );
          final r = PhilosopherReaction(philosopher, answer);
          if (mounted) setState(() => (_reactions[i] ??= {})[k] = r);
          return r;
        },
        onVote: (v) {
          // 経験値とミッションは、そのリールで初めて投票した時だけ
          if (!_votes.containsKey(i)) {
            ref.read(playerProvider.notifier).addXp(5);
            ref.read(missionProvider.notifier).add(MissionKind.vote);
          }
          setState(() => _votes[i] = v);
        },
        onQuizCorrect: () {
          ref.read(playerProvider.notifier).addXp(10);
          ref.read(missionProvider.notifier).add(MissionKind.quizWin);
        },
        replies: _replies[i] ?? const {},
        onReply: (c, text) async {
          final thread = (_replies[i] ??= {})[c] ??= [];
          setState(() => thread.add(CommentReply(text)));
          ref.read(missionProvider.notifier).add(MissionKind.reply);
          // 哲学者（AI）の返事。コメント欄を閉じても、次に開いた時に残っている
          final card = _topic.cards[i];
          final answer = await PhilosopherReplier.reply(
            comment: commentsFor(i)[c],
            topicTitle: _topic.title,
            question: card.question ?? card.quote ?? card.label,
            thread: thread,
            usedInReel: _aiRepliesIn(i),
          );
          if (answer != null && mounted) setState(() => thread.add(CommentReply(answer, mine: false)));
          return answer;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // AIの判定が出た時: ミッションだけ数える（ちびのうは、テーマを考えきった時にまとめて届く）
    ref.listen(depthGradeProvider(widget.topicId), (_, next) {
      if (next case AsyncData(:final value)) {
        // ミッション: 深海（3）以上。同じテーマで何度判定しても1回だけ数える
        if (value.level >= 3 && _deepCounted.add(widget.topicId)) {
          ref.read(missionProvider.notifier).add(MissionKind.deepGrade);
        }
      }
    });

    final topic = ref.watch(topicProvider(widget.topicId))!;
    final session = ref.watch(sessionProvider(widget.topicId));
    final cards = topic.cards;

    return Scaffold(
      backgroundColor: Colors.black,
      body: PhoneFrame(
        background: const LinearGradient(colors: [Colors.black, Colors.black]),
        child: Stack(
          children: [
            // マウスやトラックパッドでもドラッグでめくれるようにする（PC用）
            ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(
                dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse, PointerDeviceKind.trackpad},
                scrollbars: false,
              ),
              child: PageView.builder(
                controller: _pages,
                scrollDirection: Axis.vertical,
                // 考える時間とやることが終わるまでは、次へめくれない
                physics: _locked ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
                onPageChanged: _onPageChanged,
                itemCount: cards.length + 1,
                itemBuilder: (context, i) {
                  if (i == cards.length) {
                    return _EndPage(topic: topic, session: session, onJump: _jumpTo, onFinish: _finish);
                  }
                  final comments = commentsFor(i);
                  // 入力欄がキーボードの上に見えるように動く時も、リール（ページ）自体は動かさない
                  // （動くと前のリールがのぞく）。入力欄はページの中でだけ見える位置へ
                  return _NoReveal(
                    child: GestureDetector(
                      onDoubleTapDown: (d) => _doubleTapLike(i, d.localPosition),
                      onDoubleTap: () {},
                      child: _ReelPage(
                        topic: topic,
                        card: cards[i],
                        index: i,
                        active: i == _page,
                        choice: session.choices[i],
                        text: session.answers[i],
                        stance: session.stances[i],
                        onChoose: (c) => _onChoose(i, c),
                        onStance: (st) => _onStance(i, st),
                        onText: (t) => _session.setAnswer(i, t),
                        onSubmit: taskFor(cards[i]) == ReelTask.write ? _openGrade : null,
                        onNext: () {},
                        onFinish: i == cards.length - 1 && _wrote ? _toRecap : null,
                        onRewrite: _rewrite,
                        writeVersion: _writeVersion,
                        previews: i == cards.length - 1
                            ? _PreviewStrip(topic: topic, session: session, onJump: _jumpTo, onIndex: _openIndex)
                            : null,
                        floating: _FloatingComment(comments: comments, onTap: () => _openComments(i)),
                        rail: _ActionRail(
                          liked: _liked.contains(i),
                          likes: 12000 + (i * 7919) % 88000 + (_liked.contains(i) ? 1 : 0),
                          comments: comments.length + (_myComments[i]?.length ?? 0),
                          onLike: () => _toggleLike(i),
                          onComments: () => _openComments(i),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // 上: 閉じる・題名・何枚目か
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(
                  children: [
                    PushButton.circle(
                      size: 40,
                      depth: 3,
                      face: Colors.black.withValues(alpha: 0.35),
                      edge: Colors.black.withValues(alpha: 0.5),
                      border: AppColors.ink.withValues(alpha: 0.6),
                      onPressed: () => context.go('/topics'),
                      child: const Icon(Icons.close_rounded, color: AppColors.ink, size: 20),
                    ),
                    const Spacer(),
                    Text(
                      topic.title,
                      style: sans(15, weight: FontWeight.w800).copyWith(shadows: _shadow),
                    ),
                    const Spacer(),
                    // 目次: 押すと、これまでのリールの一覧
                    GestureDetector(
                      onTap: _openIndex,
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.ink.withValues(alpha: 0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.grid_view_rounded, size: 15, color: AppColors.ink),
                            const SizedBox(width: 5),
                            Text(
                              '${math.min(_page + 1, cards.length)}/${cards.length}',
                              style: sans(12, weight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 下: 動画の再生バーのような、考える時間のバー
            if (_page < cards.length)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: RepaintBoundary(
                  child: _ThinkBar(lock: _lock, locked: _locked, hint: _hint, revisit: _page < session.index),
                ),
              ),
            // ダブルタップのハート
            if (_heartAt != null)
              AnimatedBuilder(
                animation: _heart,
                builder: (context, _) {
                  final t = _heart.value;
                  if (t == 0 || t == 1) return const SizedBox.shrink();
                  final scale = t < 0.3 ? Curves.easeOutBack.transform(t / 0.3) * 1.2 : 1.2 - (t - 0.3) * 0.3;
                  return Positioned(
                    left: _heartAt!.dx - 50,
                    top: _heartAt!.dy - 50 - t * 40,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: t < 0.7 ? 1 : (1 - (t - 0.7) / 0.3),
                        child: Transform.scale(
                          scale: scale,
                          child: const Icon(Icons.favorite_rounded, size: 100, color: AppColors.red),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

const _shadow = [Shadow(color: Color(0xCC000000), blurRadius: 8)];

/// 雲の上の、本文などの文字色
const _cloudSub = Color(0xFF4A4D50);

/// 1枚分（全画面）
class _ReelPage extends StatelessWidget {
  const _ReelPage({
    required this.topic,
    required this.card,
    required this.index,
    required this.active,
    required this.choice,
    required this.text,
    required this.onChoose,
    required this.onText,
    required this.stance,
    required this.onStance,
    required this.floating,
    required this.rail,
    this.previews,
    this.onSubmit,
    this.onNext,
    this.onFinish,
    this.onRewrite,
    this.writeVersion = 0,
  });

  final Topic topic;
  final ThinkCard card;
  final int index;

  /// 今表示中のページか（背景のズームと文字のアニメーションはこの時だけ）
  final bool active;
  final int? choice;
  final String? text;
  final ValueChanged<int> onChoose;
  final ValueChanged<String> onText;
  final int? stance;
  final ValueChanged<int> onStance;
  final Widget floating;
  final Widget rail;

  /// 最後のカードだけ: これまでのリールのプレビュー（コメントとキャプションの代わりに出す）
  final Widget? previews;

  /// 書くカードで Enter・ボタン（AIの判定を出す）
  final VoidCallback? onSubmit;

  /// 反論に答えた後の「上にスワイプ」の案内
  final VoidCallback? onNext;

  /// 最後のカード: 「考えきった！おわる」「書き直す」
  final VoidCallback? onFinish;
  final VoidCallback? onRewrite;
  final int writeVersion;

  /// 版画を白黒・高コントラストにして少し暗く
  static const _engrave = ColorFilter.matrix(<double>[
    0.36, 1.2, 0.12, 0, -90, //
    0.35, 1.18, 0.12, 0, -92, //
    0.33, 1.1, 0.1, 0, -96, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    // キーボードが出ている間: 問いと入力欄だけを、キーボードのすぐ上に（ほかの飾りは隠す）
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final typing = active && keyboard > 80;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 背景: テーマの版画がゆっくりズーム
        TweenAnimationBuilder<double>(
          key: ValueKey('bg$index$active'),
          tween: Tween(begin: 1.0, end: active ? 1.12 : 1.0),
          duration: const Duration(seconds: 14),
          builder: (context, s, child) => Transform.scale(scale: s, filterQuality: FilterQuality.medium, child: child),
          // 白黒にした絵は1回だけ作って使い回す（ズーム中に毎フレームかけ直さない）
          child: RepaintBoundary(
            child: BakedImage(topic.image, filter: _engrave, alignment: Alignment(math.sin(index * 1.7) * 0.6, 0)),
          ),
        ),
        // 上下を暗くして文字を読みやすく
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xAA000000), Color(0x22000000), Color(0x66000000), Color(0xEE000000)],
              stops: [0.0, 0.25, 0.55, 1.0],
            ),
          ),
        ),
        // 右: アクション
        // ※ キーボードを出している間は、消さずに見えなくするだけ（消すと並びが変わって入力欄が作り直され、キーボードが閉じてしまう）
        Positioned(
          right: 10,
          bottom: previews != null ? 214 : 150,
          child: Visibility(visible: !typing, maintainState: true, child: rail),
        ),
        // 真ん中: 問いと、やること（開いた瞬間に目に入るように、画面の中央に大きく）
        Positioned(
          key: const ValueKey('reel-content'),
          left: 20,
          right: typing ? 20 : 76,
          top: 70,
          bottom: typing ? keyboard + 8 : 200,
          child: Align(
            alignment: typing ? Alignment.bottomCenter : Alignment.center,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 白い雲の中に問い（フォンク風: 極太の文字が1文字ずつ落ちてくる）
                  // 答えを選ぶと、雲がくるっと裏返って「反論」（灰色の雲）になる。反論に答えると、表（問い）にもどる
                  _FlipCloud(
                    // 反論に答えた後も裏のまま（「考えを変える」の時だけ表にもどる）
                    flipped: counterIndex(card, choice) != null,
                    front: ThoughtCloud(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (card.question != null)
                            SlamText(
                              card.question!,
                              fontSize: card.isLead ? 30 : 26,
                              play: active,
                              onLight: true,
                              key: ValueKey('q$index'),
                            ),
                          if (card.quote != null) ...[
                            SlamText(
                              '「${card.quote!}」',
                              fontSize: 26,
                              play: active,
                              onLight: true,
                              key: ValueKey('quote$index'),
                            ),
                            if (card.quoteAuthor != null) ...[
                              const SizedBox(height: 12),
                              // 言った人を、署名のように大きく（顔写真があれば一緒に）
                              _QuoteAuthor(author: card.quoteAuthor!),
                            ],
                            const SizedBox(height: 8),
                            // わからない時は、やさしい言葉に言いかえてもらえる（AI）
                            _EasyQuote(quote: card.quote!, author: card.quoteAuthor, topic: topic.title),
                          ],
                          if (card.body != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              card.body!,
                              style: sans(15, weight: FontWeight.w500, color: _cloudSub, height: 1.65),
                            ),
                          ],
                        ],
                      ),
                    ),
                    back: counterIndex(card, choice) != null
                        ? ThoughtCloud(
                            color: _counterCloud,
                            glow: AppColors.red,
                            child: _CounterInCloud(
                              key: ValueKey('counter$index-${counterIndex(card, choice)}'),
                              text: card.counters![counterIndex(card, choice)!],
                              answer: answerLabel(card, choice!),
                              play: active,
                            ),
                          )
                        : null,
                  ),
                  // 雲の下に「やること」
                  const SizedBox(height: 10),
                  ReelTaskPanel(
                    task: taskFor(card),
                    card: card,
                    index: index,
                    choice: choice,
                    text: text,
                    onChoose: onChoose,
                    onText: onText,
                    stance: stance,
                    onStance: onStance,
                    onSubmit: onSubmit,
                    onNext: onNext,
                    onFinish: onFinish,
                    onRewrite: onRewrite,
                    writeVersion: writeVersion,
                  ),
                ],
              ),
            ),
          ),
        ),
        // 下: 流れてくる哲学者のコメント
        if (previews != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 34,
            child: Visibility(visible: !typing, maintainState: true, child: previews!),
          ),
        if (previews == null)
          Positioned(
            left: 18,
            right: 78,
            bottom: 132,
            child: Visibility(visible: !typing, maintainState: true, child: floating),
          ),
        // 左下: リールのキャプション（アカウント・テーマ名・カードの種類・ハッシュタグ）
        if (previews == null)
          Positioned(
            left: 18,
            right: 78,
            bottom: 44,
            child: Visibility(
              visible: !typing,
              maintainState: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const _GuideAvatar(size: 30),
                      const SizedBox(width: 8),
                      Text(
                        '@hitatetsu',
                        style: sans(13, weight: FontWeight.w800).copyWith(shadows: _shadow),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${topic.title}　・　${card.label}',
                    style: sans(14, weight: FontWeight.w700).copyWith(shadows: _shadow),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '#哲学 #${topic.title} #考える',
                    style: sans(12, weight: FontWeight.w700, color: AppColors.accent).copyWith(shadows: _shadow),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 下に1つずつ流れてくる、哲学者のコメント（押すとコメント欄が開く）
class _FloatingComment extends StatefulWidget {
  const _FloatingComment({required this.comments, required this.onTap});

  final List<PhilosopherComment> comments;
  final VoidCallback onTap;

  @override
  State<_FloatingComment> createState() => _FloatingCommentState();
}

class _FloatingCommentState extends State<_FloatingComment> {
  int _i = 0;
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) setState(() => _i = (_i + 1) % widget.comments.length);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comments[_i];
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(a),
            child: child,
          ),
        ),
        layoutBuilder: (current, previous) => Stack(alignment: Alignment.bottomLeft, children: [...previous, ?current]),
        child: Align(
          key: ValueKey(_i),
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.ink.withValues(alpha: 0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(c.portrait, fit: BoxFit.cover),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${c.name}  ',
                          style: sans(12, weight: FontWeight.w800),
                        ),
                        TextSpan(
                          text: c.text,
                          style: sans(12, color: AppColors.bodyText),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 案内人の顔（ロゴの脳と∞）
class _GuideAvatar extends StatelessWidget {
  const _GuideAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: logoBlack,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.ink, width: 1.5),
      ),
      child: ClipOval(child: Image.asset(LogoAsset.mark, fit: BoxFit.contain)),
    );
  }
}

/// 右側: 案内人の顔・いいね・コメント・保存・共有
class _ActionRail extends StatelessWidget {
  const _ActionRail({
    required this.liked,
    required this.likes,
    required this.comments,
    required this.onLike,
    required this.onComments,
  });

  final bool liked;
  final int likes;
  final int comments;
  final VoidCallback onLike;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    Widget action(IconData icon, String label, VoidCallback onTap, {Color color = AppColors.ink}) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Column(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                child: Icon(icon, key: ValueKey('$icon$color'), size: 34, color: color, shadows: _shadow),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: sans(11, weight: FontWeight.w800).copyWith(shadows: _shadow),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      width: 56,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _GuideAvatar(size: 44),
          const SizedBox(height: 10),
          action(
            liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            compactCount(likes),
            onLike,
            color: liked ? AppColors.red : AppColors.ink,
          ),
          action(Icons.mode_comment_outlined, compactCount(comments), onComments),
          action(Icons.bookmark_border_rounded, '保存', () {}),
          action(Icons.reply_rounded, '共有', () {}),
        ],
      ),
    );
  }
}

/// 下の細いバー。考える時間の間は満ちていき、満ちてやることも終わったら「上にスワイプ」
class _ThinkBar extends StatelessWidget {
  const _ThinkBar({required this.lock, required this.locked, required this.hint, required this.revisit});

  final AnimationController lock;
  final bool locked;

  /// 案内の文
  final String hint;

  /// 前に見たページを見返している時（バーは満タン）
  final bool revisit;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: lock,
        builder: (context, _) {
          final v = revisit ? 1.0 : lock.value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: locked ? 0.8 : 1,
                child: Text(
                  hint,
                  style: sans(12, weight: FontWeight.w700).copyWith(shadows: _shadow),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 3,
                child: Stack(
                  children: [
                    Container(color: Colors.white.withValues(alpha: 0.2)),
                    FractionallySizedBox(
                      widthFactor: v,
                      child: Container(color: AppColors.ink),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// そのリールで自分が答えたこと（まだなら null）
String? _answerOf(ThinkCard card, int? choice, String? text) {
  final t = taskFor(card);
  if (!taskDone(t, choice, text)) return null;
  return switch (t) {
    ReelTask.instinct => instinctOptions[choice!],
    ReelTask.choice => card.choices![choice!],
    ReelTask.agree =>
      choice! < 20
          ? '反対'
          : choice < 45
          ? 'やや反対'
          : choice <= 55
          ? 'どちらとも'
          : choice <= 80
          ? 'やや賛成'
          : '賛成',
    ReelTask.write => text!.trim(),
  };
}

/// 目次（コマンドパネル）: これまでのリールの一覧。押すとそのリールへ戻れる
class _ReelIndex extends StatelessWidget {
  const _ReelIndex({required this.topic, required this.session, required this.current, required this.onJump});

  final Topic topic;
  final SessionState session;

  /// 今見ているリール（なければ -1）
  final int current;
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context) {
    final cards = topic.cards;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < cards.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _IndexRow(
              number: i + 1,
              card: cards[i],
              answer: _answerOf(cards[i], session.choices[i], session.answers[i]),
              isCurrent: i == current,
              open: i <= session.index,
              onTap: () => onJump(i),
            ),
          ),
      ],
    );
  }
}

class _IndexRow extends StatelessWidget {
  const _IndexRow({
    required this.number,
    required this.card,
    required this.answer,
    required this.isCurrent,
    required this.open,
    required this.onTap,
  });

  final int number;
  final ThinkCard card;
  final String? answer;
  final bool isCurrent;

  /// まだ見ていないリールは開けない
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = card.question ?? '「${card.quote}」';
    return Opacity(
      opacity: open ? 1 : 0.4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: open
            ? () {
                HapticFeedback.selectionClick();
                onTap();
              }
            : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
          decoration: BoxDecoration(
            color: isCurrent ? AppColors.navy : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.ink.withValues(alpha: isCurrent ? 0.9 : 0.25)),
          ),
          child: Row(
            children: [
              // 番号（答えたら緑のチェック）
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: answer != null ? AppColors.xpGreen : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(color: answer != null ? AppColors.xpGreen : AppColors.ink.withValues(alpha: 0.5)),
                ),
                child: answer != null
                    ? const Icon(Icons.check_rounded, size: 18, color: AppColors.onNavy)
                    : Text('$number', style: sans(12, weight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: sans(13, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      answer != null ? 'あなた: $answer' : card.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: sans(
                        11,
                        weight: FontWeight.w700,
                        color: answer != null ? AppColors.accent : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                open ? Icons.chevron_right_rounded : Icons.lock_rounded,
                size: open ? 22 : 16,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 最後のカードの下に出す、これまでのリールのプレビュー（横にスクロール）。押すとそのリールへ
class _PreviewStrip extends StatelessWidget {
  const _PreviewStrip({required this.topic, required this.session, required this.onJump, required this.onIndex});

  final Topic topic;
  final SessionState session;
  final ValueChanged<int> onJump;

  /// 目次（一覧）を開く
  final VoidCallback onIndex;

  @override
  Widget build(BuildContext context) {
    // 最後のカード（今いるところ）以外
    final count = topic.cards.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 14, 8),
          child: Row(
            children: [
              const Icon(Icons.history_rounded, size: 16, color: AppColors.ink, shadows: _shadow),
              const SizedBox(width: 6),
              Text(
                'これまでのリール',
                style: sans(13, weight: FontWeight.w800).copyWith(shadows: _shadow),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onIndex,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Text(
                    '目次 ›',
                    style: sans(12, weight: FontWeight.w800, color: AppColors.accent).copyWith(shadows: _shadow),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: count,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _PreviewCard(
              topic: topic,
              number: i + 1,
              card: topic.cards[i],
              answer: _answerOf(topic.cards[i], session.choices[i], session.answers[i]),
              onTap: () {
                HapticFeedback.selectionClick();
                onJump(i);
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// プレビュー1枚: 背景の版画・小さな雲に問い・自分の答え・「見る」ボタン
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.topic,
    required this.number,
    required this.card,
    required this.answer,
    required this.onTap,
  });

  final Topic topic;
  final int number;
  final ThinkCard card;
  final String? answer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = card.question ?? '「${card.quote}」';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 116,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.ink.withValues(alpha: 0.7), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x99000000), offset: Offset(3, 3))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            BakedImage(
              topic.image,
              filter: _ReelPage._engrave,
              alignment: Alignment(math.sin((number - 1) * 1.7) * 0.6, 0),
            ),
            const ColoredBox(color: Color(0x88000000)),
            Padding(
              padding: const EdgeInsets.all(7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 番号と、答えたかどうか
                  Row(
                    children: [
                      Text(
                        '$number',
                        style: sans(12, weight: FontWeight.w800).copyWith(shadows: _shadow),
                      ),
                      const Spacer(),
                      if (answer != null) const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.xpGreen),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 小さな雲に問い
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
                    decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: sans(10, weight: FontWeight.w800, color: const Color(0xFF16181A), height: 1.35),
                    ),
                  ),
                  const Spacer(),
                  if (answer != null)
                    Text(
                      answer!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: sans(10, weight: FontWeight.w800, color: AppColors.accent).copyWith(shadows: _shadow),
                    ),
                  const SizedBox(height: 4),
                  // 見るボタン
                  Container(
                    width: double.infinity,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.navy,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: AppColors.ink.withValues(alpha: 0.8)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '見る',
                          style: sans(10, weight: FontWeight.w800, color: AppColors.onNavy),
                        ),
                        const Icon(Icons.play_arrow_rounded, size: 13, color: AppColors.onNavy),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 右上の目次ボタンから出てくるパネル
class _IndexSheet extends StatelessWidget {
  const _IndexSheet({required this.topic, required this.session, required this.current, required this.onJump});

  final Topic topic;
  final SessionState session;
  final int current;
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
          decoration: const BoxDecoration(
            color: AppColors.paperBottom,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                  child: Row(
                    children: [
                      const Icon(Icons.grid_view_rounded, size: 18, color: AppColors.accent),
                      const SizedBox(width: 8),
                      Text('目次', style: sans(15, weight: FontWeight.w800)),
                      const SizedBox(width: 8),
                      Text(
                        topic.title,
                        style: sans(12, weight: FontWeight.w700, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: _ReelIndex(topic: topic, session: session, current: current, onJump: onJump),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 最後のページ: ふりかえり。これまでのリールと自分の答えが並び、押すとそのリールへ戻れる
class _EndPage extends StatelessWidget {
  const _EndPage({required this.topic, required this.session, required this.onJump, required this.onFinish});

  final Topic topic;
  final SessionState session;
  final ValueChanged<int> onJump;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 64, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _GuideAvatar(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ふりかえり', style: sans(20, weight: FontWeight.w800)),
                        Text(
                          '押すと、そのリールに戻れます',
                          style: sans(12, weight: FontWeight.w700, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_ReelIndex(topic: topic, session: session, current: -1, onJump: onJump)],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: PushButton.colored(
                  colors: Palette.main.primary,
                  width: 240,
                  height: 52,
                  depth: 5,
                  radius: 18,
                  onPressed: onFinish,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.home_rounded, color: AppColors.onNavy),
                      const SizedBox(width: 6),
                      Text(
                        '考えきった！ ホームへ',
                        style: sans(15, weight: FontWeight.w800, color: AppColors.onNavy),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// AIの判定のポップアップ（最後のカードで Enter・ボタンを押した時）
class _GradeSheet extends StatelessWidget {
  const _GradeSheet({required this.topicId, required this.transcript, required this.onRecap});

  /// 「ふりかえりへ」（これまでのリールのまとめへ進む）
  final VoidCallback onRecap;

  final String topicId;
  final String Function() transcript;

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 430, maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: const BoxDecoration(
            color: AppColors.paperBottom,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.ink.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DepthPanel(topicId: topicId, transcript: transcript),
                  const SizedBox(height: 16),
                  // このまま（書き直す・見直す）か、ふりかえりへ進むか
                  Row(
                    children: [
                      Expanded(
                        child: PushButton.colored(
                          colors: Palette.main.card,
                          height: 48,
                          depth: 4,
                          radius: 14,
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'このまま',
                            style: sans(14, weight: FontWeight.w800, color: Palette.main.card.content),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: PushButton.colored(
                          colors: Palette.main.primary,
                          height: 48,
                          depth: 4,
                          radius: 14,
                          onPressed: onRecap,
                          child: Text(
                            'ふりかえりへ ›',
                            style: sans(14, weight: FontWeight.w800, color: AppColors.onNavy),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '「このまま」で、書き直したり、もう一度測ったりできます',
                    style: sans(11, weight: FontWeight.w700, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 雲をくるっと裏返す（表: 問い、裏: 反論）。Y軸に回して、半分まわったところで裏と表が入れかわる
class _FlipCloud extends StatefulWidget {
  const _FlipCloud({required this.flipped, required this.front, required this.back});

  final bool flipped;
  final Widget front;

  /// 裏（反論）。表の時は null
  final Widget? back;

  @override
  State<_FlipCloud> createState() => _FlipCloudState();
}

class _FlipCloudState extends State<_FlipCloud> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
    value: widget.flipped ? 1 : 0,
  );

  /// 表にもどる途中でも裏を描けるように、最後の裏を覚えておく
  Widget? _back;

  @override
  void didUpdateWidget(_FlipCloud old) {
    super.didUpdateWidget(old);
    if (widget.back != null) _back = widget.back;
    if (widget.flipped != old.flipped) {
      widget.flipped ? _c.forward() : _c.reverse();
    }
  }

  @override
  void initState() {
    super.initState();
    _back = widget.back;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(_c.value);
        final angle = t * math.pi;
        final showBack = angle > math.pi / 2 && _back != null;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            // 裏は、さらに半回転させて文字が鏡うつしにならないように
            ..rotateY(showBack ? angle - math.pi : angle),
          child: showBack ? _back : widget.front,
        );
      },
    );
  }
}

/// 反論の時の雲の色（黒に近い、不気味な色）
const _counterCloud = Color(0xFF17121A);

/// 雲の中の「反論」（問いと入れかわって出る）
class _CounterInCloud extends StatelessWidget {
  const _CounterInCloud({super.key, required this.text, required this.answer, required this.play});

  final String text;

  /// 自分が選んだ答え
  final String answer;
  final bool play;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(8, 2, 9, 3),
              decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(6)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.record_voice_over_rounded, size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '反論',
                    style: sans(12, weight: FontWeight.w800, color: Colors.white, spacing: 2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'あなたの答え：$answer',
                overflow: TextOverflow.ellipsis,
                style: sans(12, weight: FontWeight.w800, color: const Color(0xFFB9A9AE)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // 黒い雲の白い文字は詰まって見えるので、行の間を少しあける
        SlamText(text, fontSize: 22, play: play, lineHeight: 1.7),
      ],
    );
  }
}

/// 名言の下の「言った人」（右寄せの署名。顔写真があれば丸く添える）
class _QuoteAuthor extends StatelessWidget {
  const _QuoteAuthor({required this.author});

  /// 例: 「— カント」
  final String author;

  @override
  Widget build(BuildContext context) {
    final name = author.replaceFirst(RegExp(r'^[—\-–\s]+'), '');
    final portrait = philosopherComments.where((c) => name.contains(c.name)).firstOrNull?.portrait;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(width: 22, height: 2, color: const Color(0xFF16181A)),
        const SizedBox(width: 10),
        if (portrait != null) ...[
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF16181A), width: 2),
            ),
            child: ClipOval(child: Image.asset(portrait, width: 40, height: 40, fit: BoxFit.cover)),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            name,
            style: serif(22, weight: FontWeight.w800, color: const Color(0xFF16181A)).copyWith(height: 1.2),
          ),
        ),
      ],
    );
  }
}

/// 名言を「やさしく言うと？」（Gemini で言いかえ）。言いかえは雲の中に出す
class _EasyQuote extends StatefulWidget {
  const _EasyQuote({required this.quote, required this.author, required this.topic});

  final String quote;
  final String? author;
  final String topic;

  @override
  State<_EasyQuote> createState() => _EasyQuoteState();
}

class _EasyQuoteState extends State<_EasyQuote> {
  String? _easy;
  bool _open = false;
  bool _loading = false;
  bool _failed = false;

  Future<void> _toggle() async {
    if (_loading) return;
    HapticFeedback.selectionClick();
    if (_open) {
      setState(() => _open = false);
      return;
    }
    setState(() {
      _open = true;
      _failed = false;
    });
    if (_easy != null) return;
    setState(() => _loading = true);
    try {
      final out = await BattleHelper.simplifyQuote(widget.quote, author: widget.author, topic: widget.topic);
      if (mounted) setState(() => _easy = out);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF16181A);
    const navy = Color(0xFF1F3A68);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _toggle,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 5, 12, 6),
            decoration: BoxDecoration(
              color: navy.withValues(alpha: _open ? 0.14 : 0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: navy.withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_loading)
                  const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: navy))
                else
                  Icon(_open ? Icons.expand_less_rounded : Icons.translate_rounded, size: 15, color: navy),
                const SizedBox(width: 4),
                Text(
                  _loading ? '言いかえています…' : (_open ? 'とじる' : 'やさしく言うと？'),
                  style: sans(12, weight: FontWeight.w800, color: navy),
                ),
              ],
            ),
          ),
        ),
        if (_open && (_easy != null || _failed))
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
            decoration: BoxDecoration(
              color: navy.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: const Border(left: BorderSide(color: navy, width: 3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'やさしく言うと',
                  style: sans(10, weight: FontWeight.w800, color: navy),
                ),
                const SizedBox(height: 2),
                Text(
                  _failed ? 'うまく言いかえられなかった…。もう一度押してみてね。' : _easy!,
                  style: sans(14, weight: FontWeight.w600, color: ink, height: 1.65),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 中の入力欄が「見える位置まで動かして」と頼んでも、外側（リールのページ送り）までは動かさない。
/// （ページの中のスクロールは、これより内側なので、ふつうに動く）
class _NoReveal extends SingleChildRenderObjectWidget {
  const _NoReveal({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderNoReveal();
}

class _RenderNoReveal extends RenderProxyBox {
  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {}
}
