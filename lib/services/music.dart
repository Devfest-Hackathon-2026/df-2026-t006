import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// BGM の曲（画面ごとに変わる。どの画面でどれかは [BgmTrack.forPath]）
enum BgmTrack {
  /// ホームなど、ふだんの画面（「The Stone Library」）
  home('audio/home.m4a'),

  /// ボス選び・ボス戦（「The Final Deduction」）
  battle('audio/battle.m4a'),

  /// リール（考える画面）（「Archive of Stillness」）
  reel('audio/reel.m4a'),

  /// ひたちゃんの画面（「Fiddles in the Clover」）
  hitachan('audio/hitachan.m4a');

  const BgmTrack(this.asset);

  final String asset;

  /// 画面のパスから曲を決める
  static BgmTrack forPath(String path) {
    if (path.startsWith('/hitachan')) return hitachan;
    if (path == '/topics/battle' || RegExp(r'^/topics/[^/]+/boss').hasMatch(path)) return battle;
    if (RegExp(r'^/topics/[^/]+/?$').hasMatch(path)) return reel;
    return home;
  }
}

/// BGM（曲をくり返し流す。画面によって曲をクロスフェードで切り替える）。
///   - ブラウザは、ユーザーが一度タップするまで音を出せないので、ローディング画面を押した時に始める
///   - ふわっと音量を上げて始める。タブを隠したら止め、戻ったら再開
///   - 画面が変わると、その画面の曲へクロスフェード（どの曲も続きから。router.dart で画面を見ている）
///   - 音量は設定で変えられる（0 でオフ。Firestore に保存）
class Bgm {
  Bgm._();

  /// 音量（0〜1）。初めは、考えるじゃまにならないよう控えめ
  static double _volume = defaultVolume;

  /// はじめの音量（スライダーの値）。考えるじゃまにならないよう控えめ
  static const defaultVolume = 0.3;

  /// スライダーの値 → 実際の音の大きさ。
  /// 人の耳は音の大きさを「倍々」で感じるので、そのまま比例させると 1〜100 でほとんど変わらない。そこで3乗する。
  /// ただし小さい方が静かすぎないよう、スライダーの 1 を、3乗のカーブの 20 の位置から始め、
  /// 大きい方はうるさすぎないよう、スライダーの 100 を、3乗のカーブの 85 の位置までにする（0 だけは消音）
  static double get _gain {
    if (_volume == 0) return 0;
    const low = 0.2, high = 0.2 + 0.8 * 0.85;
    final x = low + (high - low) * _volume;
    return x * x * x;
  }

  /// 曲ごとのプレイヤー（切り替えても、それぞれ続きから流れる）
  static final _players = {for (final t in BgmTrack.values) t: AudioPlayer(playerId: 'bgm_${t.name}')};

  /// 曲の読み込み（1曲につき1回だけ。読み込んだ後は resume で続きから）
  static final _ready = <BgmTrack, Future<void>>{};

  /// 切り替えの速さ（前の曲を下げながら、次の曲を上げる）
  static const _crossfade = Duration(milliseconds: 800);

  /// いま流す曲
  static BgmTrack _current = BgmTrack.home;

  static bool _started = false;
  static final _fades = <AudioPlayer, Timer>{};

  /// 下げて止める途中のプレイヤー
  static final _stopping = <AudioPlayer>{};
  static AppLifecycleListener? _life;

  static AudioPlayer get _player => _players[_current]!;

  /// 最初のタップの時に呼ぶ（音量 0 なら何もしない）
  static Future<void> start() async {
    if (_started || _volume == 0) return;
    _started = true;
    try {
      await _fadeIn(_current, const Duration(seconds: 3));
      // ほかの画面の曲も、裏で読み込んでおく（切り替えた時に、すぐ鳴るように）。
      // 一度に全部読むとスマホが重くなるので、少し待ってから1曲ずつ
      unawaited(_prepareRest());
      // タブを隠したら止め、戻ったら再開
      _life ??= AppLifecycleListener(onHide: _pauseAll, onShow: _resume, onResume: _resume);
      // スマホのブラウザは、ほかのタブから戻った時に、タップするまで音を出させないことがある。
      // その時は、次に画面をタップした時に続きから鳴らす
      GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
    } catch (e) {
      _started = false;
      debugPrint('BGM を再生できませんでした: $e');
    }
  }

  /// 止まっていたら、今の画面の曲を続きから鳴らす（タブに戻った時・タップした時）
  static void _resume() {
    if (!_started || _volume == 0) return;
    // 念のため: 今の曲以外が鳴っていたら止める
    _silenceOthers(const Duration(milliseconds: 400));
    final p = _player;
    if (p.state == PlayerState.playing) return;
    _fadeIn(_current, const Duration(milliseconds: 400)).catchError((Object e) {
      debugPrint('BGM を再開できませんでした: $e');
    });
  }

  static void _onPointer(PointerEvent e) {
    if (e is PointerUpEvent) _resume();
  }

  /// 曲を切り替える（次の曲が鳴り始めてから、前の曲を下げる。間に無音ができないように）
  static Future<void> switchTo(BgmTrack track) async {
    if (track == _current) return;
    _current = track;
    // まだ鳴らしていない・音量 0: 曲を覚えておくだけ（鳴らし始める時に、この曲から）
    if (!_started || _volume == 0) return;
    try {
      await _fadeIn(track, _crossfade);
    } catch (e) {
      debugPrint('BGM を切り替えられませんでした: $e');
    }
    // 今の曲以外を下げて止める（すばやく画面を行き来した時も、鳴るのは今の曲だけ）
    for (final MapEntry(key: t, value: p) in _players.entries) {
      if (t != _current && p.state == PlayerState.playing) _fadeTo(p, 0, _crossfade, then: p.pause);
    }
  }

  /// 今の曲以外を、1曲ずつ間をあけて読み込む（起動直後の画面の動きをじゃましないように）
  static Future<void> _prepareRest() async {
    await Future<void>.delayed(const Duration(seconds: 6));
    for (final t in BgmTrack.values) {
      if (_ready.containsKey(t)) continue;
      try {
        await _prepare(t);
      } catch (_) {
        _ready.remove(t);
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  /// 曲を読み込む（くり返し再生。読み込みは1曲につき1回）
  static Future<void> _prepare(BgmTrack track) => _ready.putIfAbsent(track, () async {
    final p = _players[track]!;
    await p.setReleaseMode(ReleaseMode.loop);
    await p.setSource(AssetSource(track.asset));
  });

  /// [track] を音量 0 から鳴らして、ふわっと上げる
  static Future<void> _fadeIn(BgmTrack track, Duration over) async {
    final p = _players[track]!;
    try {
      await _prepare(track);
    } catch (e) {
      // 曲を読みこめない時: ホームの曲で代わりに
      _ready.remove(track);
      if (track == BgmTrack.home) rethrow;
      debugPrint('BGM（${track.name}）を読みこめないので、ホームの曲にします: $e');
      _current = BgmTrack.home;
      return _fadeIn(BgmTrack.home, over);
    }
    // 読み込みの間に、もう別の画面へ移っていたら鳴らさない。
    // ※ 先に確かめる（先に下げている途中のフェードを止めてしまうと、その曲が止まらず鳴り続ける）
    if (track != _current) return;
    _fades.remove(p)?.cancel();
    _stopping.remove(p);
    // 止まっていた時だけ、音量 0 から上げる（下げている途中なら、今の音量から戻す）
    if (p.state != PlayerState.playing) await p.setVolume(0);
    await p.resume();
    _fadeTo(p, _gain, over);
    // 鳴らしている間に、別の曲が鳴り出していたら止める（鳴るのは、いつも今の曲だけ）
    _silenceOthers(over);
  }

  /// 今の曲以外で鳴っている曲を、下げて止める
  static void _silenceOthers(Duration over) {
    for (final MapEntry(key: t, value: p) in _players.entries) {
      if (t == _current) continue;
      // すでに下げて止める途中なら、そのまま
      if (p.state == PlayerState.playing && !_stopping.contains(p)) _fadeTo(p, 0, over, then: p.pause);
    }
  }

  /// 全部の曲を止める（音量 0・タブを隠した時）
  static void _pauseAll() {
    for (final p in _players.values) {
      _fades.remove(p)?.cancel();
      _stopping.remove(p);
      if (p.state == PlayerState.playing) p.pause();
    }
  }

  /// 音量を変える（0 で止める）
  static Future<void> setVolume(double v) async {
    final was = _volume;
    _volume = v.clamp(0, 1);
    if (!_started) {
      // まだ鳴らしていない（読み込み中など）: タップ後に、この音量で始まる
      return;
    }
    final p = _player;
    if (_volume == 0) {
      // オフ: 鳴っている曲は全部止める（今の画面の曲以外が残っていても）
      _fadeTo(p, 0, const Duration(milliseconds: 300), then: _pauseAll);
    } else if (was == 0) {
      // オフから戻した: 今の画面の曲を鳴らす
      await _fadeIn(_current, const Duration(milliseconds: 300));
    } else {
      _fades.remove(p)?.cancel();
      await p.setVolume(_gain);
      _silenceOthers(const Duration(milliseconds: 300));
    }
  }

  /// 読み込んだ設定を入れる（まだ鳴らしていないので、音は触らない）
  static void restoreVolume(double v) => _volume = v.clamp(0, 1);

  static void _fadeTo(AudioPlayer p, double target, Duration over, {VoidCallback? then}) {
    // 同じプレイヤーの前のフェードは止める（止めたフェードの then は呼ばない）
    _fades.remove(p)?.cancel();
    _stopping.remove(p);
    if (target == 0 && then != null) _stopping.add(p);
    const steps = 20;
    var i = 0;
    final from = p.volume;
    _fades[p] = Timer.periodic(over ~/ steps, (t) {
      i++;
      p.setVolume(from + (target - from) * (i / steps));
      if (i >= steps) {
        t.cancel();
        _fades.remove(p);
        _stopping.remove(p);
        then?.call();
      }
    });
  }
}

/// 効果音（ボタンを押した時の「コッ」）。自作の短い音（assets/audio/click.wav）
class Sfx {
  Sfx._();

  static const _click = 'audio/click.wav';

  /// 音量（0〜1）。0 で鳴らさない
  static double volume = 0.6;

  /// 連打しても音が途切れないように、いくつかを順番に使う
  static final _pool = [for (var i = 0; i < 4; i++) AudioPlayer(playerId: 'sfx$i')];
  static int _next = 0;
  static DateTime _last = DateTime(2000);

  /// ボタンを押した音
  static void tap() {
    if (volume == 0) return;
    // ほぼ同時に何度も呼ばれた時（入れ子のボタンなど）は1回だけ
    final now = DateTime.now();
    if (now.difference(_last).inMilliseconds < 40) return;
    _last = now;
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    p.stop().then((_) => p.play(AssetSource(_click), volume: volume)).catchError((Object _) {});
  }
}

/// 音の設定（BGM・効果音の音量）
class SoundSettings {
  const SoundSettings({this.bgm = Bgm.defaultVolume, this.sfx = 0.6});

  final double bgm;
  final double sfx;
}

class SoundNotifier extends Notifier<SoundSettings> {
  @override
  SoundSettings build() => const SoundSettings();

  void setBgm(double v) {
    state = SoundSettings(bgm: v, sfx: state.sfx);
    Bgm.setVolume(v);
  }

  void setSfx(double v) {
    state = SoundSettings(bgm: state.bgm, sfx: v);
    Sfx.volume = v;
  }

  /// クラウドから読み込んだ設定（まだ鳴らしていないので、BGM は触らない）
  void restore(SoundSettings s) {
    state = s;
    Bgm.restoreVolume(s.bgm);
    Sfx.volume = s.sfx;
  }
}

final soundProvider = NotifierProvider<SoundNotifier, SoundSettings>(SoundNotifier.new);
