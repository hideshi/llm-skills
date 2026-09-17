---
name: jev-logic-architect
description: Transforms identified business decisions into concrete, type-safe Jev schemas, confidence-based fallback flows, and TypeScript code designs ready for SDD design.md and tasks.md.
---

# Jev Logic Architect

このスキルは、前段の `jev-candidate-detector` や要件定義で選定された業務判断ポイントを入力とし、**仕様駆動開発（Kiro/cc-sdd等）の設計書（`design.md`）やタスク分解（`tasks.md`）にそのまま組み込める具体的な技術仕様**（TypeScript型、Jevスキーマ、確信度閾値、フォールバックフロー）を生成します。

## 実行ワークフロー

1. **対象ロジック & コンテキストの読み込み**
   - 採用決定された候補ロジック、およびプロジェクトの既存設計書（`design.md` や `server/` / `src/` 配下の既存コード・型定義）を把握する。

2. **型安全（Type-Safe）な Jev スキーマの設計**
   - 出力されるEnum、Boolean、または数値スコアを厳格に定義。
   - 例:
     ```typescript
     const ModerationSchema = {
       decision: ['allow', 'review', 'block'],
       reason: ['none', 'hate_speech', 'harassment', 'spam'],
     } as const;
     ```

3. **確信度（Confidence）とフォールバックの設計**
   - 業務のクリティカル度（セキュリティ・決済・UX）に応じた閾値を設定:
     - **高確信（Automated）**: そのまま自動分岐して後続処理。
     - **中確信（Degraded/Check）**: 確認プロンプトや安全側へのフォールバック。
     - **低確信（Escalated）**: 高精度な大型生成LLM（Claude/GPT）による詳細推論、または人間オペレーターへのエスカレーション。

4. **成果物の出力**
   - `templates/jev-logic-spec-template.md` に従って、`design.md` に追記可能な Markdown 設計ブロックと `tasks.md` 向けのタスクリストを出力する。
