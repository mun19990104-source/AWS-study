# AWS-study Terraform

WAF → ALB → EC2 → RDS の学習用環境。CloudWatch + SNS で監視。

## ファイル構成

```
.
├── versions.tf                 # terraform ブロック / プロバイダ制約
├── providers.tf                # provider "aws"
├── variables.tf                # 変数定義
├── data.tf                     # データソース（AZ取得）
├── vpc.tf                      # VPC / IGW / ルートテーブル / サブネット
├── security_groups.tf          # ALB / EC2 / RDS の3つ
├── ec2.tf                      # EC2 インスタンス
├── alb.tf                      # ALB / TG / リスナー
├── rds.tf                      # RDS / DBサブネットグループ
├── waf.tf                      # WAF v2 / ロググループ
├── monitoring.tf               # SNS / CloudWatch アラーム
├── outputs.tf                  # 出力値
├── tests/                      # ユニットテスト（モック・課金なし）
└── tests-integration/          # 統合テスト（実AWS・要クレデンシャル）
```

## テストの実行

### ユニットテスト（普段はこれだけでいい）

```bash
terraform init
terraform test
```

- `mock_provider` を使うので **AWSクレデンシャル不要・リソース作成なし・課金なし**
- 数秒で終わるので、コミット前やPR時に毎回回せる
- `terraform test -verbose` で各 run のプラン内容が見られる
- 1ファイルだけ回す場合: `terraform test -filter=tests/security_groups.tftest.hcl`

### 統合テスト（実AWSのプロバイダを使う）

```bash
export TF_VAR_db_password='...'
terraform test -test-directory=tests-integration
```

- `command = plan` のみなので**リソースは作られない**が、AWSクレデンシャルは必要
- モックでは検出できない「実際のAZ数」やプロバイダ側のバリデーションを確認できる
- 実際に apply して疎通確認する run はファイル内にコメントアウトで用意してある（**課金あり・RDS作成に約10分**）

## テストの中身

| ファイル | 見ているもの |
|---|---|
| `variables_validation.tftest.hcl` | `validation` ブロックが効くか（`expect_failures` を使用） |
| `network.tftest.hcl` | CIDR設計、サブネットの重複、マルチAZ配置、IGWへのデフォルトルート |
| `security_groups.tftest.hcl` | 必要な穴が開いているか + **開いてはいけない穴が閉じているか** |
| `ec2.tftest.hcl` | 変数の反映、配置先サブネット、SG |
| `alb.tftest.hcl` | インターネット向け構成、TGとリスナーのポート整合、ヘルスチェック |
| `rds.tftest.hcl` | `publicly_accessible = false`、プライベートサブネット限定 |
| `waf.tftest.hcl` | ロググループ名のプレフィックス必須要件、scope、ルールのpriority重複 |
| `monitoring.tftest.hcl` | 通知先の反映、`datapoints_to_alarm <= evaluation_periods` |

方針として、単なる「書いた値をそのまま読むだけ」のテストは最小限にして、

- **apply して初めて落ちるミス**（WAFロググループ名のプレフィックス、`datapoints_to_alarm` の上限、`period` の許容値、TGとattachmentのポート不一致）
- **セキュリティ上まずい状態**（SSHが 0.0.0.0/0、RDSがpublic、8080の直接公開）
- **リファクタで壊れやすい配線**（アラームの監視対象、リスナーの転送先、SG間の参照方向）

を優先的に押さえている。

## 既知の課題

- `PublicSubnet2` のルートテーブル関連付けが未定義。`vpc.tf` にコメントアウトで用意してあり、有効化したら `tests/network.tftest.hcl` の `public_subnet2_is_associated_with_public_route_table` のコメントも外す
- `aws_internet_gateway.igw` のタグが `KeyName = "value"` のままになっている

## 注意

`terraform.tfvars` には `db_password` が入りうるので `.gitignore` に追加すること。パスワードは `TF_VAR_db_password` 環境変数で渡すのが安全。
