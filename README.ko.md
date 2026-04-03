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

- **다이나믹 아일랜드 형태** — 컴팩트, 확장, 전체 세 가지 모드. 클릭으로 전환, 부드러운 애니메이션 전환
- **실시간 동기화** — 가사를 한 줄씩 하이라이트, 재생 진행과 정확하게 동기화
- **다중 가사 소스** — 여러 제공자에서 자동 검색, 찾지 못하면 지능적으로 폴백
- **로그인 불필요** — 로컬 Spotify 클라이언트에서 직접 재생 상태를 읽어, 계정 인증이 필요 없음
- **경량 상주** — 메뉴 막대에서만 실행, Dock 아이콘 없음, 최소한의 리소스 사용
- **수동 미세 조정** — 가사 오프셋 조정(±0.5초)으로 소스별 타이밍 차이에 대응

## 미리보기

<!-- 스크린샷이나 GIF를 여기에 추가 -->

| Compact | Expanded | Full |
|:---:|:---:|:---:|
| 한 줄 가사 | 컨텍스트 미리보기 | 전체 가사 목록 |

## 시작하기

1. [Spotify 데스크톱 앱](https://www.spotify.com/download/)이 설치되어 있는지 확인
2. Lyrisland을 다운로드하고 실행
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

- [Lyricify Lyrics Helper](https://github.com/WXRIW/Lyricify-Lyrics-Helper) — Musixmatch 가사 API 참고

## License

All rights reserved.
