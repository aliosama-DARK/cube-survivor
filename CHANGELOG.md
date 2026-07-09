# Cube Survivor — Changelog

## v1.2.1 (2026-07) — Progression, Upgrade Clarity & Character Select Polish
- **Clear level caps** — passives now cap at 3 levels (with stronger per-level
  values: +10 damage, +15% fire rate, +30 HP, +10% crit, +12% speed), side
  weapons stay at 4, and the new **Signature Core** upgrade gives your
  signature weapon 5 levels of +15% damage each (doesn't occupy a slot,
  doesn't boost side weapons).
- **Owned-first choices** — anything you own gets +35% offer weight; weapons
  one level from max +60%; partner passives +50% (double when their weapon is
  maxed). Builds deepen instead of sprawling.
- **Faster, earlier evolutions** — recipes can now trigger right after the
  first boss (Stage 3 at the latest), and boss rewards can headline an
  evolution from the second boss.
- **Stronger opening** — the first three level-ups always lead with a weapon
  (or Signature Core) option: the build starts in minute one.
- **Upgrade milestones** — Deathblow Lv3 makes crits ignite; Swift Dash Lv3
  pulls gems on every dash (plus the existing Steel Plates Lv3 shield and
  Magnet Lv3 XP bonus). Descriptions state the milestones.
- **Character select redesigned** — compact stat rows, a one-line fantasy
  tagline with automatic ellipsis, and a fixed six-line info card (Weapon /
  Q / Playstyle / Difficulty / Strength / Weakness). No text ever overflows
  the panel.

## v1.2 Phase D (2026-07) — Boss Rework vs the New Power System
Bosses now answer evolved builds with mechanics, not stat walls.

- **Shell phases** — at 75% and 40% HP the boss hardens for 3s: a bright
  pulsing shell (takes only 20% damage), a slow rotating barrage, a minion
  wave, and a "The boss hardens its shell!" toast. A repositioning beat, not
  an HP wall.
- **Adaptive shell** — if a burst build melts 18%+ of the boss's HP within a
  4s window, the shell triggers early (max 4 shells per fight, 11s internal
  cooldown). Burst-evolution builds get punished specifically; slow builds
  never see extra shells.
- **Logical side-weapon resistance** — bosses take 70% damage from side
  weapons (kunai/chain/spikes/orb); your **signature weapon stays at full
  boss damage**. Side weapons rule the crowds, signatures duel the bosses —
  an identity rule, not a nerf (side weapons unchanged vs everything else).
- **Boss HP recalibrated** for the evolution era: 850 / 2600 / 4100 / 6100 /
  8600 — measured so a 0-meta baseline still fights Bone King in ~66s (in
  target) while a maxed Blade Storm build improved from 14-25s melts to
  25-46s fights with no more free wins.
- Enemy AI decisions are now staggered (spawn-time jitter) so crowds don't
  re-steer in sync.
- Evolutions untouched — Blade Storm/Shatter Mark/Thunder Storm all verified
  firing in the test harness after the rework.

## v1.2 Phase B/C (2026-07) — Slots, Side Weapons, Passives, Evolutions & Boss Rewards
The run now has two acts: fill your slots (expansion), then deepen what you
chose and chase an Evolution.

- **Slots system** — Signature weapon is fixed and never appears as a pick;
  **3 side-weapon slots** and **4 passive slots**. Once a slot type is full,
  no new items of that type appear — only upgrades of what you own (and
  Evolutions when earned). A "Weapons 2/3 • Passives 3/4" line sits above
  every level-up choice.
- **6 side weapons** (all with 4 levels): *Kunai* (piercing knives — the
  ranged compensation for melee characters), *Frost Orb* (orbiting chill
  zone), *Orbit Spikes* (reworked orbit blades), *Lightning Chain* (reworked
  Sky Lightning), *Bomb Launcher* (crowd blasts, Lv4 leaves burning ground),
  *Marked Shot* (marks every 5th hit; marked take bonus damage from all
  sources and burst at Lv3+).
- **Passives** — new generic *Focus* (-8% Q/side-weapon cooldowns) and
  *Reach* (+12% aura/blast/wave size), plus **8 partner passives**: Precision,
  Frozen Core (all slows deeper), Gunpowder, Conductor, Bulwark Core, Crit
  Core, Aura Core (aura shoves), Speed Core.
- **8 Evolutions** — side weapon at Max + its partner passive + (Stage 3 or
  2 bosses defeated): Blade Storm (returning kunai), Eternal Winter (blizzard
  + brief per-foe freeze), Meteor Fall (friendly telegraphed meteors), Thunder
  Storm (+3 leaps, bosses resist), Thorn Halo (bigger ring, shoves, -15%
  contact damage), Shatter Mark, Soul Pulse (Soul Steal + Aura Core), Frost
  Runner (Frost Trail + Speed Core). Evolution cards show gold "before →
  after" lines, an EVOLUTION! stamp, a distinct chime, and a celebration
  burst on pick. Legacy recipe evolutions (Polar Storm etc.) retired.
- **Smarter card flow** — weapons one level from Max get +60% offer weight;
  partner passives get +50% (double once their weapon is maxed); each
  character prefers the weapons that fit them (Soldier→Kunai/Chain,
  Shinobi→Frost/Spikes/Speed Core, Gambler→Marked/Crit Core, Titan→Bomb/
  Bulwark, Knight→Spikes/Kunai, Fire Aura→Orb/Aura Core). Cards now show
  type + level ("Weapon Lv 2→3" / "Passive NEW") and a gold "Evolution path"
  marker when a pick advances a recipe.
- **Boss rewards deepened** — after boss 2+, partner passives for your owned
  weapons become prime candidates; evolutions still headline boss 3+ rewards.
  No chests, no random power spikes.

## v1.2 Phase A (2026-07) — Signature Weapons, Q Abilities & Character Identity
First phase of the v1.2 rework: every survivor is now a different game.

- **New roster** (old saves migrate automatically): Soldier, **Fire Aura** (was
  Burner), **Shinobi** (was Runner), **Knight** (was Wrecker), Titan,
  **Gambler** (was Specter).
- **Exclusive signature weapons** — the universal autogun is gone:
  - *Soldier — Marksman Rifle*: slow, precise, piercing shots.
  - *Fire Aura — Living Flame*: no bullets; the aura stacks Burn (DoT) that
    keeps ticking after enemies leave it.
  - *Shinobi — Shadow Cut*: no bullets; **3 dash charges** and the dash itself
    slices everything passed through (brief i-frames).
  - *Knight — Twin Blades*: two orbiting swords scaling with your damage.
  - *Titan — Seismic Pulse*: rhythmic shockwaves with knockback (rate scales
    with Fire Rate).
  - *Gambler — Loaded Dice*: spinning dice shots with +15% base crit.
- **Q abilities** (Q key / gamepad X, HUD readiness indicator, per-char CD):
  Soldier deploys an 8s **Turret** (50% damage, lures chasers); Fire Aura lays
  a burning **Fire Trail** (+10% speed); Shinobi summons a **Shadow Clone**
  (3 dash cuts at 25%); Knight goes **Berserk** (5s: faster/stronger blades,
  +25% speed); Titan slams **Earthbreaker** (huge wave + knockback); Gambler
  plays **All In Roll**.
- **All In Roll** — a real gamble on a visible d6: 1 = lose 20% current HP
  (never lethal), 2 = -15% damage 8s, 3 = +15% damage, 4 = +25% crit,
  5 = +40% damage & +20% crit, 6 = **JACKPOT: every hit crits for 5s**.
  Dramatic die animation over the player, result text, 20s cooldown.
- **Visual identity** — each survivor has a distinct silhouette (visor cube /
  cracked volcanic cube / sharp slim diamond with scarf / armored cube /
  wide heavy slab / rounded die with pips), secondary accent colors, and
  skin data defined for later unlocks. Dice bullets spin; turret/clone/berserk
  /roll all have clear visuals.
- **Character select** — full identity card: weapon, Q (+cooldown), playstyle,
  strength, weakness, difficulty.
- **Smart pools** — projectile/fire-rate blessings no longer appear for
  characters whose signature can't use them.
- Close Punish retuned so melee archetypes are legal: it now only punishes
  hugging the boss's body (not fighting at blade/aura range), with longer
  grace and cooldown for melee signatures.

## v1.1.5 (2026-07) — Blessing Depth & Evolution Paths
The run should feel like building a machine, not picking the biggest number.

- **Blessing categories** — every blessing is now Foundation (plain stats),
  Effect (small gameplay twist) or Engine (build-defining). Each level-up now
  composes its cards: one Foundation + one Effect/Engine + one free slot —
  a boring triple-stat roll is impossible while alternatives exist.
- **Stage-gated rarity** — per-stage odds (C/R/E/L): Stage 1 70/30/0/0,
  Stage 2 58/32/10/0, Stage 3 45/34/18/3, Stage 4 38/34/22/6, Stage 5
  32/34/25/9. Rares can appear from minute one; Epics only after the first
  boss; Legendary only from Stage 3.
- **Two new Effect blessings** — *Shard Seed* (Rare: slain foes have a
  12%/rank chance to burst into shards — Wrecker's AoE engine-starter) and
  *Close Call* (Rare: a shot grazing you grants +12% damage & +8% speed for
  2s — Runner's risk/reward tool).
- **Three new Evolution paths** (6 total now, each with visible build
  requirements on the gold card):
  - *Thunder Loop* = Sky Lightning x2 + Quick Trigger x2 + Kill Wave —
    bolts leap 2 further and every 12 kills auto-calls a storm strike.
  - *Frost Runner* = Swift Dash x2 + Frost Trail + Agility x2 — 40% wider
    trail, stronger slow, and foes dying on it burst into frost (0.5s CD).
  - *Shatter Mark* = Deathblow x2 + Marked Target + Explosive Death — marks
    every 4th hit and marked foes detonate on death.
- **Boss rewards (no chests)** — after every boss a "BOSS REWARD" choice of
  three: deepen an owned blessing / a build candidate (Rare effect after boss
  1, Epic after boss 2, a ready Evolution after boss 3+) / Second Chance
  (+1 reroll). Rerolling the reward screen itself is disabled.
- Character build paths flow through the existing blessing-weight system
  (Runner→Dash/Speed effects, Specter→Crit/Mark, Wrecker→AoE/Shards,
  Titan→Defense, Burner→Sustain, Soldier→4-card first pick).

## v1.1.4 (2026-07) — Enemy & Boss Intelligence Update
Behavior-only pass: smarter enemies and fuller boss fights with fair telegraphs
— no blanket HP/damage increases.

- **Enemy roles** (light steering, AI decisions every 0.25s — not per-frame):
  - *Chasers* (norm) unchanged — the readable baseline.
  - *Fast* enemies predict your path (target = position + velocity x 0.35s,
    capped at 150px) from Stage 2; from Stage 3, ~40% become **flankers** that
    swing in from your side instead of your face (55% at Danger III+).
  - *Shooters* keep an ideal 200-320px band — approach when far, back off when
    close, only fire inside the band, and side-step after each shot.
  - *Bombers* aim at your escape path (velocity x 0.30s) and no longer explode
    instantly on contact: within 100px they arm a **0.55s fuse** — rapid white
    blinking, slow down, and show the blast-radius circle. Dash out = alive.
  - *Tanks* cut ahead of your movement (velocity x 0.50s) to squeeze space.
  - *Elites* get the enhanced version of their role (half flank from Stage 3)
    and keep the Wound shot.
- **Group pressure** — bombers/tanks often spawn on the screen edge ahead of
  your movement direction; running in one straight line stops being free.
- **Boss brains**:
  - **Close Punish** — hugging a boss for 1.2s triggers a pulsing red warning
    ring (0.6s; 0.8s on the tutorial boss) then a shockwave slam + bullet
    ring. Dash out during the warning and you take nothing. 6s cooldown.
  - **Anti-kite by personality** (after 4s at 470px+): Meadow Warden sends
    chasing minions (gentle, tutorial); Frost Heart drops a telegraphed freeze
    zone under you; Magma Beast flashes white for 0.5s then dashes at you;
    Bone King / Void Shade / Ash King fire a homing volley.
  - Arena fill (minion waves + telegraphed hazards) and Phase-2 intensity
    carried over from v1.1.3, unchanged.
- **Fairness rules** — every new attack telegraphs 0.4-0.8s with visuals +
  a sound cue; no instant damage; Stage 1 keeps simple AI (no prediction, no
  flanking, softer punish) so new players learn safely.
- **Dev tool** — `--aidebug` overlays flanker markers, prediction lines, boss
  punish/kite timers.

## v1.1.3 Hotfix (2026-07) — Initial Canvas & Web Viewport Fix
The game could appear as a small rectangle with black/white space around it on
first load (mobile, and sometimes desktop/itch embeds).

- **Stretch settings hardened** — `display/window/stretch/aspect="keep"` (and
  fractional scale) is now explicit in project settings: the 1280x720 canvas
  always scales to fit the real window, centered with letterboxing, at any
  window/iframe size. Mouse coordinates transform automatically.
- **First-frame web fix** — some browsers (especially inside the itch.io
  iframe) report a non-final canvas size on the first frame, so scaling was
  computed against the wrong size. The game now waits two frames after boot,
  re-applies the content-scale settings against the final size, and redraws.
  A `size_changed` handler re-syncs on every later window/iframe resize.
- **HTML/CSS enforcement** — the export now injects head CSS: zero
  margin/padding, black background, block-level centered canvas, and no
  max-width/height clamping — no white page background can leak around the
  game.
- **Mobile portrait** — instead of a broken thin strip, portrait orientation
  now shows a clear "Rotate your device for the best experience" overlay
  (Arabic + English); it disappears the moment the device rotates.
- **Boot debug** — the browser console now logs window/viewport sizes at boot
  and after the two-frame fix, for diagnosing any future embed issues.

## v1.1.3 (2026-07) — Feedback Update: Better Blessings, Stage 3 Flow, Boss Pressure
Response to first player feedback (movement/dash/bosses praised; bland upgrades,
stage-3 stall, kiteable bosses, and an audio-slider mouse bug reported).

- **Audio slider mouse fix** — clicking anywhere on a volume slider now sets
  the value from the mouse position, and dragging works in both directions
  (it could only increase before). Toggle rows still cycle on click; keyboard
  A/D controls unchanged; values clamp 0-10 and save as before.
- **Six new effect blessings** (icons, tags, rarities, drawbacks included):
  - *Frost Trail* (Rare) — dashing leaves a slowing frost trail for 2s.
  - *Marked Target* (Rare) — every 5th hit marks a foe; marked foes burst into
    shards on death.
  - *Magnetic Surge* (Rare) — every 30 gems: full vacuum pull + a small pulse.
  - *Boss Breaker* (Rare) — dash near a boss to gain +25%/rank boss damage
    for 3s (rewards fighting inside the boss dance, synergizes with the new
    anti-kite pressure).
  - *Soul Pulse* (Rare) — Soul Steal heals also knock nearby foes back; only
    offered once you own Soul Steal (no extra healing, pure utility).
  - *Guardian Cube* (Epic) — an orbiting cube fully absorbs one significant
    hit, recharging in 20s (Lv2 14s); visible bright when ready, dim while
    recharging.
- **No more triple-stat choices** — the level-up roll now refuses to show
  three pure stat cards together: if that happens and an effect blessing is
  available, one card is swapped for it. Chain Lightning and friends surface
  much more often as the "build-changing" option.
- **Stage 3 anti-stall** — soft XP catch-up: +12% XP while in Stage 3 below
  level 12, +10% while in Stage 4+ below level 14 (struggling players recover;
  strong players unaffected). Stage 3 bomber spawn weight eased slightly.
- **Boss arena pressure (no HP added)** — during boss fights: a small minion
  wave every 12-18s fills the arena (and feeds gems); staying 470px+ away from
  the boss for 4s triggers a homing pressure volley (anti-kite); telegraphed
  meteor hazards drop near the player every 9-14s. At 50% HP (enrage) waves
  and hazards come faster — the existing phase system plus fuller arenas.
  Boss HP unchanged to respect the duration targets.

## v1.1.2 (2026-07) — Polish Pass: Clarity, Identity, and UI Cleanup
Presentation-only pass (no balance changes except removing chests).

- **HP numbers** — the health bar now shows a live `82 / 100` readout centered
  inside it; the number flashes softly red on damage and green on healing.
- **Character identity in gameplay** — your survivor's body is drawn in their
  own color during runs (not always blue): Burner red, Runner green, Wrecker
  purple, Titan steel, Specter pale. Readability is kept with an ink outline
  behind the sprite plus the bright blue core that always marks "you".
- **Blessing icons** — every blessing card now carries a procedural pixel icon
  (bullet, chevrons, shield, droplet, snowflake, crown, orbit ring…) tinted by
  rarity; evolutions get a gold sparkle. The synergy hint moved to a subtle
  gold marker on the tags line instead of squeezing the description.
- **Stage transitions** — a quick, smooth banner (fade + slide, ~2s) with the
  stage title replaces the abrupt center text, and the harsh transition sting
  was removed (replaced with a soft low chime; boss-intro sweep much quieter).
- **Message cleanup** — secondary messages (tips, meteors warning, golden
  horde, Frozen!, lord-fallen) moved to a small bottom toast; the big center
  text is reserved for boss warnings, boss names, synergies and evolutions.
  All combat text (WOUNDED, toasts, banners) is force-cleared the moment you
  leave gameplay — nothing leaks over menus, character select or pause.
- **Chests removed** — elite surprise boxes (free random blessing) and the
  guarded-treasure event are gone entirely (spawn, logic, draw, minimap
  marker): free power spikes undermined the value of builds and permanent
  upgrades. Random events are now meteor shower / golden horde.
- **Stats sidebar fixed** — armor % now reflects the real 8%/rank formula and
  Recovery/Soul Steal show their rank instead of stale v1.0 numbers.

## v1.1.1 (2026-07) — Playtest Calibration Pass
Numbers-only calibration of v1.1.0, driven by ~140 automated bot playtest runs
(new `--autoplay` harness) plus per-run debug balance reports.

- **Runner is a movement specialist now** — kept: highest speed cap, best dash,
  +1 reroll. Removed: +10% Cinders and the rarity-luck bonus; XP bonus cut to
  +5%. Damage penalty eased 0.82 → 0.85 (her boss fights measured far over
  target).
- **Soldier identity** — beginner-friendly: his **first level-up offers 4
  blessing cards instead of 3** (works with keys 1-4, mouse and hover).
- **Recovery tightened** — activates after 6s unhurt, heals 1 HP per 3s at all
  ranks; ranks raise the per-stage cap only (6/9/12 HP, Burner 10/14/18); heals
  up to 50% max HP (55% at rank 3, 65% Burner). Still off in boss fights.
- **Soul Steal tightened** — per-stage caps 8/12 HP (Burner 12/16), boss-death
  bonus is +3/+4 HP by rank; Burner's kill-requirement discount removed (his
  edge is the caps + heal power).
- **Enemy speed is gradual** — per-stage multipliers 1.00 / 1.08 / 1.15 /
  1.22 / 1.30 replace the old global formula; early stages feel fair again.
- **Boss durations calibrated to targets** (S1 35-60s … S5 90-140s) — boss HP
  is now a measured per-stage table (850 / 2300 / 3700 / 5300 / 7400, Ash King
  x2). Measured after tuning: S1 ~40-50s, S2 ~40-45s, S3 ~50-70s on normal
  builds.
- **Stage 4-5 wall softened (measured, not guessed)** — bombers were the #1
  killer even at 100% upgrades: bomber blast 22 → 19 damage, bomber spawn
  weight reduced in stages 4-5; enemy HP per-player-level scaling 0.08 → 0.07
  so damage upgrades keep their value late.
- **Rarity really means rarity** — card weights are now normalized per rarity
  class, so the on-screen odds match the intended 45/33/18/4 late-game split;
  Execution Core (Legendary) actually appears now (it never showed up in 100
  logged runs before the fix).
- **Wound clarity** — orange HP bar + a persistent "WOUNDED - healing blocked"
  HUD tag + a distinct sound sting the moment it lands.
- **Dev tooling (zero player impact)** — `--autoplay=N --meta=0..1 --char=0..5
  --danger=0..5` bot harness that plays full headless runs and prints per-run
  balance summaries (damage dealt/taken, healing by source, peak DPS, death
  cause, per-boss fight durations) plus an aggregate report; test modes never
  touch the player save.

## v1.1.0 (2026-07) — The Balance Pass
Full balance rework: character identity, real rarity, restrained healing, and a
harder campaign where Permanent Upgrades genuinely matter.

- **Character identity** — every survivor now has a unique strength no one else
  can reach, plus a real weakness: Burner is the only true self-healer (Soul
  Steal/Recovery are ~50% stronger for him, weaker shots); Runner is the only one
  who can exceed the speed cap, gets +1 reroll, +10% XP/Cinders and luckier
  rarities, but is frail with weak shots and 25% weaker healing; Wrecker and
  Titan have hard fire-rate floors (they can never reach top attack speed);
  Titan alone gets huge HP/armor but a speed cap; Specter alone can reach 75%
  crit (others cap at 50%) but heals at 60% effectiveness. Each survivor also
  has **blessing weights** — they see blessings matching their identity far more
  often.
- **Real rarity** — appearance odds now shift by run phase (Stage 1:
  70/25/5/0 → Stages 4-5: 45/33/18/4 for Common/Rare/Epic/Legendary). No Epic
  power hides at Common anymore: Extra Volley, Soul Steal, Heavy Core are Epic;
  Execution Core is a true Legendary that can't appear before Stage 3.
- **Healing reined in** (all healing flows through one capped hub):
  - *Lifesteal removed* — replaced by **Soul Steal** (Epic): 1 HP per 10 kills
    (rank 2: per 7), elites count x3, **disabled during boss fights**, hard cap
    per stage; boss kills grant a small burst instead.
  - *Regeneration reworked* into **Recovery** (Rare): only after 5s without
    taking damage, can't exceed 60% max HP, off during bosses, capped per stage.
  - *Vampiric Edge* now needs Deathblow x3, heals 2 HP at 35% chance with a 2s
    cooldown, never from side projectiles.
  - **Wound**: from Stage 3, elite shots block ALL healing for 4s (HP bar turns
    orange). Bosses cut generic healing by 50% (65% at Danger II+).
- **Projectiles capped** — Extra Volley is Epic, max 2, side shots deal 50%
  damage (35% vs bosses) and cost -10% fire rate; Overcharge needs Quick
  Trigger x3 and costs -8% fire rate; total bonus projectiles hard-capped at +3.
  Side shots don't trigger Vampiric/Shatter procs.
- **Boss anti-cheese** — crits deal x1.5 vs bosses (not x2), explosions/AoE deal
  65%, Execution Core bonus halved, Danger V bosses attack 15% faster.
- **New & reworked blessings** — Giant Slayer (+20% vs bosses/elites), Kill Wave
  (every 25 kills: damaging slow pulse), Heavy Core (+40% damage, -12% fire
  rate, -8% speed), Execution Core (every 5th volley x2); Agility grants a
  post-dash speed burst; Steel Plates Lv3+ adds reactive half-damage plating;
  Magnet Lv3+ converts gems into bonus XP. Level-up cards now show rarity, tags
  and drawbacks (in orange) with real numbers.
- **Harder campaign** — enemy HP/damage/speed scale steeper per stage, spawns
  are denser, elites more frequent, bosses have ~35% more HP (Ash King x2) and
  smaller heal rewards (+25 HP, was +40), XP curve is slower. Stage 1 stays
  learnable; Stages 4-5 are brutal without Permanent Upgrades. Winning on a
  fresh save is possible but very hard — expect your first win after ~5-10 runs
  of upgrades.
- **Permanent Upgrades matter** — stronger tiers (+10 HP, +2 damage, +4% fire
  rate, -8% damage taken...) with cheaper early costs, and better Cinder payouts
  every run (even losses). Danger tiers are now rule changes: II = more
  shooters + harsher boss heal-cut, III = healing caps -20% + more elites,
  IV = faster traps + more bombers + early enrage, V = healing caps -35% +
  faster bosses.

## v1.0.1 (2026-07)
- **Arabic web font fix (critical)** — Arabic showed as empty boxes in the browser
  build (worked on desktop). Cause: the font was applied only via a runtime
  `load()`, which failed on web, falling back to the engine's Latin-only built-in
  font. Fixed by binding the embedded Cairo font through a project-level Theme
  (`res://ui_theme.tres`, `gui/theme/custom`) that the engine applies at startup,
  disabling system-font fallback (`allow_system_fallback=false`) so behavior is
  identical on web and desktop. Verified in a real browser (Menu, Settings,
  Upgrades all render shaped Arabic, no boxes). Credits screen now re-translates
  on language change too.
- **Web mouse navigation** — every screen is now fully usable with the mouse:
  a clear clickable **"< Back"** button on Upgrades, Records, Settings, Credits,
  Character Select and Difficulty; **Restart Run / Main Menu** buttons on the
  Game Over screen and a **Main Menu** button on Victory; all with hover/click
  feedback. Esc is now optional (handy on desktop, never required).
- **In-game Pause button** — a small `||` button (top-right) opens the pause
  menu with the mouse; the pause menu's Resume / Restart / Settings / Main Menu
  are all clickable, and Settings opened from pause returns to pause.
- **Restart / Main Menu confirmation** — a Yes/No prompt prevents losing a run
  by accident.
- **Font/glyph fix for web** — replaced Unicode symbols the game font lacks
  (arrows, currency mark, lock, pips, stars) that showed as empty boxes in the
  browser build with in-font glyphs or plain ASCII.
- **Full pixel-art stage redesign** — all five stages rebuilt with distinct
  floors, patterns, motifs and atmosphere: Verdant Grid (green digital grid),
  Crimson Pressure (pressure stripes), **Frozen Expanse** (new icy stage,
  replaces the old third stage), Golden Collapse (fractured amber), The Core
  (dark corrupted finale). Gameplay stays fully readable in every stage.
- **Fixed the Pause Menu** — it now shows a real, navigable menu instead of just
  a dim overlay.
- **Real pause options**: Resume / Restart Run / Settings / Main Menu (keyboard
  + mouse, Esc toggles; Settings returns to pause).
- **Added 10 Blessing Synergies** — combining certain blessings unlocks new
  effects (Arcane Orbit, Frost Pulse, Shatter Core, Vampiric Edge, Core
  Resonance, Dash Breaker, Momentum, Chain Storm, Bulwark, Overcharge).
- **Synergy discovery tracking** — a collection in Records (X/10 discovered),
  saved across runs.
- **Synergy hints in level-up** — cards that would complete a synergy show a
  “⚡ Synergy!” marker.
- **Improved replayability** through build combinations — a reason to keep
  playing after your first win.

## v1.0 — Release (2026-07)
First full release. From playable beta to a polished, shippable game with a
complete art direction, meta-progression, and onboarding.

### Front-end menus (pixel-art UI)
- **New pixel-art Main Menu** — vertical button list (Start Game, Upgrades,
  Records, Settings, Credits, Quit) with clear normal/selected/hover states,
  a cube emblem, and keyboard + mouse navigation.
- **Character Select screen** — pick your survivor with a large preview, the
  full roster, role, description, a five-stat readout (Health / Speed / Power /
  Defense / Luck), and passive. Locked survivors show their unlock condition.
- **Difficulty Select screen** — choose Normal or Danger I–V. Locked tiers are
  clearly marked and cannot be started; each tier lists its modifiers.
- **Credits screen.**
- Flow: Main Menu → Start Game → Select Survivor → Select Difficulty → Run.

### Art direction — "Arcane Cubes in a Corrupted Digital Arena"
- Unified semantic palette: **you are always blue** (#2F7BFF / highlight #8FD3FF),
  **danger/enemies are red-orange** (#E84A5F), **bosses are purple** (#9B5DE5),
  **rewards are gold** (#FFD166). You can read the battlefield at a glance.
- Backgrounds are calm and muted so gameplay elements always pop; no harsh
  strobing or repeated full-screen flashes.
- New original game icon (blue player cube in the arena).

### Stages & enemies
- 5 distinct stages with their own identity, palette accents, enemy mixes and
  titles: Verdant Grid → Crimson Pressure → Violet Trapfield → Golden Collapse → The Core.
- Enemy archetypes with readable silhouettes (chargers, shooters, bombers) —
  enemies never wear the player's blue.
- 6 bosses with health bars and telegraphed attack tells; boss frame-drops fixed
  (enemy-bullet draw batched, ~30× faster).

### Depth & progression
- **Blessings**: level-up upgrade cards with rarity tiers and reroll.
- **Meta-progression**: permanent currency (**Cinders**), a permanent-upgrades
  shop `[U]`, unlockable characters (Titan, Specter), 12 achievements, and
  Ascension / Danger tiers `[T]` after your first win.
- **Records & lifetime totals** screen; save format is versioned with safe
  fallbacks for older/partial saves.

### Feel & audio
- Screen shake, hit-stop, dash trails, particle VFX (all respect Settings).
- Audio hooks (SFX pool + per-stage/boss music) via the `Audio` autoload.

### Onboarding (new in v1.0)
- Contextual one-time tips teach the loop (move, gems, warning zones, bosses).
- Game-over screen points new players to the permanent-upgrades shop.
- **Tutorial Tips** setting to toggle tips on/off (persisted; reset with progress).

### Settings & accessibility
- SFX / Music volume, Screen Shake, Damage Numbers, Tutorial Tips, Fullscreen,
  Language (English / العربية). All effects respect these settings.
- Reset progress requires explicit confirmation.

### Performance (Web / HTML5)
- Worst-case gauntlet benchmark: **~172 fps avg, <10 ms worst frame**.
- Particle cap and batched draws keep it smooth in the browser.

### Under the hood
- Data-driven tuning in `data/balance.gd`; audio in `autoload/audio_manager.gd`.
- Screenshot-regression harness (`--shot=`) and perf benchmark (`--bench`).
