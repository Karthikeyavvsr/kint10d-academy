# Reading and learning design

Reviewed 15 October 2026. This design is a practical interpretation of the sources, not a clinical or controlled evaluation of this app.

## Reading comfort

Warm neutral paper with dark green accents in light mode; dark neutral reading surfaces with lighter green accents in dark mode. Semantic primary/secondary text is used rather than hard-coded low-contrast paragraph colours. Long text sits on opaque surfaces. Material is reserved for system chrome and navigation.

- [Apple: materials](https://developer.apple.com/design/human-interface-guidelines/materials) — separate controls from content; do not make long reading depend on a moving translucent background.
- [Apple: typography](https://developer.apple.com/design/human-interface-guidelines/typography) — hierarchy and readable type.
- [Apple: Dynamic Type](https://developer.apple.com/documentation/uikit/scaling-fonts-automatically) — respect the reader's preferred size. SwiftUI text styles and scaled reader metrics support this.
- [Apple: Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/liquid-glass) — use native navigation materials, with older-OS fallback.
- [WCAG contrast rationale](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum) — 4.5:1 for normal text, 3:1 for large text. This is a design target, not a claim of a complete accessibility audit.

Colours themselves are not claimed to improve learning. The user can choose System, Light or Dark, enlarge reader text, and use system accessibility settings. A full VoiceOver, extreme text-size and physical-device audit remains part of device acceptance testing. Charts also show numerical values and explanations; animation respects Reduce Motion.

## Learning mechanisms

- [The Learning Scientists: retrieval practice](https://www.learningscientists.org/retrieval-practice) — recall before opening the worked answer.
- [The Learning Scientists: spaced practice](https://www.learningscientists.org/blog/2016/8/18-1) — revisit material across days.
- [Spacing and retrieval practice in learning, Nature Reviews Psychology](https://doi.org/10.1038/s44159-022-00089-1) — overview of the evidence and practical conditions.

The app offers worked examples, self-explanation, one-question checks and a simple review schedule. The schedule is a transparent heuristic (successful recall doubles the interval up to 30 days; unsuccessful recall returns to one day), not a validated personalised memory model. Completing a page does not prove understanding. External projects, unseen problems and reviewer feedback are still necessary.

## Friendly progress

Avoid streak penalties and false deadlines. Show remaining reading effort, separate planned pace from observed completion pace, and disclose what is not included. Wait for enough recent history before displaying an observed estimate. The display is deliberately approximate and can change.

## Privacy and notifications

- [Apple: local notification scheduling](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app).
- [Apple: access to selected directories](https://developer.apple.com/documentation/uikit/providing-access-to-directories).
- [Apple: developer accounts](https://developer.apple.com/help/account/basics/about-your-developer-account).

No Screen Time access, ad tracking or other-app activity inspection. Notifications are requested only when the user enables a chosen reminder time. Dynamic Island is not a permanent arbitrary overlay; any future character must use supported APIs and a meaningful user-initiated activity.
