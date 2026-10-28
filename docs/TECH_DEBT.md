# Known gaps and technical debt

Written down rather than left implicit. Ordered by how much each one matters
for a hosted app that strangers are expected to play.

**Closed so far:**

- **The board was invisible to assistive technology.** It now publishes a
  semantics node per cell via `CustomPainter.semanticsBuilder`, built from the
  same `BoardRender` snapshot the painting uses. See `test/semantics_test.dart`.
- **Nothing was persisted.** A game in progress and the presentation choices
  now survive a reload, through a ~90-line `KeyValueStore` port backed by
  `localStorage` on web and an in-memory stub elsewhere. No dependency, no
  database: the payload is one or two kilobytes of JSON.
- **The WasmGC build had only ever been compiled, never seen running.** It is
  now verified in Chrome 152: `main.dart.wasm` and `skwasm.wasm` load and the
  board paints, both with cross-origin isolation (multi-threaded) and without
  it (single-threaded). The earlier headless failures were an artefact of
  `--virtual-time-budget`, which starves the workers skwasm needs.
- **Correctness feedback revealed the solution.** That behaviour is now
  **Training** mode, and **Play** mode flags only rule breaks — a legal-but-
  wrong digit stays put, and correct cells do not settle, so a cell cannot be
  brute-forced by watching for the lock.

## 1. First load is heavy

2.18 MB gzipped on the WasmGC path (3.52 MB if a browser falls back to
CanvasKit), roughly 1.5 MB of which is the Skia renderer either way. That is
Flutter web's floor, not something this app controls, but it is a real cost for
a casual link click and worth knowing before choosing Flutter for something
like this again. It caches after the first visit; serve with Brotli.

## 2. Difficulty names oversell the top tier

`Tricky` means "dug as deep as uniqueness allows", and on 9×9 only about half of
those boards actually require a guess. The app reports the truth per-puzzle in
the status panel, but the tier name implies more than it guarantees. Either
generate-and-reject until the board genuinely needs search, or rename the tier.

## 3. Puzzle generation runs on the UI thread

Worst case ~24 ms on the VM, so one or two dropped frames when a new puzzle is
requested, and only then. Flutter web has no isolates on `dart2js`, so moving it
off-thread is not a simple `compute()` call. Acceptable as it stands; if the
difficulty tiers ever dig deeper, it will need chunking across frames.

## 4. Layout tests depend on test-font metrics

`phone layouts give the board the whole screen` passes partly because the test
font makes every glyph a full em square, which is *harsher* than reality —
useful, since it caught a genuine title overflow. But it means the test asserts something
slightly different from what a browser does, and a real overflow in a
proportional font could slip past it. Golden tests over the painter would cover
the visual side properly; there are none.

## 5. Hover repaints via `setState`

`BoardView` rebuilds its subtree whenever the hovered cell changes. It is
guarded so this happens once per cell crossed rather than per pointer move, and
the repaint is one canvas layer — but a `ValueNotifier<int?>` feeding the
painter directly would avoid the widget rebuild entirely.

## 6. Smaller things

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
