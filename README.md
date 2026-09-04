# BulletGO

**BulletGO** is an iOS app that connects itinerary, reservations, luggage, and official rules — and shows **what the traveler needs to do next**, instead of dumping more information on them.

**BulletGO** は、旅程・予約・荷物・公式ルールをつなぎ、情報を増やすのではなく **「次に何をすればいいか」** を旅行者に示す iOS アプリです。日本の新幹線旅を想定して設計し、現状はその縦スライスを中心に開発しています。

> **Status:** Work in progress  
> **Latest code:** [`feature/working-trip`](https://github.com/KitadeR/BulletGO/tree/feature/working-trip)  
> `main` は初期セットアップのみで、アプリ本体はまだ含まれていません。

---

## Overview

旅行アプリは予約や検索に強い一方、**予約後の準備**（荷物ルール・当日の行動・公式手続き）がバラバラになりがちです。BulletGO はそのギャップを埋めます。

- 予約・決済は **BulletGO 内では行わない**（SmartEX 等の既存サービスを前提）
- 大量の情報を並べず、**今やるべきこと 1 件**を Contextual Home で提示
- 各移動（Leg）ごとに、ルール評価 → タスク生成 → ガイド表示までつなぐ

個人開発（神戸電子専門学校・SwiftUI）。以前は AI×目標分解アプリ BestWay を企画〜実装（別プロジェクト）。

---

## Design Principles

| 原則 | 内容 |
|---|---|
| **ルール判定は AI に任せない** | 旅程の自由入力抽出などに AI を使う一方、荷物可否などの判定は JSON Pack + Rule Engine で決定的に行う |
| **Ask only when needed** | Leg Detail は Setup（必要な質問だけ）→ Cockpit（整理済み画面）。全 Leg で同じ質問をしない |
| **Contextual Home** | 旅行フェーズ（出発前 / 旅中 / 終了後）に応じて Home の見せ方を変える |

> Skipped（わからない）回答はセットアップを進めても **ready 扱いにしない** — 不確実さを完了したふりをしない。

---

## Current Status

### ✅ Implemented (`feature/working-trip`)

- Trip / Leg / Stay / Activity ドメインモデル + SwiftData 永続化
- Question Engine → Policy 評価 → Task 生成
- 新幹線特大荷物ルール（160cm 判定）+ Baggage measurement Guide
- **Contextual Home**（Primary NOW / 日別スケジュール）
- **Trips** — 旅程作成・日別タイムライン・CRUD
- **Leg Detail** — Setup → Cockpit
- Guidance（自由入力 → 旅程・移動への反映）
- 英日 2 言語 UI（String Catalog）
- Unit tests / UI tests

### 🚧 In progress / planned

- Home / Trips / Cockpit の UI 磨き
- 予約証跡（Reservation evidence）
- PDF / screenshot からの旅程取り込み
- You タブの実機能（Language 等は Coming Soon）
- 追加 Policy pack（飛行機・USJ 等）
- 旅程抽出 Worker の本番接続（API key はリポジトリ外）

---

## Example Flow（新幹線 Leg）

```text
Tokyo → Kyoto を追加
  → 移動日 → Shinkansen → 予約状況 → 荷物
  → Policy 評価（160cm）
  → Task 生成 → Home の Primary NOW → Baggage Guide
```

Simulator では Reference trip（東京→京都…）から試せます。

---

## Tech Stack

- Swift / SwiftUI / SwiftData
- Domain · Engine · Features レイヤー
- JSON policy / question packs
- XCTest / XCUITest
- Itinerary extract: local extractor + optional Cloudflare Worker（本番キーは repo 外）
- iOS 26.5+ · Xcode · Cursor

---

## Getting Started

1. `git checkout feature/working-trip`
2. `BulletGO.xcodeproj` を Xcode で開く
3. Scheme **BulletGO** → Simulator で Run
4. 東京→京都の Reference flow を試す
5. テスト: `Cmd+U` または `xcodebuild test`

---

## Roadmap

- **Phase 1** — 新幹線縦スライス（旅程 + Home + Leg + Guide）← **いまここ**
- **Phase 2** — 予約証跡・追加 Policy・You タブ
- **Phase 3** — 日本の交通・サービス利用を想定した拡張・本番 Worker 接続

## Screenshots

*(Coming soon — Home, Trips, Leg Setup, Baggage guide)*

---

**Author:** Ruwa Kitade（北出琉和）— 神戸電子専門学校 AIシステム開発学科

**License:** All rights reserved.
