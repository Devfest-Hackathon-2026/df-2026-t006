import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/quotes.dart';
import '../data/topics.dart';
import '../models/think_card.dart';

/// テーマ一覧。今はローカルの定数、後でFirestoreに差し替える。
final topicsProvider = Provider<List<Topic>>((ref) => allTopics);

/// IDからテーマを1つ取得（見つからなければ null）
final topicProvider = Provider.family<Topic?, String>((ref, id) {
  for (final t in ref.watch(topicsProvider)) {
    if (t.id == id) return t;
  }
  return null;
});

/// 1セッション（1テーマ分）の進行状況。
class SessionState {
  const SessionState({this.index = 0, this.choices = const {}, this.answers = const {}, this.stances = const {}});

  /// 今いるカードの位置（カード数と同じなら終了画面）
  final int index;

  /// カード番号 → 選んだ選択肢の番号
  final Map<int, int> choices;

  /// カード番号 → 書いた答え
  final Map<int, String> answers;

  /// カード番号 → 反論を読んだ後の答え（stanceOptions の番号）
  final Map<int, int> stances;

  SessionState copyWith({int? index, Map<int, int>? choices, Map<int, String>? answers, Map<int, int>? stances}) =>
      SessionState(
        index: index ?? this.index,
        choices: choices ?? this.choices,
        answers: answers ?? this.answers,
        stances: stances ?? this.stances,
      );
}

class SessionNotifier extends Notifier<SessionState> {
  SessionNotifier(this.topicId);

  final String topicId;

  /// 確認用: --dart-define=START_CARD=7 で、途中のカードから始める（選択はすべて済み扱い）
  static const _startCard = int.fromEnvironment('START_CARD');

  @override
  SessionState build() {
    if (_startCard == 0) return const SessionState();
    final cards = ref.read(topicProvider(topicId))?.cards.length ?? 1;
    final start = _startCard.clamp(0, cards - 1);
    return SessionState(
      index: start,
      choices: {for (var i = 0; i < start; i++) i: 0},
      stances: {for (var i = 0; i < start; i++) i: 0},
    );
  }

  void goTo(int index) => state = state.copyWith(index: index);

  void choose(int card, int choice) => state = state.copyWith(choices: {...state.choices, card: choice});

  /// 選んだ答えを取り消す（反論を読んで「考えを変える」時）
  void unchoose(int card) => state = state.copyWith(choices: {...state.choices}..remove(card));

  /// 反論への答え。null で取り消し
  void setStance(int card, int? stance) => state = state.copyWith(
    stances: stance == null ? ({...state.stances}..remove(card)) : {...state.stances, card: stance},
  );

  void setAnswer(int card, String text) => state = state.copyWith(answers: {...state.answers, card: text});

  void reset() => state = const SessionState();
}

/// テーマごとのセッション状態。画面を離れても保持される（途中から再開できる）。
final sessionProvider = NotifierProvider.family<SessionNotifier, SessionState, String>(SessionNotifier.new);

/// 最後まで考えたテーマのID
class CompletedTopics extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void complete(String id) => state = {...state, id};

  void restore(Set<String> ids) => state = ids;
}

final completedTopicsProvider = NotifierProvider<CompletedTopics, Set<String>>(CompletedTopics.new);

/// プレイヤー情報。クラウド（Firestore）への保存は services/cloud.dart
class PlayerState {
  const PlayerState({this.name = 'ゲスト', this.xp = 0});

  static const xpPerLevel = 300;

  final String name;
  final int xp;

  int get level => xp ~/ xpPerLevel + 1;

  /// 今のレベル内での経験値
  int get xpInLevel => xp % xpPerLevel;

  double get levelProgress => xpInLevel / xpPerLevel;
}

class PlayerNotifier extends Notifier<PlayerState> {
  /// 1テーマ考えきったらもらえる経験値
  static const xpPerTopic = 100;

  /// 見た目確認用: `--dart-define=START_XP=420` で経験値を入れた状態から始める
  static const _startXp = int.fromEnvironment('START_XP');

  @override
  PlayerState build() => const PlayerState(xp: _startXp);

  void addXp(int amount) => state = PlayerState(name: state.name, xp: state.xp + amount);

  void restore(PlayerState p) => state = p;
}

final playerProvider = NotifierProvider<PlayerNotifier, PlayerState>(PlayerNotifier.new);

/// 設定
class Settings {
  const Settings({this.lockSeconds = 6, this.quoteLanguage = QuoteLanguage.ja});

  /// 各カードで考える時間（秒）
  final int lockSeconds;

  /// ホームの帯に流れる名言の言語
  final QuoteLanguage quoteLanguage;

  Settings copyWith({int? lockSeconds, QuoteLanguage? quoteLanguage}) =>
      Settings(lockSeconds: lockSeconds ?? this.lockSeconds, quoteLanguage: quoteLanguage ?? this.quoteLanguage);
}

class SettingsNotifier extends Notifier<Settings> {
  @override
  Settings build() => const Settings();

  void setLockSeconds(int s) => state = state.copyWith(lockSeconds: s);

  void setQuoteLanguage(QuoteLanguage l) => state = state.copyWith(quoteLanguage: l);
}

final settingsProvider = NotifierProvider<SettingsNotifier, Settings>(SettingsNotifier.new);
