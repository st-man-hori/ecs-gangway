# ecs-gangway

Interactive shell script to jump into containers running on Amazon ECS Exec by selecting cluster, service, task, and container step by step.

Typing `aws ecs execute-command` manually every time is tedious. This script removes the ARN lookup overhead and lets you connect by choosing from interactive options. It also includes a production safety guard that requires explicit confirmation.

## Features

- Interactive selection for cluster, service, task, and container with `select` (auto-select when there is only one candidate)
- Optional environment keyword filtering for cluster/service names (`prod`, `stg`, etc.)
- Production guardrail: if target names include `prd`/`prod`, connection is blocked unless you type `yes`
- Fallback shell support: tries `bash`, falls back to `sh`
- Supports multiple AWS profiles and regions
- UI language support in Japanese and English (`ja`/`en`)

## Prerequisites

- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
- [Session Manager Plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)
- [ECS Exec enabled in your ECS task definition](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-exec.html)
- IAM permissions for the caller (including `ecs:ExecuteCommand`)

## Installation

```bash
git clone https://github.com/<your-account>/ecs-gangway.git
cd ecs-gangway
chmod +x ecs-gangway.sh
```

## Usage

```bash
./ecs-gangway.sh [ENV] [REGION] [PROFILE] [LANG]

# or (recommended)
./ecs-gangway.sh [--env ENV] [--region REGION] [--profile PROFILE] [--lang LANG]
```

| Argument | Required | Description |
| ------- | :--: | ----------- |
| ENV | - | Keyword to filter cluster/service names (e.g. `prod`, `stg`, `dev`). If omitted, all are shown |
| REGION | - | AWS region. Default: `ap-northeast-1` |
| PROFILE | - | AWS CLI profile name. If omitted, default profile/environment variables are used |
| LANG | - | UI language: `ja` or `en`. If omitted, auto-detected from `LC_ALL`/`LANG` |

## Examples

```bash
# Choose interactively from all clusters
./ecs-gangway.sh

# Filter cluster/service names containing "stg"
./ecs-gangway.sh stg

# Specify region and profile
./ecs-gangway.sh prod us-east-1 my-profile

# Force English UI
./ecs-gangway.sh prod us-east-1 my-profile en

# Specify language only (others stay interactive/default)
./ecs-gangway.sh --lang en

# Full option style
./ecs-gangway.sh --env prod --region us-east-1 --profile my-profile --lang en
```

If only one candidate exists in a step (cluster, service, task, container), it is auto-selected. Selection is required only when there are multiple candidates.

## Production Connection Safety

If the cluster or service name includes `prd` or `prod`, a confirmation prompt appears before connection. The script proceeds only when you type `yes`.

## License

[MIT](./LICENSE)
