# Sudoku Trainer

A Sudoku app built to *teach* Sudoku. It plays 4×4, 6×6 and 9×9 boards, shows
you the candidates for every empty cell, and — when you get stuck — names the
technique that cracks the next cell and explains why it works.

Flutter, targeting the web first. No runtime dependencies.

![The hint system explaining a deduction](docs/screenshots/hint-dark.png)

## Why the three board sizes

They are a learning ladder, not a gimmick:

| Size | Boxes | What it teaches |
| --- | --- | --- |
| 4×4 | 2×2 | The three constraints, with almost nothing to search |
| 6×6 | **2 rows × 3 cols** | Box scanning, where boxes are *not* square |
| 9×9 | 3×3 | The real game |

The 6×6 case is the interesting one. Its boxes are two rows tall and three
columns wide, so every piece of the engine — geometry, generation, the notes
layout inside a cell — has to handle non-square boxes rather than assuming
`√n × √n`.

## What it does

**Candidate marks.** Every empty cell can show the digits its peers still
permit, struck off live as you fill the board. This is the single biggest
"oh, I see it" feature, and it is the same computation the solver runs.

**Explained hints.** Press `H` and the app names the technique and the
reasoning — *"In this column, 4 fits nowhere except row 7, column 3"* — then
highlights the cells that justify it. Hints are answers you can check, not
answers you have to trust.

**Live conflict feedback.** A repeated digit is flagged the moment you enter
it, with the peer it collides with highlighted. If the board has become
unsolvable in a subtler way (a blank cell with no legal digit left), the app
says so rather than letting you grind on a dead position.

**Honest difficulty.** `Gentle` and `Steady` boards are *provably* finishable
by deduction alone. `Tricky` digs as deep as uniqueness allows and then tells
you the truth about what it produced — roughly half of 9×9 `Tricky` boards
genuinely require a guess, and the app says which.

| Candidates | Light | Narrow |
| --- | --- | --- |
| ![](docs/screenshots/candidates-dark.png) | ![](docs/screenshots/board-light.png) | ![](docs/screenshots/mobile-dark.png) |

## Controls

Fully playable from the keyboard, which is how most people will use it on the web.

| Key | Action |
| --- | --- |
| `1`–`9` | Enter a digit (press again to clear) |
| Arrows / `WASD` | Move the selection |
| `Backspace` / `Delete` | Erase |
| `N` | Notes (pencil-mark) mode |
| `C` | Toggle candidate marks |
| `H` | Explain the next move |
| `Space` / `Enter` | Place the explained move |
| `Ctrl`+`Z` / `Ctrl`+`Shift`+`Z` | Undo / redo |
| `Esc` | Dismiss the hint, then clear the selection |

## Architecture

```
lib/
  engine/     pure Dart, zero platform imports — runs on web, iOS and the VM
    variant.dart    board sizes, precomputed units and peers
    solver.dart     constraint propagation + search
    puzzle.dart     immutable puzzle, difficulty tiers
    generator.dart  generate-and-dig with a uniqueness check
    hint.dart       candidates, conflicts, explained hints
  state/
    game_controller.dart   the board being played, undo/redo, clock
  ui/
    board/          the canvas board: painter, glyph cache, hit testing
    theme.dart      colour scheme + board design tokens
```

The `engine/` directory imports nothing but `dart:math`. That is the whole
iOS-portability story: there is no platform code to port, and the engine is
covered by tests that run on the Dart VM in about a second.

### The solver

Peter Norvig's constraint propagation. After every assignment, two rules run to
fixpoint, and what survives is searched most-constrained-cell-first:

1. If a cell has one candidate left, eliminate it from that cell's peers.
2. If a unit has only one place left for a digit, assign it there.

Candidates are **bitmasks** — bit `d-1` set means digit `d` is still possible —
so a cell is one `int` and propagation is bit arithmetic. Masks are at most 9
bits, which stays inside the 32-bit range that bitwise operators guarantee on
every Dart backend, `dart2js` included. A 9×9 board with the minimum 17 clues
solves in about 2 ms.

Those two rules are exactly the naked-single and hidden-single techniques, which
is what makes the difficulty claim checkable: a board is "solvable by deduction
alone" precisely when propagation alone finishes it.

### Generation

Fill a random complete board, then remove clues one at a time, keeping each
removal only while the board still admits **exactly one** solution. Uniqueness
is re-checked on every dig. Worst case is ~24 ms on the VM, and it only happens
when you start a puzzle, never while you play.

### Why the board is one canvas

The board is a single `CustomPaint`, not a widget per cell. A 9×9 grid showing
candidates needs several hundred glyphs, and laying those out every frame is
what makes a canvas board stutter — so digits are laid out once into a
`GlyphCache` and reused until the cell size or colours change. Cell boundaries
are snapped to whole physical pixels, without which an arbitrary width divided
nine ways puts grid lines on fractional pixels and the whole grid renders soft.

## Running it

```bash
flutter pub get
flutter run -d chrome          # development
flutter test                   # 71 tests, ~5s
flutter analyze
```

Build for the web:

```bash
flutter build web --release            # CanvasKit
flutter build web --release --wasm     # skwasm (WasmGC), with a JS fallback
```

### Deploying

Serve with **cross-origin isolation** or the renderer silently drops to a single
thread:

```
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Serve `.wasm` and `.js` with Brotli. Be aware of what Flutter web costs: the
WasmGC path is ~2.1 MB gzipped on first load, and ~1.5 MB of that is the Skia
renderer itself — a framework floor, not something the app controls. It caches
after the first visit.

## Status

Chrome-first and feature-complete for the web. iOS is the next target; the
platform scaffolding is current and the engine needs no changes to get there.

The application id is `io.github.conatarun.fsudoku` — a neutral namespace, worth
changing before any store submission.

## History

This started years ago as a first Flutter project and was rewritten in 2026. The
original was pre-null-safety Dart 2.7 with six abandoned UI dependencies and
`dart:io` imports that could never have compiled for the web. The constraint
solver survived the rewrite; everything above it is new.

## License

MIT — see [LICENSE](LICENSE).
