#!/usr/bin/env python3
"""提出用の「著作物利用シート」（運営のテンプレートの形）を作る。

使い方（リポジトリのいちばん上で）: python3 app/tool/gen_license_sheet.py
  - 画像は docs/著作物利用シート.md の表から読む（出典・作者・ライセンスを二重に書かないため）
  - フォント・音楽・アイコン・ライブラリ・API は、下の表に書いてある
  - 出力: docs/著作物利用シート_提出用.csv（Excel / Google スプレッドシートで開ける）と、
          docs/著作物利用シート_提出用.tsv（スプレッドシートに貼り付ける用。見出しなし）

列: No. / 著作物の名称 / 種類 / 入手元URL / 権利者名（著作者名） / ライセンス形態 / 改変の有無
"""

import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'docs' / '著作物利用シート.md'
OUT_CSV = ROOT / 'docs' / '著作物利用シート_提出用.csv'
OUT_TSV = ROOT / 'docs' / '著作物利用シート_提出用.tsv'

# まだわからないところ（チームで記入する）
TODO = '【要記入】'


def cells(line):
    return [c.strip() for c in line.strip().strip('|').split('|')]


def clean(s):
    s = s.replace('**', '').replace('*', '')
    return re.sub(r'\s+', ' ', s).strip()


def first_url(s):
    m = re.search(r'https?://\S+', s)
    return m.group(0).rstrip('）)') if m else ''


def license_of(s):
    # 「**CC BY 4.0** https://...」→「CC BY 4.0」、括弧の補足は残す
    s = clean(re.sub(r'https?://\S+', '', s))
    return s


def image_rows():
    """md の画像の表（テーマの絵・ホーム背景・肖像・プロローグ）"""
    rows = []
    section = ''
    for line in SRC.read_text(encoding='utf-8').splitlines():
        if line.startswith('## ') or line.startswith('### '):
            section = line
        if not line.startswith('| `') or '.jpg' not in line.split('|')[1]:
            continue
        c = cells(line)
        file = c[0].strip('`')
        if '肖像' in section:
            # | ファイル | 人物 | 作者 | 出典 | ライセンス | クレジット |
            name = f'{re.sub(r"（.*?）", "", c[1])}の肖像（{file}）'
            author, url, lic = clean(c[2]), first_url(c[3]), license_of(c[4])
        else:
            # | ファイル | 使用箇所 | 作品名 / 作者 | 出典 | ライセンス | クレジット |
            parts = [p.strip() for p in re.split(r'\s*/\s*', clean(c[2]))]
            title = parts[0].replace('"', '').replace('“', '').replace('”', '')
            name = f'{title}（{file}）'
            author = ' / '.join(parts[1:]) or '不明'
            url, lic = first_url(c[3]), license_of(c[4])
        lic = lic.replace('Public domain', 'パブリックドメイン')
        rows.append([name, '画像', url, author, lic, 'あり（縮小・切り抜き・色の調整）'])
    return rows


FONTS = [
    ['Noto Sans JP', 'https://fonts.google.com/noto/specimen/Noto+Sans+JP', 'Google LLC'],
    ['Noto Serif JP', 'https://fonts.google.com/noto/specimen/Noto+Serif+JP', 'Google LLC'],
    ['Dela Gothic One', 'https://github.com/syakuzen/DelaGothic', 'The Dela Gothic Project Authors'],
    ['DotGothic16', 'https://github.com/google/fonts/tree/main/ofl/dotgothic16', 'The DotGothic16 Project Authors（Fontworks Inc.）'],
]

# どれもチームが Google Gemini で生成（2026-11-09）
MUSIC = [
    ['The Stone Library（ホームの BGM）', 'https://share.gemini.google/UvI5lpVLhUmk'],
    ['Archive of Stillness（リールの BGM）', 'https://share.gemini.google/ogwEmNp6SJak'],
    ['The Final Deduction（ボス戦の BGM）', 'https://share.gemini.google/SBqaBU7DQPQg'],
    ['Fiddles in the Clover（ひたちゃんの画面の BGM）', 'https://share.gemini.google/cHK5GZNXMLgp'],
]

ICONS = [
    ['Material Icons', 'アイコン', 'https://fonts.google.com/icons', 'Google LLC', 'Apache License 2.0', 'なし'],
    ['cupertino_icons', 'アイコン', 'https://pub.dev/packages/cupertino_icons', 'The Flutter Authors（Google LLC）', 'MIT License', 'なし'],
]

LIBS = [
    ['Flutter SDK', 'https://flutter.dev', 'The Flutter Authors（Google LLC）', 'BSD 3-Clause License'],
    ['flutter_riverpod', 'https://pub.dev/packages/flutter_riverpod', 'Remi Rousselet', 'MIT License'],
    ['go_router', 'https://pub.dev/packages/go_router', 'The Flutter Authors（Google LLC）', 'BSD 3-Clause License'],
    ['firebase_core', 'https://pub.dev/packages/firebase_core', 'Google LLC（FlutterFire）', 'BSD 3-Clause License'],
    ['firebase_auth', 'https://pub.dev/packages/firebase_auth', 'Google LLC（FlutterFire）', 'BSD 3-Clause License'],
    ['cloud_firestore', 'https://pub.dev/packages/cloud_firestore', 'Google LLC（FlutterFire）', 'BSD 3-Clause License'],
    ['firebase_analytics', 'https://pub.dev/packages/firebase_analytics', 'Google LLC（FlutterFire）', 'BSD 3-Clause License'],
    ['firebase_app_check', 'https://pub.dev/packages/firebase_app_check', 'Google LLC（FlutterFire）', 'BSD 3-Clause License'],
    ['firebase_ai', 'https://pub.dev/packages/firebase_ai', 'Google LLC（FlutterFire）', 'Apache License 2.0'],
    ['audioplayers', 'https://pub.dev/packages/audioplayers', 'Blue Fire', 'MIT License'],
    ['url_launcher', 'https://pub.dev/packages/url_launcher', 'The Flutter Authors（Google LLC）', 'BSD 3-Clause License'],
    ['flutter_launcher_icons（開発時のみ）', 'https://pub.dev/packages/flutter_launcher_icons', 'Flutter Community', 'MIT License'],
]

APIS = [
    ['Gemini API（Firebase AI Logic / Vertex AI 経由。考えの深さの判定・ボス戦・哲学者の返事）', 'API',
     'https://firebase.google.com/docs/ai-logic', 'Google LLC', 'Google Cloud 利用規約・生成 AI の追加利用規約（有償）', 'なし'],
    ['Firebase（Hosting・Authentication・Cloud Firestore・Analytics・App Check）', 'API・サービス',
     'https://firebase.google.com', 'Google LLC', 'Firebase 利用規約（Blaze プラン）', 'なし'],
    ['reCAPTCHA Enterprise（App Check の確認）', 'API',
     'https://cloud.google.com/security/products/recaptcha', 'Google LLC', 'Google Cloud 利用規約', 'なし'],
]

TEXTS = [
    ['哲学者の言葉（コメント欄・ホームの名言の帯・ボスの資料。ソクラテス、カント、ニーチェなど）', '文章（引用）',
     '—（古典の一般的な日本語訳）', '各哲学者（原文はパブリックドメイン）',
     'パブリックドメイン（原文）。短い引用', 'なし'],
]


def main():
    rows = []
    rows += image_rows()
    rows += [['ひたテツのロゴ・アプリアイコン（logo.png / icon.png）', '画像',
              'https://chatgpt.com/share/6af17acc-e2e8-83ec-8bd5-e84d7f879955', 'チーム（ChatGPT（OpenAI）で生成）',
              'OpenAI 利用規約に基づく（出力の権利は利用者に帰属）（生成日: 2026-11-06）', 'なし']]
    rows += [[f'{n}（フォント）', 'フォント', u, a, 'SIL Open Font License 1.1', 'あり（使う文字だけに減らした）']
             for n, u, a in FONTS]
    rows += [[n, '音声', u, 'チーム（Google Gemini で生成）', 'Google 生成 AI の利用規約に基づく（生成日: 2026-11-09）',
              'あり（mp3 を AAC 112kbps に変換）'] for n, u in MUSIC]
    rows += ICONS
    rows += [[n, 'コード（ライブラリ）', u, a, l, 'なし'] for n, u, a, l in LIBS]
    rows += APIS
    rows += TEXTS

    numbered = [[str(i + 1), *r] for i, r in enumerate(rows)]
    header = ['No.', '著作物の名称', '種類', '入手元URL', '権利者名（著作者名）', 'ライセンス形態', '改変の有無']
    # Excel でも文字化けしないよう BOM つき
    with OUT_CSV.open('w', encoding='utf-8-sig', newline='') as f:
        csv.writer(f).writerows([header, *numbered])
    with OUT_TSV.open('w', encoding='utf-8', newline='') as f:
        csv.writer(f, delimiter='\t', lineterminator='\n').writerows(numbered)
    todo = sum(1 for r in numbered if TODO in r)
    print(f'{len(numbered)} 行（うち {TODO} のある行: {todo}）→ {OUT_CSV.name}, {OUT_TSV.name}')


if __name__ == '__main__':
    main()
