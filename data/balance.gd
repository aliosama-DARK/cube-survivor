extends RefCounted
# يُقرأ في Main عبر:  const Balance := preload("res://data/balance.gd")

# ============================================================
#  نظام الألوان الدلالي (Semantic palette) — "Arcane Cubes"
#  القاعدة: أزرق = أنت | أحمر/برتقالي = خطر/عدو | بنفسجي = زعيم
#           ذهبي = مكافأة/نادر/حَرِج | الأرضيات = ألوان مراحل باهتة غامقة
# ============================================================
const COL_INK := Color("12121a")          # حدود + أعمق ظل
const COL_TEXT := Color("ede8df")          # نص الواجهة (أوف-وايت)
const COL_TEXT_DIM := Color("9aa0aa")      # نص ثانوي/تلميحات
const COL_YOU := Color("2f7bff")           # البطل + رصاصك (أزرق)
const COL_YOU_HI := Color("8fd3ff")        # قلب/إبراز البطل والرصاص
const COL_ENEMY := Color("e84a5f")         # جسم العدو + رصاص العدو (خطر)
const COL_ENEMY_HI := Color("ff8a5b")      # قلب/توهّج الخطر (برتقالي)
const COL_BOSS := Color("9b5de5")          # الزعيم (حضور مميّز)
const COL_REWARD := Color("ffd166")        # جواهر/XP/مكافآت/نادر/حَرِج (ذهبي)
const COL_HEALTH := Color("4fd173")        # شريط الصحة (أخضر مقروء)
const COL_STEEL := Color("39435a")         # محايد/حجر/panels/دبّابة

# عائلة ألوان الأعداء (دافئة كلها — تفرّق النوع مش الخطورة)
const ENEMY_PAL := [
	Color("e84a5f"),   # أحمر — عادي
	Color("f0693c"),   # برتقالي محروق — سريع
	Color("b23b3b"),   # أحمر غامق ثقيل — دبّابة
	Color("e8804a"),   # كهرماني — منقسم
]

# ============================================================
#  الأبطال (Survivors) — v1.2: سلاح توقيع حصري + قدرة Q + هوية بصرية + skins
#  sig: "rifle" رصاص دقيق · "firebolt" كرات نار (انفجار كل 3 إصابات) · "crescent" سلاش قوسي
#       · "spinblade" سيوف دوّارة · "shockwave" موجات صادمة · "dice" نرد بكريت أعلى
#  (v1.2.3: Fire Aura → Pyromancer ساحر ناري · Shinobi بقى Shadow Slayer بسلاش + R Ultimate)
#  bw = أوزان بالوسوم · pw = أوزان بأسماء محددة (تفضيلات الأسلحة الجانبية v1.2 B/C)
# ============================================================
const CHARS := [
	{"name": "Soldier", "col": Color(0.36, 0.52, 0.34), "col2": Color(0.75, 0.80, 0.70), "role": "Tactician", "cost": 0, "hint": "",
		"desc": "A tactical survivor who wins by positioning, turrets, and controlled fire",
		"stats": [3, 3, 3, 3, 3], "passive": "First level-up offers 4 blessings",
		"sig": "rifle", "signame": "Marksman Rifle", "sigdesc": "Slow, precise, piercing shots",
		"qname": "Deploy Turret", "qdesc": "Place a turret for 8s (50% of your damage) - enemies get drawn to it", "qcd": 14.0,
		"playstyle": "Positioning / Precision", "strength": "Strong when holding ground", "weak": "Weaker while running around", "difficulty": "Low",
		"bw": {},
		"pw": {"kunai": 1.6, "chain": 1.6, "precision": 1.6, "conduct": 1.6},
		"skins": [{"name": "Green Soldier", "col": Color(0.36, 0.52, 0.34), "hint": "Default"},
			{"name": "Desert Soldier", "col": Color(0.72, 0.60, 0.38), "hint": "Reach Stage 3 with Soldier"},
			{"name": "Arctic Soldier", "col": Color(0.72, 0.80, 0.88), "hint": "Win with Soldier"},
			{"name": "Black Ops", "col": Color(0.20, 0.22, 0.26), "hint": "Win at Danger II+"}]},
	{"name": "Pyromancer", "col": Color(0.95, 0.42, 0.12), "col2": Color(1.0, 0.80, 0.25), "role": "Fire Mage", "cost": 400, "hint": "or 400 kills in a run",
		"desc": "A fire caster who burns groups with bolts, blasts, and explosive rhythm",
		"stats": [3, 3, 3, 3, 2], "passive": "Fire Bolts stack Burn - every 3rd hit erupts in a small explosion",
		"sig": "firebolt", "signame": "Fire Bolt", "sigdesc": "Mid-range fire bolts - every 3 hits explode",
		"qname": "Fireball", "qdesc": "Hurl a heavy fireball: big blast, burning ground, and Burn stacks", "qcd": 14.0,
		"playstyle": "Mid-range / AoE / Burn", "strength": "Great against small groups", "weak": "Less accurate and fragile up close", "difficulty": "Medium",
		"bw": {"AoE": 2.2, "Damage": 1.6, "Projectile": 1.2, "Defense": 0.8, "Healing": 0.5, "Sustain": 0.5},
		"pw": {"bomb": 1.6, "chain": 1.5, "gpow": 1.6, "area": 1.6, "mark": 1.3},
		"skins": [{"name": "Ember Mage", "col": Color(0.95, 0.42, 0.12), "hint": "Default"},
			{"name": "Blue Flame", "col": Color(0.35, 0.62, 0.98), "hint": "Reach Stage 4 with Pyromancer"},
			{"name": "Inferno", "col": Color(0.92, 0.18, 0.10), "hint": "Kill 500 in one run"},
			{"name": "Ashen Flame", "col": Color(0.55, 0.52, 0.50), "hint": "Win with Pyromancer"}]},
	{"name": "Shinobi", "col": Color(0.16, 0.20, 0.24), "col2": Color(0.30, 0.85, 0.55), "role": "Shadow Slayer", "cost": 250, "hint": "or reach Stage 3",
		"desc": "A fragile assassin who carves foes with fast crescent slashes and dashes",
		"stats": [3, 5, 4, 1, 3], "passive": "Crescent slashes at close-mid range - 3 dash charges (kills refund). Ultimate unlocks at Lv 7",
		"sig": "crescent", "signame": "Crescent Slash", "sigdesc": "Fast arc slashes at close-mid range (cleave)",
		"qname": "Shadow Assault", "qdesc": "Vanish and cut 3-5 nearby foes in a blur, then reappear (i-frames)", "qcd": 18.0,
		"rname": "Judgement Rift", "rdesc": "Freeze time briefly, then unleash multi-hit slashes across a wide area", "runlock": 7, "rcd": 60.0,
		"playstyle": "Melee / Hit-and-run", "strength": "Shreds packs with slashes and dashes", "weak": "Fragile - punished when cornered", "difficulty": "High",
		"bw": {"Speed": 2.0, "Dash": 2.0, "Crit": 1.4, "Damage": 1.3, "Magnet": 1.2, "Healing": 0.6, "Sustain": 0.6},
		"pw": {"orbit": 1.5, "mark": 1.5, "score": 1.8, "ccore": 1.4, "kunai": 1.3},
		"skins": [{"name": "Shadow", "col": Color(0.16, 0.20, 0.24), "hint": "Default"},
			{"name": "Jade", "col": Color(0.14, 0.35, 0.24), "hint": "Reach Stage 3 with Shinobi"},
			{"name": "Crimson", "col": Color(0.40, 0.12, 0.14), "hint": "x50 combo with Shinobi"},
			{"name": "Ghost", "col": Color(0.82, 0.86, 0.92), "hint": "Win with Shinobi"}]},
	{"name": "Knight", "col": Color(0.52, 0.56, 0.66), "col2": Color(0.30, 0.50, 0.90), "role": "Blade Wall", "cost": 600, "hint": "or beat 3 bosses in a run",
		"desc": "A close-range fighter protected by steel and spinning blades",
		"stats": [4, 2, 4, 4, 1], "passive": "Twin spinning swords guard him - everything close gets cut",
		"sig": "spinblade", "signame": "Twin Blades", "sigdesc": "Two orbiting swords - your reach is your armor",
		"qname": "Berserk", "qdesc": "5s: blades spin faster, +50% blade damage, +25% speed", "qcd": 15.0,
		"playstyle": "Melee / Sustain pressure", "strength": "Shreds whatever gets close", "weak": "Shooters and kiters outrange him", "difficulty": "Medium",
		"bw": {"AoE": 2.0, "Damage": 1.5, "Boss": 1.3, "Speed": 0.7},
		"pw": {"orbit": 1.7, "kunai": 1.5, "bwall": 1.6, "area": 1.5},
		"skins": [{"name": "Iron Knight", "col": Color(0.52, 0.56, 0.66), "hint": "Default"},
			{"name": "Royal Knight", "col": Color(0.32, 0.45, 0.85), "hint": "Beat 3 bosses in one run"},
			{"name": "Blood Knight", "col": Color(0.55, 0.14, 0.16), "hint": "500 kills with Knight"},
			{"name": "Golden Knight", "col": Color(0.88, 0.72, 0.28), "hint": "Win with Knight"}]},
	{"name": "Titan", "col": Color(0.60, 0.63, 0.72), "col2": Color(0.85, 0.60, 0.25), "role": "Fortress", "cost": 1000, "hint": "or win the campaign",
		"desc": "A slow fortress that breaks enemy lines with shockwaves and knockback",
		"stats": [5, 1, 3, 5, 1], "passive": "Rhythmic shockwaves shove enemies back - heavy armor, heavier steps",
		"sig": "shockwave", "signame": "Seismic Pulse", "sigdesc": "Periodic shockwaves that damage and knock back",
		"qname": "Earthbreaker", "qdesc": "A massive shockwave: heavy damage + huge knockback", "qcd": 12.0,
		"playstyle": "Tank / Crowd break", "strength": "Unmovable, clears packed lines", "weak": "Slow - fast strays slip around him", "difficulty": "Low",
		"bw": {"Defense": 2.2, "Armor": 2.2, "Sustain": 1.2, "Healing": 1.2, "Speed": 0.5, "Crit": 0.6},
		"pw": {"frostorb": 1.5, "bomb": 1.7, "bwall": 1.6, "area": 1.5, "gpow": 1.5},
		"skins": [{"name": "Steel Titan", "col": Color(0.60, 0.63, 0.72), "hint": "Default"},
			{"name": "Obsidian Titan", "col": Color(0.18, 0.16, 0.22), "hint": "Win the campaign"},
			{"name": "Bronze Titan", "col": Color(0.62, 0.45, 0.25), "hint": "Survive 10 min in one run"},
			{"name": "Frost Titan", "col": Color(0.62, 0.78, 0.92), "hint": "Win at Danger III+"}]},
	{"name": "Gambler", "col": Color(0.92, 0.90, 0.86), "col2": Color(0.90, 0.20, 0.25), "role": "High Roller", "cost": 1200, "hint": "or reach Stage 5",
		"desc": "A living die who bets his survival on every roll. One press can win the run... or ruin it",
		"stats": [1, 3, 5, 1, 5], "passive": "Dice shots crit far more than anyone. Q is a real gamble - read the odds",
		"sig": "dice", "signame": "Loaded Dice", "sigdesc": "Spinning dice shots with +15% crit chance",
		"qname": "All In Roll", "qdesc": "Roll a die: 1 hurts you badly... 6 is the jackpot. High risk, high reward", "qcd": 20.0,
		"playstyle": "Risk / Crit / Chaos", "strength": "Huge upside", "weak": "Bad rolls can hurt", "difficulty": "High",
		"bw": {"Crit": 2.4, "Damage": 1.8, "Projectile": 1.4, "Defense": 0.5, "Healing": 0.4, "Sustain": 0.4},
		"pw": {"mark": 1.8, "chain": 1.5, "ccore": 1.8, "precision": 1.4},
		"skins": [{"name": "White Dice", "col": Color(0.92, 0.90, 0.86), "hint": "Default"},
			{"name": "Black Dice", "col": Color(0.16, 0.16, 0.20), "hint": "Reach Stage 3 with Gambler"},
			{"name": "Red Dice", "col": Color(0.85, 0.20, 0.22), "hint": "Roll Jackpot 10 times"},
			{"name": "Golden High Roller", "col": Color(0.92, 0.75, 0.28), "hint": "Win with Gambler"},
			{"name": "Cursed Dice", "col": Color(0.45, 0.25, 0.60), "hint": "Survive 5 Disaster rolls"}]},
]

# أسماء الشخصيات القديمة → الجديدة (ترحيل حفظ v1.1 → v1.2)
const CHAR_RENAME := {"Burner": "Pyromancer", "Fire Aura": "Pyromancer", "Runner": "Shinobi", "Wrecker": "Knight", "Specter": "Gambler"}

# --- مستويات الصعوبة (Danger tiers) — كل مستوى يغيّر "قواعد" مش أرقام بس ---
const DIFF_TIERS := [
	{"name": "Normal",    "desc": "The standard run. A fair fight.",              "mods": ["Baseline enemies", "Standard rewards"]},
	{"name": "Danger I",  "desc": "Enemies are tougher and a little faster.",     "mods": ["+12% enemy HP", "+5% enemy speed", "+15% Cinders"]},
	{"name": "Danger II", "desc": "The swarm never lets up.",                     "mods": ["Faster spawns", "More shooters", "Bosses cut healing harder", "+30% Cinders"]},
	{"name": "Danger III","desc": "Every hit hurts more.",                        "mods": ["+20% enemy damage", "More elites", "Healing caps -20%", "+50% Cinders"]},
	{"name": "Danger IV", "desc": "The arena itself turns on you.",               "mods": ["Bosses enrage early", "Faster traps", "More bombers", "+75% Cinders"]},
	{"name": "Danger V",  "desc": "Elites everywhere. Survival is its own prize.","mods": ["Healing caps -35%", "Bosses attack faster", "-15% your Max HP", "x2 Cinders"]},
]

# v1.2 B/C: التطوّرات = سلاح جانبي Max + الباسيف الشريك + (المرحلة 3 أو زعيمان مهزومان)
# from = سطر "قبل → بعد" يظهر على الكارت الذهبي
const EVOS := {
	"ebladestorm": {"name": "Blade Storm",    "desc": "Kunai fly out, pierce everything, then return to your hand", "need": "Kunai Max + Precision", "from": "Kunai → Blade Storm"},
	"ewinter":     {"name": "Eternal Winter", "desc": "The orb becomes a blizzard: harsher slow + brief freeze (per-foe cooldown)", "need": "Frost Orb Max + Frozen Core", "from": "Frost Orb → Eternal Winter"},
	"emeteor":     {"name": "Meteor Fall",    "desc": "A huge bomb falls periodically, blasting and igniting the ground", "need": "Bomb Launcher Max + Gunpowder", "from": "Bomb Launcher → Meteor Fall"},
	"etstorm":     {"name": "Thunder Storm",  "desc": "Wider, faster lightning with +3 leaps (bosses resist)", "need": "Lightning Chain Max + Conductor", "from": "Lightning Chain → Thunder Storm"},
	"ethalo":      {"name": "Thorn Halo",     "desc": "A bigger, faster spike ring that shoves foes and softens contact damage", "need": "Orbit Spikes Max + Bulwark Core", "from": "Orbit Spikes → Thorn Halo"},
	"eshatter":    {"name": "Shatter Mark",   "desc": "Marks every 4th hit and marked foes detonate on death", "need": "Marked Shot Max + Crit Core", "from": "Marked Shot → Shatter Mark"},
	"esoulp":      {"name": "Soul Pulse",     "desc": "Soul Steal heals release a knockback pulse (no extra healing)", "need": "Soul Steal + Aura Core", "from": "Soul Steal → Soul Pulse"},
	"efrost":      {"name": "Frost Runner",   "desc": "Wider frost trail - foes dying on it burst into frost", "need": "Frost Trail + Speed Core", "from": "Frost Trail → Frost Runner"},
}

# --- Synergies (تركيبات البركات) — تُكتشف حين تجتمع بركتان بمستوى كافٍ ---
const SYNERGIES := [
	{"id": "arcane_orbit",  "name": "Arcane Orbit",   "cat": "Projectile", "desc": "Your orbitals fire shards periodically",         "req": {"orbit": 2, "multi": 2}},
	{"id": "frost_pulse",   "name": "Frost Pulse",     "cat": "Area",       "desc": "A chilling pulse slows nearby foes every few seconds","req": {"slow": 2, "aura": 1}},
	{"id": "shatter_core",  "name": "Shatter Core",    "cat": "Area",       "desc": "Critical hits burst into damaging shards (short cooldown)", "req": {"crit": 2, "explode": 2}},
	{"id": "vampiric_edge", "name": "Vampiric Edge",   "cat": "Defensive",  "desc": "Critical hits can heal 2 HP (cooldown; halved vs bosses)", "req": {"crit": 3, "steal": 1}},
	{"id": "core_resonance","name": "Core Resonance",  "cat": "Area",       "desc": "Leveling up unleashes a gem-pulling shockwave",     "req": {"aura": 2, "hp": 2}},
	{"id": "dash_breaker",  "name": "Dash Breaker",    "cat": "Movement",   "desc": "Dashing releases a damaging shockwave",             "req": {"dash": 1, "dmg": 2}},
	{"id": "momentum",      "name": "Momentum",        "cat": "Risk/Reward","desc": "While moving, +15% damage",                         "req": {"speed": 2, "dmg": 1}},
	{"id": "chain_storm",   "name": "Chain Storm",     "cat": "Projectile", "desc": "+1 chain target and you fire faster",               "req": {"chain": 2, "rate": 2}},
	{"id": "bulwark",       "name": "Bulwark",         "cat": "Defensive",  "desc": "Reinforced plating: +armor and +max HP",            "req": {"armor": 2, "hp": 2}},
	{"id": "overcharge",    "name": "Overcharge",      "cat": "Projectile", "desc": "An extra projectile — but -8% fire rate",           "req": {"rate": 3, "multi": 2}},
]

# --- الثيمات/المراحل (Stages) ---
const THEMES := [
	{"name": "Meadow", "bg": Color(0.11, 0.17, 0.12), "grid": Color(0.14, 0.22, 0.14),
	 "decor": Color(0.16, 0.30, 0.17), "boss_col": Color(0.15, 0.65, 0.25), "boss_name": "Meadow Warden",
	 "pal": [Color(0.85, 0.38, 0.30), Color(0.82, 0.58, 0.24), Color(0.62, 0.36, 0.75), Color(0.55, 0.42, 0.30)]},
	{"name": "Desert", "bg": Color(0.22, 0.17, 0.12), "grid": Color(0.26, 0.20, 0.14),
	 "decor": Color(0.40, 0.33, 0.22), "boss_col": Color(0.92, 0.89, 0.78), "boss_name": "Bone King",
	 "pal": [Color(0.80, 0.42, 0.18), Color(0.62, 0.32, 0.22), Color(0.88, 0.66, 0.26), Color(0.50, 0.26, 0.12)],
	 "bone": true},
	{"name": "Glacier", "bg": Color(0.15, 0.20, 0.27), "grid": Color(0.22, 0.29, 0.38),
	 "decor": Color(0.46, 0.56, 0.68), "boss_col": Color(0.20, 0.75, 0.90), "boss_name": "Frost Heart",
	 "pal": [Color(0.30, 0.52, 0.82), Color(0.48, 0.75, 0.92), Color(0.22, 0.38, 0.65), Color(0.70, 0.82, 0.98)]},
	{"name": "Volcano", "bg": Color(0.16, 0.07, 0.06), "grid": Color(0.20, 0.09, 0.07),
	 "decor": Color(0.80, 0.34, 0.10), "boss_col": Color(0.90, 0.20, 0.10), "boss_name": "Magma Beast",
	 "pal": [Color(0.88, 0.24, 0.14), Color(0.95, 0.52, 0.14), Color(0.62, 0.18, 0.18), Color(0.95, 0.76, 0.24)]},
	{"name": "The Void", "bg": Color(0.05, 0.04, 0.08), "grid": Color(0.12, 0.10, 0.20),
	 "decor": Color(0.58, 0.42, 0.80), "boss_col": Color(0.65, 0.25, 0.90), "boss_name": "Void Shade",
	 "pal": [Color(0.56, 0.30, 0.82), Color(0.78, 0.36, 0.88), Color(0.36, 0.26, 0.62), Color(0.86, 0.56, 0.95)]},
]

# --- متجر الترقيات الدائمة (Meta shop / PowerUps) ---
# v1.1: الترقيات أقوى وأول مستويات أرخص — الفوز الأول متوقع بعد 5-10 جولات
const META_SHOP := [
	{"id": "vitality", "name": "Vitality",  "desc": "+10 Max HP per tier",       "costs": [30, 70, 130, 220, 340]},
	{"id": "might",    "name": "Might",      "desc": "+2 damage per tier",       "costs": [40, 90, 160, 260, 400]},
	{"id": "cooldown", "name": "Cooldown",   "desc": "+4% fire rate per tier",   "costs": [50, 110, 200, 330]},
	{"id": "swift",    "name": "Move Speed", "desc": "+8 move speed per tier",   "costs": [30, 70, 130, 210]},
	{"id": "magnet",   "name": "Magnet",     "desc": "+20 pickup range per tier","costs": [25, 50, 90, 150]},
	{"id": "growth",   "name": "Growth",     "desc": "+6% XP gain per tier",     "costs": [60, 140, 260]},
	{"id": "dash",     "name": "Swift Dash", "desc": "-6% dash cooldown per tier","costs": [40, 100, 180]},
	{"id": "armor",    "name": "Armor",      "desc": "-8% damage taken per tier","costs": [120, 280, 450]},
	{"id": "recovery", "name": "Recovery",   "desc": "Start with Recovery Lv1",  "costs": [160]},
	{"id": "greed",    "name": "Greed",      "desc": "+8% Cinders earned per tier","costs": [80, 200, 360]},
	{"id": "revival",  "name": "Revival",    "desc": "Revive once per run at 40% HP","costs": [600]},
]

# --- الإنجازات (Achievements / Traits على طريقة Halls of Torment) ---
const ACHIEVEMENTS := [
	{"id": "first",      "name": "First Blood",   "desc": "Finish your first run",       "reward": 30},
	{"id": "realm3",     "name": "Realm Walker",  "desc": "Reach Stage 3",               "reward": 40, "unlock": "Shinobi"},
	{"id": "bossslayer", "name": "Boss Slayer",   "desc": "Defeat any boss",             "reward": 25},
	{"id": "centurion",  "name": "Centurion",     "desc": "300 kills in one run",        "reward": 50},
	{"id": "massacre",   "name": "Massacre",      "desc": "500 kills in one run",        "reward": 100, "unlock": "Pyromancer"},
	{"id": "triple",     "name": "Triple Threat", "desc": "Defeat 3 bosses in one run",  "reward": 60, "unlock": "Knight"},
	{"id": "combo50",    "name": "Combo Master",  "desc": "Reach a x50 combo",           "reward": 40},
	{"id": "evolved",    "name": "Evolved",       "desc": "Trigger a weapon evolution",  "reward": 50},
	{"id": "void5",      "name": "Void Walker",   "desc": "Reach Stage 5 (The Void)",    "reward": 80, "unlock": "Gambler"},
	{"id": "win",        "name": "Ash Conqueror", "desc": "Win the campaign",            "reward": 150, "unlock": "Titan"},
	{"id": "speed",      "name": "Speed Demon",   "desc": "Win in under 6:00",           "reward": 100},
	{"id": "hoarder",    "name": "Hoarder",       "desc": "Collect 2000 gems in one run","reward": 50},
]

# --- عناوين المراحل (Stage titles) ---
const STAGE_TITLES := ["Verdant Grid", "Crimson Pressure", "Frozen Expanse", "Golden Collapse", "The Core"]

# --- معايرة السرعة والزعماء (Calibration v1.1.1) ---
# سرعة الأعداء تدريجية بالمرحلة (مش ×1.5 عام) — البدايات عادلة والنهايات ضاغطة
const ENEMY_SPD_STAGE := [1.00, 1.08, 1.15, 1.22, 1.30]
# صحة الزعيم الأساسية لكل مرحلة — مستهدف مدة المعركة:
# S1: 35-60ث · S2: 45-75ث · S3: 60-90ث · S4: 75-110ث · S5: 90-140ث (الملك ×2 فوقها)
# متحقّقة بالـ autoplay debug timers عبر جولات المعايرة
# v1.2-D: رفع معتدل للمنتصف/النهاية — البناءات المتطورة (Evolutions) بقت معيار النهاية،
# والدرع التكيفي بيتكفل بفرق الـ burst (البناء الضعيف عند S3 لسه جوه 60-90ث)
const BOSS_HP_STAGE := [850.0, 2600.0, 4100.0, 6100.0, 8600.0]

# --- مزيج الأعداء لكل مرحلة (Stage identity) ---
# 1 تعليمي (مطاردون) · 2 ضغط+رماة · 3 قنابل+رماة · 4 فوضى نخبة · 5 كله متوازن
const STAGE_MIX := [
	{"norm": 62, "fast": 28, "tank": 10},
	{"norm": 40, "fast": 24, "shooter": 26, "tank": 10},
	{"norm": 34, "fast": 14, "shooter": 22, "bomber": 20, "tank": 10},
	{"norm": 26, "fast": 14, "shooter": 18, "bomber": 12, "tank": 15, "split": 15},
	{"norm": 23, "fast": 15, "shooter": 18, "bomber": 13, "tank": 15, "split": 16},
]

# --- الندرة (Rarity) ---
# 0 Common (رمادي) · 1 Rare (أزرق) · 2 Epic (بنفسجي) · 3 Legendary (ذهبي)
const RARITY_NAME := ["COMMON", "RARE", "EPIC", "LEGENDARY"]
const RARITY_COL := [Color("9aa0aa"), Color("4a9eff"), Color("b163e6"), Color("ffc24b")]
# v1.1.5: بوابات ندرة لكل مرحلة — Rare من البداية، Epic بعد أول زعيم، Legendary من المرحلة 3
const RARITY_W_STAGE := [
	[70, 30, 0, 0],    # Stage 1: أساسيات + Rare محدودة، ممنوع Epic
	[58, 32, 10, 0],   # Stage 2: أول Epic بعد أول زعيم
	[45, 34, 18, 3],   # Stage 3: أول Legendary (بشروط)
	[38, 34, 22, 6],   # Stage 4
	[32, 34, 25, 9],   # Stage 5
]

# --- الترقيات (Blessings) ---
# rar = الندرة · max = أقصى مستوى · tags = أوسمة الأوزان والعرض
# draw = الـ Drawback (برتقالي على الكارت) · min_stage = أبكر مرحلة تظهر فيها
# cat: Foundation = أرقام · Effect = تأثير لعب · Engine = بيبني أسلوب
# slot (v1.2 B/C): "weapon" = سلاح جانبي (3 خانات) · "passive" = باسيف (4 خانات)
# partner_of: الباسيف الشريك لسلاح — سلاح Max + شريكه + المرحلة 3/زعيمان = Evolution
const SIDE_WEAPON_SLOTS := 3
const PASSIVE_SLOTS := 4
const UPS := [
	# ===== أسلحة جانبية (slot=weapon — 3 خانات) =====
	{"id": "kunai", "name": "Kunai",           "desc": "Throws piercing knives at the nearest foe (levels: +knife, +pierce, faster)", "rar": 1, "max": 4, "cat": "Engine", "slot": "weapon", "tags": ["Projectile", "Damage"]},
	{"id": "frostorb","name": "Frost Orb",     "desc": "An icy orb circles you, chilling and grinding foes in its zone", "rar": 1, "max": 4, "cat": "Engine", "slot": "weapon", "tags": ["Utility", "AoE"]},
	{"id": "orbit", "name": "Orbit Spikes",    "desc": "+1 spinning spike guarding you up close",  "rar": 1, "max": 4, "cat": "Engine", "slot": "weapon", "tags": ["AoE", "Defense", "Damage"]},
	{"id": "chain", "name": "Lightning Chain", "desc": "Bolts strike and leap between packed foes", "rar": 2, "max": 4, "cat": "Engine", "slot": "weapon", "tags": ["Damage", "AoE"]},
	{"id": "bomb",  "name": "Bomb Launcher",   "desc": "Lobs bombs that blast crowds (Lv4: leaves burning ground)", "rar": 2, "max": 4, "cat": "Engine", "slot": "weapon", "tags": ["AoE"]},
	{"id": "mark",  "name": "Marked Shot",     "desc": "Every 5th hit marks a foe: +15% damage taken, burst at Lv3", "rar": 1, "max": 4, "cat": "Engine", "slot": "weapon", "tags": ["Damage", "Crit"]},
	# ===== ترقية سلاح التوقيع (slot=sig — بلا خانة، متاحة دايماً، 5 مستويات) =====
	{"id": "sigup", "name": "Signature Core",  "desc": "+15% signature weapon damage per level", "rar": 1, "max": 5, "cat": "Foundation", "slot": "sig", "tags": ["Damage"]},
	# ===== باسيفات عامة (slot=passive — 4 خانات، أغلبها 3 مستويات بقيم أقوى) =====
	{"id": "dmg",   "name": "Firepower",       "desc": "+10 damage",                    "rar": 0, "max": 3, "cat": "Foundation", "slot": "passive", "tags": ["Damage"]},
	{"id": "rate",  "name": "Quick Trigger",   "desc": "+15% fire rate",                "rar": 0, "max": 3, "cat": "Foundation", "slot": "passive", "tags": ["FireRate"]},
	{"id": "speed", "name": "Agility",         "desc": "+12% move speed; dashing grants a 2s speed burst", "rar": 0, "max": 3, "cat": "Foundation", "slot": "passive", "tags": ["Speed", "Dash"]},
	{"id": "hp",    "name": "Toughness",       "desc": "+30 max HP and heal 20",        "rar": 0, "max": 3, "cat": "Foundation", "slot": "passive", "tags": ["Defense"]},
	{"id": "magnet","name": "Magnet",          "desc": "+50% pickup range; Lv3: every 30 gems grant +2 XP", "rar": 0, "max": 3, "cat": "Foundation", "slot": "passive", "tags": ["Magnet", "Utility", "Economy"]},
	{"id": "cdr",   "name": "Focus",           "desc": "-8% Q and side-weapon cooldowns per rank", "rar": 1, "max": 3, "cat": "Foundation", "slot": "passive", "tags": ["Utility"]},
	{"id": "area",  "name": "Reach",           "desc": "+12% aura, blast and wave size per rank", "rar": 1, "max": 3, "cat": "Foundation", "slot": "passive", "tags": ["AoE"]},
	{"id": "armor", "name": "Steel Plates",    "desc": "-8% damage taken; Lv3: hits grant a brief shield", "rar": 1, "max": 3, "cat": "Foundation", "slot": "passive", "tags": ["Armor", "Defense"]},
	{"id": "crit",  "name": "Deathblow",       "desc": "+10% crit chance; Lv3: crits ignite foes", "rar": 1, "max": 3, "cat": "Foundation", "slot": "passive", "tags": ["Crit", "Damage"]},
	{"id": "dash",  "name": "Swift Dash",      "desc": "-20% dash cooldown; Lv3: dashing pulls gems", "rar": 1, "max": 3, "cat": "Foundation", "slot": "passive", "tags": ["Dash", "Speed"]},
	{"id": "pierce","name": "Piercing",        "desc": "Shots pierce +1 enemy",         "rar": 1, "max": 3, "cat": "Foundation", "slot": "passive", "tags": ["Projectile"]},
	{"id": "big",   "name": "Massive Shots",   "desc": "+25% projectile size",          "rar": 1, "max": 3, "cat": "Foundation", "slot": "passive", "tags": ["Projectile", "AoE"]},
	# ===== باسيفات تأثير =====
	{"id": "regen", "name": "Recovery",        "desc": "Unhurt for 6s: heal 1 HP per 3s (ranks raise caps)", "rar": 1, "max": 3, "cat": "Engine", "slot": "passive", "tags": ["Healing", "Sustain"],
		"draw": "Off in boss fights - capped per stage"},
	{"id": "ric",   "name": "Ricochet",        "desc": "Shots bounce to a nearby enemy","rar": 1, "max": 3, "cat": "Effect", "slot": "passive", "tags": ["Projectile"]},
	{"id": "rear",  "name": "Rear Guard",      "desc": "+1 rear shot at 50% damage",    "rar": 1, "max": 3, "cat": "Effect", "slot": "passive", "tags": ["Projectile"]},
	{"id": "bossdmg","name": "Giant Slayer",   "desc": "+20% damage to bosses and elites", "rar": 1, "max": 2, "cat": "Effect", "slot": "passive", "tags": ["Boss", "Damage"]},
	{"id": "pulse", "name": "Kill Wave",       "desc": "Every 25 kills: a pulse damages and slows foes", "rar": 1, "max": 2, "cat": "Effect", "slot": "passive", "tags": ["AoE", "Utility"]},
	{"id": "frtrail","name": "Frost Trail",    "desc": "Dashing leaves a frost trail that slows foes for 2s", "rar": 1, "max": 2, "cat": "Effect", "slot": "passive", "tags": ["Dash", "Utility"]},
	{"id": "msurge","name": "Magnetic Surge",  "desc": "Every 30 gems: pull everything in and emit a pulse", "rar": 1, "max": 2, "cat": "Effect", "slot": "passive", "tags": ["Magnet", "Economy", "AoE"]},
	{"id": "bbreak","name": "Boss Breaker",    "desc": "Dash near a boss: +25% boss damage per rank for 3s", "rar": 1, "max": 2, "cat": "Effect", "slot": "passive", "tags": ["Boss", "Dash", "Damage"]},
	{"id": "shard", "name": "Shard Seed",      "desc": "Slain foes have a 12% chance per rank to burst into shards", "rar": 1, "max": 2, "cat": "Effect", "slot": "passive", "tags": ["AoE", "Projectile"]},
	{"id": "closecall","name": "Close Call",   "desc": "A shot grazing you grants +12% damage and speed for 2s", "rar": 1, "max": 2, "cat": "Effect", "slot": "passive", "tags": ["Speed", "Risk"]},
	{"id": "multi", "name": "Extra Volley",    "desc": "+1 side shot at 50% damage", "rar": 2, "max": 2, "cat": "Engine", "slot": "passive", "tags": ["Projectile", "Damage", "Risk"],
		"draw": "-10% fire rate - 35% dmg vs bosses"},
	{"id": "steal", "name": "Soul Steal",      "desc": "Heal 1 HP per 10 kills (Lv2: 7). Elites count x3", "rar": 2, "max": 2, "cat": "Engine", "slot": "passive", "tags": ["Healing", "Sustain"],
		"draw": "No boss-fight healing - capped per stage"},
	{"id": "aura",  "name": "Burning Aura",    "desc": "Damage aura around you (+size)","rar": 2, "max": 3, "cat": "Engine", "slot": "passive", "tags": ["AoE"]},
	{"id": "explode","name": "Explosive Death","desc": "Enemies explode on death (bosses resist)", "rar": 2, "max": 3, "cat": "Engine", "slot": "passive", "tags": ["AoE"]},
	{"id": "slow",  "name": "Frost Touch",     "desc": "Your hits slow enemies",        "rar": 2, "max": 3, "cat": "Engine", "slot": "passive", "tags": ["Utility", "AoE"]},
	{"id": "heavy", "name": "Heavy Core",      "desc": "+40% damage",                   "rar": 2, "max": 1, "cat": "Engine", "slot": "passive", "tags": ["Damage", "Risk"],
		"draw": "-12% fire rate - 8% move speed"},
	{"id": "guard", "name": "Guardian Cube",   "desc": "An orbiting cube blocks one hit completely", "rar": 2, "max": 2, "cat": "Engine", "slot": "passive", "tags": ["Defense", "Utility"],
		"draw": "Recharges every 20s (Lv2: 14s)"},
	{"id": "exec",  "name": "Execution Core",  "desc": "Every 5th volley deals x2 damage (x1.5 vs bosses)", "rar": 3, "max": 1, "cat": "Engine", "slot": "passive", "tags": ["Damage", "Projectile"], "min_stage": 3},
	# ===== باسيفات شريكة (Partner Passives) — سلاحها Max + هي + المرحلة 3 = Evolution =====
	{"id": "precision","name": "Precision",    "desc": "+1 Kunai pierce and +5% crit",  "rar": 1, "max": 2, "cat": "Engine", "slot": "passive", "partner_of": "kunai", "tags": ["Crit", "Projectile"]},
	{"id": "fcore", "name": "Frozen Core",     "desc": "Your slows are 20% stronger per rank", "rar": 1, "max": 2, "cat": "Engine", "slot": "passive", "partner_of": "frostorb", "tags": ["Utility", "AoE"]},
	{"id": "gpow",  "name": "Gunpowder",       "desc": "+20% blast damage per rank",    "rar": 1, "max": 2, "cat": "Engine", "slot": "passive", "partner_of": "bomb", "tags": ["AoE", "Damage"]},
	{"id": "conduct","name": "Conductor",      "desc": "Lightning leaps +1 extra target per rank", "rar": 1, "max": 2, "cat": "Engine", "slot": "passive", "partner_of": "chain", "tags": ["Damage", "AoE"]},
	{"id": "bwall", "name": "Bulwark Core",    "desc": "-5% damage taken and spikes shove harder", "rar": 1, "max": 2, "cat": "Engine", "slot": "passive", "partner_of": "orbit", "tags": ["Defense", "Armor"]},
	{"id": "ccore", "name": "Crit Core",       "desc": "+6% crit and marked foes take +10% more", "rar": 1, "max": 2, "cat": "Engine", "slot": "passive", "partner_of": "mark", "tags": ["Crit", "Damage"]},
	{"id": "acore", "name": "Aura Core",       "desc": "+15% aura size and aura hits shove slightly", "rar": 1, "max": 2, "cat": "Engine", "slot": "passive", "tags": ["AoE", "Sustain"]},
	{"id": "score", "name": "Speed Core",      "desc": "+6% move speed and -8% dash cooldown", "rar": 1, "max": 2, "cat": "Engine", "slot": "passive", "tags": ["Speed", "Dash"]},
]
