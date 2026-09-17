---
name: llm-selection-advisor
description: Synthesizes requirements, external research benchmarks, and hardware constraints to generate a final grounded recommendation report with actionable setup instructions.
---

# LLM Selection Advisor

このスキルは、前段の要件分析、外部ベンチマーク裏取り、ハードウェア適合性判定を統合し、ユーザーのシステムに最も適したLLMの**選定提案レポート**を作成します。

## 提案作成の原則

1. **多段階の選択肢（トレードオフの明示）**
   単一モデルの押し付けではなく、以下の観点で提示する:
   - **本命（Best Balance）**: 性能、精度、ハードウェア適合性のバランスが最も優れているモデル。
   - **軽量・高速版（Fast / Low-Resource）**: VRAMやレイテンシを最優先し、低コスト/低遅延で動くモデル。
   - **拡張・高精度版（High Capability / Cloud/Hybrid）**: より大規模なモデルやクラウドAPIとの併用案。
2. **裏取り根拠の完全明示**
   - 推奨理由には「ベンチマークスコア」「利用者の実績評価」「公式仕様」のURL/出典を必ず併記する。
3. **即時試行可能な手順（Actionable Guide）**
   - Ollama, vLLM, または llama.cpp での具体的な起動コマンド・設定例を提示する。

## 出力フォーマット

`templates/evaluation-report-template.md` の書式に従って、Markdown形式でレポートを出力する。
