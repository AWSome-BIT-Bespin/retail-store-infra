#!/usr/bin/env bash
set -Eeuo pipefail

# Terraform으로 EKS 클러스터, Node Group, IAM Role,
# Pod Identity Association이 생성된 이후 실행한다.
#
# 이 스크립트는 EKS 내부 Kubernetes 플랫폼 구성요소만 설치한다.
# Retail Store 애플리케이션 자체는 GitOps에서 관리한다.

CLUSTER_NAME="${CLUSTER_NAME:-retail-infra-eks}"
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
KUBE_NAMESPACE="${KUBE_NAMESPACE:-kube-system}"
APP_NAMESPACE="${APP_NAMESPACE:-retail-store}"
ESO_NAMESPACE="${ESO_NAMESPACE:-external-secrets}"

# 플랫폼 Pod를 Management Node Group에 고정하기 위한 공통 label/taint 기준이다.
# workload=mgmt 라벨로 관리용 Node를 선택하고, dedicated=mgmt:NoSchedule taint로 일반 Pod의 진입을 차단한다.
# Terraform 설정과 반드시 동일해야 한다.
MGMT_NODE_LABEL_KEY="${MGMT_NODE_LABEL_KEY:-workload}"
MGMT_NODE_LABEL_VALUE="${MGMT_NODE_LABEL_VALUE:-mgmt}"
MGMT_TAINT_KEY="${MGMT_TAINT_KEY:-dedicated}"
MGMT_TAINT_VALUE="${MGMT_TAINT_VALUE:-mgmt}"
MGMT_TAINT_EFFECT="${MGMT_TAINT_EFFECT:-NoSchedule}"

HELM_VERSION="${HELM_VERSION:-v3.21.4}"
HELM_INSTALL_DIR="${HELM_INSTALL_DIR:-/usr/local/bin}"

AWS_LBC_CHART_VERSION="${AWS_LBC_CHART_VERSION:-3.5.0}"

CLUSTER_AUTOSCALER_VERSION="${CLUSTER_AUTOSCALER_VERSION:-v1.36.0}"
CLUSTER_AUTOSCALER_CHART_VERSION="${CLUSTER_AUTOSCALER_CHART_VERSION:-9.59.0}"

ESO_CHART_VERSION="${ESO_CHART_VERSION:-2.10.0}"

WORK_DIR=""

log() {
  printf '\n[%s] %s\n' "$(date '+%H:%M:%S')" "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

cleanup() {
  if [[ -n "${WORK_DIR}" && -d "${WORK_DIR}" ]]; then
    rm -rf -- "${WORK_DIR}"
  fi
}
trap cleanup EXIT

require_command() {
  local command_name="$1"
  command -v "${command_name}" >/dev/null 2>&1 ||
    die "필수 명령을 찾을 수 없습니다: ${command_name}"
}

install_helm_if_missing() {
  if command -v helm >/dev/null 2>&1; then
    log "Helm이 이미 설치되어 있습니다: $(helm version --short)"
    return
  fi

  require_command curl
  command -v tar >/dev/null 2>&1 || die "Helm 설치에 tar가 필요합니다."

  log "Helm ${HELM_VERSION} 설치"
  local installer="${WORK_DIR}/get-helm-3"
  curl -fsSL -o "${installer}" \
    "https://raw.githubusercontent.com/helm/helm/${HELM_VERSION}/scripts/get-helm-3"
  chmod 700 "${installer}"

  DESIRED_VERSION="${HELM_VERSION}" \
    HELM_INSTALL_DIR="${HELM_INSTALL_DIR}" \
    "${installer}"

  hash -r
  require_command helm
  helm version --short
}

validate_management_nodes() {
  local node_rows
  local node_name
  local zone
  local ready
  local unschedulable
  local taints
  local ready_count=0
  local -A ready_zones=()
  local expected_taint="${MGMT_TAINT_KEY}=${MGMT_TAINT_VALUE}=${MGMT_TAINT_EFFECT}"

  # HA 분산을 위해 Ready이며 cordon되지 않은 MGMT Node가
  # 최소 두 대, 서로 다른 AZ에 있어야 한다.
  node_rows="$(kubectl get nodes \
    --selector "${MGMT_NODE_LABEL_KEY}=${MGMT_NODE_LABEL_VALUE}" \
    --output 'jsonpath={range .items[*]}{.metadata.name}{"|"}{.metadata.labels.topology\.kubernetes\.io/zone}{"|"}{.status.conditions[?(@.type=="Ready")].status}{"|"}{.spec.unschedulable}{"|"}{range .spec.taints[*]}{.key}={.value}={.effect}{" "}{end}{"\n"}{end}')"

  [[ -n "${node_rows}" ]] ||
    die "MGMT Node를 찾지 못했습니다: ${MGMT_NODE_LABEL_KEY}=${MGMT_NODE_LABEL_VALUE}"

  while IFS='|' read -r node_name zone ready unschedulable taints; do
    [[ -n "${node_name}" ]] || continue
    case " ${taints} " in
      *" ${expected_taint} "*)
        ;;
      *)
        die "Node ${node_name}에 필요한 taint가 없습니다: ${MGMT_TAINT_KEY}=${MGMT_TAINT_VALUE}:${MGMT_TAINT_EFFECT}"
        ;;
    esac
    if [[ "${ready}" != "True" || "${unschedulable}" == "true" ]]; then
      log "HA 배치 후보에서 제외: ${node_name} (Ready=${ready}, unschedulable=${unschedulable:-false})"
      continue
    fi
    [[ -n "${zone}" ]] ||
      die "Node ${node_name}에 topology.kubernetes.io/zone 라벨이 없습니다."
    ready_count=$((ready_count + 1))
    ready_zones["${zone}"]=1
  done <<< "${node_rows}"

  [[ "${ready_count}" -ge 2 ]] ||
    die "HA 배치에는 Ready이며 cordon되지 않은 MGMT Node가 최소 두 대 필요합니다: ${ready_count}대"
  [[ "${#ready_zones[@]}" -ge 2 ]] ||
    die "HA 배치에는 서로 다른 AZ가 최소 두 개 필요합니다: ${!ready_zones[*]}"

  log "Management Node 확인 완료: ${ready_count}대, AZ=${!ready_zones[*]}"
  log "label: ${MGMT_NODE_LABEL_KEY}=${MGMT_NODE_LABEL_VALUE}"
  log "taint: ${MGMT_TAINT_KEY}=${MGMT_TAINT_VALUE}:${MGMT_TAINT_EFFECT}"
}

# 각 Deployment의 같은 revision만 세어 롤링 업데이트 후에도 분산을 유지한다.
# minDomains=2는 장애 시 같은 노드/AZ에 두 복제본을 몰아넣지 않도록 한다.
platform_topology_constraints() {
  local app_name="$1"
  local release_name="$2"
  cat <<EOF
[
  {
    "maxSkew": 1,
    "minDomains": 2,
    "topologyKey": "kubernetes.io/hostname",
    "whenUnsatisfiable": "DoNotSchedule",
    "nodeAffinityPolicy": "Honor",
    "nodeTaintsPolicy": "Honor",
    "labelSelector": {"matchLabels": {
      "app.kubernetes.io/name": "${app_name}",
      "app.kubernetes.io/instance": "${release_name}"
    }},
    "matchLabelKeys": ["pod-template-hash"]
  },
  {
    "maxSkew": 1,
    "minDomains": 2,
    "topologyKey": "topology.kubernetes.io/zone",
    "whenUnsatisfiable": "DoNotSchedule",
    "nodeAffinityPolicy": "Honor",
    "nodeTaintsPolicy": "Honor",
    "labelSelector": {"matchLabels": {
      "app.kubernetes.io/name": "${app_name}",
      "app.kubernetes.io/instance": "${release_name}"
    }},
    "matchLabelKeys": ["pod-template-hash"]
  }
]
EOF
}

verify_platform_pod_nodes() {
  local namespace="$1"
  local selector="$2"
  local component="$3"
  local pod_rows
  local pod_name
  local node_name
  local node_label
  local zone
  local ready
  local deletion_timestamp
  local pod_count=0
  local -A pod_nodes=()
  local -A pod_zones=()

  # 종료 중인 이전 Pod를 제외하고, Ready 복제본 두 개의 노드/AZ 분산을 확인한다.
  pod_rows="$(kubectl get pods \
    --namespace "${namespace}" \
    --selector "${selector}" \
    --field-selector status.phase=Running \
    --output 'jsonpath={range .items[*]}{.metadata.name}{"|"}{.spec.nodeName}{"|"}{.status.conditions[?(@.type=="Ready")].status}{"|"}{.metadata.deletionTimestamp}{"\n"}{end}')"

  [[ -n "${pod_rows}" ]] ||
    die "${component} 실행 Pod를 찾지 못했습니다."

  while IFS='|' read -r pod_name node_name ready deletion_timestamp; do
    [[ -n "${pod_name}" ]] || continue
    [[ -z "${deletion_timestamp}" ]] || continue
    [[ "${ready}" == "True" ]] ||
      die "${component} Pod ${pod_name}가 Ready 상태가 아닙니다."
    node_label="$(kubectl get node "${node_name}" \
      --output "jsonpath={.metadata.labels['${MGMT_NODE_LABEL_KEY}']}")"
    [[ "${node_label}" == "${MGMT_NODE_LABEL_VALUE}" ]] ||
      die "${component} Pod ${pod_name}가 MGMT Node가 아닌 ${node_name}에 배치되었습니다."
    zone="$(kubectl get node "${node_name}" \
      --output 'jsonpath={.metadata.labels.topology\.kubernetes\.io/zone}')"
    [[ -n "${zone}" ]] || die "Node ${node_name}에 AZ 라벨이 없습니다."
    pod_count=$((pod_count + 1))
    pod_nodes["${node_name}"]=1
    pod_zones["${zone}"]=1
    log "${component} Pod 배치 확인: ${pod_name} -> ${node_name} (${zone})"
  done <<< "${pod_rows}"

  [[ "${pod_count}" -eq 2 ]] ||
    die "${component}의 Ready 복제본이 두 개가 아닙니다: ${pod_count}개"
  [[ "${#pod_nodes[@]}" -eq 2 && "${#pod_zones[@]}" -eq 2 ]] ||
    die "${component} 복제본이 서로 다른 두 MGMT Node/AZ에 분산되지 않았습니다."
  log "${component} HA 배치 확인 완료: Ready 2개, Node 2대, AZ 2개"
}

# APP/MGMT 두 Managed Node Group 모두 Cluster Autoscaler의
# 자동 탐색 대상이어야 하므로 전체 Node Group의 ASG에 태그를 설정한다.
tag_managed_nodegroups_for_autodiscovery() {
  local nodegroups
  local nodegroup
  local asg_name

  nodegroups="$(aws eks list-nodegroups \
    --cluster-name "${CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --query 'nodegroups[]' \
    --output text)"

  [[ -n "${nodegroups}" && "${nodegroups}" != "None" ]] ||
    die "Cluster Autoscaler가 관리할 EKS 노드 그룹을 찾지 못했습니다."

  for nodegroup in ${nodegroups}; do
    asg_name="$(aws eks describe-nodegroup \
      --cluster-name "${CLUSTER_NAME}" \
      --nodegroup-name "${nodegroup}" \
      --region "${AWS_REGION}" \
      --query 'nodegroup.resources.autoScalingGroups[0].name' \
      --output text)"

    [[ -n "${asg_name}" && "${asg_name}" != "None" ]] ||
      die "노드 그룹 ${nodegroup}의 Auto Scaling Group을 찾지 못했습니다."

    log "Cluster Autoscaler 자동 탐색 태그 설정: ${nodegroup} (${asg_name})"
    aws autoscaling create-or-update-tags \
      --region "${AWS_REGION}" \
      --tags \
        "ResourceId=${asg_name},ResourceType=auto-scaling-group,Key=k8s.io/cluster-autoscaler/enabled,Value=true,PropagateAtLaunch=false" \
        "ResourceId=${asg_name},ResourceType=auto-scaling-group,Key=k8s.io/cluster-autoscaler/${CLUSTER_NAME},Value=owned,PropagateAtLaunch=false"
  done
}

for command_name in aws kubectl; do
  require_command "${command_name}"
done

WORK_DIR="$(mktemp -d)"

log "EKS 클러스터 상태 확인"
CLUSTER_STATUS="$(aws eks describe-cluster \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" \
  --query 'cluster.status' \
  --output text)"
[[ "${CLUSTER_STATUS}" == "ACTIVE" ]] ||
  die "EKS 클러스터 상태가 ACTIVE가 아닙니다: ${CLUSTER_STATUS}"

CLUSTER_VERSION="$(aws eks describe-cluster \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" \
  --query 'cluster.version' \
  --output text)"

EXPECTED_K8S_MINOR="${CLUSTER_AUTOSCALER_VERSION#v}"
EXPECTED_K8S_MINOR="${EXPECTED_K8S_MINOR%.*}"
[[ "${CLUSTER_VERSION}" == "${EXPECTED_K8S_MINOR}" ]] ||
  die "클러스터는 Kubernetes ${CLUSTER_VERSION}이지만 Cluster Autoscaler는 ${CLUSTER_AUTOSCALER_VERSION}입니다. 마이너 버전을 맞춰 주세요."

VPC_ID="$(aws eks describe-cluster \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" \
  --query 'cluster.resourcesVpcConfig.vpcId' \
  --output text)"
[[ "${VPC_ID}" == vpc-* ]] || die "EKS 클러스터의 VPC ID를 확인하지 못했습니다."

aws eks update-kubeconfig \
  --name "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" >/dev/null
kubectl cluster-info >/dev/null

validate_management_nodes

# IAM Role과 Pod Identity Association은 Terraform에서 관리하고,
# svc.sh는 Kubernetes 플랫폼 구성만 담당한다.
install_helm_if_missing

log "애플리케이션 네임스페이스 준비: ${APP_NAMESPACE}"
kubectl create namespace "${APP_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

tag_managed_nodegroups_for_autodiscovery

log "Helm 저장소 등록"
helm repo add eks https://aws.github.io/eks-charts --force-update
helm repo add autoscaler https://kubernetes.github.io/autoscaler --force-update
helm repo add external-secrets https://charts.external-secrets.io --force-update
helm repo update

log "AWS Load Balancer Controller CRD 적용"
helm show crds eks/aws-load-balancer-controller \
  --version "${AWS_LBC_CHART_VERSION}" | kubectl apply -f -

log "AWS Load Balancer Controller 설치 또는 업그레이드"
# LBC용 IAM 권한은 Terraform의 Pod Identity Association으로 연결되므로
# Helm은 Terraform이 참조할 이름의 Kubernetes ServiceAccount만 생성한다.
# MGMT Node의 taint를 허용하고 label을 선택해 LBC를 플랫폼 노드에 배치한다.
helm upgrade --install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  --namespace "${KUBE_NAMESPACE}" \
  --version "${AWS_LBC_CHART_VERSION}" \
  --set "clusterName=${CLUSTER_NAME}" \
  --set "region=${AWS_REGION}" \
  --set "vpcId=${VPC_ID}" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller-sa \
  --set replicaCount=2 \
  --set podDisruptionBudget.maxUnavailable=1 \
  --set-json 'updateStrategy={"type":"RollingUpdate","rollingUpdate":{"maxSurge":1,"maxUnavailable":0}}' \
  --set-json "topologySpreadConstraints=$(platform_topology_constraints aws-load-balancer-controller aws-load-balancer-controller)" \
  --set-string "nodeSelector.${MGMT_NODE_LABEL_KEY}=${MGMT_NODE_LABEL_VALUE}" \
  --set-string "tolerations[0].key=${MGMT_TAINT_KEY}" \
  --set-string "tolerations[0].operator=Equal" \
  --set-string "tolerations[0].value=${MGMT_TAINT_VALUE}" \
  --set-string "tolerations[0].effect=${MGMT_TAINT_EFFECT}" \
  --set-string 'ingressClassParams.spec.subnets.tags.Tier[0]=public' \
  --set-string "podLabels.workload=mgmt" \
  --wait \
  --timeout 10m

log "Cluster Autoscaler 설치 또는 업그레이드"
# Cluster Autoscaler용 IAM 권한은 Terraform의 Pod Identity Association으로 연결하고
# 기존 APP/MGMT 전체 Managed Node Group 자동 탐색 로직은 유지한다.
# MGMT Node의 taint를 허용하고 label을 선택해 Autoscaler Pod를 플랫폼 노드에 배치한다.
helm upgrade --install cluster-autoscaler \
  autoscaler/cluster-autoscaler \
  --namespace "${KUBE_NAMESPACE}" \
  --version "${CLUSTER_AUTOSCALER_CHART_VERSION}" \
  --set cloudProvider=aws \
  --set "awsRegion=${AWS_REGION}" \
  --set "autoDiscovery.clusterName=${CLUSTER_NAME}" \
  --set "image.tag=${CLUSTER_AUTOSCALER_VERSION}" \
  --set rbac.serviceAccount.create=true \
  --set rbac.serviceAccount.name=cluster-autoscaler-sa \
  --set replicaCount=2 \
  --set extraArgs.leader-elect=true \
  --set podDisruptionBudget.maxUnavailable=1 \
  --set-json 'updateStrategy={"type":"RollingUpdate","rollingUpdate":{"maxSurge":1,"maxUnavailable":0}}' \
  --set-json "topologySpreadConstraints=$(platform_topology_constraints aws-cluster-autoscaler cluster-autoscaler)" \
  --set-string "nodeSelector.${MGMT_NODE_LABEL_KEY}=${MGMT_NODE_LABEL_VALUE}" \
  --set-string "tolerations[0].key=${MGMT_TAINT_KEY}" \
  --set-string "tolerations[0].operator=Equal" \
  --set-string "tolerations[0].value=${MGMT_TAINT_VALUE}" \
  --set-string "tolerations[0].effect=${MGMT_TAINT_EFFECT}" \
  --set extraArgs.balance-similar-node-groups=true \
  --set extraArgs.expander=least-waste \
  --set-string "additionalLabels.workload=mgmt" \
  --wait \
  --timeout 10m

log "External Secrets Operator 설치 또는 업그레이드"
# ESO Controller가 AWS Secrets Manager와 Parameter Store에 접근할 권한은
# Terraform에서 external-secrets-sa와 Pod Identity Association으로 연결한다.
# global 스케줄링 값이 controller/webhook/cert-controller 모두에 적용되도록 설정한다.
helm upgrade --install external-secrets \
  external-secrets/external-secrets \
  --namespace "${ESO_NAMESPACE}" \
  --create-namespace \
  --version "${ESO_CHART_VERSION}" \
  --set installCRDs=true \
  --set serviceAccount.create=true \
  --set serviceAccount.name=external-secrets-sa \
  --set replicaCount=2 \
  --set webhook.replicaCount=2 \
  --set certController.replicaCount=2 \
  --set leaderElect=true \
  --set podDisruptionBudget.enabled=true \
  --set podDisruptionBudget.minAvailable=1 \
  --set webhook.podDisruptionBudget.enabled=true \
  --set webhook.podDisruptionBudget.minAvailable=1 \
  --set certController.podDisruptionBudget.enabled=true \
  --set certController.podDisruptionBudget.minAvailable=1 \
  --set-json 'strategy={"type":"RollingUpdate","rollingUpdate":{"maxSurge":1,"maxUnavailable":0}}' \
  --set-json 'webhook.strategy={"type":"RollingUpdate","rollingUpdate":{"maxSurge":1,"maxUnavailable":0}}' \
  --set-json 'certController.strategy={"type":"RollingUpdate","rollingUpdate":{"maxSurge":1,"maxUnavailable":0}}' \
  --set-json "topologySpreadConstraints=$(platform_topology_constraints external-secrets external-secrets)" \
  --set-json "webhook.topologySpreadConstraints=$(platform_topology_constraints external-secrets-webhook external-secrets)" \
  --set-json "certController.topologySpreadConstraints=$(platform_topology_constraints external-secrets-cert-controller external-secrets)" \
  --set-string "global.nodeSelector.${MGMT_NODE_LABEL_KEY}=${MGMT_NODE_LABEL_VALUE}" \
  --set-string "global.tolerations[0].key=${MGMT_TAINT_KEY}" \
  --set-string "global.tolerations[0].operator=Equal" \
  --set-string "global.tolerations[0].value=${MGMT_TAINT_VALUE}" \
  --set-string "global.tolerations[0].effect=${MGMT_TAINT_EFFECT}" \
  --set-string "global.podLabels.workload=mgmt" \
  --wait \
  --timeout 10m

kubectl wait --for=condition=Established \
  crd/secretstores.external-secrets.io \
  crd/externalsecrets.external-secrets.io \
  --timeout=120s

log "컨트롤러 상태 확인"
kubectl rollout status deployment/aws-load-balancer-controller \
  --namespace "${KUBE_NAMESPACE}" \
  --timeout=5m

# 고정된 Cluster Autoscaler 9.59.0 Chart가 생성하는 실제 Deployment 이름을 사용한다.
kubectl rollout status deployment/cluster-autoscaler-aws-cluster-autoscaler \
  --namespace "${KUBE_NAMESPACE}" \
  --timeout=5m

# 고정된 ESO 2.10.0 Chart가 생성하는 세 Deployment를 각각 확인한다.
for deployment_name in external-secrets external-secrets-webhook external-secrets-cert-controller; do
  kubectl rollout status "deployment/${deployment_name}" \
  --namespace "${ESO_NAMESPACE}" \
  --timeout=5m
done

kubectl get deployment \
  --namespace "${KUBE_NAMESPACE}" \
  --selector='app.kubernetes.io/instance in (aws-load-balancer-controller,cluster-autoscaler)'

kubectl get deployment \
  --namespace "${ESO_NAMESPACE}" \
  --selector=app.kubernetes.io/instance=external-secrets

# Terraform Pod Identity와 연결될 정확한 플랫폼 ServiceAccount 이름을 검증한다.
kubectl get serviceaccount \
  aws-load-balancer-controller-sa \
  cluster-autoscaler-sa \
  --namespace "${KUBE_NAMESPACE}"

kubectl get serviceaccount \
  external-secrets-sa \
  --namespace "${ESO_NAMESPACE}"

# svc.sh가 설치한 각 플랫폼의 Ready Pod 두 개가 서로 다른 MGMT Node/AZ에 배치됐는지 확인한다.
verify_platform_pod_nodes \
  "${KUBE_NAMESPACE}" \
  "app.kubernetes.io/name=aws-load-balancer-controller,app.kubernetes.io/instance=aws-load-balancer-controller" \
  "AWS Load Balancer Controller"
verify_platform_pod_nodes \
  "${KUBE_NAMESPACE}" \
  "app.kubernetes.io/name=aws-cluster-autoscaler,app.kubernetes.io/instance=cluster-autoscaler" \
  "Cluster Autoscaler"
verify_platform_pod_nodes \
  "${ESO_NAMESPACE}" \
  "app.kubernetes.io/name=external-secrets,app.kubernetes.io/instance=external-secrets" \
  "ESO controller"
verify_platform_pod_nodes \
  "${ESO_NAMESPACE}" \
  "app.kubernetes.io/name=external-secrets-webhook,app.kubernetes.io/instance=external-secrets" \
  "ESO webhook"
verify_platform_pod_nodes \
  "${ESO_NAMESPACE}" \
  "app.kubernetes.io/name=external-secrets-cert-controller,app.kubernetes.io/instance=external-secrets" \
  "ESO cert-controller"

log "설치가 완료되었습니다. 다음으로 ESO.yaml과 ExternalSecret을 적용하세요."
