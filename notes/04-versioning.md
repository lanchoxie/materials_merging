# 04 · Version management — nothing old gets lost

## Where the old versions live

| What | Where |
|---|---|
| v0.7.0 – v0.19.0 releases | git tags `v0.7.0` … `v0.19.0` (+ `codex/*` branches, `master`) |
| v0.20.0 + all 0.21.0 previews (backpack-10 → interiors-18) | commit `7db2272`, tag **`archive/v0.21.0-interiors-18`** |
| v0.22.0 "Juice" | branch `claude/v0.22-fun-pass`, tag **`v0.22.0`** (save v21) |
| v0.23.0 "Goals" | branch `claude/v0.23-goals`, tag **`v0.23.0`** (save v22) |
| v0.24.0 "Discovery" | branch `claude/v0.24-discovery`, tag **`v0.24.0`** (save v23) |
| Old APKs / source zips | `builds/` (git-ignored, never overwritten — build script refuses to overwrite) |

> The v0.20/v0.21 work had **never been committed** (the repo is owned by a different Windows
> account, so git refused to run). It was snapshotted as-is on 2026-09-29 before any change.
> Git commands on this machine need: `git -c safe.directory=C:/Users/xiety/Desktop/game_dev/materials_merging …`
> (or run once: `git config --global --add safe.directory C:/Users/xiety/Desktop/game_dev/materials_merging`).

To play/inspect any old version: `git switch --detach <tag>` (then `git switch -` to come back),
or `git worktree add ../atom-<tag> <tag>` to have it side by side.

## Branch & tag scheme for this track

- One branch per release: `claude/v0.22-fun-pass`, `claude/v0.23-goals`, … Each new branch starts
  from the previous release tag. Branches are never deleted.
- Release = annotated tag `v0.22.0`, `v0.23.0`, … on the final commit of the branch.
- Numbering starts at **0.22.0**: the name `0.21.0` is left to the preview series already published.
- `project.godot` `config/version` is bumped in the release commit.
- Commits are small and themed (audio, fx, editor feel…) so any single feature can be reverted.

## Save compatibility

- Root save version is currently **23** (v21 = original, v22 = goals + saved_at, v23 = codex). Any release adding persistent
  state bumps it and adds a migration branch + a test that loads an older fixture.
- Pure-cosmetic settings (volume, mute) live in `user://settings.cfg`, **not** in the save, so they
  never affect save compatibility.

## QQ delivery automation — heads-up

`docs/DELIVERY-POLICY.md` describes an external 6-hourly automation (ID `qq`) that sends an APK
every 10 formal releases counted from 0.14.0 (0.15–0.20 = 6 so far). New `v0.x.0` tags on this
track would count toward that. This track does **not** send anything to QQ, build APKs or edit
`RELEASES.md`; the user decides. If 0.21–0.24 all became formal releases, 0.24.0 would be the
tenth, and the next expected send point.
