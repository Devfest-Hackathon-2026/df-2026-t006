import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../brand.dart';
import '../models/think_card.dart';
import '../services/music.dart';
import '../theme.dart';

/// リールの各カードでやること（すべてのカードに1つずつ）。
/// 終わらないと次へスワイプできない。書くのは最後の1枚だけで、それ以外は選ぶだけ。
enum ReelTask {
  /// 直感で答える（そう思う / 思わない / わからない）
  instinct,

  /// 言葉への共感度をスライダーで（反対 ↔ 賛成）
  agree,

  /// 選択肢から選ぶ
  choice,

  /// 自分の考えを書く（最後の1枚だけ）
  write,
}

/// カードの種類から、やることを決める
ReelTask taskFor(ThinkCard c) {
  if (c.choices != null) return ReelTask.choice;
  if (c.isInput) return ReelTask.write;
  if (c.quote != null) return ReelTask.agree;
  return ReelTask.instinct;
}

const instinctOptions = ['そう思う', '思わない', 'わからない'];

/// 反論を読んだ後の答え
const stanceOptions = ['それでも変わらない', '少し揺らいだ', '考えを変える'];

/// 「考えを変える」の番号
const stanceChange = 2;

/// どの反論を見せるか（なければ null）。
/// 選択・直感は選んだ番号、共感スライダーは 反対(0) / 賛成(1) / どちらとも(2)
int? counterIndex(ThinkCard c, int? choice) {
  if (choice == null || c.counters == null) return null;
  final i = switch (taskFor(c)) {
    ReelTask.instinct || ReelTask.choice => choice,
    ReelTask.agree => choice < 45 ? 0 : (choice > 55 ? 1 : 2),
    ReelTask.write => null,
  };
  return i != null && i < c.counters!.length ? i : null;
}

/// 反論への答えがまだで、先へ進めない時 true（「考えを変える」を選んだ後は、選び直せば進める）
bool needsStance(ThinkCard c, int? choice, int? stance) => counterIndex(c, choice) != null && stance == null;

/// 賛成スライダーの値（0〜100）の呼び方
String agreeLabel(int v) => v < 20
    ? '反対'
    : v < 45
    ? 'やや反対'
    : v <= 55
    ? 'どちらとも'
    : v <= 80
    ? 'やや賛成'
    : '賛成';

/// 選んだ答えの呼び方（反論の上の「あなたの答え」など）
String answerLabel(ThinkCard c, int choice) => switch (taskFor(c)) {
  ReelTask.instinct => instinctOptions[choice],
  ReelTask.choice => c.choices![choice],
  ReelTask.agree => agreeLabel(choice),
  ReelTask.write => '',
};

/// やることが終わったか。choice: 選んだ番号やスライダーの値、text: 書いた文（1文字でもOK）
bool taskDone(ReelTask t, int? choice, String? text) => switch (t) {
  ReelTask.instinct || ReelTask.agree || ReelTask.choice => choice != null,
  ReelTask.write => (text ?? '').trim().isNotEmpty,
};

/// まだ終わっていない時の案内
String taskHint(ReelTask t) => switch (t) {
  ReelTask.instinct => '直感で選ぶと、次へ進めます',
  ReelTask.agree => 'スライダーを動かすと、次へ進めます',
  ReelTask.choice => '答えを選ぶと、次へ進めます',
  ReelTask.write => 'めもを書くと、次へ進めます',
};

/// カードの下に出す「やること」
class ReelTaskPanel extends StatelessWidget {
  const ReelTaskPanel({
    super.key,
    required this.task,
    required this.card,
    required this.index,
    required this.choice,
    required this.text,
    required this.onChoose,
    required this.onText,
    this.stance,
    this.onStance,
    this.onSubmit,
    this.onNext,
    this.onFinish,
    this.onRewrite,
    this.writeVersion = 0,
  });

  /// 最後のカード: 書いてAIに測ってもらった後の「考えきった！おわる」と「書き直す」
  final VoidCallback? onFinish;
  final VoidCallback? onRewrite;

  /// 書き直すたびに増える（入力欄を空にして作り直す）
  final int writeVersion;

  /// 書くカードで Enter・ボタンを押した時（AIの判定）
  final VoidCallback? onSubmit;

  /// 反論に答えた後に「上にスワイプ」の案内を出すか（渡すと出る。めくるのは指で）
  final VoidCallback? onNext;

  final ReelTask task;
  final ThinkCard card;
  final int index;
  final int? choice;
  final String? text;
  final ValueChanged<int> onChoose;
  final ValueChanged<String> onText;

  /// 反論への答え
  final int? stance;
  final ValueChanged<int>? onStance;

  @override
  Widget build(BuildContext context) {
    // 選んだら、雲が裏返って「反論」になり、ここも選択肢から「反論への答え」に入れかわる。
    // 答えた後もそのまま（「次のリールへ」が出る）。「考えを変える」の時だけ表にもどって選び直す
    final answering = counterIndex(card, choice) != null;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.15), end: Offset.zero).animate(a),
          child: child,
        ),
      ),
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
      child: answering ? _stancePanel() : _answerPanel(),
    );
  }

  /// 反論への答え（それでも変わらない・少し揺らいだ・考えを変える）
  Widget _stancePanel() {
    return Column(
      key: const ValueKey('stance'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.record_voice_over_rounded, size: 16, color: AppColors.ink, shadows: _titleShadow),
            const SizedBox(width: 6),
            Text(
              '反論に、どう答える？',
              style: sans(13, weight: FontWeight.w800).copyWith(shadows: _titleShadow),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < stanceOptions.length; i++)
              GlassChip(text: stanceOptions[i], selected: stance == i, onTap: () => onStance?.call(i)),
          ],
        ),
        // 答えたら、すぐ下に「上にスワイプ」の案内（ボタンではなく、指でめくってもらう）
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: stance == null || onNext == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _SwipeCue(onTap: onNext!),
                ),
        ),
      ],
    );
  }

  /// ふつうの答え（選択肢・スライダー・入力欄）
  Widget _answerPanel() {
    return Column(
      key: const ValueKey('answer'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _TaskTitle(task: task),
        const SizedBox(height: 10),
        switch (task) {
          ReelTask.instinct => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < instinctOptions.length; i++)
                GlassChip(text: instinctOptions[i], selected: choice == i, onTap: () => onChoose(i)),
            ],
          ),
          ReelTask.agree => _AgreeSlider(value: choice, onChanged: onChoose),
          ReelTask.choice => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < card.choices!.length; i++)
                GlassChip(text: card.choices![i], selected: choice == i, onTap: () => onChoose(i)),
            ],
          ),
          ReelTask.write => GlassInput(
            key: ValueKey('write$index-$writeVersion'),
            initial: text ?? '',
            hint: '思ったことを、そのまま書いてみよう',
            maxLines: 5,
            onChanged: onText,
            onSubmit: onSubmit,
            submitLabel: 'AIに深さを測ってもらう',
          ),
        },
        _afterCounter(),
        if (task == ReelTask.write && onFinish != null) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _EndButton(icon: Icons.edit_rounded, label: '書き直す', onTap: onRewrite ?? () {}, filled: false),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: _EndButton(icon: Icons.flag_rounded, label: '考えきった！ふりかえりへ', onTap: onFinish!, filled: true),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// 反論に答えた後のひとこと
  Widget _afterCounter() {
    if (stance == stanceChange && choice == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(
          'もう一度、選び直してみよう',
          style: sans(13, weight: FontWeight.w800, color: AppColors.accent).copyWith(shadows: _titleShadow),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

const _titleShadow = [Shadow(color: Color(0xCC000000), blurRadius: 6)];

class _TaskTitle extends StatelessWidget {
  const _TaskTitle({required this.task});

  final ReelTask task;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (task) {
      ReelTask.instinct => (Icons.bolt_rounded, '直感で答える'),
      ReelTask.agree => (Icons.tune_rounded, 'どれくらい共感する？'),
      ReelTask.choice => (Icons.how_to_vote_rounded, '選ぶ'),
      ReelTask.write => (Icons.edit_rounded, 'めも'),
    };
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: AppColors.accent,
          shadows: const [Shadow(color: Color(0xFF000000), blurRadius: 6)],
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: sans(
            13,
            weight: FontWeight.w800,
            color: AppColors.accent,
            spacing: 1,
          ).copyWith(shadows: const [Shadow(color: Color(0xFF000000), blurRadius: 6)]),
        ),
      ],
    );
  }
}

/// 反対 ↔ 賛成 のスライダー（動かすまでは「未回答」）。
/// 指をはなした時に答えが決まる（動かしている途中で反論に入れかわらないように）
class _AgreeSlider extends StatefulWidget {
  const _AgreeSlider({required this.value, required this.onChanged});

  final int? value;
  final ValueChanged<int> onChanged;

  @override
  State<_AgreeSlider> createState() => _AgreeSliderState();
}

class _AgreeSliderState extends State<_AgreeSlider> {
  /// 動かしている途中の値
  int? _drag;

  @override
  Widget build(BuildContext context) {
    final value = _drag ?? widget.value;
    final v = value ?? 50;
    final label = value == null ? '動かしてみよう' : agreeLabel(v);
    return Column(
      children: [
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            activeTrackColor: AppColors.ink,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
            thumbColor: AppColors.ink,
            overlayColor: Colors.white.withValues(alpha: 0.12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 11),
          ),
          child: Slider(
            value: v.toDouble(),
            max: 100,
            onChanged: (x) {
              if (x.round() != value) HapticFeedback.selectionClick();
              setState(() => _drag = x.round());
            },
            onChangeEnd: (x) {
              setState(() => _drag = null);
              widget.onChanged(x.round());
            },
          ),
        ),
        Row(
          children: [
            Text(
              '反対',
              style: sans(12, weight: FontWeight.w700, color: AppColors.bodyText),
            ),
            const Spacer(),
            Text(label, style: sans(14, weight: FontWeight.w800)),
            const Spacer(),
            Text(
              '賛成',
              style: sans(12, weight: FontWeight.w700, color: AppColors.bodyText),
            ),
          ],
        ),
      ],
    );
  }
}

/// すりガラス風の選択肢
class GlassChip extends StatelessWidget {
  const GlassChip({super.key, required this.text, required this.selected, required this.onTap, this.small = false});

  /// 反論の吹き出しの中など、小さく出す時
  final bool small;

  final String text;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Sfx.tap();
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: small ? 11 : 14, vertical: small ? 8 : 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.ink.withValues(alpha: selected ? 1 : 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 16,
              color: selected ? logoBlack : AppColors.ink,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                text,
                style: sans(small ? 13 : 14, weight: FontWeight.w700, color: selected ? logoBlack : AppColors.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// コピー＆ペーストを防ぐ: 一度に何文字も増えたら（貼り付け）受けつけない。
/// 日本語の変換中（composing）の入力や、変換の確定はふつうに通す
class NoPasteFormatter extends TextInputFormatter {
  NoPasteFormatter(this.onBlocked);

  final VoidCallback onBlocked;

  /// 一度にこれ以上増えたら、貼り付けとみなす
  static const maxJump = 10;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final grew = newValue.text.characters.length - oldValue.text.characters.length;
    if (grew >= maxJump && !oldValue.composing.isValid && !newValue.composing.isValid) {
      onBlocked();
      return oldValue;
    }
    return newValue;
  }
}

/// すりガラス風の入力欄（必要な文字数のカウンター付き）
class GlassInput extends StatefulWidget {
  const GlassInput({
    super.key,
    required this.initial,
    required this.hint,
    required this.onChanged,
    this.minLength = 0,
    this.maxLines = 3,
    this.onSubmit,
    this.submitLabel = '送信',
    this.allowPaste = false,
    this.focusNode,
  });

  /// 入力中かどうかを知りたい時に渡す（ボス戦で、スマホのキーボードが出たら画面を詰める）
  final FocusNode? focusNode;

  /// 貼り付けを許すか（自分の言葉で書いてほしいので、ふだんは許さない）
  final bool allowPaste;

  final String initial;
  final String hint;
  final ValueChanged<String> onChanged;
  final int minLength;
  final int maxLines;

  /// Enter キー・送信ボタンで呼ばれる（null なら送信ボタンなし。Enter は改行）。
  /// Shift+Enter は改行。日本語の変換中の Enter は変換の確定に使う
  final VoidCallback? onSubmit;
  final String submitLabel;

  @override
  State<GlassInput> createState() => _GlassInputState();
}

class _GlassInputState extends State<GlassInput> {
  late final _c = TextEditingController(text: widget.initial);

  /// 貼り付けを止めた時のお知らせ（数秒で消える）
  bool _pasteNote = false;
  Timer? _pasteTimer;

  late final _noPaste = NoPasteFormatter(() {
    HapticFeedback.heavyImpact();
    _pasteTimer?.cancel();
    setState(() => _pasteNote = true);
    _pasteTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _pasteNote = false);
    });
  });

  bool get _canSubmit => widget.onSubmit != null && _c.text.trim().isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    FocusScope.of(context).unfocus();
    widget.onSubmit!();
  }

  /// Enter で送信（変換中・Shift 付きはそのまま）
  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (widget.onSubmit == null || e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey != LogicalKeyboardKey.enter && e.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (HardwareKeyboard.instance.isShiftPressed || _c.value.composing.isValid) return KeyEventResult.ignored;
    _submit();
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _pasteTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final len = _c.text.trim().characters.length;
    final enough = len >= widget.minLength;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Focus(
          onKeyEvent: _onKey,
          canRequestFocus: false,
          skipTraversal: true,
          child: TextField(
            controller: _c,
            focusNode: widget.focusNode,
            inputFormatters: [if (!widget.allowPaste) _noPaste],
            onChanged: (t) {
              setState(() {});
              widget.onChanged(t);
            },
            minLines: 1,
            maxLines: widget.maxLines,
            style: sans(15),
            cursorColor: AppColors.ink,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: sans(14, color: AppColors.ink.withValues(alpha: 0.55)),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.55),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.ink.withValues(alpha: 0.4)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.ink),
              ),
            ),
          ),
        ),
        // 貼り付けを止めた時のお知らせ
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          child: !_pasteNote
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_off_rounded, size: 16, color: Color(0xFFFF8A80)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'コピー＆ペーストはできません。自分の言葉で書いてみよう',
                          style: sans(
                            12,
                            weight: FontWeight.w800,
                            color: const Color(0xFFFF8A80),
                          ).copyWith(shadows: _titleShadow),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
        if (widget.onSubmit != null) ...[
          const SizedBox(height: 10),
          _SubmitButton(label: widget.submitLabel, enabled: _canSubmit, onTap: _submit),
        ],
        if (widget.minLength > 0) ...[
          const SizedBox(height: 4),
          Text(
            enough ? '✓ $len文字' : '$len / ${widget.minLength}文字',
            style: sans(11, weight: FontWeight.w700, color: enough ? AppColors.xpGreenLight : AppColors.bodyText),
          ),
        ],
      ],
    );
  }
}

/// 入力欄の下の送信ボタン（Enter と同じ）
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.label, required this.enabled, required this.onTap});

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled
          ? () {
              Sfx.tap();
              onTap();
            }
          : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1 : 0.45,
        child: Container(
          width: double.infinity,
          height: 46,
          decoration: BoxDecoration(
            color: AppColors.navy,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.ink, width: 1.5),
            boxShadow: const [BoxShadow(color: Color(0xAA000000), offset: Offset(3, 3))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 18, color: AppColors.onNavy),
              const SizedBox(width: 8),
              Text(
                label,
                style: sans(15, weight: FontWeight.w800, color: AppColors.onNavy),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.7)),
                ),
                child: Text(
                  'Enter',
                  style: sans(10, weight: FontWeight.w800, color: AppColors.accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 「上にスワイプ」の案内。山形の矢印が下から上へ流れ、指でめくりたくなるように
class _SwipeCue extends StatefulWidget {
  const _SwipeCue({required this.onTap});

  /// 押した時
  final VoidCallback onTap;

  @override
  State<_SwipeCue> createState() => _SwipeCueState();
}

class _SwipeCueState extends State<_SwipeCue> with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              // 3つの山形が、下から順に光って上へ流れる
              AnimatedBuilder(
                animation: _flow,
                builder: (context, _) => Column(
                  children: [
                    for (var k = 0; k < 3; k++)
                      Transform.translate(
                        offset: Offset(0, -_flow.value * 6),
                        child: Opacity(
                          opacity: _glow(_flow.value, 2 - k),
                          child: const Icon(
                            Icons.keyboard_arrow_up_rounded,
                            size: 30,
                            color: AppColors.ink,
                            shadows: _titleShadow,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '上にスワイプして次のリールへ',
                style: sans(13, weight: FontWeight.w800).copyWith(shadows: _titleShadow, letterSpacing: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// k 番目（下から）の矢印の明るさ。下から順に光っていく
  double _glow(double t, int k) {
    final phase = (t * 3 - k) % 3;
    return phase < 1 ? 0.35 + 0.65 * (1 - (phase - 0.5).abs() * 2) : 0.35;
  }
}

/// 最後のカードのボタン（書き直す / 考えきった！おわる）
class _EndButton extends StatelessWidget {
  const _EndButton({required this.icon, required this.label, required this.onTap, required this.filled});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// 塗りつぶし（おわる）か、枠だけ（書き直す）か
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? const Color(0xFF16181A) : AppColors.ink;
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        Sfx.tap();
        onTap();
      },
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: filled ? AppColors.ink : Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.ink, width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0xAA000000), offset: Offset(3, 3))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: sans(14, weight: FontWeight.w800, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
