extends Node2D
# ============================================================
#  ناجي المكعبات — CUBE SURVIVOR  v3
#  قوائم + إعدادات + مراحل متغيّرة كل دقيقة + زعيم كل دقيقة
#  (يمسح الأعداء ويوقف المؤقت) + داش + أرقام ضرر + موسيقى
# ============================================================

const SHOTMODE := false
const SHOTSCENE := "play"   # "menu" | "settings" | "play" | "boss" | "levelup"
const SHOTPATH := "C:/Users/madao/AppData/Local/Temp/claude/c--Users-madao-OneDrive-Desktop-darklawh-GAME/4f741e46-2be3-4eba-83bf-07d7c9c8bbcd/scratchpad/shot_shooter.png"

const W := 1280.0            # حجم الشاشة (الكاميرا)
const H := 720.0
const WW := 2560.0           # حجم عالم الساحة (2×2 شاشات)
const WH := 1440.0
var C := Vector2(W * 0.5, H * 0.5)     # مركز الشاشة (للواجهات)
var WC := Vector2(WW * 0.5, WH * 0.5)  # مركز العالم

enum { ST_MENU, ST_SETTINGS, ST_PLAY, ST_LEVELUP, ST_PAUSE, ST_OVER, ST_VICTORY }
var state := ST_MENU

# --- سجلات دائمة ---
var rec_time := 0.0
var rec_kills := 0
var rec_stage := 0
var rec_wins := 0
const FINAL_STAGE := 5   # الحملة: 5 فصول وتنتهي بالنصر

# --- الأبطال ---
var char_sel := 0
var CHARS := [
	{"name": "Soldier", "col": Color(0.20, 0.45, 0.90), "desc": "Balanced — no perks, no flaws"},
	{"name": "Burner", "col": Color(0.90, 0.30, 0.20), "desc": "Starts with a fire aura — but less HP"},
	{"name": "Runner", "col": Color(0.30, 0.80, 0.40), "desc": "Faster with wider pickup — but less damage"},
	{"name": "Wrecker", "col": Color(0.65, 0.35, 0.90), "desc": "Starts with a blade, hits harder — but slower"},
]
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
var EVOS := {
	"estorm":   {"name": "Polar Storm", "desc": "Lightning doubles and freezes all it touches", "need": "Lightning x2 + Frost x2"},
	"ecyclone": {"name": "Blade Cyclone", "desc": "Double blades, faster and deadlier", "need": "Blade x3 + Agility x2"},
	"ecluster": {"name": "Cluster Bombs", "desc": "Every explosion spawns 3 smaller ones", "need": "Explosive x2 + Massive x2"},
}
var event_t := 0.0
var meteors := []       # {pos, t}
var chest = null        # {pos}
var boxes := []         # صناديق النخبة {pos} — بركة عشوائية فورية

# --- settings (persisted) ---
var sfx_vol := 8      # 0..10
var mus_vol := 8      # 0..10
var shake_on := true
var fullscreen_on := false
var set_sel := 0      # الصف المختار في شاشة الإعدادات

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

var THEMES := [
	{"name": "Meadow", "bg": Color(0.24, 0.55, 0.24), "grid": Color(0.20, 0.48, 0.20),
	 "decor": Color(0.16, 0.40, 0.16), "boss_col": Color(0.15, 0.65, 0.25), "boss_name": "Meadow Warden",
	 "pal": [Color(0.85, 0.38, 0.30), Color(0.82, 0.58, 0.24), Color(0.62, 0.36, 0.75), Color(0.55, 0.42, 0.30)]},
	{"name": "Desert", "bg": Color(0.76, 0.64, 0.38), "grid": Color(0.70, 0.58, 0.33),
	 "decor": Color(0.55, 0.45, 0.26), "boss_col": Color(0.92, 0.89, 0.78), "boss_name": "Bone King",
	 "pal": [Color(0.80, 0.42, 0.18), Color(0.62, 0.32, 0.22), Color(0.88, 0.66, 0.26), Color(0.50, 0.26, 0.12)],
	 "bone": true},
	{"name": "Glacier", "bg": Color(0.80, 0.87, 0.92), "grid": Color(0.54, 0.66, 0.75),
	 "decor": Color(0.80, 0.88, 0.94), "boss_col": Color(0.20, 0.75, 0.90), "boss_name": "Frost Heart",
	 "pal": [Color(0.30, 0.52, 0.82), Color(0.48, 0.75, 0.92), Color(0.22, 0.38, 0.65), Color(0.70, 0.82, 0.98)]},
	{"name": "Volcano", "bg": Color(0.28, 0.11, 0.09), "grid": Color(0.26, 0.11, 0.08),
	 "decor": Color(0.95, 0.40, 0.10), "boss_col": Color(0.90, 0.20, 0.10), "boss_name": "Magma Beast",
	 "pal": [Color(0.88, 0.24, 0.14), Color(0.95, 0.52, 0.14), Color(0.62, 0.18, 0.18), Color(0.95, 0.76, 0.24)]},
	{"name": "The Void", "bg": Color(0.04, 0.03, 0.06), "grid": Color(0.14, 0.12, 0.24),
	 "decor": Color(0.75, 0.55, 1.00), "boss_col": Color(0.65, 0.25, 0.90), "boss_name": "Void Shade",
	 "pal": [Color(0.56, 0.30, 0.82), Color(0.78, 0.36, 0.88), Color(0.36, 0.26, 0.62), Color(0.86, 0.56, 0.95)]},
]
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
var zaps := []          # رسم الصواعق {pts, life}
var hazards := []       # مناطق خطر أرضية {pos, r, life, dps, col}
var vacuum_t := 0.0     # شفط البلورات بعد الزعيم
var boss_name_cur := ""

# --- feel ---
var shake := 0.0
var flash := 0.0
var wipe_t := 0.0          # وميض مسح الأعداء
var hurt_snd_cd := 0.0

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
var lv_cards: Array = []
var lv_choices: Array = []

var go_dim: ColorRect
var go_title: Label
var go_stats: Label

var menu_dim: ColorRect
var menu_labels: Array = []
var menu_char: Label
var menu_rec: Label
var vic_dim: ColorRect
var vic_stats: Label
var lbl_combo: Label
var rings := []   # حلقات موت متمددة {pos, t, max, col}
var set_dim: ColorRect
var set_rows: Array = []
var set_bars: Array = []   # [{back, fill}] لصفّي الصوت
var pause_dim: ColorRect

var snd_pool: Array = []
var snd_idx := 0
var SND := {}
var MUS := {}
var music_pl: AudioStreamPlayer

var ENEMY_COLS := [
	Color(0.85, 0.30, 0.30), Color(0.35, 0.55, 0.90), Color(0.55, 0.80, 0.40),
	Color(0.80, 0.55, 0.25), Color(0.70, 0.40, 0.80), Color(0.30, 0.75, 0.75),
	Color(0.90, 0.75, 0.30), Color(0.55, 0.45, 0.35),
]

var UPS := [
	{"id": "dmg",   "name": "Firepower", "desc": "+8 projectile damage"},
	{"id": "rate",  "name": "Quick Trigger", "desc": "+15% fire rate"},
	{"id": "multi", "name": "Extra Volley", "desc": "+1 projectile per shot"},
	{"id": "pierce","name": "Piercing", "desc": "Shots pierce +1 enemy"},
	{"id": "orbit", "name": "Orbit Blade", "desc": "+1 blade spinning around you"},
	{"id": "aura",  "name": "Burning Aura", "desc": "Damage aura around you (+size)"},
	{"id": "crit",  "name": "Deathblow", "desc": "+10% chance of double damage"},
	{"id": "speed", "name": "Agility", "desc": "+12% move speed"},
	{"id": "hp",    "name": "Toughness", "desc": "+25 max HP + heal"},
	{"id": "magnet","name": "Magnet", "desc": "+60% gem pickup range"},
	{"id": "dash",  "name": "Swift Dash", "desc": "-25% dash cooldown"},
	{"id": "chain", "name": "Sky Lightning", "desc": "Bolts strike and chain between enemies"},
	{"id": "explode","name": "Explosive Death", "desc": "Enemies explode on death"},
	{"id": "ric",   "name": "Ricochet", "desc": "Shots bounce to a nearby enemy"},
	{"id": "rear",  "name": "Rear Guard", "desc": "+1 shot fired backwards"},
	{"id": "regen", "name": "Regeneration", "desc": "+HP every second"},
	{"id": "armor", "name": "Steel Plates", "desc": "-10% damage taken"},
	{"id": "steal", "name": "Lifesteal", "desc": "Your damage heals you (3%/rank)"},
	{"id": "slow",  "name": "Frost Touch", "desc": "Your hits slow enemies"},
	{"id": "big",   "name": "Massive Shots", "desc": "+25% projectile size"},
]
var dash_cd_max := DASH_CD

# ================================================================
func _ready() -> void:
	rng.randomize()
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
		env.glow_intensity = 0.55
		env.glow_strength = 0.9
		env.glow_bloom = 0.08
		env.glow_hdr_threshold = 0.90
		var we := WorldEnvironment.new()
		we.environment = env
		add_child(we)
	_load_sounds()
	_build_hud()
	_build_levelup_ui()
	_build_gameover_ui()
	_build_menu_ui()
	_build_settings_ui()
	_build_pause_ui()
	_build_victory_ui()
	_apply_fullscreen()
	_gen_decor()
	_show_only_menu()
	if not SHOTMODE:
		_play_music("menu")

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

# ---------- settings persistence ----------
func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		sfx_vol = clampi(int(cfg.get_value("audio", "sfx_vol", 8)), 0, 10)
		mus_vol = clampi(int(cfg.get_value("audio", "mus_vol", 8)), 0, 10)
		shake_on = bool(cfg.get_value("video", "shake", true))
		rec_time = float(cfg.get_value("records", "time", 0.0))
		rec_kills = int(cfg.get_value("records", "kills", 0))
		rec_stage = mini(int(cfg.get_value("records", "stage", 0)), FINAL_STAGE)
		rec_wins = int(cfg.get_value("records", "wins", 0))
		fullscreen_on = bool(cfg.get_value("video", "fullscreen", false))
		char_sel = clampi(int(cfg.get_value("progress", "char", 0)), 0, CHARS.size() - 1)

func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sfx_vol", sfx_vol)
	cfg.set_value("audio", "mus_vol", mus_vol)
	cfg.set_value("video", "shake", shake_on)
	cfg.set_value("video", "fullscreen", fullscreen_on)
	cfg.set_value("records", "time", rec_time)
	cfg.set_value("records", "kills", rec_kills)
	cfg.set_value("records", "stage", rec_stage)
	cfg.set_value("records", "wins", rec_wins)
	cfg.set_value("progress", "char", char_sel)
	cfg.save("user://settings.cfg")

func _update_records(victory: bool) -> void:
	if gametime > rec_time: rec_time = gametime
	if kills > rec_kills: rec_kills = kills
	if stage > rec_stage: rec_stage = mini(stage, FINAL_STAGE)
	if victory: rec_wins += 1
	_save_settings()

func _apply_fullscreen() -> void:
	if fullscreen_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

# ---------- audio ----------
func _load_sounds() -> void:
	for nm in ["shoot", "hit", "kill", "gem", "levelup", "hurt", "boss", "death",
			"dash", "click", "bossdie", "sweep", "zap", "explode"]:
		var st = load("res://assets/%s.wav" % nm)
		if st != null:
			SND[nm] = st
	for i in 12:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		snd_pool.append(pl)
	music_pl = AudioStreamPlayer.new()
	music_pl.finished.connect(func(): music_pl.play())
	add_child(music_pl)
	# موسيقى لكل مرحلة وزعيم + القائمة
	var menu_m = load("res://assets/music.wav")
	if menu_m != null:
		MUS["menu"] = menu_m
	for i in 5:
		var sm = load("res://assets/mus_stage%d.wav" % i)
		if sm != null:
			MUS["s%d" % i] = sm
		var bm = load("res://assets/mus_boss%d.wav" % i)
		if bm != null:
			MUS["b%d" % i] = bm

func sfx(nm: String, vol_db: float = 0.0, pitch_lo: float = 0.95, pitch_hi: float = 1.05) -> void:
	if sfx_vol <= 0 or not SND.has(nm):
		return
	var pl: AudioStreamPlayer = snd_pool[snd_idx]
	snd_idx = (snd_idx + 1) % snd_pool.size()
	pl.stream = SND[nm]
	pl.volume_db = vol_db + linear_to_db(float(sfx_vol) / 10.0)
	pl.pitch_scale = rng.randf_range(pitch_lo, pitch_hi)
	pl.play()

func _apply_music_vol() -> void:
	if mus_vol <= 0:
		music_pl.volume_db = -80.0
	else:
		music_pl.volume_db = linear_to_db(float(mus_vol) / 10.0) - 6.0

func _play_music(key: String) -> void:
	if not MUS.has(key):
		return
	_apply_music_vol()
	if music_pl.stream == MUS[key] and music_pl.playing:
		return
	music_pl.stream = MUS[key]
	music_pl.play()

# ================================================================
#  UI BUILDERS
func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var font_col := Color(1, 1, 1)
	lbl_kills = _mk_label(Vector2(24, 18), 30, font_col)
	lbl_level = _mk_label(Vector2(W * 0.5 - 160, 14), 30, font_col)
	lbl_level.size = Vector2(320, 40)
	lbl_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_time = _mk_label(Vector2(W - 240, 18), 30, font_col)
	lbl_time.size = Vector2(216, 40)
	lbl_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_stage = _mk_label(Vector2(W - 340, 60), 22, Color(0.95, 0.9, 0.7))
	lbl_stage.size = Vector2(316, 30)
	lbl_stage.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hp_back = _mk_rect(Vector2(24, 62), Vector2(240, 22), Color(0, 0, 0, 0.55))
	hp_fill = _mk_rect(Vector2(27, 65), Vector2(234, 16), Color(0.30, 0.85, 0.30))
	dash_back = _mk_rect(Vector2(24, 90), Vector2(120, 10), Color(0, 0, 0, 0.55))
	dash_fill = _mk_rect(Vector2(26, 92), Vector2(116, 6), Color(0.35, 0.75, 1.0))
	lbl_combo = _mk_label(Vector2(24, 106), 26, Color(1, 0.85, 0.35))
	lbl_combo.visible = false
	xp_back = _mk_rect(Vector2(W * 0.5 - 130, 54), Vector2(260, 14), Color(0, 0, 0, 0.55))
	xp_fill = _mk_rect(Vector2(W * 0.5 - 127, 57), Vector2(0, 8), Color(0.45, 0.70, 1.0))
	lbl_boss = _mk_label(Vector2(W * 0.5 - 160, 72), 20, Color(1, 0.75, 0.4))
	lbl_boss.size = Vector2(320, 28)
	lbl_boss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg = _mk_label(Vector2(W * 0.5 - 300, 130), 44, Color(1, 0.9, 0.5))
	lbl_msg.size = Vector2(600, 80)
	lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_msg.visible = false

func _mk_label(pos: Vector2, sz: int, col: Color, parent: Node = null) -> Label:
	var l := Label.new()
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

func _mk_rect(pos: Vector2, sz: Vector2, col: Color, parent: Node = null) -> ColorRect:
	var r := ColorRect.new()
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
	var ch := 190.0
	var gap := 40.0
	var x0 := W * 0.5 - (cw * 3 + gap * 2) * 0.5
	for i in 3:
		var panel := _mk_rect(Vector2(x0 + (cw + gap) * i, 250), Vector2(cw, ch), Color(0.10, 0.12, 0.18, 0.95), lv_dim)
		var key := _mk_label(Vector2(16, 10), 34, Color(0.45, 0.70, 1.0), panel)
		key.text = "[%d]" % (i + 1)
		var nm := _mk_label(Vector2(16, 56), 30, Color(1, 1, 1), panel)
		nm.size = Vector2(cw - 32, 40)
		var ds := _mk_label(Vector2(16, 108), 21, Color(0.75, 0.78, 0.85), panel)
		ds.size = Vector2(cw - 32, 70)
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lv_cards.append({"panel": panel, "name": nm, "desc": ds})
	lv_dim.visible = false

func _build_gameover_ui() -> void:
	go_dim = _mk_rect(Vector2.ZERO, Vector2(W, H), Color(0.0, 0.0, 0.0, 0.94))
	go_title = _mk_label(Vector2(W * 0.5 - 300, 190), 64, Color(0.95, 0.25, 0.25), go_dim)
	go_title.size = Vector2(600, 90)
	go_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_title.text = "YOU DIED"
	go_stats = _mk_label(Vector2(W * 0.5 - 350, 310), 30, Color(0.9, 0.9, 0.9), go_dim)
	go_stats.size = Vector2(700, 240)
	go_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	go_dim.visible = false

func _build_menu_ui() -> void:
	menu_dim = _mk_rect(Vector2.ZERO, Vector2(W, H), Color(0, 0, 0, 0.25))
	var t := _mk_label(Vector2(W * 0.5 - 400, 130), 78, Color(0.45, 0.75, 1.0), menu_dim)
	t.size = Vector2(800, 110)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.text = "CUBE SURVIVOR"
	var sub := _mk_label(Vector2(W * 0.5 - 400, 240), 24, Color(0.8, 0.8, 0.85), menu_dim)
	sub.size = Vector2(800, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.text = "A roguelike run: five stages, a boss every minute, and the Ash King at the end"
	# اختيار البطل (المعاينة بتترسم في _draw عند y≈385)
	menu_char = _mk_label(Vector2(W * 0.5 - 400, 300), 26, Color(0.95, 0.85, 0.55), menu_dim)
	menu_char.size = Vector2(800, 40)
	menu_char.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var opts := ["[Enter]  Start Run", "[S] Settings        [Esc] Quit"]
	for i in opts.size():
		var o := _mk_label(Vector2(W * 0.5 - 300, 472 + i * 54), 30 if i == 0 else 24, Color(1, 1, 1) if i == 0 else Color(0.78, 0.78, 0.84), menu_dim)
		o.size = Vector2(600, 44)
		o.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		o.text = opts[i]
		menu_labels.append(o)
	# الأرقام القياسية + الشظايا
	menu_rec = _mk_label(Vector2(W * 0.5 - 450, H - 110), 22, Color(0.75, 0.80, 0.90), menu_dim)
	menu_rec.size = Vector2(900, 34)
	menu_rec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _mk_label(Vector2(W * 0.5 - 400, H - 66), 20, Color(0.7, 0.7, 0.75), menu_dim)
	hint.size = Vector2(800, 30)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = "WASD move  •  Shift/Space dash  •  Auto-fire  •  P pause"
	menu_dim.visible = false

func _refresh_menu() -> void:
	var ch = CHARS[char_sel]
	menu_char.text = "Survivor:  < %s >   (A/D)   -   %s" % [ch["name"], ch["desc"]]
	var m := int(rec_time) / 60
	var s := int(rec_time) % 60
	var wins_txt := "  •  Wins: %d" % rec_wins if rec_wins > 0 else ""
	menu_rec.text = "Best run: Stage %d  •  %02d:%02d  •  %d kills%s" % [rec_stage, m, s, rec_kills, wins_txt]

func _build_victory_ui() -> void:
	vic_dim = _mk_rect(Vector2.ZERO, Vector2(W, H), Color(0.0, 0.0, 0.0, 0.94))
	var t := _mk_label(Vector2(W * 0.5 - 400, 170), 62, Color(1.0, 0.85, 0.30), vic_dim)
	t.size = Vector2(800, 90)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.text = "VICTORY - The Ash King has fallen!"
	vic_stats = _mk_label(Vector2(W * 0.5 - 400, 300), 28, Color(0.92, 0.92, 0.92), vic_dim)
	vic_stats.size = Vector2(800, 240)
	vic_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vic_dim.visible = false

func _build_settings_ui() -> void:
	set_dim = _mk_rect(Vector2.ZERO, Vector2(W, H), Color(0, 0, 0, 0.72))
	var t := _mk_label(Vector2(W * 0.5 - 300, 100), 52, Color(1, 0.9, 0.5), set_dim)
	t.size = Vector2(600, 80)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.text = "SETTINGS"
	# 4 صفوف قابلة للاختيار: مؤثرات / موسيقى / اهتزاز / ملء الشاشة
	for i in 4:
		var r := _mk_label(Vector2(W * 0.5 - 300, 200 + i * 96), 32, Color(1, 1, 1), set_dim)
		r.size = Vector2(600, 46)
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		set_rows.append(r)
	# شريطا مستوى الصوت تحت أول صفّين
	for i in 2:
		var back := _mk_rect(Vector2(W * 0.5 - 160, 250 + i * 96), Vector2(320, 18), Color(0.15, 0.15, 0.20, 0.9), set_dim)
		var fill := _mk_rect(Vector2(W * 0.5 - 157, 253 + i * 96), Vector2(0, 12), Color(0.45, 0.70, 1.0), set_dim)
		set_bars.append({"back": back, "fill": fill})
	var hint := _mk_label(Vector2(W * 0.5 - 400, 610), 24, Color(0.72, 0.72, 0.78), set_dim)
	hint.size = Vector2(800, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = "W/S select row    •    A/D adjust    •    Esc back"
	set_dim.visible = false

func _refresh_settings_ui() -> void:
	var names := ["Sound Effects", "Music", "Screen Shake", "Fullscreen"]
	var vals := ["%d / 10" % sfx_vol, "%d / 10" % mus_vol,
		"ON" if shake_on else "OFF", "ON" if fullscreen_on else "OFF"]
	for i in 4:
		var sel := i == set_sel
		set_rows[i].text = ("‹  %s : %s  ›" if sel else "%s : %s") % [names[i], vals[i]]
		set_rows[i].add_theme_color_override("font_color", Color(1, 0.85, 0.35) if sel else Color(1, 1, 1))
	set_bars[0]["fill"].size.x = 314.0 * float(sfx_vol) / 10.0
	set_bars[1]["fill"].size.x = 314.0 * float(mus_vol) / 10.0
	set_bars[0]["fill"].color = Color(1, 0.85, 0.35) if set_sel == 0 else Color(0.45, 0.70, 1.0)
	set_bars[1]["fill"].color = Color(1, 0.85, 0.35) if set_sel == 1 else Color(0.45, 0.70, 1.0)

func _adjust_setting(d: int) -> void:
	match set_sel:
		0:
			sfx_vol = clampi(sfx_vol + d, 0, 10)
			sfx("click")   # يسمع المستوى الجديد فوراً
		1:
			mus_vol = clampi(mus_vol + d, 0, 10)
			_apply_music_vol()
			if mus_vol > 0 and not music_pl.playing:
				music_pl.play()
		2:
			shake_on = not shake_on
			sfx("click")
		3:
			fullscreen_on = not fullscreen_on
			_apply_fullscreen()
			sfx("click")
	_save_settings()
	_refresh_settings_ui()

func _build_pause_ui() -> void:
	pause_dim = _mk_rect(Vector2.ZERO, Vector2(W, H), Color(0, 0, 0, 0.55))
	var t := _mk_label(Vector2(W * 0.5 - 300, 250), 56, Color(1, 1, 1), pause_dim)
	t.size = Vector2(600, 80)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.text = "PAUSED"
	var o := _mk_label(Vector2(W * 0.5 - 300, 360), 30, Color(0.85, 0.85, 0.9), pause_dim)
	o.size = Vector2(600, 100)
	o.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	o.text = "[P] Resume      [M] Main Menu"
	pause_dim.visible = false

func _show_only_menu() -> void:
	menu_dim.visible = true
	set_dim.visible = false
	lv_dim.visible = false
	go_dim.visible = false
	pause_dim.visible = false
	vic_dim.visible = false
	_refresh_menu()
	_hud_visible(false)

func _hud_visible(v: bool) -> void:
	for n in [lbl_kills, lbl_level, lbl_time, lbl_stage, lbl_boss,
			hp_back, hp_fill, xp_back, xp_fill, dash_back, dash_fill]:
		n.visible = v
	if not v:
		lbl_combo.visible = false

# ================================================================
#  RUN CONTROL
func _new_run() -> void:
	pp = WC
	cam.position = WC
	pspeed = 305.0
	maxhp = 115.0
	fire_cd = 0.0; fire_rate = 0.46
	bullet_dmg = 23.0
	invuln = 0.0; dash_cd = 0.0; dash_t = 0.0; dash_cd_max = DASH_CD
	kills = 0; level = 1; xp = 0; xp_need = 5; gametime = 0.0
	stage = 1; stage_timer = STAGE_LEN
	multishot = 1
	pierce = 0; crit = 0.0; magnet = 150.0; orbit_n = 0; aura_r = 0.0
	chain_n = 0; chain_t = 0.0; explode_n = 0; ric_n = 0; rear_n = 0
	regen_n = 0; armor_n = 0; steal_n = 0; slow_n = 0; bsize = 1.0
	# الناجي المختار
	pcol = CHARS[char_sel]["col"]
	match char_sel:
		1:  # المحترق
			aura_r = 85.0
			maxhp *= 0.85
		2:  # العدّاء
			pspeed *= 1.2
			magnet *= 1.5
			bullet_dmg *= 0.9
		3:  # المدمّر
			orbit_n = 1
			bullet_dmg *= 1.2
			pspeed *= 0.92
	hp = maxhp
	# كومبو / تطوّرات / أحداث
	combo = 0; combo_best = 0; combo_t = 0.0; hitstop = 0.0
	ups_count = {}
	evo_storm = false; evo_cyclone = false; evo_cluster = false; evo_pending = ""
	event_t = rng.randf_range(18.0, 32.0)
	meteors.clear(); chest = null; boxes.clear(); rings.clear()
	freeze_t = 0.0; void_intro = 0.0; king_spawned = false
	enemies.clear(); bullets.clear(); ebullets.clear(); gems.clear()
	parts.clear(); trail.clear(); dmgnums.clear(); zaps.clear(); hazards.clear()
	vacuum_t = 0.0
	spawn_cd = 0.5
	boss_alive = false
	shake = 0.0; flash = 0.0; wipe_t = 0.0
	_play_music("s0")
	_gen_decor()
	menu_dim.visible = false
	go_dim.visible = false
	vic_dim.visible = false
	_save_settings()   # يحفظ اختيار الناجي
	_hud_visible(true)
	state = ST_PLAY
	_flash_msg("Stage 1 - %s" % THEMES[0]["name"], 1.8)

func _to_menu() -> void:
	state = ST_MENU
	_play_music("menu")
	_show_only_menu()

# ================================================================
#  INPUT
func _unhandled_input(ev: InputEvent) -> void:
	if SHOTMODE:
		return
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	var k: int = ev.keycode
	match state:
		ST_MENU:
			if k == KEY_ENTER or k == KEY_KP_ENTER:
				sfx("click"); _new_run()
			elif k == KEY_A or k == KEY_LEFT:
				char_sel = (char_sel + CHARS.size() - 1) % CHARS.size()
				sfx("click"); _refresh_menu()
			elif k == KEY_D or k == KEY_RIGHT:
				char_sel = (char_sel + 1) % CHARS.size()
				sfx("click"); _refresh_menu()
			elif k == KEY_S:
				sfx("click"); set_sel = 0; _refresh_settings_ui()
				menu_dim.visible = false; set_dim.visible = true
				state = ST_SETTINGS
			elif k == KEY_ESCAPE:
				get_tree().quit()
		ST_VICTORY:
			if k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_M or k == KEY_ESCAPE:
				sfx("click"); vic_dim.visible = false; _to_menu()
		ST_SETTINGS:
			if k == KEY_W or k == KEY_UP:
				set_sel = (set_sel + 3) % 4; sfx("click"); _refresh_settings_ui()
			elif k == KEY_S or k == KEY_DOWN:
				set_sel = (set_sel + 1) % 4; sfx("click"); _refresh_settings_ui()
			elif k == KEY_A or k == KEY_LEFT:
				_adjust_setting(-1)
			elif k == KEY_D or k == KEY_RIGHT:
				_adjust_setting(1)
			elif k == KEY_ENTER or k == KEY_SPACE:
				if set_sel >= 2:
					_adjust_setting(1)
			elif k == KEY_ESCAPE:
				sfx("click"); set_dim.visible = false
				menu_dim.visible = true; state = ST_MENU
		ST_LEVELUP:
			var pick := -1
			if k == KEY_1 or k == KEY_KP_1: pick = 0
			elif k == KEY_2 or k == KEY_KP_2: pick = 1
			elif k == KEY_3 or k == KEY_KP_3: pick = 2
			if pick >= 0 and pick < lv_choices.size():
				sfx("click")
				_apply_upgrade(lv_choices[pick])
				lv_dim.visible = false
				state = ST_PLAY
		ST_OVER:
			if k == KEY_R or k == KEY_ENTER:
				sfx("click"); go_dim.visible = false; _new_run()
			elif k == KEY_M or k == KEY_ESCAPE:
				sfx("click"); go_dim.visible = false; _to_menu()
		ST_PAUSE:
			if k == KEY_ESCAPE or k == KEY_P:
				pause_dim.visible = false; state = ST_PLAY
			elif k == KEY_M:
				sfx("click"); pause_dim.visible = false; _to_menu()
		ST_PLAY:
			if k == KEY_ESCAPE or k == KEY_P:
				pause_dim.visible = true; state = ST_PAUSE

func _process(dt: float) -> void:
	if SHOTMODE:
		return
	animt += dt
	if state == ST_PLAY:
		if hitstop > 0.0:
			hitstop -= dt   # توقّف لحظي — العالم متجمد
		else:
			_step(dt)
	queue_redraw()

# ================================================================
#  MAIN STEP
func _step(dt: float) -> void:
	if not boss_alive:
		gametime += dt          # المؤقت يقف أثناء الزعيم
		stage_timer -= dt
		if stage_timer <= 0.0:
			_spawn_boss()
	# الفراغ: عودة أسياد العوالم بعد المقدمة
	if stage == FINAL_STAGE and void_intro > 0.0:
		void_intro -= dt
		if void_intro <= 0.0:
			_spawn_void_gauntlet()
	hurt_snd_cd = maxf(0.0, hurt_snd_cd - dt)
	invuln = maxf(0.0, invuln - dt)
	dash_cd = maxf(0.0, dash_cd - dt)
	dash_t = maxf(0.0, dash_t - dt)

	# movement + dash
	var mv := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): mv.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): mv.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): mv.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): mv.x += 1
	# يد تحكم: العصا اليسرى + زر A/الكتف للاندفاع
	var jx := Input.get_joy_axis(0, JOY_AXIS_LEFT_X)
	var jy := Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	if absf(jx) > 0.25: mv.x += jx
	if absf(jy) > 0.25: mv.y += jy
	var pad_dash := Input.is_joy_button_pressed(0, JOY_BUTTON_A) or Input.is_joy_button_pressed(0, JOY_BUTTON_RIGHT_SHOULDER)
	if (Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_SPACE) or pad_dash) and dash_cd <= 0.0 and mv != Vector2.ZERO:
		dash_t = 0.16
		invuln = maxf(invuln, 0.35)
		dash_cd = dash_cd_max
		sfx("dash", -4.0)
	var spd := pspeed * (3.4 if dash_t > 0.0 else 1.0)
	if theme_idx() == 2:
		spd *= 0.75   # الجليد بيبطّئ الحركة بجد
	if freeze_t > 0.0:
		mv = Vector2.ZERO   # متجمّد — الحركة مشلولة لحظياً
	if mv != Vector2.ZERO:
		pp += mv.normalized() * spd * dt
		trail.append({"pos": pp, "life": 0.35 if dash_t > 0.0 else 0.18})
		if trail.size() > 48:
			trail.remove_at(0)
	pp.x = clampf(pp.x, PR, WW - PR)
	pp.y = clampf(pp.y, PR, WH - PR)
	# الكاميرا تتبع اللاعب داخل حدود العالم
	var ct := Vector2(clampf(pp.x, W * 0.5, WW - W * 0.5), clampf(pp.y, H * 0.5, WH - H * 0.5))
	cam.position = cam.position.lerp(ct, minf(1.0, 10.0 * dt))

	orbit_ang += dt * (5.2 if evo_cyclone else 3.2)
	if regen_n > 0:
		hp = minf(maxhp, hp + float(regen_n) * 1.4 * dt)
	if chain_n > 0:
		chain_t -= dt
		if chain_t <= 0.0:
			_do_chain()

	if not boss_alive:
		_spawn_step(dt)
	_enemy_step(dt)
	_ebullet_step(dt)
	_hazard_step(dt)
	_fire_step(dt)
	_bullet_step(dt)
	_orbit_step(dt)
	_aura_step(dt)
	_gem_step(dt)
	_part_step(dt)

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
	_chest_step()
	_box_step()
	# فخاخ الفصول — دايماً شغالة
	var ti2 := theme_idx()
	if ti2 >= 1:
		trap_t -= dt
		if trap_t <= 0.0:
			match ti2:
				1:
					# دايرة 10 أشواك حواليك — الداش هو المخرج الوحيد
					for k in 10:
						var ra := TAU * float(k) / 10.0
						traps.append({"k": "spike", "pos": pp + Vector2(cos(ra), sin(ra)) * 96.0, "warn": 1.0, "act": 0.9, "sprung": false})
					sfx("hit", -4.0, 0.6, 0.7)
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
					sfx("boss", -6.0)
					_flash_msg("The Void summons the traps of all realms!", 1.5)
					trap_t = rng.randf_range(5.5, 8.0)
	_trap_step(dt)
	if freeze_t > 0.0:
		freeze_t -= dt
	if shake > 0.0 and shake_on:
		cam.offset = Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake))
	else:
		cam.offset = Vector2.ZERO

	if hp <= 0.0:
		_game_over()
	_update_hud()

# ================================================================
#  DIFFICULTY / SPAWNING  (توازن: تصعيد بالمرحلة + داخل الدقيقة)
func _hp_mul() -> float:
	# روج-لايك: الأعداء يقووا بالمرحلة + داخل الدقيقة + مع كل Level Up للاعب
	# (معامل المستوى خفيف عشان ترقياتك تحس بقوتها — power fantasy)
	var ramp := (STAGE_LEN - stage_timer) / STAGE_LEN
	var lvl_mul := 1.0 + 0.07 * float(level - 1)
	return (1.0 + 0.50 * (stage - 1)) * (1.0 + 0.15 * ramp) * lvl_mul

func _dmg_mul() -> float:
	return (1.0 + 0.07 * (stage - 1)) * (1.0 + 0.03 * float(level - 1))

func _elite_chance() -> float:
	# النخبة: 4% في الفصل 1، تتصاعد حتى الفصل الأخير (~68%)
	return clampf(0.04 + 0.16 * float(stage - 1), 0.0, 1.0)

func _spawn_step(dt: float) -> void:
	spawn_cd -= dt
	if spawn_cd <= 0.0:
		var batch := 1 + (stage - 1) / 3
		for i in batch:
			_spawn_enemy()
		var ramp := (STAGE_LEN - stage_timer) / STAGE_LEN
		spawn_cd = maxf(0.24, 0.80 - 0.07 * (stage - 1) - 0.28 * ramp)

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
	var th = THEMES[theme_idx()]
	var pal: Array = th["pal"]
	# النخبة: زعيم صغير — احتماله يتصاعد، مع سقف عدد متزامن عشان توازن
	var elite_count := 0
	for e0 in enemies:
		if String(e0["type"]) == "elite":
			elite_count += 1
	var elite_cap := 2 + stage / 2
	if rng.randf() < _elite_chance() and elite_count < elite_cap:
		var ehp := 145.0 * _hp_mul()
		var bcol: Color = th["boss_col"]
		var espd := 46.0 * (1.0 + 0.03 * (stage - 1))
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
		enemies.append({
			"pos": _edge_pos(), "col": bcol.darkened(0.10),
			"r": er2, "hp": ehp, "maxhp": ehp, "spd": espd,
			"type": "elite", "orbcd": 0.0, "atk": rng.randf_range(2.0, 3.2), "mod": emod,
		})
		spawn_cd += 0.45   # النخبة تقيلة — مهلة إضافية
		return
	var t := rng.randf()
	var elapsed := STAGE_LEN - stage_timer
	var type := "norm"
	if stage >= 3 and t > 0.82:
		type = "split"
	elif stage >= 2 and t > 0.66:
		type = "tank"
	elif t > 0.48 and elapsed > 12.0:
		type = "fast"
	var r := 14.0; var hpv := 20.0; var spd := rng.randf_range(55.0, 85.0)
	match type:
		"fast":  r = 9.0;  hpv = 12.0;  spd = rng.randf_range(115.0, 145.0)
		"tank":  r = 24.0; hpv = 75.0;  spd = 40.0
		"split": r = 17.0; hpv = 35.0;  spd = 62.0
	hpv *= _hp_mul()
	spd *= 1.0 + 0.03 * (stage - 1)
	enemies.append({
		"pos": _edge_pos(),
		"col": pal[rng.randi() % pal.size()],
		"r": r, "hp": hpv, "maxhp": hpv, "spd": spd,
		"type": type, "orbcd": 0.0,
	})

# ================================================================
#  BOSS  (كل دقيقة: يمسح الأعداء، يوقف المؤقت، نمط هجوم حسب الثيم)
func _spawn_boss() -> void:
	boss_alive = true
	stage_timer = 0.0
	# مسح كل الأعداء الحاليين
	for e in enemies:
		_burst(e["pos"], Color(1, 1, 1), 6)
	enemies.clear()
	ebullets.clear()
	hazards.clear()
	meteors.clear()
	wipe_t = 1.0
	sfx("sweep", 0.0, 1.0, 1.0)
	var ti := theme_idx()
	var th = THEMES[ti]
	var hpv := 650.0 * (1.0 + 0.75 * (stage - 1)) * (1.0 + 0.10 * float(level - 1))
	var kind := ti
	if kind == 0:
		hpv *= 1.35   # حارس المرج كان أضعفهم
	var bcol: Color = th["boss_col"]
	var bname: String = th["boss_name"]
	var br := 46.0
	# الفصل الأخير: الزعيم النهائي — ملك الرماد
	if stage == FINAL_STAGE:
		kind = 5
		bcol = Color(0.62, 0.35, 0.92)
		bname = "The Ash King"
		br = 58.0
		hpv *= 1.8
	enemies.append({
		"pos": _edge_pos(),
		"col": bcol,
		"r": br, "hp": hpv, "maxhp": hpv, "spd": 53.0 if kind != 3 else 72.0,
		"type": "boss", "orbcd": 0.0,
		"kind": kind, "atk": 1.5, "spiral": 0.0, "charge": 0.0,
		"phase": 1, "atk2": 4.0, "tcd": 0.0, "cyc": 0, "sumt": 3.0, "split_done": false,
	})
	boss_name_cur = bname
	sfx("boss", 2.0)
	shake = 8.0 if kind != 5 else 12.0
	_play_music("b%d" % ti)
	_flash_msg("!! %s !!" % bname, 2.2 if kind != 5 else 3.0)

func _boss_die(epos: Vector2) -> void:
	boss_alive = false
	ebullets.clear()
	hazards.clear()
	vacuum_t = 2.5
	for k in 14:
		_drop_gem(epos + Vector2(rng.randf_range(-55, 55), rng.randf_range(-55, 55)))
	hp = minf(maxhp, hp + 40.0)
	shake = 11.0
	sfx("bossdie", 3.0, 1.0, 1.0)
	_burst(epos, Color(1, 0.85, 0.3), 46)
	# المرحلة الجاية + ثيم جديد + موسيقاه
	stage += 1
	stage_timer = STAGE_LEN
	spawn_cd = 1.2
	# النصر: سقط ملك الرماد — نهاية الحملة
	if stage > FINAL_STAGE:
		hitstop = 0.0
		state = ST_VICTORY
		_update_records(true)
		var m := int(gametime) / 60
		var s := int(gametime) % 60
		vic_stats.text = "Campaign complete, %s!\n\nKills: %d      Level: %d      Run time: %02d:%02d\nBest combo: x%d\n\n[Enter] Back to Menu" % [CHARS[char_sel]["name"], kills, level, m, s, combo_best]
		vic_dim.visible = true
		_play_music("menu")
		return
	_play_music("s%d" % theme_idx())
	_gen_decor()
	var th = THEMES[theme_idx()]
	if stage == FINAL_STAGE:
		# الفراغ: بلا وقت — أسياد العوالم قادمون
		stage_timer = 999999.0
		void_intro = 4.5
		_flash_msg("The Void... something stirs in the dark", 3.0)
	else:
		_flash_msg("Stage %d - %s   (+40 HP)" % [stage, th["name"]], 2.4)

func _boss_step(e: Dictionary, dt: float) -> void:
	var kind: int = e["kind"]
	var bp: Vector2 = e["pos"]
	# طور الغضب عند نص الصحة: أسرع + هجوم ثانوي جديد (مش للملك — له أطواره)
	if kind != 5 and int(e["phase"]) == 1 and float(e["hp"]) < float(e["maxhp"]) * 0.5:
		e["phase"] = 2
		e["spd"] = float(e["spd"]) * 1.25
		e["atk2"] = 1.5
		shake = 7.0
		sfx("boss", 0.0)
		_burst(bp, e["col"], 26)
		_flash_msg("%s is enraged!" % boss_name_cur, 1.8)
	var enraged := int(e["phase"]) == 2
	e["atk"] = float(e["atk"]) - dt
	e["atk2"] = float(e["atk2"]) - dt
	e["sumt"] = float(e.get("sumt", 3.0)) - dt
	var to := pp - bp
	var d := to.length()
	var kfrac0 := float(e["hp"]) / float(e["maxhp"])
	# حارس المرج (والملك في طوره الأول): استدعاء درع دائري كل 5ث
	if (kind == 0 or (kind == 5 and (kfrac0 > 0.75 or bool(e.get("reborn", false))))) and float(e["sumt"]) <= 0.0:
		var guards := 0
		for g0 in enemies:
			if g0.get("orbit_host") == e:
				guards += 1
		if guards <= 3:
			var pal0: Array = THEMES[theme_idx()]["pal"]
			for k in 8:
				var ga := TAU * float(k) / 8.0
				var ghp := 22.0 * _hp_mul()
				enemies.append({
					"pos": bp + Vector2(cos(ga), sin(ga)) * 88.0,
					"col": pal0[k % pal0.size()], "r": 13.0, "hp": ghp, "maxhp": ghp,
					"spd": 80.0, "type": "norm", "orbcd": 0.0,
					"orbit_host": e, "orb_a": ga,
				})
			_burst(bp, e["col"], 12)
			sfx("boss", -8.0, 1.2, 1.3)
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
			_hurt(13.0 * _dmg_mul() * dt)
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
		sfx("bossdie", -4.0, 1.3, 1.3)
		_burst(bp, e["col"], 30)
		_flash_msg("Frost Heart shattered in two!", 1.8)
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
				var pal2: Array = THEMES[0]["pal"]
				for k in 3:
					var a0 := rng.randf() * TAU
					var mhp := 16.0 * _hp_mul()
					enemies.append({"pos": bp + Vector2(cos(a0), sin(a0)) * 70.0,
						"col": pal2[k % pal2.size()], "r": 12.0, "hp": mhp, "maxhp": mhp,
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

func _ebullet(pos: Vector2, vel: Vector2, col: Color, home := false) -> void:
	if ebullets.size() >= 130:
		return
	ebullets.append({"pos": pos, "vel": vel, "r": 7.0 if not home else 8.0, "col": col, "life": 7.0 if not home else 5.0, "home": home})

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
		var bp: Vector2 = b["pos"]
		var dead := float(b["life"]) <= 0.0 or bp.x < -60 or bp.x > WW + 60 or bp.y < -60 or bp.y > WH + 60
		var ebr := float(b["r"]) + PR - 3.0
		if invuln <= 0.0 and bp.distance_squared_to(pp) < ebr * ebr:
			_hurt(16.0 * _dmg_mul())
			flash = minf(1.0, flash + 0.5)
			invuln = maxf(invuln, 0.4)
			if hurt_snd_cd <= 0.0:
				sfx("hurt", -4.0)
				hurt_snd_cd = 0.3
			dead = true
		if dead:
			ebullets.remove_at(i)
		i -= 1

func _spawn_void_gauntlet() -> void:
	# الزعماء الأربعة يعودون للحياة — أقوى، وكلهم مرة واحدة
	boss_alive = true
	for e in enemies:
		_burst(e["pos"], Color(1, 1, 1), 6)
	enemies.clear()
	ebullets.clear()
	wipe_t = 1.0
	sfx("sweep", 0.0, 0.8, 0.8)
	sfx("boss", 2.0, 0.85, 0.9)
	for k in 4:
		var th2 = THEMES[k]
		var ga := TAU * float(k) / 4.0 + 0.4
		var hpv2 := 650.0 * (1.0 + 0.75 * 4.0) * (1.0 + 0.10 * float(level - 1)) * 0.55
		if k == 0:
			hpv2 *= 1.35
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
	_play_music("b4")
	_flash_msg("!! The Lords of the Realms have returned - defeat them all !!", 3.2)

# ================================================================
#  ENEMIES
func _enemy_step(dt: float) -> void:
	var i := enemies.size() - 1
	while i >= 0:
		var e = enemies[i]
		if String(e["type"]) == "boss":
			_boss_step(e, dt)
		else:
			var to: Vector2 = pp - e["pos"]
			var d := to.length()
			var slow_t: float = e.get("slow", 0.0)
			var slow_f := 0.6 if slow_t > 0.0 else 1.0
			if theme_idx() == 2:
				slow_f *= 0.80   # الثلج بيبطّئ الأعداء أكتر
			if slow_t > 0.0:
				e["slow"] = slow_t - dt
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
				e["pos"] += (to / d) * float(e["spd"]) * slow_f * dt
			# النخبة زعيم صغير: ترمي رشقة موجّهة كل فترة
			if String(e["type"]) == "elite":
				e["atk"] = float(e["atk"]) - dt
				# ترمي بس لو قريبة من الشاشة (مش من بعيد خالص)
				if float(e["atk"]) <= 0.0 and ebullets.size() < 70 and Vector2(e["pos"]).distance_to(pp) < 620.0:
					var dir := (pp - Vector2(e["pos"])).normalized()
					_ebullet(e["pos"], dir * 168.0, Color(1.0, 0.82, 0.25))
					e["atk"] = 3.1
		e["orbcd"] = maxf(0.0, float(e["orbcd"]) - dt)
		# ضرر تلامس
		var er: float = e["r"]
		var dd: float = (pp - Vector2(e["pos"])).length()
		if dd < er + PR and invuln <= 0.0:
			var dps := (16.0 + er * 0.55) * _dmg_mul()
			if String(e["type"]) == "boss":
				dps = 38.0 * _dmg_mul()
			elif String(e["type"]) == "elite":
				dps *= 0.75   # النخبة خطرها في الرمي مش التلامس
			_hurt(dps * dt)
			flash = minf(1.0, flash + dt * 3.0)
			if hurt_snd_cd <= 0.0:
				sfx("hurt", -4.0)
				hurt_snd_cd = 0.35
		i -= 1

func damage_enemy(idx: int, dmg: float, src: String = "bullet") -> void:
	var e = enemies[idx]
	var final := dmg
	var was_crit := false
	if crit > 0.0 and rng.randf() < crit:
		final *= 2.0
		was_crit = true
	if String(e.get("mod", "")) == "shield":
		final *= 0.55   # نخبة مدرّعة
	e["hp"] = float(e["hp"]) - final
	if steal_n > 0:
		hp = minf(maxhp, hp + final * 0.03 * float(steal_n))
	if slow_n > 0:
		e["slow"] = 0.8 + 0.2 * float(slow_n)
	var ep: Vector2 = e["pos"]
	var ncol := Color(1, 1, 1)
	if was_crit:
		ncol = Color(1, 0.85, 0.25)
	elif src == "orbit":
		ncol = Color(0.5, 0.95, 1.0)
	_dmgnum(ep + Vector2(rng.randf_range(-10, 10), -float(e["r"]) - 6.0), int(final), ncol, was_crit)
	if float(e["hp"]) <= 0.0:
		_kill_enemy(idx)
	else:
		sfx("hit", -9.0)
		if was_crit:
			_burst(ep, Color(1, 0.9, 0.3), 6)

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
		sfx("boss", 3.0, 0.8, 0.8)
		_burst(Vector2(e["pos"]), Color(1.0, 0.85, 0.3), 46)
		_flash_msg("The Ash King rises from his ashes!!", 2.8)
		return
	kills += 1
	combo += 1
	combo_t = 3.0
	if combo > combo_best:
		combo_best = combo
	var epos: Vector2 = e["pos"]
	var etype: String = e["type"]
	shake = minf(6.0, shake + 3.0)
	_burst(epos, Color(1.0, 0.55, 0.12), 10)
	if rings.size() < 26:
		rings.append({"pos": epos, "t": 0.0, "max": float(e["r"]) + 26.0, "col": Color(e["col"])})
	sfx("kill", -4.0)
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
		"elite":
			for k in 5:
				_drop_gem(epos + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30)))
			shake = 8.0
			_burst(epos, Color(1, 0.85, 0.2), 22)
			# صندوق مفاجآت (10% — نادر عشان ما يكسرش التوازن)
			if rng.randf() < 0.10:
				boxes.append({"pos": epos})
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
				hp = minf(maxhp, hp + 15.0)
				shake = 8.0
				if stage == FINAL_STAGE and not king_spawned:
					_flash_msg("A Lord has fallen - %d remain" % bosses_left, 1.6)
			elif stage == FINAL_STAGE and not king_spawned:
				# سقط الأسياد الأربعة — الملك بنفسه ينزل
				king_spawned = true
				hp = minf(maxhp, hp + 40.0)
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

func _fire_step(dt: float) -> void:
	fire_cd -= dt
	if fire_cd > 0.0:
		return
	var ni := _nearest_enemy()
	if ni < 0:
		return
	var dir: Vector2 = (enemies[ni]["pos"] - pp).normalized()
	var spread := deg_to_rad(11.0)
	var start := -spread * (multishot - 1) * 0.5
	for k in multishot:
		var v := dir.rotated(start + spread * k) * bullet_speed
		bullets.append({"pos": pp, "vel": v, "life": 1.1, "pierce": pierce, "bounce": ric_n})
	# حارس الظهر: طلقات للخلف
	for k in rear_n:
		var rv := (-dir).rotated(deg_to_rad(rng.randf_range(-8.0, 8.0))) * bullet_speed
		bullets.append({"pos": pp, "vel": rv, "life": 1.1, "pierce": pierce, "bounce": ric_n})
	sfx("shoot", -11.0, 0.9, 1.1)
	fire_cd = fire_rate

func _bullet_step(dt: float) -> void:
	var i := bullets.size() - 1
	while i >= 0:
		var b = bullets[i]
		b["pos"] += b["vel"] * dt
		b["life"] = float(b["life"]) - dt
		var dead := false
		var j := enemies.size() - 1
		while j >= 0:
			var e = enemies[j]
			var bp: Vector2 = b["pos"]
			var hitr := float(e["r"]) + 6.0 * bsize
			if bp.distance_squared_to(e["pos"]) < hitr * hitr:
				damage_enemy(j, bullet_dmg)
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
	return pp + Vector2(cos(a), sin(a)) * ORBIT_R

func _orbit_step(_dt: float) -> void:
	if orbit_n <= 0:
		return
	for k in orbit_n:
		var bp := _orbit_blade_pos(k)
		var j := enemies.size() - 1
		while j >= 0:
			var e = enemies[j]
			var orr := float(e["r"]) + (14.0 if evo_cyclone else 10.0)
			if float(e["orbcd"]) <= 0.0 and bp.distance_squared_to(e["pos"]) < orr * orr:
				e["orbcd"] = 0.35
				damage_enemy(j, ORBIT_DMG * (1.6 if evo_cyclone else 1.0), "orbit")
			j -= 1

func _do_chain() -> void:
	# صاعقة: تضرب أقرب عدو وتتسلسل لمن حوله
	var chainlist := []
	var cur := pp
	var hops := 2 + chain_n
	if evo_storm:
		hops += 3
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
	sfx("zap", -5.0)
	var dmg := 38.0 + 6.0 * float(chain_n - 1)
	if evo_storm:
		dmg *= 1.8
	for e in chainlist:
		if evo_storm:
			e["slow"] = 1.6   # العاصفة القطبية تجمّد كل ما تلمسه
		var idx := enemies.find(e)
		if idx >= 0:
			damage_enemy(idx, dmg, "zap")
	chain_t = maxf(1.2, 2.6 - 0.25 * float(chain_n - 1)) * (0.65 if evo_storm else 1.0)

func _explode(pos: Vector2, scale := 1.0) -> void:
	var radius := (62.0 + 16.0 * float(explode_n - 1)) * scale
	var dmg := bullet_dmg * (0.45 + 0.15 * float(explode_n - 1)) * scale
	_burst(pos, Color(1.0, 0.45, 0.10), int(14.0 * scale))
	sfx("explode", -6.0 - (4.0 if scale < 1.0 else 0.0))
	# قنابل عنقودية: كل انفجار رئيسي يولّد 3 انفجارات صغيرة
	if evo_cluster and scale >= 1.0:
		for k in 3:
			var a := rng.randf() * TAU
			_explode(pos + Vector2(cos(a), sin(a)) * rng.randf_range(50.0, 95.0), 0.5)
	var j := enemies.size() - 1
	while j >= 0:
		var e = enemies[j]
		if pos.distance_to(e["pos"]) < radius + float(e["r"]):
			e["hp"] = float(e["hp"]) - dmg
		j -= 1
	# جولة قتل لمن سقط بالانفجار (قد تتسلسل انفجارات)
	j = enemies.size() - 1
	while j >= 0:
		if j < enemies.size() and float(enemies[j]["hp"]) <= 0.0:
			_kill_enemy(j)
		j -= 1

func _hurt(raw: float) -> void:
	# كل ضرر يمر من هنا — الدروع تخففه
	hp -= raw * pow(0.9, float(armor_n))

# ================================================================
#  الأحداث العشوائية
func _fire_event() -> void:
	var ev := rng.randi() % 3
	match ev:
		0:  # مطر نيازك
			for i in 9:
				var off := Vector2(rng.randf_range(-480, 480), rng.randf_range(-300, 300))
				var mpos := pp + off
				mpos.x = clampf(mpos.x, 60, WW - 60)
				mpos.y = clampf(mpos.y, 60, WH - 60)
				meteors.append({"pos": mpos, "t": 1.0 + float(i) * 0.35})
			sfx("boss", -4.0)
			_flash_msg("Meteors incoming - run!", 2.0)
		1:  # كنز محروس
			var coff := Vector2(rng.randf_range(-420, 420), rng.randf_range(-280, 280))
			var cpos := pp + coff
			cpos.x = clampf(cpos.x, 80, WW - 80)
			cpos.y = clampf(cpos.y, 80, WH - 80)
			chest = {"pos": cpos}
			var th = THEMES[theme_idx()]
			for k in 2:
				var ghp := 100.0 * _hp_mul()
				enemies.append({
					"pos": cpos + Vector2(rng.randf_range(-50, 50), rng.randf_range(-50, 50)),
					"col": th["boss_col"].darkened(0.10),
					"r": 25.0, "hp": ghp, "maxhp": ghp, "spd": 44.0,
					"type": "elite", "orbcd": 0.0, "atk": 2.5, "mod": "", "guard": true,
				})
			_flash_msg("A guarded treasure appeared - check the radar!", 2.2)
		_:  # قطيع ذهبي
			for i in 10:
				enemies.append({
					"pos": _edge_pos(),
					"col": Color(1.0, 0.82, 0.25),
					"r": 10.0, "hp": 10.0 * _hp_mul() * 0.6, "maxhp": 10.0,
					"spd": rng.randf_range(140.0, 170.0),
					"type": "fast", "orbcd": 0.0, "gold": true,
				})
			sfx("gem", -4.0, 0.8, 0.8)
			_flash_msg("A golden horde passes - hunt it!", 2.0)

func _meteor_step(dt: float) -> void:
	var i := meteors.size() - 1
	while i >= 0:
		var mt = meteors[i]
		mt["t"] = float(mt["t"]) - dt
		if float(mt["t"]) <= 0.0:
			var mpos: Vector2 = mt["pos"]
			_burst(mpos, Color(1.0, 0.45, 0.10), 20)
			shake = minf(9.0, shake + 4.0)
			sfx("explode", -2.0)
			if invuln <= 0.0 and pp.distance_to(mpos) < 72.0 + PR:
				_hurt(26.0 * _dmg_mul())
				flash = minf(1.0, flash + 0.5)
			meteors.remove_at(i)
		i -= 1

func _box_step() -> void:
	# صناديق النخبة: لمسها = بركة عشوائية فورية (مفاجأة سارة)
	var i := boxes.size() - 1
	while i >= 0:
		var bx = boxes[i]
		if pp.distance_to(bx["pos"]) < PR + 16.0:
			var bl = UPS[rng.randi() % UPS.size()]
			_apply_upgrade(bl["id"])
			sfx("levelup", 0.0, 1.15, 1.15)
			_burst(Vector2(bx["pos"]), Color(1.0, 0.85, 0.3), 18)
			hitstop = maxf(hitstop, 0.10)
			_flash_msg("Chest! %s" % bl["name"], 1.6)
			boxes.remove_at(i)
		i -= 1

func _chest_step() -> void:
	if chest == null:
		return
	# الكنز يتفتح لما الحرّاس يموتوا وتلمسه
	var guards := 0
	for e in enemies:
		if bool(e.get("guard", false)):
			guards += 1
	var cpos: Vector2 = chest["pos"]
	if pp.distance_to(cpos) < PR + 22.0:
		if guards > 0:
			return
		for k in 8:
			_drop_gem(cpos + Vector2(rng.randf_range(-35, 35), rng.randf_range(-35, 35)))
		hp = minf(maxhp, hp + 25.0)
		sfx("levelup", 0.0, 1.1, 1.1)
		_burst(cpos, Color(1.0, 0.85, 0.3), 24)
		_flash_msg("Treasure! +25 HP and 8 gems", 1.8)
		chest = null

func _trap_step(dt: float) -> void:
	var i := traps.size() - 1
	while i >= 0:
		var tp = traps[i]
		var dead := false
		if String(tp["k"]) == "spike":
			if not bool(tp["sprung"]):
				tp["warn"] = float(tp["warn"]) - dt
				if float(tp["warn"]) <= 0.0:
					tp["sprung"] = true
					sfx("hit", -2.0, 0.7, 0.8)
					shake = minf(6.0, shake + 2.5)
					if invuln <= 0.0 and pp.distance_to(tp["pos"]) < 46.0:
						_hurt((24.0 if bool(tp.get("ice", false)) else 22.0) * _dmg_mul())
						invuln = maxf(invuln, 0.35)
						flash = minf(1.0, flash + 0.5)
			else:
				tp["act"] = float(tp["act"]) - dt
				if float(tp["act"]) <= 0.0:
					dead = true
		elif String(tp["k"]) == "freeze":
			tp["warn"] = float(tp["warn"]) - dt
			if float(tp["warn"]) <= 0.0:
				if pp.distance_to(tp["pos"]) < 80.0:
					freeze_t = 0.8
					_hurt(8.0 * _dmg_mul())
					flash = minf(1.0, flash + 0.4)
					_flash_msg("Frozen!", 0.7)
					sfx("hurt", -4.0, 1.3, 1.4)
				_burst(Vector2(tp["pos"]), Color(0.8, 0.95, 1.0), 14)
				dead = true
		else:  # burn
			if not bool(tp.get("perm", false)):
				tp["life"] = float(tp.get("life", 1.0)) - dt
				if float(tp["life"]) <= 0.0:
					dead = true
			if not dead and invuln <= 0.0 and pp.distance_to(tp["pos"]) < 36.0:
				_hurt(16.0 * _dmg_mul() * dt)
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
			_hurt(float(hz["dps"]) * dt)
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
		var ar2 := aura_r + float(e["r"])
		if pp.distance_squared_to(e["pos"]) < ar2 * ar2:
			e["hp"] = float(e["hp"]) - AURA_DPS * dt
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
			gems.remove_at(i)
			sfx("gem", -13.0, 0.95, 1.3)
			xp += gval
			if xp >= xp_need:
				xp -= xp_need
				_enter_levelup()
		i -= 1

func _check_evolutions() -> void:
	# شرطا الاندماج: بركتان معينتان بمستوى كافٍ
	if evo_pending != "":
		return
	if not evo_storm and int(ups_count.get("chain", 0)) >= 2 and int(ups_count.get("slow", 0)) >= 2:
		evo_pending = "estorm"
	elif not evo_cyclone and int(ups_count.get("orbit", 0)) >= 3 and int(ups_count.get("speed", 0)) >= 2:
		evo_pending = "ecyclone"
	elif not evo_cluster and int(ups_count.get("explode", 0)) >= 2 and int(ups_count.get("big", 0)) >= 2:
		evo_pending = "ecluster"

func _enter_levelup() -> void:
	level += 1
	xp_need = int(xp_need * 1.32) + 2
	maxhp += 5.0
	hp = minf(maxhp, hp + 15.0)
	sfx("levelup", 0.0, 1.0, 1.0)
	var pool := UPS.duplicate()
	pool.shuffle()
	lv_choices.clear()
	for i in 3:
		var card = lv_cards[i]
		# الكرت الأول يبقى تطوّراً ذهبياً لو فيه اندماج جاهز
		if i == 0 and evo_pending != "":
			var ev = EVOS[evo_pending]
			lv_choices.append(evo_pending)
			card["name"].text = "★ " + ev["name"]
			card["desc"].text = ev["desc"]
			card["panel"].color = Color(0.30, 0.24, 0.06, 0.97)
			card["name"].add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
			continue
		lv_choices.append(pool[i]["id"])
		card["name"].text = pool[i]["name"]
		card["desc"].text = pool[i]["desc"]
		card["panel"].color = Color(0.10, 0.12, 0.18, 0.95)
		card["name"].add_theme_color_override("font_color", Color(1, 1, 1))
	lv_title.text = "LEVEL UP %d - choose a blessing [1/2/3]" % level
	lv_dim.visible = true
	state = ST_LEVELUP

func _apply_upgrade(id: String) -> void:
	# تطوّرات (اندماج بركتين)
	match id:
		"estorm":
			evo_storm = true
			evo_pending = ""
			_flash_msg("EVOLVED: Polar Storm!", 2.2)
			sfx("levelup", 2.0, 0.8, 0.8)
			return
		"ecyclone":
			evo_cyclone = true
			orbit_n *= 2
			evo_pending = ""
			_flash_msg("EVOLVED: Blade Cyclone!", 2.2)
			sfx("levelup", 2.0, 0.8, 0.8)
			return
		"ecluster":
			evo_cluster = true
			evo_pending = ""
			_flash_msg("EVOLVED: Cluster Bombs!", 2.2)
			sfx("levelup", 2.0, 0.8, 0.8)
			return
	ups_count[id] = int(ups_count.get(id, 0)) + 1
	_check_evolutions()
	match id:
		"dmg":    bullet_dmg += 8.0
		"rate":   fire_rate = maxf(0.10, fire_rate * 0.85)
		"multi":  multishot += 1
		"pierce": pierce += 1
		"orbit":  orbit_n += 1
		"aura":   aura_r = 70.0 if aura_r <= 0.0 else aura_r + 26.0
		"crit":   crit = minf(0.8, crit + 0.10)
		"speed":  pspeed *= 1.12
		"hp":     maxhp += 25.0; hp = minf(maxhp, hp + 40.0)
		"magnet": magnet *= 1.6
		"dash":   dash_cd_max = maxf(0.6, dash_cd_max * 0.75)
		"chain":  chain_n += 1
		"explode": explode_n += 1
		"ric":    ric_n += 1
		"rear":   rear_n += 1
		"regen":  regen_n += 1
		"armor":  armor_n = mini(5, armor_n + 1)
		"steal":  steal_n = mini(5, steal_n + 1)
		"slow":   slow_n += 1
		"big":    bsize = minf(2.2, bsize * 1.25)

# ================================================================
#  FEEL
func _flash_msg(t: String, dur: float = 1.1) -> void:
	lbl_msg.text = t
	lbl_msg.visible = true
	_msg_t = dur

func _dmgnum(pos: Vector2, n: int, col: Color, big: bool = false) -> void:
	dmgnums.append({"pos": pos, "life": 0.7, "txt": str(n), "col": col, "big": big})
	if dmgnums.size() > 24:
		dmgnums.remove_at(0)

func _part_step(dt: float) -> void:
	if _msg_t > 0.0:
		_msg_t -= dt
		if _msg_t <= 0.0:
			lbl_msg.visible = false
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

func _game_over() -> void:
	state = ST_OVER
	hitstop = 0.0
	sfx("death", 2.0, 1.0, 1.0)
	music_pl.stop()
	var was_rec_k := rec_kills
	var was_rec_t := rec_time
	_update_records(false)
	var m := int(gametime) / 60
	var s := int(gametime) % 60
	var rec_txt := ""
	if kills > was_rec_k or gametime > was_rec_t:
		rec_txt = "\nNEW RECORD!"
	go_stats.text = "Kills: %d      Level: %d      Stage: %d      Survived: %02d:%02d\nBest combo: x%d%s\n\n[R] New Run      [M] Menu" % [kills, level, stage, m, s, combo_best, rec_txt]
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
	# البركان: بقع حارقة ثابتة موزعة على الفصل (بعيدة عن نقطة البداية)
	if ti == 3:
		for i in 20:
			var bp2 := _rpos()
			if bp2.distance_to(WC) < 240.0:
				bp2 = WC + (bp2 - WC).normalized() * 320.0
			traps.append({"k": "burn", "pos": bp2, "perm": true})
	match ti:
		0:  # المرج: شجيرات بكسلية + زهور + يراعات مضيئة
			for i in 18:
				decor.append({"k": "bush", "pos": _rpos(), "s": rng.randf_range(12.0, 22.0)})
			for i in 34:
				var fc: Color = [Color(1, 1, 1), Color(1.0, 0.85, 0.35), Color(0.95, 0.55, 0.75)][rng.randi() % 3]
				decor.append({"k": "flower", "pos": _rpos(), "s": rng.randf_range(3.0, 5.0), "col": fc})
			for i in 26:
				decor.append({"k": "fly", "pos": _rpos(), "ph": rng.randf() * TAU})
		1:  # الصحراء: رمل وعظام فقط (المستخدم حددها)
			for i in 26:
				decor.append({"k": "bone", "pos": _rpos(), "s": rng.randf_range(7.0, 15.0), "rot": rng.randf() * TAU})
		2:  # الجليد: شقوق متوهجة نابضة (زي الحمم بس سماوية) + بريق
			for i in 26:
				decor.append({"k": "icecrack", "pts": _crack_pts(_rpos(), 5)})
			for i in 36:
				decor.append({"k": "spark", "pos": _rpos(), "s": rng.randf_range(2.5, 4.5)})
		3:  # البركان: شقوق الحمم المتوهجة + جمرات + صخور سوداء
			for i in 28:
				decor.append({"k": "lava", "pts": _crack_pts(_rpos(), 6)})
			for i in 50:
				decor.append({"k": "ember", "pos": _rpos(), "s": rng.randf_range(2.0, 4.5), "ph": rng.randf() * TAU})
			for i in 16:
				decor.append({"k": "drock", "pos": _rpos(), "s": rng.randf_range(10.0, 20.0)})
		_:  # الفراغ: سدُم + نجوم وامضة كبيرة (الصغيرة جوّه البلاط)
			for i in 7:
				var nc: Color = [Color(0.45, 0.25, 0.70), Color(0.25, 0.30, 0.65), Color(0.60, 0.20, 0.55)][rng.randi() % 3]
				decor.append({"k": "nebula", "pos": _rpos(), "s": rng.randf_range(130.0, 280.0), "col": nc})
			for i in 16:
				decor.append({"k": "bigstar", "pos": _rpos(), "s": rng.randf_range(4.0, 7.0), "ph": rng.randf() * TAU})

func _gen_tiles() -> void:
	# 3 بلاطات 16×16 لكل ثيم: واحدة شبه سادة واثنتان مزخرفتان (درس البكسل آرت: ألوان قليلة)
	tile_tex.clear()
	var ti := theme_idx()
	for v in 3:
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		for y in 16:
			for x in 16:
				img.set_pixel(x, y, _tile_pixel(ti, v))
		# البركان: تشققات متساوية (خط رأسي/أفقي ثابت المكان → شبكة منتظمة عبر البلاطات)
		if ti == 3 and v == 1:
			_tile_line(img, true)
		elif ti == 3 and v == 2:
			_tile_line(img, false)
		elif ti == 2 and v == 2:
			_tile_vein(img, ti)
		tile_tex.append(ImageTexture.create_from_image(img))

func _tile_line(img: Image, horizontal: bool) -> void:
	# شق حمم مستقيم في منتصف البلاطة — البلاطات المتجاورة تكمل بعضها
	for i in 16:
		var px := i if horizontal else 8
		var py := 8 if horizontal else i
		img.set_pixel(px, py, Color8(255, 122, 32))
		if i % 3 == 0:
			img.set_pixel(clampi(px + (0 if horizontal else 1), 0, 15), clampi(py + (1 if horizontal else 0), 0, 15), Color8(200, 82, 22))

func _tile_pixel(ti: int, v: int) -> Color:
	# البلاطة 0 شبه سادة، 1-2 أكثف زخرفة
	var density := 0.06 if v == 0 else 0.22
	var r := rng.randf()
	match ti:
		0:  # مرج
			var c := Color8(64, 118, 52)
			if r < density: c = Color8(52, 100, 44)
			elif r < density * 2.0: c = Color8(78, 136, 62)
			if v > 0 and rng.randf() < 0.010: c = Color8(214, 204, 130)
			return c
		1:  # صحراء
			var c := Color8(202, 172, 116)
			if r < density: c = Color8(188, 158, 104)
			elif r < density * 1.8: c = Color8(214, 186, 130)
			if v > 0 and rng.randf() < 0.008: c = Color8(150, 122, 82)
			return c
		2:  # جليد — أبيض ثلجي
			var c := Color8(214, 228, 238)
			if r < density: c = Color8(198, 214, 228)
			elif r < density * 2.0: c = Color8(232, 242, 250)
			if v > 0 and rng.randf() < 0.015: c = Color8(255, 255, 255)
			return c
		3:  # بركان — أحمر غامق كصخور البركان
			var c := Color8(66, 26, 22)
			if r < density: c = Color8(52, 20, 18)
			elif r < density * 1.7: c = Color8(82, 34, 27)
			if v > 0 and rng.randf() < 0.007: c = Color8(255, 122, 32)
			return c
		_:  # فراغ — أسود بنجوم بنفسجية
			var c := Color8(8, 6, 12)
			if r < density: c = Color8(5, 4, 9)
			if v > 0 and rng.randf() < 0.016:
				var b := rng.randf_range(0.5, 1.0)
				c = Color(b * 0.75, b * 0.35, b)
			return c
	return Color.BLACK

func _tile_vein(img: Image, ti: int) -> void:
	# عرق متوهج داخل البلاطة (حمم برتقالية / جليد ساطع)
	var x := rng.randi_range(3, 12)
	var main_c := Color8(255, 122, 32) if ti == 3 else Color8(235, 250, 255)
	var side_c := Color8(200, 82, 22) if ti == 3 else Color8(205, 232, 245)
	for y in 16:
		img.set_pixel(x, y, main_c)
		if rng.randf() < 0.5:
			img.set_pixel(clampi(x + (1 if rng.randf() < 0.5 else -1), 0, 15), y, side_c)
		x = clampi(x + rng.randi_range(-1, 1), 1, 14)

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
	SPR["norm"] = _shape_tex(16, func(p: Vector2) -> bool:
		return p.length() < 6.2)
	SPR["fast"] = _shape_tex(16, func(p: Vector2) -> bool:
		return p.x > -6.0 and p.x < 7.0 and absf(p.y) < (7.0 - p.x) * 0.55)
	SPR["tank"] = _shape_tex(16, func(p: Vector2) -> bool:
		return absf(p.x) < 6.2 and absf(p.y) < 6.2)
	SPR["split"] = _shape_tex(16, func(p: Vector2) -> bool:
		return (p + Vector2(3.2, 0)).length() < 4.5 or (p - Vector2(3.2, 0)).length() < 4.5)
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
	lbl_kills.text = "KILLS: %d" % kills
	lbl_level.text = "LEVEL %d" % level
	var m := int(gametime) / 60
	var s := int(gametime) % 60
	lbl_time.text = "%02d:%02d" % [m, s]
	lbl_stage.text = "Stage %d/%d - %s" % [mini(stage, FINAL_STAGE), FINAL_STAGE, THEMES[theme_idx()]["name"]]
	if stage == FINAL_STAGE:
		if king_spawned:
			lbl_boss.text = "!! THE ASH KING - THE END !!"
		elif boss_alive:
			var gleft := 0
			for e4 in enemies:
				if String(e4["type"]) == "boss":
					gleft += 1
			lbl_boss.text = "Lords of the Realms - %d left" % gleft
		else:
			lbl_boss.text = "Something approaches from the dark..."
	elif boss_alive:
		lbl_boss.text = "!! %s - TIME FROZEN !!" % boss_name_cur
	else:
		lbl_boss.text = "Boss in %ds" % int(ceil(stage_timer))
	if combo >= 5:
		lbl_combo.visible = true
		lbl_combo.text = "x%d COMBO" % combo
		lbl_combo.add_theme_color_override("font_color",
			Color(1, 0.85, 0.35) if combo < 25 else (Color(1, 0.55, 0.15) if combo < 60 else Color(1, 0.25, 0.25)))
	else:
		lbl_combo.visible = false
	var f: float = clampf(hp / maxhp, 0.0, 1.0)
	hp_fill.size.x = 234.0 * f
	hp_fill.color = Color(0.30, 0.85, 0.30).lerp(Color(0.90, 0.20, 0.20), 1.0 - f)
	xp_fill.size.x = 254.0 * clampf(float(xp) / float(xp_need), 0.0, 1.0)
	var df: float = 1.0 - clampf(dash_cd / dash_cd_max, 0.0, 1.0)
	dash_fill.size.x = 116.0 * df
	dash_fill.color = Color(0.35, 0.75, 1.0) if df >= 1.0 else Color(0.4, 0.45, 0.55)

# ================================================================
#  DRAW
func _draw() -> void:
	var th = THEMES[theme_idx()]
	var bg: Color = th["bg"]
	var dcol: Color = th["decor"]
	var cl := cam.position + cam.offset - Vector2(W * 0.5, H * 0.5)
	# القائمة والإعدادات: خلفية مصممة — مش بقايا الجولة
	if state == ST_MENU or state == ST_SETTINGS:
		_draw_menu_bg(cl)
		if state == ST_MENU:
			for i in CHARS.size():
				var hx := cl + Vector2(W * 0.5 - 165.0 + 110.0 * i, 385.0)
				var sel := i == char_sel
				var hs := 26.0 if sel else 17.0
				if sel:
					hx.y -= 4.0 + sin(animt * 3.0) * 3.0
					draw_arc(hx, hs + 14.0, 0, TAU, 32, Color(1.0, 0.85, 0.35, 0.9), 3.0)
				_shadow(hx, hs + 3.0)
				_draw_hero(hx, i, hs, 1.0 if sel else 0.55)
		return
	# حد خارجي غامق ثم بلاط البكسل آرت (المنطقة الظاهرة فقط)
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
	# ديكور متوهج فوق البلاط
	var camc := cam.position
	for dc in decor:
		var dk: String = dc["k"]
		if dk == "icecrack" or dk == "lava":
			var pts0: PackedVector2Array = dc["pts"]
			if pts0[0].distance_squared_to(camc) > 1690000.0:
				continue
			if dk == "lava":
				draw_polyline(pts0, Color(0.20, 0.06, 0.04), 6.0)
				draw_polyline(pts0, Color(1.0, 0.45, 0.08, 0.75 + 0.25 * sin(animt * 3.0 + pts0[0].x * 0.01)), 2.6)
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
				draw_rect(Rect2(dp.x - ds * 0.5, dp.y - ds * 0.5, ds, ds), Color(1.0, 0.5, 0.1, ea))
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

	# gems — ماسات سماوية لامعة بخط تحديد (باينة على أي أرضية)
	for g in gems:
		var gp: Vector2 = g["pos"]
		var gs := 5.5 + sin(animt * 6.0 + gp.x * 0.1) * 1.4 + minf(3.0, float(g.get("val", 1)) - 1.0)
		draw_set_transform(gp, PI * 0.25, Vector2.ONE)
		draw_rect(Rect2(-gs - 2, -gs - 2, (gs + 2) * 2, (gs + 2) * 2), Color(0.03, 0.05, 0.08))
		draw_rect(Rect2(-gs, -gs, gs * 2, gs * 2), Color(0.25, 0.95, 0.75))
		draw_rect(Rect2(-gs * 0.45, -gs * 0.45, gs * 0.9, gs * 0.9), Color(0.85, 1.0, 0.95))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# enemies — شكل مختلف لكل نوع (قراءة فورية للخطر)
	for e in enemies:
		var ep: Vector2 = e["pos"]
		var er: float = e["r"]
		var etype: String = e["type"]
		_shadow(ep, er)
		if etype == "boss":
			_draw_boss(e)
			continue
		var ecol: Color = e["col"]
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
			_:
				draw_texture_rect(SPR["norm"], Rect2(ep.x - sz2 * 0.5, ep.y - sz2 * 0.5, sz2, sz2), false, ecol)

	# enemy bullets
	for b in ebullets:
		var bp2: Vector2 = b["pos"]
		draw_circle(bp2, float(b["r"]) + 2.0, Color(0, 0, 0, 0.4))
		draw_circle(bp2, float(b["r"]), b["col"])
		draw_circle(bp2, float(b["r"]) * 0.45, Color(1, 1, 1, 0.85))

	# orbit blades
	for k in orbit_n:
		var obp := _orbit_blade_pos(k)
		draw_set_transform(obp, orbit_ang * 2.0, Vector2.ONE)
		draw_rect(Rect2(-9, -9, 18, 18), Color(0.3, 0.9, 0.95))
		draw_rect(Rect2(-5, -5, 10, 10), Color(0.7, 1.0, 1.0))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# player bullets
	for b in bullets:
		var ang: float = b["vel"].angle()
		draw_set_transform(b["pos"], ang, Vector2.ONE * bsize)
		draw_rect(Rect2(-8, -8, 16, 16), Color(0.55, 0.08, 0.08))
		draw_rect(Rect2(-6, -6, 12, 12), Color(0.95, 0.20, 0.15))
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

	# صناديق النخبة (بركة فورية)
	for bx in boxes:
		var bxp: Vector2 = bx["pos"]
		var bb := sin(animt * 4.0 + bxp.x * 0.05) * 2.5
		_shadow(bxp + Vector2(0, bb), 12.0)
		draw_rect(Rect2(bxp.x - 11, bxp.y - 9 + bb, 22, 18), Color(0.30, 0.18, 0.06))
		draw_rect(Rect2(bxp.x - 11, bxp.y - 9 + bb, 22, 7), Color(1.0, 0.85, 0.30))
		draw_circle(bxp + Vector2(0, bb), 3.0, Color(1, 1, 0.7, 0.6 + 0.4 * sin(animt * 6.0)))

	# الكنز المحروس
	if chest != null:
		var cpos: Vector2 = chest["pos"]
		var bob := sin(animt * 3.0) * 3.0
		draw_rect(Rect2(cpos.x - 16, cpos.y - 12 + bob, 32, 24), Color(0.35, 0.22, 0.08))
		draw_rect(Rect2(cpos.x - 16, cpos.y - 12 + bob, 32, 9), Color(0.95, 0.78, 0.25))
		draw_rect(Rect2(cpos.x - 3, cpos.y - 4 + bob, 6, 8), Color(1.0, 0.9, 0.4))

	# player (يومض أثناء الحصانة) — شكل الناجي المختار بشعاره
	if state != ST_MENU and state != ST_SETTINGS:
		var pa := 1.0
		if invuln > 0.0 and fmod(animt, 0.16) < 0.08:
			pa = 0.35
		_shadow(pp, PR + 3.0)
		_draw_hero(pp, char_sel, PR, pa)

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
	if wipe_t > 0.0:
		draw_rect(Rect2(cl.x, cl.y, W, H), Color(1, 1, 1, wipe_t * 0.35))
	if flash > 0.0:
		draw_rect(Rect2(cl.x, cl.y, W, H), Color(0.9, 0.1, 0.1, flash * 0.28))

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
		if armor_n > 0: rows.append(["armor", "%d%%" % int((1.0 - pow(0.9, float(armor_n))) * 100.0)])
		if regen_n > 0: rows.append(["regen", "%.1f" % (float(regen_n) * 1.4)])
		if steal_n > 0: rows.append(["steal", "%d%%" % int(float(steal_n) * 3.0)])
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
		if chest != null:
			var chp: Vector2 = chest["pos"]
			draw_rect(Rect2(mp.x + chp.x * sc - 3, mp.y + chp.y * sc - 3, 6, 6), Color(1.0, 0.85, 0.2))
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

func _draw_hero(pos: Vector2, idx: int, s: float, alpha: float) -> void:
	# سبرايت بكسل للناجي + شعاره المميز
	var hc: Color = CHARS[idx]["col"]
	var hsz := s * 2.4
	draw_texture_rect(SPR["hero"], Rect2(pos.x - hsz * 0.5, pos.y - hsz * 0.5, hsz, hsz), false, Color(hc.r, hc.g, hc.b, alpha))
	match idx:
		1:  # المحترق: ألسنة لهب فوق الرأس
			for k in 3:
				var fx := pos.x - s * 0.55 + s * 0.55 * k
				var fh := s * (0.55 + 0.25 * sin(animt * 7.0 + k * 2.0))
				draw_colored_polygon(PackedVector2Array([
					Vector2(fx - s * 0.18, pos.y - s), Vector2(fx + s * 0.18, pos.y - s),
					Vector2(fx, pos.y - s - fh)]), Color(1.0, 0.55, 0.15, alpha))
		2:  # العدّاء: سهمان سرعة على الجنب
			for k in 2:
				var cx := pos.x - s * 0.15 - k * s * 0.5
				draw_colored_polygon(PackedVector2Array([
					Vector2(cx, pos.y - s * 0.35), Vector2(cx + s * 0.35, pos.y),
					Vector2(cx, pos.y + s * 0.35)]), Color(1, 1, 1, alpha * 0.9))
		3:  # المدمّر: شفرة صغيرة بتلف حواليه
			var ba := animt * 4.0
			var bpos := pos + Vector2(cos(ba), sin(ba)) * (s + 8.0)
			draw_set_transform(bpos, ba * 2.0, Vector2.ONE)
			draw_rect(Rect2(-s * 0.28, -s * 0.28, s * 0.56, s * 0.56), Color(0.3, 0.9, 0.95, alpha))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _poly(c: Vector2, r: float, n: int, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := rot + TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

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
	draw_texture_rect(SPR["boss%d" % mini(kind, 5)], Rect2(ep.x - sz * 0.5, ep.y - sz * 0.5, sz, sz), false, tint)

# ================================================================
#  SCREENSHOT SIMULATION
func _simulate_for_shot() -> void:
	_hud_visible(true)
	menu_dim.visible = false
	if SHOTSCENE == "menu":
		state = ST_MENU
		_hud_visible(false)
		rec_stage = 4; rec_kills = 1240; rec_time = 543.0; rec_wins = 2
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
	# مشهد لعب مزدحم
	pp = WC
	cam.position = WC
	stage = 2 if SHOTSCENE == "play" else 3
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
		var pal: Array = THEMES[theme_idx()]["pal"]
		var bcol: Color = THEMES[theme_idx()]["boss_col"]
		for i in 40:
			var a := (TAU / 40.0) * i
			var rad := rng.randf_range(180.0, 330.0)
			var types := ["norm", "norm", "fast", "tank", "split"]
			var tt: String = types[i % types.size()]
			var r := 14.0
			match tt:
				"fast": r = 9.0
				"tank": r = 24.0
				"split": r = 17.0
			enemies.append({"pos": WC + Vector2(cos(a), sin(a)) * rad,
				"col": pal[i % pal.size()], "r": r, "hp": 30.0, "maxhp": 30.0,
				"spd": 60.0, "type": tt, "orbcd": 0.0})
		# نخبة (زعماء صغار) وسط العاديين
		for i in 4:
			var a2 := (TAU / 4.0) * i + 0.5
			enemies.append({"pos": WC + Vector2(cos(a2), sin(a2)) * 280.0,
				"col": bcol.darkened(0.10), "r": 27.0, "hp": 120.0, "maxhp": 190.0,
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
	_update_hud()
	queue_redraw()
