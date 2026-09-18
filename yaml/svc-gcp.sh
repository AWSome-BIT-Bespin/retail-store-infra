#!/usr/bin/env bash
set -Eeuo pipefail

# 이미 생성된 GKE 클러스터에 접속하고 Retail Store 배포 공간을 준비합니다.
# Cloud Shell 또는 GKE API에 접근할 수 있는 Bastion의 Bash에서 실행합니다.
#
# 실행 예:
#   export GCP_PROJECT_ID="kdt4-3"
#   export GKE_CLUSTER_NAME="retail-dr-gke"
#   export GKE_LOCATION="asia-northeast3-a"
#   bash ./svc-gcp.sh
#
# GKE_LOCATION: regional 클러스터는 region, zonal 클러스터는 zone입니다.
# APP_NAMESPACE는 생략하면 retail-store를 사용합니다.
# gcloud, gke-gcloud-auth-plugin, kubectl은 먼저 설치해야 합니다.
# Helm은 기존 설치를 사용하고, 없을 때만 svc.sh와 같은 기본 버전으로 설치합니다.
# HELM_VERSION(기본 v3.21.4), HELM_INSTALL_DIR(기본 /usr/local/bin)로 변경할 수 있습니다.
# Helm 자동 설치에는 curl, tar, openssl과 설치 경로에 대한 쓰기 권한(sudo)이 필요합니다.
#
# UI LoadBalancer와 Redis Pod는 애플리케이션 Helm 차트에서 생성합니다.
# orders-db 등 직접 관리하는 Secret은 namespace 준비 후 별도로 적용합니다.

APP_NAMESPACE="${APP_NAMESPACE:-retail-store}"
HELM_VERSION="${HELM_VERSION:-v3.21.4}"
HELM_INSTALL_DIR="${HELM_INSTALL_DIR:-/usr/local/bin}"
WORK_DIR=""

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "$WORK_DIR" && -d "$WORK_DIR" ]]; then
    rm -rf -- "$WORK_DIR"
  fi
}
trap cleanup EXIT

require_command() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 ||
    die "필수 명령을 찾을 수 없습니다: $command_name"
}

install_helm_if_missing() {
  if command -v helm >/dev/null 2>&1; then
    log "기존 Helm 사용"
    helm version --short
    return
  fi

  [[ "$HELM_VERSION" =~ ^v(3|4)\.[0-9]+\.[0-9]+$ ]] ||
    die 'HELM_VERSION은 v3.21.4 또는 v4.2.3처럼 정식 버전으로 지정해 주세요.'
  local helm_major="${BASH_REMATCH[1]}"
  local command_name
  for command_name in curl tar openssl mktemp; do
    require_command "$command_name"
  done

  [[ -d "$HELM_INSTALL_DIR" ]] ||
    die "Helm 설치 경로가 없습니다. 먼저 생성해 주세요: $HELM_INSTALL_DIR"

  WORK_DIR="$(mktemp -d -t svc-gcp-helm.XXXXXX)"
  local installer="$WORK_DIR/get-helm-$helm_major"

  log "Helm $HELM_VERSION 설치"
  curl -fsSL -o "$installer" \
    "https://raw.githubusercontent.com/helm/helm/$HELM_VERSION/scripts/get-helm-$helm_major"

  # 공식 설치 스크립트의 설치 확인에서도 사용자 지정 경로를 찾을 수 있게 합니다.
  export PATH="$HELM_INSTALL_DIR:$PATH"
  DESIRED_VERSION="$HELM_VERSION" \
    HELM_INSTALL_DIR="$HELM_INSTALL_DIR" \
    VERIFY_CHECKSUM=true \
    bash "$installer"

  hash -r
  require_command helm
  helm version --short
}

[[ -n "${GCP_PROJECT_ID:-}" ]] ||
  die 'GCP_PROJECT_ID를 설정해 주세요. 예: export GCP_PROJECT_ID="kdt4-3"'
[[ -n "${GKE_CLUSTER_NAME:-}" ]] ||
  die 'GKE_CLUSTER_NAME을 실제 GKE 클러스터 이름으로 설정해 주세요.'
[[ -n "${GKE_LOCATION:-}" ]] ||
  die 'GKE_LOCATION을 실제 클러스터의 region 또는 zone으로 설정해 주세요.'

log "필수 명령 확인"
for command_name in gcloud gke-gcloud-auth-plugin kubectl; do
  require_command "$command_name"
done

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

install_helm_if_missing

log "애플리케이션 namespace 준비: $APP_NAMESPACE"
kubectl --context "$GKE_CONTEXT" create namespace "$APP_NAMESPACE" \
  --dry-run=client -o yaml |
  kubectl --context "$GKE_CONTEXT" apply -f -

log "준비된 namespace 확인"
kubectl --context "$GKE_CONTEXT" get namespace "$APP_NAMESPACE"

log "GKE 배포 준비가 완료되었습니다."
printf '다음으로 %s namespace에 필요한 Secret을 적용하고 GCP values로 앱을 배포하세요.\n' \
  "$APP_NAMESPACE"
