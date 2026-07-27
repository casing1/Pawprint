# Pawprint

<img src="https://img.shields.io/badge/macOS-14%2B-black" alt="macOS 14+"> <img src="https://img.shields.io/badge/Swift-5.10-orange" alt="Swift 5.10">

Mac을 어떻게 쓰는지 조용히 기록하고, 하루가 끝나면 귀여운 통계로 보여주는 메뉴 바 앱입니다.

## 다운로드

[**최신 릴리즈에서 .dmg 받기**](https://github.com/yhcho0405/Pawprint/releases/latest)

DMG를 열고 Pawprint를 Applications 폴더로 끌어다 놓으세요. 처음 실행할 때는
**우클릭 → 열기**로 실행해야 합니다 (Apple Developer ID 서명이 아직 없어 Gatekeeper가 막습니다).

## 기록하지 않는 것

입력한 **글자와 순서**, 비밀번호, **클립보드 내용**, 화면 캡처, 창·문서·웹페이지 내용은
저장하지 않습니다. 횟수와 시간, 집계값만 기록합니다.

모든 데이터는 이 Mac의 `~/Library/Application Support/Pawprint/` 안에만 있고,
동의 없이 어디로도 전송되지 않습니다. 앱은 인터넷 없이 완전히 동작합니다.
유일한 네트워크 기능인 업데이트 확인은 기본값이 **꺼짐**입니다.

## 필요한 권한

| 권한 | 이유 |
|---|---|
| 손쉬운 사용 | 마우스 이벤트와 앱 전환 감지 |
| 입력 모니터링 | 키를 눌렀다는 **사실만** 감지 (무엇을 눌렀는지는 읽지 않음) |

첫 실행 시 설정 마법사가 안내합니다. 설정 > 일반에서 다시 열 수 있습니다.

## 주요 기능

- **오늘의 고양이** — 그날의 기록에 따라 생김새가 달라지는 캐릭터 (17경 가지 조합)
- **도감** — 지금까지 모은 고양이를 희귀도·날짜·점수순으로 정렬
- **무한 레벨** — 타건·스크롤 등반·집중 등 11개 트랙, 끝없이 올라가는 목표치
- **라이브 HUD** — 항상 떠 있는 실시간 세션 패널
- **Pawprint Wrapped** — 월간 회고 슬라이드
- **공유 카드** — 오늘/누적 기록을 이미지로 만들어 클립보드에 복사

## 직접 빌드하기

```bash
swift build -c release
./scripts/build_app.sh release
open ./build/Pawprint.app
```

DMG를 만들려면:

```bash
./scripts/make_dmg.sh
```

## 릴리즈

버전을 올리고 태그를 밀면 GitHub Actions가 빌드·서명·DMG 생성·릴리즈 발행까지 처리합니다.

```bash
./scripts/release.sh 0.2.0
```

자세한 내용은 [docs/RELEASING.md](docs/RELEASING.md)를 참고하세요.

## 라이선스

Apache 2.0 — [LICENSE](LICENSE)
