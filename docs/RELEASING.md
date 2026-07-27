# 릴리즈 가이드

## 한 줄 요약

```bash
./scripts/release.sh 0.2.0
```

버전을 올리고, 빌드가 되는지 확인하고, 태그를 밀면 GitHub Actions가
빌드 → 서명 → DMG/ZIP 생성 → 릴리즈 발행까지 처리합니다.

## 무엇이 만들어지나

| 파일 | 용도 |
|---|---|
| `Pawprint-<version>.dmg` | 사람이 받아서 Applications로 끌어다 놓는 것 |
| `Pawprint-<version>.zip` | 앱 내 자동 업데이트가 받는 것 |
| `Pawprint-<version>.zip.sig` | 위 zip의 Ed25519 서명 |

DMG와 ZIP을 둘 다 내는 이유: DMG는 첫 설치에 친절한 형식이지만, 실행 중인 앱을
디스크 이미지에서 교체하려면 마운트·복사·언마운트를 거쳐야 합니다. ZIP은 `ditto`로
한 번에 풀리고 서명도 보존되어서, 업데이터는 ZIP을 씁니다.

## 신뢰 모델

업데이트 피드는 평문 JSON이라 중간에서 바꿔치기될 수 있습니다. 그래서 **URL이 아니라
서명이 신뢰를 결정합니다.**

1. **Ed25519 서명** — 앱에 공개키가 박혀 있고, 개인키는 GitHub Actions 시크릿에만 있습니다.
   이 검증을 통과하지 못하면 아무것도 설치되지 않습니다.
2. **코드 서명** — 실행 중인 앱의 designated requirement를 내려받은 앱이 만족해야 합니다.
   단, ad-hoc 서명 빌드에서는 건너뜁니다. ad-hoc의 요구사항은 그 빌드의 해시라서
   다음 빌드가 만족할 방법이 애초에 없고, 요구하면 모든 업데이트를 거부하게 됩니다.

### 키 관리

키는 `scripts/updatekeys.swift generate`로 만듭니다.

- **공개키**: `Sources/Pawprint/Engine/UpdateChecker.swift`의 `UpdateDistribution.publicKey`
- **개인키**: GitHub 저장소 시크릿 `PAWPRINT_UPDATE_PRIVATE_KEY`

**공개키를 바꾸면 이전에 발행한 모든 릴리즈의 서명이 무효가 됩니다.** 개인키를 잃어버리면
새 키를 만들고 앱을 새로 배포해야 하며, 기존 사용자는 수동으로 다시 받아야 합니다.
로컬 사본은 `.secrets/update-keys.txt`에 있고 git에서 제외되어 있습니다.

## 코드 서명 현황

지금은 자체 서명(`Pawprint Dev`) 또는 CI에서 ad-hoc 서명입니다. 그래서:

- 받는 사람은 첫 실행 시 **우클릭 → 열기**를 해야 합니다.
- 자동 업데이트는 Ed25519 서명으로 보호되므로 정상 동작합니다.

Apple Developer ID($99/년)를 발급받으면 Gatekeeper 경고 없이 배포할 수 있습니다.
그 경우 워크플로에 인증서 import와 `xcrun notarytool submit` 단계를 추가하면 됩니다.

## 릴리즈 주기

정해진 주기는 강제하지 않습니다. 의미 있는 변경이 모이면 `release.sh`를 실행하세요.
버전은 semver를 따릅니다 — 기능 추가는 minor, 버그 수정은 patch.

실패한 릴리즈를 다시 발행하려면 Actions에서 **Release** 워크플로를
`workflow_dispatch`로 실행하고 태그를 입력하세요. 기존 에셋은 덮어씁니다.
