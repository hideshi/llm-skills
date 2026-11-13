# LLM Skills (LLM選定・裏取り、時代考証、Jev設計、エージェント連携の実装 & 振り返りのスキル群)

以下の5つのスキル群からなるエージェントスキル集です。

1. **LLM選定・裏取り**: 目的やシステム要件に応じて、客観的な外部ベンチマークや最新モデルカードの裏取りを行った上で、最適なLLM（主にローカルLLM）を提案
2. **Jev (System One Model) 設計**: 要件定義書やドメインモデルから決定特化型モデル「Jev」の適用候補を抽出し、期待TCO試算から型付きのJevスキーマ・フォールバック設計、評価セット freeze、閾値較正（shadow 記録まで）を支援
3. **歴史・文化背景の裏取り**: 人物や制度の判断を史料・研究と照合し、出来事の記録、当時や後世の評価、創作上の仮定を分ける。歴史的な振る舞いの評価やシミュレーション設計に利用
4. **エージェント連携の実装**: 既存のWebアプリにMCPサーバーを組み込み、HTTPでエージェントに公開する際の要件定義・設計・実装・試験を、言語・SDKに依存せず支援
5. **会話の一区切りの振り返り**: コーディングの会話の区切りで、摩擦を専門用語と情報処理技術者試験（基本情報から高度試験まで）の概念につなげ、利用者の個人用スキルを育てるかを判定

**Cursor, Claude Code, Antigravity, Codex** のマルチツールに対応しています。

---

## ディレクトリ構成

```text
llm-skills/
├── README.md
│
├── skills/                                    # [本体] スキル実体
│   ├── historical-context-grounding/          # 歴史・文化背景の裏取り（Jev以外でも利用可）
│   │   ├── SKILL.md
│   │   ├── references/source-workflows.md      # 資料の取得・判定の手順と記録
│   │   └── agents/openai.yaml
│   ├── model-requirements-analyzer/           # 1. 要件定義 & 制約整理
│   │   ├── SKILL.md
│   │   └── templates/requirements-template.md
│   ├── local-llm-researcher/                  # 2. 候補モデル探索 & 外部裏取り
│   │   ├── SKILL.md
│   │   └── references/trusted-sources.md
│   ├── hardware-compatibility-checker/        # 3. VRAM/KV Cache/推論エンジン適合性検証
│   │   ├── SKILL.md
│   │   └── references/vram-calculator-formula.md
│   ├── llm-selection-advisor/                 # 4. 比較レポート & 導入手順の生成
│   │   ├── SKILL.md
│   │   └── templates/evaluation-report-template.md
│   ├── jev-candidate-detector/                # 5. [Jev] ドメイン/要件からの候補抽出 & コスト試算
│   │   ├── SKILL.md
│   │   ├── references/cost-estimation-reference.md
│   │   └── templates/jev-candidate-report-template.md
│   ├── jev-logic-architect/                   # 6. [Jev] 詳細設計(design.md)向けスキーマ & フォールバック設計
│   │   ├── SKILL.md
│   │   ├── references/jev-design-patterns.md
│   │   └── templates/jev-logic-spec-template.md
│   ├── jev-eval-set/                          # 7. [Jev] 評価セット整備 & freeze
│   │   ├── SKILL.md
│   │   ├── references/sampling-and-leakage-guide.md
│   │   └── templates/jev-eval-set-report-template.md
│   ├── jev-calibration/                       # 8. [Jev] 閾値較正 & validationStatus / shadow 記録
│   │   ├── SKILL.md
│   │   ├── references/evaluation-metrics.md
│   │   └── templates/jev-calibration-report-template.md
│   ├── jev-observability/                     # 9. [Jev] 監視設計（観測契約）
│   │   ├── SKILL.md
│   │   ├── references/decision-event-contract.md
│   │   └── templates/jev-observability-spec-template.md
│   ├── jev-monitoring-platform/               # 10. [Jev] 監視基盤要件（CF既定・他クラウド写像）
│   │   ├── SKILL.md
│   │   ├── references/cloud-provider-remap.md
│   │   ├── references/testing-and-local-dev.md
│   │   ├── templates/jev-monitoring-platform-spec-template.md
│   │   └── templates/local-dev/                 # Dockerfile / compose 例
│   ├── jev-shared/                            # [Jev] 共有語彙・定形結果レポート
│   │   ├── references/jev-lifecycle-status.md
│   │   ├── references/judgment-input-and-sensitivity.md
│   │   ├── references/historical-judgment-evaluation.md
│   │   └── templates/jev-pipeline-result-report-template.md
│   ├── app-mcp-server-integration/            # アプリに組み込むMCPサーバー（要件・設計・実装・試験）
│   │   ├── SKILL.md
│   │   ├── references/                        # 要件・認可・書き込みの安全・実装・試験・仕様の追従
│   │   └── agents/openai.yaml
│   └── post-task-retrospective/               # 会話の一区切りの振り返り（用語化・個人用スキルの判定）
│       ├── SKILL.md
│       ├── references/                        # 試験の概念へのつなぎ方・導入・改善PRの手順
│       └── agents/openai.yaml
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
| **`jev-candidate-detector`** | Kiro/cc-sddの`requirements.md`または同等の要件定義書を一次資料とし、`design.md` / `tasks.md`、ドメインモデル・ユースケース・画面/API/テーブル設計等で補完してJev適用候補を検出、期待TCOとレイテンシを試算 | 最新の公式価格、実測レイテンシ、業務・上位成果物への影響 |
| **`jev-logic-architect`** | 選定された候補を詳細設計（`design.md`）やタスク（`tasks.md`）に落とし込み、TypeScript型定義、Jevスキーマ、確信度（Confidence）別フォールバックコードを設計 | RLCD（校正済み確信度）アーキテクチャパターン |
| **`jev-eval-set`** | 承認済み設計に対し、正解定義・サンプリング/リーク防止・`datasetVersion`・freeze 記録を整え `datasetStatus: frozen` にする | 共有語彙 `jev-shared`、実験リポ上の評価成果物 |
| **`jev-calibration`** | frozen セット上で閾値を較正し、バッチ評価要約・推奨閾値・`validationStatus`・shadow 記録（本番非適用）を出す。区切り到達時は定形結果レポート必須 | ゲート基準はプロジェクト入力、定形レポートは `jev-shared/templates` |
| **`jev-observability`** | 判定イベント・時系列メトリクス・アラート意図・保持/プライバシー境界の観測契約を設計する（実装はしない） | 目標値はプロジェクト入力、実装は SRE/MLOps |
| **`jev-monitoring-platform`** | 観測契約を監視インフラ／監視アプリ要件に落とす。既定 Cloudflare、AWS/GCP/Azure 写像 | 制限値は出典付き裏取り／入力。実装は SRE/MLOps |

### 3. 歴史・文化背景の裏取り

| スキル名 | 責務・役割 | 主な参照・裏取りリソース |
| :--- | :--- | :--- |
| **`historical-context-grounding`** | 歴史上の人物・制度・道義に関わる判断の根拠を確認し、競合する規範、適用範囲、未確認点を整理する | 原史料の本文・注・評、信頼できる翻訳・校注、学術研究 |

時代考証はJevと独立して利用できる。史料の読み分けは `historical-context-grounding`、資料の取得・採用判定は利用者や案件が指定する手順（指定がなければ同スキルの[基本手順](skills/historical-context-grounding/references/source-workflows.md)）、Jevの入力・評価は[歴史的文脈を含む判断の設計と評価](skills/jev-shared/references/historical-judgment-evaluation.md)が担当する。

Jevの人物判断では `jev-logic-architect`、`jev-eval-set`、`jev-calibration` から必要な手順だけを参照する。個別案件の調査・実測はこのリポジトリに置かない。責務と保守範囲は[時代考証スキルの責務](docs/skill-responsibilities.md)を参照。

### 4. エージェント連携の実装

| スキル名 | 責務・役割 | 主な参照・裏取りリソース |
| :--- | :--- | :--- |
| **`app-mcp-server-integration`** | 既存のWebアプリに組み込み、HTTPで公開するMCPサーバーについて、読み取りと書き込みの分離、機能ごとの有効・無効、ロールによる絞り込み、リソースサーバーとしての認可、書き込み前の利用者の確認を、不変条件と試験の対応表で設計・検証する | MCP公式仕様（使う前に版と変更履歴を確認）、OAuth関連のRFC |

MCPクライアントの実装、既存のMCPサーバーを使うだけの作業、stdio のサーバーの認可は対象外。仕様の版ごとの仕組みの違いは同スキルの[仕様の追従](skills/app-mcp-server-integration/references/spec-tracking.md)で確かめる。

### 5. 会話の一区切りの振り返り

| スキル名 | 責務・役割 | 主な参照・裏取りリソース |
| :--- | :--- | :--- |
| **`post-task-retrospective`** | 利用者が結果を受け入れた・作業を区切った・振り返りを頼んだときに一度だけ振り返り、摩擦を専門用語にし、個人用スキルを update / new-thin / discard（既定）で判定する。必要なら次の進め方か新しい技術を一つ示す | IPAの試験要綱・シラバス（基本情報、応用情報、高度試験、情報処理安全確保支援士。使う時点の現行版を確認） |

開発リポジトリへ導入して使う。振り返りのメモやそこから作るスキルは、このリポジトリにも導入したコピーにも書かず、利用者の個人用スキルリポジトリに置く。導入方法は同スキルの[導入ガイド](skills/post-task-retrospective/references/installation.md)を参照。

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
- スキルの実行で生まれた成果物（振り返りメモ、個人用スキル等）は、このリポジトリへ書き込みません。スキル自体の改善の変更・PRは歓迎します。

---

## 免責事項 (Disclaimer)

- 本リポジトリで提供されるスキル、プロンプト、計算式、およびコードテンプレートは、現状有姿（AS-IS）で提供されます。
- 本スキルの利用・実行、および提示された提案や生成コードの導入・運用によって生じた直接的・間接的な損害（API課金費用の増大、システムの障害・停止、セキュリティ上のインシデント、データの損失等）について、作者およびコントリビューターは一切の責任を負いません。
- **本スキルの利用はすべて利用者ご自身の自己責任において行ってください。** 特に本番環境への導入前には、実測値に基づく性能・コストの検証、セキュリティレビュー、および十分なテストを実施してください。

---

## ライセンス (License)

本リポジトリは [MIT License](LICENSE) のもとで公開されています。
