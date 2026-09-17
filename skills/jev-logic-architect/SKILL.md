---
name: jev-logic-architect
description: Transforms identified business decisions into concrete, type-safe Jev schemas, confidence-based fallback flows, and stack-adaptive code designs (TS/Python/HTTP) ready for SDD design.md and tasks.md.
---

# Jev Logic Architect

このスキルは、前段の `jev-candidate-detector` で承認（`decision: approved`）された業務判断ポイント、およびプロジェクトの技術スタックを入力とし、**仕様駆動開発（Kiro/cc-sdd等）の設計書（`design.md`）、ADR、およびタスク分解（`tasks.md`）にそのまま組み込める堅牢な技術仕様**（TypeSafe公式SDKコード、3プリミティブ定義、実証的閾値設計、耐障害フォールバック）を生成します。

必ず事前に `references/jev-design-patterns.md` を精読して設計パターンを把握した上で実行してください。

---

## 入力契約（Input Contract）

エージェントは以下の情報が揃っていることを確認してから設計を開始します。不足している場合は勝手に推測せず、未決事項として報告します。

1. **承認済み候補**: `decision: approved` となっている候補（Requirement ID、対象ドキュメント位置）
2. **プロジェクト技術スタック**:
   - 言語・ランタイム（TypeScript, Python, Go 等）
   - フレームワークおよび既存の外部APIクライアント・エラー処理慣習
   - 公式SDK（JS/TS: `@typesafe-ai/sdk`、Python: `typesafe-sdk`、その他: HTTP API契約）の利用可否
3. **リスク区分 & ADR方針**:
   - 不可逆・高リスク（決済・BAN・権限）か、中低リスク（UI・トリアージ）か
   - ADR の作成要否

---

## 実行ワークフロー

1. **プロジェクト環境 & 技術スタックの検出**
   - `package.json`, `pyproject.toml`, `tsconfig.json` などを確認し、プロジェクトの規約に合わせた実装形式を選択する（TypeScript非採用プロジェクトの場合は勝手にTSコードにせず、対象スタックまたは言語非依存のAPI契約を提示する）。

2. **適切なプリミティブの選定 & スキーマ設計**
   - **`Choice`**: 排他選択肢（Instructions + 各Criteria）
   - **`Score`**: 順序尺度（レベル定義）
   - **`Noul`**: Yes/No 命題確率

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
