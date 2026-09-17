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
│   ├── jev-candidate-detector/                # 5. [Jev] ドメイン/要件からの候補抽出 & コスト試算
│   │   ├── SKILL.md
│   │   ├── references/cost-estimation-reference.md
│   │   └── templates/jev-candidate-report-template.md
│   └── jev-logic-architect/                   # 6. [Jev] 詳細設計(design.md)向けスキーマ & フォールバック設計
│       ├── SKILL.md
│       ├── references/jev-design-patterns.md
│       └── templates/jev-logic-spec-template.md
│
├── .cursor/skills/                            # Cursor 向け (symlink)
├── .claude/skills/                            # Claude Code 向け (symlink)
├── .agent/skills/                             # Antigravity 向け (symlink)
└── codex/skills/                              # Codex 向け (symlink)
```

---

## スキル一覧 & 責務

### 1. LLM 選定 & 外部裏取りスキル群
| スキル名 | 責務・役割 | 主な参照・裏取りリソース |
| :--- | :--- | :--- |
| **`model-requirements-analyzer`** | システム要件、タスク分類（コーディング/RAG/エージェント）、言語要件、ライセンス、レイテンシ、ハードウェア前提のヒアリングと定義 | システム要求仕様、コンプライアンス要件 |
| **`local-llm-researcher`** | 最新のモデル候補抽出、客観的ベンチマーク値（Leaderboard、実測値）の調査、既知の課題等の裏取り | Hugging Face (Model Cards), LMSYS Arena, BFCL, LiveCodeBench |
| **`hardware-compatibility-checker`** | パラメータ規模、コンテキスト長、KV Cache、量子化（GGUF, AWQ等）のメモリ計算と推論エンジン選定 | VRAM計算式、vLLM / Ollama / llama.cpp の仕様 |
| **`llm-selection-advisor`** | 上記を統合し、本命案・軽量案・拡張案の比較マトリクスと起動コマンドを含む提案レポートを作成 | 総合評価レポートテンプレート |

### 2. Jev (System One Model) アーキテクチャ設計スキル群
| スキル名 | 責務・役割 | 主な参照・裏取りリソース |
| :--- | :--- | :--- |
| **`jev-candidate-detector`** | ドメインモデル（`domain-model.md`）や要件定義書（`requirements.md`）をスキャンし、Jev適用候補をアタリ付け＆月間コスト/速度比較を試算 | Jev価格仕様（出力$0）、GPT-4o-mini等との比較テーブル |
| **`jev-logic-architect`** | 選定された候補を詳細設計（`design.md`）やタスク（`tasks.md`）に落とし込み、TypeScript型定義、Jevスキーマ、確信度（Confidence）別フォールバックコードを設計 | RLCD（校正済み確信度）アーキテクチャパターン |

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
