# Miko companion

Miko is an original grey-and-white husky companion. This feature changes no curriculum, broker integration, credentials or progress format.

## Behaviour

- Tiny 56-point walking artwork on a reserved 43-point ledge above the native navigation/status area. Eight gait frames run at 12 fps while walking, with position sampled at up to 30 fps, with pauses at either end of a short route.
- Lesson readers show a 49-point glasses-and-paws pose behind the ledge, with occasional blinking. Motion uses easing at each end. The pet cannot intercept taps or overlap lesson content.
- On iPad layouts with top navigation, the companion retains its bottom reading ledge rather than pretending the tab bar is at the bottom.
- Settings → Miko offers a persistent device-local visibility toggle. Reduce Motion uses static artwork. Animation pauses when the scene is inactive. Decorative artwork is hidden from VoiceOver.
- Start companion session explicitly creates a local ActivityKit Live Activity. No push server, APNs token or notification permission is needed for this feature.
- Leaving the app during that session starts a break timer. Returning resumes study. The activity link opens Academy and the most recent manually saved lesson bookmark when available.
- Sessions become stale after one hour; the UI then says the session finished and stops showing the break timer. Returning to the app ends expired activities. Users can end a session in Settings at any time.
- iOS controls presentation and background scheduling. Force-quit is not a guaranteed end callback. A stale Lock Screen card can remain until the OS or user dismisses it. No promise of continuous animation in the Island, other-app monitoring, or automatic deletion at force-quit.
- The separate in-app visibility toggle does not terminate a user-started Live Activity; use End companion session for that.

## Implementation

`Shared/MikoSprite.swift` crops a bundled 4 × 3 transparent PNG once and resamples frames to a 24-point intrinsic size for ActivityKit. App and widget reuse the same original character. Native SwiftUI handles position; the atlas changes the actual leg pose. `App/MikoCompanion.swift` owns decorative motion and the local session lifecycle. `MikoWidget` is an embedded WidgetKit extension with compact, minimal, expanded and Lock Screen layouts. The extension only receives session times, never notes or credentials.

`academy://resume` is a local deep link with no sensitive parameters. Session timing is device-local, separate from progress sync.

## Asset provenance

`Resources/MikoAtlas.png` was produced with the built-in image generation tool on 2026-10-15. Original character design, generated for this project. No third-party mascot or downloaded asset.

Prompt: “Production 2D animation sprite atlas of an original adorable fluffy silver grey and white baby husky with blue eyes, black nose, upright ears, natural symmetrical white face mask, softly rendered premium 3D film aesthetic. Exactly 4 columns by 3 rows equal square cells, canvas aspect 4:3, no text, no dividers, no shadows outside character, genuinely transparent background. Each character fits fully within central 80 percent of its cell, same scale and baseline. Rows 1 and 2: eight sequential looping WALK CYCLE frames in reading order, side view facing right, anatomically coherent alternating four puppy paws, tail curved, subtle bounce, clear leg movement, consistent face and coat, not eight identical poses. Row3 col1: front-facing husky head and two front paws peeking over invisible wall, wearing small round charcoal reading glasses, eyes open. Row3 col2 same reading pose blinking with eyes closed. Row3 col3 cheerful front facing husky head no glasses for tiny Dynamic Island portrait. Row3 col4 relaxed front face same no glasses. Preserve space between cells for independent cropping. This is a game-ready sprite sheet, no UI no typography no scenery no accessories except glasses in the two reading cells. Make husky very cute with rounded features and fine soft fur, not vector not sketch. Clear silhouette at small size.”

## Validation

See `qa/miko-*.log` for local build results (ignored by Git). Debug-only launch flags `--miko-preview-reading` and `--miko-preview-session` provide reproducible simulator entry points; production release builds ignore them. Test portrait/landscape, large text, Reduce Motion, hidden companion, lesson return, background/resume, session end, stale content and URL routing on physical hardware before claiming full device validation.

## Apple references

- https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities
- https://developer.apple.com/documentation/widgetkit/dynamicisland
- https://developer.apple.com/videos/play/wwdc2023/10194/
