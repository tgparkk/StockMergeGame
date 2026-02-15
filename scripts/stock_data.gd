# 주식 등급 데이터 — 세련된 컬러 팔레트
extends Node

class_name StockData

# 등급별 정보: [이름, 크기, 메인색, 하이라이트색, 점수, 라벨]
const LEVELS = [
	{"name": "씨드", "radius": 22, "color": Color(0.55, 0.82, 0.55), "highlight": Color(0.7, 0.95, 0.7), "score": 1, "label": "1만", "emoji": "🌱"},
	{"name": "엔젤", "radius": 30, "color": Color(0.45, 0.7, 0.92), "highlight": Color(0.65, 0.85, 1.0), "score": 3, "label": "10만", "emoji": "👼"},
	{"name": "시리즈A", "radius": 38, "color": Color(0.92, 0.72, 0.38), "highlight": Color(1.0, 0.85, 0.55), "score": 6, "label": "100만", "emoji": "📈"},
	{"name": "시리즈B", "radius": 46, "color": Color(0.9, 0.48, 0.48), "highlight": Color(1.0, 0.65, 0.65), "score": 10, "label": "1000만", "emoji": "🚀"},
	{"name": "유니콘", "radius": 55, "color": Color(0.75, 0.42, 0.82), "highlight": Color(0.9, 0.6, 0.95), "score": 15, "label": "1억", "emoji": "🦄"},
	{"name": "IPO", "radius": 65, "color": Color(0.95, 0.8, 0.2), "highlight": Color(1.0, 0.92, 0.5), "score": 21, "label": "10억", "emoji": "🔔"},
	{"name": "코스닥", "radius": 75, "color": Color(0.25, 0.78, 0.78), "highlight": Color(0.45, 0.92, 0.92), "score": 28, "label": "100억", "emoji": "📊"},
	{"name": "코스피", "radius": 85, "color": Color(0.22, 0.55, 0.95), "highlight": Color(0.45, 0.72, 1.0), "score": 36, "label": "1000억", "emoji": "🏢"},
	{"name": "대기업", "radius": 98, "color": Color(0.85, 0.28, 0.28), "highlight": Color(1.0, 0.45, 0.45), "score": 45, "label": "1조", "emoji": "🏭"},
	{"name": "삼성전자", "radius": 112, "color": Color(1.0, 0.82, 0.0), "highlight": Color(1.0, 0.92, 0.4), "score": 55, "label": "10조", "emoji": "👑"},
]

const MAX_DROP_LEVEL = 3

static func get_level(idx: int) -> Dictionary:
	if idx >= 0 and idx < LEVELS.size():
		return LEVELS[idx]
	return LEVELS[0]

static func get_max_level() -> int:
	return LEVELS.size() - 1
