# AGENTS.md

## XcodeBuildMCP

- If using XcodeBuildMCP, use the installed XcodeBuildMCP skill before calling XcodeBuildMCP tools.

## Product Context

- BulletGOは ToDo /「今すぐやること」アプリではない。旅行全体を理解し、ユーザーが「今は何を気にすればいいか」を整理する（詳細: Knowledge `開発方針_本番基盤優先_2026-09-02`）。
- デモ用プロトタイプ・ハードコード専用データ・捨てるスローワウェイは作らない。未実装機能は導線 + Coming Soon（本番ルーティングは本物）。
- BulletGOの仕様・プロダクト判断の正は Obsidian `Projects/BulletGO/`（Knowledge）側にある。
- BulletGOの機能実装や仕様に関わる変更をする前に、まず `Projects/BulletGO/Hub.md` を読む。
- Hubが示す最新の `現在地_*.md` を現在の正として読む。
- 実装の何を本物/骨格/準備中にするかは `実装振り分け_2026-09-02.md` を参照。
- その後、今回のタスクに直接関係する詳細設計だけ追加で読む（例: `参照シナリオ_縦スライス1本_2026-09-02.md`）。
- Obsidian側の全資料を毎回無条件に読まない。
- Knowledge が利用できない場合は、仕様を推測して実装を進めず、ユーザーに確認する。
- 作業再開時のテンプレは Knowledge `開発運用_GitHub_2026-09-02.md` を参照。
- 実装の前に Plan でブロック設計を固め、Plan 成果物（引き継ぎ文）を Agent に渡してから実装する（詳細: 同ノート「Cursor — モデルとモード」）。

## Cursor Mode and Model

モデル選定の正は Knowledge `開発運用_GitHub_2026-09-02.md`（「Cursor — モデルとモード」）。要約:

- **Plan** — GPT-5.6 Sol High（重要: Sol Max）— ブロック設計・Agent 引き継ぎ文
- **Agent** — Grok 4.6 High（重要: XHigh; UI は Composer 2.5 も試す）— Swift 実装
- **Ask** — Grok 4.6 Medium/High（重要: Sol High）— 相談・理解
- **Debug** — Grok High → XHigh / Fable（Ask→Agent の後）
- **小修正** — Composer 2.5

## Next Step Recommendation

るわさんが「続きしたい」「〇〇やりたい」「次何する？」等、**次の作業を示す・相談する**返答のときは、**最後に1行**でおすすめの Cursor **モード + モデル**を案内する。

形式例: `次のおすすめ: 🧠 Plan モード · GPT-5.6 Sol High（ブロック2のドメイン設計）`

Knowledge のブロック別おすすめと整合させる。Plan 未了で実装に入る場合は Plan を先に勧める。

## Source of Truth

- 情報が衝突した場合は、Hubが「正」と指定する現在地を最優先する。
- 同じテーマの設計が複数ある場合は、より新しい確定設計を優先する。
- 古い `現在地_*.md`、旧ロードマップ、初期検討ノートは現在仕様として扱わない。
- 古い資料は「なぜその判断になったか」を調べる場合の背景資料として使う。
- 古い案を根拠なく現在仕様として復活させない。

## Before Implementation

大きな変更を始める前に、短く以下を整理する。

- 今回実装するもの
- 参照したKnowledgeファイル
- 影響するモデル・状態
- 変更予定ファイル

## Knowledge Updates

- Knowledge（`Projects/BulletGO/`）はプロダクト仕様・判断履歴の長期記憶として扱う。
- iOS実装中にコードとKnowledgeの差分や、新しい仕様判断の必要性を見つけても、Knowledge側を勝手に変更しない。
- Knowledge側の変更が必要な場合は、まず「何を・なぜ変更する必要があるか」をユーザーに提示する。
- ユーザーが承認した場合のみ、Knowledge側の該当ファイルを更新する。
- 実装上の都合だけを理由に、確定済みの仕様を黙って変更しない。

## Xcode Tooling

- Apple Xcode MCP は、Apple Documentation の確認、SwiftUI Preview、Xcode Issues / IDE context の確認に使用する。
- XcodeBuildMCP は、Build & Run、Simulator、Screenshot、UI Automation、Debugging に使用する。
- XcodeBuildMCPを使う場合は、既存の XcodeBuildMCP Skill の指示を先に確認する。
- 同じ目的で複数のツールを無駄に重複実行しない。
- Apple APIやSDKの仕様確認が必要な場合は、推測よりApple公式情報を優先する。

## Verification

- Apple APIについて不確かな場合は推測せずApple Documentationを確認する。
- 実装後はXcode/XcodeBuildMCPを使ってBuildを確認する。
- Build errorがある状態を完了としない。
- UI変更ではSwiftUI PreviewまたはSimulatorで確認する。
- 必要に応じてUI AutomationやTestを使用する。
