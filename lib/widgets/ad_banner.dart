import 'package:flutter/material.dart';

import '../theme.dart';

/// 広告枠（仮）。標準バナーサイズ（高さ50）。
///
/// TODO: 本番では Google AdMob（google_mobile_ads パッケージ）のバナー広告に差し替える。
///   - 「Ads by Google」の表示や、✕で閉じた後の「広告を閉じました」画面は AdMob 側が描くので、
///     ここでは Google のロゴや文言はまねせず、場所と動きだけを仮に作っている。
///   - AdMob アカウントの作成と広告ユニットID（テスト用ID）が必要。
///     ../docs/著作物利用シート.md にも記載。
class AdBanner extends StatefulWidget {
  const AdBanner({super.key});

  /// 標準バナーの高さ
  static const height = 50.0;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  bool _closed = false;

  static const _paper = Color(0xFFF1EFEA);
  static const _ink = Color(0xFF1D1F20);
  static const _muted = Color(0xFF6E6C67);

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: _closed ? _closedPanel() : _ad());
  }

  /// 広告（仮）
  Widget _ad() {
    return Container(
      key: const ValueKey('ad'),
      height: AdBanner.height,
      decoration: BoxDecoration(
        color: _paper,
        border: Border.all(color: const Color(0xFFCFCBC2)),
      ),
      child: Stack(
        children: [
          Center(
            child: Text(
              '広告スペース（準備中）',
              style: sans(12, weight: FontWeight.w700, color: _muted),
            ),
          ),
          // 左上: 広告であることの表示
          Positioned(
            left: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              color: const Color(0xFFE0DCD3),
              child: Text(
                '広告',
                style: sans(9, weight: FontWeight.w800, color: _muted, height: 1.2),
              ),
            ),
          ),
          // 右上: ⓘ と ✕
          Positioned(
            right: 2,
            top: 2,
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 13, color: _muted),
                const SizedBox(width: 4),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _closed = true),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close_rounded, size: 14, color: _muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// ✕で閉じた後の画面（仮）
  Widget _closedPanel() {
    Widget option(String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFCFCBC2)),
      ),
      child: Text(
        text,
        style: sans(10, weight: FontWeight.w700, color: _ink, height: 1.2),
      ),
    );

    return Container(
      key: const ValueKey('closed'),
      height: AdBanner.height,
      color: _paper,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          Text(
            '広告を閉じました',
            style: sans(11, weight: FontWeight.w800, color: _ink),
          ),
          const Spacer(),
          option('この広告を表示しない'),
          const SizedBox(width: 6),
          option('表示の理由'),
        ],
      ),
    );
  }
}
