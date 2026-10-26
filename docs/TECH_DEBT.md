# Known gaps and technical debt

Written down rather than left implicit. Ordered by how much each one matters
for a hosted app that strangers are expected to play.

**Closed:** the board used to be invisible to assistive technology — a
`CustomPaint` is one opaque rectangle to a screen reader. It now publishes a
semantics node per cell via `CustomPainter.semanticsBuilder`, built from the
same `BoardRender` snapshot the painting uses, so the two cannot drift. See
`test/semantics_test.dart`.

## 1. Nothing is persisted

Reloading the page loses the board, the clock and the move counters. For a page
someone opens from a link, closes, and comes back to, that is the most likely
first disappointment.

Deliberately not fixed yet because the obvious route conflicts with a stated
design goal: the app has **zero runtime dependencies**, and both
`shared_preferences` and raw `dart:js_interop` localStorage access would put
platform code into what is currently a pure-Dart state layer. The clean version
is a small `storage.dart` port with a web implementation and a stub, keeping
`GameController` unaware of either.

## 2. The WasmGC build has only been verified by compiling it

`flutter build web --wasm` succeeds and the dry run passes, but headless Chrome
would not render it during development, so every visual check in this repo was
made against the CanvasKit build. Before shipping the `--wasm` target to real
users, open it in Chrome, Firefox and Safari and confirm it paints — Safari has
no WasmGC and must fall back to the JS build.

## 3. First load is heavy

About 2.1 MB gzipped on the WasmGC path, roughly 1.5 MB of which is the Skia
renderer. That is Flutter web's floor, not something this app controls, but it
is a real cost for a casual link click and worth knowing before choosing
Flutter for something like this again. It caches after the first visit; serve
with Brotli.

## 4. Difficulty names oversell the top tier

`Tricky` means "dug as deep as uniqueness allows", and on 9×9 only about half of
those boards actually require a guess. The app reports the truth per-puzzle in
the status panel, but the tier name implies more than it guarantees. Either
generate-and-reject until the board genuinely needs search, or rename the tier.

## 5. Correctness feedback reveals the solution

Wrong digits turn red immediately and correct ones lock. That is the original
app's design and it is right for a trainer, but it does mean a player can
brute-force a cell by trying digits until one sticks. A "no feedback" mode for
people who want the deduction to stay honest would be a one-line addition to
`GameController.isLocked` plus a toggle.

## 6. Puzzle generation runs on the UI thread

Worst case ~24 ms on the VM, so one or two dropped frames when a new puzzle is
requested, and only then. Flutter web has no isolates on `dart2js`, so moving it
off-thread is not a simple `compute()` call. Acceptable as it stands; if the
difficulty tiers ever dig deeper, it will need chunking across frames.

## 7. Layout tests depend on test-font metrics

`phone layouts give the board the whole screen` passes partly because the test
font makes every glyph a full em square, which is *harsher* than reality —
useful, since it caught a genuine title overflow. But it means the test asserts something
slightly different from what a browser does, and a real overflow in a
proportional font could slip past it. Golden tests over the painter would cover
the visual side properly; there are none.

## 8. Hover repaints via `setState`

`BoardView` rebuilds its subtree whenever the hovered cell changes. It is
guarded so this happens once per cell crossed rather than per pointer move, and
the repaint is one canvas layer — but a `ValueNotifier<int?>` feeding the
painter directly would avoid the widget rebuild entirely.

## 9. Skin and brightness choices are not remembered either

Same root cause as item 1: nothing is persisted. Picking Terminal and reloading
puts you back on Slate. One `storage.dart` port would fix both.

## 10. Smaller things

- The original's `'?'` "unsure" marker was not restored. It wrote a literal
  `'?'` into the board, which the model has no state for; a real third state
  would need engine support.
- No error reporting, so a crash in someone's browser is invisible.
- The service worker is Flutter's default: it caches, but there is no update
  prompt, so a returning player may sit on a stale build for a session.
- `docs/screenshots/` are committed PNGs totalling ~650 KB, already halved and
  palette-quantised. Easy to forget when adding more.
- The radial menu's arc holds about five actions before items collide; the
  limit is the label width, and it is only documented, not enforced.
- Contrast is the one thing here that defends itself: the audit iterates
  `Skin.all`, so a new skin is measured the moment it is listed. Nothing
  equivalent guards the *structural* points above.
