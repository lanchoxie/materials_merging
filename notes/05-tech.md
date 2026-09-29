# 05 · Tech choices

## Engine: stay on Godot 4.7 (GDScript)
We were free to switch engines/languages. We don't, because:
- ~16k lines of working gameplay, versioned saves and 60+ tests would be thrown away.
- Godot already exports to Android + Web from this repo, with a portable toolchain in `tools/`.
- The problems are feel, goals and visuals — all solvable inside Godot.

Where other languages *do* help:
- **Python (numpy)** — `dev/gen_audio.py` synthesizes every sound effect and ambience loop
  (additive/FM synthesis, envelopes, simple reverb). Deterministic, license-free, re-generatable.
- **GLSL (Godot shading language)** — sky, water, glass, sway shaders (must run on GL Compatibility).
- **Bash** — `dev/run_tests.sh` test runner.

## New architecture pieces (added incrementally, no big-bang refactor)

- **Autoloads** (the project had none):
  - `Sfx` (`scripts/core/sfx.gd`): named sound bank, voice pool, per-sound pitch jitter,
    `play(name, pitch := 1.0, volume_db := 0.0)`, music/ambience cross-fade, persisted settings.
    Fails silently when a sound is missing or in headless mode (keeps tests clean).
  - `Fx` (`scripts/core/fx.gd`): UI-space juice — `pop_text`, `coin_burst(from, to)`, `punch(control)`,
    `flash(color)`. Pure tweens on a top CanvasLayer; no particles needed for UI.
- Gameplay code calls `Sfx`/`Fx` at the moment an action *succeeds* (never on failure paths except
  the explicit error sound), so feedback always matches real state.

## Conventions
- Match existing style: tabs, dense one-liners are tolerated but new code prefers readable functions.
- UI strings in Chinese.
- New constants go in `data/*.json` when they are balance numbers.
- Every new system gets a headless test in `tests/`.
