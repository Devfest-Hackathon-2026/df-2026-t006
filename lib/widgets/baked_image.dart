import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 色フィルター（と、ぼかし）を、画像に「1回だけ」かけて覚えておく画像。
///
/// ColorFiltered や ImageFiltered は、画面が動くたび（毎フレーム）にかけ直しになり、
/// スマホでは重い（ズームする背景・浮き沈みするロゴなど）。
/// ここでは、最初に1回だけフィルターをかけた画像を作って使い回すので、動かしても軽い。
/// 作り終わるまでの一瞬は、ふつうの ColorFiltered で表示する（ぼかしつきは何も出さない）。
class BakedImage extends StatefulWidget {
  const BakedImage(
    this.asset, {
    super.key,
    required this.filter,
    this.blur = 0,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.width,
    this.height,
  });

  final String asset;
  final ColorFilter filter;

  /// ぼかしの強さ（元の画像のピクセルで）。ぼかすと、まわりに [padFor] ずつ余白がつく
  final double blur;

  final BoxFit fit;
  final AlignmentGeometry alignment;
  final double? width;
  final double? height;

  /// ぼかしがはみ出す分の余白（元の画像のピクセルで）
  static double padFor(double blur) => (blur * 3).ceilToDouble();

  static final _jobs = <(String, ColorFilter, double), Future<ui.Image>>{};
  static final _done = <(String, ColorFilter, double), ui.Image>{};

  /// 先に作っておく（画面に出る前に）
  static Future<ui.Image> bake(String asset, ColorFilter filter, {double blur = 0}) {
    final key = (asset, filter, blur);
    return _jobs.putIfAbsent(key, () async {
      final data = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final src = (await codec.getNextFrame()).image;
      final pad = padFor(blur);
      final rec = ui.PictureRecorder();
      final paint = Paint()
        ..colorFilter = filter
        ..filterQuality = FilterQuality.medium;
      if (blur > 0) paint.imageFilter = ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur);
      Canvas(rec).drawImage(src, Offset(pad, pad), paint);
      final out = await rec.endRecording().toImage(src.width + 2 * pad.toInt(), src.height + 2 * pad.toInt());
      src.dispose();
      return _done[key] = out;
    });
  }

  @override
  State<BakedImage> createState() => _BakedImageState();
}

class _BakedImageState extends State<BakedImage> {
  ui.Image? _img;

  (String, ColorFilter, double) get _key => (widget.asset, widget.filter, widget.blur);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(BakedImage old) {
    super.didUpdateWidget(old);
    if (old.asset != widget.asset || old.filter != widget.filter || old.blur != widget.blur) _load();
  }

  void _load() {
    final key = _key;
    _img = BakedImage._done[key];
    if (_img != null) return;
    BakedImage.bake(widget.asset, widget.filter, blur: widget.blur).then((img) {
      if (mounted && _key == key) setState(() => _img = img);
    }, onError: (Object e) => debugPrint('画像を作れませんでした（${widget.asset}）: $e'));
  }

  @override
  Widget build(BuildContext context) {
    final img = _img;
    if (img == null) {
      if (widget.blur > 0) return SizedBox(width: widget.width, height: widget.height);
      return ColorFiltered(
        colorFilter: widget.filter,
        child: Image.asset(
          widget.asset,
          fit: widget.fit,
          alignment: widget.alignment,
          width: widget.width,
          height: widget.height,
          filterQuality: FilterQuality.medium,
        ),
      );
    }
    return RawImage(
      image: img,
      fit: widget.fit,
      alignment: widget.alignment,
      width: widget.width,
      height: widget.height,
      filterQuality: FilterQuality.medium,
    );
  }
}
