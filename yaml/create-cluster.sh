#!/bin/bash
set -e


REGION="ap-northeast-2"

echo "[1/5] AWS에서 VPC 및 서브넷 ID 조회 중..."


VPC_ID=$(aws ec2 describe-vpcs \
  --region "$REGION" \
  --filters "Name=tag:Name,Values=retail*" \
  --query "Vpcs[0].VpcId" \
  --output text)

if [ "$VPC_ID" == "None" ] || [ -z "$VPC_ID" ]; then
  echo "❌ VPC를 찾을 수 없습니다."
  exit 1
fi

# VPC 내부에서 Name 태그 기준으로 Subnet ID 가져오기
APP_a=$(aws ec2 describe-subnets \
  --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=retail-*-a" "Name=tag:Tier,Values=private" "Name=tag:Purpose,Values=app" \
  --query "Subnets[0].SubnetId" \
  --output text)

APP_c=$(aws ec2 describe-subnets \
  --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=retail-*-c" "Name=tag:Tier,Values=private" "Name=tag:Purpose,Values=app" \
  --query "Subnets[0].SubnetId" \
  --output text)


export VPC_ID
export APP_a
export APP_c

echo "조회 결과:"
echo " - VPC_ID : $VPC_ID"
echo " - APP_a  : $APP_a"
echo " - APP_c  : $APP_c"


echo "[2/5] cluster.yaml 생성 중..."


envsubst '${VPC_ID} ${APP_a} ${APP_c}' < cluster.template.yaml > cluster.yaml

echo "[3/5] 완료! cluster.yaml 파일이 생성되었습니다."

# 클러스터 생성 (선택 사항)
echo "[4/5] EKS 클러스터 생성 시작..."
eksctl create cluster -f cluster.yaml || true
# 생성 완료 후 443 포트 추가
echo "[5/5] EKS 클러스터 보안 그룹에 443 포트 오픈 중..."
CLUSTER_SG=$(aws eks describe-cluster \
  --name "retailstore-eks-cluster" \
  --region "$REGION" \
  --query "cluster.resourcesVpcConfig.clusterSecurityGroupId" \
  --output text)
# 이미 룰이 존재할 때 에러가 발생하지 않도록 예외 처리 권장
aws ec2 authorize-security-group-ingress \
  --group-id "$CLUSTER_SG" \
  --protocol tcp \
  --port 443 \
  --cidr "0.0.0.0/0" \
  --region "$REGION" || echo "⚠️ 이미 등록된 규칙이거나 실패했습니다."
echo "✅ 모든 작업이 완료되었습니다."