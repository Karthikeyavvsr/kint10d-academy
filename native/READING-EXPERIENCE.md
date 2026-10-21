# Reading and resource resume — 21 October 2026

## Delivered behaviour

- Section bookmark buttons display a persistent filled bookmark and “Place saved · resume here”. A successful new save adds local confirmation. Failed writes retain existing data and report an error.
- Continue Learning ignores completed bookmarked lessons, falls back to the first unfinished lesson, and shows a completion message when all chapters are read. The Island resume link follows the same selection rule.
- The end of each chapter offers “Mark chapter read & continue” and a separate next-chapter link that does not change completion. Reading a chapter does not mark its linked courses completed.
- Settings labels, outlined entry surfaces, helper text and primary-action buttons distinguish editable fields from explanations.
- Resource and paper links open an in-app WKWebView reader. Today offers the last resource. Per-resource checkpoints use the existing atomic progress store and sync protocol, using hashed bookmark keys, without changing old progress records.

## Automatic tracking scope

Ordinary supported course pages save their URL and vertical scroll offset. Supported YouTube embeds use the official IFrame API to capture video identity, playback seconds and available playlist position. An ended playlist item checkpoints the next known item at zero seconds. Playback is not automatically treated as understanding or course completion.

The reader checkpoints approximately every five seconds while active and attempts a final checkpoint on background/close. The last received checkpoint is retained if a final JavaScript reply is unavailable. A recent few seconds can be lost on abrupt termination. Page layout changes can move a saved scroll position.

Academy cannot observe activity in standalone YouTube, Safari or another app, or retroactively recover that activity. It cannot infer that lecture 3 means lecture 4 is next unless an actual playlist supplies that relationship. Some embeds, PDF viewers, consent pages, dynamic players or site policies do not expose usable position. The UI distinguishes page-only checkpoints from video checkpoints and offers an external-browser fallback. Login/authentication routes are not recorded. General page query strings are not stored, so query-driven course pages may not restore precisely. No credentials or page text are extracted.

The JavaScript checks use a mock player. Live playback/playlist resume across real services and two devices still requires acceptance testing; compilation is not evidence that every third-party player supports tracking.

## Learning rationale

The small daily step, end-of-chapter recall prompt and spaced-review feedback support an existing practice-first curriculum. No missed-day penalty or streak requirement was added. They are product choices informed by research, not a claim of proven motivation gains for this app.

- Carpenter, Pan & Butler (2022), *The science of effective learning with spacing and retrieval practice*: https://doi.org/10.1038/s44159-022-00089-1
- Learning Scientists, practical spacing/retrieval explanations: https://www.learningscientists.org/learning-scientists-podcast/2018/3/7/episode-14-how-students-can-use-spacing-and-retrieval-practice
- YouTube IFrame API: https://developers.google.com/youtube/iframe_api_reference
- YouTube WebView identity and embed requirements: https://developers.google.com/youtube/terms/required-minimum-functionality

## Verification

- 16 AcademyCore tests pass, including completed bookmarks, unfinished bookmarks and stale bookmarks.
- Five mock-player checks pass: resume seek, playback checkpoint, next playlist item, final item, and unstarted video not receiving a playback checkpoint.
- iOS simulator build passed. Physical installation and live resource playback acceptance are recorded separately in VERIFICATION.md.
