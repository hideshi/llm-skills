# クラウドプロバイダ写像（監視基盤・参考）

本表は **役割の読み替え候補** である。同一機能の保証ではない。制限・価格・保持・認証の詳細は各クラウドの公式ドキュメントまたは専用サーベイで裏取りする。

既定バインディングは **Cloudflare**。他列は「近い役割の出発点」。

| 役割（中立） | Cloudflare（既定の出発点） | AWS | GCP | Azure |
| :--- | :--- | :--- | :--- | :--- |
| 取り込み・軽量コンピュート／Cron | Workers（Cron Triggers 含む） | Lambda ＋ EventBridge Scheduler | Cloud Functions / Cloud Run ＋ Cloud Scheduler | Azure Functions ＋ Timer |
| 時系列メトリクス | Analytics Engine | CloudWatch Metrics / AMP | Cloud Monitoring | Azure Monitor Metrics |
| 索引・メタ・小規模 SQL | D1 | DynamoDB / RDS（小） / Timestream 併用は案件次第 | Firestore / Cloud SQL | Cosmos DB / Azure SQL |
| オブジェクト・長期ログ | R2（後段） | S3 | Cloud Storage | Blob Storage |
| キュー／非同期 | Queues / Workflows（後段） | SQS / Step Functions | Pub/Sub / Workflows | Service Bus / Logic Apps |
| 監視 UI（静的＋API） | Pages ＋ Worker API | Amplify / S3+CloudFront ＋ API Gateway | Firebase Hosting / Cloud Run UI | Static Web Apps ＋ APIM |
| 認証・認可（IdP／アプリ認可） | Access（候補） | IAM Identity Center / Cognito ＋ アプリ認可 | IAP / Identity Platform | Entra ID ＋ App Service Auth |
| 秘密 | Secrets / バインディング | Secrets Manager | Secret Manager | Key Vault |
| 強状態・単一ライター | Durable Objects（後段・要慎重） | 専用ストア＋ロック設計 | 同上 | 同上 |

## 使い方
1. 中立コアの各役割を埋めてから、既定列（CF）を仮置きする。
2. 他クラウドを本命／バックアップにする場合だけ、該当行を案件表に転記し差分を書く。
3. 「AE の保持日数」などベンダー固有値はここに焼かず、サーベイ結果を参照する。
