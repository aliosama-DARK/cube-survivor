# Cube Survivor — v1.0.1 Publish & Handover

**Status:** Release-ready. Version `v1.0.1` (shown in the main menu, `Main.gd:9`).

## Release deliverables (this session — Batch 12)
- **Game icon** — original blue-cube-in-arena art replacing the default Godot
  robot: `icon.svg` (source) + `icon_512.png`. Baked into the web export.
- **Cover image** (itch.io, 630×500): `cover.png` (source `cover.svg` + title
  composited with the in-game Cairo font).
- **Screenshots** for the store page (in `screenshots/`, all current as of v1.0.1):
  `screen_menu, screen_charsel, screen_diff, screen_stage1, screen_stage3` (new Frozen Expanse),
  `screen_boss, screen_pause` (new menu), `screen_levelup, screen_stats` (Synergies discovered), `screen_shop`.
- **Changelog:** `CHANGELOG.md` (full v1.0 feature list).
- **Store copy (EN + AR):** `ITCH_PAGE.md` — tagline, description, tags, controls.
- **Web build (v1.0):** re-exported to `build/web/`; mirrored to `docs/`
  (GitHub Pages); zipped for upload as `cube-survivor-web.zip` (index.html at root).

## Publish to itch.io (needs your account — pick one)
**Option A — drag & drop (easiest):**
1. Go to https://darklawh.itch.io/cube-survivor/edit
2. **Uploads** → replace the HTML build with `cube-survivor-web.zip`
3. Flag it **"This file will be played in the browser"**, viewport **1280×720**, Save.
4. Set the **cover image** to `cover.png`.
5. Add the **screenshots** from `screenshots/`.
6. Paste the description/tags from `ITCH_PAGE.md`.

**Option B — butler CLI (repeatable):**
```
butler login
butler push build/web darklawh/cube-survivor:html5 --userversion 1.0
```

## GitHub Pages (optional, same build)
`docs/` is refreshed with the v1.0 build. Commit & push to publish:
```
git add -A && git commit -m "v1.0 release: icon, cover, screenshots, web build" && git push
```

## What's in v1.0 (short)
Full art direction (semantic palette: you=blue, danger=red, boss=purple,
reward=gold), 5 stages + 6 bosses, blessings with rarity/reroll, full
meta-progression (Cinders, permanent shop `[U]`, unlockable characters, 12
achievements, Ascension `[T]`), records + versioned saves, onboarding tips,
full settings incl. EN/AR. See `CHANGELOG.md` for the complete list.

## Verification
- Parse clean; all 8 scenes render; perf **~172 fps avg, <10 ms worst frame**.
- Screenshot-regression goldens updated for changed screens.
- Web export succeeds; zip has `index.html` at root; icon baked in.

## Dev tools left in (zero runtime cost)
- Screenshot harness: `godot --path . -- --shot=<menu|settings|play|boss|levelup|over|shop|stats|victory> --shotout=<png>`
- Perf benchmark: `godot --path . -- --bench`

## Git status
Changes are **uncommitted** (I don't commit without asking). Suggested:
```
git checkout -b v1.0-release
git add -A && git commit -m "v1.0 release"
```
