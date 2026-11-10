# ひたテツ TODO — finishing up

Code freeze: **11/10 19:00**. The deployed URL must stay live until **11/14** (Regional Day).

## 🔴 Must do (in this order)

- [ ] **Mailbox fix**: Rio found something wrong; describe what happens and Claude fixes it
- [ ] **Push to GitHub**: `cd ~/Programming/哲学 && git push` (23+ local commits)
- [ ] **Check the live site** (https://hitatetsu-d93b9.web.app) in an incognito window:
  - [ ] prologue + music on first tap
  - [ ] one AI grading **or** one boss attack works (tests App Check with the reCAPTCHA key)
  - [ ] saving: reload and check 記録 / EXP are still there
- [ ] **Turn App Check enforcement on**: Firebase → App Check → APIs → Firebase AI Logic → Enforce (only after the AI works on the live site)
- [ ] **Budget alert** on the billing account (Cloud console → Billing → Budgets & alerts)
- [ ] **著作物利用シート TODOs**:
  - [x] BGM 「The Final Deduction」: who made it / which AI tool, source, license or terms
  - [x] BGM 「The Stone Library」(ホーム): who made it / which AI tool, source, license or terms
  - [x] BGM 「Archive of Stillness」(リール): who made it / which AI tool, source, license or terms
  - [x] BGM 「Fiddles in the Clover」(ひたちゃんの画面): who made it / which AI tool, source, license or terms
  - [x] Logo: who made it, which AI tool
  - then Claude adds both to the in-app クレジット screen
- [ ] **Team review of the new トロッコ問題 card** (transplant surgeon; Claude wrote it, questions should be human-written): `app/lib/data/topics.dart`
- [ ] **Final deploy before 11/10 19:00**: `flutter build web --release` (no `.env.local.json`, no `DEMO_RECORDS`) → `firebase deploy --only hosting`
- [ ] Check whether the repo must be **public** for judging

## 👥 Teammates

- [ ] Product doc (template)
- [ ] Demo video (tip: run with `--dart-define=DEMO_RECORDS=true` for a filled profile / 記録 / battles)
- [ ] Pitch slides — story: "an AI that won't think for you; it makes you think, and we can measure it"

## ⚠️ Don't

- Don't put `.env.local.json` or any API key in the build or the repo
- Don't unlink billing or delete the project before 11/14
- After changing app text, re-run `app/tool/subset_fonts.py` (fonts contain only the characters in use)

## Later (after the hackathon)

- English mode
- 「この言葉を調べる」 with Gemini + Google Search grounding
- BigQuery → Looker Studio dashboard
- Account system (names, icons)
