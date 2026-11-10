import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'baked_image.dart';

/// ホームの背景に流す1枚
class _Slide {
  const _Slide(this.asset, this.alignment);

  final String asset;

  /// 画面に収まりきらない時、どこを中心に見せるか
  final Alignment alignment;
}

/// ホームの背景: 古代エジプトの石版画（David Roberts『Egypt and Nubia』, CC0）。
/// [interval] ごとにフェードで切り替わり、表示中はゆっくりズームする。
/// 出典は ../docs/著作物利用シート.md
///
/// 画像の上下をオニキスに溶かし、上のステータスと下のボタンが読めるようにしている。
class HomeBackdrop extends StatefulWidget {
  const HomeBackdrop({super.key, this.interval = const Duration(seconds: 5)});

  final Duration interval;

  static const _slides = [
    _Slide('assets/home/sphinx.jpg', Alignment(-0.04, 0)), // スフィンクスとピラミッド
    _Slide('assets/home/karnak.jpg', Alignment(0, -0.2)), // カルナック神殿の大列柱
    _Slide('assets/home/gyrshe.jpg', Alignment(-0.2, -0.3)), // ゲルフ・フセインの巨像
    _Slide('assets/home/esneh.jpg', Alignment(0.1, 0)), // エスナ神殿
  ];

  /// コントラストを上げて少し暗くする（石の彫りを強調）
  static const _dramatic = ColorFilter.matrix(<double>[
    1.35, 0, 0, 0, -70, //
    0, 1.35, 0, 0, -72, //
    0, 0, 1.35, 0, -76, //
    0, 0, 0, 1, 0,
  ]);

  @override
  State<HomeBackdrop> createState() => _HomeBackdropState();
}

class _HomeBackdropState extends State<HomeBackdrop> {
  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) {
      setState(() => _index = (_index + 1) % HomeBackdrop._slides.length);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 切り替えの瞬間にちらつかないよう、全部先に読み込んでおく
    for (final s in HomeBackdrop._slides) {
      precacheImage(AssetImage(s.asset), context);
      BakedImage.bake(s.asset, HomeBackdrop._dramatic);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = HomeBackdrop._slides[_index];

    // 画像の上端・下端の位置での背景色（ここへ溶かすと継ぎ目が出ない）
    // 画像を置く位置（画面の高さに対する割合）。上に少し はみ出させて、絵を上寄りに見せる
    const topFrac = 0.04;
    const heightFrac = 0.72;

    // 画像の上端・下端の位置での背景色（ここへ溶かすと継ぎ目が出ない）。位置から計算するので、動かしてもずれない
    final topColor = Color.lerp(AppColors.paperTop, AppColors.paperBottom, topFrac.clamp(0, 1))!;
    final bottomColor = Color.lerp(AppColors.paperTop, AppColors.paperBottom, topFrac + heightFrac)!;

    return LayoutBuilder(
      builder: (context, c) {
        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              // 少し上に寄せて、スタートボタン（テツル）と重なりすぎないようにする
              top: c.maxHeight * topFrac,
              height: c.maxHeight * heightFrac,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 画像は上下を2pxずつ内側に。上に重ねるグラデーションが必ず画像の端より外まで覆うようにして、
                  // 端の1ピクセルが光って見えるのを防ぐ
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: ClipRect(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 1800),
                        switchInCurve: Curves.easeInOut,
                        switchOutCurve: Curves.easeInOut,
                        layoutBuilder: (current, previous) =>
                            Stack(fit: StackFit.expand, children: [...previous, ?current]),
                        child: TweenAnimationBuilder<double>(
                          key: ValueKey(_index),
                          tween: Tween(begin: 1.0, end: 1.06),
                          // フェードの時間ぶん長めにし、切り替わる間もズームが止まらないようにする
                          duration: widget.interval + const Duration(seconds: 2),
                          builder: (context, scale, child) => Transform.scale(
                            scale: scale,
                            // 画像として滑らかに拡大する（ピクセル単位で揺れて見えるのを防ぐ）
                            filterQuality: FilterQuality.medium,
                            child: child,
                          ),
                          // 色を変えた絵は1回だけ作って使い回す（ズーム中に毎フレームかけ直さない）
                          child: RepaintBoundary(
                            child: BakedImage(slide.asset, filter: HomeBackdrop._dramatic, alignment: slide.alignment),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 上下を背景色へ溶かす（グラデーションを上に重ねる方式。拡大表示でも崩れない）
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            topColor,
                            topColor.withValues(alpha: 0),
                            bottomColor.withValues(alpha: 0),
                            bottomColor,
                          ],
                          stops: const [0.0, 0.24, 0.62, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 全体を少しだけ沈める（文字の可読性のため）
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(decoration: BoxDecoration(color: AppColors.paperBottom.withValues(alpha: 0.18))),
              ),
            ),
          ],
        );
      },
    );
  }
}
