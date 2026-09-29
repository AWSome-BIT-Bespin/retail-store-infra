#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

for command_name in gcloud kubectl helm; do
  command -v "$command_name" >/dev/null 2>&1 || {
    printf '필수 명령을 찾을 수 없습니다: %s\n' "$command_name" >&2
    exit 1
  }
done

GKE_CONTEXT="${GKE_CONTEXT:-$(kubectl config current-context)}"
[[ "$GKE_CONTEXT" == gke_* ]] || {
  printf 'GKE context가 아닙니다. 먼저 svc-gcp.sh로 GKE에 연결해 주세요: %s\n' "$GKE_CONTEXT" >&2
  exit 1
}
printf 'WhaTap 설치 대상: %s\n' "$GKE_CONTEXT"

ACCOUNT="$(gcloud info --format='value(config.account)')"
[[ -n "$ACCOUNT" && "$ACCOUNT" != "(unset)" ]] || {
  printf 'gcloud에 로그인된 계정이 없습니다.\n' >&2
  exit 1
}

# 기존 권한 바인딩이 있으면 재생성하지 않습니다.
existing_binding="$(kubectl --context "$GKE_CONTEXT" get clusterrolebinding \
  owner-cluster-admin-binding --ignore-not-found -o name)"
if [[ -z "$existing_binding" ]]; then
  kubectl --context "$GKE_CONTEXT" create clusterrolebinding owner-cluster-admin-binding \
    --clusterrole cluster-admin --user "$ACCOUNT"
fi

helm repo add whatap https://whatap.github.io/helm/
helm repo update

kubectl --context "$GKE_CONTEXT" create namespace whatap-monitoring \
  --dry-run=client -o yaml |
  kubectl --context "$GKE_CONTEXT" apply -f -
export WHATAP_HOST=13.124.11.223/13.209.172.35
export WHATAP_LICENSE=x60679s8bd9lb-z4d8aeor9fs8a0-x6fa5vk8bh8e6c
export WHATAP_PORT=6600
kubectl --context "$GKE_CONTEXT" create secret generic whatap-credentials \
  --namespace whatap-monitoring \
  --from-literal="WHATAP_LICENSE=$WHATAP_LICENSE" \
  --from-literal="WHATAP_HOST=$WHATAP_HOST" \
  --from-literal="WHATAP_PORT=$WHATAP_PORT" \
  --dry-run=client -o yaml |
  kubectl --context "$GKE_CONTEXT" apply -f -

helm upgrade --install whatap-operator whatap/whatap-operator \
  --kube-context "$GKE_CONTEXT" \
  --namespace whatap-monitoring \
  --values "${SCRIPT_DIR}/whatap-operator-values-gcp.yaml" \
  --wait --timeout 5m

kubectl --context "$GKE_CONTEXT" apply --dry-run=server --validate=strict \
  -f "${SCRIPT_DIR}/whatap_operator_gcp.yaml"
kubectl --context "$GKE_CONTEXT" apply -f "${SCRIPT_DIR}/whatap_operator_gcp.yaml"
kubectl --context "$GKE_CONTEXT" get pods -n whatap-monitoring -o wide
