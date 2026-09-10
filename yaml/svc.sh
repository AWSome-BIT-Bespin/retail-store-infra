#!/usr/bin/env bash
set -Eeuo pipefail

# Run this script after create-cluster.sh has created the EKS cluster.
# The retail application itself remains managed by GitOps with:
#   values.yaml + values-dev-rds.yaml

CLUSTER_NAME="${CLUSTER_NAME:-retail-infra-eks}"
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
KUBE_NAMESPACE="${KUBE_NAMESPACE:-kube-system}"

HELM_VERSION="${HELM_VERSION:-v3.21.4}"
HELM_INSTALL_DIR="${HELM_INSTALL_DIR:-/usr/local/bin}"

AWS_LBC_VERSION="${AWS_LBC_VERSION:-v3.5.0}"
AWS_LBC_CHART_VERSION="${AWS_LBC_CHART_VERSION:-3.5.0}"

CLUSTER_AUTOSCALER_VERSION="${CLUSTER_AUTOSCALER_VERSION:-v1.36.0}"
CLUSTER_AUTOSCALER_CHART_VERSION="${CLUSTER_AUTOSCALER_CHART_VERSION:-9.59.0}"

AWS_LBC_POLICY_VERSION="${AWS_LBC_VERSION#v}"
AWS_LBC_POLICY_VERSION="${AWS_LBC_POLICY_VERSION//./-}"
CLUSTER_AUTOSCALER_POLICY_VERSION="${CLUSTER_AUTOSCALER_VERSION#v}"
CLUSTER_AUTOSCALER_POLICY_VERSION="${CLUSTER_AUTOSCALER_POLICY_VERSION//./-}"

AWS_LBC_POLICY_NAME="${AWS_LBC_POLICY_NAME:-AWSLoadBalancerControllerIAMPolicy-${AWS_LBC_POLICY_VERSION}}"
CLUSTER_AUTOSCALER_POLICY_NAME="${CLUSTER_AUTOSCALER_POLICY_NAME:-ClusterAutoscalerPolicy-${CLUSTER_NAME}-${CLUSTER_AUTOSCALER_POLICY_VERSION}}"

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

ensure_iam_policy() {
  local policy_name="$1"
  local policy_file="$2"
  local policy_arn="arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${policy_name}"

  if aws iam get-policy --policy-arn "${policy_arn}" >/dev/null 2>&1; then
    log "기존 IAM 정책 사용: ${policy_arn}" >&2
  else
    log "IAM 정책 생성: ${policy_name}" >&2
    aws iam create-policy \
      --policy-name "${policy_name}" \
      --policy-document "file://${policy_file}" \
      --no-cli-pager >/dev/null
  fi

  printf '%s\n' "${policy_arn}"
}

ensure_irsa_service_account() {
  local service_account_name="$1"
  local policy_arn="$2"

  log "IRSA ServiceAccount 구성: ${service_account_name}"
  eksctl create iamserviceaccount \
    --cluster "${CLUSTER_NAME}" \
    --region "${AWS_REGION}" \
    --namespace "${KUBE_NAMESPACE}" \
    --name "${service_account_name}" \
    --attach-policy-arn "${policy_arn}" \
    --override-existing-serviceaccounts \
    --approve
}

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

for command_name in aws kubectl eksctl curl; do
  require_command "${command_name}"
done

WORK_DIR="$(mktemp -d)"

log "AWS 로그인 및 EKS 클러스터 확인"
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
[[ "${AWS_ACCOUNT_ID}" =~ ^[0-9]{12}$ ]] || die "AWS 계정 ID를 확인하지 못했습니다."

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

install_helm_if_missing

log "클러스터 IAM OIDC Provider 확인"
eksctl utils associate-iam-oidc-provider \
  --cluster "${CLUSTER_NAME}" \
  --region "${AWS_REGION}" \
  --approve

AWS_LBC_POLICY_FILE="${WORK_DIR}/aws-load-balancer-controller-policy.json"
CLUSTER_AUTOSCALER_POLICY_FILE="${WORK_DIR}/cluster-autoscaler-policy.json"

log "AWS Load Balancer Controller ${AWS_LBC_VERSION} IAM 정책 다운로드"
curl -fsSL -o "${AWS_LBC_POLICY_FILE}" \
  "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/${AWS_LBC_VERSION}/docs/install/iam_policy.json"

cat >"${CLUSTER_AUTOSCALER_POLICY_FILE}" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:SetDesiredCapacity",
        "autoscaling:TerminateInstanceInAutoScalingGroup"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/k8s.io/cluster-autoscaler/enabled": "true",
          "aws:ResourceTag/k8s.io/cluster-autoscaler/${CLUSTER_NAME}": "owned"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeScalingActivities",
        "autoscaling:DescribeTags",
        "ec2:DescribeImages",
        "ec2:DescribeInstanceTypes",
        "ec2:DescribeLaunchTemplateVersions",
        "ec2:GetInstanceTypesFromInstanceRequirements",
        "eks:DescribeNodegroup"
      ],
      "Resource": "*"
    }
  ]
}
EOF

AWS_LBC_POLICY_ARN="$(ensure_iam_policy \
  "${AWS_LBC_POLICY_NAME}" \
  "${AWS_LBC_POLICY_FILE}")"
CLUSTER_AUTOSCALER_POLICY_ARN="$(ensure_iam_policy \
  "${CLUSTER_AUTOSCALER_POLICY_NAME}" \
  "${CLUSTER_AUTOSCALER_POLICY_FILE}")"

ensure_irsa_service_account \
  "aws-load-balancer-controller" \
  "${AWS_LBC_POLICY_ARN}"
ensure_irsa_service_account \
  "cluster-autoscaler" \
  "${CLUSTER_AUTOSCALER_POLICY_ARN}"

tag_managed_nodegroups_for_autodiscovery

log "Helm 저장소 등록"
helm repo add eks https://aws.github.io/eks-charts --force-update
helm repo add autoscaler https://kubernetes.github.io/autoscaler --force-update
helm repo update

log "AWS Load Balancer Controller CRD 적용"
helm show crds eks/aws-load-balancer-controller \
  --version "${AWS_LBC_CHART_VERSION}" | kubectl apply -f -

log "AWS Load Balancer Controller 설치 또는 업그레이드"
helm upgrade --install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  --namespace "${KUBE_NAMESPACE}" \
  --version "${AWS_LBC_CHART_VERSION}" \
  --set "clusterName=${CLUSTER_NAME}" \
  --set "region=${AWS_REGION}" \
  --set "vpcId=${VPC_ID}" \
  --set serviceAccount.create=false \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set-string 'ingressClassParams.spec.subnets.tags.Tier[0]=public' \
  --wait \
  --timeout 10m

log "Cluster Autoscaler 설치 또는 업그레이드"
helm upgrade --install cluster-autoscaler \
  autoscaler/cluster-autoscaler \
  --namespace "${KUBE_NAMESPACE}" \
  --version "${CLUSTER_AUTOSCALER_CHART_VERSION}" \
  --set cloudProvider=aws \
  --set "awsRegion=${AWS_REGION}" \
  --set "autoDiscovery.clusterName=${CLUSTER_NAME}" \
  --set "image.tag=${CLUSTER_AUTOSCALER_VERSION}" \
  --set rbac.serviceAccount.create=false \
  --set rbac.serviceAccount.name=cluster-autoscaler \
  --set extraArgs.balance-similar-node-groups=true \
  --set extraArgs.expander=least-waste \
  --wait \
  --timeout 10m

log "컨트롤러 상태 확인"
kubectl rollout status deployment/aws-load-balancer-controller \
  --namespace "${KUBE_NAMESPACE}" \
  --timeout=5m
kubectl rollout status deployment/cluster-autoscaler \
  --namespace "${KUBE_NAMESPACE}" \
  --timeout=5m

kubectl get deployment \
  aws-load-balancer-controller cluster-autoscaler \
  --namespace "${KUBE_NAMESPACE}"

log "설치가 완료되었습니다."
