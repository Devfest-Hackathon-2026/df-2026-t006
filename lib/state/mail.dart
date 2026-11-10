import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'brains.dart';
import 'providers.dart';

/// メール1通。ちびのう・経験値は、メールを開いて読んだ時に受け取る
class Mail {
  const Mail({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.from = 'ひたテツ',
    this.brains = 0,
    this.xp = 0,
    this.read = false,
  });

  final String id;
  final String title;
  final String body;
  final String from;
  final DateTime receivedAt;

  /// 中身（開くと受け取る）
  final int brains;
  final int xp;

  /// 読んだか（読むと灰色になる）
  final bool read;

  Mail asRead() =>
      Mail(id: id, title: title, body: body, from: from, receivedAt: receivedAt, brains: brains, xp: xp, read: true);

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'from': from,
    'at': receivedAt.millisecondsSinceEpoch,
    'brains': brains,
    'xp': xp,
    'read': read,
  };

  static Mail fromJson(Map<String, dynamic> j) => Mail(
    id: j['id'] as String? ?? '',
    title: j['title'] as String? ?? '',
    body: j['body'] as String? ?? '',
    from: j['from'] as String? ?? 'ひたテツ',
    receivedAt: DateTime.fromMillisecondsSinceEpoch((j['at'] as num?)?.toInt() ?? 0),
    brains: (j['brains'] as num?)?.toInt() ?? 0,
    xp: (j['xp'] as num?)?.toInt() ?? 0,
    read: j['read'] == true,
  );
}

/// メールボックス（新しい順）。クラウド（Firestore）への保存は services/cloud.dart
class MailNotifier extends Notifier<List<Mail>> {
  /// 残しておくメールの数（古い既読から消える）
  static const keep = 60;

  @override
  List<Mail> build() => const [];

  void restore(List<Mail> mails) => state = mails;

  /// メールを届ける
  void deliver(Mail m) {
    final list = [m, ...state];
    // 多すぎたら、古い既読から消す
    while (list.length > keep) {
      final i = list.lastIndexWhere((x) => x.read);
      if (i < 0) break;
      list.removeAt(i);
    }
    state = list;
  }

  /// 読む: 中身を受け取って、既読にする（2回目は何もしない）
  Mail? read(String id) {
    final i = state.indexWhere((m) => m.id == id);
    if (i < 0) return null;
    final m = state[i];
    if (m.read) return m;
    if (m.brains > 0) ref.read(brainProvider.notifier).addStock(m.brains);
    if (m.xp > 0) ref.read(playerProvider.notifier).addXp(m.xp);
    final r = m.asRead();
    state = [...state]..[i] = r;
    return r;
  }

  /// 未読をまとめて読む（中身を全部受け取る）。受け取った合計（ちびのう, EXP）を返す
  (int, int) readAll() {
    final unread = state.where((m) => !m.read).toList();
    final brains = unread.fold(0, (a, m) => a + m.brains);
    final xp = unread.fold(0, (a, m) => a + m.xp);
    if (unread.isEmpty) return (0, 0);
    if (brains > 0) ref.read(brainProvider.notifier).addStock(brains);
    if (xp > 0) ref.read(playerProvider.notifier).addXp(xp);
    state = [for (final m in state) m.read ? m : m.asRead()];
    return (brains, xp);
  }
}

final mailProvider = NotifierProvider<MailNotifier, List<Mail>>(MailNotifier.new);

/// まだ読んでいないメールの数（ホームの赤い丸）
final unreadMailProvider = Provider<int>((ref) => ref.watch(mailProvider).where((m) => !m.read).length);

/// まだ読んでいないメールの中の、ちびのうの合計
final unreadBrainsProvider = Provider<int>(
  (ref) => ref.watch(mailProvider).where((m) => !m.read).fold(0, (a, m) => a + m.brains),
);
