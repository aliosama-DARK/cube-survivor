extends Node
# ============================================================
#  AudioManager (autoload اسمه Audio)
#  مسؤول عن كل الصوت: مجمّع مؤثرات (12 صوت) + مشغّل موسيقى واحد
#  + مستوى الصوت. اتنقل حرفياً من Main.gd من غير أي تغيير مسموع.
#  الفوليوم مصدره Main (شاشة الإعدادات) ويُدفع هنا عبر set_*_volume.
# ============================================================

var _pool: Array = []           # مجمّع AudioStreamPlayer للمؤثرات
var _idx := 0
var _snd := {}                  # اسم -> AudioStream للمؤثرات
var _mus := {}                  # مفتاح -> AudioStream للموسيقى
var _music: AudioStreamPlayer
var _sfx_vol := 8               # 0..10 (نسخة من Main، تتحدّث عبر setter)
var _mus_vol := 8
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	for nm in ["shoot", "hit", "kill", "gem", "levelup", "hurt", "boss", "death",
			"dash", "click", "bossdie", "sweep", "zap", "explode"]:
		var st = load("res://assets/%s.wav" % nm)
		if st != null:
			_snd[nm] = st
	for i in 12:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		_pool.append(pl)
	_music = AudioStreamPlayer.new()
	_music.finished.connect(func(): _music.play())
	add_child(_music)
	# موسيقى لكل مرحلة وزعيم + القائمة
	var menu_m = load("res://assets/music.wav")
	if menu_m != null:
		_mus["menu"] = menu_m
	for i in 5:
		var sm = load("res://assets/mus_stage%d.wav" % i)
		if sm != null:
			_mus["s%d" % i] = sm
		var bm = load("res://assets/mus_boss%d.wav" % i)
		if bm != null:
			_mus["b%d" % i] = bm

# ---- مستوى الصوت (يُستدعى من Main عند التحميل وعند التعديل) ----
func set_sfx_volume(v: int) -> void:
	_sfx_vol = clampi(v, 0, 10)

func set_music_volume(v: int) -> void:
	_mus_vol = clampi(v, 0, 10)
	_apply_music_vol()
	# لو الموسيقى كانت متوقفة (بدأت مكتومة) نشغّلها لما نرفع الصوت
	if _mus_vol > 0 and _music.stream != null and not _music.playing:
		_music.play()

# ---- مؤثرات ----
func play_sfx(nm: String, vol_db: float = 0.0, pitch_lo: float = 0.95, pitch_hi: float = 1.05) -> void:
	if _sfx_vol <= 0 or not _snd.has(nm):
		return
	var pl: AudioStreamPlayer = _pool[_idx]
	_idx = (_idx + 1) % _pool.size()
	pl.stream = _snd[nm]
	pl.volume_db = vol_db + linear_to_db(float(_sfx_vol) / 10.0)
	pl.pitch_scale = _rng.randf_range(pitch_lo, pitch_hi)
	pl.play()

# ---- موسيقى ----
func _apply_music_vol() -> void:
	if _mus_vol <= 0:
		_music.volume_db = -80.0
	else:
		_music.volume_db = linear_to_db(float(_mus_vol) / 10.0) - 6.0

func play_music(key: String) -> void:
	if not _mus.has(key):
		return
	_apply_music_vol()
	if _music.stream == _mus[key] and _music.playing:
		return
	_music.stream = _mus[key]
	_music.play()

func stop_music() -> void:
	_music.stop()
