# 주식 등급 데이터 — 세련된 컬러 팔레트
extends Node

class_name StockData

# 등급별 정보: [이름, 크기, 메인색, 하이라이트색, 점수, 라벨]
## 점수 밸런스 설계
## 초반(0~3): 삼각수 기반, 빠른 진행감
## 중반(4~6): 가속 보상, 합체 동기부여
## 후반(7~9): 대폭 상향, 고등급 달성 보상 극대화
const LEVELS = [
	{"name": "씨드", "radius": 22, "color": Color(0.55, 0.82, 0.55), "highlight": Color(0.7, 0.95, 0.7), "score": 1, "label": "1만", "emoji": "🌱"},
	{"name": "엔젤", "radius": 30, "color": Color(0.45, 0.7, 0.92), "highlight": Color(0.65, 0.85, 1.0), "score": 3, "label": "10만", "emoji": "👼"},
	{"name": "시리즈A", "radius": 38, "color": Color(0.92, 0.72, 0.38), "highlight": Color(1.0, 0.85, 0.55), "score": 6, "label": "100만", "emoji": "📈"},
	{"name": "시리즈B", "radius": 46, "color": Color(0.9, 0.48, 0.48), "highlight": Color(1.0, 0.65, 0.65), "score": 10, "label": "1000만", "emoji": "🚀"},
	{"name": "유니콘", "radius": 55, "color": Color(0.75, 0.42, 0.82), "highlight": Color(0.9, 0.6, 0.95), "score": 18, "label": "1억", "emoji": "🦄"},
	{"name": "IPO", "radius": 65, "color": Color(0.95, 0.8, 0.2), "highlight": Color(1.0, 0.92, 0.5), "score": 28, "label": "10억", "emoji": "🔔"},
	{"name": "코스닥", "radius": 72, "color": Color(0.25, 0.78, 0.78), "highlight": Color(0.45, 0.92, 0.92), "score": 40, "label": "100억", "emoji": "📊"},
	{"name": "코스피", "radius": 80, "color": Color(0.22, 0.55, 0.95), "highlight": Color(0.45, 0.72, 1.0), "score": 55, "label": "1000억", "emoji": "🏢"},
	{"name": "대기업", "radius": 90, "color": Color(0.85, 0.28, 0.28), "highlight": Color(1.0, 0.45, 0.45), "score": 75, "label": "1조", "emoji": "🏭"},
	{"name": "삼성전자", "radius": 100, "color": Color(1.0, 0.82, 0.0), "highlight": Color(1.0, 0.92, 0.4), "score": 100, "label": "10조", "emoji": "👑"},
]

const MAX_DROP_LEVEL = 3

static func get_level(idx: int) -> Dictionary:
	if idx >= 0 and idx < LEVELS.size():
		return LEVELS[idx]
	return LEVELS[0]

static func get_max_level() -> int:
	return LEVELS.size() - 1
