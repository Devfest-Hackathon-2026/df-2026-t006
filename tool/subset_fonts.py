#!/usr/bin/env python3
"""同梱フォントを「使う文字だけ」に減らし直す（アプリの文章を変えたら実行）。

使い方（app/ で）:
    python3 -m venv /tmp/fontvenv && /tmp/fontvenv/bin/pip install fonttools
    /tmp/fontvenv/bin/python tool/subset_fonts.py

- 元のフォント（Google Fonts の配布ファイル）をダウンロードし、ハッシュを確かめてから減らす
- Noto Sans JP: かな・JIS第1水準漢字・英数字・アプリ内の文字（ユーザーの入力や AI の返事も表示するため）
- それ以外: アプリ内の文字・かな・英数字だけ
"""
import hashlib, pathlib, subprocess, sys, tempfile, urllib.request

APP = pathlib.Path(__file__).resolve().parent.parent
OUT = APP / 'assets' / 'fonts'

# (出力ファイル名, Google Fonts のファイルのハッシュ, 広い文字セットを使うか)
FONTS = [
    ('NotoSansJP-Regular.ttf', '0eba77a9f62df60eda7b56719cf57bbfbd8434583f2a137a9b91d4d67cf420c0', True),
    ('NotoSansJP-Bold.ttf', '74823fedeaaa812df51a6a1ab156cdde3183f65dc924d02934238d8e553f28bc', True),
    ('NotoSansJP-ExtraBold.ttf', '8900f1bbf86e9af7c4af59c2f46c862b595069cd7b462ec7b0503b88f3c23f1a', True),
    ('NotoSerifJP-SemiBold.ttf', '2dbd85f24b63306ed284e18eb7fed398a229616365f30853a7f0681c5f46d124', False),
    ('NotoSerifJP-ExtraBold.ttf', '2628feb36649ff0ba9193f9245210038989df521ed102d8568a62920e3e9ac51', False),
    ('DelaGothicOne-Regular.ttf', 'ca21b702c5c8a96a3431bd7b7496c315b8808939cd986072230e4167da1b4dbf', False),
]
# DotGothic16 は Google Fonts のハッシュ配布がないので、元ファイルの URL から
DOT = ('DotGothic16-Regular.ttf', 'https://github.com/google/fonts/raw/main/ofl/dotgothic16/DotGothic16-Regular.ttf')


def app_chars() -> set[str]:
    chars = {chr(c) for c in range(0x20, 0x7F)}
    chars |= {chr(c) for c in range(0x3000, 0x3100)}  # 記号・ひらがな・カタカナ
    chars |= {chr(c) for c in range(0xFF01, 0xFF5F)}  # 全角英数・記号
    for p in (APP / 'lib').rglob('*.dart'):
        chars |= set(p.read_text(encoding='utf-8'))
    return {c for c in chars if c.isprintable() or c == ' '}


def wide_chars() -> set[str]:
    chars = app_chars()
    for lead in range(0x81, 0x99):  # JIS X 0208: 非漢字 + 第1水準漢字
        for trail in list(range(0x40, 0x7F)) + list(range(0x80, 0xFD)):
            if lead == 0x98 and trail > 0x72:
                continue
            try:
                chars.add(bytes([lead, trail]).decode('shift_jis'))
            except UnicodeDecodeError:
                pass
    chars |= {chr(c) for c in range(0xFF61, 0xFFA0)}
    return {c for c in chars if c.isprintable() or c == ' '}


def subset(src: pathlib.Path, dst: pathlib.Path, chars: set[str], tmp: pathlib.Path):
    text = tmp / 'chars.txt'
    text.write_text(''.join(sorted(chars)), encoding='utf-8')
    subprocess.run(
        [sys.executable, '-m', 'fontTools.subset', str(src), f'--text-file={text}', f'--output-file={dst}',
         "--layout-features=*", '--no-hinting', '--desubroutinize', '--drop-tables+=DSIG'],
        check=True,
    )
    print(f'{dst.name}: {src.stat().st_size:,} -> {dst.stat().st_size:,} bytes')


def main():
    with tempfile.TemporaryDirectory() as d:
        tmp = pathlib.Path(d)
        wide, small = wide_chars(), app_chars()
        for name, digest, is_wide in FONTS:
            src = tmp / name
            src.write_bytes(urllib.request.urlopen(f'https://fonts.gstatic.com/s/a/{digest}.ttf').read())
            if hashlib.sha256(src.read_bytes()).hexdigest() != digest:
                sys.exit(f'{name}: ハッシュが一致しません')
            subset(src, OUT / name, wide if is_wide else small, tmp)
        name, url = DOT
        src = tmp / name
        try:
            src.write_bytes(urllib.request.urlopen(url, timeout=60).read())
        except OSError as e:
            # GitHub が混んでいる時など。ドット文字（名言の帯）は今の同梱ファイルのまま
            print(f'{name}: ダウンロードできなかったので、今のファイルのまま（{e}）')
            return
        subset(src, OUT / name, small, tmp)


if __name__ == '__main__':
    main()
