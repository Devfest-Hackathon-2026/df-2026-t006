#!/usr/bin/env python3
"""docs/著作物利用シート.md の画像の表から app/lib/data/credits.dart を作り直す（画像を足したら実行）。

使い方（リポジトリのいちばん上で）: python3 app/tool/gen_credits.py
"""
import pathlib, re

ROOT = pathlib.Path(__file__).resolve().parents[2]
md = (ROOT / 'docs' / '著作物利用シート.md').read_text(encoding='utf-8').splitlines()
SECTIONS = [
    ('## 1. 画像', 'テーマの絵', '白黒・高コントラストにして使用'),
    ('### ホーム画面の背景', 'ホーム画面の背景', 'トリミング・縮小して使用'),
    ('### コメント欄のプロフィール写真', '哲学者の肖像', '顔を正方形に切り抜き・縮小して使用'),
    ('### プロローグ', 'プロローグ・ひたちゃんの背景', '縮小し、紙芝居の札のように少しくすませて使用'),
]
sections, cur = [], None
for line in md:
    hit = next((s for s in SECTIONS if line.startswith(s[0])), None)
    if hit:
        cur = (hit[1], hit[2], [])
        sections.append(cur)
        continue
    if line.startswith('### ') or line.startswith('## 2'):
        cur = None
        continue
    if cur and line.startswith('| `'):
        cells = [c.strip() for c in line.strip('|').split('|')]
        clean = lambda t: re.sub(r'\*\*|`', '', t).replace('*', '').strip()
        url = (re.search(r'https?://\S+', cells[3]) or [''])[0]
        portrait = cur[0] == '哲学者の肖像'
        cur[2].append((clean(cells[1]) if portrait else clean(cells[2]), clean(cells[2]) if portrait else '', url, clean(cells[4])))

q = lambda s: "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"
out = [
    '// このファイルは app/tool/gen_credits.py が docs/著作物利用シート.md から作ったもの。直接書きかえない。',
    '',
    '/// クレジット画面の1件',
    'class Credit {',
    "  const Credit({required this.title, this.author = '', required this.source, required this.license});",
    '',
    '  final String title;',
    '  final String author;',
    '  final String source;',
    '  final String license;',
    '',
    '  /// 表記が必要なライセンス（CC BY / BY-SA）',
    "  bool get attributionRequired => license.contains('CC BY');",
    '}',
    '',
    'class CreditSection {',
    '  const CreditSection(this.title, this.note, this.items);',
    '',
    '  final String title;',
    '',
    '  /// どう改変したか',
    '  final String note;',
    '  final List<Credit> items;',
    '}',
    '',
    'const imageCredits = <CreditSection>[',
]
for title, note, rows in sections:
    out.append(f'  CreditSection({q(title)}, {q(note)}, [')
    out += [f'    Credit(title: {q(t)}, author: {q(a)}, source: {q(u)}, license: {q(l)}),' for t, a, u, l in rows]
    out.append('  ]),')
out.append('];')
(ROOT / 'app' / 'lib' / 'data' / 'credits.dart').write_text('\n'.join(out) + '\n', encoding='utf-8')
print({t: len(r) for t, _, r in sections})
