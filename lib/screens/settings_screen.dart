import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/quotes.dart';
import '../services/music.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/phone_frame.dart';
import '../widgets/push_button.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const p = Palette.main;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      body: PhoneFrame(
        background: p.background,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScreenHeader(title: '設定', palette: p, onBack: () => context.go('/')),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  children: [
                    _SectionTitle('考える時間（1枚あたり）', palette: p),
                    Row(
                      children: [
                        for (final s in const [3, 6, 10]) ...[
                          Expanded(
                            child: PushButton(
                              height: 52,
                              depth: 4,
                              radius: 14,
                              face: settings.lockSeconds == s ? p.primary.face : p.card.face,
                              edge: settings.lockSeconds == s ? p.primary.edge : p.card.edge,
                              border: settings.lockSeconds == s ? p.primary.border : p.card.border,
                              onPressed: () => notifier.setLockSeconds(s),
                              child: Text(
                                '$s秒',
                                style: sans(
                                  16,
                                  weight: FontWeight.w800,
                                  color: settings.lockSeconds == s ? p.primary.content : p.card.content,
                                ),
                              ),
                            ),
                          ),
                          if (s != 10) const SizedBox(width: 10),
                        ],
                      ],
                    ),
                    const SizedBox(height: 28),
                    _SectionTitle('名言の言語（ホームの帯）', palette: p),
                    Row(
                      children: [
                        for (final lang in QuoteLanguage.values) ...[
                          Expanded(
                            child: PushButton.colored(
                              colors: settings.quoteLanguage == lang ? p.primary : p.card,
                              height: 52,
                              depth: 4,
                              radius: 14,
                              onPressed: () => notifier.setQuoteLanguage(lang),
                              child: Text(
                                lang.label,
                                style: sans(
                                  16,
                                  weight: FontWeight.w800,
                                  color: settings.quoteLanguage == lang ? p.primary.content : p.card.content,
                                ),
                              ),
                            ),
                          ),
                          if (lang != QuoteLanguage.values.last) const SizedBox(width: 10),
                        ],
                      ],
                    ),
                    const SizedBox(height: 28),
                    _SectionTitle('サウンド', palette: p),
                    _VolumeSlider(
                      icon: Icons.music_note_rounded,
                      label: 'BGM',
                      value: ref.watch(soundProvider).bgm,
                      onChanged: (v) => ref.read(soundProvider.notifier).setBgm(v),
                    ),
                    const SizedBox(height: 10),
                    _VolumeSlider(
                      icon: Icons.touch_app_rounded,
                      label: '効果音',
                      value: ref.watch(soundProvider).sfx,
                      onChanged: (v) => ref.read(soundProvider.notifier).setSfx(v),
                      // 動かし終わったら、その音量で鳴らして確かめられる
                      onChangeEnd: (_) => Sfx.tap(),
                    ),
                    const SizedBox(height: 28),
                    _SectionTitle('アカウント', palette: p),
                    PushButton(
                      height: 56,
                      depth: 4,
                      radius: 14,
                      face: p.card.face,
                      edge: p.card.edge,
                      border: p.card.border,
                      onPressed: null, // TODO: アカウント機能
                      child: Text(
                        '準備中',
                        style: sans(15, weight: FontWeight.w700, color: p.subText),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _SectionTitle('このアプリについて', palette: p),
                    PushButton(
                      height: 56,
                      depth: 4,
                      radius: 14,
                      face: p.card.face,
                      edge: p.card.edge,
                      border: p.card.border,
                      onPressed: () => context.go('/settings/credits'),
                      child: Text(
                        'クレジット（画像・フォント・AI）',
                        style: sans(15, weight: FontWeight.w800, color: p.card.content),
                      ),
                    ),
                    const SizedBox(height: 10),
                    PushButton(
                      height: 56,
                      depth: 4,
                      radius: 14,
                      face: p.card.face,
                      edge: p.card.edge,
                      border: p.card.border,
                      onPressed: () => context.go('/prologue'),
                      child: Text(
                        'プロローグをもう一度見る',
                        style: sans(15, weight: FontWeight.w800, color: p.card.content),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {required this.palette});

  final String text;
  final Palette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text,
        style: sans(13, weight: FontWeight.w800, color: palette.subText),
      ),
    );
  }
}

/// 音量のスライダー（0% でオフ）
class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
  });

  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final off = value == 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(off ? Icons.volume_off_rounded : icon, color: off ? AppColors.muted : AppColors.ink, size: 22),
          const SizedBox(width: 8),
          SizedBox(
            width: 52,
            child: Text(label, style: sans(14, weight: FontWeight.w800)),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 5,
                activeTrackColor: AppColors.ink,
                inactiveTrackColor: AppColors.ink.withValues(alpha: 0.2),
                thumbColor: AppColors.ink,
                overlayColor: AppColors.ink.withValues(alpha: 0.1),
              ),
              child: Slider(value: value, onChanged: onChanged, onChangeEnd: onChangeEnd),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              off ? 'オフ' : '${(value * 100).round()}%',
              textAlign: TextAlign.right,
              style: sans(13, weight: FontWeight.w800, color: off ? AppColors.muted : AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
