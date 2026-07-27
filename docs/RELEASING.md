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

## 안정적인 서명 인증서 (권장)

macOS는 **손쉬운 사용 / 입력 모니터링 권한을 코드 서명에 묶어둡니다.** ad-hoc 서명은
빌드마다 해시가 달라지므로, 지금 상태에서는 **자동 업데이트를 받을 때마다 권한을 다시
허용해야 합니다.** 안정적인 인증서로 서명하면 이 문제가 사라집니다.

### 방법 A — 자체 서명 인증서 (무료)

Gatekeeper 경고는 남지만 권한 유지 문제는 해결됩니다. 로컬의 `Pawprint Dev` 인증서를
내보내서 저장소 시크릿에 넣으세요.

```bash
# 1. 내보내기 암호를 직접 정해서 .p12로 내보내기.
#    -P 를 쓰면 GUI 암호 창이 뜨지 않아, 암호가 정확히 무엇인지 확실해집니다.
P12PASS=$(openssl rand -base64 24 | tr -d '\n')
security export -k ~/Library/Keychains/login.keychain-db \
  -t identities -f pkcs12 -P "$P12PASS" -o /tmp/pawprint-signing.p12

# 2. 두 시크릿을 등록. 암호는 위에서 만든 $P12PASS 이지,
#    업데이트 서명키(PAWPRINT_UPDATE_PRIVATE_KEY)가 아닙니다 — 셋은 서로 다른 값입니다.
base64 -i /tmp/pawprint-signing.p12 | gh secret set MACOS_CERTIFICATE_P12 --repo yhcho0405/Pawprint
printf '%s' "$P12PASS" | gh secret set MACOS_CERTIFICATE_PASSWORD --repo yhcho0405/Pawprint

# 3. 흔적 지우기 (암호는 .secrets/update-keys.txt 에 보관해두세요)
rm -f /tmp/pawprint-signing.p12
```

### 시크릿 세 개의 역할

| 시크릿 | 정체 | 역할 |
|---|---|---|
| `PAWPRINT_UPDATE_PRIVATE_KEY` | Ed25519 개인키 | 업데이트 아카이브 서명 — 앱이 진짜인지 판단하는 기준 |
| `MACOS_CERTIFICATE_P12` | 코드 서명 인증서 + 키 (base64) | 앱 코드 서명 — 권한 유지 |
| `MACOS_CERTIFICATE_PASSWORD` | 위 .p12의 **내보내기 암호** | .p12를 여는 데만 쓰임 |

시크릿이 있으면 워크플로가 자동으로 인증서를 가져와 서명하고, 결과가 ad-hoc이면 릴리즈를
**실패시킵니다**. 조용히 ad-hoc으로 넘어가면 사용자가 업데이트할 때마다 권한이 초기화되는데,
릴리즈 자체는 멀쩡히 발행되어서 한참 뒤에야 드러나기 때문입니다.

자체 서명 인증서는 새 키체인에서 신뢰 설정이 없어 `security find-identity -v`에 잡히지 않습니다.
서명을 *만드는* 데는 신뢰가 필요 없고 *검증*할 때만 필요하므로, 워크플로는 인증서 레이블을 읽어
`PAWPRINT_SIGN_IDENTITY`로 넘겨줍니다.

### 방법 B — Apple Developer ID ($99/년)

Gatekeeper 경고까지 없애려면 Developer ID Application 인증서를 같은 방식으로 등록하고,
워크플로의 패키징 단계 뒤에 공증을 추가하세요.

```yaml
- name: Notarize
  run: |
    xcrun notarytool submit dist/Pawprint-$VERSION.dmg \
      --apple-id "$APPLE_ID" --team-id "$TEAM_ID" \
      --password "$APP_SPECIFIC_PASSWORD" --wait
    xcrun stapler staple dist/Pawprint-$VERSION.dmg
```
