#!/bin/bash
set -e


REGION="ap-northeast-2"

echo "[1/3] AWS에서 VPC 및 서브넷 ID 조회 중..."


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
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=retail-*-a" "Name=tag:Tier,Values=Private" "Name=tag:Purpose,Values=app" \
  --query "Subnets[0].SubnetId" \
  --output text)

APP_c=$(aws ec2 describe-subnets \
  --region "$REGION" \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=retail-*-c" "Name=tag:Tier,Values=Private" "Name=tag:Purpose,Values=app" \
  --query "Subnets[0].SubnetId" \
  --output text)


export VPC_ID
export APP_a
export APP_c

echo "조회 결과:"
echo " - VPC_ID : $VPC_ID"
echo " - APP_a  : $APP_a"
echo " - APP_c  : $APP_c"


echo "[2/3] cluster.yaml 생성 중..."


envsubst '${VPC_ID} ${APP_a} ${APP_c}' < cluster.template.yaml > cluster.yaml

echo "[3/3] 완료! cluster.yaml 파일이 생성되었습니다."
