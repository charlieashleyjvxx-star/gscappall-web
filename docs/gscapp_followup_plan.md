# GSCapp Follow-up Development Plan

This plan compares the mature React/Tauri implementation in `D:\GSCapp\gushici-app`
with the current Flutter implementation in `D:\GSCAPPALL`. The goal is not to
copy pages one by one, but to close the remaining product loops in the order
that most improves daily learning.

## Current Position

`GSCAPPALL` has already passed the basic migration stage.

- Core poem data, local SQLite storage, search/filter, details, favorites, daily poem, study cards, reading, recitation, dictation/evaluation, wrong book, learning history, profile switching, sync metadata, and report storage are all present.
- Android has a runnable build and real-device installation path.
- Pinyin display, study-card notes, daily check-in, points, spaced review basics, and report history have first usable versions.
- Speech recognition is intentionally no longer treated as the final scoring source. `sherpa_onnx` remains an offline auxiliary recognizer until a real speech assessment provider is connected.

The next stage should focus on making existing loops complete and stable before adding large new game modes.

## Lessons From Old GSCapp

The old project has several mature loops worth borrowing:

- User loop: `UserSelectPage.tsx` and `database.ts` support create, switch, update, delete users, user favorites, and user-scoped learning records.
- Daily poem loop: daily poem selection, completion, check-in records, user points, consecutive days, history, and review count are implemented together.
- Assessment loop: `AssessmentHome`, `AssessmentQuiz`, `AssessmentReport`, `AssessmentDetail`, `AssessmentWrongBook`, and `assessmentService.ts` cover quick/custom assessments, multiple question types, reports, knowledge stats, progress, and wrong-answer storage.
- Dictation loop: `DictationMode.tsx` has difficulty, fill/full modes, speed, loop mode, hints, scoring, wrong character analysis, encouragement, and learning record persistence.
- Game loop: poetry jielong, line jielong, feihualing, and challenge map have independent services and clear scoring rules.

## Recommended Priority

### P0 Stabilization

These are not flashy, but they protect all later work.

- Keep fixing red-screen paths around dialogs, profile editing, note editing, and route returns.
- Expand multi-profile automated tests to cover favorites, daily poem completion, study-card review/note, wrong questions, reports, points, and settings.
- Finish sync payload tests for all profile-scoped tables, especially `user_points`, `daily_poem_records`, `study_card_progress`, `practice_reports`, and `wrong_questions`.
- Continue Android smoke automation around profile switching, permission denial, recording, playback, report writing, and no Flutter red screen.

### P1 Learning Loops

These map directly to old-project strengths and should come before new games.

- Daily poem center: improve history calendar, review entry, points explanation, consecutive-day display, and profile-scoped stats.
- Study cards: finish review scheduling UI, due/new/mastered filters, note preview, self-test mode polish, and review outcome explanation.
- Dictation page: upgrade from current independent entry to a full training page with difficulty, fill/full mode, line playback, hints, wrong-character analysis, and report persistence.
- Assessment center: split assessment home, quiz, report detail, history trend, and weak-point stats into clearer pages instead of keeping too much in one placeholder page.
- Wrong book: add knowledge-point/type/difficulty grouping, weak-area summary, and grouped retry entry.

### P2 Profile And Growth

These make the app feel like a complete learning companion.

- Profile center: expose points, streak, badges, recent reports, daily poem status, due study cards, and weak areas in one coherent dashboard.
- Achievement system: add badge rules for streaks, completed poems, review consistency, dictation accuracy, and wrong-book cleanup.
- Learning report: add weekly/monthly trend, score bands, mode distribution, weak-point clusters, and parent-friendly summary copy.

### P3 Game Migration

These should start only after the learning/report/profile loops are stable.

- Poetry line jielong first: it is data-local, fun, and easier to validate than full poem jielong.
- Feihualing second: reuse character matching, hints, scoring, and used-poem tracking from the old service.
- Challenge map third: depends on assessment question types, progress persistence, stars, and unlock rules.

### Blocked Or Deferred

- Formal speech assessment remains deferred until a vendor account and test audio set are available.
- iOS real-device validation remains a separate platform task requiring macOS/Xcode.
- Real cloud sync service integration should wait until local profile-scoped payload tests are green for every synced resource.

## Suggested Parallel Workstreams

Worker A: Stability and multi-profile isolation.

- Add/extend tests for profile-scoped data.
- Reproduce and fix remaining dialog red-screen cases.
- Verify provider invalidation after profile switch.

Worker B: Daily poem and study cards.

- Polish daily poem history/review/points UI.
- Finish study-card review filters and self-test polish.
- Add widget/provider tests for due-card logic.

Worker C: Assessment, dictation, and wrong book.

- Extract assessment home/report/detail into clearer modules.
- Upgrade dictation training interactions.
- Add wrong-book grouping and grouped retry.

Worker D: Sync and Android regression.

- Complete sync payload coverage for all profile-scoped resources.
- Strengthen Android smoke scripts for no-red-screen, permissions, recording, playback, and report persistence.
- Keep manual smoke checklist aligned with new flows.

## Next Implementation Slice

The best next slice is:

1. P0 stability and profile isolation tests.
2. Daily poem and study-card polish.
3. Assessment center extraction plus dictation upgrade.
4. Wrong-book grouped statistics.
5. Only then start jielong/feihualing/challenge migration.

This order keeps the app stable while raising the value of the learning core before investing in larger game surfaces.
