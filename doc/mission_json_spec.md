# 📘 **C. Mission JSON 正式仕様（v1）**

この仕様は他の開発者がミッションを追加できるようにする公式仕様書として利用できます。
最終的には `/docs/mission_json_spec.md` に格納していきます。

---

# Mission JSON Format Specification

**Version:** 1.0
**Status:** Draft
**Author:** pekokana（プロジェクトオーナー）
**Editor:** pekokana（アシスタント）

---

## 1. Overview

Mission JSON は、CTF体験アプリにおける **ミッション環境（サーバー、ネットワーク、ユーザーFS、ゴール）** を定義するための JSON 文書である。本仕様に準拠することにより、アプリケーションはミッション環境を自動構築することができる。

---

## 2. Top-level structure

Mission JSON は以下のトップレベルキーを含む。

| key               | type    | required | description |
| ----------------- | ------- | -------- | ----------- |
| `mission_id`      | string  | ✓        | 一意のミッション識別子 |
| `title`           | string  | ✓        | ミッション名      |
| `description`     | string  | ✓        | 説明文         |
| `difficulty`      | integer | ✓        | 1〜5         |
| `user_filesystem` | object  | ✓        | 実行ユーザ用仮想FS  |
| `servers`         | array   | ✓        | サーバー群       |
| `network_devices` | array   | optional | ルーター/スイッチ等  |
| `goals`           | object  | ✓        | フラグなどのゴール条件 |

---

## 3. User Filesystem Specification

### Structure

```json
"user_filesystem": {
  "root": "/",
  "files": [
	{ ... file object ... }
  ]
}
```

### File Object Format

| field       | type   | required | description                        |
| ----------- | ------ | -------- | ---------------------------------- |
| `path`      | string | ✓        | 絶対パス                               |
| `type`      | string | ✓        | `text`, `log`, `pcap`, `binary` など |
| `content`   | string | optional | テキスト or Base64（バイナリ）               |
| `generator` | object | optional | 自動生成ルール（ノイズ生成等）                    |

※ `generator` は後続ステップで拡張される。

---

## 4. Server Specification

### Structure

```json
{
  "id": "web01",
  "type": "web",
  "filesystem": { ... },
  "network": { ... }
}
```

### Fields

| field        | type   | required | description                   |
| ------------ | ------ | -------- | ----------------------------- |
| `id`         | string | ✓        | サーバーID                        |
| `type`       | string | ✓        | サーバー種別。例：`web`, `app`, `file` |
| `filesystem` | object | ✓        | サーバー内部のFS定義                   |
| `network`    | object | ✓        | NICやポートの設定                    |

---

## 5. Network Definition

### Network Object

```json
"network": {
  "interfaces": [ ... ]
}
```

### Interface Object

| field   | type            | required | description |
| ------- | --------------- | -------- | ----------- |
| `name`  | string          | ✓        | インタフェース名    |
| `ip`    | string or array | optional | IPアドレス（複数可） |
| `ports` | array           | optional | 監視/待ち受けポート  |

---

## 6. Network Device Specification

```json
{
  "id": "router1",
  "type": "router",
  "interfaces": [
	{ "name": "ge0/0", "ip": "10.0.0.1", "vlan": 10 }
  ]
}
```

---

## 7. Goal Specification

```json
"goals": {
  "flag": "FLAG{something}"
}
```

#### 今後の拡張

* 複数フラグ
* スコア式
* 条件複数指定

---

## 8. Validation Rules (概要、詳細はステップA)

* `mission_id` は必須かつユニーク
* `servers[].id` は全体でユニーク
* すべての `path` は `/` から始まる
* ポート番号は 1〜65535
* IP アドレスは IPv4 のみ対応（v1.0）
* `files[].type` は登録された型のみ可
* `generator` の型は別途仕様で定義

---

## 9. Example (minimal)

```json
{
  "mission_id": "sample01",
  "title": "Intro to Web",
  "description": "Webサーバー探索",
  "difficulty": 1,

  "user_filesystem": {
	"root": "/",
	"files": [
	  { "path": "/home/user/readme.txt", "type": "text", "content": "hello" }
	]
  },

  "servers": [
	{
	  "id": "web01",
	  "type": "web",
	  "filesystem": {
		"root": "/",
		"files": [
		  { "path": "/var/www/html/index.html", "type": "text", "content": "<h1>hi</h1>" }
		]
	  },
	  "network": {
		"interfaces": [
		  { "name": "eth0", "ip": "10.0.0.10", "ports": [80] }
		]
	  }
	}
  ],

  "goals": {
	"flag": "FLAG{hello}"
  }
}
```
