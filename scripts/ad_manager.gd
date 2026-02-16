# AdMob 광고 매니저 (Poing Studios v4.x API)
extends Node

# 실제 광고 ID
const BANNER_ID = "ca-app-pub-7230084799824817/2820646865"
const INTERSTITIAL_ID = "ca-app-pub-7230084799824817/4252206085"

# 테스트 광고 ID (개발 중 사용)
const TEST_BANNER_ID = "ca-app-pub-3940256099942544/6300978111"
const TEST_INTERSTITIAL_ID = "ca-app-pub-3940256099942544/1033173712"

# true면 테스트 광고, false면 실제 광고
var is_test: bool = false

var _interstitial_ad: InterstitialAd = null
var _ad_view: AdView = null
var _game_over_count: int = 0  # 3번째 게임오버마다 전면 광고
var _interstitial_load_callback: InterstitialAdLoadCallback

func _ready():
	print("[AdMob] OS: ", OS.get_name())
	
	# Android/iOS가 아니면 스킵
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		print("[AdMob] Not on mobile platform, skipping init")
		return
	
	print("[AdMob] Initializing on ", OS.get_name())
	
	_interstitial_load_callback = InterstitialAdLoadCallback.new()
	_interstitial_load_callback.on_ad_loaded = _on_interstitial_loaded
	_interstitial_load_callback.on_ad_failed_to_load = _on_interstitial_failed
	
	# AdMob 초기화
	MobileAds.initialize()
	
	# 배너 로드 (하단)
	_load_banner()
	
	# 전면 광고 미리 로드
	_load_interstitial()

func _load_banner():
	var unit_id = TEST_BANNER_ID if is_test else BANNER_ID
	_ad_view = AdView.new(unit_id, AdSize.BANNER, AdPosition.Values.BOTTOM)
	_ad_view.load_ad(AdRequest.new())
	print("[AdMob] Banner loading: ", unit_id)

func _load_interstitial():
	var unit_id = TEST_INTERSTITIAL_ID if is_test else INTERSTITIAL_ID
	InterstitialAdLoader.new().load(unit_id, AdRequest.new(), _interstitial_load_callback)
	print("[AdMob] Interstitial loading: ", unit_id)

func _on_interstitial_loaded(ad: InterstitialAd):
	_interstitial_ad = ad
	print("[AdMob] Interstitial loaded successfully")

func _on_interstitial_failed(error: LoadAdError):
	_interstitial_ad = null
	print("[AdMob] Interstitial failed to load: ", error.message)

func show_banner():
	if _ad_view:
		_ad_view.show()

func hide_banner():
	if _ad_view:
		_ad_view.hide()

func show_interstitial_on_game_over():
	_game_over_count += 1
	# 3판마다 전면 광고
	if _game_over_count % 3 == 0 and _interstitial_ad:
		_interstitial_ad.show()
		_interstitial_ad = null
		# 다음 광고 미리 로드
		_load_interstitial()
