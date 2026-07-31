# ecs-gangway

English version: [README_US.md](./README_US.md)

ECS Execで動いているコンテナに、クラスター/サービス/タスク/コンテナを対話的に選びながら乗り込むためのシェルスクリプトです。

`aws ecs execute-command` を毎回打つのは面倒なので、クラスター名やタスクIDを調べる手間を省き、選択肢から選ぶだけで対象コンテナに接続できるようにしています。本番環境に接続する際は確認プロンプトを挟むガードレール付きです。

## 特徴

- クラスター・サービス・タスク・コンテナを `select` で対話的に選択（候補が1つしかない場合は自動決定）
- 環境名（`prod` / `stg` など）でクラスター・サービスを絞り込み可能
- 本番環境（`prd` / `prod` を含む名前）に接続する際は、確認入力なしでは接続できないガードレール付き
- コンテナに `bash` が入っていなくても `sh` にフォールバックして接続
- 複数のAWSプロファイル・リージョンに対応
- UI表示の日本語/英語切り替え（`ja` / `en`）に対応

## 前提条件

- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [Session Manager Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
- 対象のECSタスク定義で [ECS Exec が有効化されていること](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html)
- 実行するIAMユーザー/ロールに `ecs:ExecuteCommand` などの権限があること

## インストール

```bash
git clone https://github.com/<your-account>/ecs-gangway.git
cd ecs-gangway
chmod +x ecs-gangway.sh
```

## 使い方

```bash
./ecs-gangway.sh [ENV] [REGION] [PROFILE] [LANG]

# or (recommended)
./ecs-gangway.sh [--env ENV] [--region REGION] [--profile PROFILE] [--lang LANG]
```

| 引数    | 必須 | 説明                                                              |
| ------- | :--: | ----------------------------------------------------------------- |
| ENV     |  -   | クラスター/サービス名を絞り込むキーワード（例: `prod`, `stg`, `dev`）。省略時は全件表示 |
| REGION  |  -   | AWSリージョン。省略時は `ap-northeast-1`                          |
| PROFILE |  -   | AWS CLIのプロファイル名。省略時はデフォルトプロファイル/環境変数を使用 |
| LANG    |  -   | UI言語。`ja` または `en`。省略時は `LC_ALL`/`LANG` から自動判定 |

### 例

```bash
# 全クラスターから対話的に選ぶ
./ecs-gangway.sh

# "stg" を含むクラスター/サービスに絞り込む
./ecs-gangway.sh stg

# リージョンとプロファイルを指定
./ecs-gangway.sh prod us-east-1 my-profile

# UI表示を英語に固定
./ecs-gangway.sh prod us-east-1 my-profile en

# LANGだけ指定して英語UIで開始（他は対話選択/デフォルト）
./ecs-gangway.sh --lang en

# オプション形式で明示指定
./ecs-gangway.sh --env prod --region us-east-1 --profile my-profile --lang en
```

候補が1つしかないステップ（クラスター・サービス・タスク・コンテナ）は自動で決定され、複数ある場合のみ選択を求められます。

## 本番環境への接続について

クラスター名やサービス名に `prd` / `prod` が含まれる場合、接続前に確認プロンプトが表示されます。`yes` と入力しない限り接続はキャンセルされます。

## License

[MIT](./LICENSE)
