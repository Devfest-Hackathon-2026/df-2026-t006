import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../data/credits.dart';
import '../theme.dart';
import '../widgets/phone_frame.dart';

/// クレジット: 使っている画像・フォント・AI・ライブラリ。
/// CC BY / BY-SA の画像は、ライセンス上ここでの表記が必要。
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const p = Palette.main;
    return Scaffold(
      body: PhoneFrame(
        background: p.background,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(title: 'クレジット', palette: p, onBack: () => context.go('/settings')),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    Text('ひたテツは、たくさんの作品の力を借りてできています。', style: sans(13, color: AppColors.muted, height: 1.7)),
                    for (final s in imageCredits) ...[
                      _Heading(title: s.title, note: s.note),
                      for (final c in s.items) _CreditTile(credit: c),
                    ],
                    const _Heading(title: 'フォント', note: '使う文字だけに減らして（サブセット化して）同梱'),
                    const _TextTile(
                      title: 'Noto Sans JP / Noto Serif JP',
                      body: 'Google Fonts\nSIL Open Font License 1.1',
                    ),
                    const _TextTile(
                      title: 'Dela Gothic One',
                      body: 'The Dela Gothic Project Authors\nSIL Open Font License 1.1',
                    ),
                    const _TextTile(
                      title: 'DotGothic16',
                      body: 'The DotGothic16 Project Authors (Fontworks)\nSIL Open Font License 1.1',
                    ),
                    const _Heading(title: 'AI', note: ''),
                    const _TextTile(
                      title: 'Gemini（Google）',
                      body: 'Firebase AI Logic 経由で利用。\n考えの深さの判定・ボス戦・哲学者の返事の文は、Gemini がその場で作っています。',
                    ),
                    const _Heading(title: 'キャラクター・お話', note: ''),
                    const _TextTile(title: 'ひたちゃん・プロローグ', body: 'チームのオリジナル。お話はフィクションです。'),
                    const _TextTile(title: 'ロゴ・アプリアイコン', body: 'チームが ChatGPT（OpenAI）で生成（2026-11-06）。OpenAI 利用規約に基づく'),
                    const _Heading(title: '音楽', note: 'チームが Google Gemini で生成（2026-11-09）。Google 生成 AI の利用規約に基づく'),
                    const _TextTile(title: '「The Stone Library」', body: 'ホームなど、ふだんの画面の BGM'),
                    const _TextTile(title: '「Archive of Stillness」', body: 'リール（考える画面）の BGM'),
                    const _TextTile(title: '「The Final Deduction」', body: 'ボス戦の BGM'),
                    const _TextTile(title: '「Fiddles in the Clover」', body: 'ひたちゃんの画面の BGM'),
                    const _TextTile(title: '効果音（ボタンの音）', body: 'チームのオリジナル（プログラムで作った短い音）'),
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton.icon(
                        onPressed: () => showLicensePage(
                          context: context,
                          applicationName: 'ひたテツ',
                          applicationLegalese: '使っているオープンソースのライブラリとフォントのライセンス',
                        ),
                        icon: const Icon(Icons.description_rounded, size: 18, color: AppColors.accent),
                        label: Text(
                          'オープンソースのライセンス',
                          style: sans(13, weight: FontWeight.w800, color: AppColors.accent),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.note});

  final String title;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 22, 0, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: sans(14, weight: FontWeight.w800, color: AppColors.accent),
          ),
          if (note.isNotEmpty) Text(note, style: sans(11, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// 画像1件（長押しで出典のURLをコピー）
class _CreditTile extends StatelessWidget {
  const _CreditTile({required this.credit});

  final Credit credit;

  @override
  Widget build(BuildContext context) {
    final c = credit;
    return GestureDetector(
      onLongPress: () {
        Clipboard.setData(ClipboardData(text: c.source));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('出典のURLをコピーしました'), duration: Duration(seconds: 1)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: c.attributionRequired ? AppColors.accent : AppColors.ink.withValues(alpha: 0.25),
            width: c.attributionRequired ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(c.title, style: sans(12, weight: FontWeight.w800, height: 1.5)),
            if (c.author.isNotEmpty) Text(c.author, style: sans(11, color: AppColors.bodyText, height: 1.5)),
            const SizedBox(height: 3),
            Text(
              c.license,
              style: sans(
                11,
                weight: FontWeight.w800,
                color: c.attributionRequired ? AppColors.accent : AppColors.muted,
              ),
            ),
            SelectableText(c.source, style: sans(10, color: AppColors.muted, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class _TextTile extends StatelessWidget {
  const _TextTile({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: sans(12, weight: FontWeight.w800)),
          Text(body, style: sans(11, color: AppColors.bodyText, height: 1.6)),
        ],
      ),
    );
  }
}
