# UI-01B — Procedural neon city board

## Scope

The city board now presents a compact midnight miniature city inspired by the approved reference artwork. It does **not** embed the image as a background: all visual elements are original, resolution-independent Godot 2D draw commands.

### New layers

- `CityBoardArt`: static board, city skyline, roads, three destination houses, depot, trees, lamps, fountain and bench. Draws on resize only.
- `CityBoardOverlay`: active route glows, chevrons, gold interactive junctions, guide ring and color+symbol delivery carts. Redraws while a shift is running.
- `CityBoardGeometry`: shared cubic Bezier evaluator for road polylines and cart positions; uses unchanged `BoardState.NODES` and `BoardState.EDGES`.
- `BoardView`: builds layers, owns touch hit testing, forwards guide state and route changes; it **does not** own scoring or movement.

### Graph correctness

No gameplay routes, score values, spawn schedules, win/loss rules, or path-selection logic were changed. A cart is rendered at the Bezier point matching its actual `current_node`, `next_node` and `progress`. A new graph edge cannot be drawn by accident: geometry rejects invalid edges. The overlay shows the selected outgoing branch at each junction.

### Responsiveness and visual priorities

- Houses keep red diamond, blue circle and green triangle identifiers.
- All art scales to the board's actual control size. House and cart sizes adjust with small screens.
- Decorative objects avoid main junction nodes and never consume input.
- Background drawings do not redraw on every physics frame; only active overlays do.
- Existing generous junction touch targets remain unchanged.
- This is procedural, stylized 2D approximation. The concept art is a high-fidelity *art direction reference*; pixel-perfect replication and artist-authored sprites are future polish work.

## Local verification

```powershell
cd "C:\Users\gauravp\Projects\Parcel-pulse"
git switch main
git pull --ff-only origin main
$godot = "C:\Godot\Godot_v4.7.2-stable_win64_console.exe"
& $godot --headless --path . --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw "Import failed" }
& $godot --headless --path . --script res://tests/test_ui_city_board.gd
if ($LASTEXITCODE -ne 0) { throw "City board regression failed" }
& $godot --path .
```

For the complete import → core/UI/guide/design/city regression → Android export gate, use `tools/build_android_debug.ps1`.

## Android visual sign-off

Capture screenshots at 360×780, 393×852 and at least one taller device. Check that the three houses and shapes fit without clipping; the depot stays below the switch; branches are visibly connected; carts track the road center; the guide ring never hides arrow direction; scenery does not obstruct taps; the board maintains a usable size with the bottom controls visible. Record screenshot diffs before and after. These checks are **pending** until run on real hardware.

## Next milestone

UI-01C — feedback and movement polish (subtle junction tap animations, delivery score floats, route glow animation, sound and a clean pause/result presentation). No paid assets or backend needed.
