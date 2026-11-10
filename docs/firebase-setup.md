# ひたテツ × Google Cloud / Firebase つなぎ方

締切: **11/10 19:00 コードフリーズ**（URLは11/14まで動かしておく）
いちばん大事なのは「公開URLが動くこと」。上から順番にやる。

---

## 0. 役割分担

| 誰が | やること |
|---|---|
| Firebase担当（チームメイト） | 1〜3（プロジェクト作成・メンバー追加・機能ON） |
| だれか1人 | 4〜6（アプリとつなぐ・デプロイ） |
| 全員 | 7（GitHubで一緒に編集） |

---

## 1. プロジェクトを作る（Firebase担当）

- [ ] https://console.firebase.google.com →「プロジェクトを追加」
  - これで Google Cloud プロジェクトも同時にできる（審査の「Google Cloud上で動く」を満たす）
- [ ] **プロジェクトID** を決める → そのままURLになる（例: `hitatetsu` → `hitatetsu.web.app`）。**あとから変えられない**
- [ ] Google アナリティクス: **ON**
- [ ] ハッカソンのクレジットがあれば、このプロジェクトに適用する

## 2. メンバーを追加する（Firebase担当）

- [ ] ⚙ プロジェクトの設定 →「ユーザーと権限」→ チーム全員のGoogleアカウントを **編集者（Editor）** 以上で追加
  - これで誰のパソコンからでも `firebase deploy` できる。アカウントやパスワードの共有は不要

## 3. 機能をONにする（Firebase担当）

- [ ] **Authentication** →「ログイン方法」→ **匿名（Anonymous）** を有効化
- [ ] **Firestore Database** → 作成。場所は **asia-northeast1（東京）**、本番モードで開始（ルールはコードで書く）
- [ ] **Hosting** →「始める」を押すだけ（残りはターミナルで）
- [ ] 料金プランは **Spark（無料）のままでOK**
  - Cloud Functions / Gemini（Vertex）を使う時だけ Blaze が必要。その場合は **予算アラート（例: ¥1,000）を必ず設定**

## 4. パソコンの準備（Windows）

- [ ] **Git for Windows**: https://git-scm.com （GitHubが苦手なら **GitHub Desktop** でもOK）
- [ ] **Flutter**: https://docs.flutter.dev/get-started/install/windows/web （Web用だけでOK。Visual Studio は不要）
- [ ] **Node.js**（LTS版）: https://nodejs.org
- [ ] PowerShell で:

```powershell
# npm のコマンドが「スクリプトの実行が無効」で止まる時だけ、先にこれ
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

npm install -g firebase-tools
firebase login                            # ブラウザが開くので、2で追加されたアカウントで
dart pub global activate flutterfire_cli
flutter doctor                            # Chrome に ✓ があればOK
```

- アプリを動かす: `cd app` → `flutter run -d chrome`

## 5. アプリとつなぐ（つなぐ人。Claudeに頼んでもOK）

```sh
cd app
flutterfire configure --project=<プロジェクトID> --platforms=web
flutter pub add firebase_core firebase_auth cloud_firestore firebase_analytics
firebase init hosting      # public: build/web / SPA: Yes / GitHub自動デプロイ: Yes（→7）
firebase init firestore    # firestore.rules を作る
```

できるファイル:
- `lib/firebase_options.dart` … **コミットしてOK**（Web用の設定は公開サイトに必ず含まれるもので、秘密ではない）
  - 念のため Cloud Console →「APIとサービス」→「認証情報」で、そのキーを公開ドメイン（`*.web.app` など）に制限する
- `firebase.json` / `.firebaserc` / `firestore.rules` … コミットする

その後のコード側（Claude担当）:
1. `main.dart` で `Firebase.initializeApp` + 匿名ログイン
2. 今メモリだけにあるもの（記録・ミッション・EXP・プレゼント・回答ログ）を Firestore に保存 → 再読み込みしても消えない
3. `firestore.rules`: 自分のデータ（`users/{uid}`）だけ読み書きできる
4. 回答ログを Analytics のイベントとして送る
5. 余裕があれば全国ランキング

## 6. デプロイ

```sh
cd app
flutter build web --release
firebase deploy --only hosting,firestore
```

→ `https://<プロジェクトID>.web.app` が提出URL

---

## 7. GitHubで一緒に編集する

- [ ] リポジトリを作り、⚙ Settings → **Collaborators** でチームメイトを招待 → 招待された人は push できる
  - ただの公開リポジトリだと、他の人は見るだけ（編集はできない）
- [ ] **PoCのコード（`prototype.html` など）はリポジトリに入れない**（ハッカソンのルール）。`app/` と `docs/` だけ入れる
- [ ] 同じファイルを同時に触るとぶつかるので、ブランチ → Pull Request → main にマージ
- [ ] おすすめ: 5の `firebase init hosting` で「GitHub自動デプロイ」をYesにすると
  - main にマージ → 自動で本番URLに公開
  - Pull Request ごとに確認用のプレビューURLができる
  - デプロイ用の鍵はGitHubの **Secrets** に自動で保存される（リポジトリには入らない）
  - ※ GitHub Actions の中で Flutter をビルドする設定（`subosito/flutter-action`）を足す必要あり

## 絶対にコミットしないもの

`.gitignore` 設定済み: `.env`、`*service-account*.json`、`*-key.json`、`*.pem`
- **Gemini APIキー** は秘密。Webアプリのコードに書くと誰でも見られるので、使う時は Firebase AI Logic（+ App Check）か Cloud Functions 経由にする（ディベートは保留中なので今は不要）
- もし間違えてpushしたら: 削除するだけでは履歴に残る → **すぐにキーを無効化して作り直す**
