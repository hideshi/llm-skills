---
name: local-llm-researcher
description: Researches candidate LLMs (primarily local open-weight models), benchmarks, and evidence across trusted external sources (Hugging Face, Arena, papers, GitHub).
---

# Local LLM Researcher

このスキルは、定義された要件に基づいて最新のLLM（オープンウェイト/ローカルLLM中心）を探索し、信頼できる外部リソース（Hugging Face、Chatbot Arena、論文、GitHub Issues等）で**事実関係の裏取り**を行います。

## 行動規範・グラウンディング原則

1. **推測値やハルシネーションの禁止**
   - パラメータ数、対応コンテキスト長、ベンチマークスコア、ライセンスは**必ず公式ドキュメントや信頼できるソースで実確認**する。
   - 存在しない架空のモデル名や不確かなスコアを提示してはならない。
2. **多角的ソースによる裏取り**
   - 以下の「信頼できる情報源」を必ず参照・引用する:
     - **Hugging Face Model Card**: 正式なアーキテクチャ、コンテキスト長、語彙数、ライセンス。
     - **LMSYS Chatbot Arena / Arena-Hard**: 総合的な実対話性能やCoding/Japaneseのイロレーティング。
     - **Open LLM Leaderboard (Hugging Face)**: MMLU-Pro, IFEval, GSM8k などの標準評価。
     - **タスク特化ベンチマーク**:
       - コーディング: SWE-bench, HumanEval, LiveCodeBench
       - エージェント/ツール利用: BFCL (Berkeley Function Calling Leaderboard)
       - 日本語性能: JP Language Model Evaluation Harness, Rakuda, JMT-Bench
     - **GitHub / コミュニティ報告**: 特定量子化での精度劣化、日本語トークナイザの効率、既知の不具合。

## 実行ワークフロー

1. **候補モデルの絞り込み (3〜5モデル)**
   - 要件の「パラメータ規模」「タスク」「日本語要求」に合致する最新・有力モデルをリストアップ。
   - （例: Qwen 2.5 系列, Llama 3.1 / 3.3 系列, Gemma 2 系列, Mistral / Command R 系列, 日本語特化モデルなど）

2. **裏取り調査の実施**
   - 各モデルについてWeb検索や Hugging Face API を用いて最新情報を確認。
   - 以下の情報を明記する:
     - 正確なモデルID（例: `Qwen/Qwen2.5-Coder-32B-Instruct`）
     - ライセンス
     - 公式ネイティブコンテキスト長
     - 主なベンチマーク実績値
     - コミュニティでの評判・特筆すべき強み・弱み

3. **リサーチ結果の整理**
   - 各モデルの裏取りURL・引用元を付記した構造化データを後続の `hardware-compatibility-checker` および `llm-selection-advisor` に引き渡す。
