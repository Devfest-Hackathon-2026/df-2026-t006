import 'package:flutter/material.dart';

import '../theme.dart';
import 'push_button.dart';

/// フレンド（仮）。アカウント機能ができたら Firestore から読み込む。
class Friend {
  const Friend(this.name, {this.online = false});

  final String name;
  final bool online;
}

/// 仮のフレンド
const sampleFriends = [Friend('ユウ', online: true), Friend('ミナ', online: true), Friend('ケン')];

/// ホームの右端に縦に並ぶフレンド欄（ゲームのロビー風）。
/// 顔アイコン + オンラインの緑の点 + フレンドを追加する「＋」。
class FriendsRail extends StatelessWidget {
  const FriendsRail({super.key, required this.onTap, this.friends = sampleFriends});

  final List<Friend> friends;

  /// フレンドや「＋」を押した時（今は準備中の表示）
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'フレンド',
            style: sans(9, weight: FontWeight.w800, color: AppColors.ink, height: 1, spacing: 1),
          ),
          const SizedBox(height: 8),
          for (final f in friends) ...[_Avatar(friend: f, onTap: onTap), const SizedBox(height: 8)],
          PushButton.circle(
            size: 34,
            depth: 3,
            face: AppColors.surface,
            edge: AppColors.ink,
            border: AppColors.ink,
            onPressed: onTap,
            child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.ink, size: 17),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.friend, required this.onTap});

  final Friend friend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.ink, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  friend.name.characters.first,
                  style: const TextStyle(fontFamily: 'DotGothic16', fontSize: 16, color: AppColors.ink, height: 1),
                ),
              ),
              // オンラインなら緑の点
              if (friend.online)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: AppColors.xpGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            friend.name,
            style: sans(9, weight: FontWeight.w700, color: AppColors.ink, height: 1),
          ),
        ],
      ),
    );
  }
}
