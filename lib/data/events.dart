/// ホームのイベント枠に流すお知らせ・イベント。
/// 今は仮のデータ。後でFirestoreから読み込む予定。
class AppEvent {
  const AppEvent({required this.tag, required this.title, required this.detail, this.route});

  /// 種類（開催中・NEW・ミッション など）
  final String tag;
  final String title;

  /// 期間や報酬などの補足
  final String detail;

  /// タップした時の移動先（なければ何もしない）
  final String? route;
}

const currentEvents = <AppEvent>[
  AppEvent(tag: '開催中', title: '「テセウスの船」ウィーク', detail: '11/6〜11/12　今週はこの問いをみんなで考えよう', route: '/topics/theseus'),
  AppEvent(tag: 'NEW', title: '新テーマ「自由意志」が登場', detail: 'あなたの選択は、本当にあなたのもの？', route: '/topics/free-will'),
  AppEvent(tag: 'ミッション', title: 'テーマを3つ考えきろう', detail: '報酬　EXP +300'),
  AppEvent(tag: 'お知らせ', title: 'アプリをリリースしました', detail: '感想をお待ちしています', route: '/news'),
];
