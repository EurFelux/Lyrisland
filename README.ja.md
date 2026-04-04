<p align="center">
  <img src="Assets/icon.png" width="128" height="128" alt="Lyrisland Icon">
</p>

<h1 align="center">Lyrisland</h1>

<p align="center">
  <em>/ˈlɪrɪslænd/</em> — Lyrics + Island
</p>

<p align="center">
  macOS 向けダイナミックアイランド風 Spotify リアルタイム歌詞表示
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0%2B-blue" alt="macOS 14.0+">
  <img src="https://img.shields.io/badge/Spotify-Desktop-1DB954?logo=spotify&logoColor=white" alt="Spotify">
</p>

<p align="center">
  <a href="README.zh-CN.md">简体中文</a> | <a href="README.zh-TW.md">繁體中文</a> | <a href="README.md">English</a> | <strong>日本語</strong> | <a href="README.ko.md">한국어</a>
</p>

---

## Lyrisland とは？

Lyrisland は、画面上部にダイナミックアイランド（Dynamic Island）スタイルで、Spotify で再生中の歌詞をリアルタイム表示します。歌詞は音楽と正確に同期し、軽量でエレガント、常にデスクトップに常駐します。

## 機能

- **ダイナミックアイランド形態** — コンパクト、展開、フルの3つのモード、スムーズなアニメーション遷移。展開モードでは楽曲情報、フルモードでは再生コントロール（前へ/再生・一時停止/次へ）を表示
- **リアルタイム同期** — 歌詞を1行ずつハイライト、再生の進行と正確に同期
- **アルバムアートワーク** — 3つのモードすべてでアルバムカバーを表示：コンパクトモードはサムネイル、展開モードは中サイズ、フルモードは大サイズ
- **2行歌詞** — カラオケスタイルで現在の行と次の行を同時表示（⌘D で切り替え）
- **複数の歌詞ソース** — 4つのプロバイダーによるフォールバックチェーン：LRCLIB → Musixmatch → SodaMusic → Netease。設定でドラッグ並べ替えや個別の有効/無効が可能
- **柔軟な配置** — メニューバーに吸着、または画面の任意の位置に自由にドラッグ。位置設定は再起動後も保持
- **背景スタイル** — ソリッドカラー、アルバムグラデーション、すりガラス、ダイナミックグラデーションの4種類から選択
- **ショートカットカスタマイズ** — 設定ですべてのキーボードショートカットの確認・再バインド・無効化が可能。競合検出とワンクリックリセット付き
- **RTL サポート** — 右から左に書く言語（アラビア語など）を自動検出、マーキースクロールと配置が自動適応
- **多言語 UI** — English、简体中文、繁體中文、日本語、한국어
- **ログイン不要** — AppleScript でローカルの Spotify クライアントから直接再生状態を取得、アカウント認証は不要
- **軽量常駐** — メニューバーのみで動作、Dock アイコンなし、最小限のリソース使用

## インストール

### Homebrew（推奨）

```bash
brew tap EurFelux/lyrisland
brew install --cask lyrisland

# 最新バージョンに更新
brew upgrade lyrisland
```

### 手動ダウンロード

[GitHub Releases](https://github.com/EurFelux/Lyrisland/releases) から最新の `.dmg` をダウンロードし、開いて Lyrisland をアプリケーションフォルダにドラッグしてください。

## プレビュー

#### Compact
![Compact](Assets/screenshots/attached.png)

#### Expanded
![Expanded](Assets/screenshots/expanded.png)

#### Full
![Full](Assets/screenshots/full.png)

### 背景スタイル

#### ソリッド
![Solid](Assets/screenshots/bg-solid.png)

#### アルバムグラデーション
![Gradient](Assets/screenshots/bg-album-gradient.png)

#### すりガラス
![Glass](Assets/screenshots/bg-glass.png)

#### ダイナミックグラデーション
![Dynamic](Assets/screenshots/bg-dynamic-gradient.png)

### 配置モード

#### メニューバー吸着
![Attached](Assets/screenshots/attached.png)

#### フリーフロート
![Detached](Assets/screenshots/detached-compact.png)

## はじめに

1. [Spotify デスクトップアプリ](https://www.spotify.com/download/)がインストールされていることを確認
2. Lyrisland を開く
3. 初回起動時、macOS がオートメーション権限を要求します — 許可してください
4. Spotify で曲を再生すると、歌詞が画面上部に自動表示されます

## 動作要件

- macOS 14.0 (Sonoma) 以降
- Spotify デスクトップクライアント

## よくある質問

**Q: Spotify アカウントへのログインは必要ですか？**
いいえ。Lyrisland はローカルの Spotify クライアントから再生情報を取得するため、アカウント認証は不要です。

**Q: 一部の曲で歌詞が表示されないのはなぜですか？**
歌詞はサードパーティの公開データベースから取得しています。マイナーな楽曲やインストゥルメンタルはまだ収録されていない場合があります。

**Q: 歌詞と音楽がずれている場合は？**
メニューバーアイコンからオフセット調整を使用してください（`[` / `]` キー、±0.5秒ずつ）。

**Q: Apple Music には対応していますか？**
現在は Spotify のみ対応しています。

## Credits

- [Lyricify Lyrics Helper](https://github.com/WXRIW/Lyricify-Lyrics-Helper) — Musixmatch・Netease 歌詞 API リファレンス

## License

このプロジェクトは [GNU General Public License v3.0](LICENSE) の下でライセンスされています。
