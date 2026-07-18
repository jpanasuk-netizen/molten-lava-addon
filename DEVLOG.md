## Dev Story: How Molten Holy Power Was Built

Molten Holy Power (StarBar) started as a simple idea: a Paladin Holy Power bar that felt **good** to use in real combat, not just a functional meter.

### From Idea to First Working Bar

- The original concept was a magenta/gold combo meter on the target nameplate.
- That quickly expanded into a row of five animated stars floating above the target plate, tracking:
  - Holy Power pips (0–5)
  - Avenging Wrath / Crusade (wings)
  - Wake of Ashes (dawnlights window)
  - Combined AW + WoA priority state

The first versions proved the idea out, but they relied heavily on aura polling and had plenty of quirks.

### Slaying the AW / WoA / Dawnlights Dragons

Avenging Wrath broke more than once:

- Aura checks for AW were unreliable in live play. The bar sometimes failed to flip into the wings mode even though the buff was clearly visible.
- The fix was to abandon aura polling and use **cast-based timing** for Avenging Wrath and Crusade:
  - When you cast AW/Crusade, the script arms a timer and trusts the cast as the truth.
  - No more guessing about buff APIs.

Wake of Ashes brought its own logic:

- WoA should arm a 3-spender “dawnlights” window.
- Spenders should decrement the dawnlights counter, but only once per real spend.
- The script now tracks:
  - `dawnlightsLeft`
  - `dawnlightsExpire`
  - spenders vs. generators
  - large power drops (3+ points) to catch burst spends

Together, AW + WoA got a clear visual hierarchy:
- Both active: brightest, deepest, strongest mode.
- WoA only: strong, but calmer than both.
- AW only: bright wings state.
- Normal: readable Holy Power stars with subtle motion.

### Holy Power Sound System (v13.x)

The Holy Power sound system was promoted to a **major** release at v13.0:

- A clean bell “ding” fires when you use a generator at capped Holy Power (5).
- It works on the first capped generator and every one after — no double-tap, no random delay.
- All builders are covered, including the full Templar Strikes combo:
  - Templar Slash (406647)
  - Templar Strike (407480)

Early builds guessed wrong on Templar IDs; the final version reads actual spell IDs in-game and wires in the correct ones, making the ding system reliable across the combo.

### Debugging Like an Engineer

Molten Holy Power went through real debugging cycles:

- `scriptErrors` were turned on and tracked via BugGrabber/BugSack when possible.
- The script was instrumented with `[StarBar CAST]` and `[StarBar DEBUG]` prints to trace:
  - spell IDs
  - names
  - current Holy Power
  - dawnlights and wings state
- Multiple “diagnostic builds” existed just to narrow down:
  - whether failures were hard Lua errors,
  - render/anchor problems,
  - or cross-addon conflicts.

One major discovery: fatal reloads were being caused by a **separate Plater mod** (“MF Cast Highlight”) calling `CheckRange` with nil data, not by the StarBar script itself. Once that mod was disabled, StarBar stabilized and the optimization work could proceed cleanly.

### Performance Rewrites (v13.1 → v15.x → v20.0)

After the sound system was solid, the focus shifted to performance:

- v13.1 fixed a structural issue: the “one-time” setup block wasn’t truly one-time, causing lag as it rebuilt frames too often.
- v15.0+ rewrote the starbar internals with performance as the top priority:
  - Removed expensive per-frame texture rotations.
  - Removed per-frame star repositioning churn.
  - Anchoring now updates only when the target nameplate changes.
  - The render loop is throttled (not every frame) while preserving combat feedback.

The final visible optimized build reuses the original global frame name (`BigJ_StarBar_Final`) so Plater actually reconstructs the bar when the script is updated.

### Shipping to GitHub and CurseForge

Molten Holy Power is not just a local script:

- It lives as a real GitHub project (`molten-lava-addon`) with:
  - version tags,
  - release notes,
  - and readable Lua code.
- It’s published as a CurseForge addon, visible on the website and propagating to the desktop app.

The project moved through:

1. An initial working idea.
2. Multiple rounds of combat testing and visual tuning.
3. Sound-system completion and major release tagging.
4. Structural and performance fixes.
5. Cross-addon conflict resolution.
6. Final performance-first v20.0 release.

### Where It Goes From Here

v20.0 is intentionally treated as one of the “final” releases for this product:

- The core behavior is stable and refined.
- The performance profile is sane for modern WoW + Plater environments.
- The addon has a clear identity: a bespoke Holy Power bar that feels good for Retribution Paladin play.

Future work, if any, will likely be small quality-of-life improvements or spin-off utilities rather than major rewrites.
