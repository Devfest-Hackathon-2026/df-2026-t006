import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/philosopher_comments.dart';
import '../services/philosopher_reply.dart';
import '../models/think_card.dart';
import '../theme.dart';

/// リールのコメント欄（下から出てくる）。上から順に:
///   1. みんなの投票（投票すると結果のバーが伸び、経験値）
///   2. ミニゲーム「誰の言葉？」（正解すると経験値）
///   3. 哲学者たちのコメント（返信できる）と、自分のコメント
class ReelCommentsSheet extends StatefulWidget {
  const ReelCommentsSheet({
    super.key,
    required this.topicTitle,
    required this.card,
    required this.index,
    required this.comments,
    required this.mine,
    required this.myVote,
    required this.onPost,
    this.reactions = const {},
    required this.onVote,
    required this.onQuizCorrect,
    required this.replies,
    required this.onReply,
  });

  final String topicTitle;
  final ThinkCard card;
  final int index;
  final List<PhilosopherComment> comments;
  final List<String> mine;

  /// 前に投票した選択肢（まだなら null）
  final int? myVote;

  /// 自分のコメントを書いた時。[philosopher] の哲学者が反応する（返事 or いいね）
  final Future<PhilosopherReaction> Function(String text, int philosopher) onPost;

  /// これまでの、自分のコメントへの反応（自分のコメントの番号 → 反応）
  final Map<int, PhilosopherReaction> reactions;
  final ValueChanged<int> onVote;

  /// ミニゲームで正解した時（経験値をあげる）
  final VoidCallback onQuizCorrect;

  /// 哲学者のコメントへの返信のスレッド（コメント番号 → 自分と哲学者の返信）
  final Map<int, List<CommentReply>> replies;

  /// 返信した時。哲学者の返事（AI）が返ってくる。返事がなければ null
  final Future<String?> Function(int comment, String text) onReply;

  @override
  State<ReelCommentsSheet> createState() => _ReelCommentsSheetState();
}

class _ReelCommentsSheetState extends State<ReelCommentsSheet> {
  final _input = TextEditingController();
  late final List<String> _mine = [...widget.mine];
  late int? _vote = widget.myVote;
  final _liked = <int>{};
  late final Map<int, List<CommentReply>> _replies = {
    for (final e in widget.replies.entries) e.key: [...e.value],
  };
  final _focus = FocusNode();

  /// 返信先のコメント番号（null なら普通のコメント）
  int? _replyTo;

  /// 哲学者が返事を書いているコメント
  final _typing = <int>{};

  /// 自分のコメントへの反応
  late final Map<int, PhilosopherReaction> _reactions = {...widget.reactions};

  /// 哲学者が反応を書いている、自分のコメント（自分のコメントの番号 → 哲学者の番号）
  final _reacting = <int, int>{};

  @override
  void dispose() {
    _focus.dispose();
    _input.dispose();
    super.dispose();
  }

  void _post() {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    final to = _replyTo;
    if (to != null) {
      final thread = _replies[to] ??= [];
      final willAnswer = _left > 0;
      setState(() {
        thread.add(CommentReply(t));
        // 返信先はそのまま（続けて話せる）
        if (willAnswer) _typing.add(to);
      });
      widget.onReply(to, t).then((answer) {
        if (!mounted) return;
        setState(() {
          _typing.remove(to);
          if (answer != null) thread.add(CommentReply(answer, mine: false));
        });
      });
    } else {
      // そのリールの哲学者のうち1人が反応する（返事できる回数が残っていれば返事、なければいいね）
      final k = _mine.length;
      final p = (t.length + k) % widget.comments.length;
      setState(() {
        _mine.add(t);
        if (_left > 0) _reacting[k] = p;
      });
      widget.onPost(t, p).then((r) {
        if (!mounted) return;
        setState(() {
          _reacting.remove(k);
          _reactions[k] = r;
        });
      });
    }
    _input.clear();
    // 続けて書けるように、入力欄にカーソルを残す
    _focus.requestFocus();
  }

  /// このリールで、哲学者があと何回返事できるか（返事を書いている途中の分も引く）
  int get _left =>
      (PhilosopherReplier.leftIn(_replies.values) -
              _reactions.values.where((r) => r.text != null).length -
              _typing.length -
              _reacting.length)
          .clamp(0, PhilosopherReplier.maxPerReel);

  void _startReply(int i) {
    setState(() => _replyTo = i);
    _focus.requestFocus();
  }

  /// 自分のコメント1件（哲学者の返事 or いいね つき）
  Widget _mineTile(int k) {
    final r = _reactions[k];
    final pi = _reacting[k] ?? r?.philosopher;
    final who = pi == null ? null : widget.comments[pi];
    return _CommentTile(
      name: 'あなた',
      ago: 'たった今',
      text: _mine[k],
      likes: r != null && r.text == null ? 1 : 0,
      liked: false,
      onLike: () {},
      replies: [if (r?.text case final text?) CommentReply(text, mine: false)],
      replyName: who?.name,
      replyPortrait: who?.portrait,
      typing: _reacting.containsKey(k),
      likedBy: r != null && r.text == null ? who?.name : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.comments.length + _mine.length;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Container(
            height: MediaQuery.sizeOf(context).height * 0.78,
            decoration: const BoxDecoration(
              color: Color(0xFF1C1E1F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.muted, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 10),
                // 題と、右上の「？」（遊び方）
                SizedBox(
                  width: double.infinity,
                  height: 28,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text('コメント $total件', style: sans(13, weight: FontWeight.w800)),
                      Positioned(
                        right: 10,
                        child: GestureDetector(
                          onTap: () => showDialog<void>(context: context, builder: (_) => const _CommentsHelp()),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.muted),
                            ),
                            child: const Icon(Icons.question_mark_rounded, size: 15, color: AppColors.muted),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Divider(color: AppColors.ink.withValues(alpha: 0.1), height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    children: [
                      _Poll(
                        card: widget.card,
                        index: widget.index,
                        vote: _vote,
                        onVote: (v) {
                          setState(() => _vote = v);
                          widget.onVote(v);
                        },
                      ),
                      const SizedBox(height: 14),
                      _WhoSaidIt(seed: widget.index, onCorrect: widget.onQuizCorrect),
                      const SizedBox(height: 18),
                      for (var i = 0; i < widget.comments.length; i++)
                        _CommentTile(
                          name: widget.comments[i].name,
                          portrait: widget.comments[i].portrait,
                          ago: widget.comments[i].ago,
                          text: widget.comments[i].text,
                          likes: widget.comments[i].likes + (_liked.contains(i) ? 1 : 0),
                          liked: _liked.contains(i),
                          onLike: () => setState(() => _liked.contains(i) ? _liked.remove(i) : _liked.add(i)),
                          replies: _replies[i] ?? const [],
                          typing: _typing.contains(i),
                          onReply: () => _startReply(i),
                        ),
                      for (var k = 0; k < _mine.length; k++) _mineTile(k),
                    ],
                  ),
                ),
                Divider(color: AppColors.ink.withValues(alpha: 0.1), height: 1),
                // 返信中の表示
                if (_replyTo != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Row(
                      children: [
                        Text(
                          '${widget.comments[_replyTo!].name}さんに返信中',
                          style: sans(12, weight: FontWeight.w700, color: AppColors.accent),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _left > 0 ? '哲学者の返事 あと$_left回' : '哲学者の返事はここまで',
                          style: sans(11, weight: FontWeight.w700, color: AppColors.muted),
                        ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _replyTo = null),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(Icons.close_rounded, size: 16, color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            focusNode: _focus,
                            style: sans(14),
                            cursorColor: AppColors.ink,
                            onSubmitted: (_) => _post(),
                            decoration: InputDecoration(
                              hintText: _replyTo == null ? 'あなたの考えをコメント…' : '${widget.comments[_replyTo!].name}さんに返信…',
                              hintStyle: sans(14, color: AppColors.muted),
                              filled: true,
                              fillColor: AppColors.surface,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: _post,
                          icon: const Icon(Icons.send_rounded, color: AppColors.accent),
                        ),
                      ],
                    ),
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

/// 中身のある箱（投票・ミニゲーム）
class _Panel extends StatelessWidget {
  const _Panel({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                title,
                style: sans(12, weight: FontWeight.w800, color: AppColors.accent, spacing: 1),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// 2. みんなの投票
class _Poll extends StatelessWidget {
  const _Poll({required this.card, required this.index, required this.vote, required this.onVote});

  final ThinkCard card;
  final int index;
  final int? vote;
  final ValueChanged<int> onVote;

  List<String> get _options =>
      card.choices ??
      card.pollOptions ??
      (card.quote != null ? const ['共感する', '共感しない', '考え中'] : const ['そう思う', '思わない', 'わからない']);

  String get _question => card.pollQuestion != null
      ? card.pollQuestion!
      : card.choices != null
      ? (card.question ?? 'どれを選ぶ？')
      : card.quote != null
      ? 'この言葉に、共感する？'
      : (card.question ?? 'この問いに、あなたは？');

  /// 他の人の票（仮。毎回同じになるよう番号から決める）
  List<int> get _base {
    final r = math.Random(index * 31 + 7);
    return [for (final _ in _options) 40 + r.nextInt(160)];
  }

  /// 選択肢のない問い（今日の問いなど）は「そう思う」で答えても意味がないので、面白さを1〜10で聞く
  bool get _isRating => card.choices == null && card.pollOptions == null && card.quote == null;

  @override
  Widget build(BuildContext context) {
    if (_isRating) return _RatingPoll(index: index, vote: vote, onVote: onVote);
    final base = _base;
    final counts = [for (var i = 0; i < base.length; i++) base[i] + (vote == i ? 1 : 0)];
    final total = counts.fold<int>(0, (a, b) => a + b);
    final voted = vote != null;

    return _Panel(
      icon: Icons.bar_chart_rounded,
      title: 'みんなの投票',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_question, style: sans(14, weight: FontWeight.w700, height: 1.5)),
          const SizedBox(height: 10),
          for (var i = 0; i < _options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: voted
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        onVote(i);
                      },
                child: _PollBar(
                  label: _options[i],
                  ratio: voted ? counts[i] / total : 0,
                  showResult: voted,
                  mine: vote == i,
                ),
              ),
            ),
          Text(
            voted ? '${compactCount(total)}票 ・ 投票しました（+5 EXP）' : 'タップして投票（+5 EXP）',
            style: sans(11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

/// 「このテーマ、どのくらい面白い？」1〜10。押すと、みんなの平均が出る
class _RatingPoll extends StatelessWidget {
  const _RatingPoll({required this.index, required this.vote, required this.onVote});

  final int index;

  /// 選んだ点数 - 1（0〜9）
  final int? vote;
  final ValueChanged<int> onVote;

  /// 他の人の票（仮。毎回同じになるよう番号から決める。面白い寄り）
  List<int> get _base {
    final r = math.Random(index * 53 + 11);
    return [for (var i = 0; i < 10; i++) (i < 4 ? 4 : 12 + i * 6) + r.nextInt(20)];
  }

  @override
  Widget build(BuildContext context) {
    final base = _base;
    final counts = [for (var i = 0; i < 10; i++) base[i] + (vote == i ? 1 : 0)];
    final total = counts.fold<int>(0, (a, b) => a + b);
    var sum = 0;
    for (var i = 0; i < 10; i++) {
      sum += counts[i] * (i + 1);
    }
    final voted = vote != null;
    final most = counts.reduce(math.max);

    return _Panel(
      icon: Icons.star_rounded,
      title: 'みんなの評価',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('このテーマ、どのくらい面白い？', style: sans(14, weight: FontWeight.w700, height: 1.5)),
          const SizedBox(height: 10),
          // 1〜10 のボタン。投票すると、ボタンの後ろに票の多さが棒グラフで出る
          SizedBox(
            height: 64,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 10; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: GestureDetector(
                        onTap: voted
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                onVote(i);
                              },
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: voted ? counts[i] / most : 0),
                              duration: const Duration(milliseconds: 600),
                              curve: Curves.easeOutCubic,
                              builder: (context, r, _) => Container(
                                height: 26 * r,
                                decoration: BoxDecoration(
                                  color: (vote == i ? AppColors.accent : AppColors.ink).withValues(
                                    alpha: vote == i ? 0.6 : 0.18,
                                  ),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: vote == i ? AppColors.accent : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: vote == i ? AppColors.accent : AppColors.ink.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Text(
                                '${i + 1}',
                                style: sans(
                                  13,
                                  weight: FontWeight.w800,
                                  color: vote == i ? AppColors.surface : AppColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('つまらない', style: sans(10, color: AppColors.muted)),
              const Spacer(),
              Text('とても面白い', style: sans(10, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            voted ? 'みんなの平均 ${(sum / total).toStringAsFixed(1)} ・ ${compactCount(total)}票（+5 EXP）' : 'タップして評価（+5 EXP）',
            style: sans(11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _PollBar extends StatelessWidget {
  const _PollBar({required this.label, required this.ratio, required this.showResult, required this.mine});

  final String label;
  final double ratio;
  final bool showResult;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: mine ? AppColors.accent : AppColors.ink.withValues(alpha: 0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 結果のバー（投票すると伸びる）
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: ratio),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, r, _) => FractionallySizedBox(
              widthFactor: r,
              heightFactor: 1,
              child: ColoredBox(color: (mine ? AppColors.accent : AppColors.ink).withValues(alpha: mine ? 0.35 : 0.14)),
            ),
          ),
          // 文字は箱の上下中央に
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  if (mine) const Icon(Icons.check_rounded, size: 16, color: AppColors.ink),
                  if (mine) const SizedBox(width: 4),
                  Expanded(
                    child: Text(label, style: sans(13, weight: FontWeight.w700)),
                  ),
                  if (showResult) Text('${(ratio * 100).round()}%', style: sans(13, weight: FontWeight.w800)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 3. ミニゲーム「誰の言葉？」
class _WhoSaidIt extends StatefulWidget {
  const _WhoSaidIt({required this.seed, required this.onCorrect});

  final int seed;
  final VoidCallback onCorrect;

  @override
  State<_WhoSaidIt> createState() => _WhoSaidItState();
}

class _WhoSaidItState extends State<_WhoSaidIt> {
  late int _round = widget.seed;
  int? _picked;

  /// この問題の正解と、選択肢3人（正解 + 2人）
  (PhilosopherComment, List<PhilosopherComment>) get _quiz {
    final pool = philosopherComments;
    final r = math.Random(_round * 97 + 13);
    final answer = pool[r.nextInt(pool.length)];
    final others = [...pool]
      ..remove(answer)
      ..shuffle(r);
    final options = [answer, others[0], others[1]]..shuffle(r);
    return (answer, options);
  }

  @override
  Widget build(BuildContext context) {
    final (answer, options) = _quiz;
    final answered = _picked != null;
    final correct = answered && options[_picked!] == answer;

    return _Panel(
      icon: Icons.sports_esports_rounded,
      title: 'ミニゲーム：誰の言葉？',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('「${answer.text}」', style: serif(15, weight: FontWeight.w700).copyWith(height: 1.6)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < options.length; i++)
                Expanded(
                  child: GestureDetector(
                    onTap: answered
                        ? null
                        : () {
                            final ok = options[i] == answer;
                            ok ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact();
                            setState(() => _picked = i);
                            if (ok) widget.onCorrect();
                          },
                    child: _QuizOption(
                      person: options[i],
                      state: !answered
                          ? _OptionState.idle
                          : options[i] == answer
                          ? _OptionState.right
                          : i == _picked
                          ? _OptionState.wrong
                          : _OptionState.dim,
                    ),
                  ),
                ),
            ],
          ),
          if (answered) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    correct ? '正解！ +10 EXP' : '残念… 正解は${answer.name}',
                    style: sans(13, weight: FontWeight.w800, color: correct ? AppColors.xpGreenLight : AppColors.red),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _round += 1;
                    _picked = null;
                  }),
                  child: Text(
                    '次の問題 ›',
                    style: sans(13, weight: FontWeight.w800, color: AppColors.accent),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

enum _OptionState { idle, right, wrong, dim }

class _QuizOption extends StatelessWidget {
  const _QuizOption({required this.person, required this.state});

  final PhilosopherComment person;
  final _OptionState state;

  @override
  Widget build(BuildContext context) {
    final ring = switch (state) {
      _OptionState.right => AppColors.xpGreen,
      _OptionState.wrong => AppColors.red,
      _ => AppColors.ink.withValues(alpha: 0.35),
    };
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: state == _OptionState.dim ? 0.4 : 1,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: state == _OptionState.idle ? 1.5 : 3),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(person.portrait, fit: BoxFit.cover),
              ),
              if (state == _OptionState.right || state == _OptionState.wrong)
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Icon(
                    state == _OptionState.right ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: ring,
                    size: 22,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            person.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: sans(11, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// 4. コメント1件
class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.name,
    required this.ago,
    required this.text,
    required this.likes,
    required this.liked,
    required this.onLike,
    this.portrait,
    this.replies = const [],
    this.onReply,
    this.typing = false,
    this.replyName,
    this.replyPortrait,
    this.likedBy,
  });

  /// 返事をする哲学者（自分のコメントの時。なければこのコメントの人）
  final String? replyName;
  final String? replyPortrait;

  /// 「いいね」をくれた哲学者の名前
  final String? likedBy;

  /// このコメントへの返信（自分と、哲学者の返事）
  final List<CommentReply> replies;

  /// 哲学者が返事を書いているところ
  final bool typing;

  /// 「返信」を押した時（自分のコメントには出さない）
  final VoidCallback? onReply;

  final String name;

  /// 顔写真（なければ人のアイコン）
  final String? portrait;
  final String ago;
  final String text;
  final int likes;
  final bool liked;
  final VoidCallback onLike;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink.withValues(alpha: 0.35)),
            ),
            clipBehavior: Clip.antiAlias,
            child: portrait != null
                ? Image.asset(portrait!, fit: BoxFit.cover, filterQuality: FilterQuality.medium)
                : const Icon(Icons.person_rounded, color: AppColors.muted, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: sans(12, weight: FontWeight.w800, color: AppColors.bodyText),
                    ),
                    const SizedBox(width: 6),
                    Text(ago, style: sans(11, color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(text, style: sans(14, height: 1.55)),
                if (onReply != null)
                  GestureDetector(
                    onTap: onReply,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 2),
                      child: Text(
                        '返信',
                        style: sans(12, weight: FontWeight.w700, color: AppColors.muted),
                      ),
                    ),
                  ),
                // 返信のスレッド（字下げして表示）
                if (likedBy != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.favorite_rounded, size: 13, color: AppColors.red),
                        const SizedBox(width: 4),
                        Text(
                          '$likedByがいいねしました',
                          style: sans(11, weight: FontWeight.w800, color: AppColors.red),
                        ),
                      ],
                    ),
                  ),
                for (final r in replies)
                  _ReplyRow(
                    name: r.mine ? 'あなた' : replyName ?? name,
                    portrait: r.mine ? null : replyPortrait ?? portrait,
                    text: r.text,
                    // 哲学者の返事にも、続けて返信できる
                    onReply: r.mine ? null : onReply,
                  ),
                if (typing)
                  _ReplyRow(name: replyName ?? name, portrait: replyPortrait ?? portrait, text: '入力中…', muted: true),
              ],
            ),
          ),
          GestureDetector(
            onTap: onLike,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                children: [
                  Icon(
                    liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    size: 18,
                    color: liked ? AppColors.red : AppColors.muted,
                  ),
                  Text(compactCount(likes), style: sans(10, color: AppColors.muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 返信1件（自分なら人のアイコン、哲学者なら顔写真）
class _ReplyRow extends StatelessWidget {
  const _ReplyRow({required this.name, required this.portrait, required this.text, this.muted = false, this.onReply});

  /// 「返信」を押した時（哲学者の返事だけ）
  final VoidCallback? onReply;

  final String name;
  final String? portrait;
  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink.withValues(alpha: 0.35)),
            ),
            clipBehavior: Clip.antiAlias,
            child: portrait != null
                ? Image.asset(portrait!, fit: BoxFit.cover, filterQuality: FilterQuality.medium)
                : const Icon(Icons.person_rounded, color: AppColors.muted, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$name　たった今',
                  style: sans(11, weight: FontWeight.w700, color: AppColors.muted),
                ),
                Text(text, style: sans(13, height: 1.5, color: muted ? AppColors.muted : AppColors.ink)),
                if (onReply != null)
                  GestureDetector(
                    onTap: onReply,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 3, bottom: 2),
                      child: Text(
                        '返信',
                        style: sans(11, weight: FontWeight.w700, color: AppColors.muted),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// コメント欄の遊び方（右上の「？」）
class _CommentsHelp extends StatelessWidget {
  const _CommentsHelp();

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: sans(13, weight: FontWeight.w800)),
                Text(body, style: sans(12, color: AppColors.bodyText, height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
          decoration: BoxDecoration(
            color: AppColors.paperBottom,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.ink.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('コメント欄の遊び方', style: sans(17, weight: FontWeight.w800)),
              const SizedBox(height: 14),
              item(
                Icons.forum_rounded,
                '哲学者と話す',
                '哲学者のコメントの「返信」を押すと、その哲学者がAIで返事をしてくれます。返事にもまた返信して、続けて話せます。'
                    '自分でコメントを書くと、哲学者が1人、返事か「いいね」をくれます。'
                    '哲学者の返事は、1つのリールにつき${PhilosopherReplier.maxPerReel}回まで（それ以上は「いいね」）。',
              ),
              item(Icons.how_to_vote_rounded, 'みんなの投票', '投票すると +5 EXP（1つのリールで1回）。'),
              item(Icons.psychology_alt_rounded, '誰の言葉？', 'ミニゲームに正解すると +10 EXP。'),
              item(Icons.edit_rounded, '自分のコメント', '思ったことを、そのままコメントに残せます。'),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'とじる',
                    style: sans(13, weight: FontWeight.w800, color: AppColors.accent),
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
