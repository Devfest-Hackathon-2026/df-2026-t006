import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase_options.dart';
import '../data/news.dart';
import '../state/answer_log.dart';
import 'music.dart';
import '../state/brains.dart';
import '../state/mail.dart';
import '../state/missions.dart';
import '../state/providers.dart';
import '../state/records.dart';
import '../state/revisit.dart';
import '../widgets/gift_button.dart';

/// Firebase（Google Cloud）とのつなぎ。
///
///   - 匿名ログイン: 登録なしで始められる。データはこの端末（ブラウザ）のユーザーにひもづく
///   - Firestore `users/{uid}`: 経験値・考えきったテーマ・記録・ミッション・メール（ちびのう・ログインボーナス）
///   - Firestore `users/{uid}/answers`: 答えの記録（1回答えるごとに1件。深さのスコアや分析用）
///   - Analytics: 答えの記録をイベント `answer` として送る
///
/// Firebase につながらない時（オフライン・Mac版アプリ）は、今まで通り端末の中だけで動く。
class Cloud {
  Cloud._();

  static bool _ready = false;

  /// Firebase が使える状態か
  static bool get ready => _ready;

  static String? get uid => _ready ? FirebaseAuth.instance.currentUser?.uid : null;

  static DocumentReference<Map<String, dynamic>> _user(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  /// 起動時に1回: Firebase を始めて、匿名ログインする。失敗しても止まらない
  static Future<void> init() async {
    // 今は Web 版だけ Firebase の設定がある（Mac版は見た目の確認用）
    if (!kIsWeb) return;
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      await _activateAppCheck();
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) await auth.signInAnonymously();
      _ready = true;
    } catch (e) {
      debugPrint('Firebase に接続できませんでした（端末の中だけで続けます）: $e');
    }
  }

  /// Gemini をどこ経由で使うか。
  ///   false: Gemini Developer API（AI Studio のプリペイド残高から払う）
  ///   true : Agent Platform（Vertex AI）Gemini API（Google Cloud の請求先アカウント＝クレジットから払う）
  /// Firebase コンソールの AI Logic で、使う方を「有効」にしておくこと。
  static const useCloudBilling = true;

  /// Gemini を呼ぶ入口（判定・ボス戦・哲学者の返事はすべてここから）
  static FirebaseAI get ai => useCloudBilling ? FirebaseAI.agentPlatform() : FirebaseAI.googleAI();

  /// App Check の reCAPTCHA Enterprise サイトキー（公開してよい値。秘密ではない）
  static const recaptchaSiteKey = '6Le4PRQuAAAAAOR6IYTh36er_Y--iJLB15-VO2Ea';

  /// App Check: 本物のひたテツのサイトからのリクエストだと証明する（Gemini を他人に使われないように）。
  ///   - 公開サイト: reCAPTCHA Enterprise
  ///   - localhost（開発中）: デバッグトークン。
  ///     `--dart-define=APPCHECK_DEBUG_TOKEN=...` で渡すか、渡さなければブラウザのコンソールに出るので、
  ///     Firebase コンソールの App Check →「デバッグトークンを管理」に登録する。
  ///     ※ デバッグトークンは秘密。コミットしない
  static Future<void> _activateAppCheck() async {
    final host = Uri.base.host;
    final local = host == 'localhost' || host == '127.0.0.1';
    const debugToken = String.fromEnvironment('APPCHECK_DEBUG_TOKEN');
    if (local) {
      await FirebaseAppCheck.instance.activate(
        providerWeb: WebDebugProvider(debugToken: debugToken.isEmpty ? null : debugToken),
      );
    } else if (recaptchaSiteKey.isNotEmpty) {
      await FirebaseAppCheck.instance.activate(providerWeb: ReCaptchaEnterpriseProvider(recaptchaSiteKey));
    }
  }

  /// 保存してあるデータを読み込んで、アプリの状態に入れる
  static Future<void> load(WidgetRef ref) async {
    final id = uid;
    if (id == null) return;
    try {
      final snap = await _user(id).get().timeout(const Duration(seconds: 5));
      final d = snap.data();
      if (d == null) return;
      final player = ref.read(playerProvider);
      ref
          .read(playerProvider.notifier)
          .restore(PlayerState(name: d['name'] as String? ?? player.name, xp: (d['xp'] as num?)?.toInt() ?? 0));
      ref.read(completedTopicsProvider.notifier).restore({
        ...((d['completed'] as List?) ?? const []).whereType<String>(),
      });
      ref.read(battleRecordsProvider.notifier).restore([
        for (final r in (d['battles'] as List?) ?? const [])
          if (r is Map) BattleRecord.fromJson(Map<String, dynamic>.from(r)),
      ]);
      ref.read(recordsProvider.notifier).restore([
        for (final r in (d['records'] as List?) ?? const [])
          if (r is Map) TopicRecord.fromJson(Map<String, dynamic>.from(r)),
      ]);
      if (d['missions'] case final Map m) {
        ref.read(missionProvider.notifier).restore(MissionState.fromJson(Map<String, dynamic>.from(m)));
      }
      if (d['revisit'] case final Map m) {
        ref.read(revisitProvider.notifier).restore(RevisitState.fromJson(Map<String, dynamic>.from(m)));
      }
      if (d['brains'] case final Map m) {
        ref.read(brainProvider.notifier).restore(BrainState.fromJson(Map<String, dynamic>.from(m)));
      }
      ref.read(prologueSeenProvider.notifier).set(d['prologueSeen'] == true);
      // 前から遊んでいる人（記録がある人）には、はじめの「おしてみて！」は出さない
      ref
          .read(startTappedProvider.notifier)
          .set(d['startTapped'] == true || ((d['records'] as List?)?.isNotEmpty ?? false));
      ref.read(newsSeenProvider.notifier).restore((d['newsSeen'] as num?)?.toInt() ?? 0);
      ref.read(mailProvider.notifier).restore([
        for (final m in (d['mail'] as List?) ?? const [])
          if (m is Map) Mail.fromJson(Map<String, dynamic>.from(m)),
      ]);
      ref
          .read(soundProvider.notifier)
          .restore(
            SoundSettings(
              // 前の「BGM オフ」の設定は音量 0 として読む
              bgm: (d['bgmVolume'] as num?)?.toDouble() ?? (d['musicOn'] == false ? 0 : Bgm.defaultVolume),
              sfx: (d['sfxVolume'] as num?)?.toDouble() ?? 0.6,
            ),
          );
      final gift = (d['giftClaimedAt'] as num?)?.toInt();
      ref.read(giftProvider.notifier).restore(gift == null ? null : DateTime.fromMillisecondsSinceEpoch(gift));
    } catch (e) {
      debugPrint('読み込みに失敗しました: $e');
    }
  }
}

/// 読み込みが終わってから1回 read すると、それ以降の変更を自動で保存する
final cloudSyncProvider = Provider<void>((ref) {
  final id = Cloud.uid;
  if (id == null) return;

  // 変更が続く時（EXPとミッションが同時に変わる等）は、まとめて1回だけ書く
  Timer? timer;
  void save() {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 600), () {
      final player = ref.read(playerProvider);
      Cloud._user(id)
          .set({
            'name': player.name,
            'xp': player.xp,
            'level': player.level,
            'completed': ref.read(completedTopicsProvider).toList(),
            'records': [for (final r in ref.read(recordsProvider)) r.toJson()],
            'battles': [for (final r in ref.read(battleRecordsProvider)) r.toJson()],
            'missions': ref.read(missionProvider).toJson(),
            'giftClaimedAt': ref.read(giftProvider)?.millisecondsSinceEpoch,
            'brains': ref.read(brainProvider).toJson(),
            'prologueSeen': ref.read(prologueSeenProvider),
            'startTapped': ref.read(startTappedProvider),
            'bgmVolume': ref.read(soundProvider).bgm,
            'sfxVolume': ref.read(soundProvider).sfx,
            'newsSeen': ref.read(newsSeenProvider),
            'mail': [for (final m in ref.read(mailProvider)) m.toJson()],
            'revisit': ref.read(revisitProvider).toJson(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true))
          .catchError((Object e) => debugPrint('保存に失敗しました: $e'));
    });
  }

  ref.listen(playerProvider, (_, _) => save());
  ref.listen(completedTopicsProvider, (_, _) => save());
  ref.listen(recordsProvider, (_, _) => save());
  ref.listen(battleRecordsProvider, (_, _) => save());
  ref.listen(missionProvider, (_, _) => save());
  ref.listen(giftProvider, (_, _) => save());
  ref.listen(brainProvider, (a, b) {
    if (a?.stock != b.stock || a?.fed != b.fed) save();
  });
  ref.listen(prologueSeenProvider, (_, _) => save());
  ref.listen(startTappedProvider, (_, _) => save());
  ref.listen(soundProvider, (_, _) => save());
  ref.listen(newsSeenProvider, (_, _) => save());
  ref.listen(mailProvider, (_, _) => save());
  ref.listen(revisitProvider, (_, _) => save());

  // 答えの記録: 増えた分だけ Firestore と Analytics に送る
  final analytics = FirebaseAnalytics.instance;
  ref.listen<List<AnswerEvent>>(answerLogProvider, (prev, next) {
    for (final e in next.skip(prev?.length ?? 0)) {
      final json = e.toJson();
      Cloud._user(id).collection('answers').add({...json, 'at': FieldValue.serverTimestamp()}).catchError((Object err) {
        debugPrint('答えの保存に失敗しました: $err');
        return Cloud._user(id).collection('answers').doc();
      });
      analytics
          .logEvent(
            name: 'answer',
            // Analytics には null を送れないので、値のある項目だけ
            parameters: {
              for (final kv in json.entries)
                if (kv.value != null) kv.key: kv.value is bool ? ((kv.value as bool) ? 1 : 0) : kv.value as Object,
            },
          )
          .catchError((Object _) {});
    }
  });

  ref.onDispose(() => timer?.cancel());
});
