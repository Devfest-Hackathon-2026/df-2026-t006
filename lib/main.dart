import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';
import 'widgets/mission_toast.dart';
import 'widgets/phone_frame.dart';
import 'widgets/revisit.dart';

void main() {
  // 同梱フォントのライセンス（SIL OFL）を「オープンソースのライセンス」画面にも出す
  LicenseRegistry.addLicense(() async* {
    for (final (name, file) in [
      ('Noto Sans JP', 'NotoSansJP-OFL.txt'),
      ('Noto Serif JP', 'NotoSerifJP-OFL.txt'),
      ('Dela Gothic One', 'DelaGothicOne-OFL.txt'),
      ('DotGothic16', 'DotGothic16-OFL.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([name], await rootBundle.loadString('assets/fonts/$file'));
    }
  });
  // 画面ごとの BGM（ホーム・リール・ボス戦・ひたちゃん）
  followRouteWithBgm();
  runApp(const ProviderScope(child: TetsugakuApp()));
}

class TetsugakuApp extends StatelessWidget {
  const TetsugakuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ひたテツ',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: appRouter,
      // どの画面も、指・マウス・トラックパッド・ペンのどれでも、上下どちらにもドラッグでスクロールできる
      scrollBehavior: const _AnyDeviceScroll(),
      // ミッションの通知を、どの画面の上にも出す
      // 少し前に答えた問いを「もう一度考えてみる？」と出す（widgets/revisit.dart）
      // PC では、アプリ全体（ダイアログ・通知も）をスマホの形の枠に収める
      builder: (context, child) => AppFrame(
        child: MissionToastHost(child: RevisitHost(child: child ?? const SizedBox.shrink())),
      ),
    );
  }
}

class _AnyDeviceScroll extends MaterialScrollBehavior {
  const _AnyDeviceScroll();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}
