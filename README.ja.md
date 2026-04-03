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

- **ダイナミックアイランド形態** — コンパクト、展開、フルの3つのモード。クリックで切り替え、スムーズなアニメーション遷移
- **リアルタイム同期** — 歌詞を1行ずつハイライト、再生の進行と正確に同期
- **複数の歌詞ソース** — 複数のプロバイダーから自動検索、見つからない場合はインテリジェントにフォールバック
- **ログイン不要** — ローカルの Spotify クライアントから直接再生状態を取得、アカウント認証は不要
- **軽量常駐** — メニューバーのみで動作、Dock アイコンなし、最小限のリソース使用
- **手動微調整** — 歌詞オフセット調整（±0.5秒）で、ソースごとのタイミング差に対応

## プレビュー

<!-- スクリーンショットや GIF をここに追加 -->

| Compact | Expanded | Full |
|:---:|:---:|:---:|
| 1行歌詞 | コンテキストプレビュー | 完全な歌詞リスト |

## はじめに

1. [Spotify デスクトップアプリ](https://www.spotify.com/download/)がインストールされていることを確認
2. Lyrisland をダウンロードして開く
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

- [Lyricify Lyrics Helper](https://github.com/WXRIW/Lyricify-Lyrics-Helper) — Musixmatch 歌詞 API リファレンス

## License

All rights reserved.
