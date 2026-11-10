import 'package:flutter/material.dart';

/// アプリの色はこの1セットだけ（反転版: 暗い地に明るい文字）。
/// 色は「役割」で名前を付けている。明暗を入れ替える時はここの値だけ変えればよい。
class AppColors {
  // --- 元になる色 ---
  /// オニキス（灰みの黒）
  static const _onyx = Color(0xFF353839);

  /// 少し暗めの白
  static const _offWhite = Color(0xFFF1EFEA);

  // --- 役割 ---
  /// 文字・輪郭・ずらした影
  static const ink = _offWhite;

  /// カード・ボタンの面
  static const surface = _onyx;

  /// 背景（カードより少し暗いオニキス）
  static const paperTop = Color(0xFF2B2E2F);
  static const paperBottom = Color(0xFF202324);

  /// スマホ幅の外側（PC表示時）
  static const frame = Color(0xFF141617);

  /// ネイビー: 塗りつぶし（はじめるボタン・ロゴの円・選んだ選択肢）
  static const navy = Color(0xFF1F3A68);
  static const navyDeep = Color(0xFF12264A);

  /// ネイビーの上に置く文字・アイコン（明暗を反転しても常に明るい）
  static const onNavy = _offWhite;

  /// ホーム画面の差し色（Lv・EXPバー・新着の点・イベントの点）
  static const red = Color(0xFFE0322B);

  /// 経験値バーの緑と、その数字の明るい緑
  static const xpGreen = Color(0xFF3FBF7F);
  static const xpGreenLight = Color(0xFF8FE3B4);

  /// 暗い地の上で読める明るいネイビー（文字・細い線・メーター）
  static const accent = Color(0xFF8DA6D4);

  static const muted = Color(0xFFA29F98);
  static const line = Color(0xFF55595B);
  static const bodyText = Color(0xFFC9C6BF);

  /// 控えめなボタン（記録・図鑑）
  static const quietFace = Color(0xFF2E3132);
  static const quietEdge = Color(0xFF5C6061);
  static const quietContent = Color(0xFF8E8B85);
}

/// ボタン1つ分の色
class ButtonColors {
  const ButtonColors(this.face, this.edge, {this.border, this.content = AppColors.ink});

  /// 上の面
  final Color face;

  /// 下の厚み
  final Color edge;

  /// 輪郭線（null なら線なし）
  final Color? border;

  /// アイコン・文字の色
  final Color content;
}

/// 画面で使う色の組み合わせ（1種類のみ）。
class Palette {
  const Palette._();

  static const main = Palette._();

  LinearGradient get background => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.paperTop, AppColors.paperBottom],
  );

  Color get text => AppColors.ink;
  Color get subText => AppColors.muted;
  Color get accent => AppColors.accent;

  /// カード・リスト・ボタンの基本
  ButtonColors get card => const ButtonColors(AppColors.surface, AppColors.ink, border: AppColors.ink);

  /// メインのボタン（はじめる）
  ButtonColors get primary =>
      const ButtonColors(AppColors.navy, AppColors.ink, border: AppColors.ink, content: AppColors.onNavy);

  /// よく使うボタン（お知らせ・ミッション）
  ButtonColors get button => card;

  /// 控えめなボタン（記録・図鑑）
  ButtonColors get quiet => const ButtonColors(
    AppColors.quietFace,
    AppColors.quietEdge,
    border: AppColors.quietEdge,
    content: AppColors.quietContent,
  );

  /// レベルメーター
  Color get meter => AppColors.accent;
  Color get meterTrack => AppColors.surface;
}

/// 明朝体（Noto Serif JP。アプリに同梱、太さは 600 と 800）
TextStyle serif(double size, {FontWeight weight = FontWeight.w600, Color color = AppColors.ink}) =>
    TextStyle(fontFamily: 'NotoSerifJP', fontSize: size, fontWeight: weight, color: color, height: 1.6);

TextStyle sans(
  double size, {
  Color color = AppColors.ink,
  double height = 1.5,
  double spacing = 0,
  FontWeight weight = FontWeight.w400,
}) => TextStyle(
  fontFamily: 'NotoSansJP',
  fontSize: size,
  color: color,
  height: height,
  letterSpacing: spacing,
  fontWeight: weight,
);

ThemeData buildTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.paperTop,
  colorScheme: const ColorScheme.dark(primary: AppColors.accent, surface: AppColors.paperTop, onSurface: AppColors.ink),
  // ゴシック体（Noto Sans JP。アプリに同梱、太さは 400・700・800）
  fontFamily: 'NotoSansJP',
  splashFactory: NoSplash.splashFactory,
  // 画面の切りかえは、右からのスライドではなく、ふわっとズーム（どの端末でも同じ）
  pageTransitionsTheme: PageTransitionsTheme(
    builders: {for (final p in TargetPlatform.values) p: const ZoomPageTransitionsBuilder()},
  ),
);
