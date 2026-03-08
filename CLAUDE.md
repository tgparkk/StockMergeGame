# StockMergeGame (시총 키우기)

주식 테마 머지(합체) 게임. Godot 4.6 + GDScript, Android 타겟.

## 프로젝트 구조

```
new-game-project/
  scenes/main.tscn          # 메인 씬 (Node2D 기반)
  scripts/
    main.gd                  # 게임 루프, 상태머신, 게임 로직 코어
    game_draw.gd             # GameDraw 클래스 — 모든 드로잉 로직 (_draw 관련)
    game_ui.gd               # GameUI 클래스 — 모든 버튼/UI 생성 로직
    ball.gd                  # 공(RigidBody2D) — 머지 로직, 비주얼
    stock_data.gd            # 등급 데이터 (10단계, StockData 클래스)
    ad_manager.gd            # AdMob 광고 (배너/전면/리워드)
    merge_effect.gd          # 합체 이펙트 (파티클+링)
    next_preview.gd          # 다음 공 미리보기
    sfx.gd                   # 프로시저럴 효과음 (SFX 클래스)
  addons/admob/              # Poing Studios AdMob 플러그인 (외부)
  ConnectionStatePlugin/     # 네트워크 상태 플러그인
```

## 핵심 아키텍처

- **상태머신**: `main.gd`의 `State` enum — TITLE, PLAYING, PAUSED, GAME_OVER, RECORDS
- **물리**: 공은 RigidBody2D, 벽은 StaticBody2D (코드에서 동적 생성)
- **렌더링**: `_draw()` 기반 커스텀 드로잉 (씬 UI 최소화)
- **사운드**: `SFX` static 클래스, 프로시저럴 WAV 생성 + AudioStreamPlayer 풀링
- **광고**: Poing Studios godot-admob v4.x API, UMP 동의 플로우 포함

## 게임 규칙

- 자동 좌우 이동(펜듈럼) 공을 탭하여 드롭
- 같은 등급 공 충돌 시 합체 → 다음 등급
- 3초 미드롭 시 공이 커지는 패널티 → 자동 드롭
- 경고선 위 2초 유지 시 게임오버
- 콤보 시스템: 1.5초 내 연속 합체 시 점수 배수
- 리워드 광고 시청 시 1회 이어하기 가능
- 전면 광고: 3판마다 게임오버 시 표시

## 개발 참고

- **해상도**: 기본 540x960, stretch mode=canvas_items, aspect=expand
- **Safe Area**: Android/iOS 노치/펀치홀 대응 (`_update_safe_area()`)
- **통계**: `user://stats.dat`에 Dictionary 저장 (best_score, games_played, total_merges, max_level)
- **등급**: 10단계 (씨드→삼성전자), 드롭 가능 최대 레벨은 3 (시리즈B까지)
- **언어**: 한국어 UI

## 팀 운영 규약

3개 팀 + 관리자(lead)가 `.team/` 디렉토리를 통해 소통하며 능동적으로 작업합니다.

### 팀 구성

| 역할 | 담당 | 세션 시작 시 지시 |
|---|---|---|
| **lead** (관리자) | 작업 할당, 검토, 팀 간 조율, 의사결정 | "lead입니다" |
| **gameplay** | 게임플레이, 밸런스, UX, 새 기능 | "gameplay 팀입니다" |
| **infra** | 빌드, 배포, 광고 최적화, 스토어 | "infra 팀입니다" |
| **quality** | 리팩토링, 버그 탐색, 성능 개선 | "quality 팀입니다" |

### 세션 시작 프로토콜

세션 시작 시 반드시 아래 순서로 진행:
1. CLAUDE.md 읽기 (프로젝트 이해)
2. `.team/tasks.md` 읽기 (본인 팀 할당 작업 확인)
3. `.team/board.md` 읽기 (회의록, 다른 팀 요청사항, 관리자 지시 확인)
4. 할당된 작업 + board의 관련 지시를 종합하여 즉시 작업 시작

### 공유 파일 구조

```
.team/
  tasks.md              # 팀별 할당 작업 (lead가 관리)
  board.md              # 회의 게시판 (모든 팀 + lead 읽기/쓰기)
  {팀명}_done.md        # 팀별 완료 보고 (해당 팀이 작성)
```

### 회의 게시판 (board.md) 사용법

모든 팀과 관리자가 자유롭게 글을 남깁니다:
- **요청**: 다른 팀에 필요한 것 (예: "quality→gameplay: main.gd 분리 후 merge_balls 시그니처 변경됨, 확인 바람")
- **보고**: 작업 진행 상황, 발견한 이슈
- **결정**: 관리자가 내린 판단, 우선순위 변경
- **형식**: `[팀명] 날짜: 내용` (예: `[gameplay] 2026-03-07: 밸런스 분석 완료, 점수 곡선 조정안 적용함`)

### 작업 규칙

1. **능동적 실행**: 할당된 작업은 확인 없이 즉시 진행. 작업 중 발견한 추가 이슈도 본인 담당이면 스스로 처리
2. **코드 컨벤션**: GDScript, `_draw()` 기반 렌더링, 한국어 UI 유지
3. **완료 보고**: `.team/{팀명}_done.md`에 변경 파일 목록 + 요약 기록
4. **팀 간 소통**: 다른 팀에 영향을 주는 변경은 반드시 `.team/board.md`에 사전 공지
5. **금지**: 다른 팀 담당 영역 무단 수정 금지. 필요 시 board에 요청
6. **충돌 방지**: 같은 파일을 여러 팀이 동시 수정하지 않도록 board에서 조율

### 관리자(lead) 역할

- `.team/board.md`와 `{팀명}_done.md`를 읽고 진행 상황 파악
- 팀 간 충돌/의존성 조율
- 새 작업 할당 (`tasks.md` 업데이트)
- 완료된 작업의 코드 검토 및 피드백 (board에 기록)
