#!/usr/bin/env bash
set -Eeuo pipefail

# 이미 생성된 GKE 클러스터에 접속하고 Retail Store 배포 공간을 준비합니다.
# Cloud Shell 또는 GKE API에 접근할 수 있는 Bastion의 Bash에서 실행합니다.
#
# 실행 예:
#   export GCP_PROJECT_ID="kdt4-3"
#   export GKE_CLUSTER_NAME="실제-GKE-클러스터명"
#   export GKE_LOCATION="asia-northeast3"
#   bash ./svc-gcp.sh
#
# GKE_LOCATION: regional 클러스터는 region, zonal 클러스터는 zone입니다.
# APP_NAMESPACE는 생략하면 retail-store를 사용합니다.
#
# UI LoadBalancer와 Redis Pod는 애플리케이션 Helm 차트에서 생성합니다.
# orders-db 등 직접 관리하는 Secret은 namespace 준비 후 별도로 적용합니다.

APP_NAMESPACE="${APP_NAMESPACE:-retail-store}"

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 ||
    die "필수 명령을 찾을 수 없습니다: $command_name"
}

[[ -n "${GCP_PROJECT_ID:-}" ]] ||
  die 'GCP_PROJECT_ID를 설정해 주세요. 예: export GCP_PROJECT_ID="kdt4-3"'
[[ -n "${GKE_CLUSTER_NAME:-}" ]] ||
  die 'GKE_CLUSTER_NAME을 실제 GKE 클러스터 이름으로 설정해 주세요.'
[[ -n "${GKE_LOCATION:-}" ]] ||
  die 'GKE_LOCATION을 실제 클러스터의 region 또는 zone으로 설정해 주세요.'

log "필수 명령 확인"
for command_name in gcloud gke-gcloud-auth-plugin kubectl helm; do
  require_command "$command_name"
done

log "Helm 확인"
helm version --short

log "GKE 클러스터 확인: $GCP_PROJECT_ID / $GKE_LOCATION / $GKE_CLUSTER_NAME"
CLUSTER_STATUS="$(gcloud container clusters describe "$GKE_CLUSTER_NAME" \
  --project "$GCP_PROJECT_ID" \
  --location "$GKE_LOCATION" \
  --format='value(status)')"

[[ "$CLUSTER_STATUS" == "RUNNING" ]] ||
  die "GKE 클러스터가 RUNNING 상태가 아닙니다: $CLUSTER_STATUS"

log "GKE kubeconfig 구성"
gcloud container clusters get-credentials "$GKE_CLUSTER_NAME" \
  --project "$GCP_PROJECT_ID" \
  --location "$GKE_LOCATION"

# 이후 kubectl 명령은 이 GKE context를 명시적으로 사용합니다.
GKE_CONTEXT="gke_${GCP_PROJECT_ID}_${GKE_LOCATION}_${GKE_CLUSTER_NAME}"

log "GKE 연결 및 노드 확인: $GKE_CONTEXT"
kubectl --context "$GKE_CONTEXT" cluster-info
kubectl --context "$GKE_CONTEXT" get nodes -o wide

log "애플리케이션 namespace 준비: $APP_NAMESPACE"
kubectl --context "$GKE_CONTEXT" create namespace "$APP_NAMESPACE" \
  --dry-run=client -o yaml |
  kubectl --context "$GKE_CONTEXT" apply -f -

log "준비된 namespace 확인"
kubectl --context "$GKE_CONTEXT" get namespace "$APP_NAMESPACE"

log "GKE 배포 준비가 완료되었습니다."
printf '다음으로 %s namespace에 필요한 Secret을 적용하고 GCP values로 앱을 배포하세요.\n' \
  "$APP_NAMESPACE"
