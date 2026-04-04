<p align="center">
  <img src="Assets/icon.png" width="128" height="128" alt="Lyrisland Icon">
</p>

<h1 align="center">Lyrisland</h1>

<p align="center">
  <em>/ˈlɪrɪslænd/</em> — Lyrics + Island
</p>

<p align="center">
  macOS용 다이나믹 아일랜드 스타일 Spotify 실시간 가사 표시
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0%2B-blue" alt="macOS 14.0+">
  <img src="https://img.shields.io/badge/Spotify-Desktop-1DB954?logo=spotify&logoColor=white" alt="Spotify">
</p>

<p align="center">
  <a href="README.zh-CN.md">简体中文</a> | <a href="README.zh-TW.md">繁體中文</a> | <a href="README.md">English</a> | <a href="README.ja.md">日本語</a> | <strong>한국어</strong>
</p>

---

## Lyrisland이란?

Lyrisland은 화면 상단에 다이나믹 아일랜드(Dynamic Island) 스타일로 Spotify에서 재생 중인 가사를 실시간으로 표시합니다. 가사는 음악과 정확하게 동기화되며, 가볍고 우아하게 데스크톱에 상주합니다.

## 기능

- **다이나믹 아일랜드 형태** — 컴팩트, 확장, 전체 세 가지 모드, 부드러운 애니메이션 전환. 확장 모드에서 곡 정보, 전체 모드에서 재생 컨트롤(이전/재생·일시정지/다음) 표시
- **실시간 동기화** — 가사를 한 줄씩 하이라이트, 재생 진행과 정확하게 동기화
- **앨범 아트워크** — 세 가지 모드 모두 앨범 커버 표시: 컴팩트 모드 썸네일, 확장 모드 중간 크기, 전체 모드 대형 커버
- **2줄 가사** — 노래방 스타일로 현재 줄과 다음 줄을 동시에 표시 (⌘D로 전환)
- **다중 가사 소스** — 4개 제공자 폴백 체인: LRCLIB → Musixmatch → SodaMusic → Netease. 설정에서 드래그 정렬 및 개별 활성화/비활성화 가능
- **유연한 위치 지정** — 메뉴 막대에 스냅하거나 화면 아무 곳에나 자유롭게 드래그. 위치 설정은 재시작 후에도 유지
- **배경 스타일** — 단색, 앨범 그라디언트, 프로스트 글래스, 다이나믹 그라디언트 중 선택
- **단축키 커스터마이즈** — 설정에서 모든 키보드 단축키 확인·재바인딩·비활성화 가능. 충돌 감지 및 원클릭 초기화 지원
- **RTL 지원** — 오른쪽에서 왼쪽 언어(아랍어 등) 자동 감지, 마키 스크롤과 정렬이 자동 적응
- **다국어 UI** — English、简体中文、繁體中文、日本語、한국어
- **로그인 불필요** — AppleScript로 로컬 Spotify 클라이언트에서 직접 재생 상태를 읽어, 계정 인증 불필요
- **경량 상주** — 메뉴 막대에서만 실행, Dock 아이콘 없음, 최소한의 리소스 사용

## 설치

### Homebrew (권장)

```bash
brew tap EurFelux/lyrisland
brew install --cask lyrisland

# 최신 버전으로 업데이트
brew upgrade lyrisland
```

### 수동 다운로드

[GitHub Releases](https://github.com/EurFelux/Lyrisland/releases)에서 최신 `.dmg` 파일을 다운로드하고, 열어서 Lyrisland을 응용 프로그램 폴더로 드래그하세요.

## 미리보기

#### Compact
![Compact](Assets/screenshots/attached.png)

#### Expanded
![Expanded](Assets/screenshots/expanded.png)

#### Full
![Full](Assets/screenshots/full.png)

### 배경 스타일

#### 단색
![Solid](Assets/screenshots/bg-solid.png)

#### 앨범 그라디언트
![Gradient](Assets/screenshots/bg-album-gradient.png)

#### 프로스트 글래스
![Glass](Assets/screenshots/bg-glass.png)

#### 다이나믹 그라디언트
![Dynamic](Assets/screenshots/bg-dynamic-gradient.png)

### 위치 모드

#### 메뉴 막대 스냅
![Attached](Assets/screenshots/attached.png)

#### 자유 플로팅
![Detached](Assets/screenshots/detached-compact.png)

## 시작하기

1. [Spotify 데스크톱 앱](https://www.spotify.com/download/)이 설치되어 있는지 확인
2. Lyrisland을 실행
3. 처음 실행 시 macOS에서 자동화 권한을 요청합니다 — 허용해 주세요
4. Spotify에서 노래를 재생하면 화면 상단에 가사가 자동으로 표시됩니다

## 요구 사항

- macOS 14.0 (Sonoma) 이상
- Spotify 데스크톱 클라이언트

## FAQ

**Q: Spotify 계정 로그인이 필요한가요?**
아닙니다. Lyrisland은 로컬 Spotify 클라이언트에서 재생 정보를 읽기 때문에 계정 인증이 필요 없습니다.

**Q: 일부 노래에 가사가 표시되지 않는 이유는?**
가사는 서드파티 공개 데이터베이스에서 가져옵니다. 비주류 곡이나 인스트루멘탈은 아직 수록되지 않았을 수 있습니다.

**Q: 가사와 음악이 맞지 않으면?**
메뉴 막대 아이콘에서 오프셋 조정을 사용하세요(`[` / `]` 키, ±0.5초씩).

**Q: Apple Music을 지원하나요?**
현재는 Spotify만 지원합니다.

## Credits

- [Lyricify Lyrics Helper](https://github.com/WXRIW/Lyricify-Lyrics-Helper) — Musixmatch 및 Netease 가사 API 참고

## License

이 프로젝트는 [GNU General Public License v3.0](LICENSE) 하에 라이선스됩니다.
