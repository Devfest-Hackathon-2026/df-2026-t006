import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/bosses.dart';
import '../models/think_card.dart';
import '../services/battle_helper.dart';
import '../services/boss_battle.dart';
import '../services/cloud.dart';
import '../state/brains.dart';
import '../state/missions.dart';
import '../state/records.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/hitachan.dart';
import '../widgets/phone_frame.dart';
import '../widgets/push_button.dart';
import '../widgets/reel_tasks.dart';

/// ボス戦: 哲学者ボスの主張に、理由を言葉にして反論し「確信」（HP）を削る。
/// Gemini が審判（ダメージの判定）とボス役（言い返し）をする。
class BattleScreen extends ConsumerStatefulWidget {
  const BattleScreen({super.key, required this.topicId, this.difficulty = Difficulty.normal, this.bossIndex = 0});

  final String topicId;

  /// そのテーマのどちらのボスと戦うか（0 / 1。プレイヤーは反対の立場から反論する）
  final int bossIndex;

  /// ボスの強さ（★1〜3）
  final Difficulty difficulty;

  /// 負けた時にもらえる経験値（勝った時は難しさで変わる）
  static const loseXp = 30;

  @override
  ConsumerState<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends ConsumerState<BattleScreen> with TickerProviderStateMixin {
  late final Boss _boss = bossFor(widget.topicId, widget.bossIndex)!;

  /// プレイヤーの立場（ボスと反対側）
  late final String _yourStance = rivalOf(_boss)?.stance ?? '';

  /// 入力欄（スマホでキーボードが出たら、ボスの言葉が見えるように画面を詰める）
  late final FocusNode _focus = FocusNode()..addListener(() => setState(() {}));
  late final Topic _topic = ref.read(topicProvider(widget.topicId))!;

  late BattleState _s = BattleState(difficulty: widget.difficulty);

  /// このボス戦でもらったちびのう
  int _brains = 0;
  bool _thinking = false;

  /// 判定を待っている間に表示する、送った反論
  String? _pending;
  String? _error;
  String _draft = '';

  /// 入力欄を空にするため、攻撃ごとに作り直す
  int _inputKey = 0;

  /// ボスが揺れる / プレイヤーが赤く光る / ダメージの数字が浮かぶ
  late final AnimationController _bossShake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final AnimationController _playerHit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  /// 画面を横切るダメージの帯
  late final AnimationController _popup = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  final _log = ScrollController();

  /// 「やさしく言うと」: ボスの言葉 → やさしい言いかえ（開いているものだけ表示）
  final _easy = <String, String>{};
  final _easyOpen = <String>{};
  final _easyLoading = <String>{};

  Future<void> _toggleEasy(String text) async {
    if (_easyLoading.contains(text)) return;
    if (_easyOpen.contains(text)) {
      setState(() => _easyOpen.remove(text));
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _easyOpen.add(text));
    if (_easy.containsKey(text)) return;
    setState(() => _easyLoading.add(text));
    String out;
    try {
      out = await BattleHelper.simplify(_boss, text);
    } catch (_) {
      out = 'うまく言いかえられなかった…。もう一度押してみてね。';
    }
    if (!mounted) return;
    setState(() {
      _easyLoading.remove(text);
      // 失敗した時は覚えない（もう一度押せば、また聞く）
      if (out.startsWith('うまく言いかえられなかった')) {
        _easyOpen.remove(text);
        _error = out;
      } else {
        _easy[text] = out;
      }
    });
  }

  /// ヒント: 1分間 攻撃しないで考えこんでいたら「ヒントを見る」を出す
  static const _hintAfter = Duration(minutes: 1);
  Timer? _idle;
  bool _hintReady = false;
  bool _hintLoading = false;
  String? _hint;
  int _hints = 0;

  /// このボス戦で出したヒント（同じヒントをくり返さないように Gemini に渡す）
  final _hintHistory = <String>[];

  /// ターンが変わるたびに、考えている時間を数え直す
  void _restartIdle() {
    _idle?.cancel();
    _hintReady = false;
    _hint = null;
    // むずかしいはヒントなし。ふつうは1回のボス戦で数回まで
    if (_hintsLeft == 0) return;
    _idle = Timer(_hintAfter, () {
      if (mounted && _s.outcome == BattleOutcome.ongoing && !_thinking) setState(() => _hintReady = true);
    });
  }

  /// 残りのヒントの数（-1 = 何回でも）
  int get _hintsLeft {
    final max = widget.difficulty.hints;
    return max < 0 ? -1 : (max - _hints).clamp(0, max);
  }

  Future<void> _showHint() async {
    if (_hintLoading || _hintsLeft == 0) return;
    HapticFeedback.selectionClick();
    setState(() => _hintLoading = true);
    String h;
    try {
      h = await BattleHelper.hint(_boss, _s, draft: _draft.trim(), previous: _hintHistory);
    } catch (_) {
      h = BattleHelper.offlineHint(_boss, _hints);
    }
    _hints++;
    _hintHistory.add(h);
    if (!mounted) return;
    setState(() {
      _hintLoading = false;
      _hint = h;
    });
  }

  @override
  void initState() {
    super.initState();
    _restartIdle();
    // はじめてのボス戦（記録がまだない）なら、あそびかたを先に見せる
    if (ref.read(battleRecordsProvider).isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openHelp();
      });
    }
  }

  /// 右上の「？」: ボス戦のあそびかた
  void _openHelp() {
    _focus.unfocus();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HelpSheet(boss: _boss, yours: _yourStance, difficulty: widget.difficulty),
    );
  }

  /// 最小の文字数（「a」だけで攻撃するのを防ぐ）
  static const _minLength = 8;

  Future<void> _attack() async {
    final text = _draft.trim();
    if (_thinking || _s.outcome != BattleOutcome.ongoing) return;
    if (text.characters.length < _minLength) {
      setState(() => _error = '理由がわかるように、もう少し書いてみよう（$_minLength文字以上）');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _thinking = true;
      _error = null;
      _pending = text;
      _inputKey++;
    });
    _scrollToEnd();
    try {
      final turn = await BossJudge.judge(_boss, _s, text);
      if (!mounted) return;
      setState(() {
        _s = _s.apply(turn);
        _thinking = false;
        _pending = null;
        _draft = '';
        _restartIdle();
      });
      _bossShake.forward(from: 0);
      _popup.forward(from: 0);
      // 理由が効いたらちびのう（ヒット 1・メガヒット 2・勝利は難しさで 3〜8）。戦いが終わった時にまとめて届く
      final earned =
          switch (turn.hit) {
            Hit.mega => 2,
            Hit.hit => 1,
            _ => 0,
          } +
          (_s.outcome == BattleOutcome.won ? widget.difficulty.winBrains : 0);
      _brains += earned;
      if (turn.hit == Hit.mega) HapticFeedback.heavyImpact();
      // ボスの反撃は少し遅れて
      if (turn.counter > 0 && _s.bossHp > 0) {
        Future<void>.delayed(const Duration(milliseconds: 700), () {
          if (mounted) _playerHit.forward(from: 0);
        });
      }
      _scrollToEnd();
      if (_s.outcome != BattleOutcome.ongoing) _finish();
    } catch (e) {
      if (!mounted) return;
      // 失敗したら、書いた文を入力欄に戻す
      setState(() {
        _thinking = false;
        _pending = null;
        _inputKey++;
        _error = 'ボスが黙ってしまった…（通信エラー）。もう一度攻撃してみよう';
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_log.hasClients) {
        _log.animateTo(
          _log.position.maxScrollExtent,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _finish() {
    final won = _s.outcome == BattleOutcome.won;
    ref.read(playerProvider.notifier).addXp(won ? widget.difficulty.winXp : BattleScreen.loseXp);
    if (won) ref.read(missionProvider.notifier).add(MissionKind.bossWin);
    // ちびのうは、戦いが終わった時にまとめてメールで届く
    ref
        .read(brainProvider.notifier)
        .earn(
          _brains,
          won ? 'ボス戦: ${_boss.name}を納得させた（${'★' * widget.difficulty.stars}）' : 'ボス戦: ${_boss.name}に効いた反論の分',
        );
    // 記録に残す（記録の画面の「ボス戦」）
    final best = _s.turns.reduce((a, b) => a.damage >= b.damage ? a : b);
    ref
        .read(battleRecordsProvider.notifier)
        .add(
          BattleRecord(
            topicId: widget.topicId,
            boss: _boss.name,
            finishedAt: DateTime.now(),
            won: won,
            turns: _s.turns.length,
            damage: _s.damageDealt,
            stars: widget.difficulty.stars,
            bossMaxHp: _s.bossMaxHp,
            bestAttack: best.attack,
            bestDamage: best.damage,
            brains: _brains,
            log: _s.turns,
          ),
        );
    if (Cloud.ready) {
      unawaited(
        FirebaseAnalytics.instance
            .logEvent(
              name: 'boss_battle',
              parameters: {
                'topic': widget.topicId,
                'won': won ? 1 : 0,
                'turns': _s.turns.length,
                'damage': _s.damageDealt,
                'stars': widget.difficulty.stars,
              },
            )
            .catchError((Object _) {}),
      );
    }
    Future<void>.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ResultDialog(
          boss: _boss,
          state: _s,
          brains: _brains,
          onRetry: () {
            Navigator.of(context).pop();
            setState(() {
              _s = BattleState(difficulty: widget.difficulty);
              _brains = 0;
              _hints = 0;
              _hintHistory.clear();
              _restartIdle();
              _inputKey++;
              _draft = '';
            });
          },
          onHome: () {
            Navigator.of(context).pop();
            context.go('/topics/battle');
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _idle?.cancel();
    _bossShake.dispose();
    _playerHit.dispose();
    _popup.dispose();
    _log.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _s.turns.lastOrNull;
    final over = _s.outcome != BattleOutcome.ongoing;

    return Scaffold(
      backgroundColor: Colors.black,
      body: PhoneFrame(
        background: const LinearGradient(colors: [Colors.black, Colors.black]),
        child: Stack(
          children: [
            // 背景: テーマの絵を暗く
            Positioned.fill(
              child: Opacity(
                opacity: 0.28,
                child: Image.asset(_topic.image, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, box) {
                  // スマホでキーボードが出て、縦が狭い時: ボスを小さくし、直前のボスの言葉だけを大きく見せる
                  final short = box.maxHeight < 640;
                  final typing = short && _focus.hasFocus && !over;
                  final lastBoss = last?.reply ?? _boss.claim;
                  return Column(
                    children: [
                      if (!typing)
                        _TopBar(
                          title: '${_topic.title} ${'★' * widget.difficulty.stars}',
                          turnsLeft: _s.turnsLeft,
                          onClose: () => context.go('/topics/battle'),
                          onHelp: _openHelp,
                        ),
                      // ボス
                      AnimatedBuilder(
                        animation: _bossShake,
                        builder: (context, _) {
                          final shake = math.sin(_bossShake.value * math.pi * 6) * (1 - _bossShake.value) * 10;
                          return short
                              ? _BossBar(
                                  boss: _boss,
                                  hp: _s.bossHp,
                                  maxHp: _s.bossMaxHp,
                                  shake: shake,
                                  turnsLeft: typing ? _s.turnsLeft : null,
                                )
                              : _BossPanel(boss: _boss, hp: _s.bossHp, maxHp: _s.bossMaxHp, shake: shake);
                        },
                      ),
                      // あなたの立場
                      if (!typing)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                          child: _StanceRow(boss: _boss, yours: _yourStance),
                        ),
                      // やりとりの記録（入力中は、直前のボスの言葉だけ）
                      Expanded(
                        child: typing
                            ? SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                                child: _BossLine(
                                  boss: _boss,
                                  text: lastBoss,
                                  quote: true,
                                  easy: _easyOpen.contains(lastBoss) ? _easy[lastBoss] : null,
                                  easyLoading: _easyLoading.contains(lastBoss),
                                  onEasy: () => _toggleEasy(lastBoss),
                                ),
                              )
                            : ListView(
                                controller: _log,
                                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                                children: [
                                  BattleTranscript(
                                    boss: _boss,
                                    turns: _s.turns,
                                    easy: {for (final t in _easyOpen) t: ?_easy[t]},
                                    easyLoading: _easyLoading,
                                    onEasy: _toggleEasy,
                                  ),
                                  if (_pending case final p?) _PendingLine(text: p),
                                  if (_thinking) _BossLine(boss: _boss, text: '……', thinking: true),
                                ],
                              ),
                      ),
                      // プレイヤー
                      AnimatedBuilder(
                        animation: _playerHit,
                        builder: (context, child) => Container(
                          decoration: BoxDecoration(
                            color: Color.lerp(
                              AppColors.paperBottom,
                              AppColors.red.withValues(alpha: 0.6),
                              math.sin(_playerHit.value * math.pi),
                            ),
                            border: const Border(top: BorderSide(color: AppColors.line)),
                          ),
                          child: child,
                        ),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, typing ? 8 : 12, 16, typing ? 8 : 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!typing) ...[
                                _HpBar(
                                  label: 'あなた',
                                  hp: _s.playerHp,
                                  max: BattleState.playerMaxHp,
                                  color: AppColors.xpGreen,
                                ),
                                const SizedBox(height: 10),
                              ],
                              if (over)
                                Center(
                                  child: Text(
                                    _s.outcome == BattleOutcome.won ? 'ボスを納得させた！' : 'ボスの壁は厚かった…',
                                    style: sans(16, weight: FontWeight.w800),
                                  ),
                                )
                              else ...[
                                if (_error != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      _error!,
                                      style: sans(12, weight: FontWeight.w700, color: AppColors.red),
                                    ),
                                  ),
                                // 考えこんでいる時のヒント
                                if (!_thinking && (_hint != null || _hintLoading))
                                  _HintCard(
                                    text: _hint,
                                    loading: _hintLoading,
                                    onClose: () => setState(() => _hint = null),
                                  )
                                else if (!_thinking && _hintReady && _hintsLeft != 0)
                                  _HintButton(left: _hintsLeft, onTap: _showHint),
                                IgnorePointer(
                                  ignoring: _thinking,
                                  child: Opacity(
                                    opacity: _thinking ? 0.5 : 1,
                                    child: GlassInput(
                                      key: ValueKey('attack$_inputKey'),
                                      focusNode: _focus,
                                      initial: _thinking ? '' : _draft,
                                      hint: _s.turns.isEmpty ? '「$_yourStance」の立場から、理由をつけて反論しよう' : 'ボスの言い返しの弱いところを突こう',
                                      maxLines: typing ? 3 : 4,
                                      onChanged: (t) => setState(() => _draft = t),
                                      onSubmit: _attack,
                                      submitLabel: _thinking ? 'ボスが考えています…' : '反論で攻撃する',
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            // ダメージの帯（画面を横切る）
            if (last != null)
              Positioned(
                left: 0,
                right: 0,
                top: 205,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _popup,
                    builder: (context, _) => _DamageBanner(turn: last, t: _popup.value),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.turnsLeft, required this.onClose, required this.onHelp});

  final String title;
  final int turnsLeft;
  final VoidCallback onClose;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: AppColors.ink),
          ),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: sans(15, weight: FontWeight.w800),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.ink.withValues(alpha: 0.5)),
            ),
            child: Text('残り $turnsLeft ターン', style: sans(12, weight: FontWeight.w800)),
          ),
          const SizedBox(width: 8),
          // あそびかた
          Semantics(
            button: true,
            label: 'あそびかた',
            child: GestureDetector(
              onTap: onHelp,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink.withValues(alpha: 0.7), width: 1.5),
                ),
                child: const Icon(Icons.question_mark_rounded, size: 17, color: AppColors.ink),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ボスの顔・名前・HP。攻撃が当たると揺れて、ダメージの数字が浮かぶ
class _BossPanel extends StatelessWidget {
  const _BossPanel({required this.boss, required this.hp, required this.maxHp, required this.shake});

  final Boss boss;
  final int hp;
  final double shake;

  final int maxHp;

  @override
  Widget build(BuildContext context) {
    final down = hp <= 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Column(
        children: [
          SizedBox(
            height: 128,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Transform.translate(
                  offset: Offset(shake, 0),
                  child: Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: down ? AppColors.muted : AppColors.red, width: 3),
                      boxShadow: const [BoxShadow(color: Color(0xAA000000), offset: Offset(4, 4))],
                    ),
                    child: ClipOval(
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          down ? Colors.grey : Colors.transparent,
                          down ? BlendMode.saturation : BlendMode.dst,
                        ),
                        child: Image.asset(boss.portrait, fit: BoxFit.cover, filterQuality: FilterQuality.medium),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  'BOSS',
                  style: sans(10, weight: FontWeight.w800, color: AppColors.onNavy),
                ),
              ),
              const SizedBox(width: 8),
              Text(boss.name, style: serif(20, weight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          _HpBar(label: '確信', hp: hp, max: maxHp, color: AppColors.red),
        ],
      ),
    );
  }
}

/// 縦が狭い時（スマホでキーボードが出た時など）の、小さいボス表示
class _BossBar extends StatelessWidget {
  const _BossBar({required this.boss, required this.hp, required this.maxHp, required this.shake, this.turnsLeft});

  final Boss boss;
  final int hp;
  final int maxHp;
  final double shake;

  /// 上のバーを隠している時だけ、残りターンをここに出す
  final int? turnsLeft;

  @override
  Widget build(BuildContext context) {
    final down = hp <= 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Transform.translate(
            offset: Offset(shake, 0),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: down ? AppColors.muted : AppColors.red, width: 2),
              ),
              child: ClipOval(child: Image.asset(boss.portrait, width: 40, height: 40, fit: BoxFit.cover)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(boss.name, style: serif(15, weight: FontWeight.w800)),
                    const Spacer(),
                    if (turnsLeft case final n?) Text('残り $n ターン', style: sans(11, weight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 3),
                _HpBar(label: '確信', hp: hp, max: maxHp, color: AppColors.red),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// あなたの立場と、ボスの立場
class _StanceRow extends StatelessWidget {
  const _StanceRow({required this.boss, required this.yours});

  final Boss boss;
  final String yours;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.35)),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'あなた  ',
              style: sans(11, weight: FontWeight.w800, color: AppColors.muted),
            ),
            TextSpan(
              text: '「$yours」',
              style: sans(12, weight: FontWeight.w800, color: AppColors.accent),
            ),
            TextSpan(
              text: '   vs   ',
              style: sans(11, weight: FontWeight.w800, color: AppColors.muted),
            ),
            TextSpan(
              text: '${boss.name}「${boss.stance}」',
              style: sans(12, weight: FontWeight.w800, color: AppColors.red),
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// ボス戦のやりとり（ボスの主張 → 反論 → 言い返し …）。戦いの画面と、記録の画面で使う
class BattleTranscript extends StatelessWidget {
  const BattleTranscript({
    super.key,
    required this.boss,
    required this.turns,
    this.easy = const {},
    this.easyLoading = const {},
    this.onEasy,
  });

  final Boss boss;
  final List<BattleTurn> turns;

  /// 「やさしく言うと」（戦いの画面だけ。記録の画面では出さない）: ボスの言葉 → 言いかえ
  final Map<String, String> easy;
  final Set<String> easyLoading;
  final ValueChanged<String>? onEasy;

  @override
  Widget build(BuildContext context) {
    Widget boss(String text, {int counter = 0}) => _BossLine(
      boss: this.boss,
      text: text,
      counter: counter,
      easy: easy[text],
      easyLoading: easyLoading.contains(text),
      onEasy: onEasy == null ? null : () => onEasy!(text),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        boss(this.boss.claim),
        for (final t in turns) ...[_PlayerLine(turn: t), boss(t.reply, counter: t.counter)],
      ],
    );
  }
}

/// HPバー（減る時はなめらかに）
class _HpBar extends StatelessWidget {
  const _HpBar({required this.label, required this.hp, required this.max, required this.color});

  final String label;
  final int hp;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(label, style: sans(12, weight: FontWeight.w800)),
        ),
        Expanded(
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              border: Border.all(color: AppColors.ink, width: 1.5),
            ),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: hp / max),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: v.clamp(0, 1),
                child: ColoredBox(color: color),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 52,
          child: Text(
            '$hp/$max',
            textAlign: TextAlign.right,
            style: sans(12, weight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _BossLine extends StatelessWidget {
  const _BossLine({
    required this.boss,
    required this.text,
    this.counter = 0,
    this.thinking = false,
    this.quote = false,
    this.easy,
    this.easyLoading = false,
    this.onEasy,
  });

  final Boss boss;
  final String text;
  final int counter;
  final bool thinking;

  /// 「やさしく言うと」の言いかえ（開いている時だけ）・読み込み中・押した時
  final String? easy;
  final bool easyLoading;
  final VoidCallback? onEasy;

  /// 入力中に見せる「直前のボスの言葉」（見出しつき・少し大きい字）
  final bool quote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, right: 40),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(child: Image.asset(boss.portrait, width: 30, height: 30, fit: BoxFit.cover)),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                  bottomRight: Radius.circular(14),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (quote)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '${boss.name}の言葉に反論しよう',
                        style: sans(10, weight: FontWeight.w800, color: AppColors.red),
                      ),
                    ),
                  Text(
                    thinking ? '${boss.name}が考えています…' : text,
                    style: sans(quote ? 14 : 13, weight: FontWeight.w700, color: const Color(0xFF16181A), height: 1.55),
                  ),
                  if (counter > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '反撃！ あなたに $counter ダメージ',
                      style: sans(11, weight: FontWeight.w800, color: AppColors.red),
                    ),
                  ],
                  if (easy != null) _EasyBox(text: easy!),
                  if (onEasy != null && !thinking)
                    _EasyButton(open: easy != null, loading: easyLoading, onTap: onEasy!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerLine extends StatelessWidget {
  const _PlayerLine({required this.turn});

  final BattleTurn turn;

  @override
  Widget build(BuildContext context) {
    final strong = turn.hit == Hit.mega || turn.hit == Hit.hit;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 40),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            border: Border.all(color: AppColors.ink.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                turn.attack,
                style: sans(13, weight: FontWeight.w700, color: AppColors.onNavy, height: 1.55),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    strong ? Icons.flash_on_rounded : Icons.water_drop_outlined,
                    size: 14,
                    color: turn.hit == Hit.mega ? const Color(0xFFFFD54F) : AppColors.accent,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${turn.hit.label} ${turn.damage}ダメージ',
                    style: sans(11, weight: FontWeight.w800, color: AppColors.accent),
                  ),
                ],
              ),
              if (turn.reason.isNotEmpty) Text(turn.reason, style: sans(11, color: AppColors.bodyText, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({
    required this.boss,
    required this.state,
    required this.brains,
    required this.onRetry,
    required this.onHome,
  });

  final Boss boss;
  final BattleState state;
  final int brains;
  final VoidCallback onRetry;
  final VoidCallback onHome;

  @override
  Widget build(BuildContext context) {
    final won = state.outcome == BattleOutcome.won;
    final best = state.turns.isEmpty ? null : state.turns.reduce((a, b) => a.damage >= b.damage ? a : b);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            color: won ? AppColors.navy : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.ink, width: 2),
            boxShadow: const [BoxShadow(color: Color(0xAA000000), offset: Offset(5, 5))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                won ? Icons.emoji_events_rounded : Icons.shield_moon_rounded,
                size: 52,
                color: won ? const Color(0xFFFFD54F) : AppColors.accent,
              ),
              const SizedBox(height: 8),
              Text(won ? '${boss.name}を納得させた！' : '${boss.name}の壁は厚かった…', style: sans(19, weight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                won ? '${state.turns.length}ターンで勝利' : 'あと ${state.bossHp} ダメージだった',
                style: sans(13, weight: FontWeight.w700, color: AppColors.accent),
              ),
              const SizedBox(height: 14),
              Text(
                '+${won ? state.difficulty.winXp : BattleScreen.loseXp} EXP',
                style: sans(22, weight: FontWeight.w800, color: AppColors.xpGreenLight),
              ),
              if (brains > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const ChibinoIcon(size: 20),
                    const SizedBox(width: 6),
                    Text(
                      'ちびのう +$brains',
                      style: sans(16, weight: FontWeight.w800, color: AppColors.onNavy),
                    ),
                  ],
                ),
              if (best != null && best.damage > 0) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 11),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'いちばん効いた反論（${best.damage}ダメージ）',
                        style: sans(11, weight: FontWeight.w800, color: AppColors.navy),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '「${best.attack}」',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: sans(13, weight: FontWeight.w700, color: const Color(0xFF16181A), height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: PushButton.colored(
                      colors: Palette.main.card,
                      height: 48,
                      depth: 4,
                      radius: 14,
                      onPressed: onRetry,
                      child: Text(
                        'もう一度',
                        style: sans(14, weight: FontWeight.w800, color: Palette.main.card.content),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: PushButton.colored(
                      colors: Palette.main.primary,
                      height: 48,
                      depth: 4,
                      radius: 14,
                      onPressed: onHome,
                      child: Text(
                        'テーマへ',
                        style: sans(14, weight: FontWeight.w800, color: AppColors.onNavy),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 判定を待っている間の、送った反論
class _PendingLine extends StatelessWidget {
  const _PendingLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 40),
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
          decoration: BoxDecoration(
            color: AppColors.navy.withValues(alpha: 0.7),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              bottomLeft: Radius.circular(14),
              bottomRight: Radius.circular(14),
            ),
            border: Border.all(color: AppColors.ink.withValues(alpha: 0.4)),
          ),
          child: Text(
            text,
            style: sans(13, weight: FontWeight.w700, color: AppColors.onNavy, height: 1.55),
          ),
        ),
      ),
    );
  }
}

/// ダメージの帯: 右から勢いよく滑りこみ、少し止まって、左へ抜けていく
class _DamageBanner extends StatelessWidget {
  const _DamageBanner({required this.turn, required this.t});

  final BattleTurn turn;

  /// 0〜1
  final double t;

  @override
  Widget build(BuildContext context) {
    if (t <= 0 || t >= 1) return const SizedBox.shrink();
    // 入る（0〜0.22）→ 止まる → 抜ける（0.78〜1）
    final x = t < 0.22
        ? 1.3 * (1 - Curves.easeOutBack.transform(t / 0.22))
        : t > 0.78
        ? -1.3 * Curves.easeInCubic.transform((t - 0.78) / 0.22)
        : 0.0;
    final (color, textColor) = switch (turn.hit) {
      Hit.mega => (const Color(0xFFFFC93C), const Color(0xFF2A1A00)),
      Hit.hit => (AppColors.red, Colors.white),
      Hit.graze => (const Color(0xFF8A8F94), Colors.white),
      Hit.miss => (const Color(0xFF3A3F44), AppColors.muted),
    };
    final big = turn.hit == Hit.mega;
    return FractionalTranslation(
      translation: Offset(x, 0),
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.skewX(-0.18),
        child: Container(
          height: big ? 84 : 70,
          margin: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.25)!]),
            border: Border.all(color: AppColors.ink, width: 2.5),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: big ? 24 : 12),
              const BoxShadow(color: Color(0xCC000000), offset: Offset(5, 5)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                turn.hit.label,
                style: sans(big ? 30 : 24, weight: FontWeight.w800, color: textColor).copyWith(
                  fontStyle: FontStyle.italic,
                  letterSpacing: 1,
                  shadows: const [Shadow(color: Color(0x66000000), offset: Offset(2, 2))],
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '-${turn.damage}',
                style: sans(big ? 40 : 32, weight: FontWeight.w800, color: textColor).copyWith(
                  fontStyle: FontStyle.italic,
                  shadows: const [Shadow(color: Color(0x66000000), offset: Offset(2, 2))],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ボスの言葉の下の「やさしく言うと」ボタン
class _EasyButton extends StatelessWidget {
  const _EasyButton({required this.open, required this.loading, required this.onTap});

  final bool open;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF1F3A68);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: ink))
            else
              Icon(open ? Icons.expand_less_rounded : Icons.translate_rounded, size: 14, color: ink),
            const SizedBox(width: 4),
            Text(
              loading ? 'やさしい言葉にしています…' : (open ? 'とじる' : 'やさしく言うと？'),
              style: sans(11, weight: FontWeight.w800, color: ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// やさしく言いかえた言葉
class _EasyBox extends StatelessWidget {
  const _EasyBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1F3A68).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: Color(0xFF1F3A68), width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'やさしく言うと',
            style: sans(10, weight: FontWeight.w800, color: const Color(0xFF1F3A68)),
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: sans(13, weight: FontWeight.w600, color: const Color(0xFF16181A), height: 1.6),
          ),
        ],
      ),
    );
  }
}

/// 1分考えこんだら出る「ヒントを見る」（ふわっと点滅して気づかせる）
class _HintButton extends StatefulWidget {
  const _HintButton({required this.left, required this.onTap});

  /// 残りの数（-1 = 何回でも）
  final int left;
  final VoidCallback onTap;

  @override
  State<_HintButton> createState() => _HintButtonState();
}

class _HintButtonState extends State<_HintButton> with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _glow,
          builder: (context, child) => Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Color.lerp(AppColors.accent, const Color(0xFFFFD54F), _glow.value)!,
                width: 1.5,
              ),
            ),
            child: child,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Color(0xFFFFD54F)),
              const SizedBox(width: 5),
              Text(
                widget.left < 0 ? '迷ったら、ヒントを見る' : '迷ったら、ヒントを見る（あと${widget.left}回）',
                style: sans(12, weight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ヒント（答えではなく、考える糸口）
class _HintCard extends StatelessWidget {
  const _HintCard({required this.text, required this.loading, required this.onClose});

  final String? text;
  final bool loading;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.lightbulb_rounded, size: 18, color: Color(0xFFFFD54F)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ヒント',
                  style: sans(11, weight: FontWeight.w800, color: const Color(0xFFFFD54F)),
                ),
                const SizedBox(height: 2),
                Text(loading ? 'ヒントを考えています…' : text ?? '', style: sans(13, weight: FontWeight.w600, height: 1.6)),
              ],
            ),
          ),
          if (!loading)
            GestureDetector(
              onTap: onClose,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 18, color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// ボス戦のあそびかた（右上の「？」・はじめてのボス戦）。
/// 1ページに1つだけ、大きいアイコンと短い一言で。横にめくって読む
class _HelpSheet extends StatefulWidget {
  const _HelpSheet({required this.boss, required this.yours, required this.difficulty});

  final Boss boss;
  final String yours;
  final Difficulty difficulty;

  @override
  State<_HelpSheet> createState() => _HelpSheetState();
}

class _HelpSheetState extends State<_HelpSheet> {
  final _pages = PageController();
  int _i = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.difficulty;
    final hint = d.unlimitedHints ? '何回でも' : (d.hints == 0 ? 'この難しさでは なし' : '${d.hints}回まで');
    // (アイコン, 色, 見出し, ひとこと, 下に出す小さい図)
    final pages = <(IconData, Color, String, String, Widget?)>[
      (
        Icons.flag_rounded,
        AppColors.red,
        '「確信」を0にしたら勝ち',
        '${widget.boss.name}を納得させよう',
        const _MiniBar(color: AppColors.red, label: '確信', fill: 0.35),
      ),
      (
        Icons.flash_on_rounded,
        const Color(0xFFFFD54F),
        '理由をつけて反論',
        '「${widget.yours}」の立場から。\n理由が鋭いほど大ダメージ',
        const _HitChips(),
      ),
      (
        Icons.favorite_rounded,
        AppColors.xpGreen,
        'ボスの反撃に注意',
        '反論が弱いと、あなたの HP が減る',
        const _MiniBar(color: AppColors.xpGreen, label: 'あなた', fill: 0.6),
      ),
      (Icons.translate_rounded, AppColors.accent, 'むずかしい時は', '吹き出しの「やさしく言うと？」', null),
      (Icons.lightbulb_rounded, const Color(0xFFFFD54F), '迷ったらヒント', '1分考えこむと出る（$hint）', null),
    ];
    final last = _i == pages.length - 1;

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.paperTop,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: AppColors.red, width: 2)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  'あそびかた',
                  style: sans(13, weight: FontWeight.w800, color: AppColors.muted, spacing: 1),
                ),
                const Spacer(),
                Text(
                  '${_i + 1} / ${pages.length}',
                  style: sans(12, weight: FontWeight.w800, color: AppColors.muted),
                ),
              ],
            ),
            SizedBox(
              height: 250,
              child: PageView(
                controller: _pages,
                onPageChanged: (i) => setState(() => _i = i),
                children: [
                  for (final (icon, color, title, body, extra) in pages)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 2.5),
                            boxShadow: const [BoxShadow(color: Color(0xAA000000), offset: Offset(3, 3))],
                          ),
                          child: Icon(icon, size: 36, color: color),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: sans(21, weight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: sans(14, weight: FontWeight.w600, color: AppColors.bodyText, height: 1.6),
                        ),
                        if (extra != null) ...[const SizedBox(height: 14), extra],
                      ],
                    ),
                ],
              ),
            ),
            // ページの点
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var k = 0; k < pages.length; k++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: k == _i ? 18 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: k == _i ? AppColors.ink : AppColors.line,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (!last) ...[
                  Expanded(
                    child: PushButton(
                      height: 46,
                      depth: 4,
                      radius: 14,
                      face: AppColors.surface,
                      edge: const Color(0xFF16181A),
                      border: AppColors.ink,
                      borderWidth: 1.5,
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        'とばす',
                        style: sans(14, weight: FontWeight.w800, color: AppColors.ink),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  flex: 2,
                  child: PushButton(
                    height: 46,
                    depth: 4,
                    radius: 14,
                    face: last ? AppColors.red : AppColors.navy,
                    edge: last ? const Color(0xFF8E1C17) : AppColors.navyDeep,
                    onPressed: last
                        ? () => Navigator.of(context).pop()
                        : () => _pages.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut),
                    child: Text(
                      last ? 'たたかう！' : 'つぎへ ›',
                      style: sans(15, weight: FontWeight.w800, color: Colors.white),
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

/// あそびかたの図: 小さい HP バー
class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.color, required this.label, required this.fill});

  final Color color;
  final String label;
  final double fill;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Row(
        children: [
          Text(label, style: sans(11, weight: FontWeight.w800)),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                border: Border.all(color: AppColors.ink, width: 1.5),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fill,
                child: ColoredBox(color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// あそびかたの図: 当たり方
class _HitChips extends StatelessWidget {
  const _HitChips();

  @override
  Widget build(BuildContext context) {
    Widget chip(String text, Color color) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        text,
        style: sans(11, weight: FontWeight.w800, color: color),
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        chip('メガヒット', const Color(0xFFFFD54F)),
        chip('ヒット', AppColors.accent),
        chip('かすり', AppColors.muted),
        chip('ミス', AppColors.line),
      ],
    );
  }
}
