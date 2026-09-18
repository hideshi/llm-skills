# LLM Skills (LLM選定・裏取り & Jev設計スキル群)

以下の2つのスキル群からなるエージェントスキル集です。

1. **LLM選定・裏取り**: 目的やシステム要件に応じて、客観的な外部ベンチマークや最新モデルカードの裏取りを行った上で、最適なLLM（主にローカルLLM）を提案
2. **Jev (System One Model) 設計**: 要件定義書やドメインモデルから決定特化型モデル「Jev」の適用候補を抽出し、期待TCO試算から型安全な設計仕様までを生成

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
| **`jev-candidate-detector`** | Kiro/cc-sddの仕様書（`requirements.md` / `design.md` / `tasks.md`）を主資料とし、ドメインモデル・ユースケース・画面/API/テーブル設計等で補完してJev適用候補を検出、期待TCOとレイテンシを試算 | 最新の公式価格、実測レイテンシ、業務・上位成果物への影響 |
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

---

## 利用上の注意

- **非公式スキル**: 本リポジトリは TypeSafe AI 社および各LLMベンダーとは無関係の**非公式**スキル集です。仕様・価格・SDKの最新情報は必ず各社の公式ドキュメントを参照してください。
- **数値はすべて参考値**: スキル内の価格・レイテンシ等の数値は調査日時点の参考値です。見積もりや設計判断の際は最新の一次情報を確認し、**Jev の利用に際しては利用者が必ず事前に自環境での実測（PoC）を行ってください**。
- **日本語のみ**: 本スキル集は日本語での利用を想定しています。

## リポジトリポリシー

- 本リポジトリには**汎用的なスキルのみ**を配置し、特定プロジェクト固有の情報（要件定義書、解析レポート出力、社内情報等）は含めません。

---

## 免責事項 (Disclaimer)

- 本リポジトリで提供されるスキル、プロンプト、計算式、およびコードテンプレートは、現状有姿（AS-IS）で提供されます。
- 本スキルの利用・実行、および提示された提案や生成コードの導入・運用によって生じた直接的・間接的な損害（API課金費用の増大、システムの障害・停止、セキュリティ上のインシデント、データの損失等）について、作者およびコントリビューターは一切の責任を負いません。
- **本スキルの利用はすべて利用者ご自身の自己責任において行ってください。** 特に本番環境への導入前には、実測値に基づく性能・コストの検証、セキュリティレビュー、および十分なテストを実施してください。

---

## ライセンス (License)

本リポジトリは [MIT License](LICENSE) のもとで公開されています。
