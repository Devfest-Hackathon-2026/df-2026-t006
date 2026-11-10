import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/think_card.dart';
import '../router.dart';
import '../screens/loading_screen.dart';
import '../state/answer_log.dart';
import '../state/providers.dart';
import '../state/records.dart';
import '../state/revisit.dart';
import '../theme.dart';
import 'push_button.dart';
import 'reel_tasks.dart';

/// 「もう一度考える」の画面まわり（しくみは state/revisit.dart）。
///   - [RevisitHost]: 少し前に答えた問いを「もう一度考えてみる？」と下から出す（落ち着いた画面にいる時だけ）
///   - もう一度答えるシート: 前の答えは隠したまま答えてもらい、答えた後に「さっき → いま」を見せる
///   - [RevisitHistory]: 記録の画面に出す、もう一度答えた問いの一覧

/// 出してよい画面（リール・ボス戦・プロローグなど、何かに集中している時は出さない）
const _calmPaths = {'/', '/topics', '/records', '/missions', '/mail', '/profile', '/news', '/hitachan'};

/// 問いの本文（問い、または名言）
String _questionOf(ThinkCard c) => c.question ?? '「${c.quote ?? c.label}」';

/// もう一度答える時の選択肢（番号 → 記録する値）。スライダーは5段階のことばで選ぶ
List<(String, int)> _optionsFor(ThinkCard c) => switch (taskFor(c)) {
  ReelTask.instinct => [for (var i = 0; i < instinctOptions.length; i++) (instinctOptions[i], i)],
  ReelTask.choice => [for (var i = 0; i < c.choices!.length; i++) (c.choices![i], i)],
  ReelTask.agree => [
    for (final v in const [10, 32, 50, 68, 90]) (agreeLabel(v), v),
  ],
  ReelTask.write => const [],
};

/// 考えが変わったか（スライダーは、ことばが変わったら）
bool revisitChanged(ThinkCard c, int before, int after) =>
    taskFor(c) == ReelTask.agree ? agreeLabel(before) != agreeLabel(after) : before != after;

/// 「12分前」「3時間前」「2日前」
String agoLabel(DateTime t, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(t);
  if (d.inDays >= 1) return '${d.inDays}日前';
  if (d.inHours >= 1) return '${d.inHours}時間前';
  return '${d.inMinutes.clamp(1, 59)}分前';
}

/// 問いを探す（テーマやカードが無くなっていたら null）
(Topic, ThinkCard)? _find(WidgetRef ref, String topicId, int card) {
  final t = ref.read(topicProvider(topicId));
  if (t == null || card < 0 || card >= t.cards.length) return null;
  final c = t.cards[card];
  if (taskFor(c) == ReelTask.write) return null;
  return (t, c);
}

class RevisitHost extends ConsumerStatefulWidget {
  const RevisitHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RevisitHost> createState() => _RevisitHostState();
}

class _RevisitHostState extends ConsumerState<RevisitHost> {
  Timer? _tick;
  Timer? _autoHide;

  /// 起動してから少し待つ（お知らせなどと重ならないように）
  DateTime? _bootedAt;

  /// 今出している問い
  RevisitItem? _item;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 10), (_) => _check());
    appRouter.routerDelegate.addListener(_onRoute);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _autoHide?.cancel();
    appRouter.routerDelegate.removeListener(_onRoute);
    super.dispose();
  }

  String get _path => appRouter.routerDelegate.currentConfiguration.uri.path;

  bool get _calm => _calmPaths.contains(_path);

  void _onRoute() {
    // リールなどに入ったら引っこめる（次はまた時間をおいてから）
    if (_visible && !_calm) _hide(later: true);
  }

  void _check() {
    if (!mounted || _visible) return;
    if (!LoadingScreen.booted) return;
    final now = DateTime.now();
    _bootedAt ??= now;
    if (now.difference(_bootedAt!) < const Duration(seconds: 20)) return;
    if (!_calm) return;
    // お知らせやシートが開いている時は、閉じてから
    if (PopupWatcher.instance.anyOpen) return;
    final notifier = ref.read(revisitProvider.notifier);
    var item = notifier.due(now: now);
    // テーマやカードが無くなった問いは捨てて、次を見る
    while (item != null && _find(ref, item.topicId, item.card) == null) {
      notifier.answer(item, item.choice, changed: false);
      item = notifier.due(now: now);
    }
    if (item == null) return;
    notifier.shown(now: now);
    HapticFeedback.lightImpact();
    setState(() {
      _item = item;
      _visible = true;
    });
    // 何もしなければ、しばらくして引っこめる（「あとで」と同じ）
    _autoHide?.cancel();
    _autoHide = Timer(const Duration(seconds: 25), () => _hide(later: true));
  }

  void _hide({bool later = false}) {
    _autoHide?.cancel();
    if (!mounted || !_visible) return;
    final item = _item;
    if (later && item != null) ref.read(revisitProvider.notifier).later(item);
    setState(() => _visible = false);
  }

  Future<void> _open() async {
    final item = _item;
    _hide();
    final ctx = appRouter.routerDelegate.navigatorKey.currentContext;
    if (item == null || ctx == null) return;
    await showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RevisitSheet(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    final found = item == null ? null : _find(ref, item.topicId, item.card);
    return Stack(
      children: [
        widget.child,
        if (item != null && found != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              child: IgnorePointer(
                ignoring: !_visible,
                child: AnimatedSlide(
                  offset: _visible ? Offset.zero : const Offset(0, 1.6),
                  duration: const Duration(milliseconds: 380),
                  curve: _visible ? Curves.easeOutBack : Curves.easeInCubic,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: _Prompt(
                          topic: found.$1,
                          card: found.$2,
                          ago: agoLabel(item.answeredAt),
                          onLater: () => _hide(later: true),
                          onOpen: _open,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 下から出る「もう一度考えてみる？」
class _Prompt extends StatelessWidget {
  const _Prompt({
    required this.topic,
    required this.card,
    required this.ago,
    required this.onLater,
    required this.onOpen,
  });

  final Topic topic;
  final ThinkCard card;
  final String ago;
  final VoidCallback onLater;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accent, width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0xAA000000), offset: Offset(4, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.history_rounded, size: 18, color: AppColors.accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$agoに答えた問い・${topic.title}',
                    overflow: TextOverflow.ellipsis,
                    style: sans(11, weight: FontWeight.w800, color: AppColors.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('もう一度、考えてみる？', style: sans(15, weight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              _questionOf(card),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: sans(12, color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: PushButton(
                    height: 38,
                    depth: 3,
                    radius: 10,
                    face: AppColors.surface,
                    edge: const Color(0xFF16181A),
                    border: AppColors.ink,
                    borderWidth: 1.5,
                    onPressed: onLater,
                    child: Text(
                      'あとで',
                      style: sans(13, weight: FontWeight.w800, color: AppColors.ink),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: PushButton(
                    height: 38,
                    depth: 3,
                    radius: 10,
                    onPressed: onOpen,
                    child: Text(
                      'もう一度答える ›',
                      style: sans(13, weight: FontWeight.w800, color: AppColors.onNavy),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// もう一度答えるシート。前の答えは、答えるまで見せない（前の答えにつられないように）
class RevisitSheet extends ConsumerStatefulWidget {
  const RevisitSheet({super.key, required this.item});

  final RevisitItem item;

  @override
  ConsumerState<RevisitSheet> createState() => _RevisitSheetState();
}

class _RevisitSheetState extends ConsumerState<RevisitSheet> {
  final _openedAt = DateTime.now();
  RevisitResult? _result;

  void _pick(ThinkCard card, int value) {
    if (_result != null) return;
    final item = widget.item;
    final changed = revisitChanged(card, item.choice, value);
    HapticFeedback.mediumImpact();
    final r = ref.read(revisitProvider.notifier).answer(item, value, changed: changed);
    ref.read(playerProvider.notifier).addXp(RevisitNotifier.xp);
    // 答えの記録にも残す（あとで「時間をおくと考えが変わるか」を見られるように）
    ref
        .read(answerLogProvider.notifier)
        .add(
          AnswerEvent(
            topicId: item.topicId,
            card: item.card,
            choice: value,
            changedMind: changed,
            thinkMs: DateTime.now().difference(_openedAt).inMilliseconds,
            revisit: true,
            prevChoice: item.choice,
          ),
        );
    setState(() => _result = r);
  }

  @override
  Widget build(BuildContext context) {
    final found = _find(ref, widget.item.topicId, widget.item.card);
    if (found == null) return const SizedBox.shrink();
    final (topic, card) = found;
    final r = _result;
    final options = _optionsFor(card);

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        decoration: const BoxDecoration(
          color: AppColors.paperTop,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: AppColors.accent, width: 2)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(Icons.history_rounded, size: 18, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'もう一度考える・${topic.title}',
                      style: sans(12, weight: FontWeight.w800, color: AppColors.accent, spacing: 1),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${agoLabel(widget.item.answeredAt)}にも答えた問いです。いまのあなたなら？', style: sans(12, color: AppColors.muted)),
              const SizedBox(height: 14),
              // 問い
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.ink.withValues(alpha: 0.5), width: 1.5),
                  boxShadow: const [BoxShadow(color: Color(0xAA000000), offset: Offset(4, 4))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_questionOf(card), style: serif(18, weight: FontWeight.w800).copyWith(height: 1.55)),
                    if (card.quoteAuthor != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        card.quoteAuthor!,
                        style: sans(12, weight: FontWeight.w700, color: AppColors.muted),
                      ),
                    ],
                    // 今日の問いの補足はテーマ名だけなので出さない
                    if (card.body != null && !card.isLead) ...[
                      const SizedBox(height: 8),
                      Text(card.body!, style: sans(13, color: AppColors.muted, height: 1.6)),
                    ],
                    if (taskFor(card) == ReelTask.agree) ...[
                      const SizedBox(height: 8),
                      Text(
                        'この言葉に、どのくらい賛成？',
                        style: sans(12, weight: FontWeight.w700, color: AppColors.accent),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // 選択肢（答えた後は、前の答えと今の答えに印）
              for (final (label, value) in options)
                _Option(
                  label: label,
                  mine: r != null && _same(card, value, r.after),
                  before: r != null && _same(card, value, r.before),
                  onTap: r == null ? () => _pick(card, value) : null,
                ),
              AnimatedSize(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: r == null
                    ? const SizedBox(width: double.infinity)
                    : _Verdict(
                        card: card,
                        result: r,
                        onClose: () => Navigator.of(context).pop(),
                        onTopic: () {
                          Navigator.of(context).pop();
                          appRouter.go('/topics/${topic.id}');
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// その選択肢が、答え [v] にあたるか（スライダーは同じことばなら）
  static bool _same(ThinkCard c, int option, int v) =>
      taskFor(c) == ReelTask.agree ? agreeLabel(option) == agreeLabel(v) : option == v;
}

class _Option extends StatelessWidget {
  const _Option({required this.label, required this.mine, required this.before, required this.onTap});

  final String label;

  /// 今の答え・前の答え
  final bool mine;
  final bool before;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PushButton(
        height: 46,
        depth: 4,
        radius: 12,
        face: mine ? AppColors.navy : AppColors.surface,
        edge: mine ? AppColors.navyDeep : const Color(0xFF16181A),
        border: mine ? AppColors.accent : AppColors.ink.withValues(alpha: onTap == null ? 0.2 : 0.5),
        borderWidth: 1.5,
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: sans(
                    14,
                    weight: FontWeight.w800,
                    color: mine || onTap != null ? AppColors.ink : AppColors.muted,
                  ),
                ),
              ),
              if (before) _Tag(text: 'さっき', color: AppColors.muted),
              if (before && mine) const SizedBox(width: 6),
              if (mine) _Tag(text: 'いま', color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(
        text,
        style: sans(10, weight: FontWeight.w800, color: color),
      ),
    );
  }
}

/// 答えた後: さっき → いま と、変わったかどうか
class _Verdict extends StatelessWidget {
  const _Verdict({required this.card, required this.result, required this.onClose, required this.onTopic});

  final ThinkCard card;
  final RevisitResult result;
  final VoidCallback onClose;
  final VoidCallback onTopic;

  @override
  Widget build(BuildContext context) {
    final changed = result.changed;
    final color = changed ? AppColors.xpGreen : AppColors.accent;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(changed ? Icons.autorenew_rounded : Icons.anchor_rounded, color: color, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        changed ? '考えが変わった！' : '考えは変わらなかった',
                        style: sans(16, weight: FontWeight.w800, color: color),
                      ),
                    ),
                    Text(
                      '+${RevisitNotifier.xp} EXP',
                      style: sans(13, weight: FontWeight.w800, color: AppColors.xpGreenLight),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _Compare(card: card, result: result),
                const SizedBox(height: 10),
                Text(
                  changed
                      ? '時間をおいて考え直せるのは、よく考えている証拠。何があなたの考えを動かしたのか、少し振り返ってみよう。'
                      : '時間がたっても同じ答え。その答えには、あなたなりの理由がありそう。その理由を言葉にできる？',
                  style: sans(12, color: AppColors.muted, height: 1.7),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PushButton(
                  height: 42,
                  depth: 3,
                  radius: 12,
                  face: AppColors.surface,
                  edge: const Color(0xFF16181A),
                  border: AppColors.ink.withValues(alpha: 0.4),
                  borderWidth: 1.5,
                  onPressed: onTopic,
                  child: Text('テーマを見る', style: sans(13, weight: FontWeight.w800)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PushButton(
                  height: 42,
                  depth: 3,
                  radius: 12,
                  onPressed: onClose,
                  child: Text(
                    'とじる',
                    style: sans(13, weight: FontWeight.w800, color: AppColors.onNavy),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 「さっき → いま」
class _Compare extends StatelessWidget {
  const _Compare({required this.card, required this.result});

  final ThinkCard card;
  final RevisitResult result;

  @override
  Widget build(BuildContext context) {
    Widget side(String head, String value, Color color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            head,
            style: sans(10, weight: FontWeight.w800, color: AppColors.muted),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: sans(14, weight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        side('${agoLabel(result.answeredAt, now: result.at)}のあなた', answerLabel(card, result.before), AppColors.muted),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.muted),
        ),
        side('いまのあなた', answerLabel(card, result.after), AppColors.ink),
      ],
    );
  }
}

/// 記録の画面: もう一度答えた問いの一覧（なければ何も出さない）
class RevisitHistory extends ConsumerWidget {
  const RevisitHistory({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(revisitProvider).results;
    final rows = [
      for (final r in results)
        if (_find(ref, r.topicId, r.card) case (final t, final c)) (r, t, c),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    final changed = results.where((r) => r.changed).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 22, 0, 4),
          child: Row(
            children: [
              const Icon(Icons.history_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: 6),
              Text(
                'もう一度考えた問い',
                style: sans(13, weight: FontWeight.w800, color: AppColors.accent, spacing: 1),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 0, 10),
          child: Text('${results.length}問のうち、$changed問で考えが変わった', style: sans(12, color: AppColors.muted)),
        ),
        for (final (r, t, c) in rows)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border(left: BorderSide(color: r.changed ? AppColors.xpGreen : AppColors.accent, width: 4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${t.title}・${formatDateTime(r.at)}',
                        overflow: TextOverflow.ellipsis,
                        style: sans(10, weight: FontWeight.w700, color: AppColors.muted),
                      ),
                    ),
                    Text(
                      r.changed ? '変わった' : '変わらなかった',
                      style: sans(
                        11,
                        weight: FontWeight.w800,
                        color: r.changed ? AppColors.xpGreenLight : AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _questionOf(c),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: sans(13, weight: FontWeight.w800, height: 1.5),
                ),
                const SizedBox(height: 4),
                Text(
                  '${answerLabel(c, r.before)}  →  ${answerLabel(c, r.after)}',
                  style: sans(12, weight: FontWeight.w700, color: AppColors.muted),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
