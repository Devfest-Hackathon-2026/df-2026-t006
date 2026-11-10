import 'package:flutter_riverpod/flutter_riverpod.dart';

/// お知らせ（イベント・新機能）。アプリを開くたびに1つポップアップで出し、お知らせ画面にも並べる。
/// TODO: あとで Firestore から読み込む（運営が増やせるように）
class NewsItem {
  const NewsItem({
    required this.date,
    required this.tag,
    required this.title,
    required this.body,
    this.route,
    this.action,
  });

  final String date;

  /// 「イベント」「新機能」など
  final String tag;
  final String title;
  final String body;

  /// 「見てみる」で開く画面（なければボタンなし）
  final String? route;
  final String? action;
}

const news = <NewsItem>[
  NewsItem(
    date: '11/08',
    tag: 'イベント',
    title: '哲学者ボスに挑め！',
    body: 'カント・デカルト・ニーチェ・ヘラクレイトスが、きみの「理由」を待っている。★1〜★3の難しさを選んで、哲学者を納得させよう。',
    route: '/topics/battle',
    action: 'ボス戦へ',
  ),
  NewsItem(
    date: '11/08',
    tag: '新機能',
    title: '哲学者と話せるようになりました',
    body: 'コメント欄で哲学者に返信すると、その哲学者が返事をくれます。自分のコメントにも、哲学者が反応してくれるかも。',
  ),
  NewsItem(
    date: '11/08',
    tag: '新機能',
    title: 'あなたの「思考スタイル」がわかる',
    body: 'テーマの最後に AI に深さを測ってもらうと、あなたの考え方の「型」がわかります。プロフィールで確かめてみよう。',
    route: '/profile',
    action: 'プロフィールへ',
  ),
  NewsItem(
    date: '11/07',
    tag: 'お知らせ',
    title: '最後のひたちゃんを育てよう',
    body: '深く考えると、ちびのうがメールで届きます。ひたちゃんにあげて、「哲人」まで育ててあげてください。',
    route: '/hitachan',
    action: 'ひたちゃんへ',
  ),
  NewsItem(
    date: '11/06',
    tag: '新テーマ',
    title: '新しいテーマ「自由意志」',
    body: 'あなたの選択は、本当にあなたが選んだもの？ ニーチェと一緒に考えてみよう。',
    route: '/topics',
    action: 'テーマへ',
  ),
];

/// お知らせを何件まで見たか（お知らせ画面を開くと、いまの件数になる）。
/// 新しいお知らせが増えた時だけ、ホームのお知らせに赤い点が出る
class NewsSeen extends Notifier<int> {
  @override
  int build() => 0;

  void restore(int n) => state = n;

  void markAllSeen() {
    if (state != news.length) state = news.length;
  }
}

final newsSeenProvider = NotifierProvider<NewsSeen, int>(NewsSeen.new);

/// 見ていないお知らせがあるか
final hasUnseenNewsProvider = Provider<bool>((ref) => ref.watch(newsSeenProvider) < news.length);
