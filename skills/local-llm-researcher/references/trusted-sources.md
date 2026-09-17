# 信頼できる裏取りリソース一覧 (Trusted Sources)

## 1. モデルリポジトリ・モデルカード
- **Hugging Face Hub**: `https://huggingface.co/models`
  - 確認項目: Model Card, Files and versions (fp16/bf16/GGUF/AWQ), License, base_model, config.json (`max_position_embeddings`, `vocab_size`)
- **Ollama Library**: `https://ollama.com/library`
  - 確認項目: 動作確認済みタグ、量子化バリアント（q4_k_m, q8_0等）の推奨サイズ

## 2. 客観的リーダーボード & 評価基盤
- **LMSYS Chatbot Arena**: `https://chat.lmsys.org/?leaderboard`
  - 人手評価によるEloレーティング（Overall, Coding, Japanese, Hard Prompts）
- **Open LLM Leaderboard v2**: `https://huggingface.co/spaces/open-llm-leaderboard/open_llm_leaderboard`
  - MMLU-Pro, MuSR, IFEval, GPQA, MATH
- **Berkeley Function Calling Leaderboard (BFCL)**: `https://gorilla.cs.berkeley.edu/leaderboard.html`
  - ツール呼び出し・関数呼び出しの追従性・正確性
- **LiveCodeBench / SWE-bench**: `https://livecodebench.github.io/leaderboard.html`
  - 汚染のない最新コーディングベンチマーク、現実のGitHub PR解決能力

## 3. 日本語特化評価
- **Nejumi Leaderboard (Weights & Biases Japan)**
- **JP Language Model Evaluation Harness**
- トークナイザー効率（Byte Fallbackの有無、日本語1文字あたりのトークン数比率）
