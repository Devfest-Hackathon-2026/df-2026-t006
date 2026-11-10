import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'data/topics.dart';
import 'screens/hitachan_screen.dart';
import 'screens/home_screen.dart';
import 'screens/loading_screen.dart';
import 'screens/missions_screen.dart';
import 'screens/records_screen.dart';
import 'screens/news_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/prologue_screen.dart';
import 'screens/battle_screen.dart';
import 'screens/boss_select_screen.dart';
import 'screens/credits_screen.dart';
import 'screens/reel_session.dart';
import 'screens/settings_screen.dart';
import 'screens/topic_select_screen.dart';
import 'services/boss_battle.dart';
import 'services/music.dart';
import 'widgets/gift_button.dart';
import 'widgets/portal_transition.dart';

/// 画面遷移
///   /loading             起動時のローディング
///   /                    ホーム
///   /topics              テーマ選択（右上の BATTLE → /topics/battle）
///   /topics/battle       ボス選び
///   /topics/:id/boss     ボス戦（?level=1〜3 で難しさ、?vs=0/1 で相手）
///   /topics/:id          問いのスクロール
///   /settings            設定
///   /news                お知らせ
///   /missions            ミッション
///   /prologue            プロローグ（ひたちゃんのお話）
///   /hitachan            ひたちゃん（ちびのうをあげて育てる）
///   /profile             プロフィール（思考スタイル・考え方の変化）
///   /mail                メールボックス
final appRouter = GoRouter(
  initialLocation: '/loading',
  // お知らせ・シートなどが開いているか（「もう一度考える」を重ねて出さないため）
  observers: [PopupWatcher.instance],
  // ページを再読み込みした時なども、必ずローディング画面から（Firebase のログイン・読み込みのため）
  redirect: (context, state) => !LoadingScreen.booted && state.matchedLocation != '/loading' ? '/loading' : null,
  routes: [
    GoRoute(path: '/loading', builder: (context, state) => const LoadingScreen()),
    GoRoute(
      path: '/prologue',
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const PrologueScreen(),
        // ローディング画面の暗転から、そのまま真っ暗につなぐ（暗いまま待ってからのフェードインはプロローグの中で）
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        transitionsBuilder: (context, animation, _, child) => child,
      ),
    ),
    GoRoute(
      path: '/',
      // ローディング画面からは、ふわっとフェードしてホームへ
      pageBuilder: (context, state) => CustomTransitionPage(
        key: state.pageKey,
        child: const HomeScreen(),
        transitionDuration: const Duration(milliseconds: 900),
        transitionsBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
      ),
      routes: [
        GoRoute(
          path: 'settings',
          builder: (context, state) => const SettingsScreen(),
          routes: [GoRoute(path: 'credits', builder: (context, state) => const CreditsScreen())],
        ),
        GoRoute(path: 'news', builder: (context, state) => const NewsScreen()),
        GoRoute(path: 'missions', builder: (context, state) => const MissionsScreen()),
        GoRoute(
          path: 'hitachan',
          // プロローグから来た時は、暗転からゆっくりフェードイン（それ以外はふつうに）
          pageBuilder: (context, state) => state.uri.queryParameters['from'] == 'prologue'
              ? CustomTransitionPage(
                  key: state.pageKey,
                  child: const HitachanScreen(),
                  transitionDuration: const Duration(milliseconds: 1100),
                  transitionsBuilder: (context, animation, _, child) => Stack(
                    fit: StackFit.expand,
                    children: [
                      // 下の画面（ホーム）を隠す黒。ひたちゃんの画面が出きると、その下に隠れる
                      const ColoredBox(color: Colors.black),
                      FadeTransition(
                        opacity: CurvedAnimation(
                          parent: animation,
                          curve: const Interval(0.3, 1, curve: Curves.easeOut),
                        ),
                        child: child,
                      ),
                    ],
                  ),
                )
              : const MaterialPage(child: HitachanScreen()),
        ),
        GoRoute(path: 'profile', builder: (context, state) => const ProfileScreen()),
        GoRoute(path: 'records', builder: (context, state) => const RecordsScreen()),
        GoRoute(path: 'mail', builder: (context, state) => const MailScreen()),
        GoRoute(
          path: 'topics',
          // スタートボタン（白い脳）から、渦巻くポータルに吸い込まれるように入る
          pageBuilder: (context, state) => CustomTransitionPage(
            key: state.pageKey,
            child: const TopicSelectScreen(),
            transitionDuration: const Duration(milliseconds: 1200),
            reverseTransitionDuration: const Duration(milliseconds: 500),
            transitionsBuilder: portalTransition,
          ),
          routes: [
            // ボス選び（テーマ選択の右上の BATTLE から）。テーマ選択の上に重なるので、
            // 行き帰りはスライドだけ（テーマ選択の渦巻きはくり返さない）。:id より先に書く
            GoRoute(
              path: 'battle',
              pageBuilder: (context, state) => CustomTransitionPage(
                key: state.pageKey,
                child: const BossSelectScreen(),
                transitionDuration: const Duration(milliseconds: 450),
                reverseTransitionDuration: const Duration(milliseconds: 400),
                transitionsBuilder: panTransition,
              ),
            ),
            GoRoute(
              path: ':id',
              // 存在しないテーマのURLならテーマ選択へ戻す
              redirect: (context, state) {
                final id = state.pathParameters['id'];
                return allTopics.any((t) => t.id == id) ? null : '/topics';
              },
              builder: (context, state) => ReelSession(topicId: state.pathParameters['id']!),
              routes: [
                // ボス戦（そのテーマの哲学者ボスと戦う）
                GoRoute(
                  path: 'boss',
                  builder: (context, state) => BattleScreen(
                    topicId: state.pathParameters['id']!,
                    // ?level=1〜3（ボス選びで選んだ難しさ）
                    difficulty: Difficulty.ofStars(int.tryParse(state.uri.queryParameters['level'] ?? '') ?? 2),
                    // ?vs=0 / 1（どちらの哲学者と戦うか。プレイヤーは反対の立場）
                    bossIndex: int.tryParse(state.uri.queryParameters['vs'] ?? '') ?? 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);

/// ズームの切り替え（ボス選びなど、CustomTransitionPage を使う画面もほかと同じに、ふわっと寄ってくる）
Widget panTransition(BuildContext context, Animation<double> animation, Animation<double> secondary, Widget child) {
  final a = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
  return FadeTransition(
    opacity: a,
    child: ScaleTransition(scale: Tween(begin: 0.88, end: 1.0).animate(a), child: child),
  );
}

/// 画面が変わったら、その画面の BGM へ切り替える（main.dart で1回だけ呼ぶ）
void followRouteWithBgm() {
  void update() => Bgm.switchTo(BgmTrack.forPath(appRouter.routerDelegate.currentConfiguration.uri.path));
  appRouter.routerDelegate.addListener(update);
  update();
}

/// 今開いているポップアップ（ダイアログ・下から出るシート）の数を数える
class PopupWatcher extends NavigatorObserver {
  PopupWatcher._();

  static final instance = PopupWatcher._();

  int _open = 0;

  /// ダイアログやシートが開いているか
  bool get anyOpen => _open > 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) _open++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute && _open > 0) _open--;
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute && _open > 0) _open--;
  }
}
