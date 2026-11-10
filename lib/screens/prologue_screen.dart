import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/brains.dart';
import '../theme.dart';
import '../widgets/hitachan.dart';
import '../widgets/phone_frame.dart';
import '../widgets/baked_image.dart';

/// プロローグ（はじめて遊ぶ時に1回だけ。設定・ひたちゃんの画面からもう一度見られる）。
/// 紙芝居のように、木の舞台に絵の札を差し、1枚ずつ横へ抜いていく。
/// 語りは昔話の口調で、絵の下の紙に1字ずつ出る。
/// ※ お話はフィクション（ひたちゃんという生きものの話）。
class PrologueScreen extends ConsumerStatefulWidget {
  const PrologueScreen({super.key});

  @override
  ConsumerState<PrologueScreen> createState() => _PrologueScreenState();
}

class _Scene {
  const _Scene(this.image, this.text, {this.hita, this.hitaFade = false, this.title, this.modern = false});

  final String image;
  final String text;

  /// ひたちゃんを出すなら、その段階（null なら出さない）
  final int? hita;

  /// ひたちゃんが消えていく
  final bool hitaFade;

  /// 表紙の題（表紙の札だけ）
  final String? title;

  /// 現代の写真（古い絵より色を抑えて、紙芝居の絵になじませる）
  final bool modern;
}

const _scenes = [
  _Scene('assets/prologue/p2_arcadian.jpg', 'はじまり、はじまり。', title: 'ひたちゃんの\nおはなし', hita: 2),
  _Scene('assets/prologue/p1_savage.jpg', 'むかしむかし、人の頭の中には\n「ひたちゃん」という\n小さな生きものが住んでいました。', hita: 2),
  _Scene('assets/prologue/p2_arcadian.jpg', 'ひたちゃんの好物は、人の「なぜ？」。\n哲学者たちが問い続けた時代、\nひたちゃんは大きく、たくましく育ちました。', hita: 4),
  _Scene(
    'assets/prologue/p3_modern.jpg',
    'ときは流れて、西暦20XX年。\n人は、なんでも答えてくれる\nAIを手に入れました。\n考える前に聞き、「なぜ？」と\n問うのをやめてしまったのです。',
    modern: true,
  ),
  _Scene(
    'assets/prologue/p4_desolation.jpg',
    '「なぜ？」を食べられなくなった\nひたちゃんたちはしぼんでしまい、\nひとり、またひとりと\n姿を消していきました。',
    hita: 1,
    hitaFade: true,
  ),
  _Scene('assets/prologue/p5_colosseum.jpg', 'そして今、あなたの頭の中に\n最後のひたちゃんがいます。\nあなたの「なぜ？」で、\nもう一度ひたちゃんを育ててください。', hita: 0),
];

/// 紙芝居の色
const _wood = Color(0xFF7A4B2A);
const _woodDark = Color(0xFF4E2E18);
const _woodLight = Color(0xFFA06A3F);
const _paper = Color(0xFFF3E8D0);
const _sumi = Color(0xFF2B1D12);
const _table = Color(0xFF241812);

class _PrologueScreenState extends ConsumerState<PrologueScreen> with TickerProviderStateMixin {
  int _i = 0;

  /// 札を横へ抜くアニメーション（0 → 1 で今の札が左へ抜けて、次の札が見える）
  late final AnimationController _pull = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

  /// 古いテレビのちらつき・流れる明るい帯
  late final AnimationController _tv = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();

  /// 絵のゆっくりした動き
  late AnimationController _zoom = _newZoom();

  /// はじまり: 真っ暗なまま少し待ってから、お話がフェードイン
  static const _darkHold = Duration(milliseconds: 3200);

  /// 暗転中の題（PROLOGUE / 序章 / 最後のひたちゃん）。出る時と消える時は同じ動き
  /// （下からふわっと上がって現れ、そのまま上へ流れながら消える）
  static const _titleMove = Duration(milliseconds: 1200);
  late final AnimationController _titleIn = AnimationController(vsync: this, duration: _titleMove);
  late final AnimationController _titleOut = AnimationController(vsync: this, duration: _titleMove);
  late final AnimationController _fadeIn = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  Timer? _hold;

  /// おわり: 「ひたちゃんに会いにいく」で暗転してから、ひたちゃんの画面へ
  late final AnimationController _outro = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  /// 語りのスクロール（字が増えたら下へついていく）
  final _textScroll = ScrollController();

  /// 1字ずつ出す
  int _chars = 0;
  Timer? _typer;

  AnimationController _newZoom() => AnimationController(vsync: this, duration: const Duration(seconds: 10))..forward();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _titleIn.forward();
    });
    _hold = Timer(_darkHold, () async {
      if (!mounted) return;
      // 題が消えはじめてから、少し遅れてお話が明ける
      _titleOut.forward();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      await _fadeIn.forward();
      if (mounted) _type();
    });
  }

  /// まだ暗転中・フェードイン中
  bool get _starting => !_fadeIn.isCompleted;

  void _type() {
    _typer?.cancel();
    _chars = 0;
    if (_textScroll.hasClients) _textScroll.jumpTo(0);
    _typer = Timer.periodic(const Duration(milliseconds: 55), (t) {
      if (!mounted) return t.cancel();
      final len = _scenes[_i].text.characters.length;
      setState(() => _chars = math.min(_chars + 1, len));
      if (_chars >= len) t.cancel();
      // 紙からはみ出したら、出ている字が見えるように下へ
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_textScroll.hasClients) _textScroll.jumpTo(_textScroll.position.maxScrollExtent);
      });
    });
  }

  bool get _typing => _chars < _scenes[_i].text.characters.length;

  bool get _last => _i == _scenes.length - 1;

  Future<void> _next() async {
    if (_starting) return;
    if (_typing) {
      // 語りが途中なら、全部出す
      _typer?.cancel();
      setState(() => _chars = _scenes[_i].text.characters.length);
      return;
    }
    if (_last || _pull.isAnimating) return;
    HapticFeedback.selectionClick();
    await _pull.forward(from: 0);
    if (!mounted) return;
    _zoom.dispose();
    setState(() {
      _i++;
      _zoom = _newZoom();
      _pull.value = 0;
    });
    _type();
  }

  Future<void> _done() async {
    if (_outro.isAnimating) return;
    ref.read(prologueSeenProvider.notifier).set(true);
    await _outro.forward();
    // ひたちゃんの画面は、暗転からフェードインで出る
    if (mounted) context.go('/hitachan?from=prologue');
  }

  @override
  void dispose() {
    _textScroll.dispose();
    _typer?.cancel();
    _hold?.cancel();
    _fadeIn.dispose();
    _titleIn.dispose();
    _titleOut.dispose();
    _outro.dispose();
    _tv.dispose();
    _pull.dispose();
    _zoom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scene = _scenes[_i];
    final next = _last ? null : _scenes[_i + 1];
    final shown = scene.text.characters.take(_chars).toString();

    return Scaffold(
      backgroundColor: _table,
      body: PhoneFrame(
        background: const RadialGradient(center: Alignment(0, -0.3), radius: 1.1, colors: [Color(0xFF3A271B), _table]),
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _next,
              child: Focus(
                autofocus: true,
                onKeyEvent: (_, e) {
                  if (e is KeyDownEvent &&
                      (e.logicalKey == LogicalKeyboardKey.enter || e.logicalKey == LogicalKeyboardKey.space)) {
                    _last && !_typing ? _done() : _next();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Column(
                      children: [
                        // 上: 何枚目か（漢数字）とスキップ
                        Row(
                          children: [
                            Text(
                              '${_kanji(_i + 1)} ／ ${_kanji(_scenes.length)}',
                              style: serif(13, weight: FontWeight.w600, color: _paper.withValues(alpha: 0.7)),
                            ),
                            const Spacer(),
                            if (!_last)
                              TextButton(
                                onPressed: _done,
                                child: Text(
                                  'スキップ ›',
                                  style: serif(13, weight: FontWeight.w600, color: _paper.withValues(alpha: 0.8)),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // 紙芝居の舞台（木の枠）と、絵の札（低い画面では、語りの紙のために絵を小さく）
                        _Stage(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.48,
                          child: AnimatedBuilder(
                            animation: Listenable.merge([_pull, _zoom, _tv]),
                            builder: (context, _) {
                              final p = Curves.easeInCubic.transform(_pull.value);
                              // 1950年代のテレビのように: 少しぼやけ・走査線・ちらつき（色はそのまま）
                              return _OldTv(
                                t: _tv.value,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // 次の札（後ろにある）
                                    if (next != null) _Card(scene: next, zoom: 0, fade: 0),
                                    // 今の札（左へ抜ける）
                                    Transform.translate(
                                      offset: Offset(-p * 340, 0),
                                      child: _Card(
                                        scene: scene,
                                        zoom: Curves.easeInOut.transform(_zoom.value),
                                        fade: scene.hitaFade ? Curves.easeIn.transform(_zoom.value) * 0.85 : 0,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        // 語り（昔話の口調）を紙に
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                            decoration: BoxDecoration(
                              color: _paper,
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [
                                BoxShadow(color: Color(0x88000000), blurRadius: 10, offset: Offset(0, 4)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // スマホで紙が低い時も、語りを全部読めるようにスクロールできる
                                Expanded(
                                  child: Scrollbar(
                                    controller: _textScroll,
                                    thumbVisibility: true,
                                    child: SingleChildScrollView(
                                      controller: _textScroll,
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Text(
                                        shown,
                                        style: serif(
                                          16,
                                          weight: FontWeight.w600,
                                          color: _sumi,
                                        ).copyWith(height: 1.95, letterSpacing: 0.8),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_last && !_typing)
                                  Center(
                                    child: GestureDetector(
                                      onTap: _done,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: _wood,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: _woodDark, width: 2),
                                          boxShadow: const [BoxShadow(color: Color(0x66000000), offset: Offset(0, 3))],
                                        ),
                                        child: Text(
                                          'ひたちゃんに会いにいく',
                                          style: serif(15, weight: FontWeight.w800, color: _paper),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      _typing ? '' : 'つぎへ ▶',
                                      style: serif(12, weight: FontWeight.w600, color: _sumi.withValues(alpha: 0.55)),
                                    ),
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
            ),
            // はじまりの暗転（真っ暗 → ゆっくり明ける）
            IgnorePointer(
              ignoring: !_starting,
              child: AnimatedBuilder(
                animation: Listenable.merge([_fadeIn, _titleIn, _titleOut]),
                builder: (context, _) {
                  if (_fadeIn.isCompleted) return const SizedBox.shrink();
                  // 出る時: 下から上がりながら現れる / 消える時: 同じ速さで、さらに上へ流れながら消える
                  final inT = Curves.easeOut.transform(_titleIn.value);
                  final outT = Curves.easeIn.transform(_titleOut.value);
                  final title = inT * (1 - outT);
                  final rise = (1 - inT) * 10 - outT * 10;
                  return ColoredBox(
                    color: Colors.black.withValues(alpha: 1 - Curves.easeInOut.transform(_fadeIn.value)),
                    child: Center(
                      child: Opacity(
                        opacity: title,
                        child: Transform.translate(
                          offset: Offset(0, rise),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'PROLOGUE',
                                style: serif(
                                  13,
                                  weight: FontWeight.w600,
                                  color: _paper.withValues(alpha: 0.7),
                                ).copyWith(letterSpacing: 8),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                '序章',
                                style: serif(40, weight: FontWeight.w800, color: _paper).copyWith(letterSpacing: 12),
                              ),
                              const SizedBox(height: 14),
                              Container(width: 40, height: 1, color: _paper.withValues(alpha: 0.5)),
                              const SizedBox(height: 14),
                              Text(
                                '最後のひたちゃん',
                                style: serif(
                                  17,
                                  weight: FontWeight.w600,
                                  color: _paper.withValues(alpha: 0.85),
                                ).copyWith(letterSpacing: 4),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // おわりの暗転
            IgnorePointer(
              ignoring: !_outro.isAnimating && _outro.value == 0,
              child: AnimatedBuilder(
                animation: _outro,
                builder: (context, _) => _outro.value == 0
                    ? const SizedBox.shrink()
                    : ColoredBox(color: Colors.black.withValues(alpha: Curves.easeIn.transform(_outro.value))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _kanji(int n) => const ['〇', '一', '二', '三', '四', '五', '六', '七', '八', '九'][n.clamp(0, 9)];

/// 紙芝居の木の舞台（絵の札を入れる枠）
class _Stage extends StatelessWidget {
  const _Stage({required this.child, required this.maxHeight});

  final Widget child;

  /// 枠ごとの高さの上限
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_woodLight, _wood, _woodDark],
          ),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [BoxShadow(color: Color(0xAA000000), blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: Container(
          // 枠の内側の段（木の厚み）
          padding: const EdgeInsets.all(3),
          color: _woodDark,
          child: AspectRatio(aspectRatio: 0.86, child: ClipRect(child: child)),
        ),
      ),
    );
  }
}

/// 絵の札1枚（紙の白いふち、ゆっくり寄る絵、ひたちゃん）
class _Card extends StatelessWidget {
  const _Card({required this.scene, required this.zoom, required this.fade});

  final _Scene scene;

  /// 0〜1: 絵がゆっくり寄る
  final double zoom;

  /// 0〜1: ひたちゃんが消えていく
  final double fade;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _paper,
      padding: const EdgeInsets.all(6),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: Transform.scale(
              scale: 1.04 + zoom * 0.08,
              // 紙に刷った絵のように、少しくすませる（現代の写真は特に色を抑える）。
              // くすませた絵は1回だけ作って使い回す（ゆっくり寄る間に毎フレームかけ直さない）
              child: RepaintBoundary(child: BakedImage(scene.image, filter: scene.modern ? _modernFilter : _oldFilter)),
            ),
          ),
          // 紙のふちの影（周辺を少し暗く）
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(radius: 0.95, colors: [Colors.transparent, Color(0x55241812)], stops: [0.6, 1]),
            ),
          ),
          if (scene.hita != null)
            Align(
              alignment: scene.title != null ? const Alignment(0, 0.55) : const Alignment(0, 0.2),
              child: Hitachan(stage: scene.hita!, size: scene.title != null ? 170 : 190, fade: fade),
            ),
          if (scene.title != null)
            Align(
              alignment: const Alignment(0, -0.6),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                decoration: BoxDecoration(
                  color: _paper.withValues(alpha: 0.92),
                  border: Border.all(color: _sumi, width: 1.5),
                ),
                child: Text(
                  scene.title!,
                  textAlign: TextAlign.center,
                  style: serif(22, weight: FontWeight.w800, color: _sumi).copyWith(height: 1.4, letterSpacing: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static const _oldFilter = ColorFilter.matrix(_printOld);
  static const _modernFilter = ColorFilter.matrix(_printModern);

  /// 古い絵: 少しセピアに
  static const _printOld = <double>[
    0.9, 0.12, 0.05, 0, 6, //
    0.08, 0.85, 0.05, 0, 4, //
    0.05, 0.1, 0.7, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  /// 現代の写真: 色を半分ほど抜いて、少し温かく
  static const _printModern = <double>[
    0.6, 0.35, 0.1, 0, 10, //
    0.25, 0.65, 0.1, 0, 6, //
    0.2, 0.3, 0.45, 0, 0, //
    0, 0, 0, 1, 0,
  ];
}

/// 1950年代のテレビ風（色はそのまま。少しぼやけ・走査線・ちらつき・流れる明るい帯・丸い角と周辺の暗さ）
class _OldTv extends StatelessWidget {
  const _OldTv({required this.t, required this.child});

  /// 0〜1（くり返し）
  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // ちらつき: 速さのちがう波を重ねて、不規則に
    final flicker = (math.sin(t * math.pi * 2 * 37) + math.sin(t * math.pi * 2 * 61) * 0.6) * 0.5;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(imageFilter: ImageFilter.blur(sigmaX: 0.9, sigmaY: 0.9), child: child),
          // 明るさのちらつき
          ColoredBox(color: Colors.white.withValues(alpha: (0.03 + flicker * 0.025).clamp(0, 0.08))),
          // ゆっくり上から下へ流れる明るい帯
          Align(
            alignment: Alignment(0, -1.4 + t * 2.8),
            child: FractionallySizedBox(
              heightFactor: 0.18,
              widthFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.white.withValues(alpha: 0.09), Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          // 走査線
          const CustomPaint(painter: _ScanLines()),
          // ブラウン管の周辺の暗さ
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(radius: 0.85, colors: [Colors.transparent, Color(0x99000000)], stops: [0.55, 1]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanLines extends CustomPainter {
  const _ScanLines();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black.withValues(alpha: 0.22);
    for (var y = 0.0; y < size.height; y += 3) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, 1.2), p);
    }
  }

  @override
  bool shouldRepaint(_ScanLines old) => false;
}
