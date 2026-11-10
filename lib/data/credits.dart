// このファイルは app/tool/gen_credits.py が docs/著作物利用シート.md から作ったもの。直接書きかえない。

/// クレジット画面の1件
class Credit {
  const Credit({required this.title, this.author = '', required this.source, required this.license});

  final String title;
  final String author;
  final String source;
  final String license;

  /// 表記が必要なライセンス（CC BY / BY-SA）
  bool get attributionRequired => license.contains('CC BY');
}

class CreditSection {
  const CreditSection(this.title, this.note, this.items);

  final String title;

  /// どう改変したか
  final String note;
  final List<Credit> items;
}

const imageCredits = <CreditSection>[
  CreditSection('テーマの絵', '白黒・高コントラストにして使用', [
    Credit(
      title:
          '"The Ptolemy Philopator\'s \'forty\' ship" — Man upon the sea (1858) 所収の版画 / Internet Archive Book Images',
      author: '',
      source:
          'https://commons.wikimedia.org/wiki/File:The_Ptolemy_Philophator%27s_%22forty%22_ship,_from_Man_upon_the_sea_-_or,_a_history_of_maritime_adventure,_exploration,_and_discovery,_from_the_earliest_ages_to_the_present_time_(1858)_(14596783329).jpg',
      license: '著作権制限なし（No known copyright restrictions / パブリックドメイン, 1858年刊行）',
    ),
    Credit(
      title: '"Switch on a railroad track" (1860) / Alfred R. Waud',
      author: '',
      source: 'https://commons.wikimedia.org/wiki/File:Switch_on_a_railroad_track_LCCN2004660509.jpg',
      license: 'パブリックドメイン',
    ),
    Credit(
      title: '"Drawing of the brain, by Vesalius" — Andreas Vesalius『ファブリカ』(1543) の図版 / Wellcome Collection',
      author: '',
      source: 'https://commons.wikimedia.org/wiki/File:Drawing_of_the_brain,_by_Vesalius._Wellcome_M0011758.jpg',
      license: 'CC BY 4.0 https://creativecommons.org/licenses/by/4.0/',
    ),
    Credit(
      title: '『雲海の上の旅人』(c.1817) / Caspar David Friedrich',
      author: '',
      source: 'https://commons.wikimedia.org/wiki/File:Caspar_David_Friedrich_-_Wanderer_above_the_sea_of_fog.jpg',
      license: 'パブリックドメイン',
    ),
  ]),
  CreditSection('ホーム画面の背景', 'トリミング・縮小して使用', [
    Credit(
      title:
          '"The Great Sphinx, Pyramids of Gizeh"（『Egypt and Nubia』第1巻 No.18, 1839）/ 原画 David Roberts、石版 Louis Haghe / Cleveland Museum of Art 所蔵',
      author: '',
      source:
          'https://commons.wikimedia.org/wiki/File:Louis_Haghe_-_Egypt_and_Nubia-_Volume_I_-_No._18,_The_Great_Sphinx,_Pyramids_of_Gizeh,_F_-_1953.503_-_Cleveland_Museum_of_Art.jpg',
      license: 'CC0 1.0（パブリックドメイン提供）',
    ),
    Credit(
      title: '"Karnak"（『Egypt and Nubia』第2巻 No.14, 1838）/ 原画 David Roberts、石版 Louis Haghe / Cleveland Museum of Art 所蔵',
      author: '',
      source:
          'https://commons.wikimedia.org/wiki/File:Louis_Haghe_-_Egypt_and_Nubia-_Volume_II_-_No._14,_Karnak_-_1953.521_-_Cleveland_Museum_of_Art.jpg',
      license: 'CC0 1.0',
    ),
    Credit(
      title:
          '"Excavated Temple of Gyrshe, Nubia"（『Egypt and Nubia』第1巻 No.9, 1838）/ 原画 David Roberts、石版 Louis Haghe / Cleveland Museum of Art 所蔵',
      author: '',
      source:
          'https://commons.wikimedia.org/wiki/File:Louis_Haghe_-_Egypt_and_Nubia-_Volume_I_-_No._9,_Excavated_Temple_of_Gyrshe,_Nubia_-_1953.502_-_Cleveland_Museum_of_Art.jpg',
      license: 'CC0 1.0',
    ),
    Credit(
      title:
          '"Temple at Esneh"（『Egypt and Nubia』第1巻 No.24, 1838）/ 原画 David Roberts、石版 Louis Haghe / Cleveland Museum of Art 所蔵',
      author: '',
      source:
          'https://commons.wikimedia.org/wiki/File:Louis_Haghe_-_Egypt_and_Nubia-_Volume_I_-_No._24,_Temple_at_Esneh_-_1953.506_-_Cleveland_Museum_of_Art.jpg',
      license: 'CC0 1.0',
    ),
  ]),
  CreditSection('哲学者の肖像', '顔を正方形に切り抜き・縮小して使用', [
    Credit(
      title: 'ソクラテス',
      author: 'Copy of Lysippos (?)',
      source: 'https://commons.wikimedia.org/wiki/File:Socrates_Louvre.jpg',
      license: 'Public domain',
    ),
    Credit(
      title: 'プラトン',
      author: 'Marie-Lan Nguyen',
      source: 'https://commons.wikimedia.org/wiki/File:Plato_Silanion_Musei_Capitolini_MC1377.png',
      license: 'Public domain',
    ),
    Credit(
      title: 'アリストテレス',
      author: 'After Lysippos',
      source: 'https://commons.wikimedia.org/wiki/File:Aristotle_Altemps_Inv8575.jpg',
      license: 'Public domain',
    ),
    Credit(
      title: 'ヘラクレイトス',
      author: 'Johannes Moreelse',
      source: 'https://commons.wikimedia.org/wiki/File:Johannes_Moreelse_-_Heraclitus_-_Google_Art_Project.jpg',
      license: 'Public domain',
    ),
    Credit(
      title: '孔子',
      author: 'Anonymous Chinese painter of the Western Han period',
      source:
          'https://commons.wikimedia.org/wiki/File:Confucius,_fresco_from_a_Western_Han_tomb_of_Dongping_County,_Shandong_province,_China_(cropped).jpg',
      license: 'Public domain',
    ),
    Credit(
      title: '老子',
      author: 'Zhang Lu',
      source: 'https://commons.wikimedia.org/wiki/File:Zhang_Lu-Laozi_Riding_an_Ox_(cropped).jpg',
      license: 'Public domain',
    ),
    Credit(
      title: 'エピクテトス',
      author: 'William Sonmans / Michael Burghers',
      source:
          'https://commons.wikimedia.org/wiki/File:Epicteti_Enchiridion_Latinis_versibus_adumbratum_(Oxford_1715)_frontispiece_(cropped).jpg',
      license: 'Public domain',
    ),
    Credit(
      title: 'セネカ',
      author: 'Calidius',
      source:
          'https://commons.wikimedia.org/wiki/File:Duble_herma_of_Socrates_and_Seneca_Antikensammlung_Berlin_07.jpg',
      license: 'CC BY-SA 3.0',
    ),
    Credit(
      title: 'デカルト',
      author: 'After Frans Hals',
      source: 'https://commons.wikimedia.org/wiki/File:Frans_Hals_-_Portret_van_Ren%C3%A9_Descartes.jpg',
      license: 'Public domain',
    ),
    Credit(
      title: 'パスカル',
      author: 'unknown; a copy of the painting of François II Quesnel, which was made for Gérard Edelinck',
      source: 'https://commons.wikimedia.org/wiki/File:Blaise_Pascal_Versailles,_circa_1690.JPG',
      license: 'Public domain',
    ),
    Credit(
      title: 'カント',
      author: 'Johann Gottlieb Becker (1720-1782)',
      source: 'https://commons.wikimedia.org/wiki/File:Immanuel_Kant_-_Gemaelde_1.jpg',
      license: 'Public domain',
    ),
    Credit(
      title: 'ニーチェ',
      author: 'Friedrich Hermann Hartmann',
      source: 'https://commons.wikimedia.org/wiki/File:Nietzsche187a.jpg',
      license: 'Public domain',
    ),
    Credit(
      title: 'ウィトゲンシュタイン',
      author: 'Moritz Nähr',
      source: 'https://commons.wikimedia.org/wiki/File:Ludwig_Wittgenstein_1929.jpg',
      license: 'Public domain',
    ),
    Credit(
      title: 'サルトル',
      author: '作者不明（オランダ国立公文書館所蔵）',
      source: 'https://commons.wikimedia.org/wiki/File:Jean_Paul_Sartre_1965.jpg',
      license: 'CC BY-SA 3.0 nl',
    ),
    Credit(
      title: 'ボーヴォワール',
      author: 'Moshe Milner',
      source: 'https://commons.wikimedia.org/wiki/File:Simone_De_Beauvoir_(cropped).jpg',
      license: 'CC BY-SA 3.0',
    ),
    Credit(
      title: 'ミル（ボス戦）',
      author: 'London Stereoscopic Company（c. 1870）',
      source: 'https://commons.wikimedia.org/wiki/File:John_Stuart_Mill_by_London_Stereoscopic_Company,_c1870.jpg',
      license: 'Public domain',
    ),
  ]),
  CreditSection('プロローグ・ひたちゃんの背景', '縮小し、紙芝居の札のように少しくすませて使用', [
    Credit(
      title: '『帝国の推移：未開の状態』(1836) / Thomas Cole',
      author: '',
      source: 'https://commons.wikimedia.org/wiki/File:Cole_Thomas_The_Course_of_Empire_The_Savage_State_1836.jpg',
      license: 'パブリックドメイン',
    ),
    Credit(
      title: '『帝国の推移：牧歌的状態』(1836) / Thomas Cole',
      author: '',
      source:
          'https://commons.wikimedia.org/wiki/File:Cole_Thomas_The_Course_of_Empire_The_Arcadian_or_Pastoral_State_1836.jpg',
      license: 'パブリックドメイン',
    ),
    Credit(
      title: '「夜の渋谷スクランブル交差点」（2024）/ Syced',
      author: '',
      source: 'https://commons.wikimedia.org/wiki/File:Shibuya_scramble_av_night_from_Stream.jpg',
      license: 'CC0 1.0',
    ),
    Credit(
      title: '『帝国の推移：荒廃』(1836) / Thomas Cole',
      author: '',
      source: 'https://commons.wikimedia.org/wiki/File:Cole_Thomas_The_Course_of_Empire_Desolation_1836.jpg',
      license: 'パブリックドメイン',
    ),
    Credit(
      title: '『ローマの景観：コロッセオ』（Vedute di Roma）/ Giovanni Battista Piranesi / The Metropolitan Museum of Art 所蔵',
      author: '',
      source:
          'https://commons.wikimedia.org/wiki/File:Veduta_dell%27Anfiteatro_Flavio_detto_il_Colosseo,_from-_%27Vedute_di_Roma%27_(Views_of_Rome)_MET_DP104275.jpg',
      license: 'CC0 1.0',
    ),
  ]),
];
