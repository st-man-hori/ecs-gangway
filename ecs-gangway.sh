#!/bin/bash
set -e

# Usage:
#   Positional (backward compatible): ./ecs-gangway.sh [ENV] [REGION] [PROFILE] [LANG]
#   Options: ./ecs-gangway.sh [--env ENV] [--region REGION] [--profile PROFILE] [--lang ja|en]
#
# Examples:
#   ./ecs-gangway.sh --lang en
#   ./ecs-gangway.sh --env prod --region us-east-1 --profile my-profile --lang ja

usage() {
    cat <<'EOF'
Usage:
  ./ecs-gangway.sh [ENV] [REGION] [PROFILE] [LANG]
  ./ecs-gangway.sh [--env ENV] [--region REGION] [--profile PROFILE] [--lang ja|en]

Options:
  -e, --env ENV         Filter keyword for cluster/service names (e.g. prod, stg, dev)
  -r, --region REGION   AWS region (default: ap-northeast-1)
  -p, --profile PROFILE AWS CLI profile name
  -l, --lang LANG       UI language: ja or en
  -h, --help            Show this help
EOF
}

ENV=""
REGION="ap-northeast-1"
PROFILE=""
LANG_OPT=""
POSITIONAL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -e|--env)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Option $1 requires a value."
                usage
                exit 1
            fi
            ENV="$2"
            shift 2
            ;;
        -r|--region)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Option $1 requires a value."
                usage
                exit 1
            fi
            REGION="$2"
            shift 2
            ;;
        -p|--profile)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Option $1 requires a value."
                usage
                exit 1
            fi
            PROFILE="$2"
            shift 2
            ;;
        -l|--lang)
            if [[ -z "$2" || "$2" == -* ]]; then
                echo "Option $1 requires a value."
                usage
                exit 1
            fi
            LANG_OPT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            while [[ $# -gt 0 ]]; do
                POSITIONAL+=("$1")
                shift
            done
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
        *)
            POSITIONAL+=("$1")
            shift
            ;;
    esac
done

# Backward compatibility for positional args.
if [ -z "${ENV}" ] && [ -n "${POSITIONAL[0]}" ]; then
    ENV="${POSITIONAL[0]}"
fi
if [ "${REGION}" = "ap-northeast-1" ] && [ -n "${POSITIONAL[1]}" ]; then
    REGION="${POSITIONAL[1]}"
fi
if [ -z "${PROFILE}" ] && [ -n "${POSITIONAL[2]}" ]; then
    PROFILE="${POSITIONAL[2]}"
fi
if [ -z "${LANG_OPT}" ] && [ -n "${POSITIONAL[3]}" ]; then
    LANG_OPT="${POSITIONAL[3]}"
fi

UI_LANG=""
if [ -n "${LANG_OPT}" ]; then
    case "${LANG_OPT,,}" in
        ja|en)
            UI_LANG="${LANG_OPT,,}"
            ;;
        *)
            echo "Unsupported language: ${LANG_OPT}. Use 'ja' or 'en'."
            exit 1
            ;;
    esac
fi

if [ -z "${UI_LANG}" ]; then
    LOCALE_CANDIDATE="${LC_ALL:-${LANG:-}}"
    if [[ "${LOCALE_CANDIDATE,,}" == ja* ]]; then
        UI_LANG="ja"
    else
        UI_LANG="en"
    fi
fi

t() {
    local key="$1"
    if [ "${UI_LANG}" = "ja" ]; then
        case "${key}" in
            select_prompt) echo "👉 番号を入力してください: " ;;
            title) echo " ecs-gangway" ;;
            fetching_clusters) echo "🔍 クラスター一覧を AWS から取得中..." ;;
            err_no_clusters) echo "❌ エラー: クラスターが1つも見つかりませんでした。" ;;
            cluster_auto) echo "🏗️  対象クラスター（自動決定）: %s" ;;
            choose_cluster) echo "🏗️  クラスターを選択してください:" ;;
            invalid_choice) echo "❌ 無効な選択です。再入力してください。" ;;
            fetching_services) echo "🔍 クラスター [%s] からサービス一覧を取得中..." ;;
            err_no_services) echo "❌ エラー: クラスター [%s] 内にサービスが見つかりませんでした。" ;;
            service_auto) echo "📦 対象サービス（自動決定）: %s" ;;
            choose_service) echo "📦 サービスを選択してください:" ;;
            fetching_tasks) echo "🏃 起動中（RUNNING）のタスクを取得中..." ;;
            err_no_tasks) echo "❌ エラー: サービス [%s] に起動中のタスクが見つかりませんでした。" ;;
            choose_task) echo "🎯 複数のタスクが起動しています。対象タスクを選択してください:" ;;
            selected_task_id) echo "👉 対象タスクID: %s" ;;
            fetching_containers) echo "🐳 タスク内のコンテナ一覧を取得中..." ;;
            err_no_containers) echo "❌ エラー: タスク内にコンテナが見つかりませんでした。" ;;
            choose_container) echo "🚢 コンテナを選択してください:" ;;
            prd_header) echo " 🚨 本番環境（PRD）への接続確認 🚨" ;;
            normal_header) echo " 🚀 以下のターゲットに接続します" ;;
            label_cluster) echo "   Cluster   : %s" ;;
            label_service) echo "   Service   : %s" ;;
            label_container) echo "   Container : %s" ;;
            label_task) echo "   Task ID   : %s" ;;
            prd_confirm_msg) echo "本番環境のコンテナに入りますか？" ;;
            prd_confirm_prompt) echo "問題なければ [yes] と入力してください: " ;;
            canceled) echo "❌ 接続を安全にキャンセルしました。" ;;
            prd_connecting) echo "🚀 本番環境に接続します..." ;;
            *) echo "" ;;
        esac
    else
        case "${key}" in
            select_prompt) echo "👉 Enter a number: " ;;
            title) echo " ecs-gangway" ;;
            fetching_clusters) echo "🔍 Fetching clusters from AWS..." ;;
            err_no_clusters) echo "❌ Error: No clusters found." ;;
            cluster_auto) echo "🏗️  Target cluster (auto-selected): %s" ;;
            choose_cluster) echo "🏗️  Select a cluster:" ;;
            invalid_choice) echo "❌ Invalid selection. Please try again." ;;
            fetching_services) echo "🔍 Fetching services from cluster [%s]..." ;;
            err_no_services) echo "❌ Error: No services found in cluster [%s]." ;;
            service_auto) echo "📦 Target service (auto-selected): %s" ;;
            choose_service) echo "📦 Select a service:" ;;
            fetching_tasks) echo "🏃 Fetching RUNNING tasks..." ;;
            err_no_tasks) echo "❌ Error: No RUNNING tasks found for service [%s]." ;;
            choose_task) echo "🎯 Multiple tasks are running. Select a target task:" ;;
            selected_task_id) echo "👉 Target task ID: %s" ;;
            fetching_containers) echo "🐳 Fetching containers in the task..." ;;
            err_no_containers) echo "❌ Error: No containers found in the task." ;;
            choose_container) echo "🚢 Select a container:" ;;
            prd_header) echo " 🚨 Production (PRD) Connection Confirmation 🚨" ;;
            normal_header) echo " 🚀 Connecting to the following target" ;;
            label_cluster) echo "   Cluster   : %s" ;;
            label_service) echo "   Service   : %s" ;;
            label_container) echo "   Container : %s" ;;
            label_task) echo "   Task ID   : %s" ;;
            prd_confirm_msg) echo "You are about to enter a production container." ;;
            prd_confirm_prompt) echo "Type [yes] to continue: " ;;
            canceled) echo "❌ Connection canceled safely." ;;
            prd_connecting) echo "🚀 Connecting to production..." ;;
            *) echo "" ;;
        esac
    fi
}

# 🎨 カラー定義（視覚的な警告用）
RED='\033[1;31m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'       # No Color

export PS3="$(t select_prompt)"

# PROFILEが指定されていればaws cliの共通オプションに追加
AWS_OPTS=(--region "${REGION}")
if [ -n "${PROFILE}" ]; then
    AWS_OPTS+=(--profile "${PROFILE}")
fi

echo "=================================================="
echo "$(t title)"
echo "=================================================="

# --------------------------------------------------
# クラスター（CLUSTER_NAME）の自動取得と選択
# --------------------------------------------------
echo "$(t fetching_clusters)"
ALL_CLUSTERS=($(aws ecs list-clusters "${AWS_OPTS[@]}" --query "clusterArns[]" --output text | tr '\t' '\n' | awk -F/ '{print $NF}'))

if [ ${#ALL_CLUSTERS[@]} -eq 0 ]; then
    echo "$(t err_no_clusters)"
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
    printf "$(t cluster_auto)\n" "${CLUSTER_NAME}"
else
    echo "$(t choose_cluster)"
    select cluster_opt in "${FILTERED_CLUSTERS[@]}"; do
        if [ -n "${cluster_opt}" ]; then
            CLUSTER_NAME="${cluster_opt}"
            break
        else
            echo "$(t invalid_choice)"
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
printf "$(t fetching_services)\n" "${CLUSTER_NAME}"
SERVICES=($(aws ecs list-services --cluster "${CLUSTER_NAME}" "${AWS_OPTS[@]}" --query "serviceArns[]" --output text | tr '\t' '\n' | awk -F/ '{print $NF}'))

if [ ${#SERVICES[@]} -eq 0 ]; then
    printf "$(t err_no_services)\n" "${CLUSTER_NAME}"
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
    printf "$(t service_auto)\n" "${SERVICE_NAME}"
else
    echo "$(t choose_service)"
    select svc_opt in "${FILTERED_SERVICES[@]}"; do
        if [ -n "${svc_opt}" ]; then
            SERVICE_NAME="${svc_opt}"
            break
        else
            echo "$(t invalid_choice)"
        fi
    done
fi
echo "--------------------------------------------------"

# --------------------------------------------------
# 起動中タスクの取得と選択
# --------------------------------------------------
echo "$(t fetching_tasks)"
TASKS=($(aws ecs list-tasks --cluster "${CLUSTER_NAME}" --service "${SERVICE_NAME}" --desired-status RUNNING "${AWS_OPTS[@]}" --query "taskArns[]" --output text | tr '\t' '\n'))

if [ ${#TASKS[@]} -eq 0 ]; then
    printf "$(t err_no_tasks)\n" "${SERVICE_NAME}"
    exit 1
fi

if [ ${#TASKS[@]} -eq 1 ]; then
    TASK_ARN="${TASKS[0]}"
else
    echo "$(t choose_task)"
    select task_opt in "${TASKS[@]}"; do
        if [ -n "${task_opt}" ]; then
            TASK_ARN="${task_opt}"
            break
        else
            echo "$(t invalid_choice)"
        fi
    done
fi
TASK_ID=$(basename "${TASK_ARN}")
printf "$(t selected_task_id)\n" "${TASK_ID}"
echo "--------------------------------------------------"

# --------------------------------------------------
# コンテナ（CONTAINER_NAME）の選択
# --------------------------------------------------
echo "$(t fetching_containers)"
CONTAINERS=($(aws ecs describe-tasks --cluster "${CLUSTER_NAME}" --tasks "${TASK_ARN}" "${AWS_OPTS[@]}" --query "tasks[0].containers[].name" --output text | tr '\t' '\n'))

if [ ${#CONTAINERS[@]} -eq 0 ]; then
    echo "$(t err_no_containers)"
    exit 1
fi

if [ ${#CONTAINERS[@]} -eq 1 ]; then
    CONTAINER_NAME="${CONTAINERS[0]}"
else
    echo "$(t choose_container)"
    select container_opt in "${CONTAINERS[@]}"; do
        if [ -n "${container_opt}" ]; then
            CONTAINER_NAME="${container_opt}"
            break
        else
            echo "$(t invalid_choice)"
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
    echo "$(t prd_header)"
    echo -e "==================================================${NC}"
else
    echo -e "${CYAN}=================================================="
    echo "$(t normal_header)"
    echo -e "==================================================${NC}"
fi

printf "$(t label_cluster)\n" "${CLUSTER_NAME}"
printf "$(t label_service)\n" "${SERVICE_NAME}"
printf "$(t label_container)\n" "${CONTAINER_NAME}"
printf "$(t label_task)\n" "${TASK_ID}"
echo -e "==================================================${NC}"

if [ ${IS_PRD} -eq 1 ]; then
    echo -e "${RED}$(t prd_confirm_msg)${NC}"
    read -p "$(t prd_confirm_prompt)" CONFIRM
    if [ "${CONFIRM}" != "yes" ]; then
        echo -e "${YELLOW}$(t canceled)${NC}"
        exit 0
    fi
    echo -e "${RED}$(t prd_connecting)${NC}"
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
