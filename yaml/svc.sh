#!/usr/bin/env bash
set -Eeuo pipefail

# Run this script after Terraform has created the EKS cluster
# and configured workload IAM / EKS Pod Identity.
#
# This script bootstraps platform components inside the cluster.
# The retail application itself remains managed by GitOps.

CLUSTER_NAME="${CLUSTER_NAME:-retail-eks-cluster}"
AWS_REGION="${AWS_REGION:-ap-northeast-2}"
KUBE_NAMESPACE="${KUBE_NAMESPACE:-kube-system}"
APP_NAMESPACE="${APP_NAMESPACE:-retail-store}"
ESO_NAMESPACE="${ESO_NAMESPACE:-external-secrets}"
CART_TABLE_NAME="${CART_TABLE_NAME:-retail-store-cart}"

HELM_VERSION="${HELM_VERSION:-v3.21.4}"
HELM_INSTALL_DIR="${HELM_INSTALL_DIR:-/usr/local/bin}"

AWS_LBC_VERSION="${AWS_LBC_VERSION:-v3.5.0}"
AWS_LBC_CHART_VERSION="${AWS_LBC_CHART_VERSION:-3.5.0}"

CLUSTER_AUTOSCALER_VERSION="${CLUSTER_AUTOSCALER_VERSION:-v1.36.0}"
CLUSTER_AUTOSCALER_CHART_VERSION="${CLUSTER_AUTOSCALER_CHART_VERSION:-9.59.0}"

ESO_CHART_VERSION="${ESO_CHART_VERSION:-2.10.0}"
ESO_POLICY_NAME="${ESO_POLICY_NAME:-RetailStoreESOReadPolicy-${CLUSTER_NAME}-v1}"
CART_POLICY_NAME="${CART_POLICY_NAME:-RetailStoreCartDynamoDBPolicy-${CLUSTER_NAME}-v1}"

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

for command_name in aws kubectl curl; do
  require_command "${command_name}"
done

WORK_DIR="$(mktemp -d)"

log "AWS 자격 증명 및 EKS 클러스터 확인"
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

# 기존 IAM Policy 생성 로직은 유지합니다. ServiceAccount 생성 방식만 Helm으로 전환합니다.
AWS_LBC_POLICY_FILE="${WORK_DIR}/aws-load-balancer-controller-policy.json"
CLUSTER_AUTOSCALER_POLICY_FILE="${WORK_DIR}/cluster-autoscaler-policy.json"
ESO_POLICY_FILE="${WORK_DIR}/external-secrets-policy.json"
CART_POLICY_FILE="${WORK_DIR}/cart-dynamodb-policy.json"

cat >"${ESO_POLICY_FILE}" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadRetailParameters",
      "Effect": "Allow",
      "Action": ["ssm:GetParameter"],
      "Resource": "arn:aws:ssm:${AWS_REGION}:${AWS_ACCOUNT_ID}:parameter/retail-store/*"
    },
    {
      "Sid": "ReadRetailSecrets",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue",
        "secretsmanager:DescribeSecret"
      ],
      "Resource": "arn:aws:secretsmanager:${AWS_REGION}:${AWS_ACCOUNT_ID}:secret:retail-store/*"
    }
  ]
}
EOF

cat >"${CART_POLICY_FILE}" <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadWriteCartItems",
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query"
      ],
      "Resource": "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/${CART_TABLE_NAME}"
    },
    {
      "Sid": "QueryCartIndexes",
      "Effect": "Allow",
      "Action": ["dynamodb:Query"],
      "Resource": "arn:aws:dynamodb:${AWS_REGION}:${AWS_ACCOUNT_ID}:table/${CART_TABLE_NAME}/index/*"
    }
  ]
}
EOF

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
ESO_POLICY_ARN="$(ensure_iam_policy \
  "${ESO_POLICY_NAME}" \
  "${ESO_POLICY_FILE}")"
CART_POLICY_ARN="$(ensure_iam_policy \
  "${CART_POLICY_NAME}" \
  "${CART_POLICY_FILE}")"

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
# 기존: aws-load-balancer-controller 서비스 어카운트를 사전 생성하고 create=false
# 변경: Helm이 aws-load-balancer-controller-sa를 생성
helm upgrade --install aws-load-balancer-controller \
  eks/aws-load-balancer-controller \
  --namespace "${KUBE_NAMESPACE}" \
  --version "${AWS_LBC_CHART_VERSION}" \
  --set "clusterName=${CLUSTER_NAME}" \
  --set "region=${AWS_REGION}" \
  --set "vpcId=${VPC_ID}" \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller-sa \
  --set-string 'ingressClassParams.spec.subnets.tags.Tier[0]=public' \
  --wait \
  --timeout 10m

log "Cluster Autoscaler 설치 또는 업그레이드"
# 기존: cluster-autoscaler 서비스 어카운트를 사전 생성하고 create=false
# 변경: Helm이 cluster-autoscaler-sa를 생성
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
  --set extraArgs.balance-similar-node-groups=true \
  --set extraArgs.expander=least-waste \
  --wait \
  --timeout 10m

log "External Secrets Operator 설치 또는 업그레이드"
# 기존: Helm 기본 서비스 어카운트 이름 external-secrets 사용
# 변경: Helm이 external-secrets-sa를 생성
helm upgrade --install external-secrets \
  external-secrets/external-secrets \
  --namespace "${ESO_NAMESPACE}" \
  --create-namespace \
  --version "${ESO_CHART_VERSION}" \
  --set installCRDs=true \
  --set serviceAccount.create=true \
  --set serviceAccount.name=external-secrets-sa \
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

kubectl rollout status deployment \
  --namespace "${KUBE_NAMESPACE}" \
  --selector=app.kubernetes.io/instance=cluster-autoscaler \
  --timeout=5m

kubectl rollout status deployment \
  --namespace "${ESO_NAMESPACE}" \
  --selector=app.kubernetes.io/instance=external-secrets \
  --timeout=5m

kubectl get deployment \
  --namespace "${KUBE_NAMESPACE}" \
  --selector='app.kubernetes.io/instance in (aws-load-balancer-controller,cluster-autoscaler)'

kubectl get deployment \
  --namespace "${ESO_NAMESPACE}" \
  --selector=app.kubernetes.io/instance=external-secrets

# 기존: 스크립트가 별도 애플리케이션 서비스 어카운트를 확인
# 변경: Helm이 생성한 플랫폼 서비스 어카운트를 확인
kubectl get serviceaccount \
  aws-load-balancer-controller-sa \
  cluster-autoscaler-sa \
  --namespace "${KUBE_NAMESPACE}"

kubectl get serviceaccount \
  external-secrets-sa \
  --namespace "${ESO_NAMESPACE}"

log "설치가 완료되었습니다. 다음으로 ESO.yaml과 ExternalSecret을 적용하세요."
