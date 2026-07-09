extends Node2D
# ============================================================
#  ناجي المكعبات — CUBE SURVIVOR  v3
#  قوائم + إعدادات + مراحل متغيّرة كل دقيقة + زعيم كل دقيقة
#  (يمسح الأعداء ويوقف المؤقت) + داش + أرقام ضرر + موسيقى
# ============================================================

const DBG_INPUT := false
const GAME_VERSION := "v1.2.5"
# لقطات الشاشة للتطوير: تُفعَّل عبر سطر الأوامر:  godot --path . -- --shot=<scene> [--shotout=<path>]
# المشاهد: menu | menu_ar | settings | play | boss | levelup | lang | cover
var SHOTMODE := false
var SHOTSCENE := "play"
var SHOTPATH := "user://shot.png"
var SHOTCHAR := -1   # --shotchar=N: لقطات اللعب بشخصية محددة (توثيق الهوية البصرية)

# بيانات التوازن والمحتوى (الشخصيات/الثيمات/الترقيات/التطوّرات)
const Balance := preload("res://data/balance.gd")

# --- benchmark أداء (للتطوير فقط، يتفعّل عبر --bench) ---
var BENCH := false
var bench_frames := 0
var bench_us := {}       # اسم النظام -> إجمالي الميكروثانية
var bench_frame_hist := []
var _bt := 0
func _bs() -> void:
	if BENCH: _bt = Time.get_ticks_usec()
func _be(k: String) -> void:
	if BENCH: bench_us[k] = int(bench_us.get(k, 0)) + (Time.get_ticks_usec() - _bt)

# --- AUTOPLAY (معايرة التوازن، --autoplay=N) — بوت يلعب جولات كاملة headless ويطبع تقارير ---
# --meta=0..1 نسبة الترقيات الدائمة · --char=0..5 · --danger=0..5
# لا يلمس حفظ اللاعب إطلاقاً (_save_settings معطّلة في وضع الاختبار)
var AUTOPLAY := false
var AUTO_RUNS := 10
var AUTO_META := 0.0
var AUTO_CHAR := 0
var AUTO_DANGER := 0
var AUTO_SPEED := 40      # خطوات محاكاة لكل فريم (سرعة الاختبار)
var auto_done := 0
var auto_results := []
var bot_dash := false     # رغبة البوت في الداش (يحسبها _bot_move)
var AUTO_GRANT := ""      # --grant=id:n,id:n — بركات تُمنح أول كل جولة اختبار

# --- Debug Balance Report — إحصائيات معايرة تُطبع في الكونسول آخر كل جولة ---
var stat_dmg_dealt := 0.0
var stat_dmg_taken := 0.0
var stat_heal := {}          # مصدر العلاج -> إجمالي (steal/regen/levelup/reward/generic)
var last_hurt_src := "-"     # آخر مصدر ضرر = سبب الموت
var dps_bucket := 0.0        # ضرر النافذة الحالية (ثانية) لقياس أعلى DPS
var dps_bucket_t := 0.0
var stat_max_dps := 0.0
var boss_fight_t := 0.0      # مدة معركة الزعيم الحالية
var boss_times := []         # [{name, secs}] لكل زعيم في الجولة

const W := 1280.0            # حجم الشاشة (الكاميرا)
const H := 720.0
const WW := 2560.0           # حجم عالم الساحة (2×2 شاشات)
const WH := 1440.0
var C := Vector2(W * 0.5, H * 0.5)     # مركز الشاشة (للواجهات)
var WC := Vector2(WW * 0.5, WH * 0.5)  # مركز العالم

enum { ST_MENU, ST_SETTINGS, ST_PLAY, ST_LEVELUP, ST_PAUSE, ST_OVER, ST_VICTORY, ST_LANG, ST_SHOP, ST_STATS, ST_CHARSEL, ST_DIFF, ST_CREDITS }
var state := ST_MENU

# --- i18n ---
var LANG := 0        # 0 = English, 1 = العربية
var lang_chosen := false
func T(s: String) -> String:
	if LANG == 1 and TR.has(s):
		return TR[s]
	return s
const TR := {
	# menu
	"CUBE SURVIVOR": "ناجي المكعبات",
	"A roguelike run: five stages, a boss every minute, and the Ash King at the end": "جولة روج-لايك: خمسة فصول، زعيم كل دقيقة، وملك الرماد في النهاية",
	"[Enter]  Start Run": "[Enter]  ابدأ الجولة",
	"[S] Settings": "[S] الإعدادات",
	"WASD move  •  Shift/Space dash  •  Auto-fire  •  P pause": "WASD حركة  •  Shift/مسافة اندفاع  •  رماية تلقائية  •  P إيقاف",
	"WASD move • Shift/Space dash • Auto-fire • 1/2/3 pick • R reroll • P pause": "WASD حركة • Shift/مسافة اندفاع • رماية تلقائية • 1/2/3 اختيار • R إعادة • P إيقاف",
	"Survivor:  < %s >   (A/D)   -   %s": "الناجي:  ‹ %s ›   (A/D)   -   %s",
	"Best run: Stage %d  •  %02d:%02d  •  %d kills%s": "أفضل جولة: الفصل %d  •  %02d:%02d  •  %d قتيل%s",
	"  •  Wins: %d": "  •  انتصارات: %d",
	"Cinders: %d": "الجمرات: %d",
	"+%d Cinders   (Total: %d)": "+%d جمرة   (الإجمالي: %d)",
	# settings
	"SETTINGS": "الإعدادات",
	"Sound Effects": "المؤثرات الصوتية",
	"Music": "الموسيقى",
	"Screen Shake": "اهتزاز الشاشة",
	"Damage Numbers": "أرقام الضرر",
	"Tutorial Tips": "تلميحات تعليمية",
	"Blessings: %d": "البركات: %d",
	"Survive the corrupted arena": "انجُ من الساحة المشوّهة",
	"Start Game": "ابدأ اللعب",
	"Upgrades": "الترقيات",
	"Records": "السجلّات",
	"Settings": "الإعدادات",
	"Credits": "صنّاع اللعبة",
	"Quit": "خروج",
	"Click, or W/S + Enter to select": "انقر، أو W/S + Enter للاختيار",
	"< Back": "< رجوع",
	"Restart Run": "إعادة الجولة",
	"Main Menu": "القائمة الرئيسية",
	"Restart this run?": "إعادة هذه الجولة؟",
	"Return to Main Menu?": "العودة للقائمة الرئيسية؟",
	"Yes": "نعم", "No": "لا",
	"Click Yes/No   •   Enter confirm   •   Esc = No": "انقر نعم/لا   •   Enter للتأكيد   •   Esc = لا",
	"Click, or W/S + Enter   •   Esc/P to resume": "انقر، أو W/S + Enter   •   Esc/P للاستئناف",
	"WASD move • Space dash • Auto-fire • P pause": "WASD حركة • مسافة اندفاع • رماية تلقائية • P إيقاف",
	"Click Back, or press Enter": "انقر رجوع، أو اضغط Enter",
	"Cinders: %d      Best: Stage %d  %02d:%02d%s": "الجمرات: %d      الأفضل: مرحلة %d  %02d:%02d%s",
	"SELECT SURVIVOR": "اختر الناجي",
	"SELECT DIFFICULTY": "اختر الصعوبة",
	"Passive": "قدرة خاصة",
	"Health": "الصحة",
	"Speed": "السرعة",
	"Power": "القوة",
	"Defense": "الدفاع",
	"Luck": "الحظ",
	"All-Rounder": "متوازن",
	"Bruiser": "مقاتل عنيف",
	"Skirmisher": "مناوش",
	"Heavy Hitter": "ضربة ثقيلة",
	"Tank": "دبابة",
	"Glass Cannon": "مدفع زجاجي",
	"Steady fundamentals — his first level-up offers 4 blessings instead of 3": "أساسيات ثابتة — أول ارتقاء له يعرض 4 بركات بدل 3",
	"Sustainer": "صمّاد",
	"Burning aura. Soul Steal & Recovery are far stronger for him": "هالة نار. سرقة الأرواح والتعافي أقوى بكتير معاه",
	"The only one past the speed cap, quicker dash, +1 reroll — healing is weak on her": "الوحيدة فوق سقف السرعة + داش أسرع + إعادة اختيار زيادة — لكن العلاج ضعيف عليها",
	"Orbiting blade + heavy hits — his fire rate has a hard cap": "شفرة دوّارة + ضربات ثقيلة — سرعة رمايته ليها سقف صلب",
	"Heavy armor + guard aura — can never reach top speed or fire rate": "درع ثقيل + هالة حماية — مستحيل يوصل لأعلى سرعة أو رماية",
	"Only he can reach 75% crit. Healing barely works — one mistake costs dearly": "الوحيد اللي يوصل كريت 75%. العلاج شبه معدوم — أي غلطة غالية",
	"A/D or Arrows to choose   •   Enter or Click to confirm": "A/D أو الأسهم للاختيار   •   Enter أو النقر للتأكيد",
	"Confirm to unlock (%d Cinders) — you have %d": "أكّد للفتح (%d جمرة) — لديك %d",
	"Normal": "عادي",
	"Danger I": "خطر I",
	"Danger II": "خطر II",
	"Danger III": "خطر III",
	"Danger IV": "خطر IV",
	"Danger V": "خطر V",
	"The standard run. A fair fight.": "الجولة المعتادة. نزال عادل.",
	"Enemies are tougher and a little faster.": "الأعداء أقوى وأسرع قليلًا.",
	"The swarm never lets up.": "الموجة لا تتوقّف أبدًا.",
	"Every hit hurts more.": "كل ضربة توجع أكثر.",
	"The arena itself turns on you.": "الساحة نفسها بتنقلب عليك.",
	"Elites everywhere. Survival is its own prize.": "نخبة في كل مكان. البقاء بحدّ ذاته جائزة.",
	"Baseline enemies": "أعداء أساسيون",
	"Standard rewards": "مكافآت معتادة",
	"+12% enemy HP": "+12% صحة العدو",
	"+5% enemy speed": "+5% سرعة العدو",
	"+15% Cinders": "+15% جمرات",
	"Faster spawns": "ظهور أعداء أسرع",
	"More shooters": "رماة أكتر",
	"Bosses cut healing harder": "الزعماء يقصّون العلاج أكثر",
	"+30% Cinders": "+30% جمرات",
	"+20% enemy damage": "+20% ضرر العدو",
	"More elites": "نخبة أكتر",
	"Healing caps -20%": "سقوف العلاج -20%",
	"+50% Cinders": "+50% جمرات",
	"Bosses enrage early": "الزعماء يغضبون مبكرًا",
	"Faster traps": "فخاخ أسرع",
	"More bombers": "قنابل أكتر",
	"+75% Cinders": "+75% جمرات",
	"Healing caps -35%": "سقوف العلاج -35%",
	"Bosses attack faster": "الزعماء يهاجمون أسرع",
	"-15% your Max HP": "-15% من صحتك القصوى",
	"x2 Cinders": "x2 جمرات",
	"Win at the previous Danger level to unlock.": "افُز في مستوى الخطر السابق لفتحه.",
	"W/S select   •   Enter start run   •   Backspace: Change Survivor": "W/S للتنقل   •   Enter لبدء الجولة   •   Backspace: تغيير الناجي",
	"W/S select   •   Backspace: Change Survivor": "W/S للتنقل   •   Backspace: تغيير الناجي",
	"Survivor: %s": "الناجي: %s",
	"CREDITS": "صنّاع اللعبة",
	"Design, code & art": "التصميم والبرمجة والفن",
	"Made with Godot Engine": "صُنعت بمحرّك Godot",
	"Thank you for playing!": "شكرًا للّعب!",
	"Backspace / Enter — back": "Backspace / Enter — رجوع",
	"Move: WASD/Arrows • Auto-fire • Blue core = you, Red = danger, Gold = reward": "الحركة: WASD/الأسهم • رماية تلقائية • القلب الأزرق = أنت، أحمر = خطر، ذهبي = مكافأة",
	"Gold gems level you up — grab them!": "الجواهر الذهبية بترفع مستواك — لمّها!",
	"Warning zones flash before they strike — dash out!": "مناطق الخطر بتومض قبل ما تضرب — اندفع بره!",
	"Boss incoming! Bosses have a health bar — watch their attack tells.": "الزعيم قادم! ليه شريط صحة — راقب تحذيرات هجماته.",
	"Wounded! Elite shots block ALL healing for 4s — the health bar turns orange.": "جُرحت! طلقات النخبة بتمنع كل علاج 4 ثواني — شريط الصحة بيبقى برتقالي.",
	"Rotate your device for the best experience": "لفّ جهازك للوضع الأفقي لأفضل تجربة",
	"WOUNDED - healing blocked": "جرح - العلاج ممنوع",
	"Spend Cinders on permanent upgrades — [U] in the menu": "اصرف الجمرات على ترقيات دائمة — [U] في القائمة",
	"Fullscreen": "ملء الشاشة",
	"Language": "اللغة",
	"ON": "مفعّل",
	"OFF": "مكتوم",
	"W/S select row    •    A/D adjust    •    Backspace back": "W/S اختيار    •    A/D تعديل    •    Backspace رجوع",
	# pause / victory / gameover / levelup
	"PAUSED": "إيقاف مؤقت",
	"[P] Resume      [M] Main Menu": "[P] استمرار      [M] القائمة",
	"VICTORY - The Ash King has fallen!": "النصر — سقط ملك الرماد!",
	"Campaign complete, %s!\n\nKills: %d      Level: %d      Run time: %02d:%02d\nBest combo: x%d": "أنهيت الحملة يا %s!\n\nقتلى: %d      ارتقاء: %d      زمن الجولة: %02d:%02d\nأفضل كومبو: x%d",
	"[Enter] Back to Menu": "[Enter] العودة للقائمة",
	"YOU DIED": "سقطتَ",
	"Kills: %d      Level: %d      Stage: %d      Survived: %02d:%02d\nBest combo: x%d%s\n\n[R] New Run      [M] Menu": "قتلى: %d      ارتقاء: %d      الفصل: %d      صمدت: %02d:%02d\nأفضل كومبو: x%d%s\n\n[R] جولة جديدة      [M] القائمة",
	"\nNEW RECORD!": "\nرقم قياسي جديد!",
	"Kills: %d      Level: %d      Stage: %d      Survived: %02d:%02d\nBest combo: x%d%s": "قتلى: %d      ارتقاء: %d      الفصل: %d      صمدت: %02d:%02d\nأفضل كومبو: x%d%s",
	"[R] New Run      [M] Menu": "[R] جولة جديدة      [M] القائمة",
	"LEVEL UP %d - choose a blessing [1/2/3]": "ارتقاء %d — اختر بركتك [1/2/3]",
	"LEVEL UP %d": "ارتقاء %d",
	"[R] Reroll (%d)": "[R] إعادة (%d)",
	"[1/2/3] choose": "[1/2/3] اختر",
	"[1/2/3/4] choose": "[1/2/3/4] اختر",
	"COMMON": "عادي", "RARE": "نادر", "EPIC": "ملحمي", "LEGENDARY": "أسطوري",
	# HUD
	"KILLS: %d": "قتلى: %d",
	"LEVEL %d": "ارتقاء %d",
	"Stage %d/%d - %s": "الفصل %d/%d - %s",
	"Verdant Grid": "الشبكة الخضراء", "Crimson Pressure": "الضغط القرمزي",
	"Frozen Expanse": "الامتداد المتجمّد", "Golden Collapse": "الانهيار الذهبي", "The Core": "القلب",
	"Synergy Unlocked: %s": "تركيبة مفتوحة: %s",
	"Synergy!": "تركيبة!",
	"— Synergies Discovered: %d/%d —": "— التركيبات المكتشفة: %d/%d —",
	"Arcane Orbit": "المدار السحري", "Frost Pulse": "نبضة الصقيع", "Shatter Core": "قلب التحطيم",
	"Vampiric Edge": "الحدّ المصّاص", "Core Resonance": "رنين القلب", "Dash Breaker": "كاسر الاندفاع",
	"Momentum": "الزخم", "Chain Storm": "عاصفة السلاسل", "Bulwark": "الحصن", "Overcharge": "الشحن الزائد",
	"!! THE ASH KING - THE END !!": "!! ملك الرماد — النهاية !!",
	"Lords of the Realms - %d left": "أسياد العوالم — باقي %d",
	"Something approaches from the dark...": "شيء قادم من الظلام...",
	"!! %s - TIME FROZEN !!": "!! %s — الزمن متجمّد !!",
	"Boss in %ds": "الزعيم بعد %dث",
	"x%d COMBO": "x%d كومبو",
	# flash messages
	"Stage 1 - %s": "الفصل 1 — %s",
	"Stage %d - %s": "الفصل %d — %s",
	"!! Boss approaching !!": "!! الزعيم يقترب !!",
	"The Void summons the traps of all realms!": "الفراغ يستدعي فخاخ العوالم!",
	"The Void... something stirs in the dark": "الفراغ... شيء يتحرك في الظلام",
	"%s is enraged!": "%s استشاط غضباً!",
	"Frost Heart shattered in two!": "قلب الجليد انكسر لاثنين!",
	"!! The Lords of the Realms have returned - defeat them all !!": "!! أسياد العوالم عادوا من الرماد — اهزمهم جميعاً !!",
	"The Ash King rises from his ashes!!": "ملك الرماد ينهض من رماده!!",
	"A Lord has fallen - %d remain": "سقط أحد الأسياد — باقي %d",
	"Meteors incoming - run!": "نيازك تسقط — اجري!",
	"A guarded treasure appeared - check the radar!": "كنز محروس ظهر — شوف الرادار!",
	"A golden horde passes - hunt it!": "قطيع ذهبي عابر — اصطده!",
	"Chest! %s": "صندوق! %s",
	"Treasure! +25 HP and 8 gems": "الكنز! +25 صحة و8 بلورات",
	"Frozen!": "تجمّدت!",
	"EVOLVED: Polar Storm!": "تطوّر: عاصفة قطبية!",
	"EVOLVED: Blade Cyclone!": "تطوّر: إعصار الشفرات!",
	"EVOLVED: Cluster Bombs!": "تطوّر: قنابل عنقودية!",
	# survivors
	# v1.2: الشخصيات الجديدة
	"Soldier": "الجندي", "Fire Aura": "هالة النار", "Pyromancer": "الساحر الناري", "Shinobi": "الشينوبي",
	"Knight": "الفارس", "Titan": "العملاق", "Gambler": "المقامر",
	"Fire Mage": "ساحر نار", "Shadow Slayer": "قاتل الظل",
	# v1.2.3: Pyromancer + Shadow Slayer
	"A fire caster who burns groups with bolts, blasts, and explosive rhythm": "ساحر نار بيحرق المجموعات بالكرات والانفجارات وإيقاع متفجّر",
	"A fragile assassin who carves foes with fast crescent slashes and dashes": "قاتل هش بينحت الأعداء بسلاشات قوسية سريعة وداشات",
	"Fire Bolts stack Burn - every 3rd hit erupts in a small explosion": "كرات النار بتراكم الحرق - كل ضربة تالتة بتفجّر انفجار صغير",
	"Crescent slashes at close-mid range - 3 dash charges (kills refund). Ultimate unlocks at Lv 7": "سلاشات قوسية مدى قريب-متوسط - 3 شحنات داش (القتل بيردّها). الأولتيمت بتفتح عند Lv 7",
	"Fire Bolt": "كرة النار", "Mid-range fire bolts - every 3 hits explode": "كرات نار متوسطة المدى - كل 3 إصابات بتنفجر",
	"Crescent Slash": "السلاش الهلالي", "Fast arc slashes at close-mid range (cleave)": "سلاشات قوسية سريعة مدى قريب-متوسط (تقطع مجموعة)",
	"Fireball": "كرة اللهب", "Hurl a heavy fireball: big blast, burning ground, and Burn stacks": "ارمِ كرة نار تقيلة: انفجار كبير وأرض مشتعلة وطبقات حرق",
	"Shadow Assault": "الاجتياح الظلّي", "Vanish and cut 3-5 nearby foes in a blur, then reappear (i-frames)": "اختفِ واقطع 3-5 أعداء قريبين في ومضة ثم ارجع (حصانة)",
	"Judgement Rift": "صدع الحساب", "Freeze time briefly, then unleash multi-hit slashes across a wide area": "جمّد الوقت لحظة ثم أطلق سلاشات متعددة على مساحة واسعة",
	"Mid-range / AoE / Burn": "مدى متوسط / منطقة / حرق", "Great against small groups": "قوي ضد المجموعات الصغيرة", "Less accurate and fragile up close": "أقل دقة وهش من قريب",
	"Melee / Hit-and-run": "التحام / اضرب واهرب", "Shreds packs with slashes and dashes": "بيمزّق الحشود بالسلاش والداش", "Fragile - punished when cornered": "هش - بيتعاقب لو اتحاصر",
	"R Locked": "R مقفولة", "Unlocks at Lv 7": "بتفتح عند Lv 7", "JUDGEMENT RIFT!": "!صدع الحساب", "Shadow Assault!": "!اجتياح ظلّي",
	# v1.2.5: أولتيمت كل الشخصيات
	"Heavy Machine Gun": "الرشاش الثقيل", "5s: unleash a giant machine gun - huge fire rate and damage (slower while firing)": "5ث: رشاش عملاق - إيقاع وضرر هائل (أبطأ أثناء الرمي)",
	"Inferno Overload": "طوفان الجحيم", "7s: every shot becomes an exploding mini-fireball that ignites the ground": "7ث: كل طلقة بقت كرة نار صغيرة بتنفجر وبتشعل الأرض",
	"Giant Blade": "السيف العملاق", "5s: swing one huge sword - fast, heavy, wide cleaving arcs": "5ث: أرجح سيفاً ضخماً - سريع وتقيل وأقواس عريضة",
	"Cataclysm Shockwave": "الموجة الكارثية", "Smash the ground for a huge blast - clears commons, hurls elites": "اضرب الأرض بموجة هائلة - تمسح العادي وترمي النخبة",
	"Fate Gamble": "مقامرة القدر", "Roll fate: 50% +40% damage / 50% -40% damage for 30s (no stacking)": "ارمِ القدر: 50% +40% ضرر / 50% -40% ضرر لمدة 30ث (بلا تراكم)",
	"HEAVY MACHINE GUN!": "!الرشاش الثقيل", "INFERNO OVERLOAD!": "!طوفان الجحيم", "GIANT BLADE!": "!السيف العملاق",
	"CATACLYSM SHOCKWAVE!": "!الموجة الكارثية", "FATE GAMBLE!": "!مقامرة القدر",
	"FATE BLESSING! +40% DMG (30s)": "!بركة القدر! +40% ضرر (30ث)", "FATE CURSE! -40% DMG (30s)": "!لعنة القدر! -40% ضرر (30ث)",
	"BAD ROLL! -15% DMG (8s)": "!رمية سيئة -15% ضرر (8ث)", "LUCKY HIT! +15% DMG (8s)": "!ضربة حظ +15% ضرر (8ث)",
	"GOOD ROLL! +25% CRIT (10s)": "!رمية حلوة +25% كريت (10ث)", "BIG WIN! +40% DMG +20% CRIT (8s)": "!مكسب كبير +40% ضرر +20% كريت (8ث)",
	"JACKPOT! ALL CRITS (5s)": "!جاكبوت! كله كريت (5ث)", "CURSED ROLL! -20% HP": "!رمية ملعونة -20% صحة",
	"Tactician": "تكتيكي", "Burning Core": "قلب محترق", "Shadow": "ظل",
	"Blade Wall": "جدار السيوف", "Fortress": "الحصن", "High Roller": "مقامر كبير",
	"A tactical survivor who wins by positioning, turrets, and controlled fire": "ناجٍ تكتيكي بيكسب بالتمركز والتورريت والرماية المحسوبة",
	"A burning core that melts enemies up close, but must live inside danger": "قلب محترق بيسيّح الأعداء من قريب — بس لازم يعيش جوه الخطر",
	"A fragile shadow built around speed, dashes, and perfect timing": "ظل هش مبني على السرعة والداش والتوقيت المثالي",
	"A close-range fighter protected by steel and spinning blades": "مقاتل قريب محميّ بالفولاذ والسيوف الدوّارة",
	"A slow fortress that breaks enemy lines with shockwaves and knockback": "حصن بطيء بيكسر صفوف الأعداء بالموجات الصادمة والدفع",
	"A living die who bets his survival on every roll. One press can win the run... or ruin it": "نرد حي بيراهن بحياته على كل رمية. ضغطة واحدة تكسب الجولة... أو تدمّرها",
	"First level-up offers 4 blessings": "أول ارتقاء بيعرض 4 بركات",
	"Burn stacks up on foes inside the aura. Soul Steal & Recovery are stronger": "الحرق بيتراكم على اللي جوه الهالة. سرقة الأرواح والتعافي أقوى معاه",
	"3 dash charges. The dash itself is the weapon - cut through, never stand still": "3 شحنات داش. الداش نفسه هو السلاح - اقطع من خلالهم وما توقفش",
	"Twin spinning swords guard him - everything close gets cut": "سيفان دوّاران بيحموه - أي حاجة تقرّب بتتقطع",
	"Rhythmic shockwaves shove enemies back - heavy armor, heavier steps": "موجات صادمة منتظمة بتدفع الأعداء - درع تقيل وخطوات أتقل",
	"Dice shots crit far more than anyone. Q is a real gamble - read the odds": "طلقات النرد بتضرب كريت أكتر من أي حد. والـ Q مقامرة حقيقية - اقرأ الاحتمالات",
	# أسلحة التوقيع + القدرات
	"Weapon": "السلاح", "Playstyle": "أسلوب اللعب", "Strength": "القوة", "Weakness": "الضعف", "Difficulty": "الصعوبة",
	"Marksman Rifle": "بندقية قنص", "Slow, precise, piercing shots": "طلقات بطيئة دقيقة مخترقة",
	"Living Flame": "اللهب الحي", "A fire aura that stacks burn on anything inside it": "هالة نار بتراكم الحرق على أي حاجة جواها",
	"Shadow Cut": "قطع الظل", "Dashing slices everything you pass through (brief i-frames)": "الداش بيقطع كل اللي بتعدي منه (حصانة لحظية)",
	"Twin Blades": "السيفان التوأم", "Two orbiting swords - your reach is your armor": "سيفان دوّاران - مداك هو درعك",
	"Seismic Pulse": "النبضة الزلزالية", "Periodic shockwaves that damage and knock back": "موجات صادمة دورية بتضر وبتدفع",
	"Loaded Dice": "النرد المحمّل", "Spinning dice shots with +15% crit chance": "طلقات نرد بتلف بفرصة كريت +15%",
	"Deploy Turret": "نشر تورريت", "Place a turret for 8s (50% of your damage) - enemies get drawn to it": "تورريت 8ث (بنص ضررك) - الأعداء بتنجذب له",
	"Fire Trail": "أثر النار", "4s: leave burning ground behind you and gain +10% speed": "4ث: سيب أرض مشتعلة وراك وخد +10% سرعة",
	"Shadow Clone": "نسخة الظل", "Summon a clone that performs 3 dash cuts (30% damage) then vanishes": "نسخة بتعمل 3 قطعات داش (بـ30% من ضررك) وتختفي",
	"3 dash charges - dash kills refund a quarter charge. The dash itself is the weapon": "3 شحنات داش - قتلة الداش بتردّ ربع شحنة. الداش نفسه هو السلاح",
	"Berserk": "السعار", "5s: blades spin faster, +50% blade damage, +25% speed": "5ث: السيوف أسرع و+50% ضرر و+25% سرعة",
	"Earthbreaker": "كاسر الأرض", "A massive shockwave: heavy damage + huge knockback": "موجة صادمة هائلة: ضرر تقيل ودفع بعيد",
	"All In Roll": "رمية الكل أو لا شيء", "Roll a die: 1 hurts you badly... 6 is the jackpot. High risk, high reward": "ارمِ نرداً: 1 بيوجعك بجد... و6 هي الجاكبوت. مخاطرة عالية بمكافأة عالية",
	# نتائج الرمية
	"CURSED ROLL!": "!رمية ملعونة", "BAD ROLL!": "!رمية سيئة", "LUCKY HIT!": "!ضربة حظ",
	"GOOD ROLL!": "!رمية حلوة", "BIG WIN!": "!مكسب كبير", "JACKPOT!": "!جاكبوت",
	"Turret deployed!": "!التورريت اتنشر", "BERSERK!": "!سعااار",
	# أسلوب/قوة/ضعف/صعوبة
	"Positioning / Precision": "تمركز / دقة", "Strong when holding ground": "قوي وهو ماسك أرضه", "Weaker while running around": "أضعف وهو بيجري كتير", "Low": "سهلة",
	"Close-range / Zone control": "قتال قريب / سيطرة منطقة", "Melts crowds that chase him": "بيسيّح الزحام اللي بيطارده", "Short reach - must stand in danger": "مداه قصير - لازم يقف جوه الخطر", "Medium": "متوسطة",
	"Mobility / Hit-and-run": "حركة / اضرب واهرب", "Untouchable while dashes last": "مستحيل تلمسه طول ما معاه شحنات", "Dies fast when cornered without charges": "بيموت بسرعة لو اتحاصر من غير شحنات", "High": "صعبة",
	"Melee / Sustain pressure": "التحام / ضغط مستمر", "Shreds whatever gets close": "بيفرم أي حاجة تقرّب", "Shooters and kiters outrange him": "الرماة بيضربوه من بعيد",
	"Tank / Crowd break": "دبابة / كسر زحام", "Unmovable, clears packed lines": "ثابت وبيمسح الصفوف المتلاصقة", "Slow - fast strays slip around him": "بطيء - السريع بيلف من حواليه",
	"Risk / Crit / Chaos": "مخاطرة / كريت / فوضى", "Huge upside": "مكسبه ضخم", "Bad rolls can hurt": "الرميات السيئة بتوجع",
	"or 400 kills in a run": "أو 400 قتيل في جولة",
	"or reach Stage 3": "أو تُوصل للفصل 3",
	"or beat 3 bosses in a run": "أو تهزم 3 زعماء في جولة",
	"or win the campaign": "أو تكسب الحملة",
	"or reach Stage 5": "أو تُوصل للفصل 5",
	"LOCKED": "مقفولة",
	"[Enter]  Unlock (%d Cinders)": "[Enter]  افتح (%d جمرة)",
	# stages
	"Meadow": "المرج", "Desert": "الصحراء", "Glacier": "الجليد", "Volcano": "البركان", "The Void": "الفراغ",
	# bosses
	"Meadow Warden": "حارس المرج", "Bone King": "ملك العظام", "Frost Heart": "قلب الجليد",
	"Magma Beast": "وحش الحمم", "Void Shade": "ظل الفراغ", "The Ash King": "ملك الرماد",
	"Lords of the Realms": "أسياد العوالم",
	# upgrades (v1.1: ندرة حقيقية + أثمان واضحة)
	"Firepower": "قوة نارية", "+6 projectile damage": "+6 ضرر للمقذوف",
	"Quick Trigger": "زناد أسرع", "+12% fire rate": "سرعة إطلاق +12%",
	"Extra Volley": "رشقة إضافية", "+1 side shot at 50% damage (35% vs bosses)": "+1 طلقة جانبية بـ50% ضرر (35% ضد الزعماء)",
	"-10% fire rate": "-10% سرعة إطلاق",
	"Piercing": "اختراق", "Shots pierce +1 enemy": "المقذوف يخترق عدواً إضافياً",
	"Orbit Blade": "شفرة دوّارة", "+1 blade spinning around you": "+1 شفرة تدور حولك وتقطع",
	"Burning Aura": "هالة حارقة", "Damage aura around you (+size)": "هالة ضرر حولك (+ اتساع)",
	"Deathblow": "ضربة قاضية", "+8% crit chance (x2 damage, x1.5 vs bosses)": "+8% فرصة كريت (ضرر x2، وx1.5 ضد الزعماء)",
	"Agility": "خفة حركة", "+10% move speed; dashing grants a 2s speed burst": "+10% سرعة حركة؛ الداش يمنح اندفاعة سرعة لثانيتين",
	"Toughness": "صلابة", "+20 max HP and heal 15": "+20 صحة قصوى + علاج 15",
	"Magnet": "مغناطيس", "+50% pickup range; Lv3+: every 30 gems grant +2 XP": "+50% نطاق جذب؛ من المستوى 3: كل 30 بلورة = +2 خبرة",
	"Swift Dash": "اندفاع أسرع", "-20% dash cooldown": "زمن انتظار الداش -20%",
	"Sky Lightning": "صاعقة السماء", "Bolts strike and chain between enemies": "برق يضرب عدواً ويتسلسل لمن حوله",
	"Explosive Death": "موت متفجر", "Enemies explode on death (bosses resist)": "الأعداء ينفجرون عند موتهم (الزعماء يقاومون)",
	"Ricochet": "ارتداد", "Shots bounce to a nearby enemy": "المقذوف يرتد نحو عدو قريب",
	"Rear Guard": "حارس الظهر", "+1 rear shot at 50% damage": "+1 طلقة للخلف بـ50% ضرر",
	"Recovery": "تعافٍ", "Unhurt for 5s: heal 2 HP/s per rank (to 60% HP)": "بعد 5ث بلا ضرر: علاج 2/ث لكل رتبة (حتى 60%)",
	"Off in boss fights - capped per stage": "لا يعمل مع الزعماء - بسقف لكل مرحلة",
	"Steel Plates": "صفائح فولاذ", "-8% damage taken; Lv3+: hits grant a brief shield": "-8% ضرر مُستلَم؛ من مستوى 3: الضربة تمنح درعاً وجيزاً",
	"Soul Steal": "سرقة الأرواح", "Heal 1 HP per 10 kills (Lv2: 7). Elites count x3": "علاج 1 كل 10 قتلى (رتبة 2: كل 7). النخبة بـ3",
	"No boss-fight healing - capped per stage": "لا علاج أثناء الزعماء - بسقف لكل مرحلة",
	"Frost Touch": "لمسة الصقيع", "Your hits slow enemies": "إصاباتك تبطئ الأعداء",
	"Massive Shots": "مقذوفات ضخمة", "+25% projectile size": "حجم المقذوف +25%",
	"Giant Slayer": "قاتل العمالقة", "+20% damage to bosses and elites": "+20% ضرر للزعماء والنخبة",
	"Kill Wave": "موجة الحصاد", "Every 25 kills: a pulse damages and slows foes": "كل 25 قتلة: موجة تضر وتبطئ من حولك",
	"Heavy Core": "القلب الثقيل", "+40% damage": "+40% ضرر",
	"-12% fire rate - 8% move speed": "-12% سرعة إطلاق - 8% سرعة حركة",
	"Execution Core": "قلب الإعدام", "Every 5th volley deals x2 damage (x1.5 vs bosses)": "كل خامس رشقة ضررها x2 (وx1.5 ضد الزعماء)",
	# بركات التأثير v1.1.3
	"Frost Trail": "أثر الصقيع", "Dashing leaves a frost trail that slows foes for 2s": "الداش يترك أثر صقيع يبطئ الأعداء لثانيتين",
	"Marked Target": "هدف معلَّم", "Every 5th hit marks a foe - it bursts into shards on death": "كل خامس ضربة تعلّم عدواً - ينفجر شظايا عند موته",
	"Magnetic Surge": "الموجة المغناطيسية", "Every 30 gems: pull everything in and emit a pulse": "كل 30 بلورة: شفط شامل + نبضة صغيرة",
	"Boss Breaker": "كاسر الزعماء", "Dash near a boss: +25% boss damage per rank for 3s": "داش قريب من الزعيم: +25% ضرر زعماء لكل رتبة لـ3 ثواني",
	"Soul Pulse": "نبضة الأرواح", "Soul Steal heals also knock nearby foes back": "علاج سرقة الأرواح بيدفع الأعداء القريبين للخلف",
	"Guardian Cube": "المكعب الحارس", "An orbiting cube blocks one hit completely": "مكعب يدور حولك يمتص ضربة كاملة",
	"Recharges every 20s (Lv2: 14s)": "يُعاد شحنه كل 20ث (رتبة 2: 14ث)",
	# v1.2 B/C: أسلحة جانبية + باسيفات + تطوّرات
	"Kunai": "كوناي", "Throws piercing knives at the nearest foe (levels: +knife, +pierce, faster)": "يرمي خناجر مخترقة على أقرب عدو (المستويات: +خنجر، +اختراق، أسرع)",
	"Frost Orb": "كرة الصقيع", "An icy orb circles you, chilling and grinding foes in its zone": "كرة جليدية بتدور حواليك بتبرّد وتطحن اللي في نطاقها",
	"Orbit Spikes": "أشواك دوّارة", "+1 spinning spike guarding you up close": "+1 شوكة دوّارة بتحميك من قريب",
	"Lightning Chain": "سلسلة البرق", "Bolts strike and leap between packed foes": "صواعق بتضرب وتنط بين الأعداء المتلاصقين",
	"Bomb Launcher": "قاذف القنابل", "Lobs bombs that blast crowds (Lv4: leaves burning ground)": "يقذف قنابل بتفجّر التجمعات (مستوى 4: أرض مشتعلة)",
	"Marked Shot": "طلقة التعليم", "Every 5th hit marks a foe: +15% damage taken, burst at Lv3": "كل خامس ضربة تعلّم عدواً: +15% ضرر عليه وانفجار من مستوى 3",
	"+1 side shot at 50% damage": "+1 طلقة جانبية بنص الضرر",
	"-10% fire rate - 35% dmg vs bosses": "-10% سرعة إطلاق - 35% ضرر ضد الزعماء",
	"Focus": "تركيز", "-8% Q and side-weapon cooldowns per rank": "-8% تبريد القدرة والأسلحة الجانبية لكل رتبة",
	"Reach": "امتداد", "+12% aura, blast and wave size per rank": "+12% حجم الهالة والانفجارات والموجات لكل رتبة",
	"+6 damage": "+6 ضرر",
	"Precision": "دقة", "+1 Kunai pierce and +5% crit": "+1 اختراق للكوناي و+5% كريت",
	"Frozen Core": "قلب متجمد", "Your slows are 20% stronger per rank": "إبطاءاتك أقوى 20% لكل رتبة",
	"Gunpowder": "بارود", "+20% blast damage per rank": "+20% ضرر الانفجارات لكل رتبة",
	"Conductor": "موصّل", "Lightning leaps +1 extra target per rank": "البرق ينط لهدف إضافي لكل رتبة",
	"Bulwark Core": "قلب الحصن", "-5% damage taken and spikes shove harder": "-5% ضرر مستلَم والأشواك بتزقّ أقوى",
	"Crit Core": "قلب الكريت", "+6% crit and marked foes take +10% more": "+6% كريت والمعلَّمين ياخدوا +10% زيادة",
	"Aura Core": "قلب الهالة", "+15% aura size and aura hits shove slightly": "+15% حجم الهالة وضرباتها بتزقّ برفق",
	"Speed Core": "قلب السرعة", "+6% move speed and -8% dash cooldown": "+6% سرعة حركة و-8% تبريد الداش",
	"Blade Storm": "عاصفة النصال", "Kunai fly out, pierce everything, then return to your hand": "الكوناي بتطلع تخترق كل حاجة وترجع لإيدك",
	"Eternal Winter": "الشتاء الأبدي", "The orb becomes a blizzard: harsher slow + brief freeze (per-foe cooldown)": "الكرة بتبقى عاصفة: إبطاء أقسى + تجميد وجيز (بحصانة لكل عدو)",
	"Meteor Fall": "سقوط النيزك", "A huge bomb falls periodically, blasting and igniting the ground": "قنبلة ضخمة بتنزل دورياً بتفجّر وتولّع الأرض",
	"Thunder Storm": "عاصفة الرعد", "Wider, faster lightning with +3 leaps (bosses resist)": "برق أوسع وأسرع بـ3 قفزات زيادة (الزعماء يقاومون)",
	"Thorn Halo": "هالة الأشواك", "A bigger, faster spike ring that shoves foes and softens contact damage": "حلقة أشواك أكبر وأسرع بتزقّ الأعداء وتليّن ضرر التلامس",
	"Soul Steal heals release a knockback pulse (no extra healing)": "علاج سرقة الأرواح بيطلق موجة دفع (بدون علاج إضافي)",
	"NEW": "جديد", "Evolution path": "مسار تطوّر", "EVOLUTION!": "!تطوّر",
	"Weapons": "الأسلحة", "Passives": "الباسيفات",
	"The boss hardens its shell!": "!الزعيم قوّى قوقعته",
	# Improvement Pass
	"Signature Core": "قلب التوقيع", "+15% signature weapon damage per level": "+15% ضرر سلاح التوقيع لكل مستوى",
	"+10 damage": "+10 ضرر", "+15% fire rate": "سرعة إطلاق +15%",
	"+12% move speed; dashing grants a 2s speed burst": "+12% سرعة حركة؛ الداش يمنح اندفاعة سرعة لثانيتين",
	"+30 max HP and heal 20": "+30 صحة قصوى + علاج 20",
	"+50% pickup range; Lv3: every 30 gems grant +2 XP": "+50% نطاق جذب؛ مستوى 3: كل 30 بلورة = +2 خبرة",
	"-8% damage taken; Lv3: hits grant a brief shield": "-8% ضرر مُستلَم؛ مستوى 3: الضربة تمنح درعاً وجيزاً",
	"+10% crit chance; Lv3: crits ignite foes": "+10% فرصة كريت؛ مستوى 3: الكريت بيولّع الأعداء",
	"-20% dash cooldown; Lv3: dashing pulls gems": "-20% تبريد الداش؛ مستوى 3: الداش بيشفط الجواهر",
	# v1.1.5: عمق البركات ومكافأة الزعيم
	"Shard Seed": "بذرة الشظايا", "Slain foes have a 12% chance per rank to burst into shards": "القتلى ليهم فرصة 12% لكل رتبة يتفتتوا شظايا",
	"Close Call": "نجاة بأعجوبة", "A shot grazing you grants +12% damage and speed for 2s": "طلقة تمرّ لاصقة بيك = +12% ضرر وسرعة لثانيتين",
	"Second Chance": "فرصة تانية", "+1 Reroll for the rest of this run": "+1 إعادة اختيار لباقي الجولة",
	"BOSS REWARD": "مكافأة الزعيم",
	"+1 Reroll!": "+1 إعادة اختيار!",
	"Thunder Loop": "حلقة الرعد", "Bolts leap further and every 12 kills call a storm strike": "البرق يوصل أبعد وكل 12 قتلة ضربة عاصفة",
	"Frost Runner": "عدّاء الصقيع", "Wider frost trail - foes dying on it burst into frost": "أثر صقيع أوسع - اللي يموت فوقه ينفجر صقيعاً",
	"Shatter Mark": "علامة التحطيم", "Marks every 4th hit and marked foes detonate on death": "تعليم كل رابع ضربة والمعلَّم ينفجر عند موته",
	"EVOLVED: Thunder Loop!": "تطوّر: حلقة الرعد!",
	"EVOLVED: Frost Runner!": "تطوّر: عدّاء الصقيع!",
	"EVOLVED: Shatter Mark!": "تطوّر: علامة التحطيم!",
	# tags (أوسمة البركات على الكروت)
	"Damage": "ضرر", "Projectile": "مقذوفات", "FireRate": "سرعة إطلاق", "Crit": "كريت",
	"Healing": "علاج", "Sustain": "صمود", "Dash": "اندفاع", "Utility": "منفعة",
	"Economy": "اقتصاد", "AoE": "منطقة", "Boss": "زعماء", "Risk": "مخاطرة", "Evolution": "تطوّر",
	# evolutions
	"Polar Storm": "عاصفة قطبية", "Lightning doubles and freezes all it touches": "الصاعقة تتضاعف وتجمّد كل ما تلمسه",
	"Blade Cyclone": "إعصار الشفرات", "Double blades, faster and deadlier": "ضعف الشفرات وأسرع وأفتك",
	"Cluster Bombs": "قنابل عنقودية", "Every explosion spawns 3 smaller ones": "كل انفجار يولّد 3 انفجارات صغيرة",
	# متجر الترقيات الدائمة
	"PERMANENT UPGRADES": "الترقيات الدائمة",
	"MAX": "الأقصى",
	"W/S select   •   Enter buy   •   Backspace back": "W/S تنقّل   •   Enter شراء   •   Backspace رجوع",
	"[U] Upgrades      [S] Settings": "[U] الترقيات      [S] الإعدادات",
	"[U] Upgrades   [C] Records   [S] Settings": "[U] الترقيات   [C] السجلّات   [S] الإعدادات",
	"RECORDS": "السجلّات",
	"— Best Run —": "— أفضل جولة —",
	"Best Stage: %d/%d    Best Time: %02d:%02d    Most Kills: %d    Wins: %d": "أفضل فصل: %d/%d    أفضل زمن: %02d:%02d    أكثر قتلى: %d    انتصارات: %d",
	"— Lifetime —": "— الإجمالي —",
	"Runs: %d    Kills: %d    Bosses: %d    Gems: %d": "جولات: %d    قتلى: %d    زعماء: %d    بلورات: %d",
	"Cinders: %d    Survivors: %d/%d    Achievements: %d/%d    Danger: %d": "جمرات: %d    ناجون: %d/%d    إنجازات: %d/%d    خطر: %d",
	"Backspace back    •    [Del] Reset progress (press again to confirm)": "Backspace رجوع    •    [Del] مسح التقدّم (اضغط تاني للتأكيد)",
	"!! Press [Del] again to WIPE all progress — Backspace to cancel !!": "!! اضغط [Del] تاني لمسح كل التقدّم — Backspace للإلغاء !!",
	"[T] Danger %d": "[T] خطر %d",
	"SECOND WIND!": "نفَس ثانٍ!",
	"Vitality": "حيوية", "+10 Max HP per tier": "+10 صحة قصوى لكل مستوى",
	"Might": "بأس", "+2 damage per tier": "+2 ضرر لكل مستوى",
	"Cooldown": "تبريد", "+4% fire rate per tier": "+4% سرعة إطلاق لكل مستوى",
	"Move Speed": "سرعة الحركة", "+8 move speed per tier": "+8 سرعة حركة لكل مستوى",
	"+20 pickup range per tier": "+20 نطاق جذب لكل مستوى",
	"Growth": "نمو", "+6% XP gain per tier": "+6% كسب خبرة لكل مستوى",
	"-6% dash cooldown per tier": "-6% تبريد الاندفاع لكل مستوى",
	"Armor": "درع", "-8% damage taken per tier": "-8% ضرر مُستلَم لكل مستوى",
	"Start with Recovery Lv1": "ابدأ ببركة التعافي (رتبة 1)",
	"Greed": "جشع", "+8% Cinders earned per tier": "+8% جمرات مكتسبة لكل مستوى",
	"Revival": "إحياء", "Revive once per run at 40% HP": "إحياء مرة كل جولة بـ40% صحة",
	# الإنجازات
	"* %s  (+%d Cinders)": "* %s  (+%d جمرة)",
	"— %s unlocked!": "— فُتحت %s!",
	"First Blood": "أول دم", "Realm Walker": "سائر العوالم", "Boss Slayer": "قاتل الزعماء",
	"Centurion": "القائد", "Massacre": "مذبحة", "Triple Threat": "تهديد ثلاثي",
	"Combo Master": "سيّد الكومبو", "Evolved": "متطوّر", "Void Walker": "سائر الفراغ",
	"Ash Conqueror": "قاهر الرماد", "Speed Demon": "شيطان السرعة", "Hoarder": "مكتنِز",
	# language screen
	"Choose Language / اختر اللغة": "Choose Language / اختر اللغة",
	"[E]  English": "[E]  English",
	"[A]  العربية": "[A]  العربية",
}

# --- سجلات دائمة ---
var rec_time := 0.0
var rec_kills := 0
var rec_stage := 0
var rec_wins := 0
# إحصائيات تراكمية (lifetime)
var total_runs := 0
var total_kills := 0
var total_bosses := 0
var total_gems := 0
const FINAL_STAGE := 5   # الحملة: 5 فصول وتنتهي بالنصر

# --- الأبطال ---
var char_sel := 0
var CHARS := Balance.CHARS   # تعريف الأبطال في res://data/balance.gd
var pcol := Color(0.20, 0.45, 0.90)

# --- كومبو / هيت-ستوب / تطوّرات / أحداث ---
var combo := 0
var combo_best := 0
var combo_t := 0.0
var hitstop := 0.0
var ups_count := {}
var evo_storm := false
var evo_cyclone := false
var evo_cluster := false
var evo_pending := ""
var EVOS := Balance.EVOS   # تطوّرات الأسلحة في res://data/balance.gd
# --- Synergies ---
var syn_active := {}       # id -> true للتركيبات المفعّلة هذه الجولة
var syn_found := {}        # id -> true للمكتشفة (يُحفظ عبر الجولات)
var syn_orbit_t := 0.0     # مؤقّت رشقات Arcane Orbit
var syn_frost_t := 0.0     # مؤقّت نبضة Frost Pulse
var is_moving := false     # للـ Momentum: هل اللاعب يتحرّك الآن؟
var pending_aoe := []      # ضربات منطقة مؤجّلة (تُطبّق بأمان بعد حلقات القتال — تجنّب حذف وسط التكرار)
var event_t := 0.0
var meteors := []       # {pos, t}
# Polish v1.1.2: اتشالت الصناديق (chest/boxes) نهائياً — كانت مصدر قوة مجانية بيكسر قيمة البناء

# --- settings (persisted) ---
var sfx_vol := 8      # 0..10
var mus_vol := 8      # 0..10
var shake_on := true
var fullscreen_on := false
var set_sel := 0      # الصف المختار في شاشة الإعدادات
const SET_ROWS := 7   # عدد صفوف الإعدادات
const SET_TOP := 150.0
const SET_STEP := 68.0
var dmgnum_on := true   # عرض أرقام الضرر
var tips_on := true     # تلميحات التعليم (Tutorial tips)
var tips_seen := {}     # id التلميح -> true (يظهر مرة واحدة)

# --- meta-progression (يُحفظ عبر الجولات) ---
var cinders := 0        # عملة دائمة تُكتسب آخر كل جولة (زي Gold في Vampire Survivors)
var run_bosses := 0     # عدّاد زعماء الجولة الحالية (لمعادلة المكافأة) — يتصفّر كل جولة
var last_cinders := 0   # آخر مبلغ مكتسب (للعرض على شاشة النهاية)
var shop := {}          # id -> المستوى المملوك (متجر الترقيات الدائمة)
var unlocked := {}      # اسم الشخصية -> true (الجندي مفتوح دايماً)
var achieved := {}      # id الإنجاز -> true
var run_gems := 0       # بلورات مجموعة في الجولة الحالية (لإنجاز Hoarder)
# مُعدِّلات الميتا (تُحسب في _apply_meta أول كل جولة)
var meta_xp_mul := 1.0        # مضاعف كسب الـ XP (Growth)
var xp_bank := 0.0            # بنك كسور الـ XP (عشان Growth ما يضيّعش الكسور)
var meta_cinder_bonus := 0.0  # + نسبة الجمرات المكتسبة (Greed)
var revive_ready := false     # إحياء لمرة واحدة في الجولة (Revival / Second Wind)
# Ascension (مستويات صعوبة زي Danger في Brotato) — تُفتح بعد أول فوز
var asc := 0            # المستوى المختار
var asc_max := 0        # أعلى مستوى مفتوح (0 = مفيش، يزيد كل فوز)
const ASC_MAX := 5
# مُعدِّلات الجولة الحالية من الـ Ascension (تُحسب في _apply_meta)
var asc_hp := 1.0
var asc_spd := 1.0
var asc_dmg := 1.0
var asc_spawn := 1.0
var asc_cinder := 1.0
var asc_enrage := 0.5   # عتبة الغضب (نص الصحة افتراضياً)
var asc_elite := 0.0    # + فرصة النخبة
var asc_healcap := 1.0  # مضاعف سقوف العلاج (يقل في Danger III/V)
var asc_boss_atk := 1.0 # سرعة إيقاع هجمات الزعيم (Danger V أسرع)
var asc_trap := 1.0     # سرعة الفخاخ (Danger IV أسرع = أقل من 1)
var asc_heal_boss := 0.5 # مضاعف العلاج أثناء الزعيم (Danger II+: أقسى)
# متجر الترقيات (UI)
var shop_sel := 0
var shop_dim: ColorRect
var shop_rows: Array = []
var shop_title: Label
var shop_cinders_lbl: Label
var shop_hint: Label
# شاشة الإحصائيات
var stats_dim: ColorRect
var stats_title: Label
var stats_body: Label
var stats_hint: Label
var reset_armed := false   # تأكيد مسح التقدّم (خطوتان)

# --- player ---
var pp := Vector2(W * 0.5, H * 0.5)
var pspeed := 300.0
const PR := 16.0
var hp := 100.0
var maxhp := 100.0
var invuln := 0.0
const DASH_CD := 2.0
var dash_cd := 0.0
var dash_t := 0.0

# --- progression ---
var kills := 0
var level := 1
var xp := 0
var xp_need := 6
var gametime := 0.0        # يتجمّد أثناء الزعيم
var animt := 0.0

# --- stage system (مرحلة كل دقيقة + ثيم) ---
const STAGE_LEN := 60.0
var stage := 1
var stage_timer := STAGE_LEN
var decor := []            # ديكور الساحة الحالي

var THEMES := Balance.THEMES   # الثيمات/المراحل في res://data/balance.gd
func theme_idx() -> int:
	return (stage - 1) % THEMES.size()

# --- weapons / stats ---
var fire_cd := 0.0
var fire_rate := 0.5
var bullet_speed := 620.0
var bullet_dmg := 20.0
var multishot := 1
var pierce := 0
var crit := 0.0
var magnet := 130.0
var orbit_n := 0
var orbit_ang := 0.0
const ORBIT_R := 72.0
const ORBIT_DMG := 30.0
var aura_r := 0.0
const AURA_DPS := 22.0
# بركات v5
var chain_n := 0        # صاعقة متسلسلة
var chain_t := 0.0
var explode_n := 0      # موت متفجر
var ric_n := 0          # ارتداد
var rear_n := 0         # طلقة خلفية
var regen_n := 0        # تجدد
var armor_n := 0        # دروع
var steal_n := 0        # امتصاص أرواح
var slow_n := 0         # لمسة صقيع
var bsize := 1.0        # حجم المقذوف
# --- هوية الشخصية (Balance v1.1) — سقوف ومضاعفات لا تتخطاها باقي الشخصيات ---
var heal_mul := 1.0        # فعالية كل علاج (Burner 1.35 · Runner 0.75 · Specter 0.6)
var crit_cap := 0.5        # سقف الكريت (Specter فقط 0.75)
var rate_floor := 0.16     # أدنى زمن بين الطلقات (Titan/Wrecker أعلى = أبطأ سقف رماية)
var speed_cap := 470.0     # سقف سرعة الحركة (Runner فقط 620)
var luck_f := 1.0          # مضاعف حظ لندرة أعلى (Runner/Specter)
var char_steal_bonus := false  # Burner: متطلبات أقل وسقوف علاج أعلى (هوية الـ Sustain)
# --- أنظمة العلاج المقيّد (Anti-heal) ---
var no_dmg_t := 99.0       # ثواني بلا ضرر (شرط الـ Recovery)
var wound_t := 0.0         # جرح النخبة: يمنع كل علاج مؤقتاً
var vamp_cd := 0.0         # تبريد Vampiric Edge
var shatter_cd := 0.0      # تبريد Shatter Core
var plating_t := 0.0       # نص ضرر مؤقت بعد الضربة (Steel Plates Lv3+)
var plating_cd := 0.0
var burst_spd_t := 0.0     # اندفاعة سرعة بعد الداش (Agility)
var stage_heal_regen := 0.0  # علاج Recovery المستهلك هذه المرحلة (سقف)
var stage_heal_steal := 0.0  # علاج Soul Steal المستهلك هذه المرحلة (سقف)
var steal_kills := 0       # عدّاد قتلى Soul Steal
var pulse_kills := 0       # عدّاد Kill Wave
var magnet_gems := 0       # عدّاد بلورات Magnet Lv3+
var volley_i := 0          # عدّاد الرشقات (Execution Core)
var zaps := []          # رسم الصواعق {pts, life}
var hazards := []       # مناطق خطر أرضية {pos, r, life, dps, col}
var vacuum_t := 0.0     # شفط البلورات بعد الزعيم
var boss_name_cur := ""

# --- feel ---
var shake := 0.0
var flash := 0.0
var wipe_t := 0.0          # وميض مسح الأعداء
var hurt_snd_cd := 0.0
var kill_snd_cd := 0.0   # cooldown لصوت القتل (منع spam في الزحمة)

# --- entities ---
var enemies := []
var bullets := []
var ebullets := []         # مقذوفات الزعيم
var gems := []
var parts := []
var trail := []
var dmgnums := []

var spawn_cd := 0.0
var boss_alive := false
var boss_warned := false   # تحذير اقتراب البوس (مرة كل مرحلة)
var rng := RandomNumberGenerator.new()
var FONT: Font
var IS_WEB := OS.has_feature("web")   # المتصفح أبطأ — نخفف عنه
var tile_tex := []   # بلاطات بكسل آرت مولّدة للثيم الحالي
var SPR := {}        # سبرايتات بكسل للكائنات (بيضاء تتلوّن عند الرسم)
var traps := []      # فخاخ الفصول {k:"spike"/"burn"/"freeze", pos, ...}
var trap_t := 6.0    # مؤقت فخ الفصل الحالي
var freeze_t := 0.0  # تجميد اللاعب (فخ الجليد)
var void_intro := 0.0   # عدّ تنازلي لعودة أسياد العوالم
var king_spawned := false

# --- nodes ---
var cam: Camera2D
var hud: CanvasLayer
var hud_panels: Array = []   # لوحات خلفية موحّدة للـ HUD (تُخفى مع الـ HUD)
var lbl_kills: Label
var lbl_level: Label
var lbl_time: Label
var lbl_stage: Label
var lbl_boss: Label
var lbl_msg: Label
var hp_back: ColorRect
var hp_fill: ColorRect
var xp_back: ColorRect
var xp_fill: ColorRect
var dash_back: ColorRect
var dash_fill: ColorRect
var _msg_t := 0.0

var lv_dim: ColorRect
var lv_title: Label
var lv_hint: Label
# انتقال fade ناعم بين الشاشات
var fade_rect: ColorRect
var fade_a := 0.0
var rotate_dim: ColorRect   # v1.1.3 Hotfix: طبقة "لفّ جهازك" للبورتريه
var rotate_lbl: Label
var _last_state := -1
var mouse_pos := Vector2.ZERO   # لتتبّع الـ hover على القوائم
var hover_id := ""              # العنصر اللي الماوس فوقه حاليًا
var lv_cards: Array = []
var lv_choices: Array = []
var rerolls := 2      # إعادة اختيار محدودة كل جولة

var go_dim: ColorRect
var go_title: Label
var go_stats: Label

var menu_dim: ColorRect
var menu_labels: Array = []
var menu_char: Label
var menu_rec: Label
var menu_title: Label
var menu_sub: Label
var menu_hint: Label
var menu_sel := 0                 # الزر المختار في القائمة الرئيسية (0..MENU_BTNS-1)
# --- شاشة اختيار الناجي ---
var cs_dim: ColorRect
var cs_title: Label
var cs_name: Label
var cs_role: Label
var cs_desc: Label
var cs_info: Array = []   # سطور بطاقة الشخصية الست (سلاح/Q/أسلوب/صعوبة/قوة/ضعف)
var cs_hint: Label
var cs_stat_labels: Array = []    # أسماء الإحصائيات الخمسة
# --- شاشة اختيار الصعوبة ---
var df_dim: ColorRect
var df_title: Label
var df_name: Label
var df_desc: Label
var df_hint: Label
var df_row_labels: Array = []     # أسماء المستويات (فوق كل صفّ)
var df_mod_labels: Array = []     # أسطر الـ modifiers للمستوى المختار
var df_char_lbl: Label            # اسم الناجي المختار (تذكير)
const CS_STAT_NAMES := ["Health", "Speed", "Power", "Defense", "Luck"]
const CS_STAT_COLS := [Color(0.35, 0.85, 0.45), Color(0.45, 0.80, 1.0), Color(0.95, 0.45, 0.35), Color(0.70, 0.75, 0.88), Color(1.0, 0.82, 0.35)]
var df_sel := 0                   # مستوى الصعوبة المختار (0..asc_max داخل الحد المفتوح)
var cr_dim: ColorRect             # شاشة الكريدت
var cr_title: Label
var cr_body: Label
var cr_hint: Label
# --- تنقّل بالماوس (Web) ---
const BACK_RECT := Rect2(24.0, 22.0, 158.0, 46.0)   # زر رجوع موحّد أعلى-يسار
const PAUSE_BTN_RECT := Rect2(1226.0, 12.0, 40.0, 40.0)   # زر إيقاف داخل اللعب (أعلى-يمين)
var back_btns := {}               # state(int) -> button dict
var pause_hud_btn: Dictionary = {}   # زر الإيقاف داخل اللعب (HUD)
var go_btns := {}                 # أزرار شاشة النهاية (restart/menu)
var vic_btn: Dictionary = {}      # زر شاشة النصر (menu)
var pause_confirm := ""           # "" أو "restart" أو "menu" — تأكيد أثناء الإيقاف
# نصوص أزرار القائمة الرئيسية (id للتنفيذ + عنوان)
const MENU_BTNS := [
	{"id": "start",    "label": "Start Game"},
	{"id": "upgrades", "label": "Upgrades"},
	{"id": "records",  "label": "Records"},
	{"id": "settings", "label": "Settings"},
	{"id": "credits",  "label": "Credits"},
	{"id": "quit",     "label": "Quit"},
]
var set_title: Label
var set_hint: Label
var pause_title: Label
var pause_opts: Label            # سطر اختصارات صغير أسفل قائمة الإيقاف
var pause_hint: Label
var pause_labels: Array = []     # نصوص أزرار قائمة الإيقاف
var pc_prompt: Label             # نص تأكيد الإيقاف (Restart/Main Menu)
var pc_yes: Label
var pc_no: Label
var pause_sel := 0               # الزر المختار في قائمة الإيقاف
var set_return := ST_MENU        # الشاشة التي نعود إليها من الإعدادات (قائمة رئيسية أو إيقاف)
const PAUSE_BTNS := [
	{"id": "resume",   "label": "Resume"},
	{"id": "restart",  "label": "Restart Run"},
	{"id": "settings", "label": "Settings"},
	{"id": "menu",     "label": "Main Menu"},
]
var vic_title: Label
var lang_dim: ColorRect
var vic_dim: ColorRect
var vic_stats: Label
var lbl_combo: Label
var lbl_wound: Label   # مؤشر الجرح: العلاج ممنوع (وضوح الـ anti-heal)
# --- Polish v1.1.2: وضوح الصحة + رسائل أهدى ---
var lbl_hp: Label          # رقم الصحة داخل الشريط (82 / 100)
var hp_prev := -1.0        # لاكتشاف الضرر/العلاج (وميض الرقم)
var hp_flash_t := 0.0      # مؤقّت وميض رقم الصحة
var hp_flash_heal := false # الوميض أخضر (علاج) أم أحمر (ضرر)
var lbl_toast: Label       # رسائل ثانوية صغيرة أسفل الشاشة (بدل النص الكبير في النص)
var _toast_t := 0.0
var stage_intro_t := 0.0       # بانر انتقال المرحلة (رسم ناعم بدل النص المفاجئ)
var stage_intro_title := ""
var stage_intro_sub := ""
# --- v1.1.3: بركات التأثير الجديدة ---
var frost_trail := []      # بقع صقيع خلف الداش {pos, life}
var mark_hits := 0         # عدّاد Marked Target (كل خامس ضربة)
var msurge_gems := 0       # عدّاد Magnetic Surge (كل 30 بلورة)
var bbreak_t := 0.0        # نافذة Boss Breaker (+ضرر زعماء بعد داش قريب)
var guard_cd := 0.0        # تبريد Guardian Cube (جاهز لو <= 0)
# --- v1.1.5: عمق البركات ومسارات التطوّر ---
var closecall_t := 0.0     # باف Close Call بعد طلقة مرقت جنبك
var thunder_kills := 0     # عدّاد Thunder Loop (كل 12 قتلة = ضربة عاصفة)
var thunder_pending := false  # ضربة عاصفة مؤجّلة (تنفَّذ خارج حلقات القتل بأمان)
var frost_burst_cd := 0.0  # تبريد انفجارات Frost Runner
var evo_thunder := false
var evo_frostrun := false
var evo_shatter := false
var boss_reward_active := false  # شاشة مكافأة الزعيم (اختيار مقصود مش صندوق عشوائي)
# --- v1.1.3: ضغط ساحة الزعيم ---
var boss_minion_t := 0.0   # مؤقّت موجات التوابع
var boss_kite_t := 0.0     # عدّاد الابتعاد عن الزعيم (anti-kite)
var boss_haz_t := 0.0      # مؤقّت المخاطر الأرضية
# --- v1.1.4: ذكاء الأعداء ---
var pvel := Vector2.ZERO   # سرعة اللاعب الملسّاة (للتوقع predictive movement)
var DBG_AI := false        # --aidebug: عرض أدوار الأعداء وحالات الزعيم (تطوير فقط)
# --- v1.2 Phase A: أسلحة التوقيع وقدرات Q ---
var sig := "rifle"         # سلاح توقيع الشخصية الحالية (من CHARS)
var q_cd := 0.0            # تبريد القدرة الحالي
var q_cd_max := 14.0
var dash_charges := 3      # شحنات داش الشينوبي (الباقي شحنة واحدة سلوكياً)
var dash_charges_max := 1
var dash_recharge_t := 0.0
var dash_id := 0           # رقم الداش الحالي (عشان ضربة الداش تصيب كل عدو مرة لكل داش)
var wave_cd := 0.0         # إيقاع موجات Titan
var q_turret = null        # {pos, t, cd} تورريت الجندي
var q_clone = null         # {pos, t, dashes} نسخة الشينوبي
var berserk_t := 0.0       # Berserk الفارس
var q_firetrail_t := 0.0   # مدة Fire Trail
var fire_patches := []     # بقع نار Fire Trail {pos, life}
var g_dmg_mul := 1.0       # بافات/عقوبات المقامر المؤقتة (All In Roll)
var g_dmg_t := 0.0
var g_crit_add := 0.0
var g_crit_t := 0.0
var g_rate_mul := 1.0
var g_rate_t := 0.0
var roll_anim_t := 0.0     # عرض نتيجة النرد فوق اللاعب
var roll_result := 0
var lbl_q: Label           # مؤشر جاهزية Q في الـ HUD
var kill_src := ""         # مصدر الضربة القاتلة (لمكافأة قتل الداش عند الشينوبي)
# --- v1.2.3: Pyromancer (Fire Bolt) + Shinobi (Crescent Slash + Shadow Assault + Judgement Rift R) ---
var fbolt_hits := 0        # عدّاد إصابات كرة النار — كل 3 = انفجار
var fireballs := []        # كرات Fireball الطايرة (قدرة Pyromancer) {pos, vel, life, r}
var slash_cd := 0.0        # إيقاع Crescent Slash
var slash_fx := []         # مؤثرات القوس البصرية {pos, ang, arc, reach, life, max, col}
var sassault = null         # Shadow Assault الجاري {t, hits, dmg, targets}
var r_cd := 0.0            # تبريد الأولتيمت (Judgement Rift)
var r_cd_max := 60.0
var r_active_t := 0.0      # نافذة الحصانة أثناء تنفيذ R
var rift = null             # Judgement Rift الجاري {t, r, dmg, marks}
var lbl_r: Label           # مؤشر الأولتيمت R في الـ HUD (كل الشخصيات)
# v1.2.5: أولتيمت لكل الشخصيات
var r_buff_t := 0.0        # مدة الأولتيمت النشط (Soldier HMG / Pyromancer Inferno / Knight Giant Blade)
var r_fate_mul := 1.0      # مضاعف ضرر Gambler Fate Gamble
var r_fate_t := 0.0        # مدة Fate Gamble المتبقية
var r_fate_good := false   # بركة (true) أم لعنة (false)
var lbl_status: Label      # مؤشر حالة مؤقتة (بافات المقامر مع عدّاد)
# --- v1.2 B/C: أسلحة جانبية + تطوّرات ---
var kunai_cd := 0.0        # إيقاع الكوناي
var forb_ang := 0.0        # زاوية دوران Frost Orb
var bomb_cd := 0.0         # إيقاع القاذف
var bombs := []            # قنابل طايرة {pos, tgt, t}
var fmeteors := []         # نيازك صديقة (Meteor Fall) {pos, t}
var fmeteor_cd := 0.0
var orbit_radius := 72.0   # نطاق الأشواك الدوّارة (Thorn Halo بيوسّعه)
var evo_bladestorm := false
var evo_ewinter := false
var evo_meteor := false
var evo_tstorm := false
var evo_thalo := false
var evo_soulp := false
var lv_slots: Label        # عرض الخانات في شاشة الارتقاء (أسلحة 2/3 · باسيف 3/4)
var rings := []   # حلقات موت متمددة {pos, t, max, col}
var set_dim: ColorRect
var set_rows: Array = []
var set_bars: Array = []   # [{back, fill}] لصفّي الصوت
var pause_dim: ColorRect

# الصوت اتنقل لـ autoload اسمه Audio (res://autoload/audio_manager.gd)

var ENEMY_COLS := [
	Color(0.85, 0.30, 0.30), Color(0.35, 0.55, 0.90), Color(0.55, 0.80, 0.40),
	Color(0.80, 0.55, 0.25), Color(0.70, 0.40, 0.80), Color(0.30, 0.75, 0.75),
	Color(0.90, 0.75, 0.30), Color(0.55, 0.45, 0.35),
]

var UPS := Balance.UPS   # الترقيات (blessings) في res://data/balance.gd
# v1.1.5: كارت مكافأة الزعيم "فرصة تانية" — +1 إعادة اختيار (id خاص، مش في الـ pool العادي)
const RRBONUS := {"id": "rrbonus", "name": "Second Chance", "desc": "+1 Reroll for the rest of this run", "rar": 1, "max": 99, "cat": "Effect", "tags": ["Utility"]}
var dash_cd_max := DASH_CD

# ================================================================
func _ready() -> void:
	# قراءة إعدادات لقطة الشاشة من سطر الأوامر (بعد --) أول حاجة
	for _a in OS.get_cmdline_user_args():
		if _a.begins_with("--shot="):
			SHOTMODE = true
			SHOTSCENE = _a.substr(7)
		elif _a.begins_with("--shotout="):
			SHOTPATH = _a.substr(10)
		elif _a.begins_with("--shotchar="):
			SHOTCHAR = clampi(int(_a.substr(11)), 0, 5)
		elif _a == "--bench":
			BENCH = true
		elif _a.begins_with("--autoplay="):
			AUTOPLAY = true
			AUTO_RUNS = maxi(1, int(_a.substr(11)))
		elif _a.begins_with("--meta="):
			AUTO_META = clampf(float(_a.substr(7)), 0.0, 1.0)
		elif _a.begins_with("--char="):
			AUTO_CHAR = clampi(int(_a.substr(7)), 0, 5)
		elif _a.begins_with("--danger="):
			AUTO_DANGER = clampi(int(_a.substr(9)), 0, 5)
		elif _a == "--aidebug":
			DBG_AI = true
		elif _a.begins_with("--grant="):
			AUTO_GRANT = _a.substr(8)   # مثال: kunai:4,precision:1 — لاختبار الوصفات حتمياً
	if SHOTMODE:
		rng.seed = 987654321   # seed ثابت عشان اللقطات تبقى قابلة للتكرار (regression)
		seed(987654321)        # الـ global RNG كمان (shuffle/randi في اختيار الكروت)
	else:
		rng.randomize()
	# خط عربي+لاتيني مُضمَّن — عشان النصوص (خصوصاً العربية) تبان على الويب.
	# القاعدة: لا نعتمد على خط النظام إطلاقاً؛ نستخدم خط المشروع المرفق.
	# المصدر الأساسي: ثيم المشروع (gui/theme/custom) الذي يحمّله المحرّك عند الإقلاع.
	# هنا نضبط FONT (للنصوص المرسومة يدوياً) و ThemeDB.fallback_font كطبقة أمان إضافية.
	var afont: Font = load("res://assets/Cairo.ttf")
	if afont == null:
		# احتياطي: خذ الخط من ثيم المشروع المطبّق عبر الإعدادات
		var pth := ThemeDB.get_project_theme()
		if pth != null and pth.default_font != null:
			afont = pth.default_font
	if afont != null:
		FONT = afont
		ThemeDB.fallback_font = afont            # كل الـLabels تستعمله تلقائياً
	else:
		FONT = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # بكسلات حادة
	_gen_sprites()
	_load_settings()
	cam = Camera2D.new()
	cam.position = WC
	cam.enabled = true
	add_child(cam)
	# توهج نيون على العناصر الفاتحة (تقيل على المتصفح — ديسكتوب فقط)
	if not IS_WEB:
		var env := Environment.new()
		env.background_mode = Environment.BG_CANVAS
		env.glow_enabled = true
		env.glow_intensity = 0.28          # توهج أخف (كان بيعمي مع الخلفيات الساطعة)
		env.glow_strength = 0.85
		env.glow_bloom = 0.0
		env.glow_hdr_threshold = 1.05      # بس العناصر الساطعة جداً بتتوهّج
		var we := WorldEnvironment.new()
		we.environment = env
		add_child(we)
	_build_hud()
	_build_levelup_ui()
	_build_gameover_ui()
	_build_menu_ui()
	_build_settings_ui()
	_build_pause_ui()
	_build_victory_ui()
	_build_lang_ui()
	_build_shop_ui()
	_build_stats_ui()
	_build_charsel_ui()
	_build_diff_ui()
	_build_credits_ui()
	# طبقة الـ fade فوق كل الواجهات (تتحرك في _process)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.size = Vector2(W, H)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.z_index = 100
	add_child(fade_rect)
	# v1.1.3 Hotfix: طبقة "لفّ جهازك" (بورتريه موبايل) — فوق كل حاجة
	var rot_layer := CanvasLayer.new()
	rot_layer.layer = 120
	add_child(rot_layer)
	rotate_dim = ColorRect.new()
	rotate_dim.color = Color(0.02, 0.02, 0.04, 0.96)
	rotate_dim.size = Vector2(W, H)
	rotate_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rot_layer.add_child(rotate_dim)
	rotate_lbl = _mk_label(Vector2(W * 0.5 - 400, H * 0.5 - 40), 34, Color(1, 0.9, 0.5), rotate_dim)
	rotate_lbl.size = Vector2(800, 80)
	rotate_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotate_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotate_dim.visible = false
	# v1.1.3 Hotfix: تثبيت مقاس العرض — إعادة تطبيق التحجيم بعد أول فريمين (الويب أحياناً
	# بيدّي مقاس canvas غير نهائي عند الإقلاع) + متابعة أي resize لاحق
	get_tree().root.size_changed.connect(_on_window_resized)
	if not SHOTMODE and not BENCH:
		_boot_viewport_fix()
	_apply_fullscreen()
	_gen_decor()
	# أول تشغيل: شاشة اختيار اللغة؛ بعد كده استخدم المحفوظ (يتغيّر لاحقاً من الإعدادات)
	if not SHOTMODE and not lang_chosen:
		_show_lang_screen()
	else:
		_show_only_menu()
	if not SHOTMODE and not BENCH:
		Audio.play_music("menu")

	if BENCH:
		_bench_setup()

	if AUTOPLAY:
		_auto_start()

	if SHOTMODE:
		_simulate_for_shot()
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var shot_img := get_viewport().get_texture().get_image()
		if SHOTSCENE == "cover":
			# غلاف itch.io: قصّ 5:4 من منتصف اللقطة أياً كانت دقتها ثم 630×500
			var isz := shot_img.get_size()
			var cw2 := int(float(isz.y) * 630.0 / 500.0)
			var region := shot_img.get_region(Rect2i((isz.x - cw2) / 2, 0, cw2, isz.y))
			region.resize(630, 500, Image.INTERPOLATE_LANCZOS)
			region.save_png(SHOTPATH)
		else:
			shot_img.save_png(SHOTPATH)
		print("SHOT done")
		get_tree().quit()

# ---------- AUTOPLAY (بوت المعايرة) ----------
func _auto_start() -> void:
	Engine.max_fps = 0
	# متجر بنسبة الترقيات المطلوبة (0..1 من مستويات كل خط)
	shop = {}
	for m in Balance.META_SHOP:
		var n := int(round(AUTO_META * float((m["costs"] as Array).size())))
		if n > 0:
			shop[m["id"]] = n
	char_sel = AUTO_CHAR
	unlocked[CHARS[AUTO_CHAR]["name"]] = true
	asc = AUTO_DANGER
	asc_max = AUTO_DANGER
	print("=== AUTOPLAY: %d runs | char=%s | meta=%.0f%% | danger=%d ===" %
		[AUTO_RUNS, CHARS[AUTO_CHAR]["name"], AUTO_META * 100.0, AUTO_DANGER])
	rng.seed = 1337
	_new_run()
	_auto_apply_grant()

# منح بركات الاختبار (--grant) — بيتنفذ أول كل جولة autoplay
func _auto_apply_grant() -> void:
	if AUTO_GRANT == "":
		return
	for tok in AUTO_GRANT.split(","):
		var parts = tok.split(":")
		var n := int(parts[1]) if parts.size() > 1 else 1
		for k in n:
			_apply_upgrade(String(parts[0]))

# محرك الاختبار: يلعب/يختار/يعيد التشغيل — AUTO_SPEED خطوة لكل فريم
func _auto_tick() -> void:
	for i in AUTO_SPEED:
		match state:
			ST_PLAY:
				hitstop = 0.0
				_step(1.0 / 60.0)
			ST_LEVELUP:
				# اختيار عشوائي — تقريب لاعب متوسط بلا تخطيط build
				var pick := rng.randi() % maxi(1, lv_choices.size())
				_apply_upgrade(lv_choices[pick])
				lv_dim.visible = false
				state = ST_PLAY
			ST_OVER, ST_VICTORY:
				_auto_finish(state == ST_VICTORY)
				if not AUTOPLAY:
					return
			_:
				state = ST_PLAY

func _auto_finish(victory: bool) -> void:
	auto_results.append({"victory": victory, "stage": mini(stage, FINAL_STAGE), "time": gametime,
		"kills": kills, "cinders": last_cinders, "cause": last_hurt_src, "bosses": boss_times.duplicate(true)})
	auto_done += 1
	if auto_done >= AUTO_RUNS:
		_auto_report()
		AUTOPLAY = false
		get_tree().quit()
		return
	rng.seed = 1337 + auto_done * 7919
	go_dim.visible = false
	vic_dim.visible = false
	_new_run()
	_auto_apply_grant()

func _auto_report() -> void:
	var wins := 0
	var stg_sum := 0.0
	var stg_hist := {}
	var time_sum := 0.0
	var boss_by_name := {}
	for r in auto_results:
		if bool(r["victory"]):
			wins += 1
		stg_sum += float(r["stage"])
		stg_hist[int(r["stage"])] = int(stg_hist.get(int(r["stage"]), 0)) + 1
		time_sum += float(r["time"])
		for b in r["bosses"]:
			var nm := String(b["name"])
			if not boss_by_name.has(nm):
				boss_by_name[nm] = []
			(boss_by_name[nm] as Array).append(float(b["secs"]))
	var n := maxi(1, auto_results.size())
	print("=== AUTOPLAY REPORT (%d runs) ===" % n)
	print("  wins: %d/%d (%.0f%%)   avg stage: %.2f   avg time: %.0fs" %
		[wins, n, 100.0 * float(wins) / float(n), stg_sum / float(n), time_sum / float(n)])
	var hist_line := ""
	for s in range(1, FINAL_STAGE + 1):
		hist_line += "S%d:%d  " % [s, int(stg_hist.get(s, 0))]
	print("  stage reached: ", hist_line)
	for nm in boss_by_name:
		var arr: Array = boss_by_name[nm]
		var tot := 0.0
		for v in arr:
			tot += float(v)
		print("  boss [%s]: fights=%d avg=%.0fs" % [nm, arr.size(), tot / float(arr.size())])

# ---------- v1.1.3 Hotfix: تثبيت مقاس العرض على الويب ----------
# بعض المتصفحات (خصوصاً جوّه iframe بتاع itch) بتدّي مقاس canvas غير نهائي في أول فريم،
# فالتحجيم بيتحسب غلط واللعبة تبان في مستطيل صغير. الحل: استنّى فريمين واعد تطبيق
# إعدادات الـ content scale بالمقاس النهائي (وطبع مقاسات debug في الكونسول).
func _boot_viewport_fix() -> void:
	var win := get_window()
	print("[viewport] boot: window=", win.size, " visible_rect=", get_viewport().get_visible_rect().size, " state=", state)
	await get_tree().process_frame
	await get_tree().process_frame
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	win.content_scale_size = Vector2i(int(W), int(H))
	_update_rotate_hint()
	queue_redraw()
	print("[viewport] +2 frames: window=", win.size, " visible_rect=", get_viewport().get_visible_rect().size)

# أي تغيير في مقاس النافذة/الآيفريم → حدّث تلميح البورتريه وأعد الرسم فوراً
func _on_window_resized() -> void:
	_update_rotate_hint()
	queue_redraw()

# موبايل بورتريه: اعرض "لفّ جهازك" بدل لعبة مكسورة في شريط صغير
func _update_rotate_hint() -> void:
	if rotate_dim == null:
		return
	var ws := Vector2(get_window().size)
	var portrait := IS_WEB and ws.x > 0.0 and ws.y > ws.x * 1.05
	if portrait:
		rotate_lbl.text = T("Rotate your device for the best experience")
	rotate_dim.visible = portrait

# ---------- settings persistence ----------
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		sfx_vol = clampi(int(cfg.get_value("audio", "sfx_vol", 8)), 0, 10)
		mus_vol = clampi(int(cfg.get_value("audio", "mus_vol", 8)), 0, 10)
		shake_on = bool(cfg.get_value("video", "shake", true))
		dmgnum_on = bool(cfg.get_value("video", "dmgnum", true))
		tips_on = bool(cfg.get_value("video", "tips", true))
		if cfg.has_section("tips"):
			for tk in cfg.get_section_keys("tips"):
				tips_seen[tk] = true
		rec_time = float(cfg.get_value("records", "time", 0.0))
		rec_kills = int(cfg.get_value("records", "kills", 0))
		rec_stage = mini(int(cfg.get_value("records", "stage", 0)), FINAL_STAGE)
		rec_wins = int(cfg.get_value("records", "wins", 0))
		total_runs = maxi(0, int(cfg.get_value("totals", "runs", 0)))
		total_kills = maxi(0, int(cfg.get_value("totals", "kills", 0)))
		total_bosses = maxi(0, int(cfg.get_value("totals", "bosses", 0)))
		total_gems = maxi(0, int(cfg.get_value("totals", "gems", 0)))
		fullscreen_on = bool(cfg.get_value("video", "fullscreen", false))
		char_sel = clampi(int(cfg.get_value("progress", "char", 0)), 0, CHARS.size() - 1)
		LANG = clampi(int(cfg.get_value("lang", "id", 0)), 0, 1)
		lang_chosen = bool(cfg.get_value("lang", "chosen", false))
		cinders = maxi(0, int(cfg.get_value("meta", "cinders", 0)))
		asc_max = clampi(int(cfg.get_value("meta", "asc_max", 0)), 0, ASC_MAX)
		asc = clampi(int(cfg.get_value("meta", "asc", 0)), 0, asc_max)
		for it in Balance.META_SHOP:
			var t := int(cfg.get_value("shop", it["id"], 0))
			if t > 0:
				shop[it["id"]] = mini(t, it["costs"].size())
		for c in CHARS:
			if bool(cfg.get_value("unlocks", c["name"], false)):
				unlocked[c["name"]] = true
		# ترحيل v1.2: الأسماء القديمة (Burner/Runner/Wrecker/Specter) → الجديدة، الفتح محفوظ
		for old_nm in Balance.CHAR_RENAME:
			if bool(cfg.get_value("unlocks", old_nm, false)):
				unlocked[Balance.CHAR_RENAME[old_nm]] = true
		for a in Balance.ACHIEVEMENTS:
			if bool(cfg.get_value("achievements", a["id"], false)):
				achieved[a["id"]] = true
		for syn in Balance.SYNERGIES:
			if bool(cfg.get_value("synergies", syn["id"], false)):
				syn_found[syn["id"]] = true
	# دفع مستوى الصوت لمدير الصوت (سواء اتحمّل من الملف أو الافتراضي)
	Audio.set_sfx_volume(sfx_vol)
	Audio.set_music_volume(mus_vol)

func _save_settings() -> void:
	if AUTOPLAY or SHOTMODE or BENCH:
		return   # أوضاع الاختبار لا تلمس حفظ اللاعب الحقيقي إطلاقاً
	if SHOTMODE:
		return   # ما نلوّثش ملف الحفظ الحقيقي أثناء لقطات الشاشة
	var cfg := ConfigFile.new()
	cfg.set_value("save", "version", 1)   # نسخة الحفظ (لأمان الترقية مستقبلاً)
	cfg.set_value("audio", "sfx_vol", sfx_vol)
	cfg.set_value("audio", "mus_vol", mus_vol)
	cfg.set_value("video", "shake", shake_on)
	cfg.set_value("video", "dmgnum", dmgnum_on)
	cfg.set_value("video", "tips", tips_on)
	for tk in tips_seen:
		cfg.set_value("tips", tk, true)
	cfg.set_value("video", "fullscreen", fullscreen_on)
	cfg.set_value("records", "time", rec_time)
	cfg.set_value("records", "kills", rec_kills)
	cfg.set_value("records", "stage", rec_stage)
	cfg.set_value("records", "wins", rec_wins)
	cfg.set_value("totals", "runs", total_runs)
	cfg.set_value("totals", "kills", total_kills)
	cfg.set_value("totals", "bosses", total_bosses)
	cfg.set_value("totals", "gems", total_gems)
	cfg.set_value("progress", "char", char_sel)
	cfg.set_value("lang", "id", LANG)
	cfg.set_value("lang", "chosen", lang_chosen)
	cfg.set_value("meta", "cinders", cinders)
	cfg.set_value("meta", "asc_max", asc_max)
	cfg.set_value("meta", "asc", asc)
	for k in shop:
		cfg.set_value("shop", k, shop[k])
	for k in unlocked:
		cfg.set_value("unlocks", k, true)
	for k in achieved:
		cfg.set_value("achievements", k, true)
	for k in syn_found:
		cfg.set_value("synergies", k, true)
	cfg.save("user://settings.cfg")

func _update_records(victory: bool) -> void:
	if gametime > rec_time: rec_time = gametime
	if kills > rec_kills: rec_kills = kills
	if stage > rec_stage: rec_stage = mini(stage, FINAL_STAGE)
	if victory: rec_wins += 1
	# إحصائيات تراكمية
	total_runs += 1
	total_kills += kills
	total_bosses += run_bosses
	total_gems += run_gems
	_save_settings()

# جمرات تُكتسب آخر الجولة حسب الأداء (زي عملة الميتا في ألعاب الـ survivors)
func _award_cinders(victory: bool) -> void:
	var st := mini(stage, FINAL_STAGE)
	var secs := int(gametime)
	# v1.1: عائد أعلى شوية — كل جولة (حتى الخاسرة) لازم تحس إنها قرّبتك من الفوز
	var base := int(floor(kills * 0.18 + st * 10.0 + run_bosses * 15.0 + secs * 0.12 + (80.0 if victory else 0.0)))
	# لاحقاً: * (1 + ash_harvest) * ascension_mult (بيتضافوا في خطوات المتجر والـ Ascension)
	base = int(floor(base * (1.0 + meta_cinder_bonus) * asc_cinder))   # Greed + Ascension
	last_cinders = maxi(0, base)
	cinders += last_cinders
	_save_settings()

# يفحص الإنجازات آخر الجولة، يمنح Cinders، ويفتح الشخصيات. بيرجع قائمة الجديد للعرض.
func _check_achievements(victory: bool) -> Array:
	var got := []
	var evolved := evo_bladestorm or evo_ewinter or evo_meteor or evo_tstorm \
		or evo_thalo or evo_shatter or evo_soulp or evo_frostrun
	for a in Balance.ACHIEVEMENTS:
		if achieved.has(a["id"]):
			continue
		var ok := false
		match a["id"]:
			"first": ok = true
			"realm3": ok = stage >= 3
			"bossslayer": ok = run_bosses >= 1
			"centurion": ok = kills >= 300
			"massacre": ok = kills >= 500
			"triple": ok = run_bosses >= 3
			"combo50": ok = combo_best >= 50
			"evolved": ok = evolved
			"void5": ok = stage >= 5
			"win": ok = victory
			"speed": ok = victory and gametime < 360.0
			"hoarder": ok = run_gems >= 2000
		if ok:
			achieved[a["id"]] = true
			cinders += int(a.get("reward", 0))
			if a.has("unlock"):
				_unlock_char(a["unlock"])
			got.append(a)
	if not got.is_empty():
		_save_settings()
	return got

# مستوى ترقية مملوكة في المتجر
func _tier(id: String) -> int:
	return int(shop.get(id, 0))

# هل الشخصية مفتوحة؟ (تكلفة 0 = مفتوحة دايماً زي الجندي)
func _char_unlocked(i: int) -> bool:
	var c = CHARS[i]
	return int(c.get("cost", 0)) == 0 or unlocked.has(c["name"])

# فتح شخصية مجاناً (تستدعيها الإنجازات في Phase 1d)
func _unlock_char(nm: String) -> void:
	if not unlocked.has(nm):
		unlocked[nm] = true
		_save_settings()

# محاولة فتح الشخصية المختارة بالـ Cinders
func _try_unlock(i: int) -> bool:
	if _char_unlocked(i):
		return true
	var c = CHARS[i]
	var cost := int(c.get("cost", 0))
	if cinders >= cost:
		cinders -= cost
		unlocked[c["name"]] = true
		_save_settings()
		Audio.play_sfx("levelup", -2.0, 1.0, 1.0)
		return true
	Audio.play_sfx("hurt", -6.0, 1.0, 1.0)   # مش كفاية Cinders
	return false

# يطبّق ترقيات المتجر الدائمة أول كل جولة — بعد الستاتس الأساسية وقبل مميزات الناجي
func _apply_meta() -> void:
	meta_xp_mul = 1.0 + 0.06 * _tier("growth")
	xp_bank = 0.0
	meta_cinder_bonus = 0.08 * _tier("greed")
	revive_ready = _tier("revival") > 0
	maxhp += 10.0 * _tier("vitality")
	bullet_dmg += 2.0 * _tier("might")
	fire_rate *= pow(0.96, _tier("cooldown"))
	pspeed += 8.0 * _tier("swift")
	magnet += 20.0 * _tier("magnet")
	dash_cd_max *= pow(0.94, _tier("dash"))
	armor_n += _tier("armor")
	if _tier("recovery") > 0:
		regen_n = maxi(regen_n, 1)
	_apply_ascension()

# مُعدِّلات الـ Ascension تراكمية لكل مستوى (Danger 1..5)
# v1.1: كل مستوى بيغيّر قاعدة مش رقم بس — رماة/فخاخ/سقوف علاج/إيقاع زعماء
func _apply_ascension() -> void:
	asc_hp = 1.0; asc_spd = 1.0; asc_dmg = 1.0; asc_spawn = 1.0
	asc_cinder = 1.0; asc_enrage = 0.5; asc_elite = 0.0
	asc_healcap = 1.0; asc_boss_atk = 1.0; asc_trap = 1.0; asc_heal_boss = 0.5
	if asc >= 1: asc_hp *= 1.12; asc_spd *= 1.05; asc_cinder = 1.15
	if asc >= 2: asc_spawn = 0.88; asc_heal_boss = 0.35; asc_cinder = 1.30   # spawn أسرع + رماة أكتر (في المزيج)
	if asc >= 3: asc_dmg *= 1.20; asc_elite += 0.08; asc_healcap = 0.8; asc_cinder = 1.50
	if asc >= 4: asc_enrage = 0.65; asc_trap = 0.8; asc_cinder = 1.75        # غضب أبكر + فخاخ أسرع + قنابل أكتر
	if asc >= 5: asc_elite += 0.05; asc_healcap = 0.65; asc_boss_atk = 1.15; asc_cinder = 2.0; maxhp *= 0.85

func _apply_fullscreen() -> void:
	if fullscreen_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

# ---------- audio ----------
# كل منطق الصوت اتنقل لـ autoload اسمه Audio (res://autoload/audio_manager.gd).
# الاستدعاءات هنا بقت Audio.play_sfx / Audio.play_music / Audio.stop_music.

# ================================================================
#  UI BUILDERS
func _hud_panel(x: float, y: float, w: float, h: float) -> void:
	# لوحة موحّدة خلف عناصر الـ HUD (إطار steel خفيف + خلفية غامقة)
	hud_panels.append(_mk_rect(Vector2(x - 2, y - 2), Vector2(w + 4, h + 4), Color(Balance.COL_STEEL.r, Balance.COL_STEEL.g, Balance.COL_STEEL.b, 0.35)))
	hud_panels.append(_mk_rect(Vector2(x, y), Vector2(w, h), Color(0.04, 0.05, 0.08, 0.55)))

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	# panels موحّدة خلف الكتل (قبل اللابلز عشان تبقى وراهم)
	_hud_panel(12, 8, 262, 98)
	_hud_panel(W * 0.5 - 178, 6, 356, 94)
	var font_col := Balance.COL_TEXT
	lbl_kills = _mk_label(Vector2(24, 18), 30, font_col)
	lbl_level = _mk_label(Vector2(W * 0.5 - 160, 14), 30, font_col)
	lbl_level.size = Vector2(320, 40)
	lbl_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_time = _mk_label(Vector2(W - 250, 18), 30, font_col)
	lbl_time.size = Vector2(184, 40)
	lbl_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_stage = _mk_label(Vector2(W - 340, 60), 22, Color(0.95, 0.9, 0.7))
	lbl_stage.size = Vector2(316, 30)
	lbl_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_back = _mk_rect(Vector2(24, 62), Vector2(240, 22), Color(0, 0, 0, 0.55))
	hp_fill = _mk_rect(Vector2(27, 65), Vector2(234, 16), Color(0.30, 0.85, 0.30))
	# رقم الصحة داخل الشريط — 82 / 100 (يومض أحمر عند الضرر وأخضر عند العلاج)
	lbl_hp = _mk_label(Vector2(24, 61), 15, Balance.COL_TEXT)
	lbl_hp.size = Vector2(240, 22)
	lbl_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_hp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_hp.add_theme_constant_override("outline_size", 5)
	dash_back = _mk_rect(Vector2(24, 90), Vector2(120, 10), Color(0, 0, 0, 0.55))
	dash_fill = _mk_rect(Vector2(26, 92), Vector2(116, 6), Color(0.35, 0.75, 1.0))
	# v1.2: مؤشر جاهزية القدرة Q جنب شريط الداش
	lbl_q = _mk_label(Vector2(152, 84), 16, Color(0.6, 0.95, 0.7))
	lbl_q.size = Vector2(150, 22)
	# v1.2.3: مؤشر الأولتيمت R (الشينوبي فقط)
	lbl_r = _mk_label(Vector2(152, 104), 16, Color(0.75, 0.85, 1.0))
	lbl_r.size = Vector2(180, 22)
	lbl_r.visible = false
	# v1.2.5: مؤشر حالة مؤقتة (بافات المقامر) تحت مؤشر R
	lbl_status = _mk_label(Vector2(152, 124), 15, Color(0.6, 1.0, 0.6))
	lbl_status.size = Vector2(200, 20)
	lbl_status.visible = false
	lbl_combo = _mk_label(Vector2(24, 150), 26, Color(1, 0.85, 0.35))
	lbl_combo.visible = false
	# مؤشر WOUNDED جنب شريط الصحة — عشان اللاعب ما يفتكرش إن العلاج باظ
	lbl_wound = _mk_label(Vector2(270, 62), 18, Color(1.0, 0.55, 0.15))
	lbl_wound.size = Vector2(260, 24)
	lbl_wound.visible = false
	# توست الرسائل الثانوية — صغير وثابت أسفل الشاشة (بدل زحمة النص الكبير)
	lbl_toast = _mk_label(Vector2(W * 0.5 - 360, H - 64), 19, Color(0.95, 0.88, 0.65))
	lbl_toast.size = Vector2(720, 28)
	lbl_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_toast.visible = false
	xp_back = _mk_rect(Vector2(W * 0.5 - 130, 54), Vector2(260, 14), Color(0, 0, 0, 0.55))
	xp_fill = _mk_rect(Vector2(W * 0.5 - 127, 57), Vector2(0, 8), Color(0.45, 0.70, 1.0))
	lbl_boss = _mk_label(Vector2(W * 0.5 - 160, 72), 20, Color(1, 0.75, 0.4))
	lbl_boss.size = Vector2(320, 28)
	lbl_boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg = _mk_label(Vector2(W * 0.5 - 300, 130), 44, Color(1, 0.9, 0.5))
	lbl_msg.size = Vector2(600, 80)
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.visible = false
	# زر الإيقاف داخل اللعب (أعلى-يمين) — أيقونة || مرسومة من مستطيلات (بدون رموز خط)
	var _pbord := _mk_rect(PAUSE_BTN_RECT.position - Vector2(2, 2), PAUSE_BTN_RECT.size + Vector2(4, 4), Color(0.02, 0.03, 0.05, 0.85))
	var pbg := _mk_rect(PAUSE_BTN_RECT.position, PAUSE_BTN_RECT.size, Color(0.13, 0.17, 0.26, 0.85))
	var bx := PAUSE_BTN_RECT.position.x
	var by := PAUSE_BTN_RECT.position.y
	var bar1 := _mk_rect(Vector2(bx + 12, by + 10), Vector2(5, 20), Color(0.85, 0.90, 1.0))
	var bar2 := _mk_rect(Vector2(bx + 23, by + 10), Vector2(5, 20), Color(0.85, 0.90, 1.0))
	pause_hud_btn = {"border": _pbord, "bg": pbg, "bar1": bar1, "bar2": bar2, "rect": PAUSE_BTN_RECT}

func _mk_label(pos: Vector2, sz: int, col: Color, parent: Node = null) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE   # متبلعش نقرات الماوس (تعدّي للّعبة)
	l.position = pos
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 6)
	if parent == null:
		hud.add_child(l)
	else:
		parent.add_child(l)
	return l

# زر بكسل-آرت قابل للنقر (حدود + وجه + إبراز علوي + نص) — للأزرار فوق الطبقات المعتّمة
func _mk_button(parent: Node, rect: Rect2, txt: String, fsize: int = 22) -> Dictionary:
	_mk_rect(Vector2(rect.position.x - 3, rect.position.y - 3), Vector2(rect.size.x + 6, rect.size.y + 6), Color(0.02, 0.03, 0.05, 0.92), parent)
	var face := _mk_rect(rect.position, rect.size, Color(0.13, 0.17, 0.26, 0.98), parent)
	_mk_rect(rect.position, Vector2(rect.size.x, 3), Color(1, 1, 1, 0.10), parent)
	var lbl := _mk_label(rect.position, fsize, Color(0.90, 0.93, 0.99), parent)
	lbl.size = rect.size
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.text = txt
	return {"face": face, "label": lbl, "rect": rect}

func _btn_hover(btn: Dictionary, hovered: bool) -> void:
	btn["face"].color = Color(0.22, 0.30, 0.46, 0.98) if hovered else Color(0.13, 0.17, 0.26, 0.98)
	btn["label"].add_theme_color_override("font_color", Color(1.0, 0.92, 0.6) if hovered else Color(0.90, 0.93, 0.99))

func _mk_rect(pos: Vector2, sz: Vector2, col: Color, parent: Node = null) -> ColorRect:
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE   # متبلعش نقرات الماوس (تعدّي للّعبة)
	r.position = pos
	r.size = sz
	r.color = col
	if parent == null:
		hud.add_child(r)
	else:
		parent.add_child(r)
	return r

func _build_levelup_ui() -> void:
	lv_dim = _mk_rect(Vector2.ZERO, Vector2(W, H), Color(0, 0, 0, 0.62))
	lv_title = _mk_label(Vector2(W * 0.5 - 300, 120), 46, Color(1, 0.9, 0.5), lv_dim)
	lv_title.size = Vector2(600, 70)
	lv_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cw := 300.0
	var ch := 200.0
	var gap := 40.0
	var x0 := W * 0.5 - (cw * 3 + gap * 2) * 0.5
	# 4 كروت مبنية — الرابع يظهر فقط في أول ارتقاء للجندي (هوية المبتدئين)
	for i in 4:
		# إطار ندرة ملوّن خلف الكارت
		var frame := _mk_rect(Vector2(x0 + (cw + gap) * i - 3, 247), Vector2(cw + 6, ch + 6), Color(0.5, 0.5, 0.5), lv_dim)
		var panel := _mk_rect(Vector2(3, 3), Vector2(cw, ch), Color(0.09, 0.10, 0.15, 0.98), frame)
		var key := _mk_label(Vector2(16, 10), 32, Balance.COL_YOU, panel)
		key.text = "[%d]" % (i + 1)
		var rar := _mk_label(Vector2(cw - 132, 16), 18, Color(0.7, 0.7, 0.7), panel)
		rar.size = Vector2(116, 24); rar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		# أيقونة البركة (أعلى المنتصف) — رمز بصري سريع بلون الندرة
		var ico := TextureRect.new()
		ico.position = Vector2(cw * 0.5 - 20, 6)
		ico.size = Vector2(40, 40)
		ico.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ico.stretch_mode = TextureRect.STRETCH_SCALE
		ico.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(ico)
		var nm := _mk_label(Vector2(16, 56), 29, Color(1, 1, 1), panel)
		nm.size = Vector2(cw - 32, 40)
		# سطر الأوسمة (Tags) — صغير وخافت تحت الاسم
		var tg := _mk_label(Vector2(16, 92), 14, Balance.COL_TEXT_DIM, panel)
		tg.size = Vector2(cw - 32, 20)
		var ds := _mk_label(Vector2(16, 114), 20, Balance.COL_TEXT, panel)
		ds.size = Vector2(cw - 32, 52)
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		# سطر الـ Drawback — برتقالي واضح (الثمن جزء من القرار)
		var dr := _mk_label(Vector2(16, 164), 16, Balance.COL_ENEMY_HI, panel)
		dr.size = Vector2(cw - 32, 34)
		dr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lv_cards.append({"frame": frame, "panel": panel, "name": nm, "tags": tg, "desc": ds, "draw": dr, "rar": rar, "icon": ico})
	lv_hint = _mk_label(Vector2(W * 0.5 - 400, 470), 24, Balance.COL_TEXT_DIM, lv_dim)
	lv_hint.size = Vector2(800, 34); lv_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# v1.2: عرض الخانات — أسلحة 2/3 · باسيف 3/4 (فوق الكروت)
	lv_slots = _mk_label(Vector2(W * 0.5 - 300, 196), 19, Color(0.75, 0.85, 0.95), lv_dim)
	lv_slots.size = Vector2(600, 26); lv_slots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_dim.visible = false

# توزيع كروت الارتقاء أفقياً حسب عددها (3 عادي · 4 لأول ارتقاء الجندي)
func _lv_card_x0(n: int) -> float:
	var gap := 40.0 if n <= 3 else 16.0
	return W * 0.5 - (300.0 * n + gap * (n - 1)) * 0.5

func _layout_lv_cards(n: int) -> void:
	var gap := 40.0 if n <= 3 else 16.0
	var x0 := _lv_card_x0(n)
	for i in lv_cards.size():
		var card = lv_cards[i]
		card["frame"].visible = i < n
		card["frame"].position = Vector2(x0 + (300.0 + gap) * i - 3, 247)

func _build_gameover_ui() -> void:
	go_dim = _mk_rect(Vector2.ZERO, Vector2(W, H), Color(0.0, 0.0, 0.0, 0.94))
	go_title = _mk_label(Vector2(W * 0.5 - 300, 120), 60, Color(0.95, 0.25, 0.25), go_dim)
	go_title.size = Vector2(600, 80)
	go_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_title.text = T("YOU DIED")
	go_stats = _mk_label(Vector2(W * 0.5 - 400, 210), 24, Color(0.9, 0.9, 0.9), go_dim)
	go_stats.size = Vector2(800, 440)
	go_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_btns["restart"] = _mk_button(go_dim, Rect2(W * 0.5 - 224, 662, 210, 48), T("Restart Run"))
	go_btns["menu"] = _mk_button(go_dim, Rect2(W * 0.5 + 14, 662, 210, 48), T("Main Menu"))
	go_dim.visible = false

# هندسة أزرار القائمة الرئيسية (عمود متمركز)
func _menu_btn_rect(i: int) -> Rect2:
	return Rect2(W * 0.5 - 175.0, 312.0 + i * 58.0, 350.0, 48.0)

func _build_menu_ui() -> void:
	menu_dim = _mk_rect(Vector2.ZERO, Vector2(W, H), Color(0, 0, 0, 0.25))
	menu_title = _mk_label(Vector2(W * 0.5 - 400, 118), 76, Color(0.45, 0.75, 1.0), menu_dim)
	menu_title.size = Vector2(800, 100)
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_sub = _mk_label(Vector2(W * 0.5 - 400, 214), 22, Color(0.75, 0.80, 0.90), menu_dim)
	menu_sub.size = Vector2(800, 34)
	menu_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# أزرار القائمة (النصّ Label فوق إطار بكسل يُرسم في _draw)
	for i in MENU_BTNS.size():
		var r := _menu_btn_rect(i)
		var o := _mk_label(Vector2(r.position.x, r.position.y), 26, Color(1, 1, 1), menu_dim)
		o.size = r.size
		o.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		o.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		menu_labels.append(o)
	menu_rec = _mk_label(Vector2(W * 0.5 - 450, 262), 20, Color(0.80, 0.72, 0.45), menu_dim)
	menu_rec.size = Vector2(900, 30)
	menu_rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_hint = _mk_label(Vector2(W * 0.5 - 400, H - 40), 19, Balance.COL_TEXT_DIM, menu_dim)
	menu_hint.size = Vector2(800, 28)
	menu_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# رقم الإصدار (ركن) + كريدت
	var ver := _mk_label(Vector2(W - 190, H - 30), 16, Balance.COL_TEXT_DIM, menu_dim)
	ver.size = Vector2(180, 22); ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ver.text = GAME_VERSION
	var cred := _mk_label(Vector2(10, H - 30), 16, Balance.COL_TEXT_DIM, menu_dim)
	cred.size = Vector2(300, 22)
	cred.text = "Arcane Cubes"
	menu_dim.visible = false

func _refresh_menu() -> void:
	menu_title.text = T("CUBE SURVIVOR")
	menu_sub.text = T("Survive the corrupted arena")
	for i in MENU_BTNS.size():
		var sel := i == menu_sel
		menu_labels[i].text = T(MENU_BTNS[i]["label"])
		menu_labels[i].add_theme_color_override("font_color", Color(1.0, 0.92, 0.6) if sel else Color(0.88, 0.90, 0.96))
	var m := int(rec_time) / 60
	var s := int(rec_time) % 60
	var wins_txt := T("  •  Wins: %d") % rec_wins if rec_wins > 0 else ""
	menu_rec.text = T("Cinders: %d      Best: Stage %d  %02d:%02d%s") % [cinders, rec_stage, m, s, wins_txt]
	menu_hint.text = T("Click, or W/S + Enter to select")

func _menu_activate() -> void:
	Audio.play_sfx("click")
	match MENU_BTNS[menu_sel]["id"]:
		"start":
			df_sel = clampi(asc, 0, asc_max)
			menu_dim.visible = false; cs_dim.visible = true
			_refresh_charsel(); state = ST_CHARSEL
		"upgrades":
			_show_shop()
		"records":
			_show_stats()
		"settings":
			set_return = ST_MENU
			set_sel = 0; _refresh_settings_ui()
			menu_dim.visible = false; set_dim.visible = true; state = ST_SETTINGS
		"credits":
			menu_dim.visible = false; cr_dim.visible = true; state = ST_CREDITS
		"quit":
			get_tree().quit()

# ================================================================
#  شاشة اختيار الناجي (Character Select)
func _build_charsel_ui() -> void:
	cs_dim = _mk_rect(Vector2.ZERO, Vector2(W, H), Color(0, 0, 0, 0.30))
	cs_title = _mk_label(Vector2(W * 0.5 - 400, 40), 46, Color(0.55, 0.80, 1.0), cs_dim)
	cs_title.size = Vector2(800, 62); cs_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# لوحة المعلومات على اليمين (النصوص فوق لوح يُرسم في _draw عند x≈688..1208)
	cs_name = _mk_label(Vector2(710, 150), 40, Color(1, 1, 1), cs_dim)
	cs_name.size = Vector2(470, 52)
	cs_role = _mk_label(Vector2(710, 202), 22, Color(1.0, 0.82, 0.40), cs_dim)
	cs_role.size = Vector2(470, 30)
	# سطر الفانتازيا: سطر واحد فقط بقصّ تلقائي (…) — ممنوع النزول تحت
	cs_desc = _mk_label(Vector2(710, 236), 18, Balance.COL_TEXT, cs_dim)
	cs_desc.size = Vector2(480, 28)
	cs_desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# أسماء الإحصائيات الخمسة (مضغوطة — النقاط تُرسم بجانبها في _draw)
	for i in CS_STAT_NAMES.size():
		var sl := _mk_label(Vector2(710, 274 + i * 30), 18, Color(0.85, 0.88, 0.95), cs_dim)
		sl.size = Vector2(150, 26)
		cs_stat_labels.append(sl)
	# بلوك معلومات: 7 سطور مستقلة بمواضع ثابتة (السطر السابع للأولتيمت R لو موجود)
	for i in 7:
		var il := _mk_label(Vector2(710, 428 + i * 28), 16, Color(0.70, 0.90, 1.0), cs_dim)
		il.size = Vector2(485, 26)
		il.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		cs_info.append(il)
	cs_hint = _mk_label(Vector2(W * 0.5 - 450, H - 40), 19, Balance.COL_TEXT_DIM, cs_dim)
	cs_hint.size = Vector2(900, 28); cs_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_btns[ST_CHARSEL] = _mk_button(cs_dim, BACK_RECT, "< Back")
	cs_dim.visible = false

func _refresh_charsel() -> void:
	cs_title.text = T("SELECT SURVIVOR")
	var ch = CHARS[char_sel]
	cs_name.text = T(ch["name"])
	cs_role.text = T(ch.get("role", ""))
	var unlocked_c := _char_unlocked(char_sel)
	# Improvement Pass: بطاقة منظمة — 6 سطور مستقلة قصيرة، كل سطر معلومة واحدة
	var lines := [
		T("Weapon") + ": " + T(ch.get("signame", "")),
		"Q: " + T(ch.get("qname", "")) + " (%ds)" % int(ch.get("qcd", 14.0)),
		T("Playstyle") + ": " + T(ch.get("playstyle", "")),
		T("Difficulty") + ": " + T(ch.get("difficulty", "")),
		T("Strength") + ": " + T(ch.get("strength", "")),
		T("Weakness") + ": " + T(ch.get("weak", "")),
	]
	# v1.2.3: سطر الأولتيمت R للشخصيات اللي عندها rname (الشينوبي)
	if ch.has("rname"):
		lines.insert(2, "R: " + T(String(ch.get("rname", ""))) + " (Lv%d, %ds)" % [int(ch.get("runlock", 7)), int(ch.get("rcd", 60))])
	for i in cs_info.size():
		cs_info[i].text = String(lines[i]) if i < lines.size() else ""
	if unlocked_c:
		cs_desc.text = T(ch["desc"])
		cs_hint.text = T("A/D or Arrows to choose   •   Enter or Click to confirm")
	else:
		cs_desc.text = T("LOCKED") + " — " + T(ch["hint"])
		cs_hint.text = T("Confirm to unlock (%d Cinders) — you have %d") % [int(ch.get("cost", 0)), cinders]
	# لون العنوان يعكس لون الشخصية للتمييز
	cs_name.add_theme_color_override("font_color", Color(1, 1, 1) if unlocked_c else Color(0.6, 0.6, 0.65))
	for i in cs_stat_labels.size():
		cs_stat_labels[i].text = T(CS_STAT_NAMES[i])

func _charsel_confirm() -> void:
	if _char_unlocked(char_sel):
		Audio.play_sfx("click")
		df_sel = clampi(asc, 0, asc_max)
		cs_dim.visible = false; df_dim.visible = true
		_refresh_diff(); state = ST_DIFF
	else:
		if _try_unlock(char_sel):
			_refresh_charsel()

# ================================================================
#  شاشة اختيار الصعوبة (Difficulty Select)
func _diff_row_rect(i: int) -> Rect2:
	return Rect2(70.0, 148.0 + i * 70.0, 470.0, 60.0)

func _build_diff_ui() -> void:
	df_dim = _mk_rect(Vector2.ZERO, Vector2(W, H), Color(0, 0, 0, 0.30))
	df_title = _mk_label(Vector2(W * 0.5 - 400, 40), 46, Color(1.0, 0.55, 0.35), df_dim)
	df_title.size = Vector2(800, 62); df_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# صفوف المستويات (اسم كل مستوى فوق إطاره)
	for i in Balance.DIFF_TIERS.size():
		var r := _diff_row_rect(i)
		var rl := _mk_label(Vector2(r.position.x + 24, r.position.y), 26, Color(1, 1, 1), df_dim)
		rl.size = Vector2(r.size.x - 40, r.size.y); rl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		df_row_labels.append(rl)
	# لوحة تفاصيل المستوى المختار (يمين)
	df_name = _mk_label(Vector2(600, 168), 38, Color(1, 1, 1), df_dim)
	df_name.size = Vector2(430, 50)
	df_desc = _mk_label(Vector2(600, 228), 21, Balance.COL_TEXT, df_dim)
	df_desc.size = Vector2(560, 70); df_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# أسطر الـ modifiers (حتى 4 — مستويات الخطر بقت قواعد أكتر في v1.1)
	for i in 4:
		var ml := _mk_label(Vector2(624, 330 + i * 38), 21, Color(0.90, 0.92, 0.98), df_dim)
		ml.size = Vector2(540, 30)
		df_mod_labels.append(ml)
	df_char_lbl = _mk_label(Vector2(600, 560), 20, Color(0.70, 0.85, 1.0), df_dim)
	df_char_lbl.size = Vector2(600, 28)
	df_hint = _mk_label(Vector2(W * 0.5 - 450, H - 40), 19, Balance.COL_TEXT_DIM, df_dim)
	df_hint.size = Vector2(900, 28); df_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_btns[ST_DIFF] = _mk_button(df_dim, BACK_RECT, "< Back")
	df_dim.visible = false

func _refresh_diff() -> void:
	df_title.text = T("SELECT DIFFICULTY")
	for i in Balance.DIFF_TIERS.size():
		var locked_i := i > asc_max
		var sel_i := i == df_sel
		var nm := T(Balance.DIFF_TIERS[i]["name"])
		if locked_i:
			nm += "   (" + T("LOCKED") + ")"
		df_row_labels[i].text = nm
		var col := Color(0.45, 0.48, 0.55) if locked_i else (Color(1.0, 0.92, 0.6) if sel_i else Color(0.90, 0.92, 0.98))
		df_row_labels[i].add_theme_color_override("font_color", col)
	var t = Balance.DIFF_TIERS[df_sel]
	var locked := df_sel > asc_max
	df_name.text = T(t["name"])
	df_name.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65) if locked else Color(1, 1, 1))
	var mods: Array = t["mods"]
	if locked:
		df_desc.text = T("Win at the previous Danger level to unlock.")
		for i in df_mod_labels.size():
			df_mod_labels[i].text = ""
		df_hint.text = T("W/S select   •   Backspace: Change Survivor")
	else:
		df_desc.text = T(t["desc"])
		for i in df_mod_labels.size():
			df_mod_labels[i].text = ("•  " + T(mods[i])) if i < mods.size() else ""
		df_hint.text = T("W/S select   •   Enter start run   •   Backspace: Change Survivor")
	df_char_lbl.text = T("Survivor: %s") % T(CHARS[char_sel]["name"])

func _diff_confirm() -> void:
	if df_sel > asc_max:
		Audio.play_sfx("hurt", -6.0)   # مقفول
		return
	asc = df_sel
	Audio.play_sfx("click")
	_save_settings()
	_new_run()

# ================================================================
#  شاشة الكريدت (Credits)
func _build_credits_ui() -> void:
	cr_dim = _mk_rect(Vector2.ZERO, Vector2(W, H), Color(0.03, 0.03, 0.06, 0.92))
	cr_title = _mk_label(Vector2(W * 0.5 - 400, 120), 48, Color(0.55, 0.80, 1.0), cr_dim)
	cr_title.size = Vector2(800, 64); cr_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cr_body = _mk_label(Vector2(W * 0.5 - 400, 230), 24, Color(0.90, 0.92, 0.98), cr_dim)
	cr_body.size = Vector2(800, 320); cr_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cr_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	cr_hint = _mk_label(Vector2(W * 0.5 - 400, H - 60), 20, Balance.COL_TEXT_DIM, cr_dim)
	cr_hint.size = Vector2(800, 28); cr_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_btns[ST_CREDITS] = _mk_button(cr_dim, BACK_RECT, "< Back")
	_refresh_credits()
	cr_dim.visible = false

func _refresh_credits() -> void:
	cr_title.text = T("CREDITS")
	cr_body.text = "CUBE SURVIVOR\n" + GAME_VERSION + "\n\n" + \
		T("Design, code & art") + "\nArcane Cubes\n\n" + \
		T("Made with Godot Engine") + "\n\n" + \
		T("Thank you for playing!")
	cr_hint.text = T("Click Back, or press Enter")

func _build_victory_ui() -> void:
	vic_dim = _mk_rect(Vector2.ZERO, Vector2(W, H), Color(0.0, 0.0, 0.0, 0.94))
	vic_title = _mk_label(Vector2(W * 0.5 - 400, 110), 56, Color(1.0, 0.85, 0.30), vic_dim)
	vic_title.size = Vector2(800, 80)
	vic_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vic_stats = _mk_label(Vector2(W * 0.5 - 420, 172), 20, Color(0.92, 0.92, 0.92), vic_dim)
	vic_stats.size = Vector2(840, 470)
	vic_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vic_btn = _mk_button(vic_dim, Rect2(W * 0.5 - 110, 660, 220, 48), T("Main Menu"))
	vic_dim.visible = false

func _build_settings_ui() -> void:
	set_dim = _mk_rect(Vector2.ZERO, Vector2(W, H), Color(0, 0, 0, 0.72))
	set_title = _mk_label(Vector2(W * 0.5 - 300, 90), 52, Color(1, 0.9, 0.5), set_dim)
	set_title.size = Vector2(600, 80)
	set_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# صفوف: مؤثرات / موسيقى / اهتزاز / أرقام الضرر / ملء الشاشة / اللغة
	for i in SET_ROWS:
		var r := _mk_label(Vector2(W * 0.5 - 300, SET_TOP + i * SET_STEP), 30, Balance.COL_TEXT, set_dim)
		r.size = Vector2(600, 44)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		set_rows.append(r)
	# شريطا مستوى الصوت تحت أول صفّين
	for i in 2:
		var back := _mk_rect(Vector2(W * 0.5 - 160, SET_TOP + i * SET_STEP + 50), Vector2(320, 18), Color(0.15, 0.15, 0.20, 0.9), set_dim)
		var fill := _mk_rect(Vector2(W * 0.5 - 157, SET_TOP + i * SET_STEP + 53), Vector2(0, 12), Color(0.45, 0.70, 1.0), set_dim)
		set_bars.append({"back": back, "fill": fill})
	set_hint = _mk_label(Vector2(W * 0.5 - 400, 620), 24, Color(0.72, 0.72, 0.78), set_dim)
	set_hint.size = Vector2(800, 40)
	set_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_btns[ST_SETTINGS] = _mk_button(set_dim, BACK_RECT, "< Back")
	set_dim.visible = false

func _refresh_settings_ui() -> void:
	set_title.text = T("SETTINGS")
	set_hint.text = T("W/S select row    •    A/D adjust    •    Backspace back")
	var names := ["Sound Effects", "Music", "Screen Shake", "Damage Numbers", "Tutorial Tips", "Fullscreen", "Language"]
	var vals := ["%d / 10" % sfx_vol, "%d / 10" % mus_vol,
		T("ON") if shake_on else T("OFF"), T("ON") if dmgnum_on else T("OFF"),
		T("ON") if tips_on else T("OFF"),
		T("ON") if fullscreen_on else T("OFF"),
		"العربية" if LANG == 1 else "English"]
	for i in SET_ROWS:
		var sel := i == set_sel
		set_rows[i].text = ("‹  %s : %s  ›" if sel else "%s : %s") % [T(names[i]), vals[i]]
		set_rows[i].add_theme_color_override("font_color", Color(1, 0.85, 0.35) if sel else Color(1, 1, 1))
	set_bars[0]["fill"].size.x = 314.0 * float(sfx_vol) / 10.0
	set_bars[1]["fill"].size.x = 314.0 * float(mus_vol) / 10.0
	set_bars[0]["fill"].color = Color(1, 0.85, 0.35) if set_sel == 0 else Color(0.45, 0.70, 1.0)
	set_bars[1]["fill"].color = Color(1, 0.85, 0.35) if set_sel == 1 else Color(0.45, 0.70, 1.0)

# تحويل موضع الماوس الأفقي لقيمة صوت 0..10 (على شريط السلايدر 320px)
func _slider_from_mouse(mx: float) -> int:
	return clampi(int(round((mx - (W * 0.5 - 160.0)) / 320.0 * 10.0)), 0, 10)

# ضبط مستوى صوت صف معيّن مباشرة (النقر/السحب بالماوس) — الكيبورد لسه بيستخدم _adjust_setting
func _set_volume_row(row: int, v: int) -> void:
	if row == 0:
		if v != sfx_vol:
			sfx_vol = v
			Audio.set_sfx_volume(sfx_vol)
			Audio.play_sfx("click")   # يسمع المستوى الجديد فوراً
			_save_settings()
			_refresh_settings_ui()
	elif row == 1:
		if v != mus_vol:
			mus_vol = v
			Audio.set_music_volume(mus_vol)
			_save_settings()
			_refresh_settings_ui()

func _adjust_setting(d: int) -> void:
	match set_sel:
		0:
			sfx_vol = clampi(sfx_vol + d, 0, 10)
			Audio.set_sfx_volume(sfx_vol)
			Audio.play_sfx("click")   # يسمع المستوى الجديد فوراً
		1:
			mus_vol = clampi(mus_vol + d, 0, 10)
			Audio.set_music_volume(mus_vol)
		2:
			shake_on = not shake_on
			Audio.play_sfx("click")
		3:
			dmgnum_on = not dmgnum_on
			Audio.play_sfx("click")
		4:
			tips_on = not tips_on
			Audio.play_sfx("click")
		5:
			fullscreen_on = not fullscreen_on
			_apply_fullscreen()
			Audio.play_sfx("click")
		6:
			LANG = 1 - LANG          # تبديل عربي/إنجليزي
			lang_chosen = true
			_apply_lang()            # يعيد ترجمة القوائم والإعدادات فوراً
			Audio.play_sfx("click")
	_save_settings()
	_refresh_settings_ui()

func _apply_lang() -> void:
	# يعيد ترجمة كل الشاشات الثابتة بعد تغيير اللغة
	if menu_title:
		_refresh_menu()
	if set_title:
		_refresh_settings_ui()
	if pause_title:
		_refresh_pause_ui()
	if cs_title:
		_refresh_charsel()
	if df_title:
		_refresh_diff()
	if cr_title:
		_refresh_credits()

# هندسة أزرار قائمة الإيقاف (عمود متمركز)
func _pause_btn_rect(i: int) -> Rect2:
	return Rect2(W * 0.5 - 165.0, 292.0 + i * 62.0, 330.0, 50.0)

# زرّا تأكيد Yes/No (0=Yes, 1=No)
func _pc_rect(i: int) -> Rect2:
	return Rect2(W * 0.5 - 172.0 + i * 180.0, 398.0, 164.0, 54.0)

func _build_pause_ui() -> void:
	# alpha=0: مجرد حاوية للنصوص؛ التعتيم واللوح يُرسمان في _draw فوق العالم المتجمّد
	pause_dim = _mk_rect(Vector2.ZERO, Vector2(W, H), Color(0, 0, 0, 0.0))
	pause_title = _mk_label(Vector2(W * 0.5 - 300, 200), 56, Color(1, 1, 1), pause_dim)
	pause_title.size = Vector2(600, 80)
	pause_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in PAUSE_BTNS.size():
		var r := _pause_btn_rect(i)
		var o := _mk_label(Vector2(r.position.x, r.position.y), 26, Color(1, 1, 1), pause_dim)
		o.size = r.size
		o.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		o.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		pause_labels.append(o)
	pause_opts = _mk_label(Vector2(W * 0.5 - 400, 292.0 + PAUSE_BTNS.size() * 62.0 + 14.0), 18, Balance.COL_TEXT_DIM, pause_dim)
	pause_opts.size = Vector2(800, 26)
	pause_opts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_hint = _mk_label(Vector2(W * 0.5 - 400, H - 44), 19, Balance.COL_TEXT_DIM, pause_dim)
	pause_hint.size = Vector2(800, 26)
	pause_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# نصوص التأكيد (Yes/No)
	pc_prompt = _mk_label(Vector2(W * 0.5 - 320, 306), 30, Color(1.0, 0.85, 0.5), pause_dim)
	pc_prompt.size = Vector2(640, 44); pc_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pc_yes = _mk_label(_pc_rect(0).position, 26, Color(1, 1, 1), pause_dim)
	pc_yes.size = _pc_rect(0).size; pc_yes.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; pc_yes.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pc_no = _mk_label(_pc_rect(1).position, 26, Color(1, 1, 1), pause_dim)
	pc_no.size = _pc_rect(1).size; pc_no.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; pc_no.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_refresh_pause_ui()
	pause_dim.visible = false

func _refresh_pause_ui() -> void:
	pause_title.text = T("PAUSED")
	var confirming := pause_confirm != ""
	for i in PAUSE_BTNS.size():
		pause_labels[i].visible = not confirming
		var sel := i == pause_sel
		pause_labels[i].text = T(PAUSE_BTNS[i]["label"])
		pause_labels[i].add_theme_color_override("font_color", Color(1.0, 0.92, 0.6) if sel else Color(0.88, 0.90, 0.96))
	pause_opts.visible = not confirming
	pc_prompt.visible = confirming
	pc_yes.visible = confirming
	pc_no.visible = confirming
	if confirming:
		pc_prompt.text = T("Restart this run?") if pause_confirm == "restart" else T("Return to Main Menu?")
		pc_yes.text = T("Yes")
		pc_no.text = T("No")
		pc_yes.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6) if pause_sel == 0 else Color(0.88, 0.90, 0.96))
		pc_no.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6) if pause_sel == 1 else Color(0.88, 0.90, 0.96))
		pause_hint.text = T("Click Yes/No   •   Enter confirm   •   Esc = No")
	else:
		pause_opts.text = T("WASD move • Space dash • Auto-fire • P pause")
		pause_hint.text = T("Click, or W/S + Enter   •   Esc/P to resume")

func _pause_activate() -> void:
	Audio.play_sfx("click")
	match PAUSE_BTNS[pause_sel]["id"]:
		"resume":
			pause_dim.visible = false; state = ST_PLAY
		"restart":
			pause_confirm = "restart"; pause_sel = 1; _refresh_pause_ui()   # الافتراضي "No"
		"settings":
			set_return = ST_PAUSE
			set_sel = 0; _refresh_settings_ui()
			pause_dim.visible = false; set_dim.visible = true; state = ST_SETTINGS
		"menu":
			pause_confirm = "menu"; pause_sel = 1; _refresh_pause_ui()      # الافتراضي "No"

func _pause_confirm_yes() -> void:
	Audio.play_sfx("click")
	var act := pause_confirm
	pause_confirm = ""
	pause_sel = 0
	if act == "restart":
		_new_run()
	elif act == "menu":
		pause_dim.visible = false; _to_menu()

func _pause_confirm_no() -> void:
	Audio.play_sfx("click")
	pause_confirm = ""
	pause_sel = 0
	_refresh_pause_ui()

# رجوع موحّد بالماوس من أي شاشة فرعية (لا يعتمد على Esc)
func _do_back(from_state: int) -> void:
	if from_state == ST_SETTINGS:
		_exit_settings()
		return
	Audio.play_sfx("click")
	match from_state:
		ST_DIFF:
			df_dim.visible = false; cs_dim.visible = true; _refresh_charsel(); state = ST_CHARSEL
		ST_CHARSEL:
			cs_dim.visible = false; menu_dim.visible = true; _refresh_menu(); state = ST_MENU
		ST_CREDITS:
			cr_dim.visible = false; menu_dim.visible = true; _refresh_menu(); state = ST_MENU
		ST_SHOP:
			shop_dim.visible = false; menu_dim.visible = true; _refresh_menu(); state = ST_MENU
		ST_STATS:
			stats_dim.visible = false; menu_dim.visible = true; _refresh_menu(); state = ST_MENU

# الخروج من الإعدادات: نعود لقائمة الإيقاف لو دخلنا منها، وإلا للقائمة الرئيسية
func _exit_settings() -> void:
	Audio.play_sfx("click")
	set_dim.visible = false
	if set_return == ST_PAUSE:
		set_return = ST_MENU
		pause_sel = 0; _refresh_pause_ui()
		pause_dim.visible = true; state = ST_PAUSE
	else:
		menu_dim.visible = true; _refresh_menu(); state = ST_MENU

func _build_lang_ui() -> void:
	lang_dim = _mk_rect(Vector2.ZERO, Vector2(W, H), Color(0.05, 0.035, 0.09, 1.0))
	var t := _mk_label(Vector2(W * 0.5 - 450, 220), 56, Color(0.55, 0.80, 1.0), lang_dim)
	t.size = Vector2(900, 80)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.text = "Choose Language / اختر اللغة"
	var e := _mk_label(Vector2(W * 0.5 - 300, 360), 40, Color(1, 1, 1), lang_dim)
	e.size = Vector2(600, 60)
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	e.text = "[E]  English"
	var a := _mk_label(Vector2(W * 0.5 - 300, 440), 40, Color(1, 1, 1), lang_dim)
	a.size = Vector2(600, 60)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a.text = "[A]  العربية"
	lang_dim.visible = false

func _show_only_menu() -> void:
	menu_dim.visible = true
	set_dim.visible = false
	lv_dim.visible = false
	go_dim.visible = false
	pause_dim.visible = false
	vic_dim.visible = false
	if lang_dim:
		lang_dim.visible = false
	if shop_dim:
		shop_dim.visible = false
	if stats_dim:
		stats_dim.visible = false
	if cs_dim:
		cs_dim.visible = false
	if df_dim:
		df_dim.visible = false
	if cr_dim:
		cr_dim.visible = false
	state = ST_MENU
	_refresh_menu()
	_hud_visible(false)

func _show_lang_screen() -> void:
	lang_dim.visible = true
	menu_dim.visible = false
	_hud_visible(false)
	state = ST_LANG

func _confirm_lang() -> void:
	lang_chosen = true
	_save_settings()
	_apply_lang()
	Audio.play_sfx("click")
	lang_dim.visible = false
	_show_only_menu()

func _hud_visible(v: bool) -> void:
	for n in [lbl_kills, lbl_level, lbl_time, lbl_stage, lbl_boss,
			hp_back, hp_fill, lbl_hp, lbl_q, lbl_r, lbl_status, xp_back, xp_fill, dash_back, dash_fill]:
		n.visible = v
	for p in hud_panels:
		p.visible = v
	if not pause_hud_btn.is_empty():
		for key in ["border", "bg", "bar1", "bar2"]:
			pause_hud_btn[key].visible = v
	if not v:
		lbl_combo.visible = false
		_clear_combat_ui()   # مفيش رسائل قتال فوق القوائم إطلاقاً

# ================================================================
#  متجر الترقيات الدائمة (Meta shop)
func _build_shop_ui() -> void:
	shop_dim = _mk_rect(Vector2.ZERO, Vector2(W, H), Color(0.03, 0.02, 0.05, 0.97))
	shop_title = _mk_label(Vector2(W * 0.5 - 400, 34), 46, Color(1.0, 0.72, 0.28), shop_dim)
	shop_title.size = Vector2(800, 62); shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_cinders_lbl = _mk_label(Vector2(W * 0.5 - 400, 98), 26, Color(1.0, 0.88, 0.45), shop_dim)
	shop_cinders_lbl.size = Vector2(800, 36); shop_cinders_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for i in Balance.META_SHOP.size():
		var r := _mk_label(Vector2(W * 0.5 - 380, 150 + i * 44), 24, Color(1, 1, 1), shop_dim)
		r.size = Vector2(760, 38); r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shop_rows.append(r)
	shop_hint = _mk_label(Vector2(W * 0.5 - 450, H - 56), 20, Color(0.72, 0.72, 0.80), shop_dim)
	shop_hint.size = Vector2(900, 50); shop_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_btns[ST_SHOP] = _mk_button(shop_dim, BACK_RECT, "< Back")
	shop_dim.visible = false

func _refresh_shop_ui() -> void:
	shop_title.text = T("PERMANENT UPGRADES")
	shop_cinders_lbl.text = T("Cinders: %d") % cinders
	for i in Balance.META_SHOP.size():
		var it = Balance.META_SHOP[i]
		var owned := _tier(it["id"])
		var maxt: int = it["costs"].size()
		var pips := ""
		for p in maxt:
			pips += "•" if p < owned else "·"
		var sel := i == shop_sel
		var cost_txt := T("MAX")
		var affordable := false
		if owned < maxt:
			var c: int = it["costs"][owned]
			cost_txt = "%d" % c
			affordable = cinders >= c
		var line := "%s   [%s]   %s" % [T(it["name"]), pips, cost_txt]
		if sel:
			line = "‹  " + line + "  ›"
		shop_rows[i].text = line
		var col := Color(1, 1, 1)
		if owned >= maxt:
			col = Color(0.45, 0.85, 0.5)          # مكتمل
		elif not affordable:
			col = Color(0.55, 0.55, 0.62)          # مش قادر يشتري
		if sel:
			col = Color(1.0, 0.85, 0.35)
		shop_rows[i].add_theme_color_override("font_color", col)
	var d = Balance.META_SHOP[shop_sel]
	shop_hint.text = T(d["desc"]) + "\n" + T("W/S select   •   Enter buy   •   Backspace back")

func _show_shop() -> void:
	menu_dim.visible = false
	shop_sel = 0
	_refresh_shop_ui()
	shop_dim.visible = true
	state = ST_SHOP

func _buy_shop() -> void:
	var it = Balance.META_SHOP[shop_sel]
	var owned := _tier(it["id"])
	var maxt: int = it["costs"].size()
	if owned >= maxt:
		Audio.play_sfx("click")
		return
	var c: int = it["costs"][owned]
	if cinders < c:
		Audio.play_sfx("hurt", -6.0, 1.0, 1.0)   # رفض — مفيش جمرات كفاية
		return
	cinders -= c
	shop[it["id"]] = owned + 1
	_save_settings()
	Audio.play_sfx("levelup", -2.0, 1.0, 1.0)
	_refresh_shop_ui()

# ================================================================
#  شاشة الإحصائيات (Stats / Records)
func _build_stats_ui() -> void:
	stats_dim = _mk_rect(Vector2.ZERO, Vector2(W, H), Color(0.03, 0.02, 0.05, 0.97))
	stats_title = _mk_label(Vector2(W * 0.5 - 400, 46), 46, Balance.COL_REWARD, stats_dim)
	stats_title.size = Vector2(800, 62); stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_body = _mk_label(Vector2(W * 0.5 - 400, 130), 25, Balance.COL_TEXT, stats_dim)
	stats_body.size = Vector2(800, 580); stats_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_hint = _mk_label(Vector2(W * 0.5 - 450, H - 54), 20, Balance.COL_TEXT_DIM, stats_dim)
	stats_hint.size = Vector2(900, 30); stats_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_btns[ST_STATS] = _mk_button(stats_dim, BACK_RECT, "< Back")
	stats_dim.visible = false

func _refresh_stats_ui() -> void:
	stats_title.text = T("RECORDS")
	var m := int(rec_time) / 60
	var s := int(rec_time) % 60
	var ach := 0
	for a in Balance.ACHIEVEMENTS:
		if achieved.has(a["id"]):
			ach += 1
	var unl := 0
	for c in CHARS:
		if _char_unlocked(CHARS.find(c)):
			unl += 1
	# اكتشاف التركيبات (Collection): المكتشف بالاسم، غير المكتشف ???
	var syn_n := 0
	var syn_list := []
	for syn in Balance.SYNERGIES:
		if syn_found.has(syn["id"]):
			syn_n += 1
			syn_list.append(T(syn["name"]))
		else:
			syn_list.append("???")
	stats_body.text = "\n".join([
		T("— Best Run —"),
		T("Best Stage: %d/%d    Best Time: %02d:%02d    Most Kills: %d    Wins: %d") % [rec_stage, FINAL_STAGE, m, s, rec_kills, rec_wins],
		"",
		T("— Lifetime —"),
		T("Runs: %d    Kills: %d    Bosses: %d    Gems: %d") % [total_runs, total_kills, total_bosses, total_gems],
		"",
		T("Cinders: %d    Survivors: %d/%d    Achievements: %d/%d    Danger: %d") % [cinders, unl, CHARS.size(), ach, Balance.ACHIEVEMENTS.size(), asc_max],
		"",
		T("— Synergies Discovered: %d/%d —") % [syn_n, Balance.SYNERGIES.size()],
		" · ".join(syn_list),
	])
	stats_hint.text = (T("Backspace back    •    [Del] Reset progress (press again to confirm)")
		if not reset_armed else T("!! Press [Del] again to WIPE all progress — Backspace to cancel !!"))
	stats_hint.add_theme_color_override("font_color", Balance.COL_ENEMY if reset_armed else Balance.COL_TEXT_DIM)

func _show_stats() -> void:
	menu_dim.visible = false
	reset_armed = false
	_refresh_stats_ui()
	stats_dim.visible = true
	state = ST_STATS

func _reset_progress() -> void:
	# مسح كل التقدّم (بعد تأكيد) — يرجّع للـ defaults
	rec_time = 0.0; rec_kills = 0; rec_stage = 0; rec_wins = 0
	total_runs = 0; total_kills = 0; total_bosses = 0; total_gems = 0
	cinders = 0; shop = {}; unlocked = {}; achieved = {}; asc = 0; asc_max = 0
	tips_seen = {}   # يرجّع التلميحات التعليمية للاعب الجديد
	syn_found = {}   # يرجّع اكتشاف التركيبات (Collection)
	char_sel = 0     # ارجع للناجي الافتراضي (الباقي أصبح مقفولاً)
	df_sel = 0
	_save_settings()
	Audio.play_sfx("bossdie", -2.0, 0.7, 0.7)

# ================================================================
#  RUN CONTROL
func _new_run() -> void:
	if not _char_unlocked(char_sel):
		char_sel = 0   # أمان: ما نبدأش بشخصية مقفولة
	pp = WC
	cam.position = WC
	pspeed = 305.0
	maxhp = 115.0
	fire_cd = 0.0; fire_rate = 0.46
	bullet_dmg = 23.0
	invuln = 0.0; dash_cd = 0.0; dash_t = 0.0; dash_cd_max = DASH_CD
	kills = 0; level = 1; xp = 0; xp_need = 6; gametime = 0.0
	run_bosses = 0; run_gems = 0; rerolls = 2; boss_warned = false
	stage = 1; stage_timer = STAGE_LEN
	multishot = 1
	pierce = 0; crit = 0.0; magnet = 150.0; orbit_n = 0; aura_r = 0.0
	chain_n = 0; chain_t = 0.0; explode_n = 0; ric_n = 0; rear_n = 0
	regen_n = 0; armor_n = 0; steal_n = 0; slow_n = 0; bsize = 1.0
	_apply_meta()   # ترقيات المتجر الدائمة (قبل مميزات الناجي عشان مميزاته تتضاعف فوقها)
	# الناجي المختار — v1.2 Phase A: سلاح توقيع حصري + قدرة Q لكل شخصية
	pcol = CHARS[char_sel]["col"]
	sig = String(CHARS[char_sel].get("sig", "rifle"))
	q_cd_max = float(CHARS[char_sel].get("qcd", 14.0))
	q_cd = 3.0   # مش جاهزة لحظة البداية (منع سبام أول ثانية)
	heal_mul = 1.0; crit_cap = 0.5; rate_floor = 0.16; speed_cap = 470.0
	luck_f = 1.0; char_steal_bonus = false
	dash_charges_max = 1; dash_charges = 1; dash_recharge_t = 0.0; dash_id = 0
	wave_cd = 0.0; q_turret = null; q_clone = null; berserk_t = 0.0
	q_firetrail_t = 0.0; fire_patches.clear()
	g_dmg_mul = 1.0; g_dmg_t = 0.0; g_crit_add = 0.0; g_crit_t = 0.0
	g_rate_mul = 1.0; g_rate_t = 0.0; roll_anim_t = 0.0; roll_result = 0
	match char_sel:
		0:  # Soldier (rifle): طلقة دقيقة قوية مخترقة — أبطأ إيقاعاً
			# (معايرة: 1.6 خلّت الزعيم يموت في 15ث — الهدف 35-60)
			bullet_dmg *= 1.3
			fire_rate *= 1.45
			pierce += 1
		1:  # Pyromancer (firebolt): ساحر نار — كرات مدى متوسط + انفجار كل 3 إصابات + Fireball Q
			bullet_dmg *= 1.02   # ضرر متوسط (أقل من الجندي)
			fire_rate *= 1.12    # إيقاع متوسط (أبطأ شوية من الأساس)
			maxhp *= 0.95        # هش شوية من قريب
		2:  # Shinobi (crescent): سلاش قوسي مدى قريب-متوسط + داش (3 شحنات) + R Ultimate
			pspeed *= 1.22
			dash_cd_max *= 0.78
			dash_charges_max = 3
			dash_charges = 3
			magnet *= 1.3
			maxhp *= 0.82
			heal_mul = 0.8
			bullet_dmg *= 1.18   # أساس ضرر السلاش (السلاح الأساسي بقى السلاش مش الداش)
			fire_rate *= 0.7     # إيقاع سلاش سريع
			crit = maxf(crit, 0.10)
			rerolls += 1
			speed_cap = 620.0
		3:  # Knight (spinblade): سيفان دوّاران — المدى القريب هو درعه
			orbit_n = 2
			maxhp *= 1.15
			bullet_dmg *= 1.1
			pspeed *= 0.9
			heal_mul = 0.9
			rate_floor = 0.22
		4:  # Titan (shockwave): موجات صادمة بدفع — حصن بطيء
			maxhp *= 1.45
			pspeed *= 0.82
			armor_n += 2
			bullet_dmg *= 1.1
			rate_floor = 0.26
			speed_cap = 400.0
		5:  # Gambler (dice): نرد بكريت أعلى من الجميع + Q مقامرة حقيقية
			maxhp *= 0.7
			crit = maxf(crit, 0.30)   # +15% فوق قاعدة الطيف القديمة — هوية النرد
			bullet_dmg *= 0.95   # معايرة: الكريت هو مصدر قوته مش الضرر الخام
			ric_n = maxi(ric_n, 1)
			heal_mul = 0.6
			crit_cap = 0.75
			luck_f = 1.15
	pspeed = minf(pspeed, speed_cap)
	hp = maxhp
	# تصفير أنظمة العلاج المقيّد وعدّادات v1.1
	no_dmg_t = 99.0; wound_t = 0.0; vamp_cd = 0.0; shatter_cd = 0.0
	plating_t = 0.0; plating_cd = 0.0; burst_spd_t = 0.0
	stage_heal_regen = 0.0; stage_heal_steal = 0.0
	steal_kills = 0; pulse_kills = 0; magnet_gems = 0; volley_i = 0
	# تصفير إحصائيات تقرير المعايرة
	stat_dmg_dealt = 0.0; stat_dmg_taken = 0.0; stat_heal = {}
	last_hurt_src = "-"; dps_bucket = 0.0; dps_bucket_t = 0.0; stat_max_dps = 0.0
	boss_fight_t = 0.0; boss_times = []
	# تصفير بركات v1.1.3 وضغط الزعيم
	frost_trail.clear(); mark_hits = 0; msurge_gems = 0; bbreak_t = 0.0; guard_cd = 0.0
	boss_minion_t = 0.0; boss_kite_t = 0.0; boss_haz_t = 0.0
	# تصفير v1.1.5
	closecall_t = 0.0; thunder_kills = 0; thunder_pending = false; frost_burst_cd = 0.0
	evo_thunder = false; evo_frostrun = false; evo_shatter = false; boss_reward_active = false
	# تصفير v1.2 B/C (أسلحة جانبية + تطوّرات)
	kunai_cd = 0.0; forb_ang = 0.0; bomb_cd = 0.0; fmeteor_cd = 0.0
	bombs.clear(); fmeteors.clear(); orbit_radius = 72.0
	# تصفير v1.2.3 (Pyromancer + Shinobi rework)
	fbolt_hits = 0; fireballs.clear(); slash_cd = 0.0; slash_fx.clear()
	sassault = null; rift = null; r_active_t = 0.0
	r_buff_t = 0.0; r_fate_mul = 1.0; r_fate_t = 0.0; r_fate_good = false
	r_cd_max = float(CHARS[char_sel].get("rcd", 60.0))
	r_cd = r_cd_max   # الأولتيمت مش جاهز بداية الجولة
	evo_bladestorm = false; evo_ewinter = false; evo_meteor = false
	evo_tstorm = false; evo_thalo = false; evo_soulp = false
	# كومبو / تطوّرات / أحداث
	combo = 0; combo_best = 0; combo_t = 0.0; hitstop = 0.0
	ups_count = {}
	evo_storm = false; evo_cyclone = false; evo_cluster = false; evo_pending = ""
	syn_active = {}; syn_orbit_t = 0.0; syn_frost_t = 0.0; is_moving = false; pending_aoe = []
	event_t = rng.randf_range(18.0, 32.0)
	meteors.clear(); rings.clear()
	freeze_t = 0.0; void_intro = 0.0; king_spawned = false
	enemies.clear(); bullets.clear(); ebullets.clear(); gems.clear()
	parts.clear(); trail.clear(); dmgnums.clear(); zaps.clear(); hazards.clear()
	vacuum_t = 0.0
	spawn_cd = 0.5
	boss_alive = false
	shake = 0.0; flash = 0.0; wipe_t = 0.0
	Audio.play_music("s0")
	_gen_decor()
	menu_dim.visible = false
	go_dim.visible = false
	vic_dim.visible = false
	if cs_dim: cs_dim.visible = false
	if df_dim: df_dim.visible = false
	if cr_dim: cr_dim.visible = false
	_save_settings()   # يحفظ اختيار الناجي
	_hud_visible(true)
	state = ST_PLAY
	stage_intro_t = 2.0
	stage_intro_title = T("Stage 1 - %s") % T(_stage_title())
	stage_intro_sub = ""
	_tip("move", "Move: WASD/Arrows • Auto-fire • Blue core = you, Red = danger, Gold = reward", 4.0)

func _to_menu() -> void:
	state = ST_MENU
	Audio.play_music("menu")
	_show_only_menu()

# ================================================================
#  INPUT
func _unhandled_input(ev: InputEvent) -> void:
	if SHOTMODE:
		return
	if ev is InputEventMouseMotion:
		mouse_pos = ev.position          # لتتبّع الـ hover
		# v1.1.3: سحب سلايدر الصوت بالماوس (يزوّد ويقلّل) — القيمة من موضع الماوس
		if state == ST_SETTINGS and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 and set_sel <= 1:
			var ry := SET_TOP + float(set_sel) * SET_STEP
			if mouse_pos.y >= ry and mouse_pos.y < ry + 72.0:
				_set_volume_row(set_sel, _slider_from_mouse(mouse_pos.x))
		return
	# تحكّم بالماوس (والنقرة كمان بتفعّل الكيبورد في المتصفح)
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var mp: Vector2 = ev.position
		# زر الرجوع الموحّد (أعلى-يسار) في أي شاشة فرعية — يعمل بالماوس بدون Esc
		if back_btns.has(state) and BACK_RECT.has_point(mp):
			_do_back(state); return
		# زر الإيقاف داخل اللعب (HUD)
		if state == ST_PLAY and not pause_hud_btn.is_empty() and Rect2(pause_hud_btn["rect"]).has_point(mp):
			pause_sel = 0; pause_confirm = ""; _refresh_pause_ui()
			pause_dim.visible = true; state = ST_PAUSE; Audio.play_sfx("click"); return
		match state:
			ST_MENU:
				for i in MENU_BTNS.size():
					if _menu_btn_rect(i).has_point(mp):
						menu_sel = i; _refresh_menu(); _menu_activate(); return
			ST_CHARSEL:
				# نقر على أيقونة ناجٍ في الصفّ
				var lx0 := 352.0 - 2.5 * 86.0
				for i in CHARS.size():
					if mp.distance_to(Vector2(lx0 + 86.0 * i, 512.0)) < 34.0:
						char_sel = i; Audio.play_sfx("click"); _refresh_charsel(); return
				# نقر في منطقة المعاينة = تأكيد
				if mp.x < 640.0 and mp.y > 130.0 and mp.y < 500.0:
					_charsel_confirm(); return
				# غير ذلك: رجوع
				Audio.play_sfx("click"); cs_dim.visible = false
				menu_dim.visible = true; _refresh_menu(); state = ST_MENU; return
			ST_DIFF:
				for i in Balance.DIFF_TIERS.size():
					if _diff_row_rect(i).has_point(mp):
						df_sel = i; Audio.play_sfx("click"); _refresh_diff()
						if i <= asc_max:
							_diff_confirm()
						return
				Audio.play_sfx("click"); df_dim.visible = false
				cs_dim.visible = true; _refresh_charsel(); state = ST_CHARSEL; return
			ST_CREDITS:
				Audio.play_sfx("click"); cr_dim.visible = false
				menu_dim.visible = true; _refresh_menu(); state = ST_MENU; return
			ST_SHOP:
				for i in Balance.META_SHOP.size():
					var ry := 150.0 + i * 44.0
					if mp.y >= ry and mp.y < ry + 40.0:
						shop_sel = i; _refresh_shop_ui(); _buy_shop(); return
				Audio.play_sfx("click"); shop_dim.visible = false
				menu_dim.visible = true; _refresh_menu(); state = ST_MENU; return
			ST_STATS:
				Audio.play_sfx("click"); stats_dim.visible = false
				menu_dim.visible = true; _refresh_menu(); state = ST_MENU; return
			ST_LEVELUP:
				var cw := 300.0
				var nlv := lv_choices.size()
				var gap := 40.0 if nlv <= 3 else 16.0
				var x0 := _lv_card_x0(nlv)
				for i in nlv:
					var rx := x0 + (cw + gap) * i
					if mp.x >= rx and mp.x <= rx + cw and mp.y >= 250.0 and mp.y <= 450.0:
						Audio.play_sfx("click"); _apply_upgrade(lv_choices[i]); boss_reward_active = false; lv_dim.visible = false; state = ST_PLAY; return
			ST_SETTINGS:
				for i in SET_ROWS:
					var ry := SET_TOP + i * SET_STEP
					if mp.y >= ry and mp.y < ry + 60.0:
						set_sel = i
						if i <= 1:
							# v1.1.3 fix: النقر على السلايدر يحدد القيمة من موضع الماوس
							# (كان بيزوّد بس — دلوقتي يزوّد ويقلّل حسب مكان النقرة/السحب)
							_set_volume_row(i, _slider_from_mouse(mp.x))
						else:
							_adjust_setting(1)   # صفوف التبديل (ON/OFF/لغة) بالنقر زي ما هي
						return
				_exit_settings(); return
			ST_OVER:
				if Rect2(go_btns["restart"]["rect"]).has_point(mp):
					Audio.play_sfx("click"); go_dim.visible = false; _new_run(); return
				if Rect2(go_btns["menu"]["rect"]).has_point(mp):
					Audio.play_sfx("click"); go_dim.visible = false; _to_menu(); return
				return
			ST_VICTORY:
				if Rect2(vic_btn["rect"]).has_point(mp):
					Audio.play_sfx("click"); vic_dim.visible = false; _to_menu(); return
				return
			ST_PAUSE:
				if pause_confirm != "":
					if _pc_rect(0).has_point(mp):
						_pause_confirm_yes(); return
					if _pc_rect(1).has_point(mp):
						_pause_confirm_no(); return
					return
				for i in PAUSE_BTNS.size():
					if _pause_btn_rect(i).has_point(mp):
						pause_sel = i; _refresh_pause_ui(); _pause_activate(); return
				return
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	# physical_keycode = موضع الزرار (مستقل عن لغة الكيبورد)
	var k: int = ev.physical_keycode
	match state:
		ST_LANG:
			if k == KEY_E:
				LANG = 0; _confirm_lang()
			elif k == KEY_A:
				LANG = 1; _confirm_lang()
		ST_MENU:
			if k == KEY_W or k == KEY_UP:
				menu_sel = (menu_sel + MENU_BTNS.size() - 1) % MENU_BTNS.size()
				Audio.play_sfx("click"); _refresh_menu()
			elif k == KEY_S or k == KEY_DOWN:
				menu_sel = (menu_sel + 1) % MENU_BTNS.size()
				Audio.play_sfx("click"); _refresh_menu()
			elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
				_menu_activate()
			# اختصارات مباشرة (سرعة للاعب المخضرم)
			elif k == KEY_U:
				menu_sel = 1; _menu_activate()
			elif k == KEY_C:
				menu_sel = 2; _menu_activate()
		ST_CHARSEL:
			if k == KEY_A or k == KEY_LEFT:
				char_sel = (char_sel + CHARS.size() - 1) % CHARS.size()
				Audio.play_sfx("click"); _refresh_charsel()
			elif k == KEY_D or k == KEY_RIGHT:
				char_sel = (char_sel + 1) % CHARS.size()
				Audio.play_sfx("click"); _refresh_charsel()
			elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
				_charsel_confirm()
			elif k == KEY_BACKSPACE:
				Audio.play_sfx("click"); cs_dim.visible = false
				menu_dim.visible = true; _refresh_menu(); state = ST_MENU
		ST_DIFF:
			if k == KEY_W or k == KEY_UP:
				df_sel = (df_sel + Balance.DIFF_TIERS.size() - 1) % Balance.DIFF_TIERS.size()
				Audio.play_sfx("click"); _refresh_diff()
			elif k == KEY_S or k == KEY_DOWN:
				df_sel = (df_sel + 1) % Balance.DIFF_TIERS.size()
				Audio.play_sfx("click"); _refresh_diff()
			elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
				_diff_confirm()
			elif k == KEY_BACKSPACE:
				Audio.play_sfx("click"); df_dim.visible = false
				cs_dim.visible = true; _refresh_charsel(); state = ST_CHARSEL
		ST_CREDITS:
			if k == KEY_BACKSPACE or k == KEY_ENTER or k == KEY_KP_ENTER:
				Audio.play_sfx("click"); cr_dim.visible = false
				menu_dim.visible = true; _refresh_menu(); state = ST_MENU
		ST_STATS:
			if k == KEY_BACKSPACE:
				if reset_armed:
					reset_armed = false; _refresh_stats_ui()
				else:
					Audio.play_sfx("click"); stats_dim.visible = false
					menu_dim.visible = true; _refresh_menu(); state = ST_MENU
			elif k == KEY_DELETE:
				if reset_armed:
					_reset_progress(); reset_armed = false; _refresh_stats_ui()
				else:
					reset_armed = true; Audio.play_sfx("hurt", -4.0); _refresh_stats_ui()
		ST_SHOP:
			if k == KEY_W or k == KEY_UP:
				shop_sel = (shop_sel + Balance.META_SHOP.size() - 1) % Balance.META_SHOP.size()
				Audio.play_sfx("click"); _refresh_shop_ui()
			elif k == KEY_S or k == KEY_DOWN:
				shop_sel = (shop_sel + 1) % Balance.META_SHOP.size()
				Audio.play_sfx("click"); _refresh_shop_ui()
			elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE or k == KEY_D or k == KEY_RIGHT:
				_buy_shop()
			elif k == KEY_BACKSPACE or k == KEY_U:
				Audio.play_sfx("click"); shop_dim.visible = false
				menu_dim.visible = true; _refresh_menu(); state = ST_MENU
		ST_VICTORY:
			if k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_M:
				Audio.play_sfx("click"); vic_dim.visible = false; _to_menu()
		ST_SETTINGS:
			if k == KEY_W or k == KEY_UP:
				set_sel = (set_sel + SET_ROWS - 1) % SET_ROWS; Audio.play_sfx("click"); _refresh_settings_ui()
			elif k == KEY_S or k == KEY_DOWN:
				set_sel = (set_sel + 1) % SET_ROWS; Audio.play_sfx("click"); _refresh_settings_ui()
			elif k == KEY_A or k == KEY_LEFT:
				_adjust_setting(-1)
			elif k == KEY_D or k == KEY_RIGHT:
				_adjust_setting(1)
			elif k == KEY_ENTER or k == KEY_SPACE:
				if set_sel >= 2:
					_adjust_setting(1)
			elif k == KEY_BACKSPACE or k == KEY_ESCAPE:
				_exit_settings()
		ST_LEVELUP:
			var pick := -1
			if k == KEY_1 or k == KEY_KP_1: pick = 0
			elif k == KEY_2 or k == KEY_KP_2: pick = 1
			elif k == KEY_3 or k == KEY_KP_3: pick = 2
			elif k == KEY_4 or k == KEY_KP_4: pick = 3
			elif k == KEY_R and rerolls > 0 and not boss_reward_active:
				rerolls -= 1
				Audio.play_sfx("click", 0.0, 1.1, 1.2)
				_roll_levelup_cards()
			if pick >= 0 and pick < lv_choices.size():
				Audio.play_sfx("click")
				_apply_upgrade(lv_choices[pick])
				boss_reward_active = false
				lv_dim.visible = false
				state = ST_PLAY
		ST_OVER:
			if k == KEY_R or k == KEY_ENTER:
				Audio.play_sfx("click"); go_dim.visible = false; _new_run()
			elif k == KEY_M:
				Audio.play_sfx("click"); go_dim.visible = false; _to_menu()
		ST_PAUSE:
			if pause_confirm != "":
				if k == KEY_A or k == KEY_LEFT or k == KEY_D or k == KEY_RIGHT:
					pause_sel = 1 - pause_sel; Audio.play_sfx("click"); _refresh_pause_ui()
				elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
					if pause_sel == 0: _pause_confirm_yes()
					else: _pause_confirm_no()
				elif k == KEY_Y:
					_pause_confirm_yes()
				elif k == KEY_N or k == KEY_BACKSPACE or k == KEY_ESCAPE:
					_pause_confirm_no()
			elif k == KEY_P or k == KEY_BACKSPACE or k == KEY_ESCAPE:
				Audio.play_sfx("click"); pause_dim.visible = false; state = ST_PLAY
			elif k == KEY_W or k == KEY_UP:
				pause_sel = (pause_sel + PAUSE_BTNS.size() - 1) % PAUSE_BTNS.size()
				Audio.play_sfx("click"); _refresh_pause_ui()
			elif k == KEY_S or k == KEY_DOWN:
				pause_sel = (pause_sel + 1) % PAUSE_BTNS.size()
				Audio.play_sfx("click"); _refresh_pause_ui()
			elif k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
				_pause_activate()
		ST_PLAY:
			if k == KEY_P or k == KEY_BACKSPACE or k == KEY_ESCAPE:
				pause_sel = 0; pause_confirm = ""; _refresh_pause_ui()
				pause_dim.visible = true; state = ST_PAUSE; Audio.play_sfx("click")

func _process(dt: float) -> void:
	if SHOTMODE:
		return
	if AUTOPLAY:
		_auto_tick()
		return
	animt += dt
	# انتقال fade: يعتّم لحظة تغيّر الشاشة ويصفّى بسلاسة
	if state != _last_state:
		_last_state = state
		if state != ST_PLAY:
			fade_a = 0.55
			_clear_combat_ui()   # مغادرة اللعب لأي شاشة = تنضيف رسائل القتال فوراً
	fade_a = maxf(0.0, fade_a - dt * 3.2)
	if fade_rect:
		fade_rect.color = Color(0.02, 0.02, 0.04, fade_a)
	_hover_tick()
	if state == ST_PLAY:
		if hitstop > 0.0:
			hitstop -= dt   # توقّف لحظي — العالم متجمد
		else:
			_step(dt)
	if BENCH:
		hp = maxf(hp, 1.0e6)   # ما يموتش أثناء القياس
		bench_frames += 1
		bench_frame_hist.append(dt)
		if bench_frames == 720:
			_bench_report()
			get_tree().quit()
	queue_redraw()

# hover على الكروت/الخيارات (button states) + صوت hover عند التغيّر
func _hover_tick() -> void:
	var h := ""
	if state == ST_LEVELUP:
		var cw := 300.0
		var nlv := lv_choices.size()
		var gap := 40.0 if nlv <= 3 else 16.0
		var x0 := _lv_card_x0(nlv)
		for i in nlv:
			var rx := x0 + (cw + gap) * i
			if mouse_pos.x >= rx and mouse_pos.x <= rx + cw and mouse_pos.y >= 250.0 and mouse_pos.y <= 450.0:
				h = "lv%d" % i
		for i in nlv:
			var hov := h == ("lv%d" % i)
			lv_cards[i]["frame"].position.y = 247.0 - (7.0 if hov else 0.0)   # لمسة رفع بسيطة عند الـ hover
	elif state == ST_MENU:
		for i in MENU_BTNS.size():
			if _menu_btn_rect(i).has_point(mouse_pos):
				h = "mb%d" % i
				if menu_sel != i:
					menu_sel = i; _refresh_menu()
				break
	elif state == ST_DIFF:
		for i in Balance.DIFF_TIERS.size():
			if _diff_row_rect(i).has_point(mouse_pos):
				h = "df%d" % i
				if df_sel != i:
					df_sel = i; _refresh_diff()
				break
	elif state == ST_PAUSE:
		if pause_confirm != "":
			for i in 2:
				if _pc_rect(i).has_point(mouse_pos):
					h = "pc%d" % i
					if pause_sel != i:
						pause_sel = i; _refresh_pause_ui()
					break
		else:
			for i in PAUSE_BTNS.size():
				if _pause_btn_rect(i).has_point(mouse_pos):
					h = "pb%d" % i
					if pause_sel != i:
						pause_sel = i; _refresh_pause_ui()
					break
	elif state == ST_OVER:
		for key in go_btns:
			var hov := Rect2(go_btns[key]["rect"]).has_point(mouse_pos)
			_btn_hover(go_btns[key], hov)
			if hov: h = "go_" + key
	elif state == ST_VICTORY:
		if not vic_btn.is_empty():
			var hovv := Rect2(vic_btn["rect"]).has_point(mouse_pos)
			_btn_hover(vic_btn, hovv)
			if hovv: h = "vic"
	# hover زر الرجوع الموحّد (في أي شاشة فرعية بها زر رجوع)
	if back_btns.has(state):
		var over_back := BACK_RECT.has_point(mouse_pos)
		_btn_hover(back_btns[state], over_back)
		if over_back:
			h = "back"
	# hover زر الإيقاف داخل اللعب
	if state == ST_PLAY and not pause_hud_btn.is_empty():
		var over_p := Rect2(pause_hud_btn["rect"]).has_point(mouse_pos)
		pause_hud_btn["bg"].color = Color(0.24, 0.32, 0.48, 0.95) if over_p else Color(0.13, 0.17, 0.26, 0.85)
		if over_p:
			h = "pausebtn"
	if h != hover_id:
		hover_id = h
		if h != "":
			Audio.play_sfx("click", -18.0, 1.5, 1.7)   # صوت hover خفيف

# ================================================================
#  MAIN STEP
func _step(dt: float) -> void:
	if not boss_alive:
		gametime += dt          # المؤقت يقف أثناء الزعيم
		stage_timer -= dt
		# تحذير اقتراب البوس (مرة واحدة، آخر 3.5ث) + تخفيف الظهور
		if not boss_warned and stage_timer <= 3.5 and stage < FINAL_STAGE:
			boss_warned = true
			spawn_cd = maxf(spawn_cd, 1.2)   # هدوء بسيط قبل البوس
			Audio.play_sfx("boss", -6.0, 1.2, 1.2)
			_flash_msg(T("!! Boss approaching !!"), 2.0)
			_tip("boss", "Boss incoming! Bosses have a health bar — watch their attack tells.", 3.5)
		if stage_timer <= 0.0:
			_spawn_boss()
	# الفراغ: عودة أسياد العوالم بعد المقدمة
	if stage == FINAL_STAGE and void_intro > 0.0:
		void_intro -= dt
		if void_intro <= 0.0:
			_spawn_void_gauntlet()
	hurt_snd_cd = maxf(0.0, hurt_snd_cd - dt)
	kill_snd_cd = maxf(0.0, kill_snd_cd - dt)
	invuln = maxf(0.0, invuln - dt)
	dash_cd = maxf(0.0, dash_cd - dt)
	dash_t = maxf(0.0, dash_t - dt)

	# movement + dash — physical = موضع الزرار (يشتغل مع أي لغة كيبورد عربي/إنجليزي)
	var mv := Vector2.ZERO
	if AUTOPLAY:
		mv = _bot_move()   # بوت المعايرة بيحرّك بدل الكيبورد
	else:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): mv.y -= 1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): mv.y += 1
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): mv.x -= 1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): mv.x += 1
		# يد تحكم: العصا اليسرى + زر A/الكتف للاندفاع
		var jx := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
		var jy := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
		if absf(jx) > 0.25: mv.x += jx
		if absf(jy) > 0.25: mv.y += jy
	var pad_dash := false if AUTOPLAY else (Input.is_joy_button_pressed(0, JOY_BUTTON_A) or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER))
	var want_dash := (AUTOPLAY and bot_dash) or (not AUTOPLAY and (Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_SPACE) or pad_dash))
	# v1.2: قدرة Q (كيبورد Q / زر X في اليد) — البوت بيستخدمها لما تجهز والساحة زحمة
	var want_q := (AUTOPLAY and enemies.size() > 5) if AUTOPLAY else (Input.is_physical_key_pressed(KEY_Q) or Input.is_joy_button_pressed(0, JOY_BUTTON_X))
	if want_q and q_cd <= 0.0 and state == ST_PLAY and sassault == null:
		_use_q()
	# v1.2.5: أولتيمت R لكل الشخصيات (يفتح عند Level 7، تبريد ثابت 60ث) — R في اللعب لا يتعارض مع reroll (شاشة الارتقاء فقط)
	if level >= int(CHARS[char_sel].get("runlock", 7)) and r_cd <= 0.0 and rift == null and r_buff_t <= 0.0 and sassault == null and state == ST_PLAY:
		var want_r := (AUTOPLAY and enemies.size() > 6) if AUTOPLAY else (Input.is_physical_key_pressed(KEY_R) or Input.is_joy_button_pressed(0, JOY_BUTTON_Y))
		if want_r:
			_use_r()
	# Shinobi: 3 شحنات داش (الداش نفسه السلاح) — الباقي بشحنة/تبريد كالمعتاد
	var can_dash := (dash_charges > 0 and dash_cd <= 0.0) if sig == "crescent" else dash_cd <= 0.0
	if want_dash and can_dash and mv != Vector2.ZERO:
		dash_t = 0.16
		invuln = maxf(invuln, 0.35)
		dash_id += 1
		if sig == "crescent":
			dash_charges -= 1
			dash_cd = 0.22   # فاصل قصير بين الشحنات
			if dash_recharge_t <= 0.0:
				dash_recharge_t = dash_cd_max * 0.82
		else:
			dash_cd = dash_cd_max
		# Agility: الداش يمنح اندفاعة سرعة قصيرة (بركة مشروطة بدل رقم خام)
		if int(ups_count.get("speed", 0)) >= 1:
			burst_spd_t = 2.0
		# ترقية Swift Dash Lv3 (Improvement Pass): الداش بيشفط الجواهر ناحيتك
		if int(ups_count.get("dash", 0)) >= 3:
			vacuum_t = maxf(vacuum_t, 0.5)
		# Boss Breaker (v1.1.3): داش قريب من الزعيم = نافذة +ضرر زعماء 3ث
		if int(ups_count.get("bbreak", 0)) > 0 and boss_alive:
			for eb in enemies:
				if String(eb["type"]) == "boss" and Vector2(eb["pos"]).distance_to(pp) < 400.0:
					bbreak_t = 3.0
					if rings.size() < 26:
						rings.append({"pos": Vector2(pp), "t": 0.0, "max": 90.0, "col": Balance.COL_REWARD})
					break
		Audio.play_sfx("dash", -4.0)
		# Synergy — Dash Breaker: الاندفاع يطلق موجة صادمة (مؤجّل لأمان الحلقة)
		if syn_active.has("dash_breaker"):
			pending_aoe.append({"pos": Vector2(pp), "r": 122.0, "dmg": maxf(10.0, bullet_dmg * 1.0)})
			if rings.size() < 26:
				rings.append({"pos": Vector2(pp), "t": 0.0, "max": 122.0, "col": Balance.COL_YOU_HI})
			_burst(pp, Balance.COL_YOU_HI, 14)
	var spd := pspeed * (3.4 if dash_t > 0.0 else (1.25 if burst_spd_t > 0.0 else 1.0))
	if closecall_t > 0.0:
		spd *= 1.0 + 0.08 * float(ups_count.get("closecall", 0))   # باف المراوغة
	if berserk_t > 0.0:
		spd *= 1.25   # Berserk الفارس
	# v1.2.5: بطء أثناء أولتيمت الرشاش الثقيل / السيف العملاق
	if r_buff_t > 0.0 and sig == "rifle":
		spd *= 0.82
	if r_buff_t > 0.0 and sig == "spinblade":
		spd *= 0.90
	if q_firetrail_t > 0.0:
		spd *= 1.10   # Fire Trail
	if theme_idx() == 2:
		spd *= 0.75   # الجليد بيبطّئ الحركة بجد
	if freeze_t > 0.0:
		mv = Vector2.ZERO   # متجمّد — الحركة مشلولة لحظياً
	is_moving = mv != Vector2.ZERO   # للـ Momentum synergy
	# v1.1.4: سرعة اللاعب الملسّاة — أساس التوقع (predictive AI) للأعداء الأذكياء
	pvel = pvel.lerp((mv.normalized() * spd) if mv != Vector2.ZERO else Vector2.ZERO, minf(1.0, 8.0 * dt))
	if mv != Vector2.ZERO:
		pp += mv.normalized() * spd * dt
		if DBG_INPUT:
			print("MOVE ", mv, " pp=", pp)
		trail.append({"pos": pp, "life": 0.35 if dash_t > 0.0 else 0.18})
		if trail.size() > 48:
			trail.remove_at(0)
	pp.x = clampf(pp.x, PR, WW - PR)
	pp.y = clampf(pp.y, PR, WH - PR)
	# الكاميرا تتبع اللاعب داخل حدود العالم
	var ct := Vector2(clampf(pp.x, W * 0.5, WW - W * 0.5), clampf(pp.y, H * 0.5, WH - H * 0.5))
	cam.position = cam.position.lerp(ct, minf(1.0, 10.0 * dt))

	orbit_ang += dt * (5.2 if evo_cyclone else 3.2) * (1.6 if berserk_t > 0.0 else 1.0)
	# قياسات المعايرة: نافذة أعلى DPS + مدة معركة الزعيم
	dps_bucket_t += dt
	if dps_bucket_t >= 1.0:
		stat_max_dps = maxf(stat_max_dps, dps_bucket)
		dps_bucket = 0.0
		dps_bucket_t = 0.0
	if boss_alive:
		boss_fight_t += dt
		_boss_pressure(dt)   # v1.1.3: توابع + مضاد التبعيد + مخاطر (الساحة مش فاضية)
	# مؤقّتات أنظمة العلاج المقيّد (v1.1)
	no_dmg_t += dt
	wound_t = maxf(0.0, wound_t - dt)
	vamp_cd = maxf(0.0, vamp_cd - dt)
	shatter_cd = maxf(0.0, shatter_cd - dt)
	plating_t = maxf(0.0, plating_t - dt)
	plating_cd = maxf(0.0, plating_cd - dt)
	burst_spd_t = maxf(0.0, burst_spd_t - dt)
	bbreak_t = maxf(0.0, bbreak_t - dt)
	guard_cd = maxf(0.0, guard_cd - dt)
	closecall_t = maxf(0.0, closecall_t - dt)
	frost_burst_cd = maxf(0.0, frost_burst_cd - dt)
	# --- v1.2: مؤقّتات القدرات وأسلحة التوقيع ---
	q_cd = maxf(0.0, q_cd - dt)
	g_dmg_t = maxf(0.0, g_dmg_t - dt)
	g_crit_t = maxf(0.0, g_crit_t - dt)
	g_rate_t = maxf(0.0, g_rate_t - dt)
	roll_anim_t = maxf(0.0, roll_anim_t - dt)
	berserk_t = maxf(0.0, berserk_t - dt)
	# v1.2.3/1.2.5: مؤقّتات الأولتيمت
	r_cd = maxf(0.0, r_cd - dt)
	r_active_t = maxf(0.0, r_active_t - dt)
	r_buff_t = maxf(0.0, r_buff_t - dt)
	r_fate_t = maxf(0.0, r_fate_t - dt)
	if r_fate_t <= 0.0:
		r_fate_mul = 1.0
	if slash_fx.size() > 0:
		var sfi := slash_fx.size() - 1
		while sfi >= 0:
			slash_fx[sfi]["life"] = float(slash_fx[sfi]["life"]) - dt
			if float(slash_fx[sfi]["life"]) <= 0.0:
				slash_fx.remove_at(sfi)
			sfi -= 1
	_fireball_step(dt)                 # كرات Fireball الطايرة (Pyromancer)
	_shadow_assault_step(dt)           # Shadow Assault الجاري (Shinobi Q)
	_rift_step(dt)                     # Judgement Rift الجاري (Shinobi R)
	# شحنات داش الشينوبي بتتشحن واحدة واحدة (v1.2a: أسرع 18% — الداش هو الهوية)
	if sig == "crescent" and dash_charges < dash_charges_max:
		dash_recharge_t -= dt
		if dash_recharge_t <= 0.0:
			dash_charges += 1
			if dash_charges < dash_charges_max:
				dash_recharge_t = dash_cd_max * 0.82
	# ضربة الداش (سلاح الشينوبي): كل عدو بيتقطع مرة واحدة لكل داش (v1.2a: ×1.65)
	if sig == "crescent" and dash_t > 0.0:
		for di in range(enemies.size() - 1, -1, -1):
			var de = enemies[di]
			if int(de.get("dashhit", -1)) != dash_id and Vector2(de["pos"]).distance_to(pp) < 40.0 + float(de["r"]):
				de["dashhit"] = dash_id
				damage_enemy(di, bullet_dmg * 1.65 * _sigm(), "dash")
	# v1.2.3: منع الشينوبي من الوقوف داخل جسم عدو (طلّعه لمسافة آمنة لو انتهى الداش جوه hitbox)
	if sig == "crescent" and dash_t <= 0.0 and enemies.size() > 0:
		var un := _nearest_enemy()
		if un >= 0:
			var ev := pp - Vector2(enemies[un]["pos"])
			var evl := ev.length()
			var need := float(enemies[un]["r"]) + PR - 2.0
			if evl < need and evl > 0.01:
				pp = Vector2(enemies[un]["pos"]) + ev / evl * (need + 3.0)
				pp.x = clampf(pp.x, PR, WW - PR)
				pp.y = clampf(pp.y, PR, WH - PR)
	# Fire Trail (قدرة الهالة): بقع نار خلفك + سرعة
	if q_firetrail_t > 0.0:
		q_firetrail_t -= dt
		if fire_patches.size() < 46:
			fire_patches.append({"pos": Vector2(pp), "life": 3.0})
	if fire_patches.size() > 0:
		var fpi := fire_patches.size() - 1
		while fpi >= 0:
			var fpp = fire_patches[fpi]
			fpp["life"] = float(fpp["life"]) - dt
			if float(fpp["life"]) <= 0.0:
				fire_patches.remove_at(fpi)
			else:
				for ef2 in enemies:
					if Vector2(ef2["pos"]).distance_squared_to(fpp["pos"]) <= 42.0 * 42.0:
						ef2["burn_dps"] = minf(26.0, float(ef2.get("burn_dps", 0.0)) + 14.0 * dt)
						ef2["burn_t"] = 2.0
			fpi -= 1
	# تورريت الجندي: بيرمي أقرب عدو (50% ضرر) والأعداء القريبة بتنجذب له (في الـ AI)
	if q_turret != null:
		q_turret["t"] = float(q_turret["t"]) - dt
		q_turret["cd"] = float(q_turret["cd"]) - dt
		if float(q_turret["t"]) <= 0.0:
			_burst(Vector2(q_turret["pos"]), Color(0.7, 0.75, 0.65), 10)
			q_turret = null
		elif float(q_turret["cd"]) <= 0.0 and enemies.size() > 0:
			var tb := -1
			var tbd := INF
			for ti3 in enemies.size():
				var d3: float = Vector2(enemies[ti3]["pos"]).distance_squared_to(q_turret["pos"])
				if d3 < tbd:
					tbd = d3
					tb = ti3
			if tb >= 0 and tbd < 520.0 * 520.0:
				var tdir2 := (Vector2(enemies[tb]["pos"]) - Vector2(q_turret["pos"])).normalized()
				bullets.append({"pos": Vector2(q_turret["pos"]), "vel": tdir2 * bullet_speed, "life": 1.0, "pierce": 0, "bounce": 0, "side": true, "exec": false})
				Audio.play_sfx("shoot", -14.0, 0.8, 0.9)
			q_turret["cd"] = 0.5
	# --- v1.2 B/C: الأسلحة الجانبية ---
	# Kunai: خناجر مخترقة نحو أقرب عدو (سلاح المدى التعويضي لشخصيات الالتحام)
	var klv := int(ups_count.get("kunai", 0))
	if klv > 0:
		kunai_cd -= dt
		if kunai_cd <= 0.0 and enemies.size() > 0:
			var kn2 := _nearest_enemy()
			if kn2 >= 0:
				var kdir := (Vector2(enemies[kn2]["pos"]) - pp).normalized()
				var knives := 1 + (1 if klv >= 3 else 0)
				var kpierce := (1 if klv >= 2 else 0) + int(ups_count.get("precision", 0)) + (99 if evo_bladestorm else 0)
				for kk in knives:
					var kv := kdir.rotated((float(kk) - float(knives - 1) * 0.5) * 0.14) * bullet_speed * 1.05
					bullets.append({"pos": pp, "vel": kv, "life": 0.9, "pierce": kpierce, "bounce": 0,
						"side": false, "exec": false, "kunai": true, "dmg": bullet_dmg * (0.7 + 0.08 * float(klv))})
				Audio.play_sfx("shoot", -13.0, 1.4, 1.55)
			kunai_cd = maxf(0.45, (1.15 - 0.15 * float(klv))) * _cdr()
	# Frost Orb: كرة صقيع بتدور حواليك — إبطاء + ضرر خفيف مستمر (Eternal Winter: تجميد وجيز)
	var flv := int(ups_count.get("frostorb", 0))
	if flv > 0:
		forb_ang += dt * 1.4
		var fob := pp + Vector2(cos(forb_ang), sin(forb_ang)) * 115.0
		var fzr := (30.0 + 7.0 * float(flv)) * _area() * (1.5 if evo_ewinter else 1.0)
		var fzr2 := fzr * fzr
		var fdps := (6.0 + 3.0 * float(flv))
		for fe in enemies:
			if Vector2(fe["pos"]).distance_squared_to(fob) <= fzr2:
				fe["slow"] = maxf(float(fe.get("slow", 0.0)), 0.5)
				fe["hp"] = float(fe["hp"]) - fdps * dt * (0.5 if String(fe["type"]) == "boss" else 1.0)
				stat_dmg_dealt += fdps * dt
				dps_bucket += fdps * dt
				# التطوّر: تجميد 0.5ث بحصانة 4ث لكل عدو (مفيش permalock)
				if evo_ewinter and String(fe["type"]) != "boss" and float(fe.get("frz_im", 0.0)) <= 0.0:
					fe["frz_t"] = 0.5
					fe["frz_im"] = 4.0
		# جولة قتل آمنة لأي حاجة الصقيع خلّصها
		for fi2 in range(enemies.size() - 1, -1, -1):
			if float(enemies[fi2]["hp"]) <= 0.0 and String(enemies[fi2]["type"]) != "boss":
				kill_src = "frost"
				_kill_enemy(fi2)
				kill_src = ""
	# Bomb Launcher: قنبلة مقذوفة على أقرب تجمّع — انفجار مساحة (Lv4: أرض مشتعلة)
	var blv := int(ups_count.get("bomb", 0))
	if blv > 0:
		bomb_cd -= dt
		if bomb_cd <= 0.0 and enemies.size() > 0:
			var bn2 := _nearest_enemy()
			if bn2 >= 0:
				var btgt: Vector2 = enemies[bn2]["pos"]
				if btgt.distance_to(pp) > 380.0:
					btgt = pp + (btgt - pp).normalized() * 380.0
				bombs.append({"pos": Vector2(pp), "tgt": btgt, "t": 0.5})
				Audio.play_sfx("shoot", -12.0, 0.6, 0.65)
			bomb_cd = maxf(1.5, 2.9 - 0.35 * float(blv)) * _cdr()
	if bombs.size() > 0:
		var bi2 := bombs.size() - 1
		while bi2 >= 0:
			var bb = bombs[bi2]
			bb["t"] = float(bb["t"]) - dt
			bb["pos"] = Vector2(bb["pos"]).lerp(Vector2(bb["tgt"]), clampf(1.0 - float(bb["t"]) / 0.5, 0.0, 1.0))
			if float(bb["t"]) <= 0.0:
				var brad := (70.0 + 10.0 * float(blv)) * _area()
				var bdmg := bullet_dmg * (0.9 + 0.25 * float(blv)) * (1.0 + 0.20 * float(ups_count.get("gpow", 0)))
				pending_aoe.append({"pos": Vector2(bb["tgt"]), "r": brad, "dmg": bdmg})
				_burst(Vector2(bb["tgt"]), Color(1.0, 0.5, 0.15), 14)
				if rings.size() < 26:
					rings.append({"pos": Vector2(bb["tgt"]), "t": 0.0, "max": brad, "col": Color(1.0, 0.55, 0.15)})
				Audio.play_sfx("explode", -7.0)
				if blv >= 4 and fire_patches.size() < 44:
					fire_patches.append({"pos": Vector2(bb["tgt"]), "life": 2.5})
				bombs.remove_at(bi2)
			bi2 -= 1
	# Meteor Fall (تطوّر القاذف): نيزك صديق بتحذير دايرة ذهبية ثم انفجار كبير + حريق
	if evo_meteor:
		fmeteor_cd -= dt
		if fmeteor_cd <= 0.0 and enemies.size() > 0:
			var mn2 := _nearest_enemy()
			if mn2 >= 0:
				fmeteors.append({"pos": Vector2(enemies[mn2]["pos"]), "t": 1.0})
			fmeteor_cd = 6.5 * _cdr()
	if fmeteors.size() > 0:
		var mi2 := fmeteors.size() - 1
		while mi2 >= 0:
			var fm = fmeteors[mi2]
			fm["t"] = float(fm["t"]) - dt
			if float(fm["t"]) <= 0.0:
				var mrad := 120.0 * _area()
				pending_aoe.append({"pos": Vector2(fm["pos"]), "r": mrad, "dmg": bullet_dmg * 3.0 * (1.0 + 0.20 * float(ups_count.get("gpow", 0)))})
				for mk2 in 3:
					if fire_patches.size() < 44:
						fire_patches.append({"pos": Vector2(fm["pos"]) + Vector2(rng.randf_range(-40, 40), rng.randf_range(-40, 40)), "life": 2.5})
				_burst(Vector2(fm["pos"]), Color(1.0, 0.6, 0.2), 22)
				shake = maxf(shake, 6.0)
				Audio.play_sfx("explode", -4.0, 0.7, 0.75)
				fmeteors.remove_at(mi2)
			mi2 -= 1
	# نسخة الشينوبي: 3 اندفاعات قطع (25% ضرر) ثم دخان
	if q_clone != null:
		q_clone["t"] = float(q_clone["t"]) - dt
		if float(q_clone["t"]) <= 0.0:
			if int(q_clone["dashes"]) <= 0:
				_burst(Vector2(q_clone["pos"]), Color(0.55, 0.9, 0.7), 14)
				q_clone = null
			else:
				q_clone["dashes"] = int(q_clone["dashes"]) - 1
				q_clone["t"] = 0.55
				var cb := -1
				var cbd := INF
				for ci2 in enemies.size():
					var d4: float = Vector2(enemies[ci2]["pos"]).distance_squared_to(q_clone["pos"])
					if d4 < cbd and d4 < 460.0 * 460.0:
						cbd = d4
						cb = ci2
				if cb >= 0:
					var from2: Vector2 = q_clone["pos"]
					var to3: Vector2 = enemies[cb]["pos"]
					var new_p := to3 + (to3 - from2).normalized() * 46.0
					for ci3 in range(enemies.size() - 1, -1, -1):
						var ce = enemies[ci3]
						var cp := Geometry2D.get_closest_point_to_segment(Vector2(ce["pos"]), from2, new_p)
						if cp.distance_to(Vector2(ce["pos"])) < 34.0 + float(ce["r"]):
							damage_enemy(ci3, bullet_dmg * 1.65 * 0.30, "clone")
					q_clone["pos"] = new_p
					trail.append({"pos": new_p, "life": 0.3})
					Audio.play_sfx("dash", -10.0, 1.2, 1.3)
	# Thunder Loop: الضربة العاصفية المؤجّلة (بأمان خارج حلقات القتال)
	if thunder_pending:
		thunder_pending = false
		if chain_n > 0 and enemies.size() > 0:
			_do_chain()
	# Frost Trail: أثناء الداش سيب بقع صقيع، وبطّئ اللي يعدّي عليها
	var ftr := int(ups_count.get("frtrail", 0))
	if ftr > 0 and dash_t > 0.0 and frost_trail.size() < 44:
		frost_trail.append({"pos": Vector2(pp), "life": 2.0})
	if frost_trail.size() > 0:
		var fr2 := (34.0 + 10.0 * float(ftr)) * (1.4 if evo_frostrun else 1.0)   # تطوّر: أثر أوسع
		var fr2sq := fr2 * fr2
		var fslow := 0.5 if evo_frostrun else 0.3
		var fi := frost_trail.size() - 1
		while fi >= 0:
			var fp = frost_trail[fi]
			fp["life"] = float(fp["life"]) - dt
			if float(fp["life"]) <= 0.0:
				frost_trail.remove_at(fi)
			else:
				for ef in enemies:
					if String(ef["type"]) != "boss" and Vector2(ef["pos"]).distance_squared_to(fp["pos"]) <= fr2sq:
						ef["slow"] = maxf(float(ef.get("slow", 0.0)), fslow)
			fi -= 1
	# Recovery (Calibration v1.1.1): بعد 6ث بلا ضرر، 1 HP كل 3ث — الرُتب بترفع السقوف مش السرعة
	# (سقف المرحلة وسقف الـ50-55% صحة جوّه _heal)
	if regen_n > 0 and no_dmg_t >= 6.0 and not boss_alive:
		_heal(dt / 3.0, "regen")
	if chain_n > 0:
		chain_t -= dt
		if chain_t <= 0.0:
			_do_chain()

	if not boss_alive:
		_spawn_step(dt)
	_bs(); _enemy_step(dt); _be("enemy")
	_bs(); _ebullet_step(dt); _be("ebullet")
	_bs(); _hazard_step(dt); _be("hazard")
	_bs(); _fire_step(dt); _be("fire")
	_bs(); _bullet_step(dt); _be("bullet")
	_bs(); _orbit_step(dt); _be("orbit")
	_synergy_step(dt)
	_bs(); _aura_step(dt); _be("aura")
	_bs(); _gem_step(dt); _be("gem")
	_bs(); _part_step(dt); _be("part")
	# ضربات المنطقة المؤجّلة (synergies) — تُطبّق الآن خارج أي حلقة أعداء
	if pending_aoe.size() > 0:
		for a in pending_aoe:
			_aoe_damage(a["pos"], float(a["r"]), float(a["dmg"]))
		pending_aoe.clear()

	shake = maxf(0.0, shake - dt * 22.0)
	flash = maxf(0.0, flash - dt * 2.5)
	wipe_t = maxf(0.0, wipe_t - dt * 1.6)
	vacuum_t = maxf(0.0, vacuum_t - dt)
	# الكومبو ينتهي بعد 3 ثواني بلا قتل
	if combo_t > 0.0:
		combo_t -= dt
		if combo_t <= 0.0:
			combo = 0
	# الأحداث العشوائية (مش وقت الزعيم)
	if not boss_alive:
		event_t -= dt
		if event_t <= 0.0:
			_fire_event()
			event_t = rng.randf_range(38.0, 60.0)
	_meteor_step(dt)
	# فخاخ الفصول — دايماً شغالة
	var ti2 := theme_idx()
	if ti2 >= 1:
		trap_t -= dt / asc_trap   # Danger IV+: الفخاخ تيجي أسرع
		if trap_t <= 0.0:
			_tip("trap", "Warning zones flash before they strike — dash out!", 3.0)
			match ti2:
				1:
					# دايرة 10 أشواك حواليك — الداش هو المخرج الوحيد
					for k in 10:
						var ra := TAU * float(k) / 10.0
						traps.append({"k": "spike", "pos": pp + Vector2(cos(ra), sin(ra)) * 96.0, "warn": 1.0, "act": 0.9, "sprung": false})
					Audio.play_sfx("hit", -4.0, 0.6, 0.7)
					trap_t = rng.randf_range(3.4, 4.8)
				2:
					# الجليد: منطقة تجميد تحتك + وابل أشواك ثلجية
					traps.append({"k": "freeze", "pos": Vector2(pp), "warn": 1.0, "sprung": false})
					for k in 4:
						var ip := pp + Vector2(rng.randf_range(-220, 220), rng.randf_range(-170, 170))
						ip.x = clampf(ip.x, 40, WW - 40)
						ip.y = clampf(ip.y, 40, WH - 40)
						traps.append({"k": "spike", "pos": ip, "warn": 0.9, "act": 0.9, "sprung": false, "ice": true})
					trap_t = rng.randf_range(4.2, 6.0)
				3:
					# البركان: نيازك بتنزل دايماً فوق النار الأرضية
					for k in 6:
						var mpos2 := pp + Vector2(rng.randf_range(-380, 380), rng.randf_range(-260, 260))
						mpos2.x = clampf(mpos2.x, 60, WW - 60)
						mpos2.y = clampf(mpos2.y, 60, WH - 60)
						meteors.append({"pos": mpos2, "t": 0.9 + float(k) * 0.3})
					trap_t = rng.randf_range(5.0, 7.0)
				_:
					# الفراغ: كل فخاخ العوالم مرة واحدة — طول الفصل
					for k in 6:
						var ra2 := TAU * float(k) / 6.0
						traps.append({"k": "spike", "pos": pp + Vector2(cos(ra2), sin(ra2)) * 96.0, "warn": 1.0, "act": 0.9, "sprung": false})
					traps.append({"k": "freeze", "pos": Vector2(pp), "warn": 1.1, "sprung": false})
					for k in 4:
						var bp3 := pp + Vector2(rng.randf_range(-320, 320), rng.randf_range(-240, 240))
						bp3.x = clampf(bp3.x, 40, WW - 40)
						bp3.y = clampf(bp3.y, 40, WH - 40)
						traps.append({"k": "burn", "pos": bp3, "perm": false, "life": 4.0})
					for k in 3:
						meteors.append({"pos": pp + Vector2(rng.randf_range(-300, 300), rng.randf_range(-220, 220)), "t": 1.0 + float(k) * 0.35})
					Audio.play_sfx("boss", -8.0)
					_toast(T("The Void summons the traps of all realms!"), 1.8)
					trap_t = rng.randf_range(5.5, 8.0)
	_trap_step(dt)
	if freeze_t > 0.0:
		freeze_t -= dt
	if shake > 0.0 and shake_on:
		cam.offset = Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake))
	else:
		cam.offset = Vector2.ZERO

	if hp <= 0.0:
		if revive_ready:
			_do_revive()
		else:
			_game_over()
	_update_hud()

# بوت المعايرة: اهرب من التهديدات القريبة، والتقط الجواهر لو الساحة آمنة
# (مستوى لعبه أقل من إنسان متمرّس — بياخد باله من التلامس مش من أنماط الزعماء)
func _bot_move() -> Vector2:
	var flee := Vector2.ZERO
	for e in enemies:
		var d: Vector2 = pp - Vector2(e["pos"])
		var dist := maxf(d.length(), 1.0)
		var danger_r := 240.0 + float(e["r"]) * 2.0
		var wgt := 1.0
		var et := String(e["type"])
		if et == "boss":
			wgt = 2.5
		elif et == "bomber":
			wgt = 2.2   # زي اللاعب البشري: القنبلة أولوية هروب قصوى
			danger_r += 60.0
		flee += (d / dist) * maxf(0.0, (danger_r - dist) / danger_r) * wgt
	for b in ebullets:
		var db: Vector2 = pp - Vector2(b["pos"])
		var distb := maxf(db.length(), 1.0)
		if distb < 130.0:
			flee += (db / distb) * 1.1
	for tp in traps:
		var dtp: Vector2 = pp - Vector2(tp["pos"])
		var distt := maxf(dtp.length(), 1.0)
		if distt < 110.0:
			flee += (dtp / distt) * 1.3
	for mt in meteors:
		var dmt: Vector2 = pp - Vector2(mt["pos"])
		var distm := maxf(dmt.length(), 1.0)
		if distm < 120.0:
			flee += (dmt / distm) * 1.4
	for hz in hazards:
		var dhz: Vector2 = pp - Vector2(hz["pos"])
		var disth := maxf(dhz.length(), 1.0)
		if disth < float(hz["r"]) + 50.0:
			flee += (dhz / disth) * 1.2
	bot_dash = flee.length() > 2.4   # زحمة خطيرة → داش للخروج
	var want := flee
	# v1.2: شخصيات الالتحام — البوت لازم يقرّب من الأعداء وإلا سلاحه ما يشتغلش
	# (بيوازن: هجوم نحو أقرب عدو + نصف نفور — والشينوبي بيقطع بالداش)
	if (sig == "crescent" or sig == "spinblade" or sig == "shockwave") and hp > maxhp * 0.45:
		var nb2 := _nearest_enemy()
		if nb2 >= 0:
			var atk_v := (Vector2(enemies[nb2]["pos"]) - pp)
			var nbb := String(enemies[nb2]["type"]) == "boss"
			# تحذير الصفعة ظاهر؟ اهرب فوراً (زي اللاعب البشري)
			if nbb and float(enemies[nb2].get("punish_warn", 0.0)) > 0.0:
				return -atk_v.normalized() * 2.2 + (WC - pp) * 0.0012
			# حوم على مسافة سلاحك بدل الدهس جوه جسم الهدف
			var hold := 90.0 + float(enemies[nb2]["r"])
			if sig == "shockwave":
				hold = 120.0 + float(enemies[nb2]["r"])
			elif sig == "crescent":
				hold = 58.0 + float(enemies[nb2]["r"])   # مدى السلاش ~92 — البوت يقف داخله ويقطع
			elif sig == "spinblade":
				hold = 55.0 + float(enemies[nb2]["r"])   # السيوف مداها 72px — لازم يقرّب كفاية
			if atk_v.length() > hold:
				want = atk_v.normalized() * 1.4 + flee * 0.55
			else:
				want = Vector2(-atk_v.y, atk_v.x).normalized() * 1.2 + flee * 0.6
			if sig == "crescent" and atk_v.length() < 280.0 and dash_charges > 1:
				bot_dash = true
			return want + (WC - pp) * 0.0012
	if flee.length() < 0.35:
		# آمن — أقرب جوهرة
		var best := -1
		var bd := INF
		for i in gems.size():
			var d2: float = Vector2(gems[i]["pos"]).distance_squared_to(pp)
			if d2 < bd:
				bd = d2
				best = i
		if best >= 0:
			want = Vector2(gems[best]["pos"]) - pp
	want += (WC - pp) * 0.0012   # ميل خفيف للمركز (تجنّب الحشر في الأركان)
	return want

# ================================================================
#  DIFFICULTY / SPAWNING  (توازن: تصعيد بالمرحلة + داخل الدقيقة)
func _hp_mul() -> float:
	# روج-لايك: الأعداء يقووا بالمرحلة + داخل الدقيقة + مع كل Level Up للاعب
	# (معامل المستوى خفيف عشان ترقياتك تحس بقوتها — power fantasy)
	var ramp := (STAGE_LEN - stage_timer) / STAGE_LEN
	var lvl_mul := 1.0 + 0.07 * float(level - 1)   # معايرة: 0.08 كانت بتبلع قيمة ترقيات الضرر
	# v1.1: منحنى أصعب — المرحلة 1 تعليمية، من 2 الضغط حقيقي، و4-5 شبه مستحيلة بلا ترقيات دائمة
	return (1.0 + 0.62 * (stage - 1)) * (1.0 + 0.22 * ramp) * lvl_mul * asc_hp

func _dmg_mul() -> float:
	return (1.0 + 0.10 * (stage - 1)) * (1.0 + 0.03 * float(level - 1)) * asc_dmg

# سرعة الأعداء: منحنى تدريجي بالمرحلة (Calibration v1.1.1) — 1.00 → 1.30
func _spd_mul() -> float:
	return float(Balance.ENEMY_SPD_STAGE[clampi(stage - 1, 0, Balance.ENEMY_SPD_STAGE.size() - 1)])

# Anti-stall (v1.1.3): لو وصلت المرحلة 3-4 ومستواك متأخر، XP إضافي لحد ما تلحق —
# بيساعد اللاعب المتعثّر يكمل من غير ما يقوّي اللاعب الشاطر (Feedback: "علقت عند مستوى 10")
func _xp_catchup() -> float:
	if stage >= 4 and level < 14:
		return 1.10
	if stage == 3 and level < 12:
		return 1.12
	return 1.0

# ضغط ساحة الزعيم (v1.1.3) — يشتغل مرة واحدة عالمياً (مش لكل زعيم) أثناء المعركة:
# 1) موجات توابع خفيفة تملى الساحة  2) مضاد التبعيد  3) مخاطر أرضية متوقّعة
func _boss_pressure(dt: float) -> void:
	var bnear := -1
	var bd := INF
	var enraged := false
	for i in enemies.size():
		if String(enemies[i]["type"]) == "boss":
			var d: float = Vector2(enemies[i]["pos"]).distance_to(pp)
			if d < bd:
				bd = d
				bnear = i
			if int(enemies[i].get("phase", 1)) == 2 or bool(enemies[i].get("reborn", false)):
				enraged = true
	if bnear < 0:
		return
	# 1) موجة توابع صغيرة كل 12-18ث (9-13 في الغضب = ضغط الطور الثاني) — سقف أعداء يمنع الفوضى
	# (معايرة: توابع هشة جداً وعددها أقل بدري — الضغط يملى الساحة مش يطوّل المعركة)
	boss_minion_t -= dt
	if boss_minion_t <= 0.0:
		if enemies.size() < 38:
			var n := 2 + stage / 2
			for k in n:
				var mhp := 12.0 * _hp_mul() * 0.55
				enemies.append({"pos": _edge_pos(), "col": Balance.ENEMY_PAL[1], "r": 10.0,
					"hp": mhp, "maxhp": mhp, "spd": rng.randf_range(95.0, 120.0), "type": "fast", "orbcd": 0.0})
		boss_minion_t = rng.randf_range(9.0, 13.0) if enraged else rng.randf_range(12.0, 18.0)
	# 2) مضاد التبعيد (v1.1.4): بعيد عن الزعيم 4ث متواصلة ⇒ ردّ حسب شخصية الزعيم
	if bd > 470.0:
		boss_kite_t += dt
		if boss_kite_t >= 4.0:
			boss_kite_t = 0.0
			var bp2: Vector2 = enemies[bnear]["pos"]
			var bcol2 := Color(enemies[bnear]["col"]).lightened(0.2)
			match int(enemies[bnear].get("kind", 0)):
				0:  # حارس المرج (تعليمي): توابع مطارِدة خفيفة — أنعم رد
					if enemies.size() < 38:
						for k in 2:
							var mhp2 := 10.0 * _hp_mul() * 0.55
							enemies.append({"pos": _edge_pos_toward(pp - bp2), "col": Balance.ENEMY_PAL[0],
								"r": 10.0, "hp": mhp2, "maxhp": mhp2, "spd": 105.0, "type": "norm", "orbcd": 0.0})
					Audio.play_sfx("boss", -10.0, 1.2, 1.3)
				2:  # قلب الجليد (تحكّم مساحة): منطقة تجميد متلغرفة تحت اللاعب
					traps.append({"k": "freeze", "pos": Vector2(pp), "warn": 1.1, "sprung": false})
					Audio.play_sfx("zap", -10.0, 0.6, 0.7)
				3:  # وحش الحمم (عنيف): اندفاعة نحوك — بوميض تلغراف 0.5ث الأول
					enemies[bnear]["dashwarn"] = 0.5
				_:  # ملك العظام/ظل الفراغ/الملك: رشقة مطارِدة كلاسيكية
					var kn := 3 if stage >= 3 else 2
					for k in kn:
						var a := TAU * float(k) / float(kn)
						_ebullet(bp2 + Vector2(cos(a), sin(a)) * 30.0, (pp - bp2).normalized() * 160.0, bcol2, true)
					Audio.play_sfx("zap", -9.0, 0.7, 0.8)
	else:
		boss_kite_t = 0.0
	# 3) مخاطر أرضية بتحذير واضح (تلغراف النيازك الموجود) — أخف في المراحل 1-2
	boss_haz_t -= dt
	if boss_haz_t <= 0.0:
		var hz_n := 2 if stage >= 3 else 1
		for k in hz_n:
			var hp3 := pp + Vector2(rng.randf_range(-220, 220), rng.randf_range(-160, 160))
			hp3.x = clampf(hp3.x, 60, WW - 60)
			hp3.y = clampf(hp3.y, 60, WH - 60)
			meteors.append({"pos": hp3, "t": 1.15 + float(k) * 0.3})
		boss_haz_t = rng.randf_range(8.0, 12.0) if enraged else rng.randf_range(10.0, 15.0)

func _elite_chance() -> float:
	# النخبة: 5% في الفصل 1، حضور قوي في 4-5 (~45%) لكن مش الأغلبية الفوضوية
	return clampf(0.05 + 0.12 * float(stage - 1) + asc_elite, 0.0, 0.45)

# اختيار نوع العدو حسب مزيج المرحلة (كل مرحلة إحساس/تهديد مختلف)
func _pick_enemy_type() -> String:
	var elapsed := STAGE_LEN - stage_timer
	# أول 14ث في المرحلة الأولى: مطاردون فقط (تعليم الأساسيات)
	if stage == 1 and elapsed < 14.0:
		return "norm"
	var mix: Dictionary = (Balance.STAGE_MIX[clampi(stage - 1, 0, Balance.STAGE_MIX.size() - 1)] as Dictionary).duplicate()
	# Danger II+: رماة أكتر · Danger IV+: قنابل أكتر (قواعد مش أرقام)
	if asc >= 2:
		mix["shooter"] = int(mix.get("shooter", 0)) + 8
	if asc >= 4:
		mix["bomber"] = int(mix.get("bomber", 0)) + 6
	var total := 0
	for k in mix:
		total += int(mix[k])
	var r := rng.randi() % maxi(1, total)
	for k in mix:
		r -= int(mix[k])
		if r < 0:
			return k
	return "norm"

func _spawn_step(dt: float) -> void:
	spawn_cd -= dt
	if spawn_cd <= 0.0:
		var batch := 1 + (stage - 1) / 3
		for i in batch:
			_spawn_enemy()
		var ramp := (STAGE_LEN - stage_timer) / STAGE_LEN
		spawn_cd = maxf(0.22, 0.74 - 0.08 * (stage - 1) - 0.30 * ramp) * asc_spawn

func _edge_pos() -> Vector2:
	# الظهور خارج حدود الكاميرا الحالية (الساحة أكبر من الشاشة)
	var cl := cam.position - Vector2(W * 0.5, H * 0.5)
	var side := rng.randi() % 4
	var p := Vector2.ZERO
	match side:
		0: p = cl + Vector2(rng.randf_range(0, W), -45)
		1: p = cl + Vector2(rng.randf_range(0, W), H + 45)
		2: p = cl + Vector2(-45, rng.randf_range(0, H))
		_: p = cl + Vector2(W + 45, rng.randf_range(0, H))
	return p

func _spawn_enemy() -> void:
	# النخبة: زعيم صغير — احتماله يتصاعد، مع سقف عدد متزامن عشان توازن
	var elite_count := 0
	for e0 in enemies:
		if String(e0["type"]) == "elite":
			elite_count += 1
	var elite_cap := 2 + stage / 2
	if rng.randf() < _elite_chance() and elite_count < elite_cap:
		var ehp := 145.0 * _hp_mul()
		var espd := 46.0 * _spd_mul()
		var er2 := 27.0
		# معدّلات النخبة (من م3): مدرّعة / سريعة / منقسمة
		var emod := ""
		if stage >= 3:
			var mr := rng.randf()
			if mr > 0.80: emod = "shield"
			elif mr > 0.65: emod = "swift"
			elif mr > 0.50: emod = "split"
		match emod:
			"swift": espd *= 1.55; er2 = 22.0; ehp *= 0.8
			"shield": ehp *= 0.9
		var eld := {
			"pos": _edge_pos(), "col": Balance.COL_ENEMY_HI,   # نخبة = برتقالي ساطع (خطر أعلى)
			"r": er2, "hp": ehp, "maxhp": ehp, "spd": espd,
			"type": "elite", "orbcd": 0.0, "atk": rng.randf_range(2.0, 3.2), "mod": emod,
		}
		# v1.1.4: نص النخبة من المرحلة 3 بتهاجم من الجنب (نسخة محسّنة من دورها)
		if stage >= 3 and rng.randf() < 0.5:
			eld["flank"] = 1 if rng.randf() < 0.5 else -1
		enemies.append(eld)
		spawn_cd += 0.45   # النخبة تقيلة — مهلة إضافية
		return
	var type := _pick_enemy_type()
	var r := 14.0; var hpv := 20.0; var spd := rng.randf_range(55.0, 85.0)
	match type:
		"fast":    r = 9.0;  hpv = 12.0;  spd = rng.randf_range(115.0, 145.0)
		"tank":    r = 24.0; hpv = 75.0;  spd = 40.0
		"split":   r = 17.0; hpv = 35.0;  spd = 62.0
		"shooter": r = 14.0; hpv = 34.0;  spd = 66.0
		"bomber":  r = 13.0; hpv = 24.0;  spd = 96.0
	hpv *= _hp_mul()
	spd *= _spd_mul()
	# لون دافئ حسب النوع (الشكل بيفرّق النوع، اللون بيأكّد الخطورة)
	var ecol: Color = Balance.ENEMY_PAL[0]
	match type:
		"fast": ecol = Balance.ENEMY_PAL[1]
		"tank": ecol = Balance.ENEMY_PAL[2]
		"split": ecol = Balance.ENEMY_PAL[3]
		"shooter": ecol = Balance.COL_ENEMY
		"bomber": ecol = Balance.COL_ENEMY_HI
	var ed := {
		"pos": _edge_pos(),
		"col": ecol,
		"r": r, "hp": hpv, "maxhp": hpv, "spd": spd,
		"type": type, "orbcd": 0.0,
	}
	ed["ai_t"] = rng.randf_range(0.0, 0.25)   # v1.2-D: قرارات الـ AI غير متزامنة (توزيع الحمل والحركة)
	if type == "shooter":
		ed["atk"] = rng.randf_range(1.4, 2.6)   # مؤقّت الإطلاق
		ed["sdir"] = 1.0 if rng.randf() < 0.5 else -1.0   # اتجاه الخطوة الجانبية
	# v1.1.4: من المرحلة 3 نسبة من السريعين بيدخلوا Flankers (من الجنب) — أكتر في Danger III+
	if type == "fast" and stage >= 3 and rng.randf() < (0.55 if asc >= 3 else 0.4):
		ed["flank"] = 1 if rng.randf() < 0.5 else -1
	# ضغط جماعي: القنابل والدبابات أحياناً بتظهر قدام مسار حركتك (قطع الطريق)
	if (type == "bomber" or type == "tank") and pvel.length() > 60.0 and rng.randf() < 0.6:
		ed["pos"] = _edge_pos_toward(pvel)
	enemies.append(ed)

# نقطة ظهور على حافة الشاشة في اتجاه حركة اللاعب (لقطع طريق الهروب)
func _edge_pos_toward(dir: Vector2) -> Vector2:
	for i in 6:
		var p := _edge_pos()
		if (p - pp).dot(dir) > 0.0:
			return p
	return _edge_pos()

# ================================================================
#  BOSS  (كل دقيقة: يمسح الأعداء، يوقف المؤقت، نمط هجوم حسب الثيم)
func _spawn_boss() -> void:
	boss_alive = true
	boss_fight_t = 0.0
	boss_minion_t = 8.0; boss_haz_t = 11.0; boss_kite_t = 0.0   # ضغط الساحة v1.1.3
	stage_timer = 0.0
	# مسح كل الأعداء الحاليين
	for e in enemies:
		_burst(e["pos"], Color(1, 1, 1), 6)
	enemies.clear()
	ebullets.clear()
	hazards.clear()
	meteors.clear()
	wipe_t = 1.0
	Audio.play_sfx("sweep", -10.0, 0.9, 0.95)   # Polish: مسحة أهدى بكتير
	var ti := theme_idx()
	var th = THEMES[ti]
	# Calibration v1.1.1: جدول صحة لكل مرحلة (مستهدفات مدة المعركة في balance.gd)
	var hpv := float(Balance.BOSS_HP_STAGE[clampi(stage - 1, 0, Balance.BOSS_HP_STAGE.size() - 1)]) \
		* (1.0 + 0.12 * float(level - 1)) * asc_hp
	var kind := ti
	var bcol: Color = th["boss_col"]
	var bname: String = th["boss_name"]
	var br := 46.0
	# الفصل الأخير: الزعيم النهائي — ملك الرماد
	if stage == FINAL_STAGE:
		kind = 5
		bcol = Color(0.62, 0.35, 0.92)
		bname = "The Ash King"
		br = 58.0
		hpv *= 2.0
	enemies.append({
		"pos": _edge_pos(),
		"col": bcol,
		"r": br, "hp": hpv, "maxhp": hpv, "spd": 53.0 if kind != 3 else 72.0,
		"type": "boss", "orbcd": 0.0,
		"kind": kind, "atk": 1.5, "spiral": 0.0, "charge": 0.0,
		"phase": 1, "atk2": 4.0, "tcd": 0.0, "cyc": 0, "sumt": 3.0, "split_done": false,
	})
	boss_name_cur = bname
	Audio.play_sfx("boss", 2.0)
	shake = 8.0 if kind != 5 else 12.0
	Audio.play_music("b%d" % ti)
	_flash_msg("!! %s !!" % T(bname), 2.2 if kind != 5 else 3.0)
	# دخلة البوس: ومضة + حلقات صدمة متمددة من مركز الشاشة
	wipe_t = maxf(wipe_t, 0.35)
	for ri in 3:
		rings.append({"pos": cam.position, "t": 0.0, "max": 260.0 + ri * 150.0, "col": bcol})

func _show_victory() -> void:
	hitstop = 0.0
	state = ST_VICTORY
	boss_alive = false
	_update_records(true)
	if asc == asc_max and asc_max < ASC_MAX:
		asc_max += 1   # الفوز يفتح مستوى Ascension الجاي
	_award_cinders(true)
	_debug_run_summary(true)   # (معركة الملك اتسجلت في _boss_die قبل النداء)
	var vgot := _check_achievements(true)
	var m := int(gametime) / 60
	var s := int(gametime) % 60
	vic_title.text = T("VICTORY - The Ash King has fallen!")
	vic_stats.text = T("Campaign complete, %s!\n\nKills: %d      Level: %d      Run time: %02d:%02d\nBest combo: x%d") % [T(CHARS[char_sel]["name"]), kills, level, m, s, combo_best]
	vic_stats.text += "\n" + (T("Blessings: %d") % _blessing_count())
	vic_stats.text += "\n" + (T("+%d Cinders   (Total: %d)") % [last_cinders, cinders])
	vic_stats.text += _achievement_lines(vgot)
	vic_stats.text += "\n\n" + T("[Enter] Back to Menu")
	vic_dim.visible = true
	Audio.play_music("menu")

func _boss_die(epos: Vector2) -> void:
	boss_alive = false
	boss_times.append({"name": boss_name_cur, "secs": boss_fight_t})   # لتقرير المعايرة
	boss_fight_t = 0.0
	run_bosses += 1
	ebullets.clear()
	hazards.clear()
	vacuum_t = 2.5
	for k in 14:
		_drop_gem(epos + Vector2(rng.randf_range(-55, 55), rng.randf_range(-55, 55)))
	_heal(25.0, "reward")   # v1.1: مكافأة الزعيم اتقللت (كانت 40) — العلاج مورد نادر
	if steal_n > 0:
		_heal(2.0 + float(steal_n), "steal_boss")   # Soul Steal: قتل الزعيم +3/+4 HP (بديل تعطيله أثناء المعركة)
	shake = 11.0
	# Polish v1.1.2: شيلنا صافرة الانتقال الحادة — رنّة ناعمة منخفضة بدلها
	Audio.play_sfx("levelup", -9.0, 0.72, 0.78)
	_burst(epos, Color(1, 0.85, 0.3), 46)
	# المرحلة الجاية + ثيم جديد + موسيقاه — سقوف علاج المرحلة بتتصفّر هنا
	stage += 1
	stage_timer = STAGE_LEN
	stage_heal_regen = 0.0
	stage_heal_steal = 0.0
	spawn_cd = 1.8   # لحظة هدوء (breathing room) قبل ما تتصاعد المرحلة الجديدة
	boss_warned = false
	fade_a = maxf(fade_a, 0.5)   # نبضة انتقال بين المراحل
	# النصر: سقط ملك الرماد — نهاية الحملة
	if stage > FINAL_STAGE:
		_show_victory()
		return
	Audio.play_music("s%d" % theme_idx())
	_gen_decor()
	var th = THEMES[theme_idx()]
	# بانر انتقال ناعم (fade + انزلاق خفيف) بدل النص الكبير المفاجئ
	stage_intro_t = 2.2
	stage_intro_title = T("Stage %d - %s") % [stage, T(_stage_title())]
	stage_intro_sub = "+25 HP"
	if stage == FINAL_STAGE:
		# الفراغ: بلا وقت — أسياد العوالم قادمون
		stage_timer = 999999.0
		void_intro = 4.5
		stage_intro_sub = T("The Void... something stirs in the dark")
	# v1.1.5: مكافأة الزعيم — اختيار مقصود من 3 (يتعرض فوق بانر المرحلة الجاية)
	_enter_boss_reward()

func _boss_step(e: Dictionary, dt: float) -> void:
	var kind: int = e["kind"]
	var bp: Vector2 = e["pos"]
	# طور الغضب عند نص الصحة: أسرع + هجوم ثانوي جديد (مش للملك — له أطواره)
	if kind != 5 and int(e["phase"]) == 1 and float(e["hp"]) < float(e["maxhp"]) * asc_enrage:
		e["phase"] = 2
		e["spd"] = float(e["spd"]) * 1.25
		e["atk2"] = 1.5
		shake = 7.0
		Audio.play_sfx("boss", 0.0)
		_burst(bp, e["col"], 26)
		_flash_msg(T("%s is enraged!") % T(boss_name_cur), 1.8)
	var enraged := int(e["phase"]) == 2
	# Danger V: إيقاع هجمات الزعيم أسرع (asc_boss_atk > 1)
	e["atk"] = float(e["atk"]) - dt * asc_boss_atk
	e["atk2"] = float(e["atk2"]) - dt * asc_boss_atk
	e["sumt"] = float(e.get("sumt", 3.0)) - dt
	var to := pp - bp
	var d := to.length()
	var kfrac0 := float(e["hp"]) / float(e["maxhp"])
	# --- v1.2-D: طور الدرع (Shell) — عند 75% و40% صحة الزعيم يتقوقع 3ث ---
	# بياخد 20% ضرر فقط، ويرمي وابل دوّار متلغرف، وموجة توابع بتنزل — لحظة إعادة تموضع
	# مش جدار صحة: بتضيف ~6-10ث مقروءة للمعركة بدل ما البناء القوي يذيب الزعيم في ثواني
	var kfsh := float(e["hp"]) / float(e["maxhp"])
	var shq := int(e.get("shell_done", 0))
	# درع تكيفي: لقطة صحة كل 4ث — لو خسر 18%+ من صحته خلال النافذة = بيتذوّب ببناء burst
	# فبيتقوقع (بيعاقب الذوبان اللحظي تحديداً، والبناء البطيء مش بيشوف درعاً زيادة)
	e["shell_cd"] = maxf(0.0, float(e.get("shell_cd", 0.0)) - dt)
	e["hp_snap_t"] = float(e.get("hp_snap_t", 0.0)) - dt
	if float(e["hp_snap_t"]) <= 0.0:
		e["hp_snap_t"] = 4.0
		e["hp_snap"] = float(e["hp"])
	var burst_melt := (float(e.get("hp_snap", e["maxhp"])) - float(e["hp"])) / float(e["maxhp"]) >= 0.18
	var shell_fixed := (shq == 0 and kfsh <= 0.75) or (shq == 1 and kfsh <= 0.40)
	if float(e.get("shell_t", 0.0)) <= 0.0 and float(e["shell_cd"]) <= 0.0 and shq < 4 and (shell_fixed or burst_melt):
		e["shell_t"] = 3.0
		e["shell_done"] = shq + 1
		e["shell_cd"] = 11.0
		e["hp_snap"] = float(e["hp"])
		e["hp_snap_t"] = 4.0
		e["shell_barrage"] = 0.4
		boss_minion_t = minf(boss_minion_t, 0.6)   # الدرع بيجيب معاه موجة توابع
		_toast(T("The boss hardens its shell!"), 1.8)
		shake = maxf(shake, 6.0)
		Audio.play_sfx("boss", -4.0, 0.6, 0.65)
		if rings.size() < 26:
			rings.append({"pos": bp, "t": 0.0, "max": float(e["r"]) + 60.0, "col": Color(0.85, 0.90, 1.0)})
	if float(e.get("shell_t", 0.0)) > 0.0:
		e["shell_t"] = float(e["shell_t"]) - dt
		# وابل دوّار بطيء أثناء الدرع (ضغط مقروء — مش انفجار مفاجئ)
		e["shell_barrage"] = float(e.get("shell_barrage", 0.4)) - dt
		if float(e["shell_barrage"]) <= 0.0:
			e["shell_barrage"] = 0.5
			var sha := float(e.get("spiral", 0.0)) + 0.45
			e["spiral"] = sha
			for shk in 8:
				var sa4 := sha + TAU * float(shk) / 8.0
				_ebullet(bp, Vector2(cos(sa4), sin(sa4)) * 120.0, Color(0.85, 0.90, 1.0))
	# --- v1.1.4 Close Punish (معايرة v1.2): الالتصاق الفعلي بجسم الزعيم بس هو اللي بيتعاقب ---
	# النطاق أضيق من مدى أسلحة الالتحام (هالة 100px / سيوف 72px) — أسلوب الالتحام مشروع،
	# والدهس جوه جسم الزعيم هو الغلط. شخصيات الالتحام كمان ليها مهلة أطول.
	var melee_sig := sig == "crescent" or sig == "spinblade" or sig == "shockwave"
	e["punish_cd"] = maxf(0.0, float(e.get("punish_cd", 0.0)) - dt)
	var pw := float(e.get("punish_warn", 0.0))
	if pw > 0.0:
		pw -= dt
		e["punish_warn"] = pw
		if pw <= 0.0:
			_ring(bp, 10, 150.0, Color(e["col"]).lightened(0.3))
			if invuln <= 0.0 and d < float(e["r"]) + 58.0:
				_hurt(24.0 * _dmg_mul(), "boss slam")
				flash = minf(1.0, flash + 0.5)
				invuln = maxf(invuln, 0.4)
			shake = maxf(shake, 7.0)
			Audio.play_sfx("explode", -5.0, 0.8, 0.9)
			e["punish_cd"] = 9.0 if melee_sig else 6.0
			e["close_t"] = 0.0
	elif d < float(e["r"]) + 42.0 and float(e["punish_cd"]) <= 0.0:
		e["close_t"] = float(e.get("close_t", 0.0)) + dt
		if float(e["close_t"]) >= (2.2 if melee_sig else 1.2):
			e["punish_warn"] = 0.8 if stage <= 1 else 0.6   # المرحلة 1 أرحم (تعليمية)
			Audio.play_sfx("boss", -8.0, 1.4, 1.5)
	else:
		e["close_t"] = maxf(0.0, float(e.get("close_t", 0.0)) - dt)
	# v1.1.4 anti-kite dash (وحش الحمم): وميض تلغراف 0.5ث ثم اندفاعة نحو موقعك المتوقع
	var dw := float(e.get("dashwarn", 0.0))
	if dw > 0.0:
		dw -= dt
		e["dashwarn"] = dw
		e["hitflash"] = 0.09   # بيلمع أبيض طول التحذير
		if dw <= 0.0:
			e["charge"] = 0.7
			Audio.play_sfx("boss", -6.0, 1.3, 1.4)
	# حارس المرج (والملك في طوره الأول): استدعاء درع دائري كل 5ث
	if (kind == 0 or (kind == 5 and (kfrac0 > 0.75 or bool(e.get("reborn", false))))) and float(e["sumt"]) <= 0.0:
		var guards := 0
		for g0 in enemies:
			if g0.get("orbit_host") == e:
				guards += 1
		if guards <= 3:
			for k in 8:
				var ga := TAU * float(k) / 8.0
				var ghp := 22.0 * _hp_mul()
				enemies.append({
					"pos": bp + Vector2(cos(ga), sin(ga)) * 88.0,
					"col": Balance.ENEMY_PAL[0], "r": 13.0, "hp": ghp, "maxhp": ghp,
					"spd": 80.0, "type": "norm", "orbcd": 0.0,
					"orbit_host": e, "orb_a": ga,
				})
			_burst(bp, e["col"], 12)
			Audio.play_sfx("boss", -8.0, 1.2, 1.3)
		e["sumt"] = 4.2
	# ملك العظام (والملك في طوره الثاني): أشواك تحت اللاعب باستمرار
	if (kind == 1 or (kind == 5 and kfrac0 <= 0.75 and kfrac0 > 0.5)) and float(e.get("tcd", 0.0)) <= 0.0:
		traps.append({"k": "spike", "pos": Vector2(pp), "warn": 0.8, "act": 0.9, "sprung": false})
		e["tcd"] = 2.6
	if kind == 1 or kind == 5:
		e["tcd"] = float(e.get("tcd", 0.0)) - dt
	# وحش الحمم (والملك في طوره الأخير/بعثه): هالة حمراء حارقة حواليه
	if kind == 3 or (kind == 5 and (kfrac0 <= 0.25 or bool(e.get("reborn", false)))):
		if invuln <= 0.0 and d < 125.0 + float(e["r"]):
			_hurt(13.0 * _dmg_mul() * dt, "boss aura")
			flash = minf(1.0, flash + dt * 2.0)
	# قلب الجليد: عند نص الصحة ينكسر لاثنين أسرع
	if kind == 2 and not bool(e.get("split_done", false)) and kfrac0 < 0.5:
		e["split_done"] = true
		e["r"] = 32.0
		e["spd"] = float(e["spd"]) * 1.35
		e["hp"] = float(e["maxhp"]) * 0.30
		var twin = e.duplicate(true)
		twin["pos"] = bp + Vector2(rng.randf_range(-80, 80), rng.randf_range(-80, 80))
		twin["spiral"] = float(e["spiral"]) + PI
		enemies.append(twin)
		shake = 9.0
		Audio.play_sfx("bossdie", -4.0, 1.3, 1.3)
		_burst(bp, e["col"], 30)
		_flash_msg(T("Frost Heart shattered in two!"), 1.8)
	# حركة (الملك بيندفع برضه في طور الحمم وبعد البعث)
	if kind == 3 or kind == 5:
		e["charge"] = maxf(0.0, float(e["charge"]) - dt)
		if float(e["charge"]) > 0.0:
			e["pos"] += (to / maxf(d, 0.001)) * 430.0 * dt
			# نار على الأرض وراه دايماً (الحمم / الملك المبعوث)
			if kind == 3 or (kind == 5 and bool(e.get("reborn", false))):
				e["tcd"] = float(e["tcd"]) - dt
				if float(e["tcd"]) <= 0.0:
					hazards.append({"pos": Vector2(e["pos"]), "r": 26.0, "life": 2.4, "dps": 13.0, "col": Color(1.0, 0.35, 0.05)})
					e["tcd"] = 0.09
		else:
			# مطارد دايماً بسرعته الكاملة
			e["pos"] += (to / maxf(d, 0.001)) * float(e["spd"]) * dt
	else:
		if d > 0.001:
			e["pos"] += (to / d) * float(e["spd"]) * dt
	# الهجوم الثانوي (طور الغضب فقط) — مختلف لكل زعيم
	if enraged and kind != 5 and float(e["atk2"]) <= 0.0:
		match kind:
			0:  # حارس المرج: يستدعي 3 توابع
				for k in 3:
					var a0 := rng.randf() * TAU
					var mhp := 16.0 * _hp_mul()
					enemies.append({"pos": bp + Vector2(cos(a0), sin(a0)) * 70.0,
						"col": Balance.ENEMY_PAL[1], "r": 12.0, "hp": mhp, "maxhp": mhp,
						"spd": 95.0, "type": "norm", "orbcd": 0.0})
				_burst(bp, THEMES[0]["boss_col"], 12)
				e["atk2"] = 5.5
			1:  # أفعى الرمال: دوّامة رمل تحت قدميك
				hazards.append({"pos": Vector2(pp), "r": 64.0, "life": 3.2, "dps": 15.0, "col": Color(0.85, 0.62, 0.25)})
				e["atk2"] = 4.0
			2:  # قلب الجليد: نوفا جليدية واسعة
				_ring(bp, 16, 100.0, THEMES[2]["boss_col"])
				e["atk2"] = 6.0
			3:  # وحش الحمم: انفجار بركاني
				_ring(bp, 10, 195.0, Color(1.0, 0.5, 0.1))
				e["atk2"] = 5.0
			_:  # ظل الفراغ: يستدعي شبحين (نخبة)
				if enemies.size() < 45:
					for k in 2:
						var a1 := rng.randf() * TAU
						var php := 90.0 * _hp_mul()
						enemies.append({"pos": bp + Vector2(cos(a1), sin(a1)) * 90.0,
							"col": THEMES[4]["boss_col"].darkened(0.25), "r": 24.0,
							"hp": php, "maxhp": php, "spd": 55.0,
							"type": "elite", "orbcd": 0.0, "atk": 2.0})
				e["atk2"] = 7.5
	# الهجوم الأساسي
	if float(e["atk"]) <= 0.0:
		match kind:
			0:  # حارس المرج: حلقة كثيفة + حلقة عكسية في الغضب
				_ring(bp, 18, 160.0, THEMES[0]["boss_col"])
				if enraged:
					_ring(bp, 11, 115.0, THEMES[0]["boss_col"].lightened(0.25))
				e["atk"] = 1.35
			1:  # ملك العظام: وابل كثيف في خط مستقيم
				var dir := (pp - bp).normalized()
				for k in 7:
					_ebullet(bp, dir * (215.0 + float(k) * 30.0), THEMES[1]["boss_col"])
				for a in [-0.10, 0.10]:
					_ebullet(bp, dir.rotated(a) * 245.0, THEMES[1]["boss_col"])
				e["atk"] = 1.35
			2:  # قلب الجليد: لولب (أسرع بعد الانكسار)
				e["spiral"] = float(e["spiral"]) + 0.5
				var sa: float = e["spiral"]
				_ebullet(bp, Vector2(cos(sa), sin(sa)) * 135.0, THEMES[2]["boss_col"])
				_ebullet(bp, Vector2(cos(sa + PI), sin(sa + PI)) * 135.0, THEMES[2]["boss_col"])
				e["atk"] = 0.075 if bool(e.get("split_done", false)) else 0.11
			3:  # وحش الحمم: اندفاع + نار مطارِدة
				e["charge"] = 0.55
				_ring(bp, 6, 170.0, THEMES[3]["boss_col"])
				for k in 2:
					_ebullet(bp, Vector2(cos(rng.randf() * TAU), sin(rng.randf() * TAU)) * 150.0, Color(1.0, 0.45, 0.08), true)
				e["atk"] = 2.0
			4:  # ظل الفراغ: انتقال + حلقة
				var np := pp + Vector2(rng.randf_range(-260, 260), rng.randf_range(-200, 200))
				np.x = clampf(np.x, 60, WW - 60)
				np.y = clampf(np.y, 60, WH - 60)
				_burst(bp, THEMES[4]["boss_col"], 12)
				e["pos"] = np
				_ring(np, 8, 170.0, THEMES[4]["boss_col"])
				e["atk"] = 2.1
			_:  # ملك الرماد: أطوار بصحته — بيقلّد الزعماء الأربعة بالترتيب
				var kfrac := float(e["hp"]) / float(e["maxhp"])
				if bool(e.get("reborn", false)):
					# بعد البعث: كل الحركات مرة واحدة + ستايله الذهبي
					var cyc := int(e["cyc"])
					_ring(bp, 12, 170.0, e["col"])
					var dirk := (pp - bp).normalized()
					for a in [-0.25, 0.0, 0.25]:
						_ebullet(bp, dirk.rotated(a) * 255.0, Color(1.0, 0.5, 0.1))
					if cyc % 2 == 0:
						e["spiral"] = float(e["spiral"]) + 0.8
						var sk: float = e["spiral"]
						for q in 6:
							var aa := sk + TAU * float(q) / 6.0
							_ebullet(bp, Vector2(cos(aa), sin(aa)) * 150.0, e["col"])
					if cyc % 3 == 2:
						# ستايله الخاص: نار ملكية على الأرض تحت اللاعب
						traps.append({"k": "burn", "pos": Vector2(pp), "perm": false, "life": 3.5})
						e["charge"] = 0.5
					e["cyc"] = cyc + 1
					e["atk"] = 1.35
				elif kfrac > 0.75:
					# كحارس المرج المطوَّر: حلقة 16 (+ درعه من الاستدعاء فوق)
					_ring(bp, 16, 160.0, e["col"])
					e["atk"] = 1.7
				elif kfrac > 0.5:
					# كملك العظام المطوَّر: وابل مستقيم (+ أشواكه من فوق)
					var dirk2 := (pp - bp).normalized()
					for k in 7:
						_ebullet(bp, dirk2 * (215.0 + float(k) * 30.0), e["col"])
					e["atk"] = 1.3
				elif kfrac > 0.25:
					# كقلب الجليد المطوَّر: لولب سريع
					e["spiral"] = float(e["spiral"]) + 0.5
					var sk2: float = e["spiral"]
					_ebullet(bp, Vector2(cos(sk2), sin(sk2)) * 140.0, e["col"])
					_ebullet(bp, Vector2(cos(sk2 + PI), sin(sk2 + PI)) * 140.0, e["col"])
					e["atk"] = 0.09
				else:
					# كوحش الحمم المطوَّر: اندفاعات + نار مطارِدة
					e["charge"] = 0.55
					_ring(bp, 8, 180.0, e["col"])
					for k in 2:
						_ebullet(bp, Vector2(cos(rng.randf() * TAU), sin(rng.randf() * TAU)) * 150.0, Color(1.0, 0.45, 0.08), true)
					e["atk"] = 2.1
		if enraged:
			e["atk"] = float(e["atk"]) * 0.72   # إيقاع أسرع في الغضب

func _ring(pos: Vector2, n: int, spd: float, col: Color) -> void:
	for i in n:
		var a := (TAU / float(n)) * i
		_ebullet(pos, Vector2(cos(a), sin(a)) * spd, col)

func _ebullet(pos: Vector2, vel: Vector2, col: Color, home := false, wound := false) -> void:
	if ebullets.size() >= 130:
		return
	ebullets.append({"pos": pos, "vel": vel, "r": 7.0 if not home else 8.0, "col": col, "life": 7.0 if not home else 5.0, "home": home, "t": 0.0, "wound": wound})

func _ebullet_step(dt: float) -> void:
	var i := ebullets.size() - 1
	while i >= 0:
		var b = ebullets[i]
		# النار المطارِدة بتنعطف ناحيتك — اهرب بالداش
		if bool(b.get("home", false)):
			var want: Vector2 = (pp - Vector2(b["pos"])).normalized() * 175.0
			b["vel"] = Vector2(b["vel"]).lerp(want, minf(1.0, dt * 2.4))
		b["pos"] += b["vel"] * dt
		b["life"] = float(b["life"]) - dt
		b["t"] = float(b.get("t", 1.0)) + dt   # عمر القذيفة (لوميضة الإطلاق)
		var bp: Vector2 = b["pos"]
		var dead := float(b["life"]) <= 0.0 or bp.x < -60 or bp.x > WW + 60 or bp.y < -60 or bp.y > WH + 60
		var ebr := float(b["r"]) + PR - 3.0
		# Close Call (v1.1.5): الطلقة اللي بتمرّ لاصقة من غير ما تصيبك بتدّي باف قصير
		if int(ups_count.get("closecall", 0)) > 0 and not bool(b.get("nm", false)) \
				and bp.distance_squared_to(pp) < (ebr + 30.0) * (ebr + 30.0) and bp.distance_squared_to(pp) >= ebr * ebr:
			b["nm"] = true
			closecall_t = 2.0
			spawn_hit_spark(pp, Color(1.0, 0.95, 0.6))
		if invuln <= 0.0 and bp.distance_squared_to(pp) < ebr * ebr:
			_hurt(16.0 * _dmg_mul(), "enemy shot")
			# جرح النخبة: يمنع أي علاج 4 ثواني (شريط الصحة برتقالي + مؤشر WOUNDED + نغمة مميزة)
			if bool(b.get("wound", false)):
				if wound_t <= 0.0:
					Audio.play_sfx("hurt", -2.0, 1.5, 1.6)   # نغمة أحدّ من الضرر العادي
				wound_t = maxf(wound_t, 4.0)
				_tip("wound", "Wounded! Elite shots block ALL healing for 4s — the health bar turns orange.", 3.2)
			flash = minf(1.0, flash + 0.5)
			invuln = maxf(invuln, 0.4)
			if hurt_snd_cd <= 0.0:
				Audio.play_sfx("hurt", -4.0)
				hurt_snd_cd = 0.3
			dead = true
		if dead:
			ebullets.remove_at(i)
		i -= 1

func _spawn_void_gauntlet() -> void:
	# الزعماء الأربعة يعودون للحياة — أقوى، وكلهم مرة واحدة
	boss_alive = true
	boss_fight_t = 0.0
	boss_minion_t = 10.0; boss_haz_t = 13.0; boss_kite_t = 0.0
	for e in enemies:
		_burst(e["pos"], Color(1, 1, 1), 6)
	enemies.clear()
	ebullets.clear()
	wipe_t = 1.0
	Audio.play_sfx("sweep", 0.0, 0.8, 0.8)
	Audio.play_sfx("boss", 2.0, 0.85, 0.9)
	for k in 4:
		var th2 = THEMES[k]
		var ga := TAU * float(k) / 4.0 + 0.4
		var hpv2 := float(Balance.BOSS_HP_STAGE[4]) * (1.0 + 0.12 * float(level - 1)) * 0.45 * asc_hp
		enemies.append({
			"pos": pp + Vector2(cos(ga), sin(ga)) * 620.0,
			"col": th2["boss_col"],
			"r": 46.0, "hp": hpv2, "maxhp": hpv2, "spd": 58.0 if k != 3 else 76.0,
			"type": "boss", "orbcd": 0.0,
			"kind": k, "atk": 1.5 + float(k) * 0.4, "spiral": 0.0, "charge": 0.0,
			"phase": 1, "atk2": 4.0, "tcd": 0.0, "cyc": 0, "sumt": 4.0, "split_done": false,
		})
	boss_name_cur = "Lords of the Realms"
	shake = 11.0
	Audio.play_music("b4")
	_flash_msg(T("!! The Lords of the Realms have returned - defeat them all !!"), 3.2)

# ================================================================
#  ENEMIES
# v1.1.4: نقطة استهداف الدور (إزاحة نسبية للاعب — بتتبعه بين قرارات الـ AI)
# Chaser = صفر · Fast/Tank/Bomber = توقّع مسار اللاعب · Flanker = زاوية جانبية
# التوقع مسقوف بـ150px ومن المرحلة 2 فقط (المرحلة 1 تعليمية بذكاء بسيط)
func _enemy_target_offset(e: Dictionary, d: float) -> Vector2:
	var etype := String(e["type"])
	var moving := pvel.length() > 40.0
	var pred := Vector2.ZERO
	if stage >= 2 and moving:
		match etype:
			"fast":   pred = pvel * 0.35
			"tank":   pred = pvel * 0.50
			"bomber": pred = pvel * 0.30
			"elite":  pred = pvel * 0.25
	pred = pred.limit_length(150.0)
	# Flanker: يدخل من الجنب مش في وشك — يجبرك تغيّر اتجاهك
	var fl := int(e.get("flank", 0))
	if fl != 0 and d > 120.0:
		var to0 := pp - Vector2(e["pos"])
		var perp := (Vector2(-pvel.y, pvel.x).normalized() if moving else Vector2(-to0.y, to0.x).normalized())
		pred += perp * 90.0 * float(fl) * clampf(d / 300.0, 0.4, 1.0)
	return pred

func _enemy_step(dt: float) -> void:
	var i := enemies.size() - 1
	while i >= 0:
		var e = enemies[i]
		if float(e.get("hitflash", 0.0)) > 0.0:
			e["hitflash"] = float(e["hitflash"]) - dt
		# Burn DoT (v1.2 — سلاح Fire Aura): حرق متراكم، الزعماء يقاوموا 50%
		var bt2 := float(e.get("burn_t", 0.0))
		if float(e.get("flare_cd", 0.0)) > 0.0:
			e["flare_cd"] = float(e["flare_cd"]) - dt
		if bt2 > 0.0:
			e["burn_t"] = bt2 - dt
			var bdps := float(e.get("burn_dps", 0.0)) * (0.5 if String(e["type"]) == "boss" else 1.0)
			e["hp"] = float(e["hp"]) - bdps * dt
			stat_dmg_dealt += bdps * dt
			dps_bucket += bdps * dt
			if float(e["burn_t"]) <= 0.0:
				e["burn_st"] = 0
				e["burn_dps"] = 0.0
			if float(e["hp"]) <= 0.0:
				_kill_enemy(i)
				i -= 1
				continue
		if String(e["type"]) == "boss":
			_boss_step(e, dt)
		else:
			var to: Vector2 = pp - e["pos"]
			var d := to.length()
			var slow_t: float = e.get("slow", 0.0)
			# Frozen Core: الإبطاء أعمق 12% لكل رتبة (v1.2)
			var slow_f := (0.6 - 0.12 * float(ups_count.get("fcore", 0))) if slow_t > 0.0 else 1.0
			slow_f = maxf(slow_f, 0.2)
			if theme_idx() == 2:
				slow_f *= 0.80   # الثلج بيبطّئ الأعداء أكتر
			if slow_t > 0.0:
				e["slow"] = slow_t - dt
			# تجميد Eternal Winter: وقفة كاملة وجيزة بحصانة لكل عدو
			if float(e.get("frz_im", 0.0)) > 0.0:
				e["frz_im"] = float(e["frz_im"]) - dt
			if float(e.get("frz_t", 0.0)) > 0.0:
				e["frz_t"] = float(e["frz_t"]) - dt
				slow_f = 0.0
			# درع الزعيم: يدور حواليه ويحميه بدل ما يطاردك
			if e.has("orbit_host"):
				var host = e["orbit_host"]
				if enemies.has(host) and float(host.get("hp", 0.0)) > 0.0:
					e["orb_a"] = float(e["orb_a"]) + dt * 1.6
					var oa: float = e["orb_a"]
					e["pos"] = Vector2(host["pos"]) + Vector2(cos(oa), sin(oa)) * 88.0
				else:
					e.erase("orbit_host")   # مات الزعيم → يطاردك عادي
			elif d > 0.001:
				# --- v1.1.4: أدوار ذكاء — قرارات كل 0.25ث (رخيصة) + توجيه ناعم كل فريم ---
				var etype0 := String(e["type"])
				var espd2 := float(e["spd"]) * slow_f * asc_spd
				if etype0 == "shooter":
					# الرامي: يحافظ على نطاق مثالي 200-320 ويخطو جانبياً بعد كل طلقة
					if d > 320.0:
						e["pos"] += (to / d) * espd2 * dt
					elif d < 200.0:
						e["pos"] -= (to / d) * espd2 * 0.9 * dt
					elif float(e.get("strafe_t", 0.0)) > 0.0:
						e["strafe_t"] = float(e["strafe_t"]) - dt
						var perp := Vector2(-to.y, to.x).normalized() * float(e.get("sdir", 1.0))
						e["pos"] += perp * espd2 * 0.7 * dt
				else:
					# تورريت الجندي (v1.2): المطاردون القريبون منه بينجذبوا له — أداة تمركز حقيقية
					var lured := false
					if q_turret != null and (etype0 == "norm" or etype0 == "fast"):
						var tq: Vector2 = q_turret["pos"]
						if Vector2(e["pos"]).distance_squared_to(tq) < d * d:
							var tdq := tq - Vector2(e["pos"])
							var tql := tdq.length()
							if tql > 30.0:
								e["pos"] += (tdq / tql) * espd2 * dt
							lured = true
					if not lured:
						e["ai_t"] = float(e.get("ai_t", 0.0)) - dt
						if float(e["ai_t"]) <= 0.0:
							e["ai_t"] = 0.25
							e["tgt_off"] = _enemy_target_offset(e, d)
						var tdir := (pp + Vector2(e.get("tgt_off", Vector2.ZERO))) - Vector2(e["pos"])
						var td := tdir.length()
						e["pos"] += ((tdir / td) if td > 0.001 else (to / d)) * espd2 * dt
			# النخبة زعيم صغير: ترمي رشقة موجّهة كل فترة
			if String(e["type"]) == "elite":
				e["atk"] = float(e["atk"]) - dt
				# ترمي بس لو قريبة من الشاشة (مش من بعيد خالص)
				if float(e["atk"]) <= 0.0 and ebullets.size() < 70 and Vector2(e["pos"]).distance_to(pp) < 620.0:
					var dir := (pp - Vector2(e["pos"])).normalized()
					# من المرحلة 3: طلقة النخبة "تجرح" — تمنع كل علاج 4 ثواني (Anti-heal pressure)
					_ebullet(e["pos"], dir * 168.0, Color(1.0, 0.82, 0.25), false, stage >= 3)
					e["atk"] = 3.1
			# الرامي: طلقة أحمر موجّهة كل ~2.2ث لو داخل المدى
			elif String(e["type"]) == "shooter":
				e["atk"] = float(e.get("atk", 2.0)) - dt
				# v1.1.4: يرمي فقط من نطاقه المثالي، وبعد الطلقة يخطو جانبياً (مش تمثال)
				if float(e["atk"]) <= 0.0 and ebullets.size() < 90 and d < 420.0 and d > 140.0:
					_ebullet(e["pos"], (to / maxf(d, 0.001)) * 190.0, Balance.COL_ENEMY)
					e["atk"] = 2.2
					e["strafe_t"] = 0.8
		e["orbcd"] = maxf(0.0, float(e["orbcd"]) - dt)
		# ضرر تلامس
		var er: float = e["r"]
		var dd: float = (pp - Vector2(e["pos"])).length()
		# القنبلة (v1.1.4): فتيل تلغراف واضح — بيولّع ويومض ويبطّئ 0.55ث قبل الانفجار
		# (كانت بتنفجر بالتلامس فوراً — دلوقتي الداش بيطلعك منها = موت عادل)
		if String(e["type"]) == "bomber":
			var fuse := float(e.get("fuse", -1.0))
			if fuse < 0.0 and dd < 100.0:
				e["fuse"] = 0.55
				Audio.play_sfx("hit", -8.0, 1.8, 1.9)   # نقرة تحذير
			elif fuse >= 0.0:
				e["fuse"] = fuse - dt
				e["spd"] = minf(float(e["spd"]), 42.0)   # مولّع = بطيء
				e["hitflash"] = 0.09 if fmod(animt, 0.12) < 0.06 else 0.0   # وميض سريع
				if float(e["fuse"]) <= 0.0:
					_bomber_boom(Vector2(e["pos"]))
					enemies.remove_at(i)
					i -= 1
					continue
		if dd < er + PR and invuln <= 0.0:
			var dps := (16.0 + er * 0.55) * _dmg_mul()
			var hsrc := "contact:" + String(e["type"])
			if String(e["type"]) == "boss":
				dps = 38.0 * _dmg_mul()
			elif String(e["type"]) == "elite":
				dps *= 0.75   # النخبة خطرها في الرمي مش التلامس
			_hurt(dps * dt, hsrc)
			flash = minf(1.0, flash + dt * 3.0)
			if hurt_snd_cd <= 0.0:
				Audio.play_sfx("hurt", -4.0)
				hurt_snd_cd = 0.35
		i -= 1

func damage_enemy(idx: int, dmg: float, src: String = "bullet") -> void:
	var e = enemies[idx]
	var is_boss := String(e["type"]) == "boss"
	var final := dmg
	var was_crit := false
	# الكريت مسقوف بهوية الشخصية، وضد الزعماء ×1.5 بدل ×2 (anti-cheese)
	# All In Roll: بافات المقامر بتكسر السقف مؤقتاً (الجاكبوت = كريت مضمون 5ث)
	var eff_crit := minf(crit, crit_cap)
	if g_crit_t > 0.0:
		eff_crit = minf(crit + g_crit_add, 1.0)
	if eff_crit > 0.0 and rng.randf() < eff_crit:
		final *= 1.5 if is_boss else 2.0
		was_crit = true
		# ترقية Deathblow Lv3 (Improvement Pass): الكريت بيولّع الهدف
		if int(ups_count.get("crit", 0)) >= 3:
			e["burn_dps"] = minf(30.0, float(e.get("burn_dps", 0.0)) + 8.0)
			e["burn_t"] = 2.0
	if g_dmg_t > 0.0:
		final *= g_dmg_mul   # مكسب/عقوبة الرمية
	# v1.2.5: Gambler Fate Gamble — بركة/لعنة ضرر 30ث
	if r_fate_t > 0.0:
		final *= r_fate_mul
	# v1.2-D: طور الدرع — الزعيم المتقوقع بياخد 20% فقط (نافذة إعادة تموضع متلغرفة)
	if is_boss and float(e.get("shell_t", 0.0)) > 0.0:
		final *= 0.2
	# v1.2-D: مقاومة منطقية محدودة — الأسلحة الجانبية 70% ضد الزعماء
	# (سلاح توقيعك هو سلاح الزعماء؛ الجانبية متخصصة في الزحام — قاعدة هوية مش nerf)
	if is_boss and (src == "kunai" or src == "zap" or src == "orbit" or src == "frost"):
		final *= 0.7
	# v1.2.3: داش الشينوبي ضد الزعماء مخفّض (السلاش هو سلاح الزعماء مش الدهس)
	if is_boss and src == "dash":
		final *= 0.5
	# Giant Slayer: +20% لكل رتبة ضد الزعماء والنخبة فقط (بركة موقفية)
	var gs := int(ups_count.get("bossdmg", 0))
	if gs > 0 and (is_boss or String(e["type"]) == "elite"):
		final *= 1.0 + 0.20 * float(gs)
	# Boss Breaker: نافذة +ضرر زعماء بعد داش قريب (تلعب جوه رقصة الزعيم مش من بعيد)
	if is_boss and bbreak_t > 0.0:
		final *= 1.0 + 0.25 * float(ups_count.get("bbreak", 0))
	# Close Call (v1.1.5): طلقة مرقت جنبك = باف ضرر مؤقت
	if closecall_t > 0.0:
		final *= 1.0 + 0.12 * float(ups_count.get("closecall", 0))
	# Marked Shot (v1.2 سلاح): كل خامس ضربة (الرابعة مع Shatter Mark) تعلّم الهدف —
	# المعلَّم بياخد ضرر إضافي من كل المصادر، وينفجر شظايا عند موته من Lv3
	var mkr := int(ups_count.get("mark", 0))
	if mkr > 0:
		mark_hits += 1
		if mark_hits >= (4 if evo_shatter else 5) and not is_boss and not bool(e.get("marked", false)):
			mark_hits = 0
			e["marked"] = true
	if bool(e.get("marked", false)):
		final *= 1.10 + 0.05 * float(mkr) + 0.10 * float(ups_count.get("ccore", 0))
	# Synergy — Momentum: تتحرّك ⇒ ضرر أعلى
	if is_moving and syn_active.has("momentum"):
		final *= 1.15
	if String(e.get("mod", "")) == "shield":
		final *= 0.55   # نخبة مدرّعة
	e["hp"] = float(e["hp"]) - final
	stat_dmg_dealt += final
	dps_bucket += final
	e["hitflash"] = 0.09        # وميض أبيض لحظة الإصابة (feedback فوري)
	spawn_hit_spark(e["pos"], Balance.COL_YOU_HI if src != "bullet" else Color(1, 0.95, 0.8))   # شرارة إصابة
	# v1.1: اتشال امتصاص الأرواح مع كل ضربة نهائياً — العلاج بالقتل (Soul Steal في _kill_enemy)
	# Synergy — Vampiric Edge: الكريت له فرصة 35% يشفي 2 HP بتبريد 2ث (مش من الطلقات الجانبية)
	if was_crit and src != "side" and syn_active.has("vampiric_edge") and vamp_cd <= 0.0 and rng.randf() < 0.35:
		if _heal(2.0, "generic") > 0.0:
			vamp_cd = 2.0
	if slow_n > 0:
		e["slow"] = 0.8 + 0.2 * float(slow_n)
	var ep: Vector2 = e["pos"]
	var ncol := Balance.COL_TEXT          # ضرر عادي = أوف-وايت (أنعم من الأبيض الحاد)
	if was_crit:
		ncol = Balance.COL_REWARD          # كريت = ذهبي (بارز)
	elif src == "orbit":
		ncol = Balance.COL_YOU_HI          # سلاحك الدوّار = أزرق فاتح
	_dmgnum(ep + Vector2(rng.randf_range(-10, 10), -float(e["r"]) - 6.0), int(final), ncol, was_crit)
	if float(e["hp"]) <= 0.0:
		kill_src = src
		_kill_enemy(idx)
		kill_src = ""
	else:
		Audio.play_sfx("hit", -9.0)
		if was_crit:
			_burst(ep, Color(1, 0.9, 0.3), 6)
	# Synergy — Shatter Core: الكريت يفجّر شظايا (تبريد 0.5ث + مش من الجانبية — منع سبام الرشقات)
	if was_crit and src != "side" and syn_active.has("shatter_core") and shatter_cd <= 0.0:
		shatter_cd = 0.5
		pending_aoe.append({"pos": ep, "r": 82.0, "dmg": maxf(6.0, bullet_dmg * 0.5)})
		if rings.size() < 26:
			rings.append({"pos": ep, "t": 0.0, "max": 82.0, "col": Balance.COL_REWARD})
		_burst(ep, Balance.COL_REWARD, 8)

# ضرر منطقة مباشر (لا يمرّ عبر damage_enemy → لا كريت/تكرار) — للتركيبات
func _aoe_damage(center: Vector2, radius: float, dmg: float) -> void:
	var r2 := radius * radius
	var i := enemies.size() - 1
	while i >= 0:
		var e = enemies[i]
		if Vector2(e["pos"]).distance_squared_to(center) <= r2:
			# الزعماء يقاومون سبام الـ AoE (anti-cheese): 65% من الضرر فقط
			var ad := dmg * (0.65 if String(e["type"]) == "boss" else 1.0)
			e["hp"] = float(e["hp"]) - ad
			stat_dmg_dealt += ad
			dps_bucket += ad
			e["hitflash"] = 0.09
			if float(e["hp"]) <= 0.0:
				_kill_enemy(i)
		i -= 1

func _kill_enemy(idx: int) -> void:
	var e = enemies[idx]
	# ملك الرماد: أول ما صحته توصل صفر يُبعث بصحة كاملة (مرة واحدة)
	if String(e["type"]) == "boss" and int(e.get("kind", 0)) == 5 and not bool(e.get("reborn", false)):
		e["reborn"] = true
		e["hp"] = e["maxhp"]
		e["spd"] = float(e["spd"]) * 1.15
		e["atk"] = 2.0
		hitstop = 0.3
		shake = 13.0
		wipe_t = 0.9
		Audio.play_sfx("boss", 3.0, 0.8, 0.8)
		_burst(Vector2(e["pos"]), Color(1.0, 0.85, 0.3), 46)
		_flash_msg(T("The Ash King rises from his ashes!!"), 2.8)
		return
	kills += 1
	combo += 1
	combo_t = 3.0
	if combo > combo_best:
		combo_best = combo
	# Shinobi (v1.2a): قتلة بالداش بتردّ ربع شحنة — إتقان الداش بيتكافأ من غير ما يبقى لا نهائي
	if sig == "crescent" and kill_src == "dash" and dash_charges < dash_charges_max:
		dash_recharge_t = maxf(0.0, dash_recharge_t - dash_cd_max * 0.82 * 0.25)
	var epos: Vector2 = e["pos"]
	var etype: String = e["type"]
	# Marked Shot: الهدف المعلَّم ينفجر لشظايا من Lv3 (تحويل القتل لسلسلة)
	if bool(e.get("marked", false)) and (int(ups_count.get("mark", 0)) >= 3 or evo_shatter):
		var shn := 4 + 2 * int(ups_count.get("mark", 0))
		for k in shn:
			var sa := TAU * float(k) / float(shn) + rng.randf() * 0.5
			bullets.append({"pos": Vector2(epos), "vel": Vector2(cos(sa), sin(sa)) * bullet_speed * 0.8,
				"life": 0.5, "pierce": 0, "bounce": 0, "side": true, "exec": false})
		# تطوّر Shatter Mark: المعلَّم بينفجر انفجاراً حقيقياً كمان
		if evo_shatter:
			pending_aoe.append({"pos": Vector2(epos), "r": 100.0, "dmg": maxf(10.0, bullet_dmg * 0.8)})
		_burst(epos, Balance.COL_REWARD, 10)
		Audio.play_sfx("shoot", -10.0, 1.3, 1.5)
	# Shard Seed (v1.1.5): فرصة 12%/رتبة إن أي قتيل يتفتت لشظايا — محرّك AoE للـ Wrecker
	var shr := int(ups_count.get("shard", 0))
	if shr > 0 and etype != "boss" and rng.randf() < 0.12 * float(shr):
		for k in 3:
			var sa2 := rng.randf() * TAU
			bullets.append({"pos": Vector2(epos), "vel": Vector2(cos(sa2), sin(sa2)) * bullet_speed * 0.75,
				"life": 0.45, "pierce": 0, "bounce": 0, "side": true, "exec": false})
	# تطوّر Thunder Loop: كل 12 قتلة = ضربة عاصفة (مؤجّلة لخارج حلقات القتل)
	if evo_thunder:
		thunder_kills += 1
		if thunder_kills >= 12:
			thunder_kills = 0
			thunder_pending = true
	# تطوّر Frost Runner: عدو مات فوق أثر الصقيع = انفجار صقيعي (بتبريد 0.5ث)
	if evo_frostrun and frost_burst_cd <= 0.0:
		for fp2 in frost_trail:
			if Vector2(fp2["pos"]).distance_squared_to(epos) <= 60.0 * 60.0:
				frost_burst_cd = 0.5
				pending_aoe.append({"pos": Vector2(epos), "r": 90.0, "dmg": maxf(8.0, bullet_dmg * 0.5)})
				for e8 in enemies:
					if String(e8["type"]) != "boss" and Vector2(e8["pos"]).distance_squared_to(epos) <= 90.0 * 90.0:
						e8["slow"] = maxf(float(e8.get("slow", 0.0)), 1.2)
				if rings.size() < 26:
					rings.append({"pos": Vector2(epos), "t": 0.0, "max": 90.0, "col": Color(0.65, 0.88, 1.0)})
				break
	# Soul Steal: علاج بالقتل — 1 HP كل 10 قتلى (رتبة 2: كل 7)، النخبة بـ3،
	# لا يعمل أثناء الزعيم، ومسقوف لكل مرحلة (جوّه _heal — سقف Burner أعلى)
	if steal_n > 0 and not boss_alive:
		steal_kills += 3 if etype == "elite" else 1
		var sreq := 10 - 3 * (steal_n - 1)
		if steal_kills >= sreq:
			steal_kills -= sreq
			var healed := _heal(1.0, "steal")
			# Soul Pulse (تطوّر v1.2): العلاج الناجح يدفع الأعداء للخلف (منفعة مش علاج إضافي)
			if healed > 0.0 and evo_soulp:
				for e7 in enemies:
					if String(e7["type"]) == "boss":
						continue
					var pv: Vector2 = Vector2(e7["pos"]) - pp
					var pd := pv.length()
					if pd < 130.0 and pd > 0.01:
						e7["pos"] = Vector2(e7["pos"]) + (pv / pd) * (55.0 * (1.0 - pd / 130.0) + 12.0)
						e7["slow"] = maxf(float(e7.get("slow", 0.0)), 0.4)
				if rings.size() < 26:
					rings.append({"pos": Vector2(pp), "t": 0.0, "max": 130.0, "col": Color(0.75, 0.95, 0.8)})
	# Kill Wave: كل 25 قتلة موجة تضر وتبطئ من حولك (تحكم زحام مكتسَب)
	var pr := int(ups_count.get("pulse", 0))
	if pr > 0:
		pulse_kills += 1
		if pulse_kills >= 25:
			pulse_kills = 0
			var prad := 150.0 + 40.0 * float(pr)
			pending_aoe.append({"pos": Vector2(pp), "r": prad, "dmg": maxf(10.0, bullet_dmg * (0.6 + 0.3 * float(pr)))})
			var prsq := prad * prad
			for e6 in enemies:
				if String(e6["type"]) != "boss" and Vector2(e6["pos"]).distance_squared_to(pp) <= prsq:
					e6["slow"] = maxf(float(e6.get("slow", 0.0)), 1.2)
			if rings.size() < 26:
				rings.append({"pos": Vector2(pp), "t": 0.0, "max": prad, "col": Balance.COL_YOU_HI})
			Audio.play_sfx("zap", -9.0, 0.8, 0.9)
	shake = minf(6.0, shake + 3.0)
	# انفجار موت بلون نوع العدو (أقوى قليلاً للنخبة)
	var burst_n := 18 if etype == "elite" else 10
	_burst(epos, Color(e["col"]), burst_n)
	if rings.size() < 26:
		rings.append({"pos": epos, "t": 0.0, "max": float(e["r"]) + 26.0, "col": Color(e["col"])})
	# صوت القتل بـ cooldown بسيط (منع الـ spam في الزحمة)
	if kill_snd_cd <= 0.0:
		Audio.play_sfx("kill", -4.0)
		kill_snd_cd = 0.05
	# هيت-ستوب: توقّف لحظي يدّي وزن للضربات الكبيرة
	if etype == "elite":
		hitstop = maxf(hitstop, 0.07)
	elif etype == "boss":
		hitstop = maxf(hitstop, 0.22)
	enemies.remove_at(idx)
	if explode_n > 0:
		_explode(epos)
	# القطيع الذهبي: بلورتان لكل واحد
	if bool(e.get("gold", false)):
		_drop_gem(epos)
		_drop_gem(epos + Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 14)))
	match etype:
		"split":
			for k in 2:
				var off := Vector2(rng.randf_range(-18, 18), rng.randf_range(-18, 18))
				enemies.append({
					"pos": epos + off, "col": e["col"],
					"r": 9.0, "hp": 12.0 * _hp_mul(), "maxhp": 12.0,
					"spd": 128.0, "type": "fast", "orbcd": 0.0,
				})
			_drop_gem(epos)
		"bomber":
			_bomber_boom(epos)
			_drop_gem(epos)
		"elite":
			for k in 5:
				_drop_gem(epos + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30)))
			shake = 8.0
			_burst(epos, Color(1, 0.85, 0.2), 22)
			# النخبة المنقسمة: تتفتت لنخبتين صغيرتين
			if String(e.get("mod", "")) == "split":
				for k in 2:
					var shp := float(e["maxhp"]) * 0.30
					enemies.append({
						"pos": epos + Vector2(rng.randf_range(-24, 24), rng.randf_range(-24, 24)),
						"col": Color(e["col"]).lightened(0.15),
						"r": 17.0, "hp": shp, "maxhp": shp, "spd": 60.0,
						"type": "elite", "orbcd": 0.0, "atk": rng.randf_range(2.5, 3.5), "mod": "",
					})
		"boss":
			# لو لسه فيه زعيم تاني عايش (قلب الجليد المنكسر) — مانهيش المعركة
			var bosses_left := 0
			for e3 in enemies:
				if String(e3["type"]) == "boss":
					bosses_left += 1
			if bosses_left > 0:
				_burst(epos, Color(1, 0.85, 0.3), 24)
				for k in 6:
					_drop_gem(epos + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30)))
				_heal(10.0, "reward")
				shake = 8.0
				if stage == FINAL_STAGE and not king_spawned:
					_toast(T("A Lord has fallen - %d remain") % bosses_left, 1.8)
			elif stage == FINAL_STAGE and not king_spawned:
				# سقط الأسياد الأربعة — الملك بنفسه ينزل
				king_spawned = true
				boss_times.append({"name": "Lords of the Realms", "secs": boss_fight_t})
				_heal(25.0, "reward")
				vacuum_t = 2.0
				_spawn_boss()
			else:
				_boss_die(epos)
		_:
			_drop_gem(epos)

# ================================================================
#  WEAPONS
func _nearest_enemy() -> int:
	var best := -1
	var bd := INF
	for i in enemies.size():
		var d: float = enemies[i]["pos"].distance_squared_to(pp)
		if d < bd:
			bd = d
			best = i
	return best

# موجة Titan الصادمة: ضرر + دفع للخلف (بترجع بالفهارس عشان القتل الآمن)
func _titan_wave(c: Vector2, radius: float, dmg: float, kb: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var e = enemies[i]
		var dv: Vector2 = Vector2(e["pos"]) - c
		var dd := dv.length()
		if dd <= radius + float(e["r"]):
			if String(e["type"]) != "boss" and dd > 0.01:
				e["pos"] = Vector2(e["pos"]) + (dv / dd) * kb * (1.0 - dd / (radius + 40.0))
			damage_enemy(i, dmg, "wave")
	if rings.size() < 26:
		rings.append({"pos": c, "t": 0.0, "max": radius, "col": Color(0.85, 0.88, 0.95)})
	Audio.play_sfx("explode", -9.0, 0.65, 0.72)
	shake = maxf(shake, 3.5)

# ---------- v1.2.3: Pyromancer (Fire Bolt + Fireball) + Shinobi (Crescent Slash + Q/R) ----------
# Burn بطبقات (حد أقصى 5) — كل طبقة تزيد DoT، والزعماء يقاوموا 50% (التطبيق في _enemy_step)
func _ignite(e, stacks := 1) -> void:
	var st := mini(5, int(e.get("burn_st", 0)) + stacks)
	e["burn_st"] = st
	e["burn_dps"] = float(st) * 7.0
	e["burn_t"] = 2.6
	# عند أقصى طبقات: flare pulse صغير (بتبريد لكل عدو)
	if st >= 5 and float(e.get("flare_cd", 0.0)) <= 0.0:
		e["flare_cd"] = 1.0
		var isb := String(e["type"]) == "boss"
		var fd := 14.0 * (0.5 if isb else 1.0)
		e["hp"] = float(e["hp"]) - fd
		stat_dmg_dealt += fd
		dps_bucket += fd
		_burst(Vector2(e["pos"]), Color(1.0, 0.7, 0.2), 8)

# Fire Bolt: كرات نار مدى متوسط، دقة أقل — كل طلقة تكوّم Burn (منطق الانفجار في _bullet_step)
func _fire_bolt() -> void:
	var ni := _nearest_enemy()
	if ni < 0:
		return
	var dir := (Vector2(enemies[ni]["pos"]) - pp).normalized()
	var inferno := r_buff_t > 0.0   # Inferno Overload: كل طلقة بقت كرة نار صغيرة تنفجر
	var loaded := (fbolt_hits % 3) == 2   # الطلقة اللي هتكمّل الـ3 = "محمّلة" (أكبر/أسخن)
	var shots := multishot
	var spread := deg_to_rad(9.0)
	var start := -spread * float(shots - 1) * 0.5
	var center := (shots - 1) / 2
	for k in shots:
		var jitter := rng.randf_range(-0.06, 0.06)   # دقة أقل من الجندي
		var v := dir.rotated(start + spread * float(k) + jitter) * bullet_speed * 0.82
		var side := k != center
		bullets.append({"pos": pp, "vel": v, "life": 1.05, "pierce": pierce, "bounce": ric_n,
			"side": side, "exec": false, "firebolt": true, "hot": (loaded and not side) or inferno, "infernal": inferno})
	if loaded:
		Audio.play_sfx("shoot", -8.0, 1.2, 1.35)
	else:
		Audio.play_sfx("shoot", -12.0, 0.92, 1.02)

# انفجار Pyromancer: ضرر منطقة + Burn + مؤثر واضح (ضد الزعماء ضرر مخفّض 50%)
func _fire_explosion(pos: Vector2, radius: float, dmg: float, stacks := 1) -> void:
	radius *= _area()
	_burst(pos, Color(1.0, 0.55, 0.15), 16)
	if rings.size() < 26:
		rings.append({"pos": pos, "t": 0.0, "max": radius, "col": Balance.COL_ENEMY_HI})
	shake = maxf(shake, 3.0)
	flash = minf(flash + 0.06, 0.5)
	Audio.play_sfx("explode", -8.0, 0.9, 1.0)
	var rad2 := radius * radius
	for i in range(enemies.size() - 1, -1, -1):
		var e = enemies[i]
		var rr := radius + float(e["r"])
		if Vector2(e["pos"]).distance_squared_to(pos) <= rr * rr:
			var isb := String(e["type"]) == "boss"
			var xd := dmg * (0.5 if isb else 1.0)
			e["hp"] = float(e["hp"]) - xd
			stat_dmg_dealt += xd
			dps_bucket += xd
			e["hitflash"] = 0.09
			_ignite(e, stacks)
			if float(e["hp"]) <= 0.0:
				_kill_enemy(i)

# Fireball Q: كرة نار كبيرة للأمام/أقرب عدو — تنفجر عند الاصطدام أو نهاية المدى + أرض مشتعلة
func _cast_fireball() -> void:
	var dir := (pvel.normalized() if pvel.length() > 40.0 else Vector2.RIGHT)
	var ni := _nearest_enemy()
	if ni >= 0:
		dir = (Vector2(enemies[ni]["pos"]) - pp).normalized()
	fireballs.append({"pos": Vector2(pp), "vel": dir * 360.0, "life": 1.1, "r": 16.0 * _area()})
	Audio.play_sfx("explode", -10.0, 1.25, 1.4)

# حركة كرات Fireball + انفجارها (تُستدعى كل إطار من _step)
func _fireball_step(dt: float) -> void:
	if fireballs.is_empty():
		return
	var i := fireballs.size() - 1
	while i >= 0:
		var fb = fireballs[i]
		fb["pos"] = Vector2(fb["pos"]) + Vector2(fb["vel"]) * dt
		fb["life"] = float(fb["life"]) - dt
		var boom := float(fb["life"]) <= 0.0
		var fp: Vector2 = fb["pos"]
		if not boom:
			for e in enemies:
				var hr := float(fb["r"]) + float(e["r"])
				if fp.distance_squared_to(e["pos"]) <= hr * hr:
					boom = true
					break
		if fp.x < 0 or fp.x > WW or fp.y < 0 or fp.y > WH:
			boom = true
		if boom:
			_fire_explosion(fp, 118.0, bullet_dmg * 1.9 * _sigm(), 2)
			shake = maxf(shake, 5.0)
			# أرض مشتعلة قصيرة (3-4ث) — تعيد استخدام fire_patches (بتحرق الأعداء)
			for k in 5:
				if fire_patches.size() < 46:
					fire_patches.append({"pos": fp + Vector2(rng.randf_range(-46, 46), rng.randf_range(-46, 46)), "life": 3.5})
			fireballs.remove_at(i)
		i -= 1

# Crescent Slash: قوس قطع أمامك (اتجاه الحركة أو أقرب عدو) — يقطع اللي في القوس والمدى
func _crescent_slash() -> void:
	var ni := _nearest_enemy()
	if ni < 0:
		return
	# سلاح أوتوماتيك: القوس بيتّجه لأقرب عدو (يضمن إصابة الهدف حتى وإنت بتلف حواليه)
	var aim := Vector2(enemies[ni]["pos"]) - pp
	var ang := aim.angle()
	var reach := (92.0 + 5.0 * float(multishot)) * _area()
	var half := deg_to_rad(62.0)   # قوس ~124°
	var dmg := bullet_dmg * 1.25 * _sigm() * (1.5 if berserk_t > 0.0 else 1.0)
	var maxhits := 3 + multishot + int(ups_count.get("pierce", 0))
	var hit := 0
	var reach2 := reach * reach
	for i in range(enemies.size() - 1, -1, -1):
		if hit >= maxhits:
			break
		var e = enemies[i]
		var to := Vector2(e["pos"]) - pp
		var rr := reach + float(e["r"])
		if to.length_squared() > rr * rr:
			continue
		if absf(wrapf(to.angle() - ang, -PI, PI)) <= half:
			hit += 1
			damage_enemy(i, dmg, "slash")
	slash_fx.append({"pos": Vector2(pp), "ang": ang, "arc": half, "reach": reach, "life": 0.18, "max": 0.18})
	Audio.play_sfx("hit", -9.0, 1.2, 1.35)

# Shadow Assault Q: اختفِ واقطع 3-5 أعداء قريبين ثم ارجع (حصانة أثناءها) — ينفّذ عبر sassault في _step
func _shadow_assault() -> void:
	var pool := []
	for i in enemies.size():
		var d2: float = Vector2(enemies[i]["pos"]).distance_squared_to(pp)
		if d2 < 380.0 * 380.0:
			pool.append({"d": d2, "pos": Vector2(enemies[i]["pos"])})
	pool.sort_custom(func(a, b): return float(a["d"]) < float(b["d"]))
	var n := mini(5, pool.size())
	if n <= 0:
		invuln = maxf(invuln, 0.5)
		_burst(pp, Color(0.5, 0.95, 0.7), 12)
		return
	var tg := []
	for i in n:
		tg.append(pool[i]["pos"])
	sassault = {"t": 0.0, "step": 0.09, "i": 0, "targets": tg, "dmg": bullet_dmg * 0.9 * _sigm()}
	invuln = maxf(invuln, float(n) * 0.09 + 0.35)
	_toast(T("Shadow Assault!"), 1.0)
	Audio.play_sfx("dash", -6.0, 1.0, 1.1)

# Judgement Rift R (Ultimate): تجميد لحظي ثم سلاشات متعددة على مساحة واسعة — ينفّذ عبر rift في _step
func _judgement_rift() -> void:
	r_cd = r_cd_max
	hitstop = maxf(hitstop, 0.12)
	r_active_t = 0.9
	invuln = maxf(invuln, 0.9)
	shake = maxf(shake, 6.0)
	Audio.play_sfx("boss", -6.0, 1.3, 1.4)
	_flash_msg(T("JUDGEMENT RIFT!"), 1.4)
	var R := 340.0 * _area()
	var marks := []
	for i in enemies.size():
		if marks.size() >= 40:
			break
		if Vector2(enemies[i]["pos"]).distance_squared_to(pp) <= R * R:
			marks.append(Vector2(enemies[i]["pos"]))
	var extra := clampi(10 - marks.size(), 0, 10)
	for k in extra:
		var a := TAU * float(k) / float(maxi(1, extra))
		marks.append(pp + Vector2(cos(a), sin(a)) * rng.randf_range(70.0, R))
	rift = {"t": 0.35, "r": R, "dmg": bullet_dmg * 1.4 * _sigm(), "marks": marks, "done": false}

# ---------- v1.2.5: موزّع الأولتيمت R لكل الشخصيات ----------
func _use_r() -> void:
	r_cd = r_cd_max   # تبريد ثابت 60ث (مش متأثر بـ Focus)
	match sig:
		"rifle":
			r_buff_t = 5.0
			_flash_msg(T("HEAVY MACHINE GUN!"), 1.6)
			shake = maxf(shake, 4.0)
			Audio.play_sfx("boss", -8.0, 1.2, 1.3)
		"firebolt":
			r_buff_t = 7.0
			_flash_msg(T("INFERNO OVERLOAD!"), 1.6)
			Audio.play_sfx("explode", -6.0, 1.1, 1.25)
		"spinblade":
			r_buff_t = 5.0
			_flash_msg(T("GIANT BLADE!"), 1.6)
			Audio.play_sfx("boss", -8.0, 0.9, 1.0)
		"shockwave":
			_cataclysm()
		"dice":
			_fate_gamble()
		"crescent":
			_judgement_rift()

# Soldier — Heavy Machine Gun: رشقة سريعة جداً (تُستدعى من _fire_step أثناء r_buff_t)
func _hmg_fire() -> void:
	var ni := _nearest_enemy()
	if ni < 0:
		return
	var dir := (Vector2(enemies[ni]["pos"]) - pp).normalized().rotated(rng.randf_range(-0.05, 0.05))
	bullets.append({"pos": pp, "vel": dir * bullet_speed * 1.15, "life": 1.0, "pierce": pierce + 1, "bounce": 0,
		"side": false, "exec": false, "rult": true, "dmg": bullet_dmg * 1.5 * _sigm()})
	Audio.play_sfx("shoot", -16.0, 1.1, 1.25)

# Knight — Giant Blade: أرجوحة سيف عملاق (قوس عريض ~160°، مدى كبير) أثناء r_buff_t
func _giant_blade() -> void:
	var ni := _nearest_enemy()
	if ni < 0:
		return
	var ang := (Vector2(enemies[ni]["pos"]) - pp).angle()
	var reach := 165.0 * _area()
	var half := deg_to_rad(80.0)
	var dmg := bullet_dmg * 2.6 * _sigm()
	var reach2 := reach * reach
	for i in range(enemies.size() - 1, -1, -1):
		var e = enemies[i]
		var to := Vector2(e["pos"]) - pp
		var rr := reach + float(e["r"])
		if to.length_squared() > rr * rr:
			continue
		if absf(wrapf(to.angle() - ang, -PI, PI)) <= half:
			var isb := String(e["type"]) == "boss"
			damage_enemy(i, dmg * (0.5 if isb else 1.0), "slash")
	slash_fx.append({"pos": Vector2(pp), "ang": ang, "arc": half, "reach": reach, "life": 0.24, "max": 0.24, "giant": true})
	shake = maxf(shake, 2.0)
	Audio.play_sfx("hit", -6.0, 0.75, 0.9)

# Titan — Cataclysm Shockwave: كارثة فورية — تمسح العادي، تدفع النخبة، الزعيم ~27%
func _cataclysm() -> void:
	var R := 300.0 * _area()
	hitstop = maxf(hitstop, 0.12)
	shake = maxf(shake, 12.0)
	flash = minf(flash + 0.3, 0.7)
	_flash_msg(T("CATACLYSM SHOCKWAVE!"), 1.7)
	Audio.play_sfx("explode", -2.0, 0.5, 0.6)
	if rings.size() < 26:
		rings.append({"pos": Vector2(pp), "t": 0.0, "max": R, "col": Color(0.9, 0.7, 0.35)})
		rings.append({"pos": Vector2(pp), "t": 0.0, "max": R * 0.6, "col": Color(1.0, 0.85, 0.5)})
	for k in 22:
		var a := rng.randf() * TAU
		var d := rng.randf_range(30.0, R)
		parts.append({"pos": pp + Vector2(cos(a), sin(a)) * d, "vel": Vector2(cos(a), sin(a)) * rng.randf_range(40, 120),
			"life": rng.randf_range(0.4, 0.9), "sz": rng.randf_range(3, 7), "col": Color(0.7, 0.6, 0.45, 0.9)})
	var big := bullet_dmg * 4.0 * _sigm()
	var r2 := R * R
	for i in range(enemies.size() - 1, -1, -1):
		var e = enemies[i]
		var dv := Vector2(e["pos"]) - pp
		var rr := R + float(e["r"])
		if dv.length_squared() > rr * rr:
			continue
		var et := String(e["type"])
		if et == "boss":
			damage_enemy(i, big * 0.27, "rult")
		elif et == "elite":
			if dv.length() > 0.01:
				e["pos"] = Vector2(e["pos"]) + dv.normalized() * 120.0
			damage_enemy(i, big * 0.9, "rult")
		else:
			if dv.length() > 0.01:
				e["pos"] = Vector2(e["pos"]) + dv.normalized() * 70.0
			damage_enemy(i, big, "rult")

# Gambler — Fate Gamble: 50% بركة +40% ضرر / 50% لعنة -40% لمدة 30ث (بلا تراكم)
func _fate_gamble() -> void:
	_toast(T("FATE GAMBLE!"), 1.2)
	r_fate_good = rng.randf() < 0.5
	r_fate_mul = 1.4 if r_fate_good else 0.6
	r_fate_t = 30.0
	if r_fate_good:
		_flash_msg(T("FATE BLESSING! +40% DMG (30s)"), 2.0)
		_burst(pp, Balance.COL_REWARD, 24)
		if rings.size() < 26:
			rings.append({"pos": Vector2(pp), "t": 0.0, "max": 170.0, "col": Balance.COL_REWARD})
		Audio.play_sfx("levelup", 0.0, 1.2, 1.3)
	else:
		_flash_msg(T("FATE CURSE! -40% DMG (30s)"), 2.0)
		flash = minf(flash + 0.4, 0.7)
		Audio.play_sfx("hurt", -2.0, 0.7, 0.8)

# Shadow Assault الجاري: يقفز على الأهداف واحداً واحداً ويقطع (حصانة محفوظة أثناءه)
func _shadow_assault_step(dt: float) -> void:
	if sassault == null:
		return
	sassault["t"] = float(sassault["t"]) - dt
	if float(sassault["t"]) > 0.0:
		return
	var ix := int(sassault["i"])
	var tgs: Array = sassault["targets"]
	if ix >= tgs.size():
		sassault = null
		return
	var tp: Vector2 = tgs[ix]
	trail.append({"pos": Vector2(pp), "life": 0.3})
	pp = (tp + (pp - tp).normalized() * 30.0) if (pp - tp).length() > 1.0 else tp
	pp.x = clampf(pp.x, PR, WW - PR)
	pp.y = clampf(pp.y, PR, WH - PR)
	var dmg2 := float(sassault["dmg"])
	for j in range(enemies.size() - 1, -1, -1):
		var e = enemies[j]
		if Vector2(e["pos"]).distance_to(tp) < 60.0 + float(e["r"]):
			var isb := String(e["type"]) == "boss"
			damage_enemy(j, dmg2 * (0.5 if isb else 1.0), "slash")
	slash_fx.append({"pos": Vector2(tp), "ang": rng.randf() * TAU, "arc": PI, "reach": 60.0, "life": 0.16, "max": 0.16})
	_burst(tp, Color(0.6, 0.95, 0.8), 8)
	Audio.play_sfx("hit", -9.0, 1.3, 1.45)
	sassault["i"] = ix + 1
	sassault["t"] = float(sassault["step"])
	invuln = maxf(invuln, 0.2)

# Judgement Rift الجاري: بعد windup قصير تنفجر السلاشات المتعددة على المدى (الزعماء hits محدودة)
func _rift_step(dt: float) -> void:
	if rift == null:
		return
	rift["t"] = float(rift["t"]) - dt
	if not bool(rift["done"]) and float(rift["t"]) <= 0.0:
		rift["done"] = true
		var R: float = rift["r"]
		var dmg3: float = rift["dmg"]
		var rr2 := R * R
		shake = maxf(shake, 10.0)
		flash = minf(flash + 0.25, 0.7)
		hitstop = maxf(hitstop, 0.08)
		Audio.play_sfx("explode", -3.0, 0.7, 0.8)
		for i in range(enemies.size() - 1, -1, -1):
			if Vector2(enemies[i]["pos"]).distance_squared_to(pp) <= rr2:
				var isb := String(enemies[i]["type"]) == "boss"
				var hits := 1 if isb else 3
				var per := dmg3 * (0.5 if isb else 1.0)
				for h in hits:
					if i < enemies.size() and float(enemies[i]["hp"]) > 0.0:
						damage_enemy(i, per, "rift")
		rift["t"] = 0.4   # يخلّي مؤثر السلاشات ظاهر لحظة بعد الانفجار
	elif bool(rift["done"]) and float(rift["t"]) <= 0.0:
		rift = null

func _fire_step(dt: float) -> void:
	fire_cd -= dt
	# v1.2.5: Soldier Heavy Machine Gun — رشقة سريعة جداً أثناء الأولتيمت
	if sig == "rifle" and r_buff_t > 0.0:
		if fire_cd <= 0.0 and enemies.size() > 0:
			_hmg_fire()
			fire_cd = 0.05
		return
	# v1.2.5: Knight Giant Blade — أرجوحات ضخمة أثناء الأولتيمت
	if sig == "spinblade" and r_buff_t > 0.0:
		if fire_cd <= 0.0 and enemies.size() > 0:
			_giant_blade()
			fire_cd = 0.35
		return
	# v1.2: سلاح التوقيع بيحدد "الرماية" — Titan موجات، والهالة/الداش/السيوف بلا رصاص
	if sig == "shockwave":
		if fire_cd <= 0.0 and enemies.size() > 0:
			_titan_wave(pp, (155.0 + 6.0 * float(multishot)) * _area(), bullet_dmg * 1.3 * _sigm(), 46.0)
			fire_cd = maxf(0.9, fire_rate * 2.6)
		return
	# Pyromancer: كرات نار مدى متوسط، دقة أقل + Burn + انفجار كل 3 إصابات (منطق الإصابة في _bullet_step)
	if sig == "firebolt":
		if fire_cd <= 0.0 and enemies.size() > 0:
			_fire_bolt()
			fire_cd = fire_rate
		return
	# Shinobi: Crescent Slash — قوس قطع مدى قريب-متوسط بدل الاعتماد على الداش كسلاح
	if sig == "crescent":
		if fire_cd <= 0.0 and enemies.size() > 0:
			_crescent_slash()
			fire_cd = maxf(0.30, fire_rate)
		return
	if sig == "spinblade":
		return
	if fire_cd > 0.0:
		return
	var ni := _nearest_enemy()
	if ni < 0:
		return
	var dir: Vector2 = (enemies[ni]["pos"] - pp).normalized()
	if sig == "dice":
		dir = dir.rotated(rng.randf_range(-0.09, 0.09))   # النرد بيترمى مش بيتصوّب
	var spread := deg_to_rad(11.0)
	var start := -spread * (multishot - 1) * 0.5
	# Execution Core (Legendary): كل خامس رشقة ضررها مضاعف (نصفه ضد الزعماء)
	volley_i += 1
	var exec_hit := int(ups_count.get("exec", 0)) > 0 and volley_i % 5 == 0
	# v1.1: الطلقة المركزية فقط بكامل الضرر — الجانبية (Extra Volley/Rear) بـ50% و35% ضد الزعماء
	var center := (multishot - 1) / 2
	for k in multishot:
		var v := dir.rotated(start + spread * k) * bullet_speed
		bullets.append({"pos": pp, "vel": v, "life": 1.1, "pierce": pierce, "bounce": ric_n, "side": k != center, "exec": exec_hit, "dice": sig == "dice"})
	# حارس الظهر: طلقات للخلف (جانبية برضه)
	for k in rear_n:
		var rv := (-dir).rotated(deg_to_rad(rng.randf_range(-8.0, 8.0))) * bullet_speed
		bullets.append({"pos": pp, "vel": rv, "life": 1.1, "pierce": pierce, "bounce": ric_n, "side": true, "exec": exec_hit})
	Audio.play_sfx("shoot", -11.0, 0.9, 1.1)
	fire_cd = fire_rate

func _bullet_step(dt: float) -> void:
	var i := bullets.size() - 1
	while i >= 0:
		var b = bullets[i]
		b["pos"] += b["vel"] * dt
		b["life"] = float(b["life"]) - dt
		var dead := false
		# Blade Storm (تطوّر الكوناي): النصل بيرجع لإيدك ويقطع في طريق العودة
		if bool(b.get("kunai", false)) and evo_bladestorm:
			if not bool(b.get("ret", false)) and float(b["life"]) <= 0.35:
				b["ret"] = true
				b["life"] = 1.3
				b["vel"] = (pp - Vector2(b["pos"])).normalized() * bullet_speed * 1.1
			elif bool(b.get("ret", false)):
				b["vel"] = (pp - Vector2(b["pos"])).normalized() * bullet_speed * 1.1
				if Vector2(b["pos"]).distance_to(pp) < 26.0:
					dead = true
		var j := enemies.size() - 1
		while j >= 0:
			var e = enemies[j]
			var bp: Vector2 = b["pos"]
			var hitr := float(e["r"]) + 6.0 * bsize
			if bp.distance_squared_to(e["pos"]) < hitr * hitr:
				# ضرر لكل مقذوف: الجانبي 50% (و35% ضد الزعماء) · Execution Core ×2 (×1.5 ضد الزعماء)
				var eb := String(e["type"]) == "boss"
				var bd := bullet_dmg * _sigm()   # رصاص البندقية/النرد = سلاح توقيع
				var bsrc := "bullet"
				if b.has("dmg"):
					bd = float(b["dmg"])   # ضرر مخصص (كوناي — بلا Signature Core)
				if bool(b.get("kunai", false)):
					bsrc = "kunai"
					if bool(b.get("ret", false)):
						bd *= 0.75   # ضربة العودة أخف (Blade Storm بلا كسر)
				if bool(b.get("side", false)):
					bd *= 0.35 if eb else 0.5
					bsrc = "side"
				if bool(b.get("exec", false)):
					bd *= 1.5 if eb else 2.0
				# Pyromancer Fire Bolt: كل إصابة تكوّم Burn + كل 3 إصابات = انفجار (Inferno: كل طلقة تنفجر)
				var firebolt := bool(b.get("firebolt", false))
				var infernal := bool(b.get("infernal", false))
				var hitpos := Vector2(e["pos"])
				if bool(b.get("rult", false)) and eb:
					bd *= 0.5   # Heavy Machine Gun ضد الزعماء
				if firebolt:
					bsrc = "firebolt"
					_ignite(e, 1)
				damage_enemy(j, bd, bsrc)
				if infernal:
					_fire_explosion(hitpos, 80.0, bullet_dmg * 1.15 * _sigm(), 1)   # ~60% من قوة Fireball الـ Q
					if fire_patches.size() < 46 and rng.randf() < 0.5:
						fire_patches.append({"pos": hitpos, "life": 2.5})
				elif firebolt:
					fbolt_hits += 1
					if fbolt_hits % 3 == 0:
						_fire_explosion(hitpos, 62.0, bullet_dmg * 0.85 * _sigm(), 1)
				if int(b["pierce"]) > 0:
					b["pierce"] = int(b["pierce"]) - 1
				elif int(b["bounce"]) > 0:
					# ارتداد: وجّه المقذوف لأقرب عدو آخر
					var nb := -1
					var nbd := INF
					for j2 in enemies.size():
						if j2 == j:
							continue
						var d2: float = bp.distance_to(enemies[j2]["pos"])
						if d2 < 360.0 and d2 < nbd:
							nbd = d2
							nb = j2
					if nb >= 0:
						b["vel"] = (Vector2(enemies[nb]["pos"]) - bp).normalized() * bullet_speed
						b["bounce"] = int(b["bounce"]) - 1
						b["life"] = 0.9
					else:
						dead = true
				else:
					dead = true
				break
			j -= 1
		var bpos: Vector2 = b["pos"]
		var off := bpos.x < -30 or bpos.x > WW + 30 or bpos.y < -30 or bpos.y > WH + 30
		if dead or float(b["life"]) <= 0.0 or off:
			bullets.remove_at(i)
		i -= 1

func _orbit_blade_pos(k: int) -> Vector2:
	var a := orbit_ang + (TAU / float(maxi(1, orbit_n))) * k
	return pp + Vector2(cos(a), sin(a)) * orbit_radius

# التركيبات ذات المؤقّت الدوري (Arcane Orbit / Frost Pulse)
func _synergy_step(dt: float) -> void:
	if syn_active.has("arcane_orbit") and orbit_n > 0:
		syn_orbit_t -= dt
		if syn_orbit_t <= 0.0:
			syn_orbit_t = 1.4
			for k in orbit_n:
				var op := _orbit_blade_pos(k)
				var d := (op - pp)
				d = d.normalized() if d.length() > 0.01 else Vector2.RIGHT
				bullets.append({"pos": op, "vel": d * bullet_speed * 0.9, "life": 0.9, "pierce": 0, "bounce": 0})
			Audio.play_sfx("shoot", -14.0, 1.25, 1.4)
	if syn_active.has("frost_pulse"):
		syn_frost_t -= dt
		if syn_frost_t <= 0.0:
			syn_frost_t = 3.5
			var r2 := 210.0 * 210.0
			for e in enemies:
				if Vector2(e["pos"]).distance_squared_to(pp) <= r2:
					e["slow"] = maxf(float(e.get("slow", 0.0)), 1.6)
			if rings.size() < 26:
				rings.append({"pos": Vector2(pp), "t": 0.0, "max": 210.0, "col": Color(0.6, 0.85, 1.0)})
			Audio.play_sfx("zap", -11.0, 0.7, 0.8)

func _orbit_step(_dt: float) -> void:
	if orbit_n <= 0:
		return
	# Knight: سيوفه بتتقوى مع ضربه (سلاح توقيع مش إكسسوار) + Berserk ×1.5
	var odmg := ORBIT_DMG * (1.6 if evo_cyclone else 1.0)
	if sig == "spinblade":
		odmg = maxf(odmg, bullet_dmg * 1.15) * (1.5 if berserk_t > 0.0 else 1.0) * _sigm()
	for k in orbit_n:
		var bp := _orbit_blade_pos(k)
		var j := enemies.size() - 1
		while j >= 0:
			var e = enemies[j]
			var orr := float(e["r"]) + (14.0 if evo_cyclone else 10.0)
			if float(e["orbcd"]) <= 0.0 and bp.distance_squared_to(e["pos"]) < orr * orr:
				e["orbcd"] = 0.30 if berserk_t > 0.0 else 0.35
				# Thorn Halo / Bulwark Core: الأشواك بتزقّ الأعداء
				var kbp := (18.0 if evo_thalo else 0.0) + 8.0 * float(ups_count.get("bwall", 0))
				if kbp > 0.0 and String(e["type"]) != "boss":
					var kv2 := (Vector2(e["pos"]) - pp)
					if kv2.length() > 0.01:
						e["pos"] = Vector2(e["pos"]) + kv2.normalized() * kbp
				damage_enemy(j, odmg, "orbit")
			j -= 1

func _do_chain() -> void:
	# صاعقة: تضرب أقرب عدو وتتسلسل لمن حوله
	var chainlist := []
	var cur := pp
	var hops := 2 + chain_n + int(ups_count.get("conduct", 0))
	if evo_tstorm:
		hops += 3   # تطوّر Thunder Storm: قفزات أكتر وأوسع
	for step in hops:
		var best = null
		var bd := INF
		var rng_max := 520.0 if step == 0 else 210.0
		for e in enemies:
			if e in chainlist:
				continue
			var d: float = cur.distance_to(e["pos"])
			if d < rng_max and d < bd:
				bd = d
				best = e
		if best == null:
			break
		chainlist.append(best)
		cur = best["pos"]
	if chainlist.is_empty():
		return
	# رسم البرق (قبل الضرر — المواقع لسه صحيحة)
	var prev := pp
	for e in chainlist:
		var tgt: Vector2 = e["pos"]
		var pts := PackedVector2Array()
		pts.append(prev)
		var seg := 5
		for si in range(1, seg):
			var base := prev.lerp(tgt, float(si) / float(seg))
			var perp := (tgt - prev).normalized().rotated(PI * 0.5)
			pts.append(base + perp * rng.randf_range(-14.0, 14.0))
		pts.append(tgt)
		zaps.append({"pts": pts, "life": 0.20})
		prev = tgt
	Audio.play_sfx("zap", -5.0)
	var dmg := 38.0 + 6.0 * float(chain_n - 1)
	for e in chainlist:
		var idx := enemies.find(e)
		if idx >= 0:
			# Thunder Storm: الزعماء يقاومون البرق المتطوّر (ما يقتلهمش بسرعة مبالغ فيها)
			var cd2 := dmg * (0.6 if evo_tstorm and String(e["type"]) == "boss" else 1.0)
			damage_enemy(idx, cd2, "zap")
	chain_t = maxf(1.0, 2.6 - 0.25 * float(chain_n - 1)) * (0.72 if evo_tstorm else 1.0) * _cdr()

# انفجار عدو القنبلة (Bomber): ضرر منطقة على اللاعب لو قريب + تأثير بصري
func _bomber_boom(pos: Vector2) -> void:
	_burst(pos, Balance.COL_ENEMY_HI, 20)
	if rings.size() < 26:
		rings.append({"pos": pos, "t": 0.0, "max": 90.0, "col": Balance.COL_ENEMY_HI})
	shake = maxf(shake, 6.0)
	Audio.play_sfx("explode", -4.0)
	if invuln <= 0.0 and pp.distance_to(pos) < 78.0:
		_hurt(19.0 * _dmg_mul(), "bomber")   # معايرة: كانت 22 — القاتل الأول في القياسات
		flash = minf(1.0, flash + 0.5)
		invuln = maxf(invuln, 0.4)

func _explode(pos: Vector2, scale := 1.0) -> void:
	var radius := (62.0 + 16.0 * float(explode_n - 1)) * scale * _area()
	var dmg := bullet_dmg * (0.45 + 0.15 * float(explode_n - 1)) * scale
	_burst(pos, Color(1.0, 0.45, 0.10), int(14.0 * scale))
	Audio.play_sfx("explode", -6.0 - (4.0 if scale < 1.0 else 0.0))
	# قنابل عنقودية: كل انفجار رئيسي يولّد 3 انفجارات صغيرة
	if evo_cluster and scale >= 1.0:
		for k in 3:
			var a := rng.randf() * TAU
			_explode(pos + Vector2(cos(a), sin(a)) * rng.randf_range(50.0, 95.0), 0.5)
	var j := enemies.size() - 1
	while j >= 0:
		var e = enemies[j]
		if pos.distance_to(e["pos"]) < radius + float(e["r"]):
			# الزعماء يقاومون الانفجارات المتسلسلة (anti-cheese)
			var xd := dmg * (0.65 if String(e["type"]) == "boss" else 1.0)
			e["hp"] = float(e["hp"]) - xd
			stat_dmg_dealt += xd
			dps_bucket += xd
		j -= 1
	# جولة قتل لمن سقط بالانفجار (قد تتسلسل انفجارات)
	j = enemies.size() - 1
	while j >= 0:
		if j < enemies.size() and float(enemies[j]["hp"]) <= 0.0:
			_kill_enemy(j)
		j -= 1

# ---------- v1.2: قدرات Q ----------
func _use_q() -> void:
	q_cd = q_cd_max * _cdr()   # Focus بيقلل تبريد القدرة
	match sig:
		"rifle":
			q_turret = {"pos": Vector2(pp), "t": 8.0, "cd": 0.3}
			_toast(T("Turret deployed!"), 1.4)
			Audio.play_sfx("levelup", -8.0, 0.7, 0.75)
		"firebolt":
			_cast_fireball()
		"crescent":
			_shadow_assault()
		"spinblade":
			berserk_t = 5.0
			_toast(T("BERSERK!"), 1.4)
			Audio.play_sfx("boss", -10.0, 1.5, 1.6)
		"shockwave":
			_titan_wave(pp, 280.0 * _area(), bullet_dmg * 2.5 * _sigm(), 120.0)
			shake = maxf(shake, 8.0)
			Audio.play_sfx("explode", -4.0, 0.6, 0.65)
		"dice":
			_all_in_roll()

# All In Roll: مقامرة حقيقية — 1 كارثة … 6 جاكبوت. اللاعب ضغط بإرادته وفاهم المخاطرة
func _all_in_roll() -> void:
	roll_result = 1 + rng.randi() % 6
	roll_anim_t = 1.6
	match roll_result:
		1:  # كارثة: -20% من صحتك الحالية (عمرها ما تقتلك مباشرة)
			hp = maxf(1.0, hp - hp * 0.20)
			flash = minf(1.0, flash + 0.6)
			_flash_msg(T("CURSED ROLL! -20% HP"), 1.8)
			Audio.play_sfx("hurt", 0.0, 0.6, 0.65)
		2:
			g_dmg_mul = 0.85
			g_dmg_t = 8.0
			_flash_msg(T("BAD ROLL! -15% DMG (8s)"), 1.6)
			Audio.play_sfx("hurt", -6.0, 0.8, 0.85)
		3:
			g_dmg_mul = 1.15
			g_dmg_t = 8.0
			_flash_msg(T("LUCKY HIT! +15% DMG (8s)"), 1.6)
			Audio.play_sfx("gem", -4.0, 1.0, 1.1)
		4:
			g_crit_add = 0.25
			g_crit_t = 10.0
			_flash_msg(T("GOOD ROLL! +25% CRIT (10s)"), 1.6)
			Audio.play_sfx("gem", -3.0, 1.1, 1.2)
		5:
			g_dmg_mul = 1.40
			g_dmg_t = 8.0
			g_crit_add = 0.20
			g_crit_t = 8.0
			_flash_msg(T("BIG WIN! +40% DMG +20% CRIT (8s)"), 1.8)
			Audio.play_sfx("levelup", -3.0, 1.1, 1.2)
		6:  # جاكبوت: كل الضربات كريت 5 ثواني
			g_crit_add = 1.0
			g_crit_t = 5.0
			_flash_msg(T("JACKPOT! ALL CRITS (5s)"), 2.0)
			_burst(pp, Balance.COL_REWARD, 26)
			if rings.size() < 26:
				rings.append({"pos": Vector2(pp), "t": 0.0, "max": 180.0, "col": Balance.COL_REWARD})
			Audio.play_sfx("levelup", 1.0, 1.3, 1.4)

func _hurt(raw: float, src: String = "enemy") -> void:
	# Guardian Cube (v1.1.3): يمتص ضربة كاملة واحدة (المؤثرة بس، مش تكات التلامس) ثم يُعاد شحنه
	var gr := int(ups_count.get("guard", 0))
	if gr > 0 and guard_cd <= 0.0 and raw >= 8.0:
		guard_cd = 20.0 - 6.0 * float(gr - 1)
		no_dmg_t = 0.0   # الامتصاص برضه بيقطع شرط الـ Recovery (اتضربت فعلاً)
		if rings.size() < 26:
			rings.append({"pos": Vector2(pp), "t": 0.0, "max": 70.0, "col": Color(0.85, 0.92, 1.0)})
		_burst(pp, Color(0.85, 0.92, 1.0), 10)
		Audio.play_sfx("hit", -4.0, 1.6, 1.7)
		return
	# كل ضرر يمر من هنا — الدروع تخففه (src لتقرير المعايرة/سبب الموت)
	var f := raw * pow(0.92, float(armor_n))
	f *= pow(0.95, float(ups_count.get("bwall", 0)))   # Bulwark Core
	# Thorn Halo: بيليّن ضرر التلامس فقط (له سقف — مش حصانة)
	if evo_thalo and src.begins_with("contact"):
		f *= 0.85
	# Steel Plates Lv3+: أول ضربة تفعّل 1.5ث نص ضرر (كل 8ث) — دفاع تفاعلي مش رقم خام
	if int(ups_count.get("armor", 0)) >= 3 and plating_cd <= 0.0:
		plating_t = 1.5
		plating_cd = 8.0
	if plating_t > 0.0:
		f *= 0.5
	hp -= f
	no_dmg_t = 0.0   # أي ضرر يقطع شرط الـ Recovery (لازم 6ث هدوء)
	stat_dmg_taken += f
	last_hurt_src = src

# كل علاج يمرّ من هنا (Balance v1.1) — هوية الشخصية + الجرح + عقوبة الزعيم + سقوف المرحلة
# kind: "generic" | "regen" | "steal" | "reward" (مكافآت الزعيم/الكنز/الارتقاء — بلا عقوبة زعيم)
# بيرجع العلاج الفعلي المطبَّق (0 لو اتمنع)
func _heal(amount: float, kind: String = "generic") -> float:
	if amount <= 0.0 or wound_t > 0.0:
		return 0.0
	var a := amount * heal_mul
	var reward_like := kind == "reward" or kind == "levelup" or kind == "steal_boss"
	if boss_alive and not reward_like:
		if kind == "regen" or kind == "steal":
			return 0.0            # ممنوع Recovery/Soul Steal أثناء معركة الزعيم
		a *= asc_heal_boss        # باقي العلاج ينقص 50% (أو 65% في Danger II+)
	if kind == "regen":
		# Calibration v1.1.1: سقف مرحلة 6/9/12 (Burner: 10/14/18) + سقف صحة 50% (رتبة 3: 55%، Burner: 65%)
		var rr := clampi(regen_n, 1, 3)
		var cap := float([10, 14, 18][rr - 1] if char_steal_bonus else [6, 9, 12][rr - 1]) * asc_healcap
		a = minf(a, maxf(0.0, cap - stage_heal_regen))
		var hcap := maxhp * (0.65 if char_steal_bonus else (0.55 if regen_n >= 3 else 0.50))
		a = minf(a, maxf(0.0, hcap - hp))
		stage_heal_regen += a
	elif kind == "steal":
		# Calibration v1.1.1: سقف مرحلة 8/12 (Burner: 12/16)
		var sr := clampi(steal_n, 1, 2)
		var cap2 := float([12, 16][sr - 1] if char_steal_bonus else [8, 12][sr - 1]) * asc_healcap
		a = minf(a, maxf(0.0, cap2 - stage_heal_steal))
		stage_heal_steal += a
	if a <= 0.0:
		return 0.0
	var before := hp
	hp = minf(maxhp, hp + a)
	stat_heal[kind] = float(stat_heal.get(kind, 0.0)) + (hp - before)   # لتقرير المعايرة
	return hp - before

# ================================================================
#  الأحداث العشوائية
func _fire_event() -> void:
	# Polish v1.1.2: حدث الكنز المحروس اتشال مع الصناديق — حدثان: نيازك أو قطيع ذهبي
	var ev := rng.randi() % 2
	match ev:
		0:  # مطر نيازك
			for i in 9:
				var off := Vector2(rng.randf_range(-480, 480), rng.randf_range(-300, 300))
				var mpos := pp + off
				mpos.x = clampf(mpos.x, 60, WW - 60)
				mpos.y = clampf(mpos.y, 60, WH - 60)
				meteors.append({"pos": mpos, "t": 1.0 + float(i) * 0.35})
			Audio.play_sfx("boss", -6.0)
			_toast(T("Meteors incoming - run!"), 2.0)
		_:  # قطيع ذهبي
			for i in 10:
				enemies.append({
					"pos": _edge_pos(),
					"col": Color(1.0, 0.82, 0.25),
					"r": 10.0, "hp": 10.0 * _hp_mul() * 0.6, "maxhp": 10.0,
					"spd": rng.randf_range(140.0, 170.0),
					"type": "fast", "orbcd": 0.0, "gold": true,
				})
			Audio.play_sfx("gem", -4.0, 0.8, 0.8)
			_toast(T("A golden horde passes - hunt it!"), 2.2)

func _meteor_step(dt: float) -> void:
	var i := meteors.size() - 1
	while i >= 0:
		var mt = meteors[i]
		mt["t"] = float(mt["t"]) - dt
		if float(mt["t"]) <= 0.0:
			var mpos: Vector2 = mt["pos"]
			_burst(mpos, Color(1.0, 0.45, 0.10), 20)
			shake = minf(9.0, shake + 4.0)
			Audio.play_sfx("explode", -2.0)
			if invuln <= 0.0 and pp.distance_to(mpos) < 72.0 + PR:
				_hurt(26.0 * _dmg_mul(), "meteor")
				flash = minf(1.0, flash + 0.5)
			meteors.remove_at(i)
		i -= 1

func _trap_step(dt: float) -> void:
	var i := traps.size() - 1
	while i >= 0:
		var tp = traps[i]
		var dead := false
		if String(tp["k"]) == "spike":
			if not bool(tp["sprung"]):
				tp["warn"] = float(tp["warn"]) - dt / asc_trap   # Danger IV+: تحذير أقصر
				if float(tp["warn"]) <= 0.0:
					tp["sprung"] = true
					Audio.play_sfx("hit", -2.0, 0.7, 0.8)
					shake = minf(6.0, shake + 2.5)
					if invuln <= 0.0 and pp.distance_to(tp["pos"]) < 46.0:
						_hurt((24.0 if bool(tp.get("ice", false)) else 22.0) * _dmg_mul(), "spike trap")
						invuln = maxf(invuln, 0.35)
						flash = minf(1.0, flash + 0.5)
			else:
				tp["act"] = float(tp["act"]) - dt
				if float(tp["act"]) <= 0.0:
					dead = true
		elif String(tp["k"]) == "freeze":
			tp["warn"] = float(tp["warn"]) - dt / asc_trap
			if float(tp["warn"]) <= 0.0:
				if pp.distance_to(tp["pos"]) < 80.0:
					freeze_t = 0.8
					_hurt(8.0 * _dmg_mul(), "freeze trap")
					flash = minf(1.0, flash + 0.4)
					_toast(T("Frozen!"), 0.9)
					Audio.play_sfx("hurt", -4.0, 1.3, 1.4)
				_burst(Vector2(tp["pos"]), Color(0.8, 0.95, 1.0), 14)
				dead = true
		else:  # burn
			if not bool(tp.get("perm", false)):
				tp["life"] = float(tp.get("life", 1.0)) - dt
				if float(tp["life"]) <= 0.0:
					dead = true
			if not dead and invuln <= 0.0 and pp.distance_to(tp["pos"]) < 36.0:
				_hurt(16.0 * _dmg_mul() * dt, "burn trap")
				flash = minf(1.0, flash + dt * 2.5)
		if dead:
			traps.remove_at(i)
		i -= 1

func _hazard_step(dt: float) -> void:
	# مناطق الخطر الأرضية (نار الحمم / دوّامات الرمل)
	var i := hazards.size() - 1
	while i >= 0:
		var hz = hazards[i]
		hz["life"] = float(hz["life"]) - dt
		if pp.distance_to(hz["pos"]) < float(hz["r"]) + PR * 0.5:
			_hurt(float(hz["dps"]) * dt, "hazard")
			flash = minf(1.0, flash + dt * 2.0)
		if float(hz["life"]) <= 0.0:
			hazards.remove_at(i)
		i -= 1

func _aura_step(dt: float) -> void:
	if aura_r <= 0.0:
		return
	var j := enemies.size() - 1
	while j >= 0:
		var e = enemies[j]
		# Reach + Aura Core بيوسّعوا الهالة (v1.2)
		var aeff := aura_r * _area() * (1.0 + 0.15 * float(ups_count.get("acore", 0)))
		var ar2 := aeff + float(e["r"])
		if pp.distance_squared_to(e["pos"]) < ar2 * ar2:
			var adps := AURA_DPS * ((1.0 + bullet_dmg / 46.0) * _sigm() if sig == "fireaura" else 1.0)
			e["hp"] = float(e["hp"]) - adps * dt
			stat_dmg_dealt += adps * dt
			dps_bucket += adps * dt
			# سلاح Fire Aura: الوقوف جوه الهالة بيكوّم Burn stacks (بتفضل بتحرق بعد الخروج)
			if sig == "fireaura":
				e["burn_dps"] = minf(30.0, float(e.get("burn_dps", 0.0)) + 12.0 * dt)
				e["burn_t"] = 2.0
			# Aura Core: الهالة بتزقّ برفق (تحكم مساحة بدون علاج)
			var acr := int(ups_count.get("acore", 0))
			if acr > 0 and String(e["type"]) != "boss":
				var av := Vector2(e["pos"]) - pp
				if av.length() > 0.01:
					e["pos"] = Vector2(e["pos"]) + av.normalized() * 7.0 * float(acr) * dt
			if float(e["hp"]) <= 0.0:
				_kill_enemy(j)
		j -= 1

# ================================================================
#  GEMS / UPGRADES
func _drop_gem(pos: Vector2, val := 1) -> void:
	# فوق 130 بلورة: ادمج القيمة بدل إغراق الرسم والمنطق
	if gems.size() >= 130:
		var g = gems[rng.randi() % gems.size()]
		g["val"] = int(g.get("val", 1)) + val
		return
	gems.append({"pos": pos, "val": val})

func _gem_step(dt: float) -> void:
	var i := gems.size() - 1
	while i >= 0:
		var g = gems[i]
		var to: Vector2 = pp - g["pos"]
		var d := to.length()
		if vacuum_t > 0.0:
			g["pos"] += (to / maxf(d, 0.001)) * 760.0 * dt   # شفط بعد الزعيم
		elif d < magnet:
			g["pos"] += (to / maxf(d, 0.001)) * 440.0 * dt
		if d < PR + 8.0:
			var gval := int(g.get("val", 1))
			var gpos: Vector2 = g["pos"]
			gems.remove_at(i)
			run_gems += gval
			Audio.play_sfx("gem", -13.0, 0.95, 1.3)
			# pop صغير عند الجمع (إحساس مُرضٍ)
			if rings.size() < 26:
				rings.append({"pos": gpos, "t": 0.4, "max": 20.0, "col": Balance.COL_REWARD})
			_tip("gem", "Gold gems level you up — grab them!", 3.0)
			# Magnet Lv3+: كل 30 بلورة → +2 XP (اقتصاد مكتسَب مش رقم خام)
			if int(ups_count.get("magnet", 0)) >= 3:
				magnet_gems += gval
				if magnet_gems >= 30:
					magnet_gems -= 30
					xp_bank += 2.0 * meta_xp_mul
			# Magnetic Surge (v1.1.3): كل 30 بلورة → شفط شامل + نبضة صغيرة
			var msr := int(ups_count.get("msurge", 0))
			if msr > 0:
				msurge_gems += gval
				if msurge_gems >= 30:
					msurge_gems -= 30
					vacuum_t = maxf(vacuum_t, 0.8)
					pending_aoe.append({"pos": Vector2(pp), "r": 130.0 + 30.0 * float(msr), "dmg": maxf(8.0, bullet_dmg * 0.4)})
					if rings.size() < 26:
						rings.append({"pos": Vector2(pp), "t": 0.0, "max": 130.0 + 30.0 * float(msr), "col": Color(0.55, 0.8, 1.0)})
					Audio.play_sfx("gem", -8.0, 0.6, 0.7)
			# Growth: مضاعف XP مع بنك للكسور — + إنقاذ منتصف اللعبة (anti-stall v1.1.3)
			xp_bank += float(gval) * meta_xp_mul * _xp_catchup()
			var whole := int(xp_bank)
			xp_bank -= float(whole)
			xp += whole
			if xp >= xp_need:
				xp -= xp_need
				_enter_levelup()
		i -= 1

func _check_evolutions() -> void:
	# شرطا الاندماج: بركتان معينتان بمستوى كافٍ
	if evo_pending != "":
		return
	# Improvement Pass: التطوّر متاح من بعد أول زعيم (أو المرحلة 3 كحد أقصى) —
	# اللاعب الشاطر يلحق تطوّراً في أغلب الجولات القوية
	if stage < 3 and run_bosses < 1:
		return
	var c := ups_count
	if not evo_bladestorm and int(c.get("kunai", 0)) >= 4 and int(c.get("precision", 0)) >= 1:
		evo_pending = "ebladestorm"
	elif not evo_ewinter and int(c.get("frostorb", 0)) >= 4 and int(c.get("fcore", 0)) >= 1:
		evo_pending = "ewinter"
	elif not evo_meteor and int(c.get("bomb", 0)) >= 4 and int(c.get("gpow", 0)) >= 1:
		evo_pending = "emeteor"
	elif not evo_tstorm and int(c.get("chain", 0)) >= 4 and int(c.get("conduct", 0)) >= 1:
		evo_pending = "etstorm"
	elif not evo_thalo and int(c.get("orbit", 0)) >= 4 and int(c.get("bwall", 0)) >= 1:
		evo_pending = "ethalo"
	elif not evo_shatter and int(c.get("mark", 0)) >= 4 and int(c.get("ccore", 0)) >= 1:
		evo_pending = "eshatter"
	elif not evo_soulp and int(c.get("steal", 0)) >= 1 and int(c.get("acore", 0)) >= 1:
		evo_pending = "esoulp"
	elif not evo_frostrun and int(c.get("frtrail", 0)) >= 1 and int(c.get("score", 0)) >= 1:
		evo_pending = "efrost"

# يفحص تركيبات البركات: أي synergy اجتمعت شروطها ولمّا تتفعّل بعد → فعّلها
func _check_synergies() -> void:
	for syn in Balance.SYNERGIES:
		var id: String = syn["id"]
		if syn_active.has(id):
			continue
		var ok := true
		for req_id in syn["req"]:
			if int(ups_count.get(req_id, 0)) < int(syn["req"][req_id]):
				ok = false
				break
		if ok:
			_activate_synergy(syn)

func _activate_synergy(syn: Dictionary) -> void:
	var id: String = syn["id"]
	syn_active[id] = true
	# اكتشاف دائم (يُحفظ)
	if not syn_found.has(id):
		syn_found[id] = true
		_save_settings()
	# تأثيرات فورية وقت التفعيل
	match id:
		"chain_storm":
			chain_n += 1
			fire_rate = maxf(rate_floor, fire_rate * 0.9)
		"bulwark":
			armor_n = mini(7, armor_n + 2)
			maxhp += 30.0
			_heal(30.0, "reward")
		"overcharge":
			# Legendary-style: مقذوف إضافي لكن بثمن (-8% سرعة إطلاق) وداخل سقف الـ+3
			multishot = mini(4, multishot + 1)
			fire_rate = minf(1.2, fire_rate * 1.08)
	# رسالة + صوت + نبضة بصرية (اكتشاف واضح للاعب)
	_flash_msg(T("Synergy Unlocked: %s") % T(syn["name"]), 2.6)
	Audio.play_sfx("levelup", 1.0, 1.15, 1.25)
	if rings.size() < 26:
		rings.append({"pos": Vector2(pp), "t": 0.0, "max": 160.0, "col": Balance.COL_REWARD})
	_burst(pp, Balance.COL_REWARD, 16)

# هل اختيار هذه البركة سيُكمِل تركيبة غير مفعّلة؟ (لتلميح شاشة الترقية)
func _card_completes_synergy(bid: String) -> bool:
	for syn in Balance.SYNERGIES:
		if syn_active.has(syn["id"]):
			continue
		if not syn["req"].has(bid):
			continue
		var would := true
		for req_id in syn["req"]:
			var have := int(ups_count.get(req_id, 0))
			if req_id == bid:
				have += 1
			if have < int(syn["req"][req_id]):
				would = false
				break
		if would:
			return true
	return false

func _enter_levelup() -> void:
	level += 1
	xp_need = int(xp_need * 1.36) + 2   # v1.1: منحنى XP أبطأ شوية — البناء القوي مش ببلاش
	maxhp += 5.0
	_heal(10.0, "levelup")
	Audio.play_sfx("levelup", 0.0, 1.0, 1.0)
	# نبضة ارتقاء حول اللاعب + شرارات (feedback واضح)
	if rings.size() < 26:
		rings.append({"pos": Vector2(pp), "t": 0.0, "max": 130.0, "col": Balance.COL_YOU})
	_burst(pp, Balance.COL_YOU_HI, 14)
	# Synergy — Core Resonance: الارتقاء يطلق موجة تضرّ وتجذب الجواهر (مؤجّل لأمان الحلقة)
	if syn_active.has("core_resonance"):
		pending_aoe.append({"pos": Vector2(pp), "r": 190.0, "dmg": maxf(12.0, bullet_dmg * 1.2)})
		vacuum_t = maxf(vacuum_t, 1.4)
		if rings.size() < 26:
			rings.append({"pos": Vector2(pp), "t": 0.0, "max": 200.0, "col": Balance.COL_REWARD})
	_roll_levelup_cards()
	lv_title.text = T("LEVEL UP %d") % level
	lv_dim.visible = true
	state = ST_LEVELUP

# أوزان الندرة حسب المرحلة (v1.1.5): Rare من البداية، Epic بعد أول زعيم، Legendary من المرحلة 3
func _phase_weights() -> Array:
	return Balance.RARITY_W_STAGE[clampi(stage - 1, 0, Balance.RARITY_W_STAGE.size() - 1)]

# عدد بركات كل ندرة (يُحسب مرة) — عشان نسب الفئات تطلع زي الجدول المستهدف بالظبط
# (من غير القسمة دي: فئة فيها 10 بركات بتزاحم فئة فيها بركة واحدة والـ Legendary ما يظهرش أبداً)
var _rar_counts := []
func _rarity_count(rar: int) -> int:
	if _rar_counts.is_empty():
		_rar_counts = [0, 0, 0, 0]
		for u in UPS:
			_rar_counts[int(u["rar"])] += 1
	return maxi(1, int(_rar_counts[rar]))

# وزن كارت واحد = (وزن فئة ندرته في الطور ÷ حجم الفئة) × ميول الشخصية (bw) × حظها (luck_f)
func _card_weight(u: Dictionary) -> int:
	var pw: Array = _phase_weights()
	var w := float(pw[int(u["rar"])])
	if w <= 0.0:
		return 0
	w = w * 100.0 / float(_rarity_count(int(u["rar"])))
	if int(u["rar"]) >= 1:
		w *= luck_f   # Runner/Specter يشوفوا النادر أكتر شوية
	# هوية الشخصية: أقوى وسم مطابق (مضاعفات >1 تغلب، وإلا التخفيضات <1)
	var bw: Dictionary = CHARS[char_sel].get("bw", {})
	if not bw.is_empty() and u.has("tags"):
		var best := 1.0
		for t in u["tags"]:
			if bw.has(t):
				var f := float(bw[t])
				if absf(log(f)) > absf(log(best)):
					best = f
		w *= best
	# v1.2: تفضيلات الشخصية بالاسم (pw) — Soldier بيشوف Kunai/Chain أكتر إلخ
	w *= float(CHARS[char_sel].get("pw", {}).get(String(u["id"]), 1.0))
	# Improvement Pass: المملوك أولى بالتعميق — أي عنصر عندك وزن ترقيته أعلى
	var cnt2 := int(ups_count.get(u["id"], 0))
	if cnt2 > 0:
		w *= 1.35
	# سلاح قرب الـ Max → وزن ترقيته أعلى بكتير (بتقرّب من التطوّر)
	if String(u.get("slot", "")) == "weapon" and cnt2 == int(u["max"]) - 1:
		w *= 1.6
	# الباسيف الشريك: لو سلاحه مملوك وزنه أعلى، ولو سلاحه Max وزنه أعلى بكتير (يفتح التطوّر)
	if u.has("partner_of"):
		var wid := String(u["partner_of"])
		var wcnt := int(ups_count.get(wid, 0))
		if wcnt > 0:
			w *= 2.0 if wcnt >= 4 else 1.5
	return maxi(1, int(round(w)))

# v1.2 B/C: تخفيض التبريدات (Focus) — للـ Q والأسلحة الجانبية
func _cdr() -> float:
	return pow(0.92, float(ups_count.get("cdr", 0)))

# Signature Core: +15% لكل مستوى لضرر سلاح التوقيع فقط (مش الأسلحة الجانبية)
func _sigm() -> float:
	return 1.0 + 0.15 * float(ups_count.get("sigup", 0))

# v1.2 B/C: مضاعف المساحات (Reach) — هالة/انفجارات/موجات
func _area() -> float:
	return 1.0 + 0.12 * float(ups_count.get("area", 0))

# عدد الخانات المشغولة من نوع معيّن (weapon / passive)
func _slot_used(kind: String) -> int:
	var n := 0
	for u in UPS:
		if int(ups_count.get(u["id"], 0)) > 0 and String(u.get("slot", "passive")) == kind:
			n += 1
	return n

# pool مؤهّل: استبعد اللي وصل الحد الأقصى + Legendary قبل مرحلتها + وزن صفر في المرحلة
# + v1.2: نظام الخانات — الخانات المليانة تقفل العناصر الجديدة (الترقيات فقط)
func _eligible_pool() -> Array:
	var shoots := sig == "rifle" or sig == "dice"
	var wused := _slot_used("weapon")
	var pused := _slot_used("passive")
	var pool := []
	for u in UPS:
		var cnt := int(ups_count.get(u["id"], 0))
		if cnt >= int(u["max"]):
			continue
		if int(u.get("min_stage", 1)) > stage:
			continue
		if u.has("req_id") and int(ups_count.get(String(u["req_id"]), 0)) <= 0:
			continue
		# الخانات: عنصر جديد ما يظهرش لو خاناته مليانة (المملوك بيكمّل ترقياته عادي)
		if cnt == 0:
			var uslot := String(u.get("slot", "passive"))
			if uslot == "weapon" and wused >= Balance.SIDE_WEAPON_SLOTS:
				continue
			if uslot == "passive" and pused >= Balance.PASSIVE_SLOTS:
				continue
		# بركات المقذوفات/سرعة الإطلاق ما تظهرش لأصحاب الأسلحة غير النارية
		# (Kunai مستثنى — هو سلاح المدى التعويضي لشخصيات الالتحام)
		var utags: Array = u.get("tags", [])
		if not shoots and utags.has("Projectile") and String(u["id"]) != "kunai" and String(u["id"]) != "precision":
			continue
		if (sig == "crescent" or sig == "spinblade") and utags.has("FireRate"):
			continue
		if _card_weight(u) <= 0:
			continue
		pool.append(u)
	return pool

# اختيار موزون من الترقيات المؤهّلة (اللي لسه ماوصلتش max)
func _weighted_pick(pool: Array):
	var total := 0
	for u in pool:
		total += _card_weight(u)
	var r := rng.randi() % maxi(1, total)
	for u in pool:
		r -= _card_weight(u)
		if r < 0:
			return u
	return pool[0]

func _set_card_up(card: Dictionary, u: Dictionary) -> void:
	var rr := int(u["rar"])
	var rc: Color = Balance.RARITY_COL[rr]
	card["frame"].color = rc
	card["panel"].color = Color(0.09, 0.10, 0.15, 0.98)
	card["name"].text = T(u["name"])
	card["name"].add_theme_color_override("font_color", Color(1, 1, 1) if rr == 0 else rc.lightened(0.2))
	# الأيقونة بلون الندرة (الشائع يفضل فاتح محايد) — مع بدائل العناصر الجديدة
	var iid := String(u["id"])
	card["icon"].texture = SPR.get("bi_" + iid, SPR.get("bi_" + String(ICON_ALIAS.get(iid, "")), null))
	card["icon"].modulate = Color(0.88, 0.90, 0.96) if rr == 0 else rc.lightened(0.35)
	# v1.2: سطر النوع والمستوى — "Weapon Lv 2→3" / "Passive NEW" + ماركر مسار التطوّر
	var cnt3 := int(ups_count.get(String(u["id"]), 0))
	var ttxt := T("Weapon") if String(u.get("slot", "")) == "weapon" else T("Passive")
	if cnt3 > 0:
		ttxt += "  Lv %d→%d" % [cnt3, cnt3 + 1]
	else:
		ttxt += "  " + T("NEW")
	if u.has("tags") and (u["tags"] as Array).size() > 0:
		ttxt += " • " + T(String(u["tags"][0]))
	# مسار تطوّر: سلاح شريكه مملوك، أو باسيف شريك سلاحه مملوك، أو Synergy قديمة
	var evo_path := false
	if u.has("partner_of") and int(ups_count.get(String(u["partner_of"]), 0)) > 0:
		evo_path = true
	elif String(u.get("slot", "")) == "weapon":
		for u3 in UPS:
			if String(u3.get("partner_of", "")) == String(u["id"]) and int(ups_count.get(u3["id"], 0)) > 0:
				evo_path = true
				break
	if evo_path:
		ttxt += "  * " + T("Evolution path")
		card["tags"].add_theme_color_override("font_color", Balance.COL_REWARD)
	elif _card_completes_synergy(u["id"]):
		ttxt += "  * " + T("Synergy!")
		card["tags"].add_theme_color_override("font_color", Balance.COL_REWARD)
	else:
		card["tags"].add_theme_color_override("font_color", Balance.COL_TEXT_DIM)
	card["tags"].text = ttxt
	card["desc"].text = T(u["desc"])
	card["draw"].text = T(String(u.get("draw", "")))
	card["rar"].text = T(Balance.RARITY_NAME[rr])
	card["rar"].add_theme_color_override("font_color", rc)

func _set_card_evo(card: Dictionary, id: String) -> void:
	var ev = EVOS[id]
	var rc: Color = Balance.RARITY_COL[3]
	card["frame"].color = rc
	card["panel"].color = Color(0.16, 0.13, 0.05, 0.98)
	card["name"].text = "* " + T(ev["name"])
	card["name"].add_theme_color_override("font_color", rc)
	card["icon"].texture = SPR.get("bi_evo", null)
	card["icon"].modulate = rc.lightened(0.25)
	# سطر "قبل → بعد" بالذهبي (Lightning Chain → Thunder Storm)
	card["tags"].add_theme_color_override("font_color", rc)
	card["tags"].text = String(ev.get("from", T("Evolution")))
	card["desc"].text = T(ev["desc"])
	card["draw"].text = ""
	card["rar"].text = T("EVOLUTION!")
	card["rar"].add_theme_color_override("font_color", rc)

func _roll_levelup_cards() -> void:
	lv_choices.clear()
	var pool := _eligible_pool()
	var evo_first := evo_pending != ""       # الكرت الأول تطوّر ذهبي لو جاهز
	# هوية الجندي (Calibration v1.1.1): أول ارتقاء له يعرض 4 اختيارات — بداية مريحة للمبتدئ
	var ncards := 4 if (char_sel == 0 and level == 2 and not evo_first) else 3
	var picks := []
	var need := ncards - (1 if evo_first else 0)
	# v1.1.5: تركيبة مقصودة بالفئات — كارت أساس + كارت تأثير/محرّك + كارت حر
	# Improvement Pass: أول 3 ارتقاءات بيتصدّرها سلاح — البناء بيبدأ من أول دقيقة
	var slots := ["Foundation", "FX", "Any", "Any"]
	if level <= 4:
		slots = ["WPN", "FX", "Any", "Any"]
	for si in need:
		if pool.is_empty():
			break
		var sub := []
		match String(slots[mini(si, slots.size() - 1)]):
			"Foundation":
				for u2 in pool:
					if String(u2.get("cat", "Foundation")) == "Foundation":
						sub.append(u2)
			"FX":
				for u2 in pool:
					var c2 := String(u2.get("cat", ""))
					if c2 == "Effect" or c2 == "Engine":
						sub.append(u2)
			"WPN":
				for u2 in pool:
					if String(u2.get("slot", "")) == "weapon" or String(u2["id"]) == "sigup":
						sub.append(u2)
			_:
				sub = pool
		if sub.is_empty():
			sub = pool   # الفئة خلصت → أي بركة مؤهلة
		var pk = _weighted_pick(sub)
		picks.append(pk)
		pool.erase(pk)
	for i in ncards:
		var card = lv_cards[i]
		if i == 0 and evo_first:
			_set_card_evo(card, evo_pending)
			lv_choices.append(evo_pending)
		else:
			var pi := i - (1 if evo_first else 0)
			if pi < picks.size():
				_set_card_up(card, picks[pi])
				lv_choices.append(picks[pi]["id"])
			else:
				# احتياطي نادر (كل الترقيات وصلت max): صحة إضافية
				_set_card_up(card, {"id": "hp", "name": "Toughness", "desc": "+20 max HP and heal 15", "rar": 0})
				lv_choices.append("hp")
	_layout_lv_cards(ncards)
	var keys_txt := "[1/2/3/4] choose" if ncards == 4 else "[1/2/3] choose"
	lv_hint.text = (T("[R] Reroll (%d)") % rerolls + "   •   " + T(keys_txt)) if rerolls > 0 else T(keys_txt)
	# عرض الخانات + رنّة مميزة لو فيه كارت تطوّر
	lv_slots.text = T("Weapons") + " %d/%d   •   " % [_slot_used("weapon"), Balance.SIDE_WEAPON_SLOTS] + T("Passives") + " %d/%d" % [_slot_used("passive"), Balance.PASSIVE_SLOTS]
	if evo_first:
		Audio.play_sfx("levelup", 0.0, 0.7, 0.72)

# ---------- مكافأة الزعيم (v1.1.5) — اختيار مقصود بدل صندوق عشوائي ----------
# زعيم 1: عمّق بركة مملوكة / خد Rare تأثير / +1 Reroll
# زعيم 2: نفس الفكرة لكن المرشّح Epic (بناء حقيقي)
# زعيم 3+: لو شروط تطوّر متحققة → كارت Evolution، وإلا دعم Epic
func _enter_boss_reward() -> void:
	boss_reward_active = true
	_roll_boss_reward()
	lv_title.text = T("BOSS REWARD")
	lv_dim.visible = true
	state = ST_LEVELUP

func _roll_boss_reward() -> void:
	lv_choices.clear()
	var bossnum := stage - 1   # الزعيم اللي لسه ساقط
	var pool := _eligible_pool()
	var cards := []
	# سلوت 1: التطوّر لو جاهز (من الزعيم الثاني) — أكتر لحظة مثيرة ممكنة
	var evo_slot := bossnum >= 2 and evo_pending != ""
	# سلوت "عمّق مسارك": بركة مملوكة لسه ما وصلتش حدّها
	var owned := []
	for u in pool:
		if int(ups_count.get(u["id"], 0)) > 0:
			owned.append(u)
	if not owned.is_empty():
		cards.append(owned[rng.randi() % owned.size()])
	# سلوت "مرشّح البناء": Rare تأثير بعد أول زعيم، وEpic من الزعيم الثاني
	if not evo_slot:
		var cand := []
		for u in pool:
			if cards.has(u):
				continue
			var c := String(u.get("cat", ""))
			if bossnum <= 1 and int(u["rar"]) == 1 and c != "Foundation":
				cand.append(u)
			elif bossnum >= 2:
				if int(u["rar"]) >= 2:
					cand.append(u)
				# v1.2: الباسيف الشريك لسلاح مملوك = مرشّح ذهبي بعد الزعيم الثاني (بيقرّب التطوّر)
				elif u.has("partner_of") and int(ups_count.get(String(u["partner_of"]), 0)) > 0:
					cand.append(u)
					cand.append(u)   # وزن مضاعف
		if cand.is_empty():
			for u in pool:
				if not cards.has(u) and String(u.get("cat", "")) != "Foundation":
					cand.append(u)
		if not cand.is_empty():
			cards.append(_weighted_pick(cand))
	# تعبئة الكروت: [تطوّر أو مملوكة] + [مرشّح] + [فرصة تانية]
	var ci := 0
	if evo_slot:
		_set_card_evo(lv_cards[0], evo_pending)
		lv_choices.append(evo_pending)
		ci = 1
	for pk in cards:
		if ci >= 2:
			break
		_set_card_up(lv_cards[ci], pk)
		lv_choices.append(pk["id"])
		ci += 1
	while ci < 2:
		_set_card_up(lv_cards[ci], {"id": "hp", "name": "Toughness", "desc": "+20 max HP and heal 15", "rar": 0})
		lv_choices.append("hp")
		ci += 1
	_set_card_up(lv_cards[2], RRBONUS)
	lv_choices.append("rrbonus")
	_layout_lv_cards(3)
	lv_hint.text = T("[1/2/3] choose")
	lv_slots.text = T("Weapons") + " %d/%d   •   " % [_slot_used("weapon"), Balance.SIDE_WEAPON_SLOTS] + T("Passives") + " %d/%d" % [_slot_used("passive"), Balance.PASSIVE_SLOTS]
	if evo_slot:
		Audio.play_sfx("levelup", 0.0, 0.7, 0.72)

# احتفال التطوّر: رسالة كبيرة + انفجار ذهبي + صوت مميز (لحظة الجولة)
func _evolve_fx(nm: String) -> void:
	evo_pending = ""
	_flash_msg(T("EVOLUTION!") + " " + T(nm), 2.6)
	_burst(pp, Balance.COL_REWARD, 30)
	if rings.size() < 26:
		rings.append({"pos": Vector2(pp), "t": 0.0, "max": 220.0, "col": Balance.COL_REWARD})
	hitstop = maxf(hitstop, 0.12)
	Audio.play_sfx("levelup", 2.0, 0.75, 0.8)
	Audio.play_sfx("zap", -4.0, 0.6, 0.65)

func _apply_upgrade(id: String) -> void:
	# تطوّرات (اندماج بركتين)
	match id:
		"ebladestorm":
			evo_bladestorm = true
			_evolve_fx("Blade Storm")
			return
		"ewinter":
			evo_ewinter = true
			_evolve_fx("Eternal Winter")
			return
		"emeteor":
			evo_meteor = true
			fmeteor_cd = 2.0
			_evolve_fx("Meteor Fall")
			return
		"etstorm":
			evo_tstorm = true
			_evolve_fx("Thunder Storm")
			return
		"ethalo":
			evo_thalo = true
			orbit_n += 1
			orbit_radius = 95.0
			_evolve_fx("Thorn Halo")
			return
		"eshatter":
			evo_shatter = true
			_evolve_fx("Shatter Mark")
			return
		"esoulp":
			evo_soulp = true
			_evolve_fx("Soul Pulse")
			return
		"efrost":
			evo_frostrun = true
			_evolve_fx("Frost Runner")
			return
		"rrbonus":
			rerolls += 1
			_flash_msg(T("+1 Reroll!"), 1.2)
			Audio.play_sfx("levelup", -2.0, 1.1, 1.2)
			return
	ups_count[id] = int(ups_count.get(id, 0)) + 1
	_check_evolutions()
	_check_synergies()
	match id:
		"dmg":    bullet_dmg += 10.0
		"rate":   fire_rate = maxf(rate_floor, fire_rate * 0.85)
		"multi":
			# سقف صلب: أقصى مقذوفات من البركات +3 (2 Extra Volley + 1 Overcharge)
			multishot = mini(4, multishot + 1)
			fire_rate = minf(1.2, fire_rate * 1.10)   # الـ drawback: -10% سرعة إطلاق
		"pierce": pierce += 1
		"orbit":  orbit_n += 1
		"aura":   aura_r = 70.0 if aura_r <= 0.0 else aura_r + 26.0
		"crit":   crit = minf(crit_cap, crit + 0.10)
		"speed":  pspeed = minf(speed_cap, pspeed * 1.12)
		"hp":     maxhp += 30.0; _heal(20.0, "reward")
		"magnet": magnet *= 1.5
		"dash":   dash_cd_max = maxf(0.6, dash_cd_max * 0.8)
		"chain":  chain_n += 1
		"explode": explode_n += 1
		"ric":    ric_n += 1
		"rear":   rear_n += 1
		"regen":  regen_n += 1
		"armor":  armor_n = mini(7, armor_n + 1)
		"steal":  steal_n = mini(2, steal_n + 1)
		"slow":   slow_n += 1
		"big":    bsize = minf(2.2, bsize * 1.25)
		"heavy":
			# Heavy Core: ضرر كبير بثمن واضح — مفيش x2 دائم مجاني
			bullet_dmg *= 1.40
			fire_rate = minf(1.2, fire_rate * 1.12)
			pspeed *= 0.92
		"score":
			# Speed Core: سرعة + داش أخف (شريك Frost Runner)
			pspeed = minf(speed_cap, pspeed * 1.06)
			dash_cd_max *= 0.92
		"precision":
			crit = minf(crit_cap, crit + 0.05)
		"ccore":
			crit = minf(crit_cap, crit + 0.06)
		"bossdmg", "pulse", "exec", "kunai", "frostorb", "bomb", "cdr", "area", "fcore", "gpow", "conduct", "bwall", "acore", "sigup":
			pass   # تُقرأ رتبتها من ups_count وقت الاستخدام

# ================================================================
#  FEEL
func _flash_msg(t: String, dur: float = 1.1) -> void:
	lbl_msg.text = t
	lbl_msg.visible = true
	_msg_t = dur

# رسالة ثانوية صغيرة أسفل الشاشة — للتلميحات والأحداث الجانبية (مش وسط الشاشة)
func _toast(t: String, dur: float = 2.2) -> void:
	lbl_toast.text = t
	lbl_toast.visible = true
	_toast_t = dur

# تنظيف كل رسائل/مؤقّتات القتال — يُستدعى عند مغادرة اللعب لأي شاشة تانية
# (يمنع تسرّب WOUNDED أو أي نص قتالي فوق القوائم)
func _clear_combat_ui() -> void:
	_msg_t = 0.0
	lbl_msg.visible = false
	_toast_t = 0.0
	lbl_toast.visible = false
	lbl_wound.visible = false
	stage_intro_t = 0.0
	hp_flash_t = 0.0

# تلميح تعليمي يظهر مرة واحدة فقط (لو التلميحات مفعّلة) — توست صغير مش نص وسط الشاشة
func _tip(id: String, key: String, dur: float = 2.6) -> void:
	if not tips_on or tips_seen.has(id):
		return
	tips_seen[id] = true
	_save_settings()
	_toast(T(key), dur + 0.6)

func _dmgnum(pos: Vector2, n: int, col: Color, big: bool = false) -> void:
	if not dmgnum_on:
		return   # إعداد: إخفاء أرقام الضرر
	dmgnums.append({"pos": pos, "life": 0.7, "txt": str(n), "col": col, "big": big})
	if dmgnums.size() > 24:
		dmgnums.remove_at(0)

func _part_step(dt: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= dt
		if _msg_t <= 0.0:
			lbl_msg.visible = false
	if _toast_t > 0.0:
		_toast_t -= dt
		if _toast_t <= 0.0:
			lbl_toast.visible = false
	hp_flash_t = maxf(0.0, hp_flash_t - dt)
	stage_intro_t = maxf(0.0, stage_intro_t - dt)
	var i := parts.size() - 1
	while i >= 0:
		var p = parts[i]
		p["pos"] += p["vel"] * dt
		p["vel"] *= 0.90
		p["life"] = float(p["life"]) - dt
		if float(p["life"]) <= 0.0:
			parts.remove_at(i)
		i -= 1
	i = trail.size() - 1
	while i >= 0:
		var t = trail[i]
		t["life"] = float(t["life"]) - dt
		if float(t["life"]) <= 0.0:
			trail.remove_at(i)
		i -= 1
	i = dmgnums.size() - 1
	while i >= 0:
		var dn = dmgnums[i]
		dn["pos"] += Vector2(0, -46.0 * dt)
		dn["life"] = float(dn["life"]) - dt
		if float(dn["life"]) <= 0.0:
			dmgnums.remove_at(i)
		i -= 1
	i = zaps.size() - 1
	while i >= 0:
		var z = zaps[i]
		z["life"] = float(z["life"]) - dt
		if float(z["life"]) <= 0.0:
			zaps.remove_at(i)
		i -= 1
	i = rings.size() - 1
	while i >= 0:
		var rg = rings[i]
		rg["t"] = float(rg["t"]) + dt * 3.4
		if float(rg["t"]) >= 1.0:
			rings.remove_at(i)
		i -= 1

func _burst(pos: Vector2, col: Color, amount: int) -> void:
	amount = mini(amount, maxi(0, 230 - parts.size()))
	for i in amount:
		var a := rng.randf() * TAU
		var sp := rng.randf_range(60.0, 260.0)
		parts.append({
			"pos": pos, "vel": Vector2(cos(a), sin(a)) * sp,
			"life": rng.randf_range(0.25, 0.55), "col": col,
			"sz": rng.randf_range(3.0, 7.0),
		})

# --- VFX منظّمة (wrappers واضحة فوق نظام الجزيئات/الحلقات) ---
func spawn_hit_spark(pos: Vector2, col: Color) -> void:
	# شرارة إصابة خفيفة جداً (2 جزيء) — الـ cap بيحمي الأداء في الزحمة
	if parts.size() < 210:
		for i in 2:
			var a := rng.randf() * TAU
			parts.append({"pos": pos, "vel": Vector2(cos(a), sin(a)) * rng.randf_range(70.0, 150.0),
				"life": rng.randf_range(0.12, 0.22), "col": col, "sz": rng.randf_range(2.0, 4.0)})

# مجموع البركات المأخوذة في الجولة (ملخّص البِلد)
func _blessing_count() -> int:
	var c := 0
	for k in ups_count:
		c += int(ups_count[k])
	return c

# نص الإنجازات المكتسبة (للعرض على شاشة النهاية)
func _achievement_lines(got: Array) -> String:
	var txt := ""
	for a in got:
		txt += "\n" + (T("* %s  (+%d Cinders)") % [T(a["name"]), int(a.get("reward", 0))])
		if a.has("unlock"):
			txt += "  " + (T("— %s unlocked!") % T(a["unlock"]))
	return txt

# Revival / Second Wind: إحياء لمرة واحدة عند الموت — 40% صحة + مسح الأعداء (مش البوس)
func _do_revive() -> void:
	revive_ready = false
	hp = maxhp * 0.4
	invuln = 1.6
	var kept := []
	for e in enemies:
		if String(e.get("type", "")) == "boss":
			kept.append(e)
		else:
			_burst(e["pos"], Color(1, 1, 1), 6)
	enemies = kept
	ebullets.clear(); hazards.clear(); meteors.clear()
	wipe_t = 1.0
	shake = 10.0
	Audio.play_sfx("sweep", 0.0, 1.0, 1.0)
	_flash_msg(T("SECOND WIND!"), 1.8)

# تقرير معايرة داخلي يُطبع في الكونسول آخر كل جولة (للتوازن فقط — مش UI للاعب)
func _debug_run_summary(victory: bool) -> void:
	var total_tiers := 0
	var owned := 0
	for m in Balance.META_SHOP:
		total_tiers += (m["costs"] as Array).size()
		owned += mini(_tier(String(m["id"])), (m["costs"] as Array).size())
	var bl := []
	for id in ups_count:
		bl.append("%s x%d" % [id, int(ups_count[id])])
	var syns := []
	for id2 in syn_active:
		syns.append(String(id2))
	var evos := []
	if evo_bladestorm: evos.append("BladeStorm")
	if evo_ewinter: evos.append("EternalWinter")
	if evo_meteor: evos.append("MeteorFall")
	if evo_tstorm: evos.append("ThunderStorm")
	if evo_thalo: evos.append("ThornHalo")
	if evo_shatter: evos.append("ShatterMark")
	if evo_soulp: evos.append("SoulPulse")
	if evo_frostrun: evos.append("FrostRunner")
	var bt := []
	for b in boss_times:
		bt.append("%s: %.0fs" % [String(b["name"]), float(b["secs"])])
	print("=== RUN SUMMARY: %s ===" % ("VICTORY" if victory else "DEATH"))
	print("  char=%s  danger=%d  stage=%d  time=%.0fs  kills=%d  bosses=%d  cinders=+%d" %
		[CHARS[char_sel]["name"], asc, mini(stage, FINAL_STAGE), gametime, kills, run_bosses, last_cinders])
	print("  meta upgrades: %d/%d tiers (%.0f%%)" % [owned, total_tiers, 100.0 * float(owned) / float(maxi(1, total_tiers))])
	print("  blessings: %s" % (", ".join(bl) if bl.size() > 0 else "-"))
	print("  synergies: %s" % (", ".join(syns) if syns.size() > 0 else "-"))
	print("  evolutions: %s" % (", ".join(evos) if evos.size() > 0 else "-"))
	print("  dmg dealt=%.0f  taken=%.0f  peak DPS=%.0f/s" % [stat_dmg_dealt, stat_dmg_taken, stat_max_dps])
	print("  healing: soul_steal=%.0f (+boss %.0f)  recovery=%.0f  levelup=%.0f  rewards=%.0f  other=%.0f" %
		[float(stat_heal.get("steal", 0.0)), float(stat_heal.get("steal_boss", 0.0)),
		float(stat_heal.get("regen", 0.0)), float(stat_heal.get("levelup", 0.0)),
		float(stat_heal.get("reward", 0.0)), float(stat_heal.get("generic", 0.0))])
	print("  death cause: %s" % ("-" if victory else last_hurt_src))
	print("  boss fights: %s" % (" | ".join(bt) if bt.size() > 0 else "-"))

func _game_over() -> void:
	state = ST_OVER
	hitstop = 0.0
	Audio.play_sfx("death", 2.0, 1.0, 1.0)
	Audio.stop_music()
	var was_rec_k := rec_kills
	var was_rec_t := rec_time
	_update_records(false)
	_award_cinders(false)
	_debug_run_summary(false)
	var got := _check_achievements(false)
	var m := int(gametime) / 60
	var s := int(gametime) % 60
	var rec_txt := ""
	if kills > was_rec_k or gametime > was_rec_t:
		rec_txt = T("\nNEW RECORD!")
	go_title.text = T("YOU DIED")
	go_stats.text = T("Kills: %d      Level: %d      Stage: %d      Survived: %02d:%02d\nBest combo: x%d%s") % [kills, level, stage, m, s, combo_best, rec_txt]
	go_stats.text += "\n" + (T("Blessings: %d") % _blessing_count())
	go_stats.text += "\n" + (T("+%d Cinders   (Total: %d)") % [last_cinders, cinders])
	go_stats.text += _achievement_lines(got)
	go_stats.text += "\n" + T("Spend Cinders on permanent upgrades — [U] in the menu")
	go_stats.text += "\n\n" + T("[R] New Run      [M] Menu")
	go_dim.visible = true

# ================================================================
#  DECOR
func _rpos() -> Vector2:
	return Vector2(rng.randf_range(30, WW - 30), rng.randf_range(30, WH - 30))

func _gen_decor() -> void:
	# أرضية بكسل آرت لكل فصل + ديكور متوهج + فخاخ الفصل
	_gen_tiles()
	decor.clear()
	traps.clear()
	trap_t = 6.0
	var ti := theme_idx()
	# Golden Collapse: رُقَع حارقة ثابتة موزعة على الفصل (بعيدة عن نقطة البداية)
	if ti == 3:
		for i in 20:
			var bp2 := _rpos()
			if bp2.distance_to(WC) < 240.0:
				bp2 = WC + (bp2 - WC).normalized() * 320.0
			traps.append({"k": "burn", "pos": bp2, "perm": true})
	match ti:
		0:  # Verdant Grid — عُقد شبكة خضراء نابضة + جسيمات بيانات طافية
			for i in 22:
				decor.append({"k": "gridnode", "pos": _rpos(), "ph": rng.randf() * TAU, "s": rng.randf_range(3.5, 6.0)})
			for i in 30:
				decor.append({"k": "mote", "pos": _rpos(), "ph": rng.randf() * TAU, "col": Color(0.45, 0.90, 0.60)})
		1:  # Crimson Pressure — شقوق ضغط حمراء + جمرات + شظايا زاويّة
			for i in 22:
				decor.append({"k": "vein", "pts": _crack_pts(_rpos(), 6), "col": Color(0.95, 0.32, 0.20)})
			for i in 40:
				decor.append({"k": "ember", "pos": _rpos(), "s": rng.randf_range(2.0, 4.0), "ph": rng.randf() * TAU, "col": Color(1.0, 0.42, 0.22)})
			for i in 14:
				decor.append({"k": "shard", "pos": _rpos(), "s": rng.randf_range(6.0, 12.0), "rot": rng.randf() * TAU, "col": Color(0.72, 0.26, 0.22)})
		2:  # Frozen Expanse — شقوق صقيع سماوية + بريق + ثلج متساقط بطيء
			for i in 24:
				decor.append({"k": "icecrack", "pts": _crack_pts(_rpos(), 5)})
			for i in 30:
				decor.append({"k": "spark", "pos": _rpos(), "s": rng.randf_range(2.5, 4.5)})
			for i in 24:
				decor.append({"k": "snow", "pos": _rpos(), "ph": rng.randf() * TAU})
		3:  # Golden Collapse — شقوق كهرمانية متوهّجة + جمرات ذهبية + حطام
			for i in 24:
				decor.append({"k": "vein", "pts": _crack_pts(_rpos(), 6), "col": Color(0.98, 0.72, 0.26)})
			for i in 40:
				decor.append({"k": "ember", "pos": _rpos(), "s": rng.randf_range(2.0, 4.5), "ph": rng.randf() * TAU, "col": Color(1.0, 0.80, 0.35)})
			for i in 16:
				decor.append({"k": "drock", "pos": _rpos(), "s": rng.randf_range(10.0, 20.0)})
		_:  # The Core — سدُم + نجوم كبيرة + عُقد فساد متوهّجة (نهائي، تباين عالٍ)
			for i in 7:
				var nc: Color = [Color(0.45, 0.25, 0.70), Color(0.25, 0.30, 0.65), Color(0.60, 0.20, 0.55)][rng.randi() % 3]
				decor.append({"k": "nebula", "pos": _rpos(), "s": rng.randf_range(130.0, 280.0), "col": nc})
			for i in 16:
				decor.append({"k": "bigstar", "pos": _rpos(), "s": rng.randf_range(4.0, 7.0), "ph": rng.randf() * TAU})
			for i in 12:
				decor.append({"k": "corenode", "pos": _rpos(), "ph": rng.randf() * TAU, "s": rng.randf_range(5.0, 9.0)})

func _gen_tiles() -> void:
	# 3 بلاطات 16×16 لكل ثيم بهوية بصرية مميزة (motif مخبوز): أرضية غامقة هادئة + نقش خفيف
	# القاعدة: الأرضية تتراجع للخلف دائماً؛ الأنماط خفيفة ولا تنافس اللاعب/الأعداء/المقذوفات.
	tile_tex.clear()
	var ti := theme_idx()
	for v in 3:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				img.set_pixel(x, y, _tile_pixel(ti, v))
		match ti:
			0:  # Verdant Grid — شبكة رقمية خضراء متّصلة عبر البلاطات + عُقد متوهّجة
				_tile_grid(img, Color8(40, 78, 54), Color8(30, 58, 42))
				if v == 2:
					_tile_node(img, Color8(70, 150, 96), Color8(30, 70, 46))
			1:  # Crimson Pressure — خطوط ضغط قُطرية حادّة + شقّ متوهّج أحمر
				if v >= 1:
					_tile_diag(img, Color8(96, 34, 30), v == 2)
				if v == 2:
					_tile_vein_c(img, Color8(168, 58, 40), Color8(104, 34, 24))
			2:  # Frozen Expanse — عروق صقيع + شظايا بلّورية + رُقَع ثلج خفيفة
				if v == 1:
					_tile_frost(img, Color8(126, 168, 204), Color8(158, 196, 226))
				if v == 2:
					_tile_facet(img, Color8(104, 140, 176))
				_tile_specks(img, Color8(190, 214, 236), 3)
			3:  # Golden Collapse — هندسة مكسورة + شقوق كهرمانية متوهّجة
				if v >= 1:
					_tile_fracture(img, Color8(150, 108, 44))
				if v == 2:
					_tile_vein_c(img, Color8(216, 156, 56), Color8(150, 108, 44))
			_:  # The Core — ظلام مع دوائر فساد + عُقد كهربائية خافتة (تباين عالٍ)
				if v == 2:
					_tile_node(img, Color8(120, 72, 164), Color8(52, 30, 82))
				_tile_specks(img, Color8(96, 72, 140), 2)
		tile_tex.append(ImageTexture.create_from_image(img))

func _tile_pixel(ti: int, v: int) -> Color:
	# أرضيات غامقة هادئة تتراجع للخلف (تباين خفيف، بلا نقط ساطعة) عشان الأعداء والبطل يبانوا
	var density := 0.05 if v == 0 else 0.12
	var r := rng.randf()
	match ti:
		0:  # Verdant Grid — أخضر رقمي غامق
			var c := Color8(28, 48, 36)
			if r < density: c = Color8(24, 42, 31)
			elif r < density * 2.0: c = Color8(34, 56, 42)
			return c
		1:  # Crimson Pressure — أحمر داكن متوتّر
			var c := Color8(48, 22, 22)
			if r < density: c = Color8(40, 18, 18)
			elif r < density * 2.0: c = Color8(58, 28, 26)
			return c
		2:  # Frozen Expanse — أزرق إردوازي بارد غامق (مش أبيض)
			var c := Color8(42, 56, 74)
			if r < density: c = Color8(36, 48, 64)
			elif r < density * 2.0: c = Color8(50, 66, 86)
			return c
		3:  # Golden Collapse — حجر كهرماني غامق
			var c := Color8(46, 34, 16)
			if r < density: c = Color8(39, 28, 13)
			elif r < density * 1.7: c = Color8(56, 42, 20)
			return c
		_:  # The Core — أسود بنفسجي بنجوم خافتة
			var c := Color8(11, 9, 17)
			if r < density: c = Color8(7, 6, 12)
			if v > 0 and rng.randf() < 0.012:
				var b := rng.randf_range(0.30, 0.55)
				c = Color(b * 0.7, b * 0.35, b)
			return c
	return Color.BLACK

# ---- رسّامو نقوش البلاط (16×16، مخبوزة مرة واحدة) ----
func _tile_grid(img: Image, edge: Color, edge2: Color) -> void:
	# خط علوي + أيسر → شبكة متّصلة عند التجاور (خلايا 16px)
	for i in 16:
		img.set_pixel(i, 0, edge)
		img.set_pixel(0, i, edge)
		if i % 2 == 0:
			img.set_pixel(i, 1, edge2)
			img.set_pixel(1, i, edge2)

func _tile_node(img: Image, col: Color, border: Color) -> void:
	# عقدة صغيرة متوهّجة في المنتصف
	for yy in range(6, 10):
		for xx in range(6, 10):
			img.set_pixel(xx, yy, border)
	for yy in range(7, 9):
		for xx in range(7, 9):
			img.set_pixel(xx, yy, col)

func _tile_diag(img: Image, col: Color, dense: bool) -> void:
	# خطوط قُطرية للضغط
	var step := 6 if dense else 8
	for y in 16:
		for x in 16:
			if (x + y) % step == 0:
				img.set_pixel(x, y, col)

func _tile_facet(img: Image, col: Color) -> void:
	# شظيتان بلّوريتان قصيرتان (زوايا كريستال)
	for i in 6:
		img.set_pixel(clampi(3 + i, 0, 15), clampi(4 + i, 0, 15), col)
		img.set_pixel(clampi(12 - i, 0, 15), clampi(3 + i, 0, 15), col)

func _tile_specks(img: Image, col: Color, n: int) -> void:
	for i in n:
		img.set_pixel(rng.randi_range(1, 14), rng.randi_range(1, 14), col)

func _tile_frost(img: Image, main_c: Color, hi_c: Color) -> void:
	# عرق صقيع متعرّج + تفرّع قصير (بلّوري بارد)
	var x := rng.randi_range(3, 12)
	for y in 16:
		img.set_pixel(clampi(x, 0, 15), y, main_c)
		if y % 4 == 0:
			img.set_pixel(clampi(x + 1, 0, 15), y, hi_c)
			img.set_pixel(clampi(x - 1, 0, 15), y, hi_c)
		x = clampi(x + rng.randi_range(-1, 1), 1, 14)

func _tile_fracture(img: Image, col: Color) -> void:
	# 3 قطع خطوط زاويّة مكسورة
	var dxs := [1, 1, -1]
	var dys := [1, -1, 1]
	for seg in 3:
		var x := rng.randi_range(2, 13)
		var y := rng.randi_range(2, 13)
		var dx: int = dxs[seg]
		var dy: int = dys[seg]
		for i in rng.randi_range(3, 6):
			img.set_pixel(clampi(x, 0, 15), clampi(y, 0, 15), col)
			x += dx; y += dy

func _tile_vein_c(img: Image, main_c: Color, side_c: Color) -> void:
	# عرق متوهّج عمودي متعرّج بلون معطى
	var x := rng.randi_range(3, 12)
	for y in 16:
		img.set_pixel(x, y, main_c)
		if rng.randf() < 0.5:
			img.set_pixel(clampi(x + (1 if rng.randf() < 0.5 else -1), 0, 15), y, side_c)
		x = clampi(x + rng.randi_range(-1, 1), 1, 14)

# ---------- أيقونات البركات (Polish v1.1.2) ----------
# أيقونة بكسل 16×16 بيضاء من دالة شكل هندسي — تتلوّن على الكارت بلون الندرة
func _icon_tex(test: Callable) -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var p := Vector2(float(x) - 7.5, float(y) - 7.5)
			if bool(test.call(p)):
				img.set_pixel(x, y, Color(1, 1, 1, 1))
	return ImageTexture.create_from_image(img)

# رمز بصري بسيط لكل بركة — يقرأه اللاعب في لحظة قبل ما يقرأ النص
func _gen_blessing_icons() -> void:
	SPR["bi_dmg"] = _icon_tex(func(p: Vector2): return (absf(p.x) <= 1.6 and p.y > -3.0 and p.y < 6.0) or (p.y >= -7.0 and p.y <= -2.0 and absf(p.x) <= (p.y + 7.5) * 0.9))
	SPR["bi_rate"] = _icon_tex(func(p: Vector2): return absf(p.y) <= 5.0 and ((p.x >= -6.0 and p.x <= -1.0 and absf(absf(p.y) - (-(p.x + 6.0) + 5.0)) <= 1.1) or (p.x >= 0.0 and p.x <= 5.0 and absf(absf(p.y) - (-p.x + 5.0)) <= 1.1)))
	SPR["bi_speed"] = _icon_tex(func(p: Vector2): return (absf(p.y + 4.0) <= 0.9 and p.x >= -6.0 and p.x <= 2.0) or (absf(p.y) <= 0.9 and p.x >= -4.0 and p.x <= 5.5) or (absf(p.y - 4.0) <= 0.9 and p.x >= -6.0 and p.x <= 1.0))
	SPR["bi_hp"] = _icon_tex(func(p: Vector2): return (absf(p.x) <= 1.8 and absf(p.y) <= 5.5) or (absf(p.y) <= 1.8 and absf(p.x) <= 5.5))
	SPR["bi_magnet"] = _icon_tex(func(p: Vector2): return (p.length() >= 2.6 and p.length() <= 5.6 and p.y <= 1.5) or (p.y > 1.5 and p.y <= 5.5 and (absf(p.x - 4.0) <= 1.4 or absf(p.x + 4.0) <= 1.4)))
	SPR["bi_regen"] = _icon_tex(func(p: Vector2): return (p - Vector2(-2.6, -2.0)).length() <= 2.9 or (p - Vector2(2.6, -2.0)).length() <= 2.9 or (p.y >= -1.5 and p.y <= 6.0 and absf(p.x) <= (6.0 - p.y) * 0.75))
	SPR["bi_pierce"] = _icon_tex(func(p: Vector2): return (absf(p.y) <= 1.2 and p.x >= -6.5 and p.x <= 3.0) or (p.x >= 2.0 and p.x <= 6.8 and absf(p.y) <= (6.8 - p.x)) or (absf(p.x + 1.0) <= 1.0 and absf(p.y) <= 5.5))
	SPR["bi_crit"] = _icon_tex(func(p: Vector2): return (absf(p.x) <= 1.1 or absf(p.y) <= 1.1 or absf(absf(p.x) - absf(p.y)) <= 1.0) and (absf(p.x) + absf(p.y)) <= 8.0)
	SPR["bi_dash"] = _icon_tex(func(p: Vector2): return (absf(p.y) <= 1.3 and p.x >= -6.5 and p.x <= 2.0) or (p.x >= 1.0 and p.x <= 6.8 and absf(p.y) <= (6.8 - p.x)))
	SPR["bi_armor"] = _icon_tex(func(p: Vector2): return p.y >= -5.5 and p.y <= 6.0 and absf(p.x) <= (4.8 if p.y < 1.0 else maxf(0.0, 4.8 * (1.0 - (p.y - 1.0) / 5.2))))
	SPR["bi_ric"] = _icon_tex(func(p: Vector2): return absf(p.x) <= 6.0 and absf(p.y - (absf(p.x) * 0.9 - 3.0)) <= 1.3)
	SPR["bi_rear"] = _icon_tex(func(p: Vector2): return (absf(p.y) <= 1.3 and p.x <= 6.5 and p.x >= -2.0) or (p.x <= -1.0 and p.x >= -6.8 and absf(p.y) <= (p.x + 6.8)))
	SPR["bi_big"] = _icon_tex(func(p: Vector2): return p.length() <= 5.5)
	SPR["bi_bossdmg"] = _icon_tex(func(p: Vector2): return (p.y >= 2.0 and p.y <= 5.0 and absf(p.x) <= 5.5) or (p.y >= -5.5 and p.y < 2.0 and (absf(p.x + 4.0) <= (p.y + 5.5) * 0.45 or absf(p.x) <= (p.y + 5.5) * 0.45 or absf(p.x - 4.0) <= (p.y + 5.5) * 0.45)))
	SPR["bi_pulse"] = _icon_tex(func(p: Vector2): return absf(p.length() - 6.2) <= 0.9 or absf(p.length() - 2.8) <= 0.9)
	SPR["bi_multi"] = _icon_tex(func(p: Vector2): return absf(p.y) <= 4.5 and (absf(p.x + 4.5) <= 1.2 or absf(p.x) <= 1.2 or absf(p.x - 4.5) <= 1.2))
	SPR["bi_steal"] = _icon_tex(func(p: Vector2): return (p - Vector2(0.0, 2.2)).length() <= 3.8 or (p.y >= -6.5 and p.y < 2.2 and absf(p.x) <= (p.y + 6.5) * 0.42))
	SPR["bi_orbit"] = _icon_tex(func(p: Vector2): return p.length() <= 1.8 or absf(p.length() - 5.4) <= 0.8 or (p - Vector2(3.8, -3.8)).length() <= 1.9)
	SPR["bi_aura"] = _icon_tex(func(p: Vector2): return p.length() <= 2.3 or absf(p.length() - 5.6) <= 0.9)
	SPR["bi_chain"] = _icon_tex(func(p: Vector2): return absf(p.y) <= 6.5 and ((p.y < 0.0 and absf(p.x - (p.y * 0.5 + 1.4)) <= 1.4) or (p.y >= 0.0 and absf(p.x - (p.y * 0.5 - 1.4)) <= 1.4)))
	SPR["bi_explode"] = _icon_tex(func(p: Vector2): return (absf(p.x) + absf(p.y)) <= 2.6 or ((absf(p.x) <= 1.0 or absf(p.y) <= 1.0 or absf(absf(p.x) - absf(p.y)) <= 1.0) and p.length() >= 3.4 and p.length() <= 7.0))
	SPR["bi_slow"] = _icon_tex(func(p: Vector2): return (absf(p.x) <= 0.8 or absf(p.y) <= 0.8 or absf(absf(p.x) - absf(p.y)) <= 0.8) and p.length() <= 6.2 and p.length() >= 1.0)
	SPR["bi_heavy"] = _icon_tex(func(p: Vector2): return (p.y >= -1.0 and p.y <= 5.0 and absf(p.x) <= 5.2) or (p.y >= -5.5 and p.y < -1.0 and absf(p.x) <= 2.2))
	SPR["bi_exec"] = _icon_tex(func(p: Vector2): return absf(absf(p.x) - absf(p.y)) <= 1.4 and absf(p.x) <= 6.0 and absf(p.y) <= 6.0)
	SPR["bi_evo"] = _icon_tex(func(p: Vector2): return absf(p.x * p.y) <= 2.2 and (absf(p.x) + absf(p.y)) <= 8.0)
	# --- أيقونات بركات v1.1.3 ---
	SPR["bi_frtrail"] = _icon_tex(func(p: Vector2): return (absf(p.y) <= 1.2 and p.x >= -1.0 and p.x <= 2.0) or (p.x >= 1.5 and p.x <= 6.6 and absf(p.y) <= (6.6 - p.x)) or (p - Vector2(-3.2, 0.0)).length() <= 1.3 or (p - Vector2(-6.0, 0.0)).length() <= 1.0)
	SPR["bi_mark"] = _icon_tex(func(p: Vector2): return absf(p.length() - 5.2) <= 0.9 or p.length() <= 1.6 or (absf(p.x) <= 0.8 and absf(p.y) >= 3.2 and absf(p.y) <= 7.2) or (absf(p.y) <= 0.8 and absf(p.x) >= 3.2 and absf(p.x) <= 7.2))
	SPR["bi_msurge"] = _icon_tex(func(p: Vector2): return (p.length() >= 2.4 and p.length() <= 5.0 and p.y <= 1.2) or (p.y > 1.2 and p.y <= 4.8 and (absf(p.x - 3.6) <= 1.3 or absf(p.x + 3.6) <= 1.3)) or (absf(p.length() - 7.0) <= 0.7 and p.y < -1.0))
	SPR["bi_bbreak"] = _icon_tex(func(p: Vector2): return (p.y >= 2.0 and p.y <= 4.6 and absf(p.x) <= 5.2) or (p.y >= -5.0 and p.y < 2.0 and (absf(p.x + 3.8) <= (p.y + 5.0) * 0.42 or absf(p.x) <= (p.y + 5.0) * 0.42 or absf(p.x - 3.8) <= (p.y + 5.0) * 0.42)) or (absf(p.x + p.y) <= 0.9 and absf(p.x) <= 7.0))
	SPR["bi_soulp"] = _icon_tex(func(p: Vector2): return (p - Vector2(0.0, 1.4)).length() <= 2.9 or (p.y >= -4.6 and p.y < 1.4 and absf(p.x) <= (p.y + 4.6) * 0.45) or absf(p.length() - 6.8) <= 0.7)
	SPR["bi_guard"] = _icon_tex(func(p: Vector2): return (absf(p.x) <= 4.8 and absf(p.y) <= 4.8 and not (absf(p.x) <= 2.6 and absf(p.y) <= 2.6)) or p.length() <= 1.4)
	# --- أيقونات v1.1.5 ---
	SPR["bi_shard"] = _icon_tex(func(p: Vector2): return (absf(p.x) + absf(p.y)) <= 2.2 or (absf(p.x - 4.0) + absf(p.y + 3.5)) <= 1.8 or (absf(p.x + 4.2) + absf(p.y + 2.5)) <= 1.8 or (absf(p.x - 2.5) + absf(p.y - 4.0)) <= 1.8 or (absf(p.x + 3.0) + absf(p.y - 4.0)) <= 1.8)
	SPR["bi_closecall"] = _icon_tex(func(p: Vector2): return (absf(p.x) <= 1.3 and p.y >= -6.5 and p.y <= 1.5) or (p - Vector2(0.0, 4.8)).length() <= 1.6)
	SPR["bi_rrbonus"] = _icon_tex(func(p: Vector2): return (absf(p.length() - 5.0) <= 1.0 and not (p.y < -1.5 and p.x > 1.5)) or (p - Vector2(4.6, -2.8)).length() <= 2.0)
	# --- أيقونات أسلحة v1.2 B/C ---
	SPR["bi_kunai"] = _icon_tex(func(p: Vector2): return absf(p.y - p.x * 0.0) <= (1.2 if p.x < 2.0 else (6.0 - p.x) * 0.9) and p.x >= -6.5 and p.x <= 6.0 and absf(p.y) <= 2.4)
	SPR["bi_bomb"] = _icon_tex(func(p: Vector2): return (p - Vector2(0.0, 1.2)).length() <= 4.8 or (absf(p.x - 2.6) <= 0.9 and p.y >= -6.2 and p.y <= -3.0))

# أيقونات بديلة للعناصر الجديدة اللي شكلها قريب من عنصر موجود (توفير بدون فقدان وضوح)
const ICON_ALIAS := {
	"frostorb": "slow", "fcore": "slow", "gpow": "explode", "conduct": "chain",
	"bwall": "armor", "ccore": "crit", "acore": "aura", "score": "speed",
	"cdr": "dash", "area": "pulse", "precision": "mark",
}

func _shape_tex(sz: int, test: Callable) -> ImageTexture:
	# يرسم شكلاً هندسياً كسبرايت بكسل: تعبئة رمادية بتظليل + خط تحديد أسود
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in sz:
		for x in sz:
			var p := Vector2(float(x) - sz * 0.5 + 0.5, float(y) - sz * 0.5 + 0.5)
			if bool(test.call(p)):
				var g := 0.85
				if p.y < -sz * 0.18:
					g = 1.0
				elif p.y > sz * 0.22:
					g = 0.62
				img.set_pixel(x, y, Color(g, g, g, 1.0))
	# خط التحديد (بيبيّن العدو على أي أرضية)
	var edges := []
	for y in sz:
		for x in sz:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + off.x
				var ny: int = y + off.y
				if nx >= 0 and nx < sz and ny >= 0 and ny < sz and img.get_pixel(nx, ny).a > 0.5:
					edges.append(Vector2i(x, y))
					break
	for e2 in edges:
		img.set_pixel(e2.x, e2.y, Color(0.04, 0.04, 0.07, 1.0))
	return ImageTexture.create_from_image(img)

func _gen_sprites() -> void:
	_gen_blessing_icons()   # أيقونات كروت البركات (Polish v1.1.2)
	# v1.2 Phase A: جسم مميّز لكل ناجٍ — silhouette مقروء حتى وهو صغير وسط الزحمة
	SPR["hero0"] = _shape_tex(16, func(p: Vector2) -> bool:   # Soldier: مكعب بفيزور أفقي
		return absf(p.x) < 6.4 and absf(p.y) < 6.4 and not (p.y > -3.0 and p.y < -1.4 and absf(p.x) < 4.6))
	SPR["hero1"] = _shape_tex(16, func(p: Vector2) -> bool:   # Fire Aura: مكعب بشق بركاني مائل
		return absf(p.x) < 6.4 and absf(p.y) < 6.4 and not (absf(p.x - p.y * 0.55) < 0.9 and absf(p.y) < 5.2))
	SPR["hero2"] = _shape_tex(16, func(p: Vector2) -> bool:   # Shinobi: مربع نينجا بحواف مشطوفة حادة
		return absf(p.x) < 6.2 and absf(p.y) < 6.2 and absf(p.x) + absf(p.y) < 10.2)
	SPR["hero3"] = _shape_tex(16, func(p: Vector2) -> bool:   # Knight: مكعب مدرّع بأكتاف وفيزور
		return absf(p.x) < 6.4 and absf(p.y) < 6.4 and not (p.y < -4.8 and absf(p.x) > 4.6) and not (p.y > -2.6 and p.y < -1.2 and absf(p.x) < 3.8))
	SPR["hero4"] = _shape_tex(16, func(p: Vector2) -> bool:   # Titan: عريض وثقيل بحواف مشطوفة
		return absf(p.x) < 7.4 and absf(p.y) < 5.9 and absf(p.x) + absf(p.y) < 11.6)
	SPR["hero5"] = _shape_tex(16, func(p: Vector2) -> bool:   # Gambler: نرد بحواف ناعمة
		return absf(p.x) < 6.1 and absf(p.y) < 6.1 and p.length() < 7.4)
	SPR["norm"] = _shape_tex(16, func(p: Vector2) -> bool:
		return p.length() < 6.2)
	SPR["fast"] = _shape_tex(16, func(p: Vector2) -> bool:
		return p.x > -6.0 and p.x < 7.0 and absf(p.y) < (7.0 - p.x) * 0.55)
	SPR["tank"] = _shape_tex(16, func(p: Vector2) -> bool:
		# مثمّن ثقيل (مميّز عن المربّع والدائرة)
		return absf(p.x) < 6.4 and absf(p.y) < 6.4 and absf(p.x) + absf(p.y) < 9.2)
	SPR["split"] = _shape_tex(16, func(p: Vector2) -> bool:
		return (p + Vector2(3.2, 0)).length() < 4.5 or (p - Vector2(3.2, 0)).length() < 4.5)
	SPR["shooter"] = _shape_tex(16, func(p: Vector2) -> bool:
		# جسم مربّع + سبطانة يمين = عدو يطلق
		return (absf(p.x) < 5.0 and absf(p.y) < 5.2) or (p.x > 3.5 and p.x < 8.0 and absf(p.y) < 1.8))
	SPR["bomber"] = _shape_tex(16, func(p: Vector2) -> bool:
		# كرة شوكية (burr) = خطر متفجّر
		return p.length() < 5.2 + cos(p.angle() * 8.0) * 1.7)
	SPR["elite"] = _shape_tex(20, func(p: Vector2) -> bool:
		if p.length() < 7.6:
			return true
		# تاج فوق الرأس — زعيم صغير
		return p.y < -6.0 and p.y > -9.4 and absf(p.x) < 7.0 and absf(fposmod(p.x + 10.0, 4.6) - 2.3) < 1.1)
	SPR["boss0"] = _shape_tex(26, func(p: Vector2) -> bool:
		if p.length() < 7.5:
			return true
		for k in 6:
			var a := TAU * float(k) / 6.0
			if (p - Vector2(cos(a), sin(a)) * 9.0).length() < 3.7:
				return true
		return false)
	SPR["boss1"] = _shape_tex(26, func(p: Vector2) -> bool:
		# جمجمة عظام: رأس دائري + فك + عيون مفرّغة
		if (p + Vector2(3.2, 1.8)).length() < 2.1 or (p - Vector2(3.2, -1.8)).length() < 2.1:
			return false   # عيون
		if p.length() < 8.6 and p.y < 4.0:
			return true    # الرأس
		return absf(p.x) < 5.2 and p.y >= 4.0 and p.y < 9.5 and absf(fposmod(p.x + 6.0, 3.0) - 1.5) > 0.4)
	SPR["boss2"] = _shape_tex(26, func(p: Vector2) -> bool:
		return absf(p.x) < 9.5 and absf(p.x) * 0.5 + absf(p.y) * 0.9 < 9.8)
	SPR["boss3"] = _shape_tex(26, func(p: Vector2) -> bool:
		var d := p.length()
		if d < 7.2:
			return true
		var a := absf(fposmod(p.angle(), TAU / 8.0) - TAU / 16.0)
		return d < 12.0 - a * 22.0)
	SPR["boss4"] = _shape_tex(26, func(p: Vector2) -> bool:
		return (p + Vector2(2.6, 0)).length() < 8.2 or (p - Vector2(2.6, 0)).length() < 8.2)
	SPR["boss5"] = _king_tex()
	SPR["hero"] = _shape_tex(16, func(p: Vector2) -> bool:
		return absf(p.x) < 6.4 and absf(p.y) < 6.4 and absf(p.x) + absf(p.y) < 11.2)
	SPR["ebul"] = _gen_ball_tex()   # كرة قذيفة العدو (نرسمها كـ texture واحدة بدل 3 دوائر — أرخص بكتير)
	SPR["vignette"] = _gen_vignette()   # تعتيم أطراف الشاشة (يريّح العين ويركّز على المنتصف)

func _gen_vignette() -> ImageTexture:
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var c := float(n - 1) * 0.5
	for y in n:
		for x in n:
			var dx := (float(x) - c) / c
			var dy := (float(y) - c) / c
			var d := sqrt(dx * dx + dy * dy)          # 0 بالمنتصف .. ~1.41 بالركن
			var a := clampf((d - 0.60) / 0.80, 0.0, 1.0)
			a = a * a * 0.55                          # منحنى ناعم، أقصى تعتيم ~0.55
			img.set_pixel(x, y, Color(1, 1, 1, a))    # أبيض + alpha → يتلوّن بالـ modulate حسب المرحلة
	return ImageTexture.create_from_image(img)

# لون فينييت الأطراف لكل مرحلة (غامق = يعتّم + يميّز الهوية بلمسة خفيفة)
func _stage_title() -> String:
	return T(Balance.STAGE_TITLES[clampi(theme_idx(), 0, Balance.STAGE_TITLES.size() - 1)])

# لون فينييت الأطراف لكل مرحلة (غامق = يعتّم + يميّز الهوية بلمسة خفيفة)
func _stage_vignette() -> Color:
	match theme_idx():
		0: return Color(0.05, 0.11, 0.06)   # 1 Verdant — أخضر غامق
		1: return Color(0.13, 0.05, 0.05)   # 2 Crimson — أحمر غامق
		2: return Color(0.06, 0.09, 0.14)   # 3 (جليد/بنفسجي) — أزرق-بنفسجي غامق
		3: return Color(0.14, 0.09, 0.03)   # 4 Golden — كهرماني غامق
		_: return Color(0.09, 0.03, 0.10)   # 5 Core — بنفسجي/أسود عالي التباين
	return Color(0.02, 0.02, 0.04)

func _gen_ball_tex() -> ImageTexture:
	# كرة: قلب أبيض ساطع + جسم + خط تحديد غامق — تتلوّن بالـ modulate.
	# رسمها كـ texture مجمّعة أرخص بكثير من draw_circle المصمتة المتكررة.
	var sz := 32
	var R := 16.0
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	for y in sz:
		for x in sz:
			var d := Vector2(float(x) - sz * 0.5 + 0.5, float(y) - sz * 0.5 + 0.5).length()
			if d < R * 0.40:
				img.set_pixel(x, y, Color(1, 1, 1, 1))            # قلب ساطع
			elif d < R - 3.0:
				img.set_pixel(x, y, Color(0.90, 0.90, 0.92, 1))   # جسم
			elif d < R:
				img.set_pixel(x, y, Color(0.05, 0.05, 0.08, 1))   # خط تحديد غامق
	return ImageTexture.create_from_image(img)

func _king_tex() -> ImageTexture:
	# ملك الرماد: نجمة بنفسجية بحواف ذهبية + تاج ذهبي — ألوان مدموجة في السبرايت
	var sz := 34
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var purple := Color(0.52, 0.28, 0.80)
	var purple_hi := Color(0.68, 0.42, 0.95)
	var gold := Color(0.95, 0.78, 0.22)
	for y in sz:
		for x in sz:
			var p := Vector2(float(x) - sz * 0.5 + 0.5, float(y) - sz * 0.5 + 2.0)
			var d := p.length()
			var a := absf(fposmod(p.angle(), TAU / 8.0) - TAU / 16.0)
			var star_r := 14.5 - a * 28.0
			if d < 8.0:
				img.set_pixel(x, y, purple_hi if p.y < -2.0 else purple)
			elif d < star_r:
				img.set_pixel(x, y, gold if d > star_r - 3.0 else purple)
			# التاج فوق الرأس
			var cp := Vector2(float(x) - sz * 0.5 + 0.5, float(y) - 4.5)
			if absf(cp.x) < 6.5 and cp.y > -2.5 and cp.y < 2.0:
				if absf(fposmod(cp.x + 8.0, 4.2) - 2.1) < 1.0 or cp.y > 0.0:
					img.set_pixel(x, y, gold)
	# خط تحديد أسود
	var edges := []
	for y in sz:
		for x in sz:
			if img.get_pixel(x, y).a > 0.0:
				continue
			for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + off.x
				var ny: int = y + off.y
				if nx >= 0 and nx < sz and ny >= 0 and ny < sz and img.get_pixel(nx, ny).a > 0.5:
					edges.append(Vector2i(x, y))
					break
	for e2 in edges:
		img.set_pixel(e2.x, e2.y, Color(0.04, 0.04, 0.07, 1.0))
	return ImageTexture.create_from_image(img)

func _crack_pts(start: Vector2, segs: int) -> PackedVector2Array:
	# خط متعرّج (شق جليد / شق حمم)
	var pts := PackedVector2Array()
	var cur := start
	var dir := rng.randf() * TAU
	pts.append(cur)
	for i in segs:
		dir += rng.randf_range(-0.7, 0.7)
		cur += Vector2(cos(dir), sin(dir)) * rng.randf_range(16.0, 34.0)
		pts.append(cur)
	return pts

# ================================================================
#  HUD
func _update_hud() -> void:
	lbl_kills.text = T("KILLS: %d") % kills
	lbl_level.text = T("LEVEL %d") % level
	var m := int(gametime) / 60
	var s := int(gametime) % 60
	lbl_time.text = "%02d:%02d" % [m, s]
	lbl_stage.text = T("Stage %d/%d - %s") % [mini(stage, FINAL_STAGE), FINAL_STAGE, _stage_title()]
	if stage == FINAL_STAGE:
		if king_spawned:
			lbl_boss.text = T("!! THE ASH KING - THE END !!")
		elif boss_alive:
			var gleft := 0
			for e4 in enemies:
				if String(e4["type"]) == "boss":
					gleft += 1
			lbl_boss.text = T("Lords of the Realms - %d left") % gleft
		else:
			lbl_boss.text = T("Something approaches from the dark...")
	elif boss_alive:
		lbl_boss.text = T("!! %s - TIME FROZEN !!") % T(boss_name_cur)
	else:
		lbl_boss.text = T("Boss in %ds") % int(ceil(stage_timer))
	if combo >= 5:
		lbl_combo.visible = true
		lbl_combo.text = T("x%d COMBO") % combo
		lbl_combo.add_theme_color_override("font_color",
			Color(1, 0.85, 0.35) if combo < 25 else (Color(1, 0.55, 0.15) if combo < 60 else Color(1, 0.25, 0.25)))
	else:
		lbl_combo.visible = false
	var f: float = clampf(hp / maxhp, 0.0, 1.0)
	hp_fill.size.x = 234.0 * f
	hp_fill.color = Color(0.30, 0.85, 0.30).lerp(Color(0.90, 0.20, 0.20), 1.0 - f)
	if wound_t > 0.0:
		hp_fill.color = Color(1.0, 0.55, 0.15)   # جرح: العلاج ممنوع مؤقتاً (برتقالي)
		lbl_wound.text = T("WOUNDED - healing blocked")
		lbl_wound.visible = true
	else:
		lbl_wound.visible = false
	# رقم الصحة: قيمة حية + وميض خفيف (أحمر ضرر / أخضر علاج)
	if hp_prev >= 0.0:
		if hp < hp_prev - 0.01:
			hp_flash_t = 0.30
			hp_flash_heal = false
		elif hp > hp_prev + 0.01:
			hp_flash_t = 0.30
			hp_flash_heal = true
	hp_prev = hp
	lbl_hp.text = "%d / %d" % [int(ceil(maxf(0.0, hp))), int(maxhp)]
	var hp_col := Balance.COL_TEXT
	if hp_flash_t > 0.0:
		hp_col = Color(0.55, 1.0, 0.55) if hp_flash_heal else Color(1.0, 0.45, 0.40)
	lbl_hp.add_theme_color_override("font_color", hp_col)
	xp_fill.size.x = 254.0 * clampf(float(xp) / float(xp_need), 0.0, 1.0)
	# الداش: الشينوبي بيشوف شحناته (3) — الباقي شريط التبريد المعتاد
	if sig == "crescent":
		var chf := (float(dash_charges) + (1.0 - clampf(dash_recharge_t / dash_cd_max, 0.0, 1.0)) * (1.0 if dash_charges < dash_charges_max else 0.0)) / float(dash_charges_max)
		dash_fill.size.x = 116.0 * clampf(chf, 0.0, 1.0)
		dash_fill.color = Color(0.35, 0.9, 0.6) if dash_charges > 0 else Color(0.4, 0.45, 0.55)
	else:
		var df: float = 1.0 - clampf(dash_cd / dash_cd_max, 0.0, 1.0)
		dash_fill.size.x = 116.0 * df
		dash_fill.color = Color(0.35, 0.75, 1.0) if df >= 1.0 else Color(0.4, 0.45, 0.55)
	# مؤشر القدرة Q
	if q_cd <= 0.0:
		lbl_q.text = "[Q] " + T(String(CHARS[char_sel].get("qname", "Ability")))
		lbl_q.add_theme_color_override("font_color", Color(0.6, 0.95, 0.7))
	else:
		lbl_q.text = "[Q] %.1fs" % q_cd
		lbl_q.add_theme_color_override("font_color", Color(0.55, 0.58, 0.66))
	# v1.2.3/1.2.5: مؤشر الأولتيمت R — كل الشخصيات (مقفول قبل Level 7)
	if CHARS[char_sel].has("rname"):
		lbl_r.visible = true
		var runlock := int(CHARS[char_sel].get("runlock", 7))
		if level < runlock:
			lbl_r.text = "[R] " + T("R Locked") + " (Lv%d)" % runlock
			lbl_r.add_theme_color_override("font_color", Color(0.5, 0.52, 0.58))
		elif r_cd <= 0.0:
			lbl_r.text = "[R] " + T(String(CHARS[char_sel].get("rname", "Ultimate")))
			lbl_r.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
		else:
			lbl_r.text = "[R] %.0fs" % ceil(r_cd)
			lbl_r.add_theme_color_override("font_color", Color(0.55, 0.58, 0.66))
	else:
		lbl_r.visible = false
	# v1.2.5: مؤشر حالة مؤقتة (بافات المقامر / القدر) مع عدّاد
	var stx := ""
	var good := true
	if r_fate_t > 0.0:
		good = r_fate_good
		stx = ("FATE +40%% (%ds)" % int(ceil(r_fate_t))) if r_fate_good else ("FATE -40%% (%ds)" % int(ceil(r_fate_t)))
	elif g_dmg_t > 0.0 and absf(g_dmg_mul - 1.0) > 0.01:
		good = g_dmg_mul >= 1.0
		stx = "DMG %+d%% (%ds)" % [int(round((g_dmg_mul - 1.0) * 100.0)), int(ceil(g_dmg_t))]
	elif g_crit_t > 0.0 and g_crit_add > 0.0:
		good = true
		stx = "CRIT +%d%% (%ds)" % [int(round(g_crit_add * 100.0)), int(ceil(g_crit_t))]
	if stx != "":
		lbl_status.visible = true
		lbl_status.text = stx
		lbl_status.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5) if good else Color(1.0, 0.5, 0.4))
	else:
		lbl_status.visible = false

# ================================================================
#  DRAW
func _draw() -> void:
	var th = THEMES[theme_idx()]
	var bg: Color = th["bg"]
	var dcol: Color = th["decor"]
	var cl := cam.position + cam.offset - Vector2(W * 0.5, H * 0.5)
	# القائمة والإعدادات والمتجر: خلفية مصممة — مش بقايا الجولة
	if state == ST_MENU or state == ST_SETTINGS or state == ST_SHOP or state == ST_STATS \
			or state == ST_CHARSEL or state == ST_DIFF or state == ST_CREDITS:
		_draw_menu_bg(cl)
		match state:
			ST_MENU: _draw_menu_buttons(cl)
			ST_CHARSEL: _draw_charsel(cl)
			ST_DIFF: _draw_diff(cl)
		return
	# حد خارجي غامق ثم بلاط البكسل آرت (المنطقة الظاهرة فقط)
	_bs()
	draw_rect(Rect2(-200, -200, WW + 400, WH + 400), bg.darkened(0.55))
	var cs := 64.0
	if tile_tex.size() > 0:
		var gx0 := maxi(0, int(cl.x / cs))
		var gy0 := maxi(0, int(cl.y / cs))
		var gx1 := mini(int(WW / cs), int((cl.x + W) / cs) + 1)
		var gy1 := mini(int(WH / cs), int((cl.y + H) / cs) + 1)
		for gx in range(gx0, gx1):
			for gy in range(gy0, gy1):
				var vi := posmod(gx * 92821 + gy * 68917, tile_tex.size())
				draw_texture_rect(tile_tex[vi], Rect2(gx * cs, gy * cs, cs, cs), false)
	_be("d_tiles")
	# ديكور متوهج فوق البلاط
	_bs()
	var camc := cam.position
	for dc in decor:
		var dk: String = dc["k"]
		if dk == "icecrack" or dk == "lava" or dk == "vein":
			var pts0: PackedVector2Array = dc["pts"]
			if pts0[0].distance_squared_to(camc) > 1690000.0:
				continue
			if dk == "lava":
				draw_polyline(pts0, Color(0.20, 0.06, 0.04), 6.0)
				draw_polyline(pts0, Color(1.0, 0.45, 0.08, 0.75 + 0.25 * sin(animt * 3.0 + pts0[0].x * 0.01)), 2.6)
			elif dk == "vein":
				# شقّ متوهّج ملوّن (أحمر للضغط / كهرماني للانهيار)
				var vcol: Color = dc["col"]
				draw_polyline(pts0, Color(vcol.r * 0.3, vcol.g * 0.3, vcol.b * 0.3, 0.9), 6.0)
				draw_polyline(pts0, Color(vcol.r, vcol.g, vcol.b, 0.55 + 0.35 * sin(animt * 3.0 + pts0[0].x * 0.01)), 2.4)
			else:
				draw_polyline(pts0, Color(0.55, 0.75, 0.90), 5.0)
				draw_polyline(pts0, Color(0.85, 0.97, 1.0, 0.6 + 0.4 * sin(animt * 2.6 + pts0[0].y * 0.01)), 2.2)
			continue
		var dp: Vector2 = dc["pos"]
		if dp.distance_squared_to(camc) > 1440000.0:
			continue
		var ds: float = dc["s"] if dc.has("s") else 3.0
		match dk:
			"flower":
				var fcol: Color = dc["col"]
				for p4 in 4:
					var pa2 := TAU * p4 / 4.0 + PI * 0.25
					var fo := dp + Vector2(cos(pa2), sin(pa2)) * ds * 0.75
					draw_rect(Rect2(fo.x - ds * 0.45, fo.y - ds * 0.45, ds * 0.9, ds * 0.9), fcol)
				draw_rect(Rect2(dp.x - ds * 0.4, dp.y - ds * 0.4, ds * 0.8, ds * 0.8), Color(1.0, 0.75, 0.2))
			"bush":
				draw_rect(Rect2(dp.x - ds, dp.y - ds * 0.6, ds * 2.0, ds * 1.2), dcol.darkened(0.12))
				draw_rect(Rect2(dp.x - ds * 0.6, dp.y - ds, ds * 1.2, ds * 0.8), dcol)
				draw_rect(Rect2(dp.x - ds * 0.3, dp.y - ds * 0.7, ds * 0.5, ds * 0.4), dcol.lightened(0.18))
			"fly":
				# يراعة مضيئة تسبح ببطء
				var ph: float = dc["ph"]
				var fp := dp + Vector2(sin(animt * 0.6 + ph) * 26.0, cos(animt * 0.45 + ph * 1.3) * 18.0)
				var fa := 0.35 + 0.65 * (0.5 + 0.5 * sin(animt * 3.0 + ph))
				draw_rect(Rect2(fp.x - 2, fp.y - 2, 4, 4), Color(0.85, 1.0, 0.45, fa))
			"gdust":
				var ga := 0.25 + 0.55 * (0.5 + 0.5 * sin(animt * 2.2 + float(dc["ph"])))
				draw_rect(Rect2(dp.x - ds * 0.5, dp.y - ds * 0.5, ds, ds), Color(1.0, 0.88, 0.45, ga))
			"rock":
				draw_rect(Rect2(dp.x - ds, dp.y - ds * 0.55, ds * 2.0, ds * 1.1), Color(0.52, 0.42, 0.30))
				draw_rect(Rect2(dp.x - ds * 0.55, dp.y - ds, ds * 1.1, ds * 0.7), Color(0.62, 0.51, 0.37))
			"bone":
				var br2: float = dc["rot"]
				var bv := Vector2(cos(br2), sin(br2)) * ds
				draw_line(dp - bv, dp + bv, Color(0.95, 0.93, 0.85, 0.8), 3.0)
				draw_rect(Rect2(dp.x + bv.x - 2.5, dp.y + bv.y - 2.5, 5, 5), Color(0.95, 0.93, 0.85, 0.8))
				draw_rect(Rect2(dp.x - bv.x - 2.5, dp.y - bv.y - 2.5, 5, 5), Color(0.95, 0.93, 0.85, 0.8))
			"spark":
				draw_line(dp + Vector2(-ds, 0), dp + Vector2(ds, 0), Color(1, 1, 1, 0.7), 1.5)
				draw_line(dp + Vector2(0, -ds), dp + Vector2(0, ds), Color(1, 1, 1, 0.7), 1.5)
			"ember":
				var ea := 0.4 + 0.5 * (0.5 + 0.5 * sin(animt * 4.0 + float(dc["ph"])))
				var ecol: Color = dc["col"] if dc.has("col") else Color(1.0, 0.5, 0.1)
				# تصعد ببطء (جمرة عائمة)
				var ey := dp.y - fposmod(animt * 6.0 + float(dc["ph"]) * 12.0, 30.0)
				draw_rect(Rect2(dp.x - ds * 0.5, ey - ds * 0.5, ds, ds), Color(ecol.r, ecol.g, ecol.b, ea))
			"gridnode":
				# عقدة شبكة خضراء نابضة + هالة خفيفة
				var gph: float = dc["ph"]
				var gpul := 0.45 + 0.55 * (0.5 + 0.5 * sin(animt * 2.0 + gph))
				draw_rect(Rect2(dp.x - ds, dp.y - ds, ds * 2.0, ds * 2.0), Color(0.20, 0.55, 0.32, 0.12 * gpul))
				draw_rect(Rect2(dp.x - ds * 0.5, dp.y - ds * 0.5, ds, ds), Color(0.40, 0.90, 0.55, 0.35 + 0.4 * gpul))
			"mote":
				# جسيم بيانات يطفو ببطء
				var mph: float = dc["ph"]
				var mcol: Color = dc["col"]
				var mp := dp + Vector2(sin(animt * 0.5 + mph) * 22.0, cos(animt * 0.4 + mph * 1.3) * 16.0)
				var ma := 0.25 + 0.45 * (0.5 + 0.5 * sin(animt * 2.4 + mph))
				draw_rect(Rect2(mp.x - 1.5, mp.y - 1.5, 3, 3), Color(mcol.r, mcol.g, mcol.b, ma))
			"shard":
				# شظية زاويّة ثابتة (ضغط قرمزي)
				var sr: float = dc["rot"]
				var scol2: Color = dc["col"]
				var sv := Vector2(cos(sr), sin(sr))
				var sperp := Vector2(-sv.y, sv.x)
				draw_colored_polygon(PackedVector2Array([
					dp + sv * ds, dp - sv * ds * 0.6 + sperp * ds * 0.4,
					dp - sv * ds * 0.6 - sperp * ds * 0.4]), Color(scol2.r, scol2.g, scol2.b, 0.55))
			"snow":
				# ندفة ثلج تتساقط ببطء وتلتفّ
				var nph: float = dc["ph"]
				var sy := dp.y + fposmod(animt * 14.0 + nph * 30.0, 90.0)
				var sx := dp.x + sin(animt * 0.8 + nph) * 10.0
				var sa := 0.35 + 0.35 * (0.5 + 0.5 * sin(animt * 1.6 + nph))
				draw_rect(Rect2(sx - 1.5, sy - 1.5, 3, 3), Color(0.85, 0.94, 1.0, sa))
			"corenode":
				# عقدة فساد متوهّجة (نهائي) — نبض بنفسجي/سماوي
				var cph: float = dc["ph"]
				var cpul := 0.5 + 0.5 * sin(animt * 2.2 + cph)
				draw_circle(dp, ds * 1.6, Color(0.55, 0.30, 0.85, 0.08 * cpul))
				draw_arc(dp, ds, animt * 0.8 + cph, animt * 0.8 + cph + TAU * 0.7, 18, Color(0.70, 0.45, 0.95, 0.4 + 0.3 * cpul), 2.0)
				draw_rect(Rect2(dp.x - 2, dp.y - 2, 4, 4), Color(0.85, 0.65, 1.0, 0.6 + 0.3 * cpul))
			"drock":
				draw_rect(Rect2(dp.x - ds, dp.y - ds * 0.6, ds * 2.0, ds * 1.2), Color(0.12, 0.05, 0.04))
				draw_rect(Rect2(dp.x - ds * 0.5, dp.y - ds, ds, ds * 0.7), Color(0.22, 0.10, 0.08))
			"nebula":
				var ncol: Color = dc["col"]
				draw_circle(dp, ds, Color(ncol.r, ncol.g, ncol.b, 0.10))
				draw_circle(dp, ds * 0.55, Color(ncol.r, ncol.g, ncol.b, 0.08))
			"bigstar":
				var tw := 0.4 + 0.6 * (0.5 + 0.5 * sin(animt * 2.5 + float(dc["ph"])))
				draw_line(dp + Vector2(-ds, 0), dp + Vector2(ds, 0), Color(1, 1, 1, tw), 1.5)
				draw_line(dp + Vector2(0, -ds), dp + Vector2(0, ds), Color(1, 1, 1, tw), 1.5)
	# سور الساحة
	draw_rect(Rect2(0, 0, WW, WH), bg.darkened(0.55), false, 6.0)

	# aura
	if aura_r > 0.0 and state != ST_MENU:
		draw_circle(pp, aura_r, Color(1.0, 0.5, 0.15, 0.10))
		draw_arc(pp, aura_r, 0, TAU, 48, Color(1.0, 0.55, 0.15, 0.5), 2.5)

	# trail
	for t in trail:
		var tl: float = t["life"]
		var tp: Vector2 = t["pos"]
		var a2 := tl * 1.8
		draw_rect(Rect2(tp.x - 8, tp.y - 8, 16, 16), Color(0.35, 0.6, 1.0, clampf(a2, 0.0, 0.4)))

	# فخاخ الفصول
	for tp in traps:
		var tpp: Vector2 = tp["pos"]
		if String(tp["k"]) == "spike":
			var is_ice := bool(tp.get("ice", false))
			var scol := Color(0.75, 0.92, 1.0) if is_ice else Color(0.93, 0.90, 0.80)
			if not bool(tp["sprung"]):
				# تحذير وامض قبل ما الأشواك تطلع
				var wa := 0.35 + 0.4 * (0.5 + 0.5 * sin(animt * 14.0))
				draw_arc(tpp, 44.0, 0, TAU, 20, Color(scol.r, scol.g, scol.b, wa), 2.0)
				for k in 6:
					var sa2 := TAU * float(k) / 6.0
					var sp2 := tpp + Vector2(cos(sa2), sin(sa2)) * 26.0
					draw_rect(Rect2(sp2.x - 2, sp2.y - 4, 4, 8), Color(scol.r * 0.8, scol.g * 0.78, scol.b * 0.72, wa))
			else:
				# أشواك طالعة
				for k in 7:
					var sa3 := TAU * float(k) / 7.0 + 0.3
					var base3 := tpp + Vector2(cos(sa3), sin(sa3)) * 24.0
					draw_colored_polygon(PackedVector2Array([
						base3 + Vector2(-5, 4), base3 + Vector2(5, 4), base3 + Vector2(0, -22)]), scol)
				draw_colored_polygon(PackedVector2Array([
					tpp + Vector2(-6, 6), tpp + Vector2(6, 6), tpp + Vector2(0, -30)]), scol.lightened(0.1))
		elif String(tp["k"]) == "freeze":
			# منطقة تجميد: دايرة زرقا بتقفل عليك
			var fw: float = tp["warn"]
			var ffrac := clampf(fw / 1.1, 0.0, 1.0)
			draw_circle(tpp, 80.0, Color(0.45, 0.75, 1.0, 0.13 + 0.07 * sin(animt * 10.0)))
			draw_arc(tpp, 80.0, 0, TAU, 28, Color(0.6, 0.85, 1.0, 0.8), 2.5)
			draw_arc(tpp, 80.0 * ffrac, 0, TAU, 24, Color(0.85, 0.97, 1.0, 0.9), 2.0)
		else:
			# بقعة حارقة نابضة
			var ba2 := 0.5 + 0.3 * sin(animt * 5.0 + tpp.x * 0.02)
			draw_circle(tpp, 36.0, Color(0.55, 0.12, 0.03, 0.55))
			draw_circle(tpp, 28.0, Color(1.0, 0.42, 0.06, ba2))
			draw_circle(tpp, 14.0, Color(1.0, 0.75, 0.20, ba2))
			for k in 4:
				var ea2 := animt * 2.0 + TAU * float(k) / 4.0 + tpp.y
				var ep2 := tpp + Vector2(cos(ea2), sin(ea2)) * 20.0
				draw_rect(Rect2(ep2.x - 2, ep2.y - 2, 4, 4), Color(1.0, 0.6, 0.1, 0.8))

	# مناطق الخطر الأرضية (نار/دوّامات)
	for hz in hazards:
		var hp2: Vector2 = hz["pos"]
		var hr: float = hz["r"]
		var hc: Color = hz["col"]
		var ha: float = clampf(float(hz["life"]) * 1.2, 0.0, 1.0)
		draw_circle(hp2, hr, Color(hc.r, hc.g, hc.b, 0.22 * ha))
		draw_arc(hp2, hr, 0, TAU, 24, Color(hc.r, hc.g, hc.b, 0.65 * ha), 2.5)
		draw_circle(hp2, hr * (0.4 + 0.15 * sin(animt * 7.0)), Color(hc.r, hc.g, hc.b, 0.3 * ha))

	# Fire Trail (v1.2 — قدرة Fire Aura): بقع نار مشتعلة خلف اللاعب
	for fpp2 in fire_patches:
		var fa2 := clampf(float(fpp2["life"]) / 3.0, 0.0, 1.0)
		draw_circle(Vector2(fpp2["pos"]), 40.0, Color(1.0, 0.40, 0.08, 0.14 * fa2))
		draw_circle(Vector2(fpp2["pos"]), 22.0, Color(1.0, 0.62, 0.15, 0.20 * fa2))
		draw_arc(Vector2(fpp2["pos"]), 40.0, 0, TAU, 16, Color(1.0, 0.5, 0.1, 0.45 * fa2), 1.5)

	# --- v1.2 B/C: مرئيات الأسلحة الجانبية ---
	# Frost Orb: كرة جليدية بمنطقة برد واضحة
	var flv2 := int(ups_count.get("frostorb", 0))
	if flv2 > 0 and state != ST_MENU:
		var fob2 := pp + Vector2(cos(forb_ang), sin(forb_ang)) * 115.0
		var fzr3 := (30.0 + 7.0 * float(flv2)) * _area() * (1.5 if evo_ewinter else 1.0)
		draw_circle(fob2, fzr3, Color(0.55, 0.80, 1.0, 0.10))
		draw_arc(fob2, fzr3, 0, TAU, 22, Color(0.65, 0.88, 1.0, 0.5), 1.5)
		draw_circle(fob2, 9.0, Balance.COL_INK)
		draw_circle(fob2, 7.0, Color(0.75, 0.92, 1.0))
		draw_circle(fob2, 3.0, Color(1, 1, 1))
		if evo_ewinter:
			# عاصفة: ندف بتلف جوه المنطقة
			for sfk in 5:
				var sfa := animt * 2.5 + TAU * float(sfk) / 5.0
				draw_circle(fob2 + Vector2(cos(sfa), sin(sfa)) * fzr3 * 0.6, 2.5, Color(1, 1, 1, 0.7))
	# قنابل القاذف الطايرة
	for bb2 in bombs:
		var bpp: Vector2 = bb2["pos"]
		_shadow(bpp + Vector2(0, 6), 7.0)
		draw_circle(bpp, 7.5, Balance.COL_INK)
		draw_circle(bpp, 6.0, Color(0.25, 0.25, 0.3))
		draw_circle(bpp + Vector2(2, -3), 1.8, Color(1.0, 0.6, 0.2, 0.5 + 0.5 * sin(animt * 20.0)))
	# تحذير نيزك Meteor Fall (صديق — دايرة ذهبية مش حمرا)
	for fm2 in fmeteors:
		var fmp: Vector2 = fm2["pos"]
		var fmt2 := clampf(float(fm2["t"]), 0.0, 1.0)
		draw_circle(fmp, 120.0 * _area(), Color(1.0, 0.82, 0.3, 0.10))
		draw_arc(fmp, 120.0 * _area(), 0, TAU, 26, Color(1.0, 0.82, 0.3, 0.7), 2.0)
		draw_circle(fmp, 120.0 * _area() * (1.0 - fmt2), Color(1.0, 0.7, 0.2, 0.20))

	# Frost Trail (v1.1.3): بقع صقيع خلف الداش — باهتة وبتتلاشى مع العمر
	for fp in frost_trail:
		var fa := clampf(float(fp["life"]) / 2.0, 0.0, 1.0)
		var frr := 34.0 + 10.0 * float(ups_count.get("frtrail", 1))
		draw_circle(Vector2(fp["pos"]), frr, Color(0.55, 0.80, 1.0, 0.10 * fa))
		draw_arc(Vector2(fp["pos"]), frr, 0, TAU, 18, Color(0.70, 0.90, 1.0, 0.35 * fa), 1.5)

	# gems — ماسات ذهبية (مكافأة = ذهبي) بخط تحديد، باينة على أي أرضية
	for g in gems:
		var gp: Vector2 = g["pos"]
		var gs := 5.5 + sin(animt * 6.0 + gp.x * 0.1) * 1.4 + minf(3.0, float(g.get("val", 1)) - 1.0)
		draw_set_transform(gp, PI * 0.25, Vector2.ONE)
		draw_rect(Rect2(-gs - 2, -gs - 2, (gs + 2) * 2, (gs + 2) * 2), Balance.COL_INK)
		draw_rect(Rect2(-gs, -gs, gs * 2, gs * 2), Balance.COL_REWARD)
		draw_rect(Rect2(-gs * 0.45, -gs * 0.45, gs * 0.9, gs * 0.9), Color(1.0, 0.95, 0.8))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_be("d_decor")
	# enemies — شكل مختلف لكل نوع (قراءة فورية للخطر)
	_bs()
	for e in enemies:
		var ep: Vector2 = e["pos"]
		var er: float = e["r"]
		var etype: String = e["type"]
		_shadow(ep, er)
		if etype == "boss":
			_draw_boss(e)
			continue
		var ecol: Color = e["col"]
		# وميض أبيض لحظة الإصابة (feedback فوري للضرب)
		var hf := float(e.get("hitflash", 0.0))
		if hf > 0.0:
			ecol = ecol.lerp(Color(1, 1, 1), clampf(hf / 0.09, 0.0, 1.0) * 0.85)
		# Marked Target: ماسة ذهبية نابضة فوق الهدف المعلَّم (هينفجر شظايا عند موته)
		if bool(e.get("marked", false)):
			var mky := ep.y - er - 14.0 + sin(animt * 8.0) * 2.0
			draw_set_transform(Vector2(ep.x, mky), PI * 0.25, Vector2.ONE)
			draw_rect(Rect2(-4.5, -4.5, 9, 9), Balance.COL_INK)
			draw_rect(Rect2(-3.2, -3.2, 6.4, 6.4), Balance.COL_REWARD)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var sz2 := (er + 4.0) * 2.2
		if etype == "elite":
			# حلقة المعدّل: فضي=مدرّعة، أبيض=سريعة، مزدوجة=منقسمة
			match String(e.get("mod", "")):
				"shield":
					draw_arc(ep, er + 9.0, 0, TAU, 24, Color(0.80, 0.85, 0.92), 3.0)
				"swift":
					draw_arc(ep, er + 9.0, animt * 4.0, animt * 4.0 + PI, 14, Color(1, 1, 1, 0.9), 3.0)
				"split":
					draw_arc(ep, er + 9.0, 0, TAU, 24, Color(1.0, 0.85, 0.2, 0.7), 2.0)
					draw_arc(ep, er + 13.0, 0, TAU, 24, Color(1.0, 0.85, 0.2, 0.45), 2.0)
			draw_texture_rect(SPR["elite"], Rect2(ep.x - sz2 * 0.5, ep.y - sz2 * 0.5, sz2, sz2), false, ecol)
			var frac: float = clampf(float(e["hp"]) / float(e["maxhp"]), 0.0, 1.0)
			var bw := er * 2.0
			draw_rect(Rect2(ep.x - bw * 0.5, ep.y - er - 18, bw, 7), Color(0, 0, 0, 0.6))
			draw_rect(Rect2(ep.x - bw * 0.5, ep.y - er - 18, bw * frac, 7), Color(0.9, 0.2, 0.2))
			continue
		var gold_tint := Color(1.0, 0.85, 0.25) if bool(e.get("gold", false)) else ecol
		match etype:
			"fast":
				# سهم بكسلي مدبّب ناحيتك
				var ang := (pp - ep).angle()
				draw_set_transform(ep, ang, Vector2.ONE)
				draw_texture_rect(SPR["fast"], Rect2(-sz2 * 0.5, -sz2 * 0.5, sz2, sz2), false, gold_tint)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"tank":
				draw_texture_rect(SPR["tank"], Rect2(ep.x - sz2 * 0.5, ep.y - sz2 * 0.5, sz2, sz2), false, ecol)
			"split":
				draw_set_transform(ep, animt * 1.2, Vector2.ONE)
				draw_texture_rect(SPR["split"], Rect2(-sz2 * 0.5, -sz2 * 0.5, sz2, sz2), false, ecol)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"shooter":
				# السبطانة بتلفّ ناحية اللاعب — يبان إنه يطلق
				var sang := (pp - ep).angle()
				draw_set_transform(ep, sang, Vector2.ONE)
				draw_texture_rect(SPR["shooter"], Rect2(-sz2 * 0.5, -sz2 * 0.5, sz2, sz2), false, ecol)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"bomber":
				# كرة شوكية نابضة (تحذير إنها هتنفجر)
				var pulse := 1.0 + sin(animt * 9.0) * 0.10
				# v1.1.4: فتيل مولّع = دايرة نطاق الانفجار تظهر بوضوح (تلغراف عادل)
				if float(e.get("fuse", -1.0)) >= 0.0:
					pulse = 1.0 + sin(animt * 26.0) * 0.18
					draw_circle(ep, 78.0, Color(1.0, 0.3, 0.05, 0.14 + 0.10 * sin(animt * 22.0)))
					draw_arc(ep, 78.0, 0, TAU, 26, Color(1.0, 0.45, 0.10, 0.85), 2.5)
				draw_set_transform(ep, animt * 2.0, Vector2.ONE * pulse)
				draw_texture_rect(SPR["bomber"], Rect2(-sz2 * 0.5, -sz2 * 0.5, sz2, sz2), false, ecol)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_:
				draw_texture_rect(SPR["norm"], Rect2(ep.x - sz2 * 0.5, ep.y - sz2 * 0.5, sz2, sz2), false, ecol)

	# v1.1.4: أوفرلاي تشخيص الـ AI (--aidebug — للتطوير فقط)
	if DBG_AI and (state == ST_PLAY or state == ST_LEVELUP):
		for e in enemies:
			var edp: Vector2 = e["pos"]
			if int(e.get("flank", 0)) != 0:
				draw_string(FONT, edp + Vector2(-5, -float(e["r"]) - 8.0), "F", HORIZONTAL_ALIGNMENT_CENTER, 20, 14, Color(0.4, 1.0, 0.6))
			if e.has("tgt_off") and Vector2(e["tgt_off"]).length() > 5.0:
				draw_line(edp, pp + Vector2(e["tgt_off"]), Color(0.4, 1.0, 0.6, 0.35), 1.0)
			if String(e["type"]) == "boss":
				var binfo := "close=%.1f cd=%.1f warn=%.1f" % [float(e.get("close_t", 0.0)), float(e.get("punish_cd", 0.0)), float(e.get("punish_warn", 0.0))]
				draw_string(FONT, edp + Vector2(-90, -float(e["r"]) - 30.0), binfo, HORIZONTAL_ALIGNMENT_CENTER, 200, 13, Color(1, 0.8, 0.4))
		if boss_alive:
			draw_string(FONT, cl + Vector2(24, 640), "kite=%.1f  minion=%.1f  haz=%.1f" % [boss_kite_t, boss_minion_t, boss_haz_t], HORIZONTAL_ALIGNMENT_LEFT, 400, 15, Color(0.6, 0.9, 1.0))

	_be("d_enemy")
	# enemy bullets — texture واحدة مجمّعة بدل 3 دوائر مصمتة (أسرع بكثير)
	_bs()
	# رصاص العدو دايماً بلون خطر دافئ (أحمر عادي / برتقالي للمطارِد) — قراءة فورية
	var ebt: Texture2D = SPR["ebul"]
	for b in ebullets:
		var bp2: Vector2 = b["pos"]
		var rr := (float(b["r"]) + 2.0)
		var ecol: Color = Balance.COL_ENEMY_HI if bool(b.get("home", false)) else Balance.COL_ENEMY
		# وميضة الإطلاق: أول ~0.12ث القذيفة أكبر وأفتح = "جايلك" (telegraph)
		var bt := float(b.get("t", 1.0))
		if bt < 0.12:
			var f := 1.0 - bt / 0.12
			rr *= 1.0 + 0.7 * f
			ecol = ecol.lerp(Color(1, 1, 1), 0.6 * f)
		draw_texture_rect(ebt, Rect2(bp2.x - rr, bp2.y - rr, rr * 2.0, rr * 2.0), false, ecol)

	_be("d_ebullet")
	# orbit blades — الفارس: سيوف حقيقية (أكبر)؛ غيره: أشواك دوّارة
	for k in orbit_n:
		var obp := _orbit_blade_pos(k)
		if sig == "spinblade":
			# سيف يشير للخارج من اللاعب؛ Berserk = أكبر + توهّج ذهبي
			var gsz := 1.28 * (1.35 if berserk_t > 0.0 else 1.0)
			var rad := (obp - pp).angle()
			draw_set_transform(obp, rad, Vector2.ONE * gsz)
			if berserk_t > 0.0:
				draw_circle(Vector2.ZERO, 22.0, Color(1.0, 0.8, 0.25, 0.22 + 0.1 * sin(animt * 14.0)))
			var steel := Color(0.72, 0.80, 0.95)
			var edge := Color(0.90, 0.95, 1.0)
			if berserk_t > 0.0:
				steel = Color(1.0, 0.88, 0.5)
				edge = Color(1.0, 0.97, 0.75)
			# النصل
			draw_colored_polygon(PackedVector2Array([Vector2(-6, -3.0), Vector2(18, -2.2), Vector2(26, 0), Vector2(18, 2.2), Vector2(-6, 3.0)]), Balance.COL_INK)
			draw_colored_polygon(PackedVector2Array([Vector2(-5, -2.0), Vector2(18, -1.3), Vector2(24, 0), Vector2(18, 1.3), Vector2(-5, 2.0)]), steel)
			draw_line(Vector2(-3, 0), Vector2(22, 0), edge, 1.2)
			# الصليب والمقبض
			draw_rect(Rect2(-8, -7, 4, 14), Color(0.55, 0.42, 0.22))
			draw_rect(Rect2(-16, -2, 9, 4), Color(0.42, 0.32, 0.18))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_set_transform(obp, orbit_ang * 2.0, Vector2.ONE)
			draw_rect(Rect2(-9, -9, 18, 18), Color(0.3, 0.9, 0.95))
			draw_rect(Rect2(-5, -5, 10, 10), Color(0.7, 1.0, 1.0))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# player bullets — أزرق (بتاعك) عشان تتفرّق فورًا عن رصاص العدو الأحمر
	# نرد المقامر بيلف وعليه نقطة (هوية بصرية للسلاح)
	for b in bullets:
		# كوناي: نصل رفيع فاتح (يتميّز عن الرصاص الأزرق)
		if bool(b.get("kunai", false)):
			var kang: float = b["vel"].angle()
			draw_set_transform(b["pos"], kang, Vector2.ONE)
			draw_colored_polygon(PackedVector2Array([Vector2(-9, -2.5), Vector2(7, -1), Vector2(11, 0), Vector2(7, 1), Vector2(-9, 2.5)]),
				Color(0.92, 0.95, 1.0) if not bool(b.get("ret", false)) else Color(0.65, 0.95, 0.85))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		if bool(b.get("firebolt", false)):
			var fr := (7.5 if bool(b.get("hot", false)) else 5.0) * bsize
			var fpc := Color(1.0, 0.85, 0.35) if bool(b.get("hot", false)) else Color(1.0, 0.55, 0.2)
			draw_circle(Vector2(b["pos"]), fr + 2.0, Color(0.9, 0.3, 0.08, 0.35))
			draw_circle(Vector2(b["pos"]), fr, fpc)
			draw_circle(Vector2(b["pos"]), fr * 0.45, Color(1.0, 0.97, 0.8))
			continue
		if bool(b.get("dice", false)):
			draw_set_transform(b["pos"], animt * 9.0 + Vector2(b["pos"]).x * 0.05, Vector2.ONE * bsize)
			draw_rect(Rect2(-7, -7, 14, 14), Balance.COL_INK)
			draw_rect(Rect2(-5.5, -5.5, 11, 11), Color(0.94, 0.92, 0.88))
			draw_circle(Vector2.ZERO, 1.8, Balance.COL_INK)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			continue
		var ang: float = b["vel"].angle()
		draw_set_transform(b["pos"], ang, Vector2.ONE * bsize)
		draw_rect(Rect2(-8, -8, 16, 16), Balance.COL_YOU.darkened(0.35))
		draw_rect(Rect2(-6, -6, 12, 12), Balance.COL_YOU)
		draw_rect(Rect2(-3, -3, 6, 6), Balance.COL_YOU_HI)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# صواعق
	for z in zaps:
		var za: float = z["life"] * 5.0
		draw_polyline(z["pts"], Color(0.80, 0.92, 1.0, clampf(za, 0.0, 1.0)), 3.0)
		draw_polyline(z["pts"], Color(1, 1, 1, clampf(za * 0.6, 0.0, 0.7)), 1.2)

	# particles
	for p in parts:
		var s: float = p["sz"]
		var pos: Vector2 = p["pos"]
		draw_rect(Rect2(pos.x - s * 0.5, pos.y - s * 0.5, s, s), p["col"])

	# v1.2.3: أقواس Crescent Slash / Shadow Assault
	for sx in slash_fx:
		var sl := clampf(float(sx["life"]) / maxf(0.001, float(sx["max"])), 0.0, 1.0)
		var sang: float = sx["ang"]
		var sarc: float = sx["arc"]
		var srch: float = float(sx["reach"]) * (0.85 + 0.15 * (1.0 - sl))
		var giant := bool(sx.get("giant", false))
		var scol := (Color(1.0, 0.88, 0.4, sl * 0.9) if giant else Color(0.75, 0.98, 0.85, sl * 0.8))
		draw_arc(Vector2(sx["pos"]), srch, sang - sarc, sang + sarc, 28, scol, (7.0 if giant else 4.0) * sl + 1.0)
		draw_arc(Vector2(sx["pos"]), srch * 0.7, sang - sarc, sang + sarc, 22, Color(1, 1, 1, sl * 0.55), (3.0 if giant else 2.0))
	# v1.2.3: كرات Fireball الطايرة (Pyromancer Q)
	for fb in fireballs:
		var fbp: Vector2 = fb["pos"]
		var fbr: float = float(fb["r"])
		draw_circle(fbp, fbr + 6.0 + sin(animt * 18.0) * 2.0, Color(0.95, 0.35, 0.08, 0.30))
		draw_circle(fbp, fbr, Color(1.0, 0.55, 0.18))
		draw_circle(fbp, fbr * 0.5, Color(1.0, 0.95, 0.75))
	# v1.2.3: Judgement Rift — علامات السلاش قبل الانفجار (windup) ثم ومضتها
	if rift != null:
		var rdone := bool(rift["done"])
		var rmarks: Array = rift["marks"]
		var ra := 0.9 if not rdone else clampf(float(rift["t"]) / 0.4, 0.0, 1.0)
		for mk in rmarks:
			var mp: Vector2 = mk
			var ma := (Vector2(mp).x + Vector2(mp).y) * 0.05
			var ln := 26.0 if not rdone else 40.0
			var mc := Color(0.4, 0.7, 1.0, ra * 0.7) if not rdone else Color(0.9, 0.95, 1.0, ra)
			var dv := Vector2(cos(ma), sin(ma)) * ln
			draw_line(mp - dv, mp + dv, mc, 3.0 if not rdone else 4.0)
		if not rdone:
			draw_arc(pp, float(rift["r"]), 0, TAU, 40, Color(0.5, 0.7, 1.0, 0.25), 2.0)
	# حلقات موت متمددة
	for rg in rings:
		var rt: float = rg["t"]
		var rcol: Color = rg["col"]
		draw_arc(Vector2(rg["pos"]), 8.0 + float(rg["max"]) * rt, 0, TAU, 26,
			Color(rcol.r, rcol.g, rcol.b, (1.0 - rt) * 0.7), 3.0 * (1.0 - rt) + 1.0)

	# النيازك (تحذير قبل السقوط)
	for mt in meteors:
		var mpos: Vector2 = mt["pos"]
		var mtt: float = mt["t"]
		if mtt < 1.3:
			var frac := clampf(mtt / 1.3, 0.0, 1.0)
			draw_circle(mpos, 72.0, Color(1.0, 0.15, 0.10, 0.14 + 0.08 * sin(animt * 10.0)))
			draw_arc(mpos, 72.0, 0, TAU, 28, Color(1.0, 0.25, 0.10, 0.7), 2.5)
			draw_circle(mpos, 72.0 * (1.0 - frac), Color(1.0, 0.35, 0.10, 0.30))

	# player (يومض أثناء الحصانة) — شكل الناجي المختار بشعاره
	if state != ST_MENU and state != ST_SETTINGS:
		var pa := 1.0
		if invuln > 0.0 and fmod(animt, 0.16) < 0.08:
			pa = 0.35
		_shadow(pp, PR + 3.0)
		# Shinobi: afterimages أثناء الداش + حلقة سماوية = i-frames شغالة (وضوح الحصانة)
		if sig == "crescent":
			if dash_t > 0.0 and pvel.length() > 10.0:
				var back := -pvel.normalized()
				_draw_hero(pp + back * 26.0, char_sel, PR, 0.35)
				_draw_hero(pp + back * 52.0, char_sel, PR, 0.18)
			if invuln > 0.0:
				draw_arc(pp, PR + 9.0, 0, TAU, 20, Color(0.5, 0.95, 0.8, 0.35 + 0.3 * sin(animt * 20.0)), 2.0)
		_draw_hero(pp, char_sel, PR, pa, true)   # true = البطل (حد حبر + قلب أزرق ساطع)
		# --- v1.2: مرئيات القدرات ---
		# تورريت الجندي: قاعدة + ماسورة + دايرة مداه
		if q_turret != null:
			var tp2: Vector2 = q_turret["pos"]
			draw_circle(tp2, 520.0 * 0.25, Color(0.5, 0.7, 0.5, 0.035))
			draw_arc(tp2, 520.0 * 0.25, 0, TAU, 28, Color(0.55, 0.75, 0.55, 0.25), 1.5)
			_shadow(tp2, 12.0)
			draw_rect(Rect2(tp2.x - 9, tp2.y - 4, 18, 10), Color(0.30, 0.36, 0.28))
			draw_rect(Rect2(tp2.x - 6, tp2.y - 9, 12, 7), Color(0.42, 0.50, 0.38))
			var tang := animt * 2.0
			if enemies.size() > 0:
				var tn := _nearest_enemy()
				if tn >= 0:
					tang = (Vector2(enemies[tn]["pos"]) - tp2).angle()
			draw_line(tp2 + Vector2(0, -5), tp2 + Vector2(0, -5) + Vector2(cos(tang), sin(tang)) * 14.0, Color(0.80, 0.85, 0.75), 3.0)
			# مؤقت بصري: قوس بيقصر مع قرب النهاية
			draw_arc(tp2, 16.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(float(q_turret["t"]) / 8.0, 0.0, 1.0), 20, Color(0.7, 0.9, 0.7, 0.8), 2.0)
		# نسخة الشينوبي: شبح أخضر شفاف
		if q_clone != null:
			_draw_hero(Vector2(q_clone["pos"]), char_sel, PR * 0.9, 0.45)
		# Berserk الفارس: هالة ذهبية نابضة
		if berserk_t > 0.0:
			draw_arc(pp, PR + 12.0 + sin(animt * 12.0) * 3.0, 0, TAU, 24, Color(1.0, 0.75, 0.2, 0.7), 2.5)
		# v1.2.5: مرئيات الأولتيمت النشط
		if r_buff_t > 0.0:
			var _rdir := (pvel.normalized() if pvel.length() > 20.0 else Vector2.RIGHT)
			var _tn := _nearest_enemy()
			if _tn >= 0:
				_rdir = (Vector2(enemies[_tn]["pos"]) - pp).normalized()
			if sig == "rifle":
				# رشاش ثقيل: سبطانة عريضة + وميض فوهة
				draw_set_transform(pp, _rdir.angle(), Vector2.ONE)
				draw_rect(Rect2(2, -5, 34, 10), Color(0.2, 0.22, 0.26))
				draw_rect(Rect2(2, -3, 30, 6), Color(0.45, 0.48, 0.55))
				if fmod(animt, 0.1) < 0.05:
					draw_circle(Vector2(38, 0), 6.0, Color(1.0, 0.85, 0.4, 0.9))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			elif sig == "firebolt":
				# طوفان الجحيم: هالة نار نابضة + جمرات
				draw_circle(pp, PR + 16.0 + sin(animt * 14.0) * 4.0, Color(1.0, 0.4, 0.1, 0.18))
				draw_arc(pp, PR + 14.0, 0, TAU, 26, Color(1.0, 0.6, 0.2, 0.7), 2.5)
				for _ei in 5:
					var _ea := animt * 3.0 + TAU * float(_ei) / 5.0
					draw_circle(pp + Vector2(cos(_ea), sin(_ea)) * (PR + 18.0), 2.5, Color(1.0, 0.75, 0.3, 0.8))
			elif sig == "spinblade":
				# سيف عملاق ممسوك ناحية الهدف
				draw_set_transform(pp, _rdir.angle(), Vector2.ONE)
				draw_colored_polygon(PackedVector2Array([Vector2(8, -8), Vector2(78, -5), Vector2(96, 0), Vector2(78, 5), Vector2(8, 8)]), Balance.COL_INK)
				draw_colored_polygon(PackedVector2Array([Vector2(10, -6), Vector2(78, -3.5), Vector2(90, 0), Vector2(78, 3.5), Vector2(10, 6)]), Color(0.8, 0.86, 1.0))
				draw_line(Vector2(12, 0), Vector2(86, 0), Color(1, 1, 1, 0.8), 1.5)
				draw_rect(Rect2(2, -12, 6, 24), Color(0.55, 0.42, 0.22))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# نتيجة All In Roll: نرد بيلف فوق اللاعب + نقاط النتيجة
		if roll_anim_t > 0.0:
			var ra4 := clampf(roll_anim_t / 1.6, 0.0, 1.0)
			var dpos := pp + Vector2(0, -PR - 34.0 - (1.0 - ra4) * 10.0)
			var spin := (roll_anim_t * 14.0) if roll_anim_t > 1.1 else 0.0
			draw_set_transform(dpos, spin, Vector2.ONE)
			draw_rect(Rect2(-13, -13, 26, 26), Color(Balance.COL_INK.r, Balance.COL_INK.g, Balance.COL_INK.b, ra4))
			var dice_col := (Color(1.0, 0.85, 0.3, ra4) if roll_result >= 5 else (Color(0.9, 0.25, 0.2, ra4) if roll_result <= 2 else Color(0.94, 0.92, 0.88, ra4)))
			draw_rect(Rect2(-11, -11, 22, 22), dice_col)
			if roll_anim_t <= 1.1:
				# نقاط الوش النهائي
				var pipp := Color(0.08, 0.08, 0.10, ra4)
				var offs := []
				match roll_result:
					1: offs = [Vector2.ZERO]
					2: offs = [Vector2(-5, -5), Vector2(5, 5)]
					3: offs = [Vector2(-6, -6), Vector2.ZERO, Vector2(6, 6)]
					4: offs = [Vector2(-5, -5), Vector2(5, -5), Vector2(-5, 5), Vector2(5, 5)]
					5: offs = [Vector2(-6, -6), Vector2(6, -6), Vector2.ZERO, Vector2(-6, 6), Vector2(6, 6)]
					_: offs = [Vector2(-5, -6), Vector2(5, -6), Vector2(-5, 0), Vector2(5, 0), Vector2(-5, 6), Vector2(5, 6)]
				for od in offs:
					draw_circle(od, 2.2, pipp)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Guardian Cube (v1.1.3): مكعب صغير يدور حواليك — ساطع=جاهز يمتص ضربة، باهت=بيتشحن
		if int(ups_count.get("guard", 0)) > 0:
			var ga4 := animt * 2.4
			var gpos := pp + Vector2(cos(ga4), sin(ga4)) * (PR + 20.0)
			var gcol := Color(0.85, 0.92, 1.0) if guard_cd <= 0.0 else Color(0.45, 0.50, 0.60, 0.7)
			draw_set_transform(gpos, ga4 * 1.5, Vector2.ONE)
			draw_rect(Rect2(-5.5, -5.5, 11, 11), Balance.COL_INK)
			draw_rect(Rect2(-4, -4, 8, 8), gcol)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# معاينة الأبطال في القائمة الرئيسية
	if state == ST_MENU:
		var base := cam.position + cam.offset - Vector2(W * 0.5, H * 0.5)
		for i in CHARS.size():
			var hx := base + Vector2(W * 0.5 - 165.0 + 110.0 * i, 385.0)
			var sel := i == char_sel
			var hs := 26.0 if sel else 17.0
			if sel:
				hx.y -= 4.0 + sin(animt * 3.0) * 3.0
				draw_arc(hx, hs + 14.0, 0, TAU, 32, Color(1.0, 0.85, 0.35, 0.9), 3.0)
			_shadow(hx, hs + 3.0)
			_draw_hero(hx, i, hs, 1.0 if sel else 0.55)

	# damage numbers
	for dn in dmgnums:
		var dp2: Vector2 = dn["pos"]
		var dl: float = dn["life"]
		var fsz := 22 if bool(dn["big"]) else 16
		var dc2: Color = dn["col"]
		var aa := clampf(dl * 1.8, 0.0, 1.0)
		if not IS_WEB:
			draw_string(FONT, dp2 + Vector2(1, 1), dn["txt"], HORIZONTAL_ALIGNMENT_CENTER, 80, fsz, Color(0, 0, 0, aa * 0.8))
		draw_string(FONT, dp2, dn["txt"], HORIZONTAL_ALIGNMENT_CENTER, 80, fsz, Color(dc2.r, dc2.g, dc2.b, aa))

	# الأوفرلايات لازم تغطي الشاشة الحالية (الكاميرا بتتحرك)
	# فينييت: يعتّم الأطراف ويركّز العين على المنتصف (راحة للعين)
	if state == ST_PLAY:
		draw_texture_rect(SPR["vignette"], Rect2(cl.x, cl.y, W, H), false, _stage_vignette())
	if wipe_t > 0.0:
		draw_rect(Rect2(cl.x, cl.y, W, H), Color(0.85, 0.9, 1.0, wipe_t * 0.18))
	if flash > 0.0:
		draw_rect(Rect2(cl.x, cl.y, W, H), Color(0.9, 0.15, 0.12, flash * 0.20))

	# بانر انتقال المرحلة (Polish v1.1.2): شريط ناعم + عنوان بينزلق ويتلاشى — سريع وهادي
	if stage_intro_t > 0.0 and state == ST_PLAY:
		var bt := stage_intro_t / 2.2
		# alpha: دخول سريع (آخر 15% من البداية) وخروج ناعم (أول 30% من النهاية)
		var ba := clampf((1.0 - bt) * 8.0, 0.0, 1.0) * clampf(bt * 3.0, 0.0, 1.0)
		var slide := (1.0 - clampf((1.0 - bt) * 5.0, 0.0, 1.0)) * 46.0
		var by := cl.y + 176.0
		draw_rect(Rect2(cl.x, by, W, 86.0), Color(0.02, 0.03, 0.06, 0.55 * ba))
		draw_rect(Rect2(cl.x, by, W, 2.0), Color(1.0, 0.82, 0.35, 0.8 * ba))
		draw_rect(Rect2(cl.x, by + 84.0, W, 2.0), Color(1.0, 0.82, 0.35, 0.8 * ba))
		draw_string(FONT, Vector2(cl.x + slide, by + 44.0), stage_intro_title,
			HORIZONTAL_ALIGNMENT_CENTER, W, 40, Color(1.0, 0.92, 0.62, ba))
		if stage_intro_sub != "":
			draw_string(FONT, Vector2(cl.x + slide * 0.6, by + 74.0), stage_intro_sub,
				HORIZONTAL_ALIGNMENT_CENTER, W, 20, Color(0.85, 0.88, 0.95, ba * 0.9))

	# الجليد: ثلج بيمطر من فوق دايماً
	if theme_idx() == 2 and state != ST_MENU:
		for i in (44 if IS_WEB else 80):
			var fi := float(i)
			var sx := fposmod(fi * 173.7 + sin(animt * 0.8 + fi) * 34.0, W)
			var sy := fposmod(fi * 97.3 + animt * (46.0 + float(i % 5) * 16.0), H + 20.0) - 10.0
			var ssz := 2.0 + float(i % 3)
			draw_rect(Rect2(cl.x + sx, cl.y + sy, ssz, ssz), Color(1, 1, 1, 0.45 + 0.3 * float(i % 2)))

	# لوحة إحصائيات عمودية بأيقونات (أسلوب The Binding of Isaac)
	if state == ST_PLAY or state == ST_LEVELUP or state == ST_PAUSE:
		var rows := []
		rows.append(["dmg", str(int(bullet_dmg))])
		rows.append(["rate", "%.1f" % (1.0 / fire_rate)])
		rows.append(["shots", str(multishot + rear_n)])
		rows.append(["spd", str(int(pspeed))])
		if pierce > 0: rows.append(["pierce", str(pierce)])
		if crit > 0.0: rows.append(["crit", "%d%%" % int(crit * 100.0)])
		if armor_n > 0: rows.append(["armor", "%d%%" % int((1.0 - pow(0.92, float(armor_n))) * 100.0)])
		if regen_n > 0: rows.append(["regen", "Lv%d" % regen_n])
		if steal_n > 0: rows.append(["steal", "Lv%d" % steal_n])
		rows.append(["fps", str(Engine.get_frames_per_second())])
		var px0 := cl.x + 22.0
		var py0 := cl.y + 148.0
		draw_rect(Rect2(px0 - 8, py0 - 10, 106, float(rows.size()) * 26.0 + 14.0), Color(0, 0, 0, 0.35))
		for ri in rows.size():
			var row = rows[ri]
			var ip := Vector2(px0 + 8.0, py0 + 4.0 + float(ri) * 26.0)
			_stat_icon(String(row[0]), ip)
			draw_string(FONT, ip + Vector2(20, 6), String(row[1]), HORIZONTAL_ALIGNMENT_LEFT, 70, 16, Color(0.92, 0.94, 0.98))

	# رادار صغير (أعلى يمين تحت اسم المرحلة)
	if state == ST_PLAY or state == ST_LEVELUP or state == ST_PAUSE:
		var mw := 180.0
		var mh := mw * WH / WW
		var mp := cl + Vector2(W - mw - 20.0, 96.0)
		draw_rect(Rect2(mp.x, mp.y, mw, mh), Color(0, 0, 0, 0.42))
		draw_rect(Rect2(mp.x, mp.y, mw, mh), Color(1, 1, 1, 0.35), false, 1.5)
		var sc := mw / WW
		var shown := 0
		for e in enemies:
			if shown > 80:
				break
			shown += 1
			var epv: Vector2 = e["pos"]
			var mpos := mp + Vector2(clampf(epv.x, 0, WW) * sc, clampf(epv.y, 0, WH) * sc)
			var etype2: String = e["type"]
			if etype2 == "boss":
				draw_circle(mpos, 4.0, Color(1.0, 0.3, 0.9))
			elif etype2 == "elite":
				draw_circle(mpos, 2.6, Color(1.0, 0.85, 0.2))
			else:
				draw_circle(mpos, 1.6, Color(1, 1, 1, 0.75))
		draw_rect(Rect2(mp.x + pp.x * sc - 2.5, mp.y + pp.y * sc - 2.5, 5, 5), Color(0.30, 0.60, 1.0))

	# شريط صحة الزعيم الكبير أعلى الشاشة
	if boss_alive and not (SHOTMODE and SHOTSCENE == "cover"):
		for e in enemies:
			if String(e["type"]) == "boss":
				var bw2 := 420.0
				var bx := cl.x + W * 0.5 - bw2 * 0.5
				var by := cl.y + 102.0
				var fr: float = clampf(float(e["hp"]) / float(e["maxhp"]), 0.0, 1.0)
				draw_rect(Rect2(bx - 3, by - 3, bw2 + 6, 20), Color(0, 0, 0, 0.65))
				draw_rect(Rect2(bx, by, bw2 * fr, 14), Color(0.95, 0.22, 0.25) if int(e.get("phase", 1)) == 1 else Color(1.0, 0.45, 0.10))
				draw_rect(Rect2(bx - 3, by - 3, bw2 + 6, 20), Color(1, 1, 1, 0.4), false, 1.5)
				break

	# نبض تحذير عند صحة منخفضة
	if state == ST_PLAY and hp < maxhp * 0.25 and hp > 0.0:
		var pa2 := 0.10 + 0.08 * sin(animt * 7.0)
		draw_rect(Rect2(cl.x, cl.y, W, H), Color(0.85, 0.05, 0.05, pa2))

	# قائمة الإيقاف: تعتيم + لوح + أزرار (فوق العالم المتجمّد؛ النصوص Labels فوقها)
	if state == ST_PAUSE:
		draw_rect(Rect2(cl.x, cl.y, W, H), Color(0.03, 0.04, 0.07, 0.72))
		# لوح خلفي للقائمة
		_draw_panel(Rect2(cl + Vector2(W * 0.5 - 220.0, 176.0), Vector2(440.0, 470.0)), false)
		if pause_confirm == "":
			for i in PAUSE_BTNS.size():
				var r := _pause_btn_rect(i)
				r.position += cl
				_draw_panel(r, i == pause_sel)
		else:
			for i in 2:
				var rc := _pc_rect(i)
				rc.position += cl
				_draw_panel(rc, i == pause_sel, false, Balance.COL_ENEMY if i == 0 else Balance.COL_YOU)

	# نص الغلاف (مرسوم داخل منطقة القص 190..1090 بالظبط)
	if SHOTMODE and SHOTSCENE == "cover":
		for off in [Vector2(-3, 0), Vector2(3, 0), Vector2(0, -3), Vector2(0, 3), Vector2(3, 3), Vector2(-3, 3)]:
			draw_string(FONT, cl + Vector2(190, 130) + off, "CUBE SURVIVOR", HORIZONTAL_ALIGNMENT_CENTER, 900, 76, Color(0.02, 0.03, 0.08))
		draw_string(FONT, cl + Vector2(190, 130), "CUBE SURVIVOR", HORIZONTAL_ALIGNMENT_CENTER, 900, 76, Color(0.55, 0.80, 1.0))
		for off in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
			draw_string(FONT, cl + Vector2(190, 655) + off, "Survive the Ash King", HORIZONTAL_ALIGNMENT_CENTER, 900, 32, Color(0.02, 0.03, 0.08))
		draw_string(FONT, cl + Vector2(190, 655), "Survive the Ash King", HORIZONTAL_ALIGNMENT_CENTER, 900, 32, Color(1.0, 0.85, 0.35))

func _shadow(pos: Vector2, r: float) -> void:
	# ظل بيضاوي ناعم تحت الكيان — عمق فوري
	draw_set_transform(pos + Vector2(0, r * 0.85), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, r * 0.9, Color(0, 0, 0, 0.20))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_hero(pos: Vector2, idx: int, s: float, alpha: float, player := false) -> void:
	# سبرايت بكسل للناجي + شعاره المميز
	# Polish v1.1.2: البطل داخل اللعب بلون شخصيته فعلاً (هوية بصرية حقيقية) —
	# والمقروئية مضمونة بحد حبر خلفه + قلب أزرق ساطع ثابت (بؤرة "أنت" في كل الشخصيات).
	var acc: Color = CHARS[idx]["col"]
	var acc2: Color = CHARS[idx].get("col2", Balance.COL_YOU_HI)
	var body: Color = acc
	var body_tex: Texture2D = SPR.get("hero%d" % idx, SPR["hero"])
	var hsz := s * 2.4
	if player:
		# حد حبر خارجي — البطل واضح فوق أي أرضية مهما كان لونه
		var osz := hsz + 5.0
		draw_texture_rect(body_tex, Rect2(pos.x - osz * 0.5, pos.y - osz * 0.5, osz, osz), false, Color(Balance.COL_INK.r, Balance.COL_INK.g, Balance.COL_INK.b, alpha * 0.9))
	draw_texture_rect(body_tex, Rect2(pos.x - hsz * 0.5, pos.y - hsz * 0.5, hsz, hsz), false, Color(body.r, body.g, body.b, alpha))
	if player:
		draw_rect(Rect2(pos.x - s * 0.30, pos.y - s * 0.30, s * 0.60, s * 0.60), Color(Balance.COL_YOU_HI.r, Balance.COL_YOU_HI.g, Balance.COL_YOU_HI.b, alpha * 0.9))
	match idx:
		0:  # Soldier: ماسورة بندقية + نقطة تصويب
			var sdir := (pvel.normalized() if player and pvel.length() > 30.0 else Vector2.RIGHT)
			draw_line(pos + sdir * s * 0.4, pos + sdir * (s + 8.0), Color(acc2.r, acc2.g, acc2.b, alpha), 3.0)
			draw_circle(pos + sdir * (s + 11.0), 1.8, Color(1, 1, 1, alpha * 0.8))
		1:  # Pyromancer: ألسنة لهب فوق الرأس
			for k in 3:
				var fx := pos.x - s * 0.55 + s * 0.55 * k
				var fh := s * (0.55 + 0.25 * sin(animt * 7.0 + k * 2.0))
				draw_colored_polygon(PackedVector2Array([
					Vector2(fx - s * 0.18, pos.y - s), Vector2(fx + s * 0.18, pos.y - s),
					Vector2(fx, pos.y - s - fh)]), Color(1.0, 0.55, 0.15, alpha))
		2:  # Shinobi: قناع نينجا داكن + عين واحدة خضرا مضيئة + وشاح مرفرف
			# القناع: حزام أغمق فوق منتصف الوش
			draw_rect(Rect2(pos.x - s * 0.72, pos.y - s * 0.42, s * 1.44, s * 0.36), Color(0.08, 0.10, 0.12, alpha))
			# عين واحدة (يمين) بلمعة
			draw_rect(Rect2(pos.x + s * 0.02, pos.y - s * 0.36, s * 0.42, s * 0.24), Color(acc2.r, acc2.g, acc2.b, alpha))
			draw_rect(Rect2(pos.x + s * 0.06, pos.y - s * 0.33, s * 0.14, s * 0.10), Color(1, 1, 1, alpha * 0.9))
			# وشاح خلفه بيرفرف
			var scx := pos + Vector2(-s * 0.95 - sin(animt * 7.0) * 3.0, s * 0.05 + cos(animt * 5.0) * 1.5)
			draw_rect(Rect2(scx.x - s * 0.5, scx.y - s * 0.12, s * 0.55, s * 0.24), Color(acc2.r, acc2.g, acc2.b, alpha * 0.75))
		3:  # Knight: سيفان دوّاران واضحان (سلاح توقيعه) — الرسم الفعلي في _draw عبر orbit
			draw_rect(Rect2(pos.x - s * 0.5, pos.y - s * 0.28, s * 1.0, s * 0.16), Color(acc2.r, acc2.g, acc2.b, alpha * 0.9))
		4:  # Titan: صفيحتا درع أفقيتان
			draw_rect(Rect2(pos.x - s * 0.7, pos.y - s * 0.34, s * 1.4, s * 0.22), Color(0.85, 0.88, 0.95, alpha))
			draw_rect(Rect2(pos.x - s * 0.7, pos.y + s * 0.12, s * 1.4, s * 0.22), Color(0.72, 0.75, 0.85, alpha))
		5:  # Gambler: نقاط نرد (pips) غامقة على الجسم — قلب النرد المضيء هو الـ core الأزرق
			var pipc := Color(0.10, 0.10, 0.14, alpha)
			draw_circle(pos + Vector2(-s * 0.5, -s * 0.5), s * 0.16, pipc)
			draw_circle(pos + Vector2(s * 0.5, s * 0.5), s * 0.16, pipc)
			draw_circle(pos + Vector2(s * 0.5, -s * 0.5), s * 0.16, pipc)
			draw_circle(pos + Vector2(-s * 0.5, s * 0.5), s * 0.16, pipc)

func _poly(c: Vector2, r: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := rot + TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

# ================================================================
#  عناصر واجهة بكسل-آرت مشتركة (قوائم + اختيار الناجي + الصعوبة)
#  إطار بسيط: حدّ خارجي غامق + وجه مسطّح + إبراز علوي رفيع + حالة اختيار
func _draw_panel(r: Rect2, selected: bool, locked := false, accent := Balance.COL_YOU) -> void:
	# ظل/حدّ خارجي (يعطي عمق بكسل خفيف)
	draw_rect(Rect2(r.position.x - 3.0, r.position.y - 2.0, r.size.x + 6.0, r.size.y + 6.0), Color(0.02, 0.03, 0.05, 0.85))
	var face := Color(0.09, 0.11, 0.17, 0.96)
	if locked:
		face = Color(0.08, 0.08, 0.10, 0.94)
	elif selected:
		face = Color(0.15, 0.20, 0.31, 0.98)
	draw_rect(r, face)
	# إبراز علوي رفيع (شريحة بكسل فاتحة)
	draw_rect(Rect2(r.position.x, r.position.y, r.size.x, 3.0), Color(1, 1, 1, 0.09))
	# حدّ
	if selected and not locked:
		draw_rect(r, Color(1.0, 0.82, 0.35, 0.95), false, 3.0)
		# شريط تمييز جانبي بلون العنصر + مؤشّر مثلّث
		draw_rect(Rect2(r.position.x, r.position.y, 5.0, r.size.y), Color(accent.r, accent.g, accent.b, 0.95))
		var my := r.position.y + r.size.y * 0.5
		draw_colored_polygon(PackedVector2Array([
			Vector2(r.position.x - 16.0, my - 7.0), Vector2(r.position.x - 6.0, my),
			Vector2(r.position.x - 16.0, my + 7.0)]), Color(1.0, 0.82, 0.35, 0.95))
	else:
		draw_rect(r, Color(0.32, 0.42, 0.58, 0.55) if not locked else Color(0.25, 0.25, 0.30, 0.5), false, 2.0)

# صفّ نقاط تقييم بكسل (0..maxv) — للوحة إحصائيات الناجي
func _draw_pips(pos: Vector2, val: int, maxv: int, col: Color) -> void:
	for i in maxv:
		var px := pos.x + i * 22.0
		var on := i < val
		# مربّع بكسل مع حدّ غامق
		draw_rect(Rect2(px - 1, pos.y - 1, 18, 14), Color(0.03, 0.04, 0.06, 0.9))
		draw_rect(Rect2(px, pos.y, 16, 12), col if on else Color(0.20, 0.23, 0.30, 0.9))
		if on:
			draw_rect(Rect2(px, pos.y, 16, 3), Color(1, 1, 1, 0.22))   # إبراز علوي

func _stat_icon(kind: String, p: Vector2) -> void:
	# أيقونات بكسل صغيرة 14px للوحة الإحصائيات
	match kind:
		"dmg":  # سيف
			draw_rect(Rect2(p.x - 2, p.y - 8, 4, 11), Color(0.85, 0.88, 0.95))
			draw_rect(Rect2(p.x - 5, p.y + 2, 10, 3), Color(0.85, 0.65, 0.25))
			draw_rect(Rect2(p.x - 2, p.y + 4, 4, 4), Color(0.6, 0.45, 0.2))
		"rate":  # مقذوف
			draw_set_transform(p, PI * 0.25, Vector2.ONE)
			draw_rect(Rect2(-5, -5, 10, 10), Color(0.95, 0.25, 0.2))
			draw_rect(Rect2(-2, -2, 4, 4), Color(1, 0.7, 0.6))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"shots":  # ثلاث نقط
			for k in 3:
				draw_rect(Rect2(p.x - 7 + k * 5, p.y - 2, 4, 4), Color(1.0, 0.6, 0.2))
		"spd":  # سهما سرعة
			for k in 2:
				var cx := p.x - 5 + float(k) * 6.0
				draw_colored_polygon(PackedVector2Array([
					Vector2(cx, p.y - 6), Vector2(cx + 5, p.y), Vector2(cx, p.y + 6)]), Color(0.6, 0.9, 1.0))
		"pierce":  # سهم مخترق
			draw_rect(Rect2(p.x - 7, p.y - 1, 11, 2), Color(0.9, 0.9, 0.5))
			draw_colored_polygon(PackedVector2Array([
				Vector2(p.x + 4, p.y - 4), Vector2(p.x + 8, p.y), Vector2(p.x + 4, p.y + 4)]), Color(0.9, 0.9, 0.5))
		"crit":  # نجمة
			draw_set_transform(p, 0.0, Vector2.ONE)
			draw_rect(Rect2(-2, -7, 4, 14), Color(1.0, 0.85, 0.25))
			draw_rect(Rect2(-7, -2, 14, 4), Color(1.0, 0.85, 0.25))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"armor":  # درع
			draw_rect(Rect2(p.x - 5, p.y - 6, 10, 8), Color(0.7, 0.75, 0.85))
			draw_colored_polygon(PackedVector2Array([
				Vector2(p.x - 5, p.y + 2), Vector2(p.x + 5, p.y + 2), Vector2(p.x, p.y + 8)]), Color(0.7, 0.75, 0.85))
		"regen":  # صليب صحة
			draw_rect(Rect2(p.x - 2, p.y - 6, 4, 12), Color(0.35, 0.9, 0.4))
			draw_rect(Rect2(p.x - 6, p.y - 2, 12, 4), Color(0.35, 0.9, 0.4))
		"fps":  # شاشة صغيرة
			draw_rect(Rect2(p.x - 7, p.y - 5, 14, 10), Color(0.25, 0.9, 0.45))
			draw_rect(Rect2(p.x - 5, p.y - 3, 10, 6), Color(0.05, 0.25, 0.10))
		"steal":  # قطرة
			draw_circle(p + Vector2(0, 2), 4.0, Color(0.95, 0.4, 0.55))
			draw_colored_polygon(PackedVector2Array([
				Vector2(p.x - 3, p.y), Vector2(p.x + 3, p.y), Vector2(p.x, p.y - 7)]), Color(0.95, 0.4, 0.55))

func _draw_menu_bg(cl: Vector2) -> void:
	# سماء فراغ متحركة: نجوم وامضة + سدُم + مكعبات عايمة
	draw_rect(Rect2(cl.x, cl.y, W, H), Color(0.05, 0.035, 0.09))
	# سدُم كبيرة هادئة
	draw_circle(cl + Vector2(W * 0.25, H * 0.30), 260.0, Color(0.35, 0.18, 0.55, 0.07))
	draw_circle(cl + Vector2(W * 0.78, H * 0.62), 300.0, Color(0.20, 0.22, 0.55, 0.06))
	draw_circle(cl + Vector2(W * 0.55, H * 0.85), 200.0, Color(0.50, 0.15, 0.45, 0.05))
	# نجوم وامضة (مواقع ثابتة stateless)
	for i in 130:
		var fi := float(i)
		var sx := fposmod(fi * 137.51, W)
		var sy := fposmod(fi * 79.37, H)
		var tw := 0.25 + 0.55 * (0.5 + 0.5 * sin(animt * (0.8 + fposmod(fi, 3.0) * 0.5) + fi))
		var scol := Color(0.85, 0.75, 1.0, tw) if i % 3 == 0 else Color(1, 1, 1, tw * 0.8)
		draw_rect(Rect2(cl.x + sx, cl.y + sy, 2.5, 2.5), scol)
	# كائنات عايمة ببطء (استعراض صامت)
	var drift := [["norm", Color(0.85, 0.38, 0.30)], ["fast", Color(0.30, 0.75, 0.85)],
		["tank", Color(0.80, 0.55, 0.25)], ["split", Color(0.62, 0.36, 0.75)], ["norm", Color(0.55, 0.42, 0.30)]]
	for i in drift.size():
		var fi2 := float(i)
		var dx := fposmod(fi2 * 300.0 + animt * (9.0 + fi2 * 3.0), W + 120.0) - 60.0
		var dy := H * 0.15 + fi2 * H * 0.17 + sin(animt * 0.5 + fi2 * 2.0) * 26.0
		var dsz := 26.0 + fposmod(fi2 * 7.0, 12.0)
		var item = drift[i]
		var icol: Color = item[1]
		draw_texture_rect(SPR[item[0]], Rect2(cl.x + dx - dsz * 0.5, cl.y + dy - dsz * 0.5, dsz, dsz), false,
			Color(icol.r, icol.g, icol.b, 0.35))
	# تعتيم أعلى وأسفل (فينييت بسيط)
	draw_rect(Rect2(cl.x, cl.y, W, 90), Color(0, 0, 0, 0.30))
	draw_rect(Rect2(cl.x, cl.y + H - 110, W, 110), Color(0, 0, 0, 0.30))

# مكعّب أيزومتري صغير بالبكسل — شعار القائمة
func _draw_menu_cube(c: Vector2, s: float) -> void:
	c.y += sin(animt * 1.5) * 2.0
	var top := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, -s * 0.5), c + Vector2(0, 0), c + Vector2(-s, -s * 0.5)])
	var left := PackedVector2Array([c + Vector2(-s, -s * 0.5), c + Vector2(0, 0), c + Vector2(0, s), c + Vector2(-s, s * 0.5)])
	var right := PackedVector2Array([c + Vector2(s, -s * 0.5), c + Vector2(0, 0), c + Vector2(0, s), c + Vector2(s, s * 0.5)])
	draw_circle(c, s * 2.0, Color(Balance.COL_YOU.r, Balance.COL_YOU.g, Balance.COL_YOU.b, 0.10))
	draw_colored_polygon(top, Color(0.56, 0.83, 1.0))
	draw_colored_polygon(left, Color(0.18, 0.48, 1.0))
	draw_colored_polygon(right, Color(0.12, 0.32, 0.78))

func _draw_menu_buttons(cl: Vector2) -> void:
	_draw_menu_cube(cl + Vector2(W * 0.5, 74.0), 20.0)
	for i in MENU_BTNS.size():
		var r := _menu_btn_rect(i)
		r.position += cl
		_draw_panel(r, i == menu_sel)

func _draw_charsel(cl: Vector2) -> void:
	var unlocked_c := _char_unlocked(char_sel)
	# لوح المعاينة (يسار) + لوح المعلومات (يمين)
	_draw_panel(Rect2(cl + Vector2(64, 132), Vector2(576, 486)), false)
	_draw_panel(Rect2(cl + Vector2(688, 132), Vector2(520, 486)), false)
	# معاينة كبيرة للناجي المختار
	var ch = CHARS[char_sel]
	var pc := cl + Vector2(352, 292)
	var ccol: Color = ch["col"]
	draw_circle(pc, 96.0, Color(ccol.r, ccol.g, ccol.b, 0.10))
	draw_arc(pc, 96.0, animt * 0.5, animt * 0.5 + TAU * 0.72, 40, Color(ccol.r, ccol.g, ccol.b, 0.5), 2.0)
	_shadow(pc + Vector2(0, 70), 60.0)
	_draw_hero(pc, char_sel, 64.0, 1.0 if unlocked_c else 0.4)
	if not unlocked_c:
		# قفل كبير فوق المعاينة
		var lp := pc + Vector2(0, -8)
		draw_arc(lp + Vector2(0, -18), 12.0, PI, TAU, 12, Color(1.0, 0.85, 0.35, 0.95), 4.0)
		draw_rect(Rect2(lp.x - 16, lp.y - 18, 32, 26), Color(1.0, 0.85, 0.35, 0.95))
		draw_rect(Rect2(lp.x - 4, lp.y - 12, 8, 12), Color(0.15, 0.12, 0.05))
	# صفّ اختيار الناجين أسفل المعاينة
	var lx0 := 352.0 - 2.5 * 86.0
	for i in CHARS.size():
		var hp2 := cl + Vector2(lx0 + 86.0 * i, 512.0)
		var sel := i == char_sel
		var lk := not _char_unlocked(i)
		var hs := 25.0 if sel else 17.0
		if sel:
			draw_arc(hp2, hs + 11.0, 0, TAU, 28, Color(1.0, 0.82, 0.35, 0.95), 3.0)
		_draw_hero(hp2, i, hs, (1.0 if sel else 0.6) * (0.4 if lk else 1.0))
		if lk:
			draw_rect(Rect2(hp2.x - 5, hp2.y - hs - 10, 10, 8), Color(1.0, 0.85, 0.35, 0.95))
	# نقاط الإحصائيات بجانب أسمائها (مضغوطة — Improvement Pass)
	var stats: Array = ch["stats"]
	for i in stats.size():
		_draw_pips(cl + Vector2(858, 282 + i * 30), int(stats[i]), 5, CS_STAT_COLS[i])

func _draw_diff(cl: Vector2) -> void:
	# لوح تفاصيل (يمين)
	_draw_panel(Rect2(cl + Vector2(576, 140), Vector2(632, 478)), false)
	# صفوف المستويات (يسار)
	for i in Balance.DIFF_TIERS.size():
		var r := _diff_row_rect(i)
		r.position += cl
		var locked := i > asc_max
		_draw_panel(r, i == df_sel, locked, Color(1.0, 0.5, 0.3))
	# معاينة صغيرة للناجي المختار (أعلى يمين اللوح)
	var pc := cl + Vector2(1128, 200)
	draw_circle(pc, 40.0, Color(0.5, 0.7, 1.0, 0.08))
	_draw_hero(pc, char_sel, 26.0, 1.0)

func _draw_boss(e: Dictionary) -> void:
	# سبرايت بكسل ثابت لكل زعيم + هالات حيوية
	var ep: Vector2 = e["pos"]
	var er: float = e["r"]
	var col: Color = e["col"]
	var kind := int(e.get("kind", 0))
	var enraged := int(e.get("phase", 1)) == 2
	var reborn := bool(e.get("reborn", false))
	var pulse := 5.0 + sin(animt * (9.0 if enraged or reborn else 5.0)) * 3.0
	draw_circle(ep, er + pulse, Color(1, 1, 1, 0.22))
	if enraged:
		draw_circle(ep, er + pulse + 5.0, Color(1.0, 0.15, 0.15, 0.20))
	# v1.2-D: قوقعة الدرع — صدفة فاتحة نابضة = ضربك شبه معطّل مؤقتاً، اتحرك
	var sht := float(e.get("shell_t", 0.0))
	if sht > 0.0:
		var sha2 := 0.35 + 0.20 * sin(animt * 10.0)
		draw_circle(ep, er + 14.0, Color(0.85, 0.90, 1.0, 0.22))
		draw_arc(ep, er + 14.0, 0, TAU, 30, Color(0.90, 0.95, 1.0, sha2 + 0.35), 4.0)
		draw_arc(ep, er + 20.0, animt * 3.0, animt * 3.0 + TAU * 0.65, 24, Color(0.75, 0.85, 1.0, sha2), 2.0)
	# v1.1.4 تلغراف الـ Close Punish: دايرة حمرا نابضة = ابعد عن الزعيم فوراً
	var pw2 := float(e.get("punish_warn", 0.0))
	if pw2 > 0.0:
		var pa2 := 0.35 + 0.30 * sin(animt * 18.0)
		draw_circle(ep, er + 85.0, Color(1.0, 0.2, 0.1, 0.10 + 0.08 * sin(animt * 18.0)))
		draw_arc(ep, er + 85.0, 0, TAU, 30, Color(1.0, 0.3, 0.1, pa2 + 0.35), 3.0)
	if reborn:
		# هالة ملكية نارية بعد البعث (الشكل نفسه ثابت)
		draw_circle(ep, er + pulse + 6.0, Color(1.0, 0.55, 0.10, 0.25))
		draw_arc(ep, er + pulse + 12.0, animt * 2.0, animt * 2.0 + TAU * 0.6, 22, Color(1.0, 0.75, 0.2, 0.7), 3.0)
	# هالة الاحتراق الحمراء (وحش الحمم / الملك في طوره الأخير)
	var kfrac_d := float(e["hp"]) / float(e["maxhp"])
	if kind == 3 or (kind == 5 and (kfrac_d <= 0.25 or reborn)):
		var ba3 := 0.10 + 0.06 * sin(animt * 6.0)
		draw_circle(ep, 125.0 + er, Color(1.0, 0.15, 0.05, ba3))
		draw_arc(ep, 125.0 + er, 0, TAU, 40, Color(1.0, 0.30, 0.08, 0.55), 2.5)
	var sz := (er + 12.0) * 2.1
	# الملك سبرايته ملوّن بنفسجي/ذهبي جاهز — يتُرسم أبيض بلا صبغة
	var tint := Color(1, 1, 1) if kind == 5 else col
	# وميض إصابة البوس (feedback مميّز — البوس بيلمع أبيض لما يتضرب)
	var bhf := float(e.get("hitflash", 0.0))
	if bhf > 0.0:
		tint = tint.lerp(Color(1, 1, 1), clampf(bhf / 0.09, 0.0, 1.0) * 0.7)
	draw_texture_rect(SPR["boss%d" % mini(kind, 5)], Rect2(ep.x - sz * 0.5, ep.y - sz * 0.5, sz, sz), false, tint)

# ================================================================
#  BENCHMARK (أداء) — أسوأ مشهد: الـ gauntlet بأربع بوسات + لودأوت قوي
func _bench_setup() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)   # fps بيعكس التكلفة الحقيقية
	Engine.max_fps = 0
	rng.seed = 424242; seed(424242)   # ثبات العدّ بين التشغيلات
	_new_run()
	multishot = 5; pierce = 2; orbit_n = 4; aura_r = 110.0; chain_n = 3
	explode_n = 2; ric_n = 1; bsize = 1.6; fire_rate = 0.12; bullet_dmg = 1.0
	crit = 0.5; slow_n = 2; steal_n = 1; dash_cd_max = 0.6
	# فعّل كل التركيبات لقياس أسوأ حالة أداء + اختبار عدم التعطّل تحت الضغط
	ups_count = {"orbit": 3, "multi": 3, "slow": 2, "aura": 2, "crit": 2, "explode": 2,
		"steal": 1, "hp": 2, "dash": 1, "dmg": 2, "speed": 2, "chain": 2, "rate": 2, "armor": 2}
	_check_synergies()
	stage = 5
	_gen_decor()
	_spawn_void_gauntlet()
	var base_enemies := enemies.duplicate()
	for e in base_enemies:
		e["hp"] = 1.0e9; e["maxhp"] = 1.0e9
		for k in 8:
			var ga := TAU * float(k) / 8.0
			enemies.append({"pos": Vector2(e["pos"]) + Vector2(cos(ga), sin(ga)) * 70.0,
				"col": e["col"], "r": 13.0, "hp": 1.0e9, "maxhp": 1.0e9, "spd": 80.0,
				"type": "norm", "orbcd": 0.0, "orbit_host": e, "orb_a": ga})
	while ebullets.size() < 130:
		_ebullet(pp + Vector2(rng.randf_range(-300, 300), rng.randf_range(-300, 300)),
			Vector2(rng.randf_range(-120, 120), rng.randf_range(-120, 120)), Color(1, 0.5, 0.2))
	hp = 1.0e9; maxhp = 1.0e9
	state = ST_PLAY

func _bench_report() -> void:
	var hs: Array = bench_frame_hist.slice(30)   # تجاهل فريمات الإحماء
	hs.sort()
	var n := hs.size()
	var sum := 0.0
	for x in hs:
		sum += x
	var avg: float = sum / maxf(1.0, float(n))
	var p99: float = hs[int(n * 0.99)] if n > 0 else 0.0
	var worst: float = hs[n - 1] if n > 0 else 0.0
	var step_total := 0.0
	var draw_total := 0.0
	for k in bench_us:
		if String(k).begins_with("d_"):
			draw_total += float(bench_us[k])
		else:
			step_total += float(bench_us[k])
	print("=== BENCH (%d frames, %d measured) ===" % [bench_frames, n])
	print("avg %.1f fps  (%.2f ms/frame) | p99 %.2f ms | worst %.2f ms" % [1.0 / avg, avg * 1000.0, p99 * 1000.0, worst * 1000.0])
	print("counts: enemies=%d bullets=%d ebullets=%d parts=%d hazards=%d traps=%d" % [enemies.size(), bullets.size(), ebullets.size(), parts.size(), hazards.size(), traps.size()])
	var keys: Array = bench_us.keys()
	keys.sort()
	for k in keys:
		print("  %-10s %.3f ms/frame" % [k, float(bench_us[k]) / 1000.0 / float(bench_frames)])
	print("  STEP total %.3f ms | DRAW measured %.3f ms | DRAW unmeasured+glow ~= %.3f ms" % [step_total / 1000.0 / float(bench_frames), draw_total / 1000.0 / float(bench_frames), avg * 1000.0 - (step_total + draw_total) / 1000.0 / float(bench_frames)])

# ================================================================
#  SCREENSHOT SIMULATION
func _simulate_for_shot() -> void:
	_hud_visible(true)
	menu_dim.visible = false
	if SHOTSCENE == "lang":
		state = ST_LANG
		_hud_visible(false)
		lang_dim.visible = true
		queue_redraw()
		return
	if SHOTSCENE == "over":
		_hud_visible(false)
		kills = 348; level = 9; stage = 3; gametime = 187.0; combo_best = 27; run_bosses = 2
		cinders = 120; achieved = {}; unlocked = {}   # عرض ثابت: انفجار إنجازات أول جولة
		_game_over()
		queue_redraw()
		return
	if SHOTSCENE == "shop":
		_hud_visible(false)
		cinders = 340
		shop = {"vitality": 3, "might": 1, "magnet": 2, "growth": 1}
		shop_sel = 1
		_show_shop()
		queue_redraw()
		return
	if SHOTSCENE == "stats":
		_hud_visible(false)
		rec_stage = 4; rec_time = 543.0; rec_kills = 1240; rec_wins = 2
		total_runs = 37; total_kills = 18420; total_bosses = 42; total_gems = 9130
		cinders = 300; achieved = {"first": true, "realm3": true, "bossslayer": true, "centurion": true}
		asc_max = 2
		syn_found = {"arcane_orbit": true, "frost_pulse": true, "shatter_core": true, "momentum": true}
		_show_stats()
		queue_redraw()
		return
	if SHOTSCENE == "victory":
		_hud_visible(false)
		kills = 742; level = 15; gametime = 298.0; combo_best = 63; run_bosses = 6; stage = 6
		cinders = 200; achieved = {}; unlocked = {}; char_sel = 0; asc = 0; asc_max = 0
		_show_victory()
		queue_redraw()
		return
	if SHOTSCENE == "menu" or SHOTSCENE == "menu_ar":
		state = ST_MENU
		_hud_visible(false)
		if SHOTSCENE == "menu_ar":
			LANG = 1
		rec_stage = 4; rec_kills = 1240; rec_time = 543.0; rec_wins = 2
		cinders = 300; unlocked = {}; char_sel = 2   # للعرض: Runner مقفول (250) والباقي مقفول
		asc_max = 2; asc = 1                          # للعرض: Ascension مفتوح
		_refresh_menu()
		menu_dim.visible = true
		queue_redraw()
		return
	if SHOTSCENE == "settings":
		state = ST_SETTINGS
		_hud_visible(false)
		sfx_vol = 7
		mus_vol = 4
		set_sel = 1
		_refresh_settings_ui()
		set_dim.visible = true
		queue_redraw()
		return
	if SHOTSCENE == "charsel":
		state = ST_CHARSEL
		# اختبار تسرّب: جرح + توست مفعّلين قبل إخفاء الـ HUD — لازم ما يبانوش فوق القائمة
		wound_t = 4.0
		_toast("leak test", 5.0)
		_hud_visible(false)
		cinders = 300; unlocked = {}; char_sel = 3   # Wrecker مختار، بعض الشخصيات مقفولة للعرض
		_refresh_charsel()
		cs_dim.visible = true
		queue_redraw()
		return
	if SHOTSCENE == "diff":
		state = ST_DIFF
		_hud_visible(false)
		char_sel = 3; asc_max = 3; df_sel = 2   # Danger II مختار، I..III مفتوحة
		_refresh_diff()
		df_dim.visible = true
		queue_redraw()
		return
	if SHOTSCENE == "credits":
		state = ST_CREDITS
		_hud_visible(false)
		cr_dim.visible = true
		queue_redraw()
		return
	# مشهد لعب مزدحم
	pp = WC
	cam.position = WC
	if SHOTCHAR >= 0:
		char_sel = SHOTCHAR
		pcol = CHARS[char_sel]["col"]
	if SHOTSCENE == "stagein":
		# لحظة بانر انتقال المرحلة (للتوثيق)
		stage_intro_t = 1.6
		stage_intro_title = T("Stage %d - %s") % [3, T(Balance.STAGE_TITLES[2])]
		stage_intro_sub = "+25 HP"
	stage = 2 if SHOTSCENE == "play" else 3
	# play1..play5 = مرحلة محددة (للتشخيص البصري)
	if SHOTSCENE.begins_with("play") and SHOTSCENE.length() == 5:
		stage = clampi(int(SHOTSCENE.substr(4)), 1, FINAL_STAGE)
	_gen_decor()
	if SHOTSCENE == "boss" or SHOTSCENE == "cover":
		boss_alive = true
		stage = 5   # ملك الرماد في الفراغ للعرض
		_gen_decor()
		var th = THEMES[theme_idx()]
		boss_name_cur = "The Ash King"
		if SHOTSCENE == "cover":
			_hud_visible(false)
		var kpos := WC + (Vector2(140, -80) if SHOTSCENE == "cover" else Vector2(300, -120))
		var king = {"pos": kpos, "col": Color(0.62, 0.35, 0.92), "r": 58.0,
			"hp": 500.0, "maxhp": 1400.0, "spd": 53.0, "type": "boss", "orbcd": 0.0,
			"kind": 5, "atk": 1.0, "spiral": 3.0, "charge": 0.0,
			"phase": 1, "atk2": 3.0, "tcd": 0.0, "cyc": 0, "sumt": 3.0, "split_done": false, "reborn": true}
		enemies.append(king)
		# درعه الدائري
		for k in 6:
			var ga2 := TAU * float(k) / 6.0
			enemies.append({"pos": Vector2(king["pos"]) + Vector2(cos(ga2), sin(ga2)) * 88.0,
				"col": th["pal"][k % 4], "r": 13.0, "hp": 20.0, "maxhp": 20.0,
				"spd": 80.0, "type": "norm", "orbcd": 0.0, "orbit_host": king, "orb_a": ga2})
		for i in 7:
			hazards.append({"pos": WC + Vector2(60 + i * 42, -20 + sin(i * 1.1) * 60.0),
				"r": 26.0, "life": 2.0, "dps": 13.0, "col": Color(1.0, 0.35, 0.05)})
		for i in 26:
			var a := (TAU / 26.0) * i + 0.4
			_ebullet(WC + Vector2(300, -120) + Vector2(cos(a), sin(a)) * (60.0 + (i % 5) * 40.0), Vector2(cos(a), sin(a)) * 135.0, th["boss_col"])
		wipe_t = 0.25
	else:
		var etypecol := {"norm": Balance.ENEMY_PAL[0], "fast": Balance.ENEMY_PAL[1], "tank": Balance.ENEMY_PAL[2], "split": Balance.ENEMY_PAL[3], "shooter": Balance.COL_ENEMY, "bomber": Balance.COL_ENEMY_HI}
		for i in 40:
			var a := (TAU / 40.0) * i
			var rad := rng.randf_range(180.0, 330.0)
			var types := ["norm", "fast", "tank", "split", "shooter", "bomber"]
			var tt: String = types[i % types.size()]
			var r := 14.0
			match tt:
				"fast": r = 9.0
				"tank": r = 24.0
				"split": r = 17.0
				"bomber": r = 13.0
			enemies.append({"pos": WC + Vector2(cos(a), sin(a)) * rad,
				"col": etypecol[tt], "r": r, "hp": 30.0, "maxhp": 30.0,
				"spd": 60.0, "type": tt, "orbcd": 0.0})
		# نخبة (زعماء صغار) وسط العاديين
		for i in 4:
			var a2 := (TAU / 4.0) * i + 0.5
			enemies.append({"pos": WC + Vector2(cos(a2), sin(a2)) * 280.0,
				"col": Balance.COL_ENEMY_HI, "r": 27.0, "hp": 120.0, "maxhp": 190.0,
				"spd": 48.0, "type": "elite", "orbcd": 0.0, "atk": 1.0})
		for i in 6:
			var a3 := (TAU / 6.0) * i + 0.2
			_ebullet(WC + Vector2(cos(a3), sin(a3)) * 210.0, Vector2(cos(a3 + PI), sin(a3 + PI)) * 195.0, Color(1.0, 0.82, 0.25))
		for i in 10:
			var a := (TAU / 10.0) * i
			bullets.append({"pos": WC + Vector2(cos(a), sin(a)) * rng.randf_range(60, 190), "vel": Vector2(cos(a), sin(a)) * 600.0, "life": 1.0, "pierce": 0})
		_dmgnum(WC + Vector2(-140, -90), 28, Color(1, 1, 1))
		_dmgnum(WC + Vector2(160, -60), 56, Color(1, 0.85, 0.25), true)
		_dmgnum(WC + Vector2(80, 120), 26, Color(0.5, 0.95, 1.0))
		# فخاخ للعرض: دايرة الأشواك حوالين اللاعب + شوكة منطلقة
		for k in 10:
			var ra3 := TAU * float(k) / 10.0
			traps.append({"k": "spike", "pos": WC + Vector2(cos(ra3), sin(ra3)) * 96.0, "warn": 0.5, "act": 0.9, "sprung": false})
		traps.append({"k": "spike", "pos": WC + Vector2(-260, 190), "warn": 0.0, "act": 0.9, "sprung": true})
	for i in 14:
		gems.append({"pos": WC + Vector2(rng.randf_range(-300, 300), rng.randf_range(-250, 250))})
	for i in 4:
		var a := (TAU / 4.0) * i
		_burst(WC + Vector2(cos(a), sin(a)) * 180.0, Color(1.0, 0.55, 0.12), 12)
	for i in 9:
		trail.append({"pos": WC + Vector2(-40 - i * 14, 30 + i * 8), "life": 0.05 + i * 0.03})
	orbit_n = 2
	aura_r = 90.0
	orbit_ang = 0.7
	kills = 348
	level = 9
	xp = 11
	gametime = 187.0
	stage_timer = 23.0
	hp = 64.0
	dash_cd = 0.8
	state = ST_PLAY
	if SHOTSCENE == "levelup":
		_enter_levelup()
	if SHOTSCENE == "pause":
		pause_sel = 1   # "Restart Run" مختار للعرض
		_refresh_pause_ui()
		pause_dim.visible = true
		state = ST_PAUSE
	_update_hud()
	queue_redraw()
