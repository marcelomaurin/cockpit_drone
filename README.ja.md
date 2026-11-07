[Português](README.md) · [English](README.en.md) · [Español](README.es.md) · [Français](README.fr.md) · [Deutsch](README.de.md) · [Русский](README.ru.md) · [中文](README.zh-CN.md) · [日本語](README.ja.md) · [العربية](README.ar.md) · [हिन्दी](README.hi.md)

# Cockpit Drone - ドローン制御・テレメトリ監視・3Dシミュレーションシステム

Object Pascal（Lazarus / Free Pascal）で開発された、ドローンや無人航空機（UAV）のための総合リモートコントロール＆シミュレーションシステム。アナログジョイスティック、GPSセンサー、低遅延ライブ映像（H.264および合成カメラ）、OpenStreetMapベースの戦術マップ、オンライン共有マルチプレイヤーを統合しています。

---

## 目次

1. [プロジェクト概要](#プロジェクト概要)
2. [プロジェクト構成](#プロジェクト構成)
3. [対応プロトコル](#対応プロトコル)
4. [公式3Dシミュレーター＆マルチプレイヤー](#公式3dシミュレーターマルチプレイヤー)
5. [操作方法：ジョイスティック vs キーボード](#操作方法ジョイスティック-vs-キーボード)
6. [コンパイル済みバイナリのダウンロード](#コンパイル済みバイナリのダウンロード)
7. [連絡先とライセンス](#連絡先とライセンス)

---

## プロジェクト概要

**Cockpit Drone**は、UIとフライト制御通信スレッドを分離した安全設計を採用しています。50ms周期のコマンド送信やテレメトリ受信がダイアログ等でブロックされることはありません。

主な特徴：
- **フェイルセーフ設計：** スペースキーによる緊急モーター停止（パニック機能）と自動ホバリング復帰。
- **タクティカルUI：** 飛行計器、LEDインジケーター、ミリタリー風HUD、地図トラッキング、リアルタイム映像。
- **統合エコシステム：** 6DOF物理エンジン搭載の**3Dフライトシミュレーター**（`simulador/`）およびPHP/WebSocketサーバー（`PHP/`）。

---

## 公式3Dシミュレーター＆マルチプレイヤー

> **マルチプレイヤー接続について：**  
> **共有ワールド（マルチプレイヤー）**への接続は**シミュレーター**（`simulador.exe`）から行います：  
> 1. `simulador.exe` を起動します。  
> 2. 「共有ワールド」パネルでサーバーURL（`https://maurinsoft.com.br/cockpit/`）とコールサインを入力し、**入室**をクリックします。  
> 3. 半径**2km**以内のドローンがマップおよび3D画面上に自動表示されます。  
> 4. 地上局 **Cockpit Drone**（`drone.exe`）はローカルの `127.0.0.1` でシミュレーターに接続します。

---

## コンパイル済みバイナリのダウンロード

[`bin/`](bin/) フォルダから最新版を直接ダウンロード可能です：
- **`bin/setup_cockpit_drone_0.41.exe`：** シミュレーターを含む完全なWindowsインストーラー。
- **`bin/drone.exe`：** Cockpit Drone 実行ファイル。
- **`bin/simulador.exe`：** 3Dシミュレーター 実行ファイル。

---

## 連絡先とライセンス

- **開発者：** Marcelo Maurin Martins (marcelomaurinmartins@gmail.com)
- **公式ウェブサイト：** [Maurinsoft - Cockpit Drone](https://maurinsoft.com.br/wp/projetos-open-source/projeto-cockpit-drone/)
