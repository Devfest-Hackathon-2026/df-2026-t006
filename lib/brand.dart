import 'package:flutter/material.dart';

/// アプリ名
const appName = 'ひたテツ';

/// スローガン
const slogan = '知識を永遠に';

/// ロゴを置く黒。ロゴ画像の黒地も [LogoImage] で真っ黒に寄せるので、継ぎ目が出ない
const logoBlack = Color(0xFF000000);

/// ロゴ画像（チーム制作。../docs/著作物利用シート.md）
class LogoAsset {
  /// 脳と∞ + 「ひたテツ」
  static const full = 'assets/brand/logo.png';

  /// 脳と∞だけ（文字なし）
  static const mark = 'assets/brand/mark.png';
}

/// 黒地の上にロゴ画像を継ぎ目なく置く。
/// 画像の黒地は場所によって少しムラ（#020202〜#0C0C0C）があるので、
/// 全体を少し暗くして真っ黒に寄せ、さらに端をぼかして周りの黒になじませる。
class LogoImage extends StatelessWidget {
  const LogoImage(this.asset, {super.key, required this.width, this.height});

  final String asset;
  final double width;
  final double? height;

  static const _toPureBlack = ColorFilter.matrix(<double>[
    1.06, 0, 0, 0, -14, //
    0, 1.06, 0, 0, -14, //
    0, 0, 1.06, 0, -14, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => const RadialGradient(
        radius: 0.72,
        colors: [Colors.black, Colors.black, Colors.transparent],
        stops: [0.0, 0.8, 1.0],
      ).createShader(rect),
      child: ColorFiltered(
        colorFilter: _toPureBlack,
        child: Image.asset(asset, width: width, height: height, filterQuality: FilterQuality.medium),
      ),
    );
  }
}
