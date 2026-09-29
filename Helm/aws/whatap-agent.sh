#!/usr/bin/env bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

helm repo add whatap https://whatap.github.io/helm/
helm repo update

# 설치 시 retail-store 프로젝트에 보입니다.
kubectl create ns whatap-monitoring
export WHATAP_HOST=13.124.11.223/13.209.172.35
export WHATAP_LICENSE=x60679o83rkup-x1k9q8fdekh0su-z3q0kr7iqgh62r
export WHATAP_PORT=6600
kubectl create secret generic whatap-credentials --namespace whatap-monitoring --from-literal WHATAP_LICENSE=$WHATAP_LICENSE --from-literal WHATAP_HOST=$WHATAP_HOST --from-literal WHATAP_PORT=$WHATAP_PORT
helm install whatap-operator whatap/whatap-operator --namespace whatap-monitoring \
  --values "${SCRIPT_DIR}/whatap-operator-values.yaml"

kubectl apply -f "${SCRIPT_DIR}/whatap_operator.yaml"
