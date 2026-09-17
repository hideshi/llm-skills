# LLM Selection Skills (ローカルLLM選定・裏取りスキル群)

目的やシステム要件に応じて、客観的な外部ベンチマークや最新モデルカードの裏取りを行った上で、最適なLLM（主にローカルLLM）を提案するエージェントスキル群です。

**Cursor, Claude Code, Antigravity, Codex** のマルチツールに対応しています。

---

## ディレクトリ構成

```text
llm-skills/
├── README.md
│
├── skills/                                    # [本体] スキル実体
│   ├── model-requirements-analyzer/           # 1. 要件定義 & 制約整理
│   │   ├── SKILL.md
│   │   └── templates/requirements-template.md
│   ├── local-llm-researcher/                  # 2. 候補モデル探索 & 外部裏取り
│   │   ├── SKILL.md
│   │   └── references/trusted-sources.md
│   ├── hardware-compatibility-checker/        # 3. VRAM/KV Cache/推論エンジン適合性検証
│   │   ├── SKILL.md
│   │   └── references/vram-calculator-formula.md
│   └── llm-selection-advisor/                 # 4. 比較レポート & 導入手順の生成
│       ├── SKILL.md
│       └── templates/evaluation-report-template.md
│
├── .cursor/skills/                            # Cursor 向け (symlink)
├── .claude/skills/                            # Claude Code 向け (symlink)
├── .agent/skills/                             # Antigravity 向け (symlink)
└── codex/skills/                              # Codex 向け (symlink)
```

---

## スキル一覧 & 責務

| スキル名 | 責務・役割 | 主な参照・裏取りリソース |
| :--- | :--- | :--- |
| **`model-requirements-analyzer`** | システム要件、タスク分類（コーディング/RAG/エージェント）、言語要件、ライセンス、レイテンシ、ハードウェア前提のヒアリングと定義 | システム要求仕様、コンプライアンス要件 |
| **`local-llm-researcher`** | 最新のモデル候補抽出、客観的ベンチマーク値（Leaderboard、実測値）の調査、既知の課題等の裏取り | Hugging Face (Model Cards), LMSYS Arena, BFCL, LiveCodeBench |
| **`hardware-compatibility-checker`** | パラメータ規模、コンテキスト長、KV Cache、量子化（GGUF, AWQ等）のメモリ計算と推論エンジン選定 | VRAM計算式、vLLM / Ollama / llama.cpp の仕様 |
| **`llm-selection-advisor`** | 上記を統合し、本命案・軽量案・拡張案の比較マトリクスと起動コマンドを含む提案レポートを作成 | 総合評価レポートテンプレート |

---

## 各ツールでの利用方法

### 1. Cursor
`.cursor/skills/` 配下に配置されているため、Agentモードで自動認識されます。
またはチャット欄で `/model-requirements-analyzer` などのように直接呼び出すことも可能です。

### 2. Claude Code
`.claude/skills/` 配下を参照するため、対話内で自動的にタスクに応じたスキルがロードされます。

### 3. Antigravity
`.agent/skills/` 配下を参照し、ワークスペースのスキルとして利用可能です。

### 4. Codex
`codex/skills/` 配下に同期されているプロンプト指示および `SKILL.md` が利用されます。
