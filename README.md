# retail-store-infra

AWSome-BIT-Bespin의 AWS 기반 인프라를 Terraform으로 관리합니다. 실제 WSL 작업 경로는 `/home/yong/project`입니다.
VPC·EKS·PostgreSQL을 세 모듈로 나누고, 루트에서는 모듈 연결과 환경값을 관리합니다.

## 저장소별 담당 범위

| 저장소 | 관리할 내용 |
| --- | --- |
| [retail-store-infra](https://github.com/AWSome-BIT-Bespin/retail-store-infra) | VPC, subnet, routing, NAT, EKS, Node Group, EKS managed add-ons, RDS, Security Group, IAM 및 향후 ECR·ACM·Route 53·앱 AWS 권한 |
| [retail-store-gitops](https://github.com/AWSome-BIT-Bespin/retail-store-gitops) | Helm values/chart, Deployment, Service, Ingress, Namespace, HPA/PDB, 컨트롤러 설치 설정, Secret 참조 및 Argo CD Application |
| [retail-store-app](https://github.com/AWSome-BIT-Bespin/retail-store-app) | 애플리케이션 소스, 테스트, Dockerfile, 빌드·이미지 게시 CI |

Terraform은 AWS API로 클러스터와 외부 서비스를 구성합니다. GitOps 컨트롤러는 Kubernetes API로 클러스터 내부 배포 상태를 맞춥니다.
ALB/NLB의 실제 생성은 AWS Load Balancer Controller가 담당하고 Terraform에서는 그 컨트롤러의 IAM 권한 등을 준비합니다.
같은 ALB를 Terraform `aws_lb`로도 선언하지 않습니다.

현재 구현된 모듈은 VPC, EKS, RDS입니다. ECR/ACM/Route 53/앱 IAM 및 GitOps 부트스트랩은 아직 추가하지 않았습니다.
리팩터링과 신규 AWS 리소스 도입을 같은 변경으로 섞지 않습니다.

## 디렉터리

```text
.
├── main.tf                  # VPC -> EKS / RDS 연결
├── variables.tf             # 환경 입력의 자료형·검증
├── terraform.tfvars         # 현재 환경값, 비밀값 없음
├── versions.tf              # Terraform 및 AWS provider 버전
├── providers.tf             # AWS 리전
├── backend.tf               # 기존 S3 backend 공통값
├── backend-infra.hcl        # 현재 prod state key
├── backend-dev.hcl          # 과거 dev state key, 현재 root에서 전환하지 않음
├── moved.tf                 # 기존 루트 리소스 16개의 주소 이동 이력
├── outputs.tf               # 팀 전달값
├── Makefile                 # fmt / check / init / plan
├── modules/
│   ├── vpc/                 # VPC·서브넷·NAT·라우팅
│   ├── eks/                 # EKS·IAM·접근 권한·노드·애드온
│   └── rds/                 # DB·subnet group·DB 보안 그룹
└── docs/
    ├── migration.md         # 리팩터링 반영·state 확인
    └── ownership.md         # 팀 업무 경계와 GitOps 전달 절차
```

각 모듈의 `variables.tf`는 입력, `outputs.tf`는 외부에 전달할 값입니다.
같은 모듈 안에서만 사용할 리소스 ID는 직접 참조하고, 모듈 사이에서는 입력/output으로 연결합니다.
`.tf` 파일을 역할별로 나누는 것은 가독성을 위한 것이며 state가 나뉘지는 않습니다.
SG나 IAM 역할 하나마다 모듈을 만들지 않고, EKS 또는 RDS의 수명 주기에 맞춰 같은 모듈 안에 둡니다.

## 환경값 변경

대부분의 변경은 `terraform.tfvars`에서 합니다.

| 변경할 내용 | 입력값 |
| --- | --- |
| API 접속 가능 네트워크 | `eks_public_access_cidrs` |
| 관리자 IAM 주체 | `eks_admin_principal_arn` |
| 노드 수·유형 | `eks_node_scaling`, `eks_node_instance_types` |
| 애드온 버전 고정 | `eks_addon_versions` |
| DB 버전·사양 | `rds_engine_version`, `rds_instance_class` |
| DB 고가용성·백업·삭제 정책 | `rds_multi_az`, `rds_backup_retention_period`, `rds_deletion_protection`, `rds_skip_final_snapshot` |
| DB 접근 허용 | `rds_client_security_group_ids` |

현재 설정은 원래 코드의 동작을 보존합니다. DB 접근 규칙은 빈 집합이며, EKS API CIDR은 `0.0.0.0/0`입니다.
앱 접속을 열 때에는 실제 Pod/노드 ENI의 SG를 확인해 넣고, 관리자 접속망 CIDR도 팀 운영 방식에 맞춰 별도로 제한하세요.
`rds_skip_final_snapshot=false`로 바꾸면 `rds_final_snapshot_identifier`도 지정해야 합니다.

현재 `worldload` 노드 라벨 키와 일부 dev 이름 태그도 보존했습니다. 기존 selector와 리소스 변경을 검토한 후 별도 변경으로 정리하세요.
`availability_zones=[]`는 기존의 AZ 자동 선택을 유지합니다. 첫 검토에서 확인된 AZ 두 개를 이후 명시적으로 고정할 수 있습니다.

## 일상 작업

```bash
cd /home/yong/project
terraform init -lockfile=readonly -backend-config=backend-infra.hcl
terraform fmt -recursive
terraform validate
terraform plan -out=review.tfplan
terraform show review.tfplan
```

실제 변경을 검토하고 반영할 때만 `terraform apply review.tfplan`을 실행합니다.
생성된 plan, state, 비밀번호를 Git에 넣지 않습니다. `.terraform.lock.hcl`은 Git에 유지합니다.
현재 state 위치를 처음 확인하거나 모듈 이동을 반영할 때는 [migration.md](docs/migration.md)를 먼저 읽으세요.

## 현재 state

- 리전: `ap-northeast-2`
- workspace: `default`
- S3 bucket: `retail-terraform-state-350606136784-ap-northeast-2-an`
- 현재 key: `infra/prod/terraform.tfstate`

모듈별 state 분리는 하지 않았습니다. 현재 규모에서는 모듈 간 연결과 변경 검토를 한 plan으로 유지하는 편이 단순합니다.
dev를 실제로 추가할 때에는 별도 `environments/dev` root와 입력값·backend·리소스 이름/CIDR을 구성하세요.
backend key만 dev로 바꾸면 동일 이름의 AWS 리소스를 다른 state에서 다시 만들려 할 수 있습니다.
S3 state bucket 자체를 그 bucket을 사용하는 이 root에 추가하지 않습니다. 향후 bootstrap root에서 별도 관리합니다.

공식 참고: [Terraform 모듈 구조](https://developer.hashicorp.com/terraform/language/modules/develop/structure), [리소스 주소 이동](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring).
