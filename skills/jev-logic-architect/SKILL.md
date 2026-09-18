---
name: jev-logic-architect
description: Transforms identified business decisions into concrete, typed Jev schemas, confidence-based fallback flows, and stack-adaptive code designs (TS/Python/HTTP) ready for SDD design.md and tasks.md.
---

# Jev Logic Architect

このスキルは、前段の `jev-candidate-detector` で承認（`decision: approved`）された業務判断ポイント、およびプロジェクトの技術スタックを入力とし、**仕様駆動開発（Kiro/cc-sdd等）の設計書（`design.md`）、ADR、およびタスク分解（`tasks.md`）にそのまま組み込める堅牢な技術仕様**（TypeSafe公式SDKコード、3プリミティブ定義、実証的閾値設計、耐障害フォールバック）を生成します。

必ず事前に `references/jev-design-patterns.md` を精読して設計パターンを把握した上で実行してください。

---

## スコープ境界（委譲事項）

本スキルがカバーするのは **Jev 固有の設計**（3プリミティブのスキーマ、確信度・閾値設計、フォールバック・耐障害設計）までです。以下は本スキルの対象外とし、プロジェクトの規約・専用スキル・専門プロセスへ委譲します。

- **プロジェクト全体のエラーハンドリング方針**（エラー分類・例外階層・ログフォーマット等）→ steering ドキュメント / 専用スキル
- **コーディング規約**（命名・lint・フォーマッタ・ディレクトリ構成等）→ steering ドキュメント / 専用スキル
- **テスト規約**（テストピラミッド・命名・カバレッジ要件・E2E方針等）→ steering ドキュメント / 専用スキル
- **セキュリティ・プライバシー審査**（個人情報・機密データの外部API送信の可否、越境データ移転、DPA締結、ベンダーの学習利用ポリシー確認）→ セキュリティレビュー・法務/コンプライアンス
- **評価データセットの作成・ラベリング**（作成タスクの起票は行うが、ラベリングガイドライン・複数人アノテーション・一致率確保等の方法論と品質管理）→ データ整備プロセス
- **PoC・負荷試験の実施**（負荷試験の設計、レイテンシ・スループット実測の実行）→ 性能試験スキル / SRE
- **本番運用の定常業務**（監視タスクの設計は行うが、アラート対応、ドリフト監視に基づく閾値の定期再較正の実行）→ SRE / MLOps 運用プロセス
- **リリース戦略**（shadow mode → canary → 全量展開の段階的ロールアウト、ロールバック手順）→ リリース管理プロセス
- **ベンダー契約・調達**（APIキー発行・契約・SLA交渉・請求管理）→ 調達・情シス

規約関連はプロジェクトの steering ドキュメント（Kiro steering / cc-sdd / AGENTS.md / .cursor/rules 等）を参照し、未整備の場合は推測で作成せず**未決事項として報告**した上で、専用スキル（コーディング規約・テスト設計等）での整備を促してください。

---

## 入力契約（Input Contract）

エージェントは以下の情報が揃っていることを確認してから設計を開始します。不足している場合は勝手に推測せず、未決事項として報告します。

1. **承認済み候補**: `decision: approved` となっている候補（Requirement ID、なければ安定した見出し。行番号は用いない）
2. **プロジェクト技術スタック**:
   - 言語・ランタイム（TypeScript, Python, Go 等）
   - フレームワークおよび既存の外部APIクライアント・エラー処理慣習
   - 公式SDK（JS/TS: `@typesafe-ai/sdk`、Python: `typesafe-sdk`、その他: HTTP API契約）の利用可否
3. **リスク区分 & ADR方針**:
   - 不可逆・高リスク（決済・BAN・権限）か、中低リスク（UI・トリアージ）か
   - ADR の作成要否
4. **プロジェクト規約の所在**: エラーハンドリング方針・コーディング規約・テスト規約を定めた steering ドキュメント（Kiro steering / cc-sdd / AGENTS.md / .cursor/rules 等）。未整備の場合は未決事項として報告する（スコープ境界参照）。

---

## 実行ワークフロー

1. **プロジェクト環境 & 技術スタックの検出**
   - `package.json`, `pyproject.toml`, `tsconfig.json` などを確認し、プロジェクトの規約に合わせた実装形式を選択する（TypeScript非採用プロジェクトの場合は勝手にTSコードにせず、対象スタックまたは言語非依存のAPI契約を提示する）。
   - エラーハンドリング・コーディング・テスト規約は steering ドキュメントを参照し、未整備の場合は推測で作成せず未決事項として報告する（スコープ境界参照）。

2. **適切なプリミティブの選定 & スキーマ設計**
   - **`Choice`**: 排他選択肢（Instructions + 各Criteria）
   - **`Score`**: 順序尺度（レベル定義）
   - **`Noul`**: Yes/No 命題確率
   - 問い（instructions / criteria / state）の中身の設計は `references/jev-design-patterns.md` §2 の設計原則（1プリミティブ1問、MECE、脱出選択肢、行動アンカー、state の必要十分性等）に従い、要件原文とのトレーサビリティを確保する。サンプルコードの問い文をそのまま転用しない。

3. **閾値設計 & 3段階ハンドリングの実装**
   - 固定の決め打ち（0.95等）を排し、評価データセットに基づく閾値決定プロセスを前提とする。
   - `Noul` の場合は Dual Threshold（$p \ge \text{high}$ でBlock、$p \le \text{low}$ でAllow、中間帯はReview/エスカレーション）を設計する。
   - 設計書の表とコード例の分岐ロジックが**完全に一致**していることを担保する。

4. **耐障害性（Production Resilience）の組み込み**
   - タイムアウト・外側絶対Deadline（プロジェクトSLOから導出）
   - 429/5xx の限定リトライ
   - 外部障害・Deadline超過時の Safe Default（安全側への縮退）

5. **成果物の出力**
   - `templates/jev-logic-spec-template.md` に従い、`design.md` / ADR 用の設計ブロック、および `tasks.md` 向けの実装・評価・監視タスクを出力する。
