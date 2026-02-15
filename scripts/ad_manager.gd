# AdMob 광고 매니저
extends Node

# 실제 광고 ID
const BANNER_ID = "ca-app-pub-7230084799824817/2820646865"
const INTERSTITIAL_ID = "ca-app-pub-7230084799824817/4252206085"

# 테스트 광고 ID (개발 중 사용 — 실제 출시 시 위의 ID 사용)
const TEST_BANNER_ID = "ca-app-pub-3940256099942544/6300978111"
const TEST_INTERSTITIAL_ID = "ca-app-pub-3940256099942544/1033173712"

# true면 테스트 광고, false면 실제 광고
var is_test: bool = true

var _admob = null
var _interstitial_loaded: bool = false
var _game_over_count: int = 0  # 3번째 게임오버마다 전면 광고

func _ready():
	if Engine.has_singleton("AdMob"):
		_admob = Engine.get_singleton("AdMob")
		_initialize()

func _initialize():
	if _admob == null:
		return
	
	_admob.initialize()
	
	# 배너 로드
	var banner_id = TEST_BANNER_ID if is_test else BANNER_ID
	_admob.load_banner({
		"ad_unit_id": banner_id,
		"position": _admob.BOTTOM,
		"size": "BANNER"
	})
	
	# 전면 광고 로드
	_load_interstitial()

func _load_interstitial():
	if _admob == null:
		return
	var inter_id = TEST_INTERSTITIAL_ID if is_test else INTERSTITIAL_ID
	_admob.load_interstitial({"ad_unit_id": inter_id})
	_interstitial_loaded = true

func show_banner():
	if _admob:
		_admob.show_banner()

func hide_banner():
	if _admob:
		_admob.hide_banner()

func show_interstitial_on_game_over():
	_game_over_count += 1
	# 3판마다 전면 광고
	if _game_over_count % 3 == 0 and _interstitial_loaded and _admob:
		_admob.show_interstitial()
		_interstitial_loaded = false
		# 다음 광고 미리 로드
		_load_interstitial()
