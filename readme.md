# CTF Mission Simulator (仮)

CTF（Capture The Flag）の学習・体験を目的とした、仮想ネットワーク環境シミュレーターです。JSON形式の定義ファイル（Mission JSON）を読み込むことで、複雑なサーバー構成やネットワーク、ファイルシステムを動的に構築し、ハッキング・調査体験を提供します。

## 🚀 プロジェクトの目的

従来のCTFは「特定の問題（Web、Pwn等）」を解く形式が多いですが、本アプリは**「ネットワーク全体を探索し、サーバー間の関係性を把握しながらゴールを目指す」**という、より実践的なインフラ調査体験の提供を目指しています。

## 🛠 主な機能（開発中）

* **Mission JSON Interpreter**: JSONベースのミッション定義を解析し、仮想環境をエミュレート。
* **Virtual Filesystem**: ユーザー端末および各サーバー内のディレクトリ構造を独立して管理。
* **Network Simulation**: 複数サーバー、ルーター、スイッチによるサブネット環境の構築。
* **Goal Validation**: フラグ（FLAG{...}）の照合によるクリア判定。

## 📂 構成

* `/src`: アプリケーション本体コード
* `/docs`: 仕様書、マニュアル
* [`mission_json_spec.md`](doc/mission_json_spec.md): Mission JSONの正式仕様書


* `/missions`: ミッションデータのサンプル

## 📄 Mission JSON プレビュー

ミッションは以下のような構造で定義されます：

```json
{
  "mission_id": "intro-01",
  "title": "最初の探索",
  "difficulty": 1,
  "servers": [
    {
      "id": "target-srv",
      "network": {
        "interfaces": [{ "name": "eth0", "ip": "10.0.0.5", "ports": [80] }]
      }
    }
  ],
  "goals": { "flag": "FLAG{hello_world}" }
}

```

## 🛠 セットアップ（開発者向け）

現在、開発の初期段階です。

1. 本リポジトリをクローン:
```bash
git clone https://github.com/pekokana/ctf_gui.git

```


2. 依存関係のインストール:
*(ここに使用言語に合わせたコマンドを記載例：npm install / pip install)*

## 🤝 コントリビューション

1. `/docs/mission_json_spec.md` を確認し、ミッションの定義方法を理解する。
2. Issueを作成して機能提案やバグ報告を行う。
3. プルリクエストを送る。

## 👤 作者

* **pekokana** - プロジェクトオーナー

