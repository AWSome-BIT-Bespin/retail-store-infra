# EKS 모듈

입력: 앱 서브넷 ID, 클러스터·IAM 역할 이름, Kubernetes 버전, 관리자 ARN, API CIDR, 노드 크기·수·라벨, 애드온 버전.
출력: 클러스터 이름·API 주소·클러스터 SG ID, 노드 IAM 역할 ARN.

- `main.tf`: EKS 제어 평면
- `iam.tf`: EKS 서비스 및 EC2 노드 역할
- `access.tf`: 관리자 EKS access entry / policy association
- `nodes.tf`: Managed Node Group
- `addons.tf`: VPC CNI, kube-proxy, CoreDNS

의존 순서는 제어 평면 -> CNI/kube-proxy -> Node Group -> CoreDNS입니다.
CNI와 kube-proxy가 노드 그룹 완료를 기다리도록 바꾸면 초기 노드 준비와 순환 대기가 생길 수 있습니다.

기존 CNI 정책은 노드 역할에 연결되어 있습니다. 향후 CNI 전용 IAM 역할/Pod Identity로 분리할 때 별도 변경으로 검증합니다.
Argo CD, Load Balancer Controller, 앱 Helm release는 이 모듈에서 설치하지 않습니다. 관리 경계는 루트 docs/ownership.md에 있습니다.
클러스터 SG 출력이 모든 앱 트래픽의 SG라는 보장은 없습니다. 실제 ENI 연결을 확인한 뒤 RDS 접근 규칙에 사용하세요.
