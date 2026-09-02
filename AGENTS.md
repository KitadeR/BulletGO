# AGENTS.md

## XcodeBuildMCP

- If using XcodeBuildMCP, use the installed XcodeBuildMCP skill before calling XcodeBuildMCP tools.

## Product Context

- BulletGOは ToDo /「今すぐやること」アプリではない。旅行全体を理解し、ユーザーが「今は何を気にすればいいか」を整理する（詳細: Knowledge `開発方針_本番基盤優先_2026-09-02`）。
- デモ用プロトタイプ・ハードコード専用データ・捨てるスローワウェイは作らない。未実装機能は導線 + Coming Soon（本番ルーティングは本物）。
- BulletGOの仕様・プロダクト判断の正は BulletGO-Knowledge 側にある。
- BulletGOの機能実装や仕様に関わる変更をする前に、まず Workspace root `BulletGO-Knowledge` にある `Hub.md` を読む。
- Hubが示す最新の `現在地_*.md` を現在の正として読む。
- その後、今回のタスクに直接関係する詳細設計だけ追加で読む。
- Obsidian側の全資料を毎回無条件に読まない。
- Workspace root `BulletGO-Knowledge` が利用できない場合は、仕様を推測して実装を進めず、ユーザーに確認する。

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

- `BulletGO-Knowledge` はプロダクト仕様・判断履歴の長期記憶として扱う。
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
