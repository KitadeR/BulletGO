# AGENTS.md

## XcodeBuildMCP

- If using XcodeBuildMCP, use the installed XcodeBuildMCP skill before calling XcodeBuildMCP tools.

## Product Context

- BulletGOは訪日旅行者のための Inbound Navigation OS。旅行全体を理解し、ユーザーが「今は何を気にすればいいか」を整理するプロダクトである。
- BulletGOは ToDo /「今すぐやること」アプリではない。必要な手順だけを、必要なタイミングで示す。
- ハブ型のプロダクトとして、予約・決済を代行せず、適切なサービスや公式手順へ案内する。
- 既存Architectureを守る。旅程（`Trip` / `Leg` / `Stay` / `Activity`）から Trip State、Policy、Action、Task、文脈に応じた表示へ至る流れを維持する。ルールの判定はコード、AIは解釈・抽出に限定する。
- デモ用プロトタイプ・ハードコード専用データ・捨てるスローワウェイは作らない。未実装機能は、仕様に沿った本物の導線 + 文脈付き Coming Soon とする。

## Knowledge Is the Source of Truth

- Knowledge `Projects/BulletGO/`（Obsidian Vault 内。Vault の物理パスは開発者環境ごとに異なる）は、BulletGOの仕様・プロダクト判断の正である。Obsidian MCPの利用を前提にせず、直接ファイルから読む。
- 機能実装や仕様に関わる変更の前に、原則として次の順で確認する。
  1. `Projects/BulletGO/Hub.md`
  2. Hubが現在の正として指定する最新の `現在地_*.md`
  3. `Projects/BulletGO/実装振り分け_2026-09-02.md`
  4. タスクに直接関係する `UIUX方針_*.md` や設計資料
- 日付付きファイル名をこの指示に固定しない。常にHubが指定する現在の正を優先する。
- Knowledge側の全資料を毎回無条件に読まない。必須の入口資料の後は、タスクに関係する詳細設計だけを読む。
- Knowledgeが利用できない、または必要な仕様判断を解決できない場合は、仕様を推測して実装せずユーザーに確認する。

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

- 既存のArchitecture、命名、データフローを尊重する。実装の都合だけでアーキテクチャや確定仕様を変えない。

## Knowledge Updates

- Knowledge（`Projects/BulletGO/`）はプロダクト仕様・判断履歴の長期記憶として扱う。
- iOS実装中にコードとKnowledgeの差分や、新しい仕様判断の必要性を見つけても、Knowledge側を勝手に変更しない。
- Knowledge側の変更が必要な場合は、まず「何を・なぜ変更する必要があるか」をユーザーに提示する。
- ユーザーが承認した場合のみ、Knowledge側の該当ファイルを更新する。
- 実装上の都合だけを理由に、確定済みの仕様を黙って変更しない。

## Git Safety

- 作業前に現在のbranchとworking treeを確認する。`main` が最新実装とは限らない。
- 既存の未コミット変更を保持し、無関係なファイルを上書き・破棄・整形しない。
- ユーザーの明示的な指示なしにbranch作成、merge、pushを行わない。

## Xcode Tooling

- `.xcodebuildmcp/config.yaml` の既存設定を優先する。想定する既定値は Project `BulletGO.xcodeproj`、Scheme `BulletGO`、Simulator `iPhone 17 Pro Max`。
- XcodeBuildMCPは Build / Run / Test / Simulator / Screenshot / UI Automation / Debugging に使用可能。利用環境に対応するスキルや手順がある場合は、ツール呼び出し前に従う。
- 必要に応じて通常の `xcodebuild` も使用できる。
- Apple APIやSDKの仕様確認が必要な場合は、推測よりApple公式情報を優先する。

## Verification

- Apple APIについて不確かな場合は推測せずApple Documentationを確認する。
- 実装後はXcodeBuildMCPまたは `xcodebuild` を使ってBuildを確認する。
- Build errorがある状態を完了としない。
- UI変更ではSwiftUI PreviewまたはSimulatorで確認する。
- 変更に関係するTest・検証を行ってから完了とする。最小限でも意味のある検証範囲を選び、実行しなかった検証は明記する。
- 検証でエラーが出た場合、依頼されていない修正を行う前に、エラー内容・推定原因・影響するファイルを報告する。
