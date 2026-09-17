---
name: model-requirements-analyzer
description: Analyzes system goals and requirements to define target constraints for LLM selection (tasks, language, latency, privacy, budget, hardware context).
---

# Model Requirements Analyzer

このスキルは、システムで実現したい目的やユースケースをヒアリング・分析し、最適なLLM（主にローカルLLM）を選定するための**前提条件・要件定義シート**を作成します。

## 実行ワークフロー

1. **目的・タスク分類のヒアリング/特定**
   - 主なタスク種別を特定する:
     - コーディング支援 / リポジトリ解析
     - RAG (Retrieval-Augmented Generation) / ドキュメントQA
     - エージェント / Tool Calling (Function Calling)
     - 構造化データ抽出 (JSON Mode / Schema Enforcing)
     - 要約・翻訳・一般的な対話
   - 入出力特性:
     - 必要なコンテキスト長（8k, 32k, 128k 等）
     - 想定出力トークン数
     - 日本語処理能力の重要度（最優先 / 英語中心 / 多言語）

2. **非機能要件 & 制約条件の抽出**
   - **プライバシー・コンプライアンス**:
     - 完全オンプレミス・オフライン必須か
     - 商用利用ライセンス（Apache 2.0, MIT, Llama 3 Community License等）の許容範囲
   - **レイテンシ & スループット**:
     - リアルタイム性重視（Time-To-First-Token < 1s, > 30 tokens/sec）か
     - バッチ処理・非同期実行か
   - **実行環境（ハードウェア）**:
     - ターゲットマシンのGPU（VRAM容量、台数）、CPU、RAM仕様
     - 運用形態（常駐型サービス、CLIオンデマンド実行等）

3. **要件定義書の出力**
   - `templates/requirements-template.md` のフォーマットに従い、要件定義書を出力する。
   - 後続の `local-llm-researcher` や `hardware-compatibility-checker` に引き渡す。
