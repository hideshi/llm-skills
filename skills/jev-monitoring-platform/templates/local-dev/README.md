# ローカル開発コンテナ（例）

## 目的
- Worker ＋ Miniflare／Wrangler が模せるバインディング程度を、**1コンテナ（1プロセス系統）**で再現する。
- コンポーネント試験・合成リクエストの煙テスト用。

## 含めない（別経路）
- Analytics Engine の本番相当クエリ／保持
- Access 等の本番認証の完全再現（必要ならモック IdP を compose で追加）
- 本番データ・本番 Secrets

## 分け方の方針
- ローカルで一緒に動く単位はまとめる。
- プロセスとして独立するもの（モック IdP、別言語 API、D1 以外の DB など）だけサービスを足す。

## 使い方（概要）
1. 本ディレクトリを案件リポへコピーする。
2. `Dockerfile.example` / `docker-compose.example.yml` のパス・Node／Wrangler 版を案件に合わせる（公式ドキュメントで確認）。
3. `docker compose up --build` などで起動し、合成リクエストで取り込み→索引を確認する。
