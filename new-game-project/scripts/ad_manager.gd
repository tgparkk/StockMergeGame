# AdMob 광고 매니저 (Poing Studios v4.x API)
extends Node

# 광고 ID — ad_config.cfg에서 로드
var BANNER_ID: String = ""
var INTERSTITIAL_ID: String = ""
var REWARDED_ID: String = ""
var TEST_BANNER_ID: String = ""
var TEST_INTERSTITIAL_ID: String = ""
var TEST_REWARDED_ID: String = ""

# 전면 광고 표시 주기
var _interstitial_interval: int = 3

# 디버그 빌드면 자동으로 테스트 광고 사용
var is_test: bool = OS.is_debug_build()

var _interstitial_ad: InterstitialAd = null
var _rewarded_ad: RewardedAd = null
var _ad_view: AdView = null
var _game_over_count: int = 0  # N번째 게임오버마다 전면 광고
var _interstitial_load_callback: InterstitialAdLoadCallback
var _rewarded_load_callback: RewardedAdLoadCallback

signal rewarded_ad_earned

func _load_ad_config():
	var config = ConfigFile.new()
	var err = config.load("res://ad_config.cfg")
	if err != OK:
		push_warning("[AdMob] ad_config.cfg 로드 실패 (err=%d), 기본값 사용" % err)
		# 기본 폴백 값 (설정 파일이 없을 때)
		BANNER_ID = "ca-app-pub-7230084799824817/2820646865"
		INTERSTITIAL_ID = "ca-app-pub-7230084799824817/4252206085"
		REWARDED_ID = "ca-app-pub-7230084799824817/5683765305"
		TEST_BANNER_ID = "ca-app-pub-3940256099942544/6300978111"
		TEST_INTERSTITIAL_ID = "ca-app-pub-3940256099942544/1033173712"
		TEST_REWARDED_ID = "ca-app-pub-3940256099942544/5224354917"
		return

	BANNER_ID = config.get_value("ad_ids", "banner_id", "")
	INTERSTITIAL_ID = config.get_value("ad_ids", "interstitial_id", "")
	REWARDED_ID = config.get_value("ad_ids", "rewarded_id", "")
	TEST_BANNER_ID = config.get_value("ad_ids", "test_banner_id", "")
	TEST_INTERSTITIAL_ID = config.get_value("ad_ids", "test_interstitial_id", "")
	TEST_REWARDED_ID = config.get_value("ad_ids", "test_rewarded_id", "")
	_interstitial_interval = config.get_value("ad_settings", "interstitial_interval", 3)
	print("[AdMob] Config loaded from ad_config.cfg")

func _ready():
	_load_ad_config()
	print("[AdMob] OS: ", OS.get_name())

	# Android/iOS가 아니면 스킵
	if OS.get_name() != "Android" and OS.get_name() != "iOS":
		print("[AdMob] Not on mobile platform, skipping init")
		return

	print("[AdMob] Initializing on ", OS.get_name())

	_interstitial_load_callback = InterstitialAdLoadCallback.new()
	_interstitial_load_callback.on_ad_loaded = _on_interstitial_loaded
	_interstitial_load_callback.on_ad_failed_to_load = _on_interstitial_failed

	_rewarded_load_callback = RewardedAdLoadCallback.new()
	_rewarded_load_callback.on_ad_loaded = _on_rewarded_loaded
	_rewarded_load_callback.on_ad_failed_to_load = _on_rewarded_failed

	# UMP 동의 후 AdMob 초기화
	_request_consent()

func _request_consent():
	# GDPR/UMP 동의 플로우 (Poing v4.x API)
	var params = ConsentRequestParameters.new()
	params.tag_for_under_age_of_consent = false
	if is_test:
		var debug = ConsentDebugSettings.new()
		debug.debug_geography = DebugGeography.Values.EEA
		params.consent_debug_settings = debug

	UserMessagingPlatform.consent_information.update(params, _on_consent_info_updated, _on_consent_info_failed)

func _on_consent_info_updated():
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_on_consent_form_loaded, _on_consent_form_failed)
	else:
		_init_ads()

func _on_consent_form_loaded(consent_form: ConsentForm):
	consent_form.show(func(error):
		if error:
			print("[AdMob] Consent form dismissed with error: ", error.message)
		_init_ads()
	)

func _on_consent_info_failed(error):
	print("[AdMob] Consent info failed: ", error.message if error else "unknown")
	_init_ads()  # 실패해도 광고는 로드 (non-EEA)

func _on_consent_form_failed(error):
	print("[AdMob] Consent form failed: ", error.message if error else "unknown")
	_init_ads()

func _init_ads():
	MobileAds.initialize()
	_load_banner()
	_load_interstitial()
	_load_rewarded()

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

func _load_rewarded():
	var unit_id = TEST_REWARDED_ID if is_test else REWARDED_ID
	RewardedAdLoader.new().load(unit_id, AdRequest.new(), _rewarded_load_callback)
	print("[AdMob] Rewarded loading: ", unit_id)

func _on_rewarded_loaded(ad: RewardedAd):
	_rewarded_ad = ad
	print("[AdMob] Rewarded loaded successfully")

func _on_rewarded_failed(error: LoadAdError):
	_rewarded_ad = null
	print("[AdMob] Rewarded failed to load: ", error.message)

func is_rewarded_ready() -> bool:
	return _rewarded_ad != null

func show_rewarded(callback: Callable):
	if _rewarded_ad:
		var _on_reward = OnUserEarnedRewardListener.new()
		_on_reward.on_user_earned_reward = func(_reward):
			rewarded_ad_earned.emit()
			callback.call()
		_rewarded_ad.show(_on_reward)
		_rewarded_ad = null
		_load_rewarded()
	else:
		print("[AdMob] Rewarded ad not ready")

func show_interstitial_on_game_over():
	_game_over_count += 1
	# N판마다 전면 광고 (_interstitial_interval 설정)
	if _game_over_count % _interstitial_interval == 0 and _interstitial_ad:
		_interstitial_ad.show()
		_interstitial_ad = null
		# 다음 광고 미리 로드
		_load_interstitial()
