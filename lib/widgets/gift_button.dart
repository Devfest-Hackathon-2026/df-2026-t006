import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/mail.dart';
import '../theme.dart';
import 'hitachan.dart';
import 'phone_frame.dart';
import 'push_button.dart';

/// 毎日のログインボーナス: 1日1回、アプリを開いた時にメールで届く（読むと経験値）
/// 届けた日のクラウド（Firestore）への保存は services/cloud.dart
class GiftNotifier extends Notifier<DateTime?> {
  static const reward = 30;

  @override
  DateTime? build() => null;

  /// 今日はまだ届けていないか
  bool get canClaim {
    final last = state;
    if (last == null) return true;
    final now = DateTime.now();
    return last.year != now.year || last.month != now.month || last.day != now.day;
  }

  void restore(DateTime? last) => state = last;

  /// 今日のログインボーナスをメールで届ける（1日1回）
  void deliverToday() {
    if (!canClaim) return;
    final now = DateTime.now();
    state = now;
    ref
        .read(mailProvider.notifier)
        .deliver(
          Mail(
            id: 'daily-${now.year}${now.month}${now.day}',
            title: 'ログインボーナス',
            body: '今日も来てくれてありがとう。きょうも「なぜ？」を探しにいこう。',
            receivedAt: now,
            xp: reward,
          ),
        );
  }
}

final giftProvider = NotifierProvider<GiftNotifier, DateTime?>(GiftNotifier.new);

/// ホームの右側のメールボックス（読んでいないメールの数を赤い丸で）
class GiftButton extends ConsumerWidget {
  const GiftButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadMailProvider);
    const p = Palette.main;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            PushButton.circle(
              face: p.card.face,
              edge: p.card.edge,
              border: p.card.border,
              size: 52,
              // メールボックスは別のページで開く
              onPressed: () => context.go('/mail'),
              child: Icon(
                unread > 0 ? Icons.markunread_mailbox_rounded : Icons.mail_outline_rounded,
                color: p.card.content,
                size: 26,
              ),
            ),
            if (unread > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.ink, width: 2),
                  ),
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: sans(10, weight: FontWeight.w800, color: Colors.white, height: 1),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'メール',
          style: sans(
            10,
            weight: FontWeight.w800,
          ).copyWith(shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 6)]),
        ),
      ],
    );
  }
}

/// メールボックス（ページ）: 1通ずつ開いて読む（読むと中身を受け取り、灰色になる）。未読だけ / すべて で絞りこめる。
/// 一覧はページいっぱいの高さで、メールの数で大きさが変わらない
class MailScreen extends ConsumerStatefulWidget {
  const MailScreen({super.key});

  @override
  ConsumerState<MailScreen> createState() => _MailScreenState();
}

class _MailScreenState extends ConsumerState<MailScreen> {
  /// 未読だけを出すか
  bool _unreadOnly = true;

  Future<void> _open(Mail m) async {
    HapticFeedback.selectionClick();
    // 開いた時点で読んだことにして、中身を受け取る
    final wasUnread = !m.read;
    final read = ref.read(mailProvider.notifier).read(m.id) ?? m;
    await showDialog<void>(
      context: context,
      builder: (_) => _LetterDialog(mail: read, justReceived: wasUnread),
    );
  }

  void _claimAll() {
    HapticFeedback.mediumImpact();
    final (brains, xp) = ref.read(mailProvider.notifier).readAll();
    final got = [if (brains > 0) 'ちびのう ×$brains', if (xp > 0) '+$xp EXP'];
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(got.isEmpty ? 'メールをすべて読みました' : '${got.join('・')} を受け取りました'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(mailProvider);
    final unread = all.where((m) => !m.read).length;
    final shown = _unreadOnly ? all.where((m) => !m.read).toList() : all;

    const p = Palette.main;
    return Scaffold(
      body: PhoneFrame(
        background: p.background,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(title: 'メールボックス', palette: p, onBack: () => context.go('/')),
              // 絞りこみ: 未読だけ / すべて
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: SizedBox(
                  height: 38,
                  child: Row(
                    children: [
                      _Filter(
                        label: '未読 $unread',
                        selected: _unreadOnly,
                        onTap: () => setState(() => _unreadOnly = true),
                      ),
                      const SizedBox(width: 8),
                      _Filter(
                        label: 'すべて ${all.length}',
                        selected: !_unreadOnly,
                        onTap: () => setState(() => _unreadOnly = false),
                      ),
                      if (unread > 0) ...[
                        const Spacer(),
                        // 未読をまとめて開いて、中身を全部受け取る
                        PushButton(
                          width: 140,
                          height: 34,
                          depth: 3,
                          radius: 10,
                          onPressed: _claimAll,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'まとめて受け取る',
                              style: sans(12, weight: FontWeight.w800, color: AppColors.onNavy),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // 一覧（ページの残り全部。メールが多ければスクロール）
              Expanded(
                child: shown.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.mail_outline_rounded, size: 48, color: AppColors.muted),
                              const SizedBox(height: 10),
                              Text(
                                _unreadOnly ? '読んでいないメールはありません' : 'メールはありません',
                                style: sans(15, weight: FontWeight.w800, color: AppColors.muted),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'テーマを考えきったり、ボスと戦ったり、ミッションを達成したりすると届きます',
                                textAlign: TextAlign.center,
                                style: sans(12, color: AppColors.muted, height: 1.6),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                        children: [for (final m in shown) _LetterRow(mail: m, onTap: () => _open(m))],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Filter extends StatelessWidget {
  const _Filter({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.ink.withValues(alpha: selected ? 1 : 0.4)),
        ),
        child: Text(
          label,
          style: sans(12, weight: FontWeight.w800, color: selected ? const Color(0xFF16181A) : AppColors.ink),
        ),
      ),
    );
  }
}

/// メールの一覧の1行（未読は明るく、読んだら灰色）
class _LetterRow extends StatelessWidget {
  const _LetterRow({required this.mail, required this.onTap});

  final Mail mail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final m = mail;
    final unread = !m.read;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: unread ? 1 : 0.45,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: unread ? AppColors.surface : const Color(0xFF2A2C2D),
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: unread ? AppColors.accent : AppColors.quietEdge, width: 4)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: unread ? AppColors.navy : AppColors.quietFace,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  unread ? Icons.mail_rounded : Icons.drafts_rounded,
                  color: unread ? AppColors.onNavy : AppColors.muted,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (unread) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            color: AppColors.red,
                            child: Text(
                              'NEW',
                              style: sans(9, weight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            m.title,
                            overflow: TextOverflow.ellipsis,
                            style: sans(13, weight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      m.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: sans(11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                unread ? '開く ›' : '既読',
                style: sans(12, weight: FontWeight.w800, color: unread ? AppColors.accent : AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 開いたメール（手紙のように読む。中身はこの時に受け取る）
class _LetterDialog extends StatelessWidget {
  const _LetterDialog({required this.mail, required this.justReceived});

  final Mail mail;

  /// 今ここで受け取ったか（もう読んだメールを開き直した時は false）
  final bool justReceived;

  @override
  Widget build(BuildContext context) {
    final m = mail;
    String two(int n) => n.toString().padLeft(2, '0');
    final date =
        '${m.receivedAt.year}/${two(m.receivedAt.month)}/${two(m.receivedAt.day)} ${two(m.receivedAt.hour)}:${two(m.receivedAt.minute)}';
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8D0),
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [BoxShadow(color: Color(0xAA000000), offset: Offset(5, 5))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'From: ${m.from}',
                    style: sans(11, weight: FontWeight.w800, color: const Color(0xFF6B5A44)),
                  ),
                  const Spacer(),
                  Text(date, style: sans(11, color: const Color(0xFF6B5A44))),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                m.title,
                style: serif(19, weight: FontWeight.w800, color: const Color(0xFF2B1D12)),
              ),
              const SizedBox(height: 8),
              Text(m.body, style: sans(14, color: const Color(0xFF2B1D12), height: 1.7)),
              if (m.brains > 0 || m.xp > 0) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B1D12).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Text(
                        justReceived ? '受け取りました' : '受け取りずみ',
                        style: sans(12, weight: FontWeight.w800, color: const Color(0xFF2B1D12)),
                      ),
                      const Spacer(),
                      if (m.brains > 0) ...[
                        const ChibinoIcon(size: 18),
                        Text(
                          ' ×${m.brains}',
                          style: sans(15, weight: FontWeight.w800, color: const Color(0xFF2B1D12)),
                        ),
                      ],
                      if (m.brains > 0 && m.xp > 0) const SizedBox(width: 10),
                      if (m.xp > 0)
                        Text(
                          '+${m.xp} EXP',
                          style: sans(15, weight: FontWeight.w800, color: AppColors.xpGreen),
                        ),
                    ],
                  ),
                ),
              ],
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'とじる',
                    style: sans(14, weight: FontWeight.w800, color: const Color(0xFF2B1D12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
