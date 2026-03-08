# 시총 키우기 - 출시 체크리스트

## 자동 완료된 항목

- [x] 코드 작업 완료 (14건 — 게임플레이/인프라/품질)
- [x] export_presets.cfg: AAB 포맷, arm64-v8a, 아이콘 경로 설정
- [x] 런처 아이콘 생성 (192, 432x3종, 512 Play Store용)
- [x] 광고 ID: 프로덕션 ID 설정, 릴리스 빌드 자동 전환
- [x] 권한: INTERNET, ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE
- [x] Play Store 등록정보 텍스트 작성 (store_listing.txt)
- [x] 개인정보처리방침 페이지 작성 (privacy_policy.html)
- [x] ad_config.cfg .gitignore 처리 (보안)

## 수동 작업 필요 (Godot 에디터 / Play Console)

### 1. 빌드 전 확인
- [ ] Godot 에디터에서 프로젝트 열고 에러 없는지 확인
- [ ] Editor Settings > Export > Android에서 keystore 경로/비밀번호 설정
  - Keystore 파일: `release.keystore` (프로젝트 루트)
  - Debug keystore도 설정 필요
- [ ] Android SDK/NDK 경로 설정 확인
- [ ] AdMob 플러그인 정상 로드 확인

### 2. AAB 빌드
- [ ] Godot 에디터 > Project > Export > Android > Export Project
- [ ] `stockmerge.aab` 파일 생성 확인
- [ ] (선택) 로컬 테스트: `bundletool` 으로 APK 추출 후 기기 설치 테스트

### 3. Google Play Console
- [ ] https://play.google.com/console 접속
- [ ] 새 앱 만들기 (앱 이름: "시총 키우기 - 주식 머지 게임")
- [ ] 앱 설정:
  - [ ] 앱 액세스 권한: 특별한 액세스 권한 없음
  - [ ] 광고: 예, 광고 포함
  - [ ] 콘텐츠 등급: 설문지 작성 (전체이용가)
  - [ ] 타겟 잠재고객: 13세 이상
  - [ ] 뉴스 앱: 아니오
  - [ ] 코로나19 접촉자 추적/상태 앱: 아니오
  - [ ] 데이터 보안: 설문지 작성 (아래 참고)
- [ ] 스토어 등록정보:
  - [ ] 앱 이름, 간단한 설명, 자세한 설명 → store_listing.txt 참고
  - [ ] 앱 아이콘: icons/icon_512.png 업로드
  - [ ] 그래픽 이미지 (1024x500): 별도 제작 필요
  - [ ] 스크린샷: 폰 2장 이상 (게임 플레이 화면 캡처)
  - [ ] 카테고리: 게임 > 캐주얼
  - [ ] 개인정보처리방침 URL: privacy_policy.html 호스팅 후 URL 입력
- [ ] 프로덕션 트랙에 AAB 업로드
- [ ] 출시 검토 제출

### 4. 데이터 보안 설문 답변 가이드

| 질문 | 답변 |
|------|------|
| 앱에서 필수 사용자 데이터 유형을 수집하거나 공유하나요? | 예 (AdMob) |
| 수집되는 데이터 유형 | 기기 또는 기타 ID (광고 ID) |
| 데이터 암호화 전송 | 예 (HTTPS) |
| 데이터 삭제 요청 방법 | 앱 삭제 시 로컬 데이터 자동 삭제 |
| 어린이를 대상으로 하나요? | 아니오 (13세 이상) |

### 5. 개인정보처리방침 호스팅
- [ ] privacy_policy.html을 웹에 호스팅 (옵션 택1):
  - GitHub Pages: repo에 push 후 Settings > Pages 활성화
  - 개인 웹사이트에 업로드
  - Firebase Hosting 등
- [ ] 호스팅된 URL을 Play Console에 입력
- [ ] privacy_policy.html의 이메일 주소 변경 (tgpark@example.com → 실제 이메일)

### 6. 출시 후
- [ ] Play Console에서 검토 상태 확인 (보통 수시간~수일)
- [ ] 승인 후 스토어에서 앱 확인
- [ ] AdMob 대시보드에서 광고 노출 확인
- [ ] 크래시 리포트 모니터링 (Play Console > Android vitals)
