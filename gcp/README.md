# 현재 GCP 구성을 Terraform으로 가져오기

2026-09-18에 Google Cloud 콘솔의 `kdt4-3` 프로젝트를 Computer Use로 조회해 작성한 **기존 리소스 인수용 코드**입니다. WSL의 `/home/yong/project/gcp`와 클라우드 리소스는 수정하지 않았습니다.

현재 설치된 Google provider `8.3.0`과 Terraform `1.16.0`으로 `terraform fmt`, `terraform validate`를 실행했습니다. **validate: 오류 0, 경고 0. 실제 계정으로 plan/import/apply는 실행하지 않았으므로 무변경 plan을 보장하는 결과는 아닙니다.**

## 콘솔에서 확인한 구성

| 항목 | 확인 값 |
|---|---|
| 프로젝트 / 리전 / 존 | `kdt4-3` / `asia-northeast3` / `asia-northeast3-a` |
| VPC | `retail-dr-vpc`, Custom, GLOBAL 라우팅, MTU 1460 |
| 관리 서브넷 | `retail-dr-admin-subnet`, `10.10.0.0/20`, Private Google Access 꺼짐 |
| GKE 서브넷 | `retail-dr-gke-subnet`, `10.20.0.0/20`, Private Google Access 켜짐 |
| 현재 사용 중인 Pod 범위 | `gke-retail-dr-gke-pods-89de90ed`, `10.90.0.0/17` |
| 사용하지 않는 보조 범위 | `retail-dr-pods=10.24.0.0/16`, `retail-dr-services=10.25.0.0/20` |
| 실제 GKE Service 범위 | `34.118.224.0/20`, GKE 관리 범위 |
| Cloud Router / NAT | `retail-dr-router-real` / `retail-dr-nat` |
| NAT 설정 | GKE 서브넷의 모든 범위, 자동 IP, Premium, 동적 포트 할당 꺼짐, 로그 꺼짐 |
| PSA 예약 범위 | `google-managed-services-retail-dr-vpc`, `10.40.0.0/16` |
| PSA 연결 | `servicenetworking-googleapis-com`, custom routes import/export 켜짐 |
| GKE | `retail-dr-gke`, Standard, Zonal, REGULAR 채널 |
| 조회 당시 Kubernetes 버전 | `1.35.7-gke.1222000`; 자동 업그레이드를 고려해 코드에 버전 고정하지 않음 |
| 노드 풀 | `retail-dr-pool`, 1대, 자동 확장 꺼짐 |
| 노드 | `n2d-standard-2`, COS_CONTAINERD, pd-balanced 50GB, AMD SEV 켜짐 |
| 노드 업그레이드 | max surge 1 / max unavailable 0 |
| GKE 접근·인증 | Private Nodes, Authorized Networks, DNS 접근, Workload Identity 모두 꺼짐 |
| GKE 엔드포인트 | Public endpoint와 Private endpoint 모두 존재 |
| GKE 서비스 계정 | `retail-dr-gke-node@kdt4-3.iam.gserviceaccount.com` |
| GKE SA 프로젝트 역할 | `roles/container.defaultNodeServiceAccount` |
| 관리 VM | `retail-dr-admin`, e2-micro, Debian 12, pd-standard 10GB, 임시 공인 IP |
| Bastion | `retail-dr-bastion`, e2-medium, Debian 13, pd-balanced 10GB, 공인 IP 없음 |
| Bastion 서비스 계정 | `retail-dr-ops@kdt4-3.iam.gserviceaccount.com`, `roles/container.developer` |
| Bastion 메타데이터 | `enable-osconfig=TRUE`; 인스턴스에 `enable-oslogin` 설정은 없음 |
| Bastion 스냅샷 | 공유 정책 `default-schedule-1`, UTC 02:00 매일, 14일 보관 |

## 파일 구조

```text
gcp-current-20260918/
├── versions.tf              # provider 8.3.0, 프로젝트/리전/존
├── network.tf               # VPC, 서브넷, Router, NAT, 수동 방화벽
├── private-services.tf      # PSA 예약 IP, 연결, 피어링 경로 설정
├── iam.tf                   # 전용 서비스 계정 2개와 현재 프로젝트 역할
├── gke.tf                   # GKE와 노드 풀
├── compute.tf               # admin, bastion, 스냅샷 정책 연결
├── outputs.tf
├── imports.tf               # 기존 리소스 19개 import 블록
├── import-existing.sh       # import 블록 방식 대신 사용할 CLI 명령
├── backend.tf.example
├── backend.hcl.example
├── .terraform.lock.hcl
├── .gitignore
├── COPY_PASTE.md            # 파일별 코드를 한 문서에서 복사
└── README.md
```

값을 콘솔과 대조하기 쉽도록 이 제공본은 파일별 root resource로 구성했습니다. 별도 tfvars 입력은 필요하지 않습니다. 기존 WSL의 module 기반 코드와 resource 주소가 다르므로 **기존 `gcp/` 안에 그대로 합쳐 넣으면 안 됩니다.** 먼저 별도 디렉터리에서 검토한 뒤 최종 관리 주소를 하나로 정하세요.

## 기존 리소스를 연결하는 순서

1. 이 파일들을 별도 디렉터리에 둡니다. 같은 리소스를 이미 관리하는 Terraform state가 있는지 먼저 확인합니다. 기존 GCS state가 있다면 그 state를 기준으로 주소 이동을 설계해야 하며, 새 state에서 중복 소유하면 안 됩니다.
2. 아래 명령은 `kdt4-3` 접근 권한이 있는 사용자로 실행합니다. 브라우저 로그인과 WSL의 Terraform ADC 인증은 별도입니다.

```bash
# gcloud가 설치된 WSL에서, 해당 프로젝트에 접근 가능한 계정으로 인증
gcloud auth application-default login
gcloud auth application-default set-quota-project kdt4-3

# 현재 제공본은 local backend이므로 로컬 검토가 가능함
terraform init
terraform fmt -check
terraform validate
terraform plan -out=adopt.tfplan
```

3. `imports.tf`가 있으므로 plan에서 기존 리소스 조회와 import 예정 내역이 표시됩니다. **19 to import, 0 to add, 0 to change, 0 to destroy**가 목표입니다. `+`, `~`, `-/+`, 삭제 또는 `prevent_destroy` 오류가 나오면 적용하지 말고 실제 값과 코드를 먼저 맞추세요. 이 목표 출력은 아직 실제 실행으로 확인한 출력이 아닙니다.
4. 무변경 import 계획을 확인한 다음에만 저장한 계획을 실행합니다.

```bash
# 위 plan의 내용이 import만 수행한다는 것을 확인한 뒤 실행
terraform apply adopt.tfplan
terraform plan
```

`terraform apply`는 import 외의 변경도 함께 실행할 수 있으므로 plan 확인이 필요합니다. import가 끝난 뒤에는 일반 plan이 `No changes`인지 확인합니다. `imports.tf`는 기록으로 남겨도 됩니다.

CLI import 방식을 원하면 위 plan/apply import 방식 대신 `bash import-existing.sh`를 사용할 수 있습니다. CLI import는 state에 등록하고, 뒤이어 실행하는 `terraform plan`으로 구성 차이를 확인합니다. 이 스크립트는 이미 리소스를 관리하는 state에 무작정 실행하지 마세요. 두 방식을 동시에 실행할 필요는 없습니다.

팀 운영에 사용할 GCS bucket은 이번 조회에서 확인하지 않았습니다. 첫 import를 실제 state에 기록하기 전에 bucket을 정했다면 `backend.tf.example`을 `backend.tf`로 복사하고 `backend.hcl`에 실제 bucket/prefix를 넣은 뒤 `terraform init -backend-config=backend.hcl`을 사용하세요. 이미 local state에 import한 뒤 GCS로 옮길 경우에는 `terraform init -migrate-state -backend-config=backend.hcl`로 기존 state를 함께 이전합니다. bucket 자체는 이 코드가 생성하지 않습니다.

## 현재 구성에서 따로 검토할 사항

이 제공본은 현재 값을 옮긴 것입니다. 아래 개선을 자동으로 실행하거나 기존 리소스에 반영하지 않았습니다.

- **Bastion 태그 오타:** VM은 `retail-dr-basion`, 이름이 비슷한 방화벽은 `retail-dr-bastion`을 대상으로 합니다. 따라서 그 태그 기반 규칙은 현재 Bastion에 매칭되지 않습니다. 다만 별도 `allow-iap-ssh` 규칙이 VPC 전체에 IAP 대역의 SSH를 허용합니다.
- **방화벽 이름과 범위 불일치:** `allow-iap-ssh-bastion`의 실제 출발지 범위는 `0.0.0.0/0`입니다. 태그를 먼저 고치면 이 넓은 규칙이 매칭되므로, 수정할 때는 규칙의 범위와 대상 태그를 함께 검토해야 합니다. 공인 IP가 없는 현재 Bastion이 인터넷에서 바로 접속 가능하다는 뜻은 아닙니다.
- **노드 1대의 의미:** 정상 상태는 1대지만 현재 max surge가 1이어서 업그레이드 중 추가 1대가 생길 수 있습니다. 항상 추가 노드 없이 교체하려면 `0/1`로 바꾸는 별도 변경이 필요하며 단일 노드 서비스 중단이 생길 수 있습니다.
- **현재 GKE는 public node 구성:** WSL의 기존 private node/WIF 구성과 다릅니다. 현재 값을 보존했으며 보안 구성 변경은 별도 plan으로 검토해야 합니다.
- **Pod/Service 범위:** 지금 `retail-dr-pods`/`retail-dr-services`로 바꾸는 것은 단순 이름 정리가 아닙니다. 현재 클러스터가 쓰는 범위와 다르므로 이번 코드에서는 바꾸지 않았습니다.
- **IAM:** GKE SA의 프로젝트 수준 Artifact Registry Reader 부여는 확인되지 않아 추가하지 않았습니다. Repository 자체의 IAM은 이번 범위에서 확인하지 않았으므로 이미지 pull 가능 여부를 이 결과만으로 단정할 수 없습니다. Bastion의 `container.developer` 역할만으로 VPC/IAM 전체 Terraform 변경 권한이 생기지는 않습니다.

## 소유 범위와 한계

- `retail-dr-vpc`에 연결된 위 네트워크, GKE, 관리 VM과 전용 IAM을 대상으로 합니다. 프로젝트 전체의 Cloud SQL/DMS, Cloud Storage, Artifact Registry, 애플리케이션/Helm 리소스까지 조사·코드화한 결과는 아닙니다.
- `code-server`, `default`, `dr-poc-vpc`는 포함하지 않았습니다. 별도 관련 없는 리소스를 새 state가 소유하지 않도록 했습니다.
- GKE가 생성한 워커 VM, MIG, 방화벽, 내부 IP range 및 NAT 자동 외부 IP는 독립 resource로 중복 소유하지 않습니다. 현재 GKE 생성 내부 range와 서브넷 연결만 보존합니다.
- `network.tf`의 `reserved_internal_range`는 **현재 프로젝트에 존재하는 GKE 생성 객체를 참조**합니다. 이 파일을 다른 빈 프로젝트에 그대로 실행하는 재구축용 템플릿으로 사용하면 안 됩니다. 신규 재구축용으로 바꿀 때는 관리형 Pod 범위의 생성/소유 방식을 따로 정해야 합니다.
- 스냅샷 정책 `default-schedule-1`은 `code-server`와 공유하므로 data source로 읽고 Bastion 디스크 연결만 관리합니다. 정책과 프로젝트 공용 Compute Engine SA는 이미 존재해야 합니다.
- Ops Agent 정책은 VM의 label과 `enable-osconfig`만 보존합니다. 프로젝트 공용 OS 정책 자체는 인수하지 않습니다. VM 안에 설치한 kubectl, gcloud, Terraform 등의 소프트웨어 상태나 수동 파일은 이번 코드에 포함되지 않습니다.
- 브라우저 SSH가 주입한 임시 공개키를 코드에 복사하지 않았습니다. `metadata["ssh-keys"]` 하나만 Terraform 변경 비교에서 제외해 기존 로그인 흐름을 보존합니다.
- 주요 기존 리소스에는 Terraform의 `prevent_destroy`를 넣었습니다. 기존 cloud 리소스의 삭제 방지 옵션을 켠 것과는 다르며, 코드와 비교했을 때 교체가 필요하면 먼저 plan 단계에서 멈춥니다.
- API enablement는 기존 프로젝트의 활성 API를 사용합니다. 빈 프로젝트 초기화나 전체 프로젝트 IAM 정책 덮어쓰기는 하지 않습니다.

## 확인한 화면과 참고 문서

- [VPC](https://console.cloud.google.com/networking/networks/details/retail-dr-vpc?project=kdt4-3)
- [GKE 상세](https://console.cloud.google.com/kubernetes/clusters/details/asia-northeast3-a/retail-dr-gke/details?project=kdt4-3)
- [노드 풀](https://console.cloud.google.com/kubernetes/nodepool/asia-northeast3-a/retail-dr-gke/retail-dr-pool?project=kdt4-3)
- [Bastion](https://console.cloud.google.com/compute/instancesDetail/zones/asia-northeast3-a/instances/retail-dr-bastion?project=kdt4-3)
- [관리 VM](https://console.cloud.google.com/compute/instancesDetail/zones/asia-northeast3-a/instances/retail-dr-admin?project=kdt4-3)
- [Cloud NAT](https://console.cloud.google.com/net-services/nat/details/asia-northeast3/retail-dr-router-real/retail-dr-nat?project=kdt4-3)
- [프로젝트 IAM](https://console.cloud.google.com/iam-admin/iam?project=kdt4-3)
- [Terraform import와 코드 생성](https://developer.hashicorp.com/terraform/language/import/generating-configuration)
- [PSA Terraform resource/import](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_networking_connection)
- [Peering routes Terraform resource/import](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_network_peering_routes_config)
