# Terraform, GitOps, 앱 담당 업무

## Terraform 담당

현재 VPC·서브넷·NAT·라우팅, EKS·노드 그룹·관리자 접근, VPC CNI/CoreDNS/kube-proxy EKS 애드온, PostgreSQL·DB subnet group·보안 그룹을 관리합니다.
필요해질 때 ECR, ACM 인증서, Route 53 zone/record, 컨트롤러·앱 IAM 역할, Pod Identity/IRSA 연결을 추가합니다.
IAM은 워크로드가 필요한 AWS 리소스 단위로 제한하고 노드 역할에 앱 권한을 계속 합치지 않습니다.

Kubernetes API를 사용하지 않는 현재 인프라 root는 클러스터 내부 앱의 상태와 독립적으로 plan할 수 있습니다.
GitOps 컨트롤러 설치를 추가하면 별도 `bootstrap` root 또는 문서화된 Helm 절차로 분리합니다.
Argo CD 첫 설치/최상위 Application 등록은 담당자를 지정하고, 이후 자체 관리 주체를 확정합니다.
Terraform Helm release와 Argo CD Application이 동일 release를 동시에 관리하지 않습니다.

## GitOps 담당

기존 `src/<service>/chart` 구조를 유지하며 환경 values로 배포 차이를 관리합니다.
추후 `platform/`에는 Argo CD Application, AWS Load Balancer Controller, External Secrets, Metrics Server, 관측 도구의 chart/values를 모을 수 있습니다.
이미 Terraform으로 관리 중인 EKS 애드온 세 개는 GitOps chart로 다시 설치하지 않습니다.

ALB가 필요할 때 Ingress를 선언하고 Controller가 생성하도록 합니다. 앱 Service를 Terraform에서 중복 선언하지 않습니다.
DNS는 Route 53 리소스를 Terraform으로 고정 관리할지, ExternalDNS가 해당 레코드를 관리할지 한 가지 소유자를 정합니다.

## 현재 PostgreSQL 연결에서 조율할 항목

공개 `retail-store-gitops/src/app/chart/values-dev-rds.yaml`에서 PostgreSQL provider, database `orders`, 내장 postgresql 활성화 설정을 확인했습니다.
이 파일이 실제 릴리스에 선택되는지는 클러스터/Argo CD에서 확인해야 합니다.
Terraform의 현재 최초 DB 이름은 `retail`입니다. RDS로 연결할 때 다음을 함께 맞추세요.

1. `orders` 앱이 사용할 DB를 결정합니다. 기존 RDS를 교체하며 `db_name`을 바꾸지 말고, 필요하면 관리 SQL로 `orders` DB/앱 계정을 생성하고 소유권·권한을 부여합니다.
2. 앱 Helm values에서 내장 PostgreSQL을 끄고 실제 RDS 호스트·포트·DB 이름을 지정합니다. 정확한 values 키는 해당 chart의 템플릿에 맞춥니다.
3. 앱 Pod/노드 ENI SG를 확인해 `rds_client_security_group_ids`에 넣습니다. SG for Pods를 쓴다면 노드 SG 대신 실제 Pod SG가 필요할 수 있습니다. 클라이언트 outbound도 확인합니다.
4. 앱 전용 계정을 Secrets Manager에 저장하고, 선택한 External Secrets 또는 앱 SDK 인증 방식에 맞춰 IAM과 Secret 참조를 구성합니다.
5. PostgreSQL TLS 인증서 검증, 마이그레이션, 실제 읽기/쓰기, 로그 확인으로 접속을 검증합니다.

관리자 Secret ARN은 관리용이며 앱의 상시 계정으로 전달하지 않습니다. 비밀번호를 Git의 values에 넣지 않습니다.
Catalog MySQL, Cart DynamoDB, Checkout Redis 등 다른 서비스 저장소가 PostgreSQL 하나로 자동 대체되는 것은 아닙니다.

## 인계 출력

```bash
terraform output network
terraform output eks
terraform output postgres
```

출력은 원격 state에 반영된 값입니다. 구조 변경을 아직 apply하지 않았다면 새 output은 없을 수 있습니다.
Kubernetes 담당자에게는 클러스터 이름/리전, 접근 IAM 역할, VPC·subnet ID, DB host/port/database와 별도로 구성한 앱 Secret ARN을 전달합니다.
앱 담당자는 앱 포트, health endpoint, DB 요구 버전·스키마, 환경변수, 이미지 경로·digest를 제공합니다.

공개 저장소 확인일: 2026-09-09. 이번 변경에서는 다른 저장소나 원격 GitHub 파일을 수정하지 않았습니다.
