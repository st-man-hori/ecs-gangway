#!/bin/bash
set -e

# Usage: ./ecs-gangway.sh [ENV] [REGION] [PROFILE]
#   ENV     : クラスター/サービス名を絞り込むキーワード（例: prod, stg, dev）。省略時は全件表示
#   REGION  : デフォルトは ap-northeast-1
#   PROFILE : AWS CLIのプロファイル名（省略時はデフォルトプロファイル/環境変数を使用）
ENV=$1
REGION=${2:-"ap-northeast-1"}
PROFILE=$3

# 🎨 カラー定義（視覚的な警告用）
RED='\033[1;31m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'       # No Color

export PS3="👉 番号を入力してください: "

# PROFILEが指定されていればaws cliの共通オプションに追加
AWS_OPTS=(--region "${REGION}")
if [ -n "${PROFILE}" ]; then
    AWS_OPTS+=(--profile "${PROFILE}")
fi

echo "=================================================="
echo " ecs-gangway"
echo "=================================================="

# --------------------------------------------------
# クラスター（CLUSTER_NAME）の自動取得と選択
# --------------------------------------------------
echo "🔍 クラスター一覧を AWS から取得中..."
ALL_CLUSTERS=($(aws ecs list-clusters "${AWS_OPTS[@]}" --query "clusterArns[]" --output text | tr '\t' '\n' | awk -F/ '{print $NF}'))

if [ ${#ALL_CLUSTERS[@]} -eq 0 ]; then
    echo "❌ エラー: クラスターが1つも見つかりませんでした。"
    exit 1
fi

# ENVが指定されていればキーワードで絞り込み。ヒットしなければ全件を候補にする
FILTERED_CLUSTERS=()
if [ -n "${ENV}" ]; then
    for cluster in "${ALL_CLUSTERS[@]}"; do
        if [[ "${cluster}" == *"${ENV}"* ]]; then
            FILTERED_CLUSTERS+=("${cluster}")
        fi
    done
fi
if [ ${#FILTERED_CLUSTERS[@]} -eq 0 ]; then
    FILTERED_CLUSTERS=("${ALL_CLUSTERS[@]}")
fi

# 確定 or 選択
if [ ${#FILTERED_CLUSTERS[@]} -eq 1 ]; then
    CLUSTER_NAME="${FILTERED_CLUSTERS[0]}"
    echo "🏗️  対象クラスター（自動決定）: ${CLUSTER_NAME}"
else
    echo "🏗️  クラスターを選択してください:"
    select cluster_opt in "${FILTERED_CLUSTERS[@]}"; do
        if [ -n "${cluster_opt}" ]; then
            CLUSTER_NAME="${cluster_opt}"
            break
        else
            echo "❌ 無効な選択です。再入力してください。"
        fi
    done
fi

# 選択後、ENVが未指定なら本番判定用に推測しておく（後続のサービス絞り込み・警告表示のため）
if [ -z "${ENV}" ]; then
    if [[ "${CLUSTER_NAME}" == *"prd"* || "${CLUSTER_NAME}" == *"prod"* ]]; then ENV="prd";
    elif [[ "${CLUSTER_NAME}" == *"stg"* ]]; then ENV="stg";
    else ENV="dev"; fi
fi
echo "--------------------------------------------------"

# --------------------------------------------------
# サービス（SERVICE_NAME）の選択
# --------------------------------------------------
echo "🔍 クラスター [${CLUSTER_NAME}] からサービス一覧を取得中..."
SERVICES=($(aws ecs list-services --cluster "${CLUSTER_NAME}" "${AWS_OPTS[@]}" --query "serviceArns[]" --output text | tr '\t' '\n' | awk -F/ '{print $NF}'))

if [ ${#SERVICES[@]} -eq 0 ]; then
    echo "❌ エラー: クラスター [${CLUSTER_NAME}] 内にサービスが見つかりませんでした。"
    exit 1
fi

# ENV名でサービスを初期絞り込み
FILTERED_SERVICES=()
for svc in "${SERVICES[@]}"; do
    if [[ "${svc}" == *"${ENV}"* ]]; then
        FILTERED_SERVICES+=("${svc}")
    fi
done

# キーワードで1つもヒットしなかった場合は、全件を選択肢に出す
if [ ${#FILTERED_SERVICES[@]} -eq 0 ]; then
    FILTERED_SERVICES=("${SERVICES[@]}")
fi

if [ ${#FILTERED_SERVICES[@]} -eq 1 ]; then
    SERVICE_NAME="${FILTERED_SERVICES[0]}"
    echo "📦 対象サービス（自動決定）: ${SERVICE_NAME}"
else
    echo "📦 サービスを選択してください:"
    select svc_opt in "${FILTERED_SERVICES[@]}"; do
        if [ -n "${svc_opt}" ]; then
            SERVICE_NAME="${svc_opt}"
            break
        else
            echo "❌ 無効な選択です。再入力してください。"
        fi
    done
fi
echo "--------------------------------------------------"

# --------------------------------------------------
# 起動中タスクの取得と選択
# --------------------------------------------------
echo "🏃 起動中（RUNNING）のタスクを取得中..."
TASKS=($(aws ecs list-tasks --cluster "${CLUSTER_NAME}" --service "${SERVICE_NAME}" --desired-status RUNNING "${AWS_OPTS[@]}" --query "taskArns[]" --output text | tr '\t' '\n'))

if [ ${#TASKS[@]} -eq 0 ]; then
    echo "❌ エラー: サービス [${SERVICE_NAME}] に起動中のタスクが見つかりませんでした。"
    exit 1
fi

if [ ${#TASKS[@]} -eq 1 ]; then
    TASK_ARN="${TASKS[0]}"
else
    echo "🎯 複数のタスクが起動しています。対象タスクを選択してください:"
    select task_opt in "${TASKS[@]}"; do
        if [ -n "${task_opt}" ]; then
            TASK_ARN="${task_opt}"
            break
        else
            echo "❌ 無効な選択です。再入力してください。"
        fi
    done
fi
TASK_ID=$(basename "${TASK_ARN}")
echo "👉 対象タスクID: ${TASK_ID}"
echo "--------------------------------------------------"

# --------------------------------------------------
# コンテナ（CONTAINER_NAME）の選択
# --------------------------------------------------
echo "🐳 タスク内のコンテナ一覧を取得中..."
CONTAINERS=($(aws ecs describe-tasks --cluster "${CLUSTER_NAME}" --tasks "${TASK_ARN}" "${AWS_OPTS[@]}" --query "tasks[0].containers[].name" --output text | tr '\t' '\n'))

if [ ${#CONTAINERS[@]} -eq 0 ]; then
    echo "❌ エラー: タスク内にコンテナが見つかりませんでした。"
    exit 1
fi

if [ ${#CONTAINERS[@]} -eq 1 ]; then
    CONTAINER_NAME="${CONTAINERS[0]}"
else
    echo "🚢 コンテナを選択してください:"
    select container_opt in "${CONTAINERS[@]}"; do
        if [ -n "${container_opt}" ]; then
            CONTAINER_NAME="${container_opt}"
            break
        else
            echo "❌ 無効な選択です。再入力してください。"
        fi
    done
fi
echo "--------------------------------------------------"

# --------------------------------------------------
# ECS Exec の実行（本番の警告ガードレールのみ残存）
# --------------------------------------------------
IS_PRD=0
if [[ "${CLUSTER_NAME}" == *"prd"* || "${CLUSTER_NAME}" == *"prod"* || "${ENV}" == "prd" || "${ENV}" == "prod" ]]; then
    IS_PRD=1
fi

if [ ${IS_PRD} -eq 1 ]; then
    echo -e "${RED}=================================================="
    echo " 🚨 本番環境（PRD）への接続確認 🚨"
    echo -e "==================================================${NC}"
else
    echo -e "${CYAN}=================================================="
    echo " 🚀 以下のターゲットに接続します"
    echo -e "==================================================${NC}"
fi

echo "   Cluster   : ${CLUSTER_NAME}"
echo "   Service   : ${SERVICE_NAME}"
echo "   Container : ${CONTAINER_NAME}"
echo "   Task ID   : ${TASK_ID}"
echo -e "==================================================${NC}"

if [ ${IS_PRD} -eq 1 ]; then
    echo -e "${RED}本番環境のコンテナに入りますか？${NC}"
    read -p "問題なければ [yes] と入力してください: " CONFIRM
    if [ "${CONFIRM}" != "yes" ]; then
        echo -e "${YELLOW}❌ 接続を安全にキャンセルしました。${NC}"
        exit 0
    fi
    echo -e "${RED}🚀 本番環境に接続します...${NC}"
fi

# ECS Exec の実行
# bashが入っていないイメージ（Alpine系など）でも動くよう、まずbashを試し、なければshにフォールバックする
SHELL_CMD="if command -v bash >/dev/null 2>&1; then exec bash; else exec sh; fi"
aws ecs execute-command \
    --cluster "${CLUSTER_NAME}" \
    --task "${TASK_ID}" \
    --container "${CONTAINER_NAME}" \
    --command "sh -c '${SHELL_CMD}'" \
    --interactive \
    "${AWS_OPTS[@]}"
